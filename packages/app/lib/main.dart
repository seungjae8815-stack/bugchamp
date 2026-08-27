import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_version.dart';
import 'data/save_repository.dart';
import 'domain/ad_service.dart';
import 'domain/admob_ad_service.dart';
import 'domain/audio_service.dart';
import 'domain/auth_service.dart';
import 'domain/chat_service.dart';
import 'domain/game_server.dart';
import 'domain/cloud_save_service.dart';
import 'domain/notification_service.dart';
import 'domain/locale_prefs.dart';
import 'domain/providers.dart';
import 'domain/iap_service.dart';
import 'domain/purchase_verifier.dart';
import 'domain/pvp_backend.dart';
import 'domain/store_iap_service.dart';
import 'domain/supabase_pvp_backend.dart';
import 'features/title/title_screen.dart';
import 'l10n/app_localizations.dart';

/// Supabase 자격증명은 코드에 넣지 않고 빌드 인자로 주입(GitHub 유출 방지):
///   flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
/// 둘 중 하나라도 비어 있으면 로컬 백엔드(LocalPvpBackend)로 동작한다.
const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

/// 구글 로그인용 **웹** 클라이언트 ID(공개값). 없으면 로그인 버튼이 비활성.
const _googleWebClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');

/// 권위 서버 주소. `--dart-define=GAME_SERVER_URL=https://...` 로 주입한다.
/// 비어 있으면 **기존 로컬 계산 경로**로 동작한다(전환 중 안전장치).
const _gameServerUrl = String.fromEnvironment('GAME_SERVER_URL');

/// 스토어 결제 사용 여부. `--dart-define=STORE_IAP=on|off` 로 강제할 수 있고,
/// 지정이 없으면 **릴리즈 빌드에서만 켠다**.
///
/// 기본값이 이런 이유: 개발용 `LocalIapService` 는 결제 없이 상품을 그냥 주므로
/// 릴리즈에 딸려 나가면 전 상품이 공짜가 된다. 릴리즈=스토어를 기본으로 두어
/// "깜빡하고 로컬로 출시"가 구조적으로 불가능하게 만든다.
const _storeIapFlag = String.fromEnvironment('STORE_IAP');
bool get _useStoreIap => switch (_storeIapFlag) {
  'on' => true,
  'off' => false,
  _ => kReleaseMode,
};

/// 실광고 사용 여부. `--dart-define=REAL_ADS=on|off`, **기본 off**.
///
/// 2026-08-18 광고 없는 운영으로 전환(사장님 결정 — 애드몹 무효 트래픽 정지 후,
/// 수익은 인앱결제로). `NoAdService` 가 모든 "무료로 받기"를 즉시 지급한다.
/// 예전 기본값은 릴리즈=실광고였다. 광고를 되살릴 땐 REAL_ADS=on 으로 빌드하고,
/// **그 전에 ARB 문구를 광고용으로 되돌려야 한다** — 지금 문구는 광고를 언급하지
/// 않는다(광고 없이 "광고 보기"라고 쓰면 기만이라 전부 "무료" 계열로 바꿨다).
const _realAdsFlag = String.fromEnvironment('REAL_ADS');
bool get _useRealAds => switch (_realAdsFlag) {
  'on' => true,
  _ => false,
};

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 세로 고정 — 모든 화면이 세로 설계라 가로로 돌면 레이아웃이 깨진다
  // (실기 지적 2026-08-20). 매니페스트/Info.plist 잠금과 삼중이지만,
  // 하나만 믿으면 플랫폼별로 새는 구멍이 생긴다.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  // 설정 화면에 보여줄 버전 — pubspec 값을 그대로 읽는다(표시 전용).
  await loadAppVersion();
  await Hive.initFlutter();
  final box = await Hive.openBox<String>('bugchamp_save');
  final repository = HiveSaveRepository(box);

  // 로컬 알림 초기화(실패해도 앱은 정상). 권한 요청·예약은 AppShell 에서.
  await NotificationService.instance.init();

  // Supabase: 키가 주입됐을 때만 초기화 + 익명 로그인. 실패 시 client=null → 로컬 유지.
  // 값 끝의 공백/개행이 있으면 URL·키가 무효가 되므로 trim 한다(CI 붙여넣기 방어).
  SupabaseClient? supaClient;
  final supaUrl = _supabaseUrl.trim();
  final supaKey = _supabaseAnonKey.trim();
  if (supaUrl.isNotEmpty && supaKey.isNotEmpty) {
    try {
      await Supabase.initialize(
        url: supaUrl,
        // ignore: deprecated_member_use — 레거시 anon(JWT) 키 사용. 신형 키면 publishableKey 로 교체.
        anonKey: supaKey,
      );
      final client = Supabase.instance.client;
      if (client.auth.currentUser == null) {
        await client.auth.signInAnonymously();
      }
      supaClient = client;
    } catch (e) {
      // 초기화/로그인 실패 → 로컬 백엔드 유지(앱은 정상 동작).
      debugPrint('Supabase init failed: $e');
    }
  }

  // 저장된 표시 언어를 **첫 프레임 전에** 읽는다(안 그러면 기기 언어로 한 번
  // 그려졌다가 바뀌어 깜빡인다).
  final savedLocale = await loadSavedLocale();

  runApp(
    ProviderScope(
      overrides: [
        saveRepositoryProvider.overrideWithValue(repository),
        initialLocaleProvider.overrideWithValue(savedLocale),
        if (_useRealAds)
          adServiceProvider.overrideWith((ref) {
            final s = AdMobAdService();
            ref.onDispose(s.dispose);
            unawaited(s.init());
            return s;
          }),
        if (_useStoreIap)
          iapServiceProvider.overrideWith((ref) {
            final s = StoreIapService(ref);
            ref.onDispose(s.dispose);
            return s;
          }),
        if (supaClient != null) ...[
          pvpBackendProvider.overrideWithValue(SupabasePvpBackend(supaClient)),
          cloudSaveProvider.overrideWithValue(SupabaseCloudSave(supaClient)),
          if (_gameServerUrl.isNotEmpty)
            gameServerProvider.overrideWithValue(
              HttpGameServer(baseUrl: _gameServerUrl, client: supaClient),
            ),
          purchaseVerifierProvider.overrideWithValue(
            SupabasePurchaseVerifier(supaClient),
          ),
          chatServiceProvider.overrideWith((ref) {
            final s = SupabaseChatService(supaClient!);
            ref.onDispose(s.dispose);
            return s;
          }),
          authServiceProvider.overrideWithValue(
            SupabaseAuthService(supaClient, _googleWebClientId),
          ),
        ],
      ],
      child: const BugChampApp(),
    ),
  );
}

/// 앱 루트. 실제 화면(홈/채집/보관함)은 Phase 1 UI 단계에서 features/ 아래에 구현한다.
class BugChampApp extends ConsumerWidget {
  const BugChampApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3B7A2A)),
        useMaterial3: true,
        // 앱은 다크 게임 톤 — Scaffold/AppBar 기본 배경을 어둡게(밝은 M3 기본 위
        // 흰 글씨가 안 보이던 전투·랭킹 등 화면을 한 번에 맞춘다). 플레이/보관함은
        // 자체 다크 배경을 그 위에 그리므로 영향 없음.
        scaffoldBackgroundColor: const Color(0xFF11190B),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF16240D),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        // ⚠️ 비활성 버튼 색을 **여기서 한 번에** 정한다.
        //    호출부는 보통 backgroundColor 만 주는데, 그러면 비활성 색은 M3
        //    기본값(밝은 테마 기준 회색)이 깔려 **다크 배경에서 글씨가 사라진다**.
        //    "재화가 모자라다"를 알려야 할 버튼이 통째로 안 보이던 원인.
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            disabledBackgroundColor: const Color(0x33FFFFFF),
            disabledForegroundColor: const Color(0x99FFFFFF),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            disabledForegroundColor: const Color(0x99FFFFFF),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            disabledForegroundColor: const Color(0x99FFFFFF),
          ),
        ),
      ),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // null 이면 기기 설정을 따른다(기본). 설정에서 고르면 그 언어로 고정.
      //
      // ⚠️ 지원하지 않는 언어(예: 프랑스어) 기기는 Flutter 가
      // `supportedLocales` 의 **첫 항목(en)** 으로 떨어뜨린다. 한국어를
      // 원하는 사람에게 방법이 없었던 이유다.
      locale: ref.watch(localePrefsProvider),
      navigatorObservers: [_SheetSound()],
      // 대문 → (게이트·로그인·동기화·닉네임) → AppShell.
      home: const TitleScreen(),
    );
  }
}

/// 바텀시트가 열릴 때 스와이프 효과음. 시트를 여는 곳이 10군데라 호출부마다
/// 넣으면 새 시트를 추가할 때 빠뜨린다 — 라우트를 관찰해 한 곳에서 처리한다.
class _SheetSound extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is ModalBottomSheetRoute) AudioService.instance.sfxSwipe();
  }
}

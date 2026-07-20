import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/save_repository.dart';
import 'domain/auth_service.dart';
import 'domain/cloud_save_service.dart';
import 'domain/notification_service.dart';
import 'domain/providers.dart';
import 'domain/pvp_backend.dart';
import 'domain/supabase_pvp_backend.dart';
import 'features/app_shell.dart';
import 'l10n/app_localizations.dart';

/// Supabase 자격증명은 코드에 넣지 않고 빌드 인자로 주입(GitHub 유출 방지):
///   flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
/// 둘 중 하나라도 비어 있으면 로컬 백엔드(LocalPvpBackend)로 동작한다.
const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

/// 구글 로그인용 **웹** 클라이언트 ID(공개값). 없으면 로그인 버튼이 비활성.
const _googleWebClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  final box = await Hive.openBox<String>('bugchamp_save');
  final repository = HiveSaveRepository(box);

  // 로컬 알림 초기화(실패해도 앱은 정상). 권한 요청·예약은 AppShell 에서.
  await NotificationService.instance.init();

  // Supabase: 키가 주입됐을 때만 초기화 + 익명 로그인. 실패 시 client=null → 로컬 유지.
  SupabaseClient? supaClient;
  if (_supabaseUrl.isNotEmpty && _supabaseAnonKey.isNotEmpty) {
    try {
      await Supabase.initialize(
        url: _supabaseUrl,
        // ignore: deprecated_member_use — 레거시 anon(JWT) 키 사용. 신형 키면 publishableKey 로 교체.
        anonKey: _supabaseAnonKey,
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

  runApp(
    ProviderScope(
      overrides: [
        saveRepositoryProvider.overrideWithValue(repository),
        if (supaClient != null) ...[
          pvpBackendProvider.overrideWithValue(SupabasePvpBackend(supaClient)),
          cloudSaveProvider.overrideWithValue(SupabaseCloudSave(supaClient)),
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
class BugChampApp extends StatelessWidget {
  const BugChampApp({super.key});

  @override
  Widget build(BuildContext context) {
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
      ),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const AppShell(),
    );
  }
}

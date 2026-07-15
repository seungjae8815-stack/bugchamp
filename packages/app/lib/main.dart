import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/save_repository.dart';
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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  final box = await Hive.openBox<String>('bugchamp_save');
  final repository = HiveSaveRepository(box);

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
        if (supaClient != null)
          pvpBackendProvider.overrideWithValue(SupabasePvpBackend(supaClient)),
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
      ),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const AppShell(),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'data/save_repository.dart';
import 'domain/providers.dart';
import 'features/app_shell.dart';
import 'l10n/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  final box = await Hive.openBox<String>('bugchamp_save');
  final repository = HiveSaveRepository(box);

  runApp(
    ProviderScope(
      overrides: [saveRepositoryProvider.overrideWithValue(repository)],
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

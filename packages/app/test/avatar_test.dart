import 'dart:convert';
import 'dart:io';

import 'package:app/data/game_data.dart';
import 'package:app/data/save_repository.dart';
import 'package:app/domain/providers.dart';
import 'package:app/domain/save_controller.dart';
import 'package:app/l10n/app_localizations.dart';
import 'package:app/ui/avatar.dart';
import 'package:core_save/core_save.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 프로필 그림(2026-10-10 사장님 확정, 1.0.19) — 모두 무료 · 고르면 세이브에 · 모르는 id 는 기본으로.
class _Repo implements SaveRepository {
  _Repo(this._g);
  SaveGame _g;
  @override
  SaveLoadFailure? get lastFailure => null;
  @override
  Future<SaveGame> load() async => _g;
  @override
  Future<void> save(SaveGame g) async => _g = g;
  @override
  Future<void> clear() async {}
}

Map<String, dynamic> _read(String f) =>
    jsonDecode(File('assets/data/$f').readAsStringSync())
        as Map<String, dynamic>;

GameData _data() => GameData.fromDecoded(
  species: _read('species.json'),
  traps: _read('traps.json'),
  fields: _read('fields.json'),
  spawns: _read('spawns.json'),
  runConfig: _read('run_config.json'),
);

void main() {
  test('목록 — 20개 + 기본, id 는 SQL 검사 꼴(avatar_*)과 맞고 그림 파일이 모두 있다', () {
    final cat = AvatarCatalog.fromJson(_read('avatars.json'));
    expect(cat.avatars.length, 21);
    expect(cat.byId(cat.defaultId), isNotNull);
    final ids = <String>{};
    for (final a in cat.avatars) {
      expect(
        RegExp(r'^avatar_[a-z0-9_]{1,24}$').hasMatch(a.id),
        isTrue,
        reason: a.id,
      );
      expect(ids.add(a.id), isTrue, reason: '중복 ${a.id}');
      expect(File(a.image).existsSync(), isTrue, reason: a.image);
      for (final lang in ['ko', 'en', 'ja']) {
        expect(a.name[lang], isNotNull, reason: '${a.id} $lang');
      }
    }
    // 모르는 id·null 은 기본 프로필.
    expect(cat.shown(null)!.id, cat.defaultId);
    expect(cat.shown('avatar_future_99')!.id, cat.defaultId);
  });

  testWidgets('고르기 창에서 누르면 세이브에 들어가고, 모르는 id 도 깨지지 않고 그려진다', (tester) async {
    final container = ProviderContainer(
      overrides: [
        gameDataProvider.overrideWith((ref) => _data()),
        saveRepositoryProvider.overrideWithValue(
          _Repo(SaveGame.initial(createdAt: DateTime.utc(2026, 10))),
        ),
        avatarCatalogProvider.overrideWith(
          (ref) async => AvatarCatalog.fromJson(_read('avatars.json')),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.runAsync(() => container.read(saveControllerProvider.future));
    await tester.runAsync(() => container.read(avatarCatalogProvider.future));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('ko'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => Column(
                children: [
                  const AvatarCircle(id: 'avatar_future_99', size: 30),
                  const AvatarCircle(id: null, size: 16),
                  TextButton(
                    key: const ValueKey('open'),
                    onPressed: () => showAvatarPicker(context, ref),
                    child: const Text('open'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('open')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('avatarPick:avatar_default')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('avatarPick:avatar_07')));
    await tester.pumpAndSettle();
    expect(
      container.read(saveControllerProvider).requireValue.avatar,
      'avatar_07',
    );
    // 토스트 타이머를 흘려보낸다.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });
}

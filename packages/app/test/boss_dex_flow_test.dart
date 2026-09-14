import 'dart:convert';
import 'dart:io';

import 'package:app/data/game_data.dart';
import 'package:app/data/save_repository.dart';
import 'package:app/domain/providers.dart';
import 'package:app/domain/save_controller.dart';
import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:core_save/core_save.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
  Future<void> clear() async =>
      _g = SaveGame.initial(createdAt: DateTime.utc(2026));
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
  dexConfig: _read('dex.json'),
  roadmapConfig: _read('roadmap.json'),
);

/// 도감 보스 수집(2026-09-15) — 보스를 깨면 기록되고, 마일스톤은 젤리·화석을 준다.
void main() {
  final t0 = DateTime.utc(2026, 9, 15, 12);
  final run = RunConfig.fromJson(_read('run_config.json'));

  ProviderContainer make(SaveGame seed) {
    final c = ProviderContainer(
      overrides: [
        gameDataProvider.overrideWith((ref) => _data()),
        saveRepositoryProvider.overrideWithValue(_Repo(seed)),
        clockProvider.overrideWithValue(FixedClock(t0)),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('사냥터 보스를 깨면 그 난이도의 보스로 기록된다(최종 보스 포함)', () async {
    final c = make(
      SaveGame.initial(createdAt: t0).copyWith(
        lastSeen: t0,
        zoneEpoch: kZoneEpoch,
        difficultyTier: 1,
        maxTierReached: 1,
        stageNumber: run.zoneStartStage(3),
      ),
    );
    await c.read(saveControllerProvider.future);
    final ctrl = c.read(saveControllerProvider.notifier);
    await ctrl.advanceZone();
    var s = c.read(saveControllerProvider).requireValue;
    expect(s.bossDex, {'n03'});
    expect(s.stageNumber, run.zoneStartStage(4));

    // 최종 사냥터: 옮기지는 않지만 기록은 남는다.
    final fin = make(
      s.copyWith(stageNumber: run.zoneStartStage(run.zonesPerTier)),
    );
    await fin.read(saveControllerProvider.future);
    await fin.read(saveControllerProvider.notifier).advanceZone();
    s = fin.read(saveControllerProvider).requireValue;
    expect(s.bossDex, {'n03', 'n_final'});
    expect(s.stageNumber, run.zoneStartStage(run.zonesPerTier));
  });

  test('보스 5마리 마일스톤을 받으면 젤리·화석이 들어온다', () async {
    final c = make(
      SaveGame.initial(
        createdAt: t0,
      ).copyWith(lastSeen: t0, bossDex: {'e01', 'e02', 'e03', 'e04', 'e05'}),
    );
    await c.read(saveControllerProvider.future);
    final got = await c
        .read(saveControllerProvider.notifier)
        .claimDexMilestones();
    expect(got.map((m) => m.id), contains('dex_b_5'));
    final s = c.read(saveControllerProvider).requireValue;
    final m = got.firstWhere((m) => m.id == 'dex_b_5');
    expect(s.materialCount(MaterialKind.fossil), m.fossil);
    expect(s.claimedDex, contains('dex_b_5'));
  });
}

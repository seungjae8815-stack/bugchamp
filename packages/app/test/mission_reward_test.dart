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

/// 미션 보상 개편(2026-10-10 사장님 확정) — 사냥·강화 미션 = 사냥 10분치 · 젤리 미션 = 하루 2번까지.
///
/// 목표 상한 뒤로 옛 식(`rewardGrowth^claims`)이 받을 때마다 1.6배씩 커져 쉬움에서 94만~10억 골드가 됐고,
/// 제련 미션 젤리는 켜 둔 시간에 비례해 하루 30개까지 나왔다.
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
  petConfig: _read('pets.json'),
  missionConfig: _read('missions.json'),
);

void main() {
  final t0 = DateTime.utc(2026, 10, 10, 3);
  final missions = MissionConfig.fromJson(_read('missions.json'));
  final hunt = missions.missions.firstWhere((m) => m.reward == 'gold');
  final forge = missions.missions.firstWhere((m) => m.reward == 'jelly');

  ProviderContainer make(SaveGame seed, {DateTime? now}) {
    final c = ProviderContainer(
      overrides: [
        gameDataProvider.overrideWith((ref) => _data()),
        saveRepositoryProvider.overrideWithValue(_Repo(seed)),
        clockProvider.overrideWithValue(FixedClock(now ?? t0)),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  SaveGame seed() =>
      SaveGame.initial(createdAt: t0).copyWith(lastSeen: t0, gold: 0);

  test('사냥 미션 골드는 받은 횟수와 상관없이 사냥 10분치 — 옛 식처럼 1.6배씩 자라지 않는다', () async {
    Future<int> gain(int claims) async {
      final c = make(
        seed().copyWith(
          missionClaims: {hunt.id: claims},
          missionProgress: {hunt.id: hunt.goalAt(claims)},
        ),
      );
      await c.read(saveControllerProvider.future);
      final ctrl = c.read(saveControllerProvider.notifier);
      final shown = ctrl.missionRewardAmount(hunt);
      final got = await ctrl.claimMission(hunt.id);
      expect(got, isNotNull);
      expect(got!.gold, shown.gold, reason: '화면 표시와 실제 지급이 같다');
      expect(c.read(saveControllerProvider).requireValue.gold, got.gold);
      return got.gold;
    }

    final at0 = await gain(0);
    final at30 = await gain(30);
    expect(at0, greaterThan(0));
    expect(at30, at0);
    expect(at30, lessThan(hunt.rewardAt(30)), reason: '옛 식이면 2.7억');
  });

  test('젤리 미션은 하루 2번까지 — 세 번째는 젤리 없이 다음 미션으로 · 다음 날 다시', () async {
    var s = seed();
    // 매번 직전 세이브(받은 횟수·오늘 기록)로 다시 켜고 진행도만 채운다.
    Future<int> claim() async {
      final c = make(
        s.copyWith(
          missionProgress: {
            forge.id: forge.goalAt(s.missionClaimCount(forge.id)),
          },
        ),
      );
      await c.read(saveControllerProvider.future);
      final got = await c
          .read(saveControllerProvider.notifier)
          .claimMission(forge.id);
      expect(got, isNotNull);
      s = c.read(saveControllerProvider).requireValue;
      return got!.materials[MaterialKind.jelly] ?? 0;
    }

    expect(await claim(), greaterThan(0));
    expect(await claim(), greaterThan(0));
    expect(await claim(), 0);
    expect(s.missionClaimCount(forge.id), 3, reason: '젤리 없이도 다음 미션으로 넘어간다');
    expect(
      missionJellyAvailable(
        s,
        forge,
        dailyDateKey(t0.add(const Duration(days: 1))),
      ),
      isTrue,
    );
  });
}

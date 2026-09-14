import 'dart:convert';
import 'dart:io';

import 'package:core_run/core_run.dart';
import 'package:core_save/core_save.dart';
import 'package:test/test.dart';

/// 도감 보스 수집(2026-09-15) — `boss_dex.dart`.
void main() {
  Map<String, dynamic> read(String f) =>
      jsonDecode(File('../app/assets/data/$f').readAsStringSync())
          as Map<String, dynamic>;
  final run = RunConfig.fromJson(read('run_config.json'));
  final roadmap = RoadmapConfig.fromJson(read('roadmap.json'));
  final dex = DexConfig.fromJson(read('dex.json'));
  final base = SaveGame.initial(createdAt: DateTime.utc(2026, 1, 1));

  test('칸은 난이도마다 사냥터 수만큼, id 가 전부 다르다', () {
    final slots = bossDexSlots(run);
    expect(slots.length, kBossDexTiers * run.zonesPerTier);
    expect(slots.map((s) => s.id).toSet().length, slots.length);
    for (final s in slots) {
      expect(
        File('../app/assets/images/bosses/${s.id}.webp').existsSync(),
        isTrue,
        reason: '${s.id} 그림이 없다',
      );
    }
  });

  test('기록한 보스 + 옛 클리어 기록(난이도별 키)을 합쳐 센다', () {
    final s = base.copyWith(
      bossDex: {'e05'},
      clearedChapters: {'w1', 'w2@1', 'w11@3'},
    );
    expect(collectedBosses(s, run, roadmap), {'e05', 'e01', 'n02', 'x_final'});
  });

  test('bossDex 는 세이브를 오간다(비었으면 싣지 않는다)', () {
    expect(base.toJson().containsKey('bossDex'), isFalse);
    final s = base.copyWith(bossDex: {'h03', 'n_final'});
    expect(SaveGame.fromJson(s.toJson()).bossDex, {'h03', 'n_final'});
  });

  test('보스 마일스톤: 모은 수에 따라 열리고 한 번만 받는다, 골드는 없다', () {
    expect(dex.bossMilestones, isNotEmpty);
    expect(dex.bossMilestones.last.count, kBossDexTiers * run.zonesPerTier);
    for (final m in dex.bossMilestones) {
      expect(m.isBoss, isTrue);
      expect(m.gold, 0, reason: '골드는 난이도마다 규모가 달라 정액이면 안 된다');
    }
    final five = dex.claimable(0, 0, const {}, bosses: 5);
    expect(five.map((m) => m.id), ['dex_b_5']);
    expect(dex.claimable(0, 0, {'dex_b_5'}, bosses: 5), isEmpty);
    expect(dex.claimable(0, 0, const {}), isEmpty);
  });
}

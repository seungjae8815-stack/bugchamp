import 'package:core_run/core_run.dart';
import 'package:core_save/core_save.dart';
import 'package:server/src/actions.dart';
import 'package:server/src/game_config.dart';
import 'package:test/test.dart';

/// 심연 포자 · 심연 연구소 업로드 검사(2026-11-12, `_enforceAbyssLab`).
void main() {
  late GameConfig cfg;
  late GameActions actions;
  late AbyssLabConfig lab;
  final t0 = DateTime.utc(2026, 9, 29, 3); // 월요일 12시 KST — 이번 주 = 2026-09-28
  const week = '2026-09-28';

  setUpAll(() async {
    cfg = await GameConfig.load(dir: '../app/assets/data');
    actions = GameActions(config: cfg, now: () => t0);
    lab = cfg.research!.abyssLab;
  });

  SaveGame stored({int spores = 0, Map<String, int> levels = const {}}) =>
      SaveGame.initial(createdAt: t0).copyWith(
        lastSeen: t0.subtract(const Duration(minutes: 10)),
        zoneEpoch: kZoneEpoch,
        difficultyTier: 3,
        maxTierReached: 3,
        stageNumber: abyssStage(cfg.run),
        bossDex: {cfg.run.bossArtId(abyssTier(cfg.run), cfg.run.zonesPerTier)},
        abyssUnlocked: true,
        inAbyss: true,
        abyssFloor: 5,
        abyssBest: 4,
        abyssWeekTop: 4,
        abyssWeek: week,
        abyssSpores: spores,
        abyssLabLevels: levels,
      );

  test('새로 깬 층의 포자만 인정 · 부풀린 포자는 잘린다', () {
    final s = stored();
    final up = s.copyWith(abyssFloor: 6, abyssBest: 5, abyssWeekTop: 5);
    final ok = actions.mergeSave(
      s,
      up.copyWith(abyssSpores: lab.sporesPerFloor).toJson(),
    );
    expect(ok.save!.abyssSpores, lab.sporesPerFloor);
    final forged = actions.mergeSave(s, up.copyWith(abyssSpores: 999).toJson());
    expect(forged.save!.abyssSpores, lab.sporesPerFloor);
  });

  test('정당한 연구 시작은 받고 포자를 뺀다', () {
    final d = lab.defs.first;
    final cost = cfg.research!.costAt(d, 1).samples;
    final s = stored(spores: cost + 5);
    final r = startAbyssLab(s, cfg.research!, d.id, t0);
    final got = actions.mergeSave(s, r.save!.toJson()).save!;
    expect(got.abyssLabSlot?.id, d.id);
    expect(got.abyssSpores, 5);
  });

  test('곧바로 끝나는 칸 · 칸 없이 올린 레벨은 무효', () {
    final d = lab.defs.first;
    final cost = cfg.research!.costAt(d, 1).samples;
    final s = stored(spores: cost);
    final instant = s.copyWith(
      abyssSpores: 0,
      abyssLabSlot: ResearchSlot(id: d.id, level: 1, endsAt: t0),
    );
    final a = actions.mergeSave(s, instant.toJson()).save!;
    expect(a.abyssLabSlot, isNull);
    expect(a.abyssLabLevels[d.id] ?? 0, 0);
    final forged = s.copyWith(abyssLabLevels: {d.id: 5});
    final b = actions.mergeSave(s, forged.toJson()).save!;
    expect(b.abyssLabLevels[d.id] ?? 0, 0);
  });

  test('끝난 저장본 칸은 레벨로 받는다', () {
    final d = lab.defs.first;
    final s = stored().copyWith(
      abyssLabSlot: ResearchSlot(id: d.id, level: 1, endsAt: t0),
    );
    final up = claimAbyssLab(s, t0);
    final got = actions.mergeSave(s, up.toJson()).save!;
    expect(got.abyssLabLevels[d.id], 1);
    expect(got.abyssLabSlot, isNull);
  });
}

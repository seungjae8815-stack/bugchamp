import 'package:core_run/core_run.dart';
import 'package:core_save/core_save.dart';
import 'package:server/src/actions.dart';
import 'package:server/src/game_config.dart';
import 'package:test/test.dart';

/// 심연 결정 · 강화 상한 돌파 · 심연 각인 업로드 검사(2026-11-10).
void main() {
  late GameConfig cfg;
  late GameActions actions;
  final t0 = DateTime.utc(2026, 9, 29, 3); // 월요일 12시 KST — 이번 주 = 2026-09-28
  const week = '2026-09-28';

  setUpAll(() async {
    cfg = await GameConfig.load(dir: '../app/assets/data');
    actions = GameActions(config: cfg, now: () => t0);
  });

  SaveGame stored({
    int floor = 9,
    int top = 8,
    int crystals = 0,
    Duration ago = const Duration(minutes: 10),
  }) => SaveGame.initial(createdAt: t0).copyWith(
    lastSeen: t0.subtract(ago),
    zoneEpoch: kZoneEpoch,
    difficultyTier: 3,
    maxTierReached: 3,
    stageNumber: abyssStage(cfg.run),
    bossDex: {cfg.run.bossArtId(abyssTier(cfg.run), cfg.run.zonesPerTier)},
    abyssUnlocked: true,
    inAbyss: true,
    abyssFloor: floor,
    abyssBest: top,
    abyssWeekTop: top,
    abyssWeek: week,
    abyssCrystals: crystals,
  );

  test('10층을 깨면 결정을 받는다 · 그 이상은 잘린다', () {
    final s = stored();
    final got = cfg.run.abyss.crystalsAt(10);
    expect(got, greaterThan(0));
    final ok = actions.mergeSave(
      s,
      s
          .copyWith(
            abyssFloor: 11,
            abyssBest: 10,
            abyssWeekTop: 10,
            abyssCrystals: got,
          )
          .toJson(),
    );
    expect(ok.save!.abyssCrystals, got);
    final forged = actions.mergeSave(
      s,
      s.copyWith(abyssFloor: 11, abyssWeekTop: 10, abyssCrystals: 999).toJson(),
    );
    expect(forged.save!.abyssCrystals, got);
    expect(forged.extra['clampReasons'], contains('abyssCrystal'));
  });

  test('그 주 최고 층 아래를 다시 깨도 결정이 늘지 않는다', () {
    final s = stored(floor: 10, top: 10, crystals: 5);
    final r = actions.mergeSave(
      s,
      s.copyWith(abyssFloor: 11, abyssCrystals: 8).toJson(),
    );
    expect(r.save!.abyssCrystals, 5);
  });

  test('결정으로 상한 돌파 · 모자라면 저장본 단계로 · 단계는 줄지 않는다', () {
    final cost = cfg.run.abyss.capStepCost(0)!;
    final s = stored(crystals: cost);
    final bought = buyUpgradeCapStep(s, cfg.run, UpgradeKind.attack)!;
    final r = actions.mergeSave(s, bought.toJson());
    expect(r.save!.upgradeCapUps[UpgradeKind.attack], 1);
    expect(r.save!.abyssCrystals, 0);

    final greedy = s.copyWith(
      upgradeCapUps: {UpgradeKind.attack: 3},
      abyssCrystals: 0,
    );
    final g = actions.mergeSave(s, greedy.toJson());
    expect(g.save!.upgradeCapUps[UpgradeKind.attack], isNull);
    expect(g.extra['clampReasons'], contains('abyssCrystal'));

    final dropped = actions.mergeSave(
      r.save!,
      r.save!.copyWith(upgradeCapUps: const {}).toJson(),
    );
    expect(dropped.save!.upgradeCapUps[UpgradeKind.attack], 1);
  });

  test('치명·회피는 상한 돌파가 없다', () {
    final s = stored(crystals: 100);
    final r = actions.mergeSave(
      s,
      s.copyWith(upgradeCapUps: {UpgradeKind.crit: 2}).toJson(),
    );
    expect(r.save!.upgradeCapUps[UpgradeKind.crit], isNull);
  });

  test('각인은 결정을 쓴 만큼만 오른다', () {
    final cost = cfg.run.abyss.imprintCost(0);
    final s = stored(crystals: cost);
    final bought = buyAbyssImprint(s, cfg.run, 'attack')!;
    final r = actions.mergeSave(s, bought.toJson());
    expect(r.save!.abyssImprint['attack'], 1);
    final forged = actions.mergeSave(
      s,
      s.copyWith(abyssImprint: {'attack': 20}).toJson(),
    );
    expect(forged.save!.abyssImprint['attack'], isNull);
  });

  test('구버전 앱(feat 29)이 올리면 결정·돌파·각인을 저장본으로 지킨다', () {
    final s = stored(crystals: 7).copyWith(
      upgradeCapUps: {UpgradeKind.attack: 1},
      abyssImprint: {'maxHp': 2},
    );
    final json = s.toJson()
      ..['feat'] = 29
      ..remove('abC')
      ..remove('abWt')
      ..remove('upCap')
      ..remove('abI');
    final r = actions.mergeSave(s, json);
    expect(r.save!.abyssCrystals, 7);
    expect(r.save!.upgradeCapUps[UpgradeKind.attack], 1);
    expect(r.save!.abyssImprint['maxHp'], 2);
  });

  test('달성하지 않은 업적의 칭호는 서버가 뗀다 · 달성한 칭호는 남긴다', () {
    final s = stored();
    final bad = actions.mergeSave(s, s.copyWith(title: 'abyss100').toJson());
    expect(bad.save!.title, isNull);
    final ok = actions.mergeSave(s, s.copyWith(title: 'tier3').toJson());
    expect(ok.save!.title, 'tier3');
  });

  test('크기 순위 기록 — 오른 종만 · 종 최대 크기 × 1.3 으로 자른다', () {
    final sp = cfg.speciesList.first;
    final s = stored().copyWith(dex: {sp.id: const DexEntry(maxSizeMm: 10)});
    final up = s.copyWith(dex: {sp.id: const DexEntry(maxSizeMm: 12)});
    expect(actions.speciesSizeGains(s, up), {sp.id: 12.0});
    expect(actions.speciesSizeGains(up, up), isEmpty);
    final forged = s.copyWith(dex: {sp.id: const DexEntry(maxSizeMm: 99999)});
    expect(
      actions.speciesSizeGains(s, forged)[sp.id],
      closeTo(sp.sizeMaxMm * 1.3, 0.1),
    );
  });
}

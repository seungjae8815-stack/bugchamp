import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:core_save/core_save.dart';
import 'package:server/src/actions.dart';
import 'package:server/src/game_config.dart';
import 'package:test/test.dart';

/// 방치 정예 희귀 드롭 · 채집꾼 버프(2026-10-14 사장님 확정) — 업로드 검사가 정상 증가를 자르지 않고,
/// 터무니없는 증가는 자르는지. 허용치는 경과 시간 기반(`rareDropUploadAllowance`, core_save 공용).
final t0 = DateTime.utc(2026, 10, 14, 12);

void main() {
  late GameConfig cfg;
  late GameActions actions;

  setUpAll(() async {
    cfg = await GameConfig.load(dir: '../app/assets/data');
    actions = GameActions(config: cfg, now: () => t0);
  });

  SaveGame stored(Duration ago) => SaveGame.initial(
    createdAt: t0.subtract(const Duration(days: 3)),
  ).copyWith(lastSeen: t0.subtract(ago));

  String sub() => cfg.fairy!.subWeight.keys.first;
  int fairyStones(SaveGame s) => s.fairy.stones.values.fold(0, (a, b) => a + b);
  int duelStones(SaveGame s) => s.duelStones.values.fold(0, (a, b) => a + b);

  test('설정 — 채집꾼 희귀 배율을 서버도 읽는다', () {
    expect(cfg.buffs, isNotNull);
    expect(cfg.buffs!.maxRareDropMult, 2.0);
  });

  test('8시간 방치(채집꾼) 뒤 속성석 15 · 결투석 12 · 물약 3 — 잘리지 않는다', () {
    // 정상 기댓값은 속성석 4~7 · 결투석 1 · 물약 1~2 — 운 좋은 꼬리(예전 업로드 여유 10 을 넘는 값)까지.
    final s = stored(const Duration(hours: 8));
    final day = dailyDateKey(t0);
    final client = s.copyWith(
      fairy: s.fairy.copyWith(stones: {sub(): 15}),
      duelStones: {DuelStone.element: 12},
      growthPotions: 3,
      dailyClaims: {kPotionDropKey: '$day:03'},
    );
    final r = actions.mergeSave(s, client.toJson());
    expect(fairyStones(r.save!), 15);
    expect(duelStones(r.save!), 12);
    expect(r.save!.growthPotions, 3);
    expect(r.extra['clampReasons'], isNot(contains('fairy')));
    expect(r.extra['clampReasons'], isNot(contains('train')));
    expect(r.extra['clampReasons'], isNot(contains('grade')));
  });

  test('8시간이어도 터무니없는 증가는 저장본 수로', () {
    final s = stored(const Duration(hours: 8));
    final client = s.copyWith(
      fairy: s.fairy.copyWith(stones: {sub(): 500}),
      duelStones: {DuelStone.element: 500},
    );
    final r = actions.mergeSave(s, client.toJson());
    expect(fairyStones(r.save!), 0);
    expect(duelStones(r.save!), 0);
    expect(r.extra['clampReasons'], containsAll(['fairy', 'train']));
  });

  test('60초 업로드의 속성석 15 는 잘린다(경과 시간 기반)', () {
    final s = stored(const Duration(seconds: 60));
    final client = s.copyWith(fairy: s.fairy.copyWith(stones: {sub(): 15}));
    final r = actions.mergeSave(s, client.toJson());
    expect(fairyStones(r.save!), 0);
  });

  test('물약은 그날 확률 드롭 한도(potionDropDaily)까지만', () {
    final s = stored(const Duration(hours: 8));
    final cap = cfg.pet.individualGrade.potionDropDaily;
    final client = s.copyWith(growthPotions: cap + 5);
    final r = actions.mergeSave(s, client.toJson());
    expect(r.save!.growthPotions, cap);
  });
}

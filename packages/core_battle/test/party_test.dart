import 'package:core_battle/core_battle.dart';
import 'package:core_models/core_models.dart';
import 'package:test/test.dart';

/// `buildBattleBug` — 개체 → 전투 유닛 변환.
///
/// **앱과 서버가 같은 결과를 내야 한다.** 한쪽만 달라지면 "클라에선 이겼는데
/// 서버는 졌다"가 되므로, 계수가 어디에 곱해지는지를 고정해 둔다.
void main() {
  const species = Species(
    id: 'stag',
    name: LocalizedText(ko: '사슴벌레', en: 'Stag', ja: 'クワガタ'),
    grade: Grade.common,
    specialty: Specialty.strike,
    baseStats: Stats(hp: 100, atk: 40, def: 30, spd: 20),
    sizeMinMm: 30,
    sizeMaxMm: 70,
  );

  IndividualBug bug({
    BugTrait trait = BugTrait.none,
    PartLevels enhancement = PartLevels.zero,
  }) => IndividualBug(
    id: 'b',
    speciesId: species.id,
    // 중앙 사이즈 → 배율이 딱 중간이라 계산이 흔들리지 않는다.
    sizeMm: (species.sizeMinMm + species.sizeMaxMm) / 2,
    potential: 3,
    temperament: Temperament.steadfast,
    sex: Sex.male,
    element: Element.fire,
    trait: trait,
    enhancement: enhancement,
  );

  BattleBug build(IndividualBug b, {double atkBonus = 0, double hpBonus = 0}) =>
      buildBattleBug(
        bug: b,
        species: species,
        locale: 'ko',
        traitAtkBonus: atkBonus,
        traitHpBonus: hpBonus,
      );

  group('혈통 특성 → 전투 스탯 (§2.5)', () {
    test('보정 0 이면 기존 동작 그대로 — 특성을 전투에서 끌 수 있어야 한다', () {
      final plain = build(bug());
      final withTrait = build(bug(trait: BugTrait.fierce));
      expect(withTrait.atk, plain.atk);
      expect(withTrait.maxHp, plain.maxHp);
    });

    test('공격 보정은 atk 에만, 체력 보정은 maxHp 에만 실린다', () {
      final base = build(bug());
      final atkOnly = build(bug(trait: BugTrait.fierce), atkBonus: 0.35);
      final hpOnly = build(bug(trait: BugTrait.sturdy), hpBonus: 0.35);

      expect(atkOnly.atk, closeTo(base.atk * 1.35, 1e-9));
      expect(atkOnly.maxHp, closeTo(base.maxHp, 1e-9));
      expect(hpOnly.maxHp, closeTo(base.maxHp * 1.35, 1e-9));
      expect(hpOnly.atk, closeTo(base.atk, 1e-9));
      // 방어·속도는 특성 축이 아니다 — 건드리면 안 된다.
      expect(atkOnly.def, closeTo(base.def, 1e-9));
      expect(atkOnly.spd, closeTo(base.spd, 1e-9));
    });

    test('부위 강화와 **곱해진다** — 후반에도 세대를 쌓은 보람이 남아야 한다', () {
      // 강화가 이미 큰 상태에서 덧셈으로 붙이면 체감이 사라진다.
      final enhanced = bug(enhancement: const PartLevels(hornJaw: 25));
      final base = build(enhanced);
      final withTrait = build(enhanced, atkBonus: 0.35);
      expect(withTrait.atk, closeTo(base.atk * 1.35, 1e-9));
      // 강화 +100%(25레벨 × 4%) 위에 특성이 곱해진 값인지 확인.
      // ⚠️ 사이즈 배율은 중앙값이어도 1.0 이 아니다 — [min,max] 가
      // [0.85, 1.20] 으로 매핑되므로 중앙은 1.025 다(§2.1).
      final sm = enhanced.statMultiplier(species);
      expect(sm, closeTo((kStatMultiplierMin + kStatMultiplierMax) / 2, 1e-9));
      expect(base.atk, closeTo(40 * sm * 2.0, 1e-9));
    });

    test('오행·기질·선호 스탠스는 특성과 무관하게 그대로다', () {
      final b = build(bug(trait: BugTrait.noble), atkBonus: 0.3, hpBonus: 0.3);
      expect(b.element, Element.fire);
      expect(b.temperament, Temperament.steadfast);
      expect(b.preferredStance, Stance.attack); // strike → attack
    });
  });
}

import 'package:core_battle/core_battle.dart';
import 'package:core_models/core_models.dart';
import 'package:test/test.dart';

/// 결투 팀 역할 오라(1.0.21 D3, docs/design_growth_1021.md §3) — 엔진 쪽 순수 함수.
DuelBug _bug(String id, {DuelRole? role, double aura = 0}) => DuelBug(
  id: id,
  name: id,
  speciesId: 'x',
  element: Element.wood,
  temperament: Temperament.fickle,
  specialty: Specialty.strike,
  sizeMm: 60,
  maxHp: 1000,
  atk: 100,
  def: 50,
  spd: 80,
).withAura(role, aura);

void main() {
  test('역할마다 팀 전체에 더한다 — 공격형 → 공격 · 방어형 → 방어 · 체력형 → 최대 체력', () {
    final team = applyTeamAura([
      _bug('a', role: DuelRole.attack, aura: 0.06),
      _bug('d', role: DuelRole.defense, aura: 0.04),
      _bug('h', role: DuelRole.hp, aura: 0.02),
    ], capPerStat: 0.20);
    for (final b in team) {
      expect(b.atk, closeTo(106, 1e-9));
      expect(b.def, closeTo(52, 1e-9));
      expect(b.maxHp, closeTo(1020, 1e-9));
      expect(b.spd, 80, reason: '속도는 오라가 없다');
      expect(b.auraApplied, isTrue);
    }
  });

  test('같은 역할은 합치고 능력치마다 상한에서 자른다', () {
    final team = [
      _bug('a1', role: DuelRole.attack, aura: 0.10),
      _bug('a2', role: DuelRole.attack, aura: 0.09),
      _bug('a3', role: DuelRole.attack, aura: 0.08),
    ];
    expect(teamAuraTotals(team, capPerStat: 0.20), {DuelRole.attack: 0.20});
    final out = applyTeamAura(team, capPerStat: 0.20);
    expect(out.first.atk, closeTo(120, 1e-9));
    expect(out.first.def, 50);
    expect(out.first.maxHp, 1000);
  });

  test('역할 없는 곤충(대회·야생·옛 방어 행)은 아무것도 주지 않는다', () {
    final out = applyTeamAura([
      _bug('x'),
      _bug('y', aura: 0.5), // 역할이 없으면 크기도 버린다
    ], capPerStat: 0.20);
    expect(out.first.atk, 100);
    expect(out[1].aura, 0);
  });

  test('두 번 입히지 않는다 — 직렬화된 팀(제안·세션)을 다시 읽어도 그대로', () {
    final once = applyTeamAura([
      _bug('a', role: DuelRole.attack, aura: 0.06),
      _bug('h', role: DuelRole.hp, aura: 0.06),
    ], capPerStat: 0.20);
    final reloaded = [for (final b in once) DuelBug.fromJson(b.toJson())];
    expect(reloaded.first.auraApplied, isTrue);
    expect(reloaded.first.auraRole, DuelRole.attack);
    expect(reloaded.first.aura, closeTo(0.06, 1e-12));
    final twice = applyTeamAura(reloaded, capPerStat: 0.20);
    expect(twice.first.atk, closeTo(106, 1e-9));
    expect(twice.first.maxHp, closeTo(1060, 1e-9));
  });

  test('오라 필드는 훈련·전투 수치 복사에서도 유지된다', () {
    final b = _bug('a', role: DuelRole.defense, aura: 0.05)
        .withTraining(atkMult: 1.1)
        .copyWith(element: Element.fire)
        .withCombatStats(maxHp: 1, atk: 1, def: 1);
    expect(b.auraRole, DuelRole.defense);
    expect(b.aura, 0.05);
    // 오라 없는 곤충의 JSON 에는 키가 없다(옛 세션·대회 판과 같은 모양).
    expect(_bug('z').toJson().keys, isNot(contains('ar')));
  });
}

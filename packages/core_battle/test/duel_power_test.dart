import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:core_battle/core_battle.dart';
import 'package:core_models/core_models.dart';
import 'package:test/test.dart';

/// 실전 전투력(2026-10-10 사장님 확정) — 전투력 비 = 이길 확률 비.
/// 가중치는 `server/tool/duel_power_fit.dart` 가 맞춘다. 여기서는 **구조**를 지킨다.
DuelParams _real() {
  final b =
      jsonDecode(File('../app/assets/data/battle.json').readAsStringSync())
          as Map<String, dynamic>;
  return DuelParams.fromJson(b['duel'] as Map<String, dynamic>);
}

DuelBug _bug({
  double atk = 300,
  double hp = 2000,
  double def = 150,
  double evade = 0,
  double crit = 0,
  double recovery = 0,
  double mass = 1,
  double push = 1,
}) => DuelBug(
  id: 'x',
  name: 'x',
  speciesId: 'x',
  element: Element.wood,
  temperament: Temperament.fickle,
  specialty: Specialty.strike,
  sizeMm: 60,
  maxHp: hp,
  atk: atk,
  def: def,
  spd: 100,
  evade: evade,
  crit: crit,
  recovery: recovery,
  massMult: mass,
  pushMult: push,
);

void main() {
  final p = _real();

  test('battle.json 의 가중치 = 코드 기본값(데이터 없이 만든 설정도 같은 숫자)', () {
    expect(p.powerWeights, kDuelPowerWeights);
    expect(p.powerScale, kDuelPowerScale);
    expect(p.powerWeights.length, _bug().powerFeatures(p).length);
  });

  test('공격만이 아니라 방어·회피·치명·회복력·밀어내기·체급도 전투력을 올린다', () {
    final base = _bug().powerIn(p);
    for (final (name, b) in [
      ('공격', _bug(atk: 360)),
      ('체력', _bug(hp: 2400)),
      ('방어', _bug(def: 200)),
      ('회피', _bug(evade: 0.1)),
      ('치명', _bug(crit: 0.1)),
      ('회복력', _bug(recovery: 0.1)),
      ('밀어내기', _bug(push: 1.1)),
      ('체급', _bug(mass: 1.05)),
    ]) {
      expect(b.powerIn(p), greaterThan(base), reason: name);
    }
  });

  test('공격 몰빵이 균형 배분보다 높게 나오지 않는다(실기 지적의 모양)', () {
    // 같은 투자량을 공격에 몰아준 곤충 vs 공격·방어·체력에 나눈 곤충.
    final allAtk = _bug(atk: 300 * 1.6).powerIn(p);
    final balanced = _bug(
      atk: 300 * 1.2,
      def: 150 * 1.2,
      hp: 2000 * 1.2,
    ).powerIn(p);
    expect(balanced, greaterThan(allAtk));
  });

  test('전투력 비는 이길 확률 비다 — 공식이 곱 꼴이라 비가 능력치 배율로만 정해진다', () {
    final a = _bug(atk: 300).powerIn(p);
    final b = _bug(atk: 600).powerIn(p);
    expect(b / a, closeTo(math.pow(2, p.powerWeights[0]), 1e-9));
  });
}

import 'package:core_battle/core_battle.dart';
import 'package:core_models/core_models.dart';
import 'package:test/test.dart';

/// 왕중왕전 대진(2026-11-10).
void main() {
  DuelBug bug(int i, double s) => DuelBug(
    id: 'b$i',
    name: 'b$i',
    speciesId: 'stag_dorcus',
    element: Element.values[i % Element.values.length],
    temperament: Temperament.steadfast,
    specialty: Specialty.grip,
    sizeMm: 40,
    maxHp: 100 * s,
    atk: 30 * s,
    def: 30 * s,
    spd: 25 * s,
  );
  List<KotkEntrant> field(int n) => [
    for (var i = 0; i < n; i++)
      KotkEntrant(userId: 'u$i', bug: bug(i, 1 + i * 0.05), power: 100.0 + i),
  ];
  const params = DuelParams();

  test('대진 순서 — 1번과 2번 시드는 결승에서만 만난다', () {
    expect(kotkSeedOrder(4), [1, 4, 2, 3]);
    expect(kotkSeedOrder(8), [1, 8, 4, 5, 2, 7, 3, 6]);
  });

  test('같은 seed 면 같은 결과 · 순위 칸 수가 맞다', () {
    final a = runKotk(seed: 5, entrants: field(16), params: params);
    final b = runKotk(
      seed: 5,
      entrants: field(16).reversed.toList(),
      params: params,
    );
    expect(a.placement, b.placement);
    expect(a.placement.values.where((p) => p == 1).length, 1);
    expect(a.placement.values.where((p) => p == 2).length, 1);
    expect(a.placement.values.where((p) => p == 4).length, 2);
    expect(a.placement.values.where((p) => p == 16).length, 8);
    expect(a.losers.length, 15);
  });

  test('2의 거듭제곱이 아니면 높은 시드가 부전승 · 상위 32명까지만', () {
    final r = runKotk(seed: 1, entrants: field(5), params: params);
    expect(r.placement.length, 5);
    expect(r.rounds.first.where((m) => m.a < 0 || m.b < 0).length, 3);
    final big = runKotk(seed: 1, entrants: field(40), params: params);
    expect(big.entrants.length, 32);
    // 전투력이 가장 낮은 8명은 대진에 못 오른다(표본도 안 된다).
    expect(big.placement.containsKey('u0'), isFalse);
  });

  test('혼자면 대회가 없다 — 우승 처리만', () {
    final r = runKotk(seed: 1, entrants: field(1), params: params);
    expect(r.rounds, isEmpty);
    expect(r.losers, isEmpty);
  });
}

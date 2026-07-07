import 'dart:math';

/// 가중치 기반 결정론 추첨. 같은 [rng] 상태면 항상 같은 결과.
/// 전체 가중치가 0 이하이면 첫 항목을 반환한다(퇴화 방어).
T weightedPick<T>(Random rng, List<T> items, int Function(T) weightOf) {
  assert(items.isNotEmpty, 'weightedPick on empty list');
  var total = 0;
  for (final it in items) {
    total += weightOf(it);
  }
  if (total <= 0) return items.first;
  var r = rng.nextDouble() * total;
  for (final it in items) {
    r -= weightOf(it);
    if (r < 0) return it;
  }
  return items.last;
}

import 'package:core_save/core_save.dart';
import 'package:flutter/foundation.dart';

/// 새 곤충 발견 연출(2026-11-09 사장님 확정) — 수집 게임에서 가장 즐거워야 할 순간이 보이지 않았다.
///
/// 곤충은 효과음만 내고 알로 조용히 채집함에 들어와서, 새 종을 처음 만나도 아무 일도 일어나지 않았다.
/// 이제 도감에 **새 종**이 생기거나 그 종의 **첫 이색**이 생기면 홈에서 "새 곤충 발견!" 창을 띄운다.
///
/// - 판정은 저장 직전·직후 도감 비교([dexDiscoveries]) — `SaveController._commit` 한 곳이라
///   사냥·방치 정산·짝짓기·뽑기 어느 경로로 들어와도 빠지지 않는다(도감 갱신과 같은 원칙).
/// - 서버 세이브 채택(다른 기기에서 모은 것)은 연출하지 않는다 — 그건 새로 만난 게 아니다.
/// - 연출만 한다. 세이브·보상은 그대로다.
typedef Discovery = ({String speciesId, bool newSpecies, bool variant});

/// [before] → [after] 사이에 새로 생긴 발견. 새 종이면서 첫 이색이면 한 건으로 합친다.
List<Discovery> dexDiscoveries(
  Map<String, DexEntry> before,
  Map<String, DexEntry> after,
) => [
  for (final e in after.entries)
    if (!before.containsKey(e.key))
      (speciesId: e.key, newSpecies: true, variant: e.value.variantFound)
    else if (e.value.variantFound && !before[e.key]!.variantFound)
      (speciesId: e.key, newSpecies: false, variant: true),
];

/// 아직 보여 주지 않은 발견(기기 메모리 — 앱을 끄면 사라져도 된다, 도감에는 남는다).
class DiscoveryFeed {
  DiscoveryFeed._();
  static final DiscoveryFeed instance = DiscoveryFeed._();

  final ValueNotifier<List<Discovery>> pending = ValueNotifier(const []);

  void addAll(List<Discovery> found) {
    if (found.isEmpty) return;
    pending.value = [...pending.value, ...found];
  }

  /// 맨 앞 하나를 꺼낸다. 없으면 null.
  Discovery? take() {
    final list = pending.value;
    if (list.isEmpty) return null;
    pending.value = list.sublist(1);
    return list.first;
  }
}

/// 대회 회차 뱃지 id(`champion:1`) — 해석과 **대표 뱃지 고르기**.
///
/// 순수 모델에 두는 이유: 서버(대표 뱃지를 `profiles` 에 쓴다)와 앱(채팅에 방금
/// 쓴 글을 먼저 띄울 때 붙일 뱃지)이 **같은 규칙**으로 골라야 한다. 갈리면
/// 순위표와 채팅에서 같은 사람의 뱃지가 다르게 보인다.
///
/// id 형식은 `종류:회차번호`. 회차 번호가 붙는 이유 = 1회차 챔피언과 3회차
/// 챔피언은 다른 자랑거리다.
library;

/// 뱃지 id 를 (종류, 회차) 로 가른다. 형식이 아니면 null.
({String kind, int round})? parseEventBadge(String id) {
  if (id.isEmpty) return null;
  final i = id.indexOf(':');
  if (i <= 0) return null;
  final round = int.tryParse(id.substring(i + 1));
  if (round == null) return null;
  return (kind: id.substring(0, i), round: round);
}

/// 뱃지 종류의 급. 높을수록 대표로 먼저 뽑힌다.
///
/// 모르는 종류는 0 — 대표로 뽑지 않는다. 신버전 서버가 종류를 늘려도 구버전이
/// 그걸 챔피언보다 앞에 세우는 일이 없어야 한다.
int eventBadgeWeight(String kind) => switch (kind) {
  'champion' => 3,
  'finalist' => 2,
  'participant' => 1,
  _ => 0,
};

/// 가진 뱃지 중 **대표 하나**. 급이 높은 것 → 같은 급이면 최근 회차. 없으면 `''`.
///
/// 표시 칸은 하나다(`profiles.badge`). 나중 회차 뱃지로 그냥 덮어쓰면
/// 1회차 챔피언이 2회차에 한 판 참가하는 순간 `참가` 로 내려앉는다.
String bestEventBadge(Iterable<String> ids) {
  String best = '';
  var bestWeight = 0;
  var bestRound = 0;
  for (final id in ids) {
    final b = parseEventBadge(id);
    if (b == null) continue;
    final w = eventBadgeWeight(b.kind);
    if (w <= 0) continue;
    if (w > bestWeight || (w == bestWeight && b.round > bestRound)) {
      best = id;
      bestWeight = w;
      bestRound = b.round;
    }
  }
  return best;
}

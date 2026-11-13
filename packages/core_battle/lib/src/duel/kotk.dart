import 'package:meta/meta.dart';

import 'duel_bug.dart';
import 'duel_engine.dart';
import 'duel_params.dart';

/// 왕중왕전(2026-11-10 사장님 확정) — 주마다 참가한 곤충 1마리씩으로 치르는 **단판 토너먼트**.
///
/// 시드 = 전투력 순(동률은 유저 id), 상위 [maxSize] 명까지. 칸이 2의 거듭제곱보다 모자라면 높은 시드가 부전승.
/// 한 경기 = 결투 엔진 1:1 판을 [winsNeeded] 번 먼저 이기기(판마다 체력 가득, 던지기·반격은 자동).
/// 서버가 이 함수 하나로 대진·결과를 정한다 — 같은 [seed]·같은 참가 목록이면 늘 같은 결과(다시 계산해도 같다).
@immutable
class KotkEntrant {
  const KotkEntrant({
    required this.userId,
    required this.bug,
    required this.power,
  });

  final String userId;
  final DuelBug bug;
  final double power;
}

@immutable
class KotkMatch {
  const KotkMatch({
    required this.a,
    required this.b,
    required this.winner,
    this.winsA = 0,
    this.winsB = 0,
  });

  /// 참가자 순번([KotkResult.entrants]) — -1 = 부전승 자리.
  final int a;
  final int b;

  /// 이긴 쪽 순번.
  final int winner;
  final int winsA;
  final int winsB;

  Map<String, dynamic> toJson() => {
    'a': a,
    'b': b,
    'w': winner,
    'wa': winsA,
    'wb': winsB,
  };

  /// 저장해 둔 결과(서버 `kotk_results`)를 다시 읽는다.
  factory KotkMatch.fromJson(Map<String, dynamic> j) => KotkMatch(
    a: (j['a'] as num).toInt(),
    b: (j['b'] as num).toInt(),
    winner: (j['w'] as num).toInt(),
    winsA: (j['wa'] as num?)?.toInt() ?? 0,
    winsB: (j['wb'] as num?)?.toInt() ?? 0,
  );
}

@immutable
class KotkResult {
  const KotkResult({
    required this.entrants,
    required this.rounds,
    required this.placement,
  });

  /// 대진에 오른 참가자(시드 순 — 0 이 1번 시드).
  final List<KotkEntrant> entrants;

  /// 라운드별 경기(첫 라운드부터 결승까지).
  final List<List<KotkMatch>> rounds;

  /// 유저 id → 순위(1 우승 · 2 준우승 · 4 4강 · 8 8강 …). 대진에 못 오른 참가자는 없다.
  final Map<String, int> placement;

  /// 진 경기 수가 있는(= 표본이 되는) 유저 — 우승자만 빠진다.
  Iterable<String> get losers =>
      placement.entries.where((e) => e.value > 1).map((e) => e.key);
}

/// 대진 순서(1번 시드가 맨 위, 결승까지 강한 시드끼리 늦게 만나게) — 길이 [size](2의 거듭제곱).
List<int> kotkSeedOrder(int size) {
  var order = [1];
  while (order.length < size) {
    final n = order.length * 2;
    order = [
      for (final s in order) ...[s, n + 1 - s],
    ];
  }
  return order;
}

KotkResult runKotk({
  required int seed,
  required List<KotkEntrant> entrants,
  required DuelParams params,
  int maxSize = 32,
  int winsNeeded = 2,
}) {
  final sorted = [...entrants]
    ..sort((x, y) {
      final c = y.power.compareTo(x.power);
      return c != 0 ? c : x.userId.compareTo(y.userId);
    });
  final picked = sorted.take(maxSize).toList();
  if (picked.length < 2) {
    return KotkResult(
      entrants: picked,
      rounds: const [],
      placement: {for (final e in picked) e.userId: 1},
    );
  }
  var size = 1;
  while (size < picked.length) {
    size *= 2;
  }
  var alive = [
    for (final s in kotkSeedOrder(size)) s <= picked.length ? s - 1 : -1,
  ];
  final rounds = <List<KotkMatch>>[];
  final placement = <String, int>{};
  var r = 0;
  while (alive.length > 1) {
    final matches = <KotkMatch>[];
    final next = <int>[];
    for (var m = 0; m * 2 < alive.length; m++) {
      final a = alive[m * 2], b = alive[m * 2 + 1];
      if (a < 0 || b < 0) {
        final w = a < 0 ? b : a;
        matches.add(KotkMatch(a: a, b: b, winner: w));
        next.add(w);
        continue;
      }
      var wa = 0, wb = 0, bout = 0;
      while (wa < winsNeeded && wb < winsNeeded) {
        final out = simulateBout(
          seed: (seed * 31 + r * 1009 + m * 97 + bout) & 0x7fffffff,
          a: picked[a].bug,
          b: picked[b].bug,
          params: params,
        );
        if (out.winner == 0) {
          wa++;
        } else {
          wb++;
        }
        bout++;
      }
      final w = wa > wb ? a : b;
      final l = w == a ? b : a;
      placement[picked[l].userId] = alive.length;
      matches.add(KotkMatch(a: a, b: b, winner: w, winsA: wa, winsB: wb));
      next.add(w);
    }
    rounds.add(matches);
    alive = next;
    r++;
  }
  if (alive.first >= 0) placement[picked[alive.first].userId] = 1;
  return KotkResult(entrants: picked, rounds: rounds, placement: placement);
}

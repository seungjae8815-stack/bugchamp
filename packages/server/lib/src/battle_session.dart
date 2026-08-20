import 'dart:convert';

import 'package:core_battle/core_battle.dart';
import 'package:core_models/core_models.dart';

/// 수동 전투 1판의 서버 세션.
///
/// **시드를 클라이언트에 주지 않는다.** 시드를 알면 상대의 매 라운드 수를
/// 미리 계산해 최적해를 고를 수 있다(심리전이 무의미해진다).
/// 클라이언트는 세션 id 만 들고 있고, 서버가 라운드마다 결과를 알려준다.
///
/// Cloud Run 은 인스턴스가 바뀔 수 있으므로 상태를 메모리에 두면 안 된다.
/// DB 에 저장하고, 매 스텝마다 **처음부터 재생**해 현재 상태를 만든다
/// (최대 20라운드라 비용이 무시할 수준이다).
class BattleSession {
  BattleSession({
    required this.id,
    required this.userId,
    required this.seed,
    required this.myTeamBugIds,
    required this.foe,
    required this.location,
    required this.rewardMult,
    required this.stances,
    required this.finished,
    this.trophiesAtStart = 0,
    this.trophyPrepaid = 0,
  });

  final String id;
  final String userId;

  /// 🔴 클라이언트에 노출 금지.
  final int seed;

  final List<String> myTeamBugIds;
  final List<BattleBug> foe;
  final Element location;
  final double rewardMult;

  /// 지금까지 플레이어가 고른 수(라운드 순서).
  final List<Stance> stances;

  /// 보상까지 반영 완료됐는지 — 중복 수령 방지.
  final bool finished;

  /// 시작 시점의 트로피. 보상 계산 기준이다.
  ///
  /// 시작할 때 **패배분을 미리 깎기** 때문에(아래 [trophyPrepaid]) 결착 때
  /// 현재 값으로 계산하면 보상이 낮게 잡힌다. 시작 값을 그대로 들고 간다.
  final int trophiesAtStart;

  /// 시작할 때 이미 적용한 트로피 변동(패배분, 음수).
  ///
  /// ⚠️ 수동 전투는 결착까지 시간이 걸려서, 지고 있으면 앱을 강제 종료해
  /// **트로피를 지키는 치트**가 가능했다(2026-08-19 지적). 티켓만 날아가고
  /// 점수는 그대로였다. 그래서 시작할 때 **먼저 지고 들어간다** — 이기면
  /// 결착에서 그만큼 되돌려준다. 중간에 사라지면 패배가 그대로 남는다.
  /// (다음 판 시작 때 정산하는 방식은 안 된다 — 그 판을 마지막으로 다시는
  ///  안 들어오면 시즌 종료까지 점수가 지켜진다.)
  final int trophyPrepaid;

  BattleSession copyWith({List<Stance>? stances, bool? finished}) =>
      BattleSession(
        trophiesAtStart: trophiesAtStart,
        trophyPrepaid: trophyPrepaid,
        id: id,
        userId: userId,
        seed: seed,
        myTeamBugIds: myTeamBugIds,
        foe: foe,
        location: location,
        rewardMult: rewardMult,
        stances: stances ?? this.stances,
        finished: finished ?? this.finished,
      );

  Map<String, dynamic> toJson() => {
    'trophiesAtStart': trophiesAtStart,
    'trophyPrepaid': trophyPrepaid,
    'seed': seed,
    'myTeamBugIds': myTeamBugIds,
    'foe': [
      for (final b in foe)
        {
          'id': b.id,
          'name': b.name,
          'el': b.element.key,
          'tm': b.temperament.key,
          'ps': b.preferredStance.name,
          'hp': b.maxHp,
          'atk': b.atk,
          'def': b.def,
          'spd': b.spd,
        },
    ],
    'location': location.key,
    'rewardMult': rewardMult,
    'stances': [for (final s in stances) s.name],
    'finished': finished,
  };

  static BattleSession fromJson(
    String id,
    String userId,
    Map<String, dynamic> j,
  ) => BattleSession(
    id: id,
    userId: userId,
    seed: (j['seed'] as num).toInt(),
    myTeamBugIds: [
      for (final x in (j['myTeamBugIds'] as List? ?? const [])) x.toString(),
    ],
    foe: [
      for (final f in (j['foe'] as List? ?? const []))
        BattleBug(
          id: (f as Map)['id'].toString(),
          name: f['name'].toString(),
          element: Element.fromKey(f['el'].toString()),
          temperament: Temperament.fromKey(f['tm'].toString()),
          preferredStance: Stance.values.firstWhere(
            (s) => s.name == f['ps'].toString(),
            orElse: () => Stance.attack,
          ),
          maxHp: (f['hp'] as num).toDouble(),
          atk: (f['atk'] as num).toDouble(),
          def: (f['def'] as num).toDouble(),
          spd: (f['spd'] as num).toDouble(),
        ),
    ],
    location: Element.fromKey(j['location']?.toString() ?? 'wood'),
    rewardMult: (j['rewardMult'] as num?)?.toDouble() ?? 1.0,
    // 개편(2026-08-19) 전에 열린 세션은 선차감이 없다 — 0 이면 예전처럼 돈다.
    trophiesAtStart: (j['trophiesAtStart'] as num?)?.toInt() ?? 0,
    trophyPrepaid: (j['trophyPrepaid'] as num?)?.toInt() ?? 0,
    stances: [
      for (final s in (j['stances'] as List? ?? const []))
        Stance.values.firstWhere(
          (v) => v.name == s.toString(),
          orElse: () => Stance.attack,
        ),
    ],
    finished: j['finished'] == true,
  );

  String encode() => jsonEncode(toJson());
}

/// 세션의 수 목록을 처음부터 재생해 현재 전투 상태를 만든다.
///
/// 매번 재생하는 이유: `Random` 의 내부 상태를 직렬화할 수 없기 때문이다.
/// 시드 + 수 목록이면 결정론적으로 같은 상태가 나온다.
BattleState replay(
  BattleSession session,
  List<BattleBug> myTeam, {
  required double locationBonus,
}) {
  final st = initBattle(
    session.seed,
    myTeam,
    session.foe,
    location: session.location,
    locationBonus: locationBonus,
  );
  for (final s in session.stances) {
    if (st.done) break;
    st.step(playerAStance: s);
  }
  return st;
}

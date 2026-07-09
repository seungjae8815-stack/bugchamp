import 'dart:math';

import 'package:core_models/core_models.dart';

/// 라운드 행동(스탠스). 상성: 공격 > 회복 > 방어 > 공격.
enum Stance { attack, defend, heal }

bool _beats(Stance a, Stance b) => switch (a) {
  Stance.attack => b == Stance.heal,
  Stance.heal => b == Stance.defend,
  Stance.defend => b == Stance.attack,
};

/// 전투에 참여하는 **해석된** 개체(스탯이 이미 계산된 상태).
class BattleBug {
  const BattleBug({
    required this.id,
    required this.name,
    required this.element,
    required this.temperament,
    required this.preferredStance,
    required this.maxHp,
    required this.atk,
    required this.def,
    required this.spd,
  });

  final String id;
  final String name;
  final Element element; // 오행 상성
  final Temperament temperament; // 오토 스탠스 성향
  final Stance preferredStance; // 선호 스탠스(기존 주특기 매핑)
  final double maxHp;
  final double atk;
  final double def;
  final double spd;
}

enum BattleOutcome { teamA, teamB, draw }

/// 한 라운드 기록(UI 재생용).
class BattleEvent {
  const BattleEvent({
    required this.round,
    required this.aName,
    required this.bName,
    required this.aStance,
    required this.bStance,
    required this.rps,
    required this.dmgToA,
    required this.dmgToB,
    required this.healToA,
    required this.healToB,
    required this.aHp,
    required this.bHp,
    required this.aDown,
    required this.bDown,
  });

  final int round;
  final String aName;
  final String bName;
  final Stance aStance;
  final Stance bStance;

  /// -1 무승부(같은 스탠스), 0 A 스탠스 승, 1 B 스탠스 승.
  final int rps;
  final double dmgToA;
  final double dmgToB;
  final double healToA;
  final double healToB;

  /// 라운드 종료 후 현재 전투원 HP(0 이상).
  final double aHp;
  final double bHp;
  final bool aDown;
  final bool bDown;
}

class BattleResult {
  const BattleResult({
    required this.outcome,
    required this.events,
    required this.teamAHpPct,
    required this.teamBHpPct,
    required this.rounds,
  });

  final BattleOutcome outcome;
  final List<BattleEvent> events;
  final double teamAHpPct;
  final double teamBHpPct;
  final int rounds;
}

// ── 엔진 상수 ─────────────────────────────────────────────────
const int _startEnergy = 1;
const int _maxEnergy = 3;
const double _healPct = 0.12;
const double _synergyPerLink = 0.10; // 상생 연결당 팀 공격/회복 +10%
const double _restrainMult = 1.5; // 상극(克) 데미지 배율

/// 팀 배치의 상생(生) 연결 수 → 팀 배율(1 + links×0.10).
double teamSynergy(List<BattleBug> team) {
  var links = 0;
  for (var i = 0; i + 1 < team.length; i++) {
    if (team[i].element.generates(team[i + 1].element)) links++;
  }
  return 1 + links * _synergyPerLink;
}

/// 진행 가능한(step) 전투 상태. 오토=양쪽 AI, 수동=A 스탠스 주입.
class BattleState {
  BattleState._(this.teamA, this.teamB, this._rng)
    : hpA = [for (final u in teamA) u.maxHp],
      hpB = [for (final u in teamB) u.maxHp],
      enA = [for (final _ in teamA) _startEnergy],
      enB = [for (final _ in teamB) _startEnergy],
      synA = teamSynergy(teamA),
      synB = teamSynergy(teamB),
      _maxA = teamA.fold(0.0, (s, u) => s + u.maxHp),
      _maxB = teamB.fold(0.0, (s, u) => s + u.maxHp);

  final List<BattleBug> teamA;
  final List<BattleBug> teamB;
  final Random _rng;

  final List<double> hpA;
  final List<double> hpB;
  final List<int> enA;
  final List<int> enB;
  final double synA;
  final double synB;
  final double _maxA;
  final double _maxB;

  int a = 0;
  int b = 0;
  int round = 0;
  bool done = false;
  BattleOutcome outcome = BattleOutcome.draw;
  final List<BattleEvent> events = [];

  double get teamAHpPct =>
      _maxA <= 0 ? 0 : hpA.fold(0.0, (s, h) => s + h) / _maxA;
  double get teamBHpPct =>
      _maxB <= 0 ? 0 : hpB.fold(0.0, (s, h) => s + h) / _maxB;

  BattleBug? get fighterA => a < teamA.length ? teamA[a] : null;
  BattleBug? get fighterB => b < teamB.length ? teamB[b] : null;

  double _dmg(BattleBug att, BattleBug def, double mult, double syn) {
    var m = mult * syn;
    if (att.element.restrains(def.element)) m *= _restrainMult;
    return att.atk * m * (100.0 / (100.0 + def.def));
  }

  double _heal(BattleBug u, double mult, double syn) =>
      u.maxHp * _healPct * mult * syn;

  Stance _autoPick(BattleBug u, int energy) {
    final w = {Stance.attack: 1.0, Stance.defend: 1.0, Stance.heal: 1.0};
    switch (u.temperament) {
      case Temperament.aggressive:
        w[Stance.attack] = w[Stance.attack]! + 1.6;
      case Temperament.cautious:
        w[Stance.defend] = w[Stance.defend]! + 1.6;
      case Temperament.cunning:
        w[Stance.heal] = w[Stance.heal]! + 1.0;
        w[Stance.attack] = w[Stance.attack]! + 0.5;
      case Temperament.steadfast:
        w[u.preferredStance] = w[u.preferredStance]! + 1.6;
      case Temperament.fickle:
        break;
    }
    if (energy < 1) {
      w[Stance.defend] = 0;
      w[Stance.heal] = 0;
    }
    final total = w.values.fold(0.0, (s, c) => s + c);
    var r = _rng.nextDouble() * total;
    for (final s in Stance.values) {
      r -= w[s]!;
      if (r < 0) return s;
    }
    return Stance.attack;
  }

  Stance _enforceEnergy(Stance s, int energy) =>
      (energy < 1 && s != Stance.attack) ? Stance.attack : s;

  /// 한 라운드 진행. [playerAStance] 주면 A는 그 스탠스(수동), 없으면 오토.
  void step({Stance? playerAStance}) {
    if (done) return;
    final ua = fighterA;
    final ub = fighterB;
    if (ua == null || ub == null) {
      _finish();
      return;
    }
    round++;
    final sa = _enforceEnergy(playerAStance ?? _autoPick(ua, enA[a]), enA[a]);
    final sb = _autoPick(ub, enB[b]);

    var dmgA = 0.0, dmgB = 0.0, healA = 0.0, healB = 0.0;
    var deA = 0, deB = 0;
    var rps = _beats(sa, sb) ? 0 : (_beats(sb, sa) ? 1 : -1);

    double dA(double m) => _dmg(ua, ub, m, synA); // A가 B에게
    double dB(double m) => _dmg(ub, ua, m, synB); // B가 A에게
    double hA(double m) => _heal(ua, m, synA);
    double hB(double m) => _heal(ub, m, synB);

    if (sa == Stance.attack && sb == Stance.attack) {
      dmgB = dA(0.6);
      dmgA = dB(0.6);
      deA = 1;
      deB = 1;
    } else if (sa == Stance.attack && sb == Stance.defend) {
      dmgB = dA(0.2);
      dmgA = dB(0.35);
      deA = 1;
      deB = -1;
    } else if (sa == Stance.attack && sb == Stance.heal) {
      dmgB = dA(1.0);
      healB = hB(0.2);
      deA = 1;
      deB = -1;
    } else if (sa == Stance.defend && sb == Stance.attack) {
      dmgA = dB(0.2);
      dmgB = dA(0.35);
      deA = -1;
      deB = 1;
    } else if (sa == Stance.defend && sb == Stance.defend) {
      deA = -1;
      deB = -1;
    } else if (sa == Stance.defend && sb == Stance.heal) {
      healB = hB(1.0);
      deA = -1;
      deB = -1;
    } else if (sa == Stance.heal && sb == Stance.attack) {
      dmgA = dB(1.0);
      healA = hA(0.2);
      deA = -1;
      deB = 1;
    } else if (sa == Stance.heal && sb == Stance.defend) {
      healA = hA(1.0);
      deA = -1;
      deB = -1;
    } else {
      // heal / heal
      healA = hA(1.0);
      healB = hB(1.0);
      deA = -1;
      deB = -1;
    }

    hpA[a] = (hpA[a] - dmgA + healA).clamp(0.0, ua.maxHp);
    hpB[b] = (hpB[b] - dmgB + healB).clamp(0.0, ub.maxHp);
    enA[a] = (enA[a] + deA).clamp(0, _maxEnergy);
    enB[b] = (enB[b] + deB).clamp(0, _maxEnergy);

    final aDown = hpA[a] <= 0;
    final bDown = hpB[b] <= 0;

    events.add(
      BattleEvent(
        round: round,
        aName: ua.name,
        bName: ub.name,
        aStance: sa,
        bStance: sb,
        rps: rps,
        dmgToA: dmgA,
        dmgToB: dmgB,
        healToA: healA,
        healToB: healB,
        aHp: hpA[a],
        bHp: hpB[b],
        aDown: aDown,
        bDown: bDown,
      ),
    );

    if (aDown) a++;
    if (bDown) b++;

    if (round >= kMaxBattleRounds || a >= teamA.length || b >= teamB.length) {
      _finish();
    }
  }

  void _finish() {
    done = true;
    final aEx = a >= teamA.length;
    final bEx = b >= teamB.length;
    if (aEx && !bEx) {
      outcome = BattleOutcome.teamB;
    } else if (bEx && !aEx) {
      outcome = BattleOutcome.teamA;
    } else if (aEx && bEx) {
      outcome = BattleOutcome.draw;
    } else {
      final pa = teamAHpPct, pb = teamBHpPct;
      if (pa > pb) {
        outcome = BattleOutcome.teamA;
      } else if (pb > pa) {
        outcome = BattleOutcome.teamB;
      } else {
        final sa = teamA.fold(0.0, (s, u) => s + u.spd);
        final sb = teamB.fold(0.0, (s, u) => s + u.spd);
        outcome = sa > sb
            ? BattleOutcome.teamA
            : (sb > sa ? BattleOutcome.teamB : BattleOutcome.draw);
      }
    }
  }

  BattleResult toResult() => BattleResult(
    outcome: outcome,
    events: events,
    teamAHpPct: teamAHpPct,
    teamBHpPct: teamBHpPct,
    rounds: round,
  );
}

/// 수동/오토 공용 전투 상태 생성.
BattleState initBattle(
  int seed,
  List<BattleBug> teamA,
  List<BattleBug> teamB,
) => BattleState._(teamA, teamB, Random(seed));

/// 오토 전투(양쪽 AI). 같은 seed·팀 → 같은 결과 (§2.3, 결정론).
BattleResult simulate(int seed, List<BattleBug> teamA, List<BattleBug> teamB) {
  final st = initBattle(seed, teamA, teamB);
  var guard = 0;
  while (!st.done && guard < 200) {
    st.step();
    guard++;
  }
  return st.toResult();
}

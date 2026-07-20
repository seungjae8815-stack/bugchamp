import 'package:core_battle/core_battle.dart';

import '../../domain/game_server.dart';

/// 수동 전투 한 수의 결과. 로컬 엔진과 서버 세션이 **같은 모양**으로 돌려준다.
class ManualStep {
  const ManualStep({
    required this.event,
    required this.done,
    required this.round,
    required this.energyA,
  });

  final BattleEvent event;
  final bool done;
  final int round;

  /// 다음 수를 고를 때 내 파이터의 기력(0 이면 공격만 가능).
  final int energyA;
}

/// 결착 결과 — 보상까지 확정된 값.
class ManualFinish {
  const ManualFinish({
    required this.result,
    required this.gold,
    required this.trophyDelta,
    required this.rewardsApplied,
    this.save,
  });

  final BattleResult result;
  final int gold;
  final int trophyDelta;

  /// 보상이 **이미 반영됐는지**. 서버 모드는 서버가 세이브를 확정해 돌려주므로
  /// true — 화면이 또 지급하면 두 배가 된다.
  final bool rewardsApplied;

  /// 서버가 확정해 돌려준 세이브(서버 모드에서만). 화면이 이걸 채택한다.
  final Map<String, dynamic>? save;
}

/// 수동 전투를 한 수씩 진행시키는 주체.
///
/// 화면은 이 인터페이스만 알고, 전투가 로컬 엔진에서 도는지 서버 세션에서
/// 도는지 모른다.
abstract interface class ManualBattleDriver {
  int get round;
  bool get done;
  int get energyA;

  /// 한 수 진행. **null 이면 진행하지 못했다**(서버 불통 등) — 화면은
  /// 로컬로 대신 계산하지 않고 전투를 중단해야 한다.
  Future<ManualStep?> step(Stance s);

  /// 결착 후 결과·보상. null 이면 확정하지 못했다.
  Future<ManualFinish?> finish();
}

/// 로컬 엔진 드라이버 — 야생 상대 등 서버가 관여하지 않는 전투.
class LocalManualDriver implements ManualBattleDriver {
  LocalManualDriver(this._state);

  final BattleState _state;

  @override
  int get round => _state.round;

  @override
  bool get done => _state.done;

  @override
  int get energyA => _state.a < _state.enA.length ? _state.enA[_state.a] : 0;

  @override
  Future<ManualStep?> step(Stance s) async {
    _state.step(playerAStance: s);
    return ManualStep(
      event: _state.events.last,
      done: _state.done,
      round: _state.round,
      energyA: energyA,
    );
  }

  /// 로컬은 보상을 화면이 지급한다(`rewardsApplied: false`).
  /// 금액 계산은 화면이 `pvpReward` 로 한다 — 여기서는 결과만 넘긴다.
  @override
  Future<ManualFinish?> finish() async => ManualFinish(
    result: _state.toResult(),
    gold: 0,
    trophyDelta: 0,
    rewardsApplied: false,
  );
}

/// 서버 세션 드라이버 — **시드를 클라이언트가 모른다.**
///
/// 시드를 알면 상대의 매 라운드 수를 미리 계산해 최적해를 고를 수 있어
/// 심리전이 무의미해진다. 그래서 서버가 매 수마다 그 라운드 결과만 준다.
class ServerManualDriver implements ManualBattleDriver {
  ServerManualDriver({
    required this.server,
    required this.sessionId,
    required int startEnergy,
  }) : _energyA = startEnergy;

  final GameServer server;
  final String sessionId;

  final List<BattleEvent> _events = [];
  int _round = 0;
  bool _done = false;
  int _energyA;

  /// 결착 응답에 실려 온 값들 — `finish()` 가 다시 서버를 부르지 않도록 보관.
  BattleOutcome? _outcome;
  double _hpPctA = 0, _hpPctB = 0;
  int _gold = 0, _trophyDelta = 0;
  Map<String, dynamic>? _finalSave;

  /// 결착 시 서버가 확정해 돌려준 세이브(화면이 이걸 채택한다).
  Map<String, dynamic>? get finalSave => _finalSave;

  @override
  int get round => _round;

  @override
  bool get done => _done;

  @override
  int get energyA => _energyA;

  @override
  Future<ManualStep?> step(Stance s) async {
    final res = await server.stepManualBattle(
      sessionId: sessionId,
      stance: s.name,
    );
    if (!res.isOk || res.data == null) return null;
    final d = res.data!;

    final evJson = d['event'] as Map<String, dynamic>?;
    if (evJson == null) return null;
    final ev = _eventFromJson(evJson);
    _events.add(ev);

    _round = (d['round'] as num?)?.toInt() ?? _round;
    _done = d['done'] == true;
    _energyA = (d['energyA'] as num?)?.toInt() ?? 0;

    if (_done) {
      _outcome = BattleOutcome.values
          .where((o) => o.name == d['outcome']?.toString())
          .firstOrNull;
      _hpPctA = (d['teamAHpPct'] as num?)?.toDouble() ?? 0;
      _hpPctB = (d['teamBHpPct'] as num?)?.toDouble() ?? 0;
      _gold = (d['gold'] as num?)?.toInt() ?? 0;
      _trophyDelta = (d['trophyDelta'] as num?)?.toInt() ?? 0;
      _finalSave = res.save;
    }
    return ManualStep(event: ev, done: _done, round: _round, energyA: _energyA);
  }

  /// 서버가 결착 응답에서 승패·보상을 이미 확정했다.
  /// 확정값이 없으면 null — 화면은 로컬로 승패를 지어내지 않는다.
  @override
  Future<ManualFinish?> finish() async {
    final o = _outcome;
    if (o == null) return null;
    return ManualFinish(
      result: BattleResult(
        outcome: o,
        events: List.unmodifiable(_events),
        teamAHpPct: _hpPctA,
        teamBHpPct: _hpPctB,
        rounds: _round,
      ),
      gold: _gold,
      trophyDelta: _trophyDelta,
      rewardsApplied: true,
      save: _finalSave,
    );
  }

  static BattleEvent _eventFromJson(Map<String, dynamic> j) => BattleEvent(
    round: (j['round'] as num?)?.toInt() ?? 0,
    aName: j['aName']?.toString() ?? '',
    bName: j['bName']?.toString() ?? '',
    aStance: _stance(j['aStance']),
    bStance: _stance(j['bStance']),
    rps: (j['rps'] as num?)?.toInt() ?? -1,
    dmgToA: (j['dmgToA'] as num?)?.toDouble() ?? 0,
    dmgToB: (j['dmgToB'] as num?)?.toDouble() ?? 0,
    healToA: (j['healToA'] as num?)?.toDouble() ?? 0,
    healToB: (j['healToB'] as num?)?.toDouble() ?? 0,
    aHp: (j['aHp'] as num?)?.toDouble() ?? 0,
    bHp: (j['bHp'] as num?)?.toDouble() ?? 0,
    aDown: j['aDown'] == true,
    bDown: j['bDown'] == true,
  );

  static Stance _stance(Object? v) =>
      Stance.values.where((s) => s.name == v?.toString()).firstOrNull ??
      Stance.attack;
}

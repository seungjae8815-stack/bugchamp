import 'package:core_battle/core_battle.dart';
import 'package:core_run/core_run.dart';

import '../../domain/game_server.dart';

/// 결투 한 판의 결과 + 경기 진행 상황.
class DuelStep {
  const DuelStep({
    required this.bout,
    required this.winsA,
    required this.winsB,
    required this.done,
    this.save,
    this.gold = 0,
    this.trophyDelta = 0,
  });

  final DuelBout bout;
  final int winsA;
  final int winsB;

  /// 경기가 끝났나(한 팀이 모두 쓰러짐 — 승자 연속).
  final bool done;

  /// 서버가 확정한 세이브(끝났을 때만).
  final Map<String, dynamic>? save;
  final int gold;
  final int trophyDelta;

  bool get won => winsA > winsB;

  /// 내 곤충 위기에서 멈춘 판이면 그 자리 — 무대가 여기까지 재생하고 탭 게이지를 띄운다(훈련 v2 §4).
  DuelClutchPending? get clutch => bout.pending;
}

/// 판을 하나씩 받아 오는 진행기 — 화면은 이것만 안다(서버 세션 · 로컬 · 미리 받은 판).
abstract interface class DuelDriver {
  /// 다음 판을 [launch](던지기 게이지 0~1)로 던진다. 실패하면 null([error] 에 사유).
  Future<DuelStep?> next(double launch);

  /// 위기에서 멈춘 판([DuelStep.clutch])에 탭 점수(0~1)를 넣고 이어 간다 — 같은 판을 처음부터 다시 받는다
  /// (앞부분 궤적은 같다). [index] 는 멈춘 위기 번호. 실패하면 null.
  Future<DuelStep?> clutch(int index, double score);

  /// 판마다 게이지를 받나(빠른 결투는 false — 서버가 이미 다 정했다).
  bool get interactive;
  String? get error;
}

/// 서버 세션 — 판마다 `/duel/throw` 로 확정한다(시드는 서버만 안다).
class ServerDuelDriver implements DuelDriver {
  ServerDuelDriver({required this.server, required this.sessionId});

  final GameServer server;
  final String sessionId;
  @override
  String? error;

  @override
  bool get interactive => true;

  @override
  Future<DuelStep?> next(double launch) async =>
      _parse(await server.duelThrow(sessionId: sessionId, launch: launch));

  @override
  Future<DuelStep?> clutch(int index, double score) async => _parse(
    await server.duelClutch(sessionId: sessionId, index: index, score: score),
  );

  DuelStep? _parse(ServerResult res) {
    final d = res.data;
    if (!res.isOk || d == null || d['bout'] is! Map) {
      error = res.error ?? 'server';
      return null;
    }
    return DuelStep(
      bout: DuelBout.fromJson(Map<String, dynamic>.from(d['bout'] as Map)),
      winsA: (d['winsA'] as num?)?.toInt() ?? 0,
      winsB: (d['winsB'] as num?)?.toInt() ?? 0,
      done: d['done'] == true,
      save: res.save,
      gold: (d['gold'] as num?)?.toInt() ?? 0,
      trophyDelta: (d['trophyDelta'] as num?)?.toInt() ?? 0,
    );
  }
}

/// 빠른 결투 — 서버가 한 번에 준 판들을 순서대로 내놓는다.
class PrebakedDuelDriver implements DuelDriver {
  PrebakedDuelDriver({
    required this.bouts,
    this.save,
    this.gold = 0,
    this.trophyDelta = 0,
  });

  final List<DuelBout> bouts;
  final Map<String, dynamic>? save;
  final int gold;
  final int trophyDelta;
  int _i = 0;

  @override
  String? error;

  @override
  bool get interactive => false;

  /// 빠른 결투는 서버가 자동 점수로 끝까지 정했다 — 멈춘 판이 없다.
  @override
  Future<DuelStep?> clutch(int index, double score) async => null;

  @override
  Future<DuelStep?> next(double launch) async {
    if (_i >= bouts.length) return null;
    final b = bouts[_i++];
    final done = _i >= bouts.length;
    final upto = bouts.take(_i);
    return DuelStep(
      bout: b,
      winsA: upto.where((x) => x.winner == 0).length,
      winsB: upto.where((x) => x.winner == 1).length,
      done: done,
      save: done ? save : null,
      gold: done ? gold : 0,
      trophyDelta: done ? trophyDelta : 0,
    );
  }
}

/// 서버 없이(개발 실행) — 같은 엔진을 앱에서 돌린다. 보상은 끝날 때 호출자가 반영한다.
class LocalDuelDriver implements DuelDriver {
  LocalDuelDriver({
    required this.seed,
    required this.mine,
    required this.foe,
    required this.params,
    required this.battle,
    required this.trophies,
    required this.rewardMult,
  });

  final int seed;
  final List<DuelBug> mine;
  final List<DuelBug> foe;
  final DuelParams params;
  final BattleConfig battle;
  final int trophies;
  final double rewardMult;
  final List<DuelBout> _done = [];

  /// 위기에서 멈춘 판의 던지기 값·지금까지의 탭 점수(서버 세션과 같은 규칙).
  double? _pendingLaunch;
  final List<double> _scores = [];

  @override
  String? error;

  @override
  bool get interactive => true;

  @override
  Future<DuelStep?> next(double launch) async {
    _scores.clear();
    return _play(launch);
  }

  @override
  Future<DuelStep?> clutch(int index, double score) async {
    final l = _pendingLaunch;
    if (l == null || index != _scores.length) return null;
    _scores.add(score.clamp(0.0, 1.0));
    return _play(l);
  }

  DuelStep? _play(double launch) {
    final i = _done.length;
    // 승자 연속 — 대진·시작 체력은 지금까지의 판에서 나온다(서버와 같은 함수).
    final st = duelNextState(_done, mine, foe, params);
    if (st.ia >= mine.length || st.ib >= foe.length) return null;
    final b = simulateBout(
      seed: duelBoutSeed(seed, i),
      a: mine[st.ia],
      b: foe[st.ib],
      params: params,
      launchA: launch,
      hpA: st.hpA,
      hpB: st.hpB,
      clutchScores: List.of(_scores),
    );
    if (b.pending != null) {
      // 위기에서 멈췄다 — 판을 넘기지 않는다(점수를 받으면 같은 판을 처음부터 다시).
      _pendingLaunch = launch;
      final m = DuelMatch(bouts: _done);
      return DuelStep(bout: b, winsA: m.winsA, winsB: m.winsB, done: false);
    }
    _pendingLaunch = null;
    _done.add(b);
    final m = DuelMatch(bouts: _done);
    final done = m.winsA >= foe.length || m.winsB >= mine.length;
    final rw = done
        ? pvpReward(
            won: m.winsA > m.winsB,
            draw: false,
            trophies: trophies,
            cfg: battle,
            rewardMult: rewardMult,
          )
        : null;
    return DuelStep(
      bout: b,
      winsA: m.winsA,
      winsB: m.winsB,
      done: done,
      gold: rw?.gold ?? 0,
      trophyDelta: rw?.trophyDelta ?? 0,
    );
  }
}

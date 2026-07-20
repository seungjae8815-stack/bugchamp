import 'dart:math' as math;

import 'package:core_battle/core_battle.dart';
import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:flutter/material.dart' hide Element;
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../data/game_data.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/labels.dart';
import 'arena_widgets.dart';

/// 표시용 최대 기력(엔진 상수와 일치 — core_battle `_maxEnergy`).
const _maxEnergyDisplay = 3;

enum _Phase { input, resolving, done }

/// 수동 배틀 — 매 라운드 플레이어가 공/방/회를 직접 골라 `step()` 을 밟는 심리전.
/// 오토 아레나(`battle_arena.dart`)와 표시 위젯(`arena_widgets.dart`)을 공유한다.
class ManualBattleScreen extends StatefulWidget {
  const ManualBattleScreen({
    super.key,
    required this.data,
    required this.myTeam,
    required this.foeTeam,
    required this.speciesOf,
    required this.seed,
    required this.trophiesAtStart,
    required this.config,
    required this.onApply,
    required this.location,
    this.rewardMult = 1.0,
  });

  final GameData data;
  final List<BattleBug> myTeam;
  final List<BattleBug> foeTeam;
  final Map<String, String> speciesOf; // battleBug.id → speciesId
  final int seed;
  final int trophiesAtStart;
  final BattleConfig config;
  final double rewardMult;

  /// 전투 장소 오행(같은 오행 곤충 강화 + 배경).
  final Element location;
  final Future<void> Function(
    int gold,
    int trophyDelta,
    List<String> koedBugIds,
  )
  onApply;

  @override
  State<ManualBattleScreen> createState() => _ManualBattleScreenState();
}

class _ManualBattleScreenState extends State<ManualBattleScreen>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  late final BattleState _state;
  Duration _last = Duration.zero;

  _Phase _phase = _Phase.input;
  int _dispA = 0, _dispB = 0; // 표시용 파이터 인덱스
  late List<double> _hpA, _hpB;
  double _tgtA = 0, _tgtB = 0;

  double _accum = 0, _clashT = 0;
  int _lungeSide = 0;
  double _flashL = 0, _flashR = 0, _shake = 0;
  final List<FloatText> _floats = [];
  final List<BurstFx> _bursts = [];
  BattleEvent? _lastEvent;

  bool _resultPending = false;
  double _endWait = 0;

  @override
  void initState() {
    super.initState();
    _state = initBattle(
      widget.seed,
      widget.myTeam,
      widget.foeTeam,
      location: widget.location,
      locationBonus: widget.config.locationAffinityBonus,
    );
    _hpA = [for (final u in widget.myTeam) u.maxHp];
    _hpB = [for (final u in widget.foeTeam) u.maxHp];
    _ticker = createTicker(_tick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  /// 현재 내 파이터의 기력(입력 단계에서 버튼 활성 판정).
  int get _myEnergy => _state.a < _state.enA.length ? _state.enA[_state.a] : 0;

  void _choose(Stance s) {
    if (_phase != _Phase.input || _state.done) return;
    // 기력 부족 시 공격 외 선택 불가(엔진과 동일 규칙).
    if (_myEnergy < 1 && s != Stance.attack) return;
    HapticFeedback.selectionClick();
    _state.step(playerAStance: s);
    _enterResolve(_state.events.last);
  }

  void _enterResolve(BattleEvent ev) {
    _lastEvent = ev;
    _tgtA = ev.aHp;
    _tgtB = ev.bHp;
    _accum = 0;
    _clashT = 0;
    final dmgA = ev.dmgToA, dmgB = ev.dmgToB, hA = ev.healToA, hB = ev.healToB;
    _lungeSide = dmgB > dmgA + 0.5 ? -1 : (dmgA > dmgB + 0.5 ? 1 : 0);
    if (dmgA >= 1) {
      _floats.add(FloatText('-${dmgA.round()}', const Color(0xFFFF6B6B), true));
      _flashL = 1;
    }
    if (hA >= 1) {
      _floats.add(FloatText('+${hA.round()}', const Color(0xFF7CE38B), true));
    }
    if (dmgB >= 1) {
      _floats.add(
        FloatText('-${dmgB.round()}', const Color(0xFFFF6B6B), false),
      );
      _flashR = 1;
    }
    if (hB >= 1) {
      _floats.add(FloatText('+${hB.round()}', const Color(0xFF7CE38B), false));
    }
    final ua = widget.myTeam[_dispA], ub = widget.foeTeam[_dispB];
    final foeRestrained = dmgB >= 1 && ua.element.restrains(ub.element);
    final selfRestrained = dmgA >= 1 && ub.element.restrains(ua.element);
    if (foeRestrained) {
      _bursts.add(BurstFx(left: false, color: elementColor(ua.element)));
    }
    if (selfRestrained) {
      _bursts.add(BurstFx(left: true, color: elementColor(ub.element)));
    }
    if (foeRestrained || selfRestrained) {
      _shake = 1;
      HapticFeedback.mediumImpact();
    }
    setState(() => _phase = _Phase.resolving);
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t.clamp(0.0, 1.0);

  void _tick(Duration elapsed) {
    final raw = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    final dt = raw.clamp(0.0, 0.05);
    if (dt <= 0) return;
    setState(() {
      _flashL = math.max(0, _flashL - dt * 3);
      _flashR = math.max(0, _flashR - dt * 3);
      _shake = math.max(0, _shake - dt * 2.5);
      for (final f in _floats) {
        f.age += dt;
      }
      _floats.removeWhere((f) => f.age > FloatText.life);
      for (final b in _bursts) {
        b.age += dt;
      }
      _bursts.removeWhere((b) => b.age > BurstFx.life);

      if (_phase == _Phase.resolving) {
        _accum += dt;
        _clashT += dt;
        _hpA[_dispA] = _lerp(_hpA[_dispA], _tgtA, dt * 7);
        _hpB[_dispB] = _lerp(_hpB[_dispB], _tgtB, dt * 7);
        if (_accum >= kRoundDur) {
          _hpA[_dispA] = _tgtA;
          _hpB[_dispB] = _tgtB;
          final ev = _lastEvent!;
          if (ev.aDown) _dispA++;
          if (ev.bDown) _dispB++;
          _lungeSide = 0;
          _phase = _state.done ? _Phase.done : _Phase.input;
        }
      } else if (_phase == _Phase.done && !_resultPending) {
        _endWait += dt;
        if (_endWait > 0.4) {
          _resultPending = true;
          WidgetsBinding.instance.addPostFrameCallback((_) => _finish());
        }
      }
    });
  }

  Future<void> _finish() async {
    final r = _state.toResult();
    final rw = pvpReward(
      r.outcome,
      widget.trophiesAtStart,
      widget.config,
      rewardMult: widget.rewardMult,
    );
    final koed = koedTeamAIds(widget.myTeam, r.events);
    await widget.onApply(rw.gold, rw.trophyDelta, koed);
    if (!mounted) return;
    showBattleResultDialog(
      context,
      result: r,
      gold: rw.gold,
      trophyDelta: rw.trophyDelta,
      onClose: () {
        Navigator.pop(context); // 다이얼로그
        Navigator.pop(context); // 수동 배틀
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final resolving = _phase == _Phase.resolving;
    final reveal = _phase != _Phase.input; // 스탠스 공개(심리전 → 동시 공개)
    final ev = _lastEvent;
    final round = _phase == _Phase.input
        ? math.min(_state.round + 1, kMaxBattleRounds)
        : _state.round;
    final shakeDx = _shake > 0 ? math.sin(_shake * 40) * _shake * 6 : 0.0;
    final lunge = _lungeSide != 0
        ? math.sin((_clashT / kRoundDur).clamp(0.0, 1.0) * math.pi) * 26
        : 0.0;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: biomeColors(widget.location),
          ),
        ),
        child: Stack(
          children: [
            // 장소 배경 아트(없으면 그라데이션만).
            Positioned.fill(
              child: biomeBackground(
                widget.location,
                fallback: const SizedBox.shrink(),
              ),
            ),
            SafeArea(
              child: Transform.translate(
                offset: Offset(shakeDx, 0),
                child: Column(
                  children: [
                    // 상단: 라운드 + 닫기(포기)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Color(0xCCFFFFFF),
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0x88000000),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: const Color(0x55EBA52F),
                              ),
                            ),
                            child: Text(
                              'ROUND $round / $kMaxBattleRounds',
                              style: const TextStyle(
                                color: arenaHoney,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Container(
                            constraints: const BoxConstraints(minWidth: 48),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: elementColor(
                                widget.location,
                              ).withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${biomeEmoji(widget.location)} ${biomeName(l, widget.location)}',
                              style: TextStyle(
                                color: elementColor(widget.location),
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // 아레나
                    Expanded(
                      child: Stack(
                        children: [
                          // 장소 배경 워터마크(큰 이모지, 은은하게)
                          Center(
                            child: Opacity(
                              opacity: 0.07,
                              child: Text(
                                biomeEmoji(widget.location),
                                style: const TextStyle(fontSize: 200),
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: _dispA < widget.myTeam.length
                                    ? ArenaFighter(
                                        data: widget.data,
                                        bug: widget.myTeam[_dispA],
                                        speciesId:
                                            widget.speciesOf[widget
                                                .myTeam[_dispA]
                                                .id],
                                        hpFrac:
                                            (_hpA[_dispA] /
                                                    widget.myTeam[_dispA].maxHp)
                                                .clamp(0.0, 1.0),
                                        flip: false,
                                        stance: reveal ? ev?.aStance : null,
                                        flash: _flashL,
                                        dx: _lungeSide == -1 ? lunge : 0.0,
                                      )
                                    : const SizedBox.shrink(),
                              ),
                              Expanded(
                                child: _dispB < widget.foeTeam.length
                                    ? ArenaFighter(
                                        data: widget.data,
                                        bug: widget.foeTeam[_dispB],
                                        speciesId:
                                            widget.speciesOf[widget
                                                .foeTeam[_dispB]
                                                .id],
                                        hpFrac:
                                            (_hpB[_dispB] /
                                                    widget
                                                        .foeTeam[_dispB]
                                                        .maxHp)
                                                .clamp(0.0, 1.0),
                                        flip: true,
                                        stance: reveal ? ev?.bStance : null,
                                        stanceHidden: !reveal,
                                        flash: _flashR,
                                        dx: _lungeSide == 1 ? -lunge : 0.0,
                                      )
                                    : const SizedBox.shrink(),
                              ),
                            ],
                          ),
                          // 라운드 판정 배너(심리전 결과)
                          if (resolving && ev != null)
                            Align(
                              alignment: const Alignment(0, -0.55),
                              child: _clashBanner(l, ev.rps),
                            ),
                          // 오행 克 버스트
                          for (final b in _bursts) ArenaBurst(fx: b),
                          // 데미지/회복 숫자
                          for (final f in _floats) ArenaFloat(f: f),
                        ],
                      ),
                    ),
                    // 하단: 기력 + 공/방/회 버튼
                    _controls(l),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _clashBanner(AppLocalizations l, int rps) {
    // rps: 0 A 우세, 1 A 열세, -1 무승부(같은 스탠스).
    final (text, color) = switch (rps) {
      0 => (l.battleClashWin, const Color(0xFF7CE38B)),
      1 => (l.battleClashLose, const Color(0xFFFF8A6B)),
      _ => (l.battleClashEven, const Color(0xFFBFC4CC)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xCC000000),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 15,
        ),
      ),
    );
  }

  Widget _controls(AppLocalizations l) {
    final canAct = _phase == _Phase.input && !_state.done;
    final energy = _myEnergy;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 기력 표시 + 안내
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${l.battleEnergy}  ',
                style: const TextStyle(
                  color: Color(0xB3FFFFFF),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              for (var i = 0; i < _maxEnergyDisplay; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Icon(
                    i < energy ? Icons.bolt : Icons.bolt_outlined,
                    size: 16,
                    color: i < energy
                        ? const Color(0xFFEBD24A)
                        : const Color(0x55FFFFFF),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            canAct ? l.battleYourMove : '',
            style: const TextStyle(
              color: arenaHoney,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          _stanceWheel(l, canAct, energy),
        ],
      ),
    );
  }

  /// 공/방/회 상성(공>회>방>공)을 원형으로 표현한 스탠스 휠.
  /// 공격 12시 · 회복 4시 · 방어 8시 → 시계방향 화살표가 "이김" 방향.
  /// 폭에 맞춰 크게 그리고, 노드 중심이 링 위에 정확히 오도록 좌표 계산.
  Widget _stanceWheel(AppLocalizations l, bool canAct, int energy) {
    return LayoutBuilder(
      builder: (ctx, cons) {
        final s = math.min(cons.maxWidth, 320.0);
        final node = s * 0.27; // 노드 지름(폭 비례)
        final r = s / 2 - node / 2 - 2; // 노드 중심이 지나는 링 반지름
        final center = Offset(s / 2, s / 2);
        Widget at(double deg, Widget child) {
          final a = deg * math.pi / 180;
          final p = center + Offset(math.cos(a), math.sin(a)) * r;
          return Positioned(
            left: p.dx - node / 2,
            top: p.dy - node / 2,
            width: node,
            child: child,
          );
        }

        return SizedBox(
          width: s,
          height: s + 26, // 하단 노드 라벨 여유
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                top: 0,
                width: s,
                height: s,
                child: CustomPaint(painter: _StanceRingPainter(r)),
              ),
              Positioned(
                left: 0,
                top: s / 2 - 9,
                width: s,
                child: const Text(
                  '공 › 회 › 방 › 공',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0x66FFFFFF),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              at(-90, _wheelNode(l, Stance.attack, canAct, true, node)),
              at(30, _wheelNode(l, Stance.heal, canAct, energy >= 1, node)),
              at(150, _wheelNode(l, Stance.defend, canAct, energy >= 1, node)),
            ],
          ),
        );
      },
    );
  }

  Widget _wheelNode(
    AppLocalizations l,
    Stance s,
    bool phaseActive,
    bool affordable,
    double size,
  ) {
    final enabled = phaseActive && affordable;
    final base = stanceColor(s);
    final cost = s == Stance.attack ? '+1' : '−1';
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: GestureDetector(
        onTap: enabled ? () => _choose(s) : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: base,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white24, width: 2.5),
                boxShadow: enabled
                    ? [
                        BoxShadow(
                          color: base.withValues(alpha: 0.55),
                          blurRadius: 16,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                stanceIcon(s),
                size: size * 0.44,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              stanceLabel(l, s),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              '⚡$cost',
              style: const TextStyle(
                color: Color(0xCCFFFFFF),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 스탠스 휠 링 + 시계방향 화살표(공>회>방>공 상성 흐름).
class _StanceRingPainter extends CustomPainter {
  const _StanceRingPainter(this.radius);

  /// 노드 중심이 지나는 링 반지름(휠 위젯과 동일 좌표계).
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = radius;
    if (r <= 0) return;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = const Color(0x2EFFFFFF);
    canvas.drawCircle(c, r, ring);
    // 노드 12시(-90°)·4시(30°)·8시(150°) 사이 호 중점에 시계방향 화살촉.
    final arrow = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0x66FFFFFF);
    for (final deg in const [-30.0, 90.0, 210.0]) {
      final a = deg * math.pi / 180;
      final p = c + Offset(math.cos(a), math.sin(a)) * r;
      final t = a + math.pi / 2; // 시계방향 접선
      _head(canvas, p, Offset(math.cos(t), math.sin(t)), arrow);
    }
  }

  void _head(Canvas canvas, Offset p, Offset dir, Paint paint) {
    const s = 10.0;
    final perp = Offset(-dir.dy, dir.dx);
    final tip = p + dir * s;
    final b1 = p - dir * s + perp * (s * 0.7);
    final b2 = p - dir * s - perp * (s * 0.7);
    canvas.drawPath(
      Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(b1.dx, b1.dy)
        ..lineTo(b2.dx, b2.dy)
        ..close(),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _StanceRingPainter oldDelegate) =>
      oldDelegate.radius != radius;
}

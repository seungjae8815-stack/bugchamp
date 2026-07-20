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
import '../../ui/skins.dart';
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
    this.skinOf = noSkin,
    this.arenaTheme = false,
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

  /// 내 곤충의 종 id → 구매한 스킨 색 필터. 상대에는 적용하지 않는다.
  final SkinOf skinOf;

  /// 아레나 테마 스킨 보유 여부(배경 색보정).
  final bool arenaTheme;
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

  /// 이번 수를 고를 남은 시간(초). 0 이하가 되면 공격이 자동 선택된다.
  /// config 가 0 이하면 무제한(카운터 미표시).
  late double _turnLeft = widget.config.manualTurnSeconds.toDouble();
  bool get _timed => widget.config.manualTurnSeconds > 0;

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
          // 다음 입력 턴 제한시간 리셋.
          _turnLeft = widget.config.manualTurnSeconds.toDouble();
        }
      } else if (_phase == _Phase.input && _timed) {
        // 제한시간 소진 → 공격 자동 선택(기력 없어도 항상 가능한 수).
        _turnLeft -= dt;
        if (_turnLeft <= 0) {
          _turnLeft = 0;
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _choose(Stance.attack),
          );
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
      won: r.outcome == BattleOutcome.teamA,
      draw: r.outcome == BattleOutcome.draw,
      trophies: widget.trophiesAtStart,
      cfg: widget.config,
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
      body: SafeArea(
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
                        border: Border.all(color: const Color(0x55EBA52F)),
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
                    // 전투 씬 배경 — 이 영역(상단)에만 깐다.
                    Positioned.fill(
                      child: withSkin(
                        biomeBackground(
                          widget.location,
                          fallback: const SizedBox.shrink(),
                        ),
                        // 아레나 테마 스킨 보유 시 배경 색보정.
                        widget.arenaTheme ? arenaThemeFilter : null,
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: _dispA < widget.myTeam.length
                              ? ArenaFighter(
                                  data: widget.data,
                                  bug: widget.myTeam[_dispA],
                                  speciesId: widget
                                      .speciesOf[widget.myTeam[_dispA].id],
                                  hpFrac:
                                      (_hpA[_dispA] /
                                              widget.myTeam[_dispA].maxHp)
                                          .clamp(0.0, 1.0),
                                  flip: false,
                                  stance: reveal ? ev?.aStance : null,
                                  flash: _flashL,
                                  dx: _lungeSide == -1 ? lunge : 0.0,
                                  skin: widget.skinOf(
                                    widget.speciesOf[widget
                                            .myTeam[_dispA]
                                            .id] ??
                                        '',
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                        Expanded(
                          child: _dispB < widget.foeTeam.length
                              ? ArenaFighter(
                                  data: widget.data,
                                  bug: widget.foeTeam[_dispB],
                                  speciesId: widget
                                      .speciesOf[widget.foeTeam[_dispB].id],
                                  hpFrac:
                                      (_hpB[_dispB] /
                                              widget.foeTeam[_dispB].maxHp)
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
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
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
          // 내 차례 + 남은 제한시간(3초 이하면 붉게 경고).
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                canAct ? l.battleYourMove : '',
                style: const TextStyle(
                  color: arenaHoney,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (canAct && _timed) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.timer_outlined,
                  size: 14,
                  color: _turnLeft <= 3
                      ? const Color(0xFFFF6B6B)
                      : const Color(0x99FFFFFF),
                ),
                const SizedBox(width: 3),
                Text(
                  '${_turnLeft.ceil()}',
                  style: TextStyle(
                    color: _turnLeft <= 3
                        ? const Color(0xFFFF6B6B)
                        : const Color(0xCCFFFFFF),
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ],
          ),
          if (canAct && _timed) ...[
            const SizedBox(height: 5),
            // 남은 시간 게이지
            SizedBox(
              width: 160,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: (_turnLeft / widget.config.manualTurnSeconds).clamp(
                    0.0,
                    1.0,
                  ),
                  minHeight: 5,
                  backgroundColor: const Color(0x33000000),
                  valueColor: AlwaysStoppedAnimation(
                    _turnLeft <= 3
                        ? const Color(0xFFFF6B6B)
                        : const Color(0xFFEBA52F),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 6),
          StanceWheel(energy: energy, enabled: canAct, onPick: _choose),
        ],
      ),
    );
  }
}

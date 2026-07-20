import 'dart:math' as math;

import 'package:core_battle/core_battle.dart';
import 'package:core_models/core_models.dart' show Element;
import 'package:flutter/material.dart' hide Element;
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../data/game_data.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/labels.dart';
import 'arena_widgets.dart';

/// 전투 아레나 — `BattleResult`의 라운드 이벤트를 절차적 모션으로 재생(오토).
class BattleArenaScreen extends StatefulWidget {
  const BattleArenaScreen({
    super.key,
    required this.data,
    required this.myTeam,
    required this.foeTeam,
    required this.speciesOf,
    required this.result,
    required this.gold,
    required this.trophyDelta,
    required this.location,
  });

  final GameData data;
  final List<BattleBug> myTeam;
  final List<BattleBug> foeTeam;
  final Map<String, String> speciesOf; // battleBug.id → speciesId
  final BattleResult result;
  final int gold;
  final int trophyDelta;

  /// 전투 장소 오행(배경 톤).
  final Element location;

  @override
  State<BattleArenaScreen> createState() => _BattleArenaScreenState();
}

class _BattleArenaScreenState extends State<BattleArenaScreen>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  double _speed = 1;

  int _ei = 0; // 현재 이벤트
  double _accum = 0; // 라운드 진행 시간
  double _clashT = 0;
  int _a = 0, _b = 0;
  late List<double> _hpA, _hpB;
  double _tgtA = 0, _tgtB = 0;
  final List<FloatText> _floats = [];
  final List<BurstFx> _bursts = [];
  int _lungeSide = 0; // -1 왼쪽(내팀) 공격, 1 오른쪽(상대) 공격
  double _flashL = 0, _flashR = 0, _shake = 0;
  bool _finished = false;
  bool _resultShown = false;
  double _endWait = 0;

  List<BattleEvent> get _events => widget.result.events;

  @override
  void initState() {
    super.initState();
    _hpA = [for (final u in widget.myTeam) u.maxHp];
    _hpB = [for (final u in widget.foeTeam) u.maxHp];
    if (_events.isEmpty) {
      _finished = true;
    } else {
      _enterEvent(0);
    }
    _ticker = createTicker(_tick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _enterEvent(int idx) {
    final ev = _events[idx];
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
    final ua = widget.myTeam[_a], ub = widget.foeTeam[_b];
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
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t.clamp(0.0, 1.0);

  void _tick(Duration elapsed) {
    final raw = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    var dt = raw.clamp(0.0, 0.05) * _speed;
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

      if (!_finished) {
        _accum += dt;
        _clashT += dt;
        _hpA[_a] = _lerp(_hpA[_a], _tgtA, dt * 7);
        _hpB[_b] = _lerp(_hpB[_b], _tgtB, dt * 7);
        if (_accum >= kRoundDur) {
          _hpA[_a] = _tgtA;
          _hpB[_b] = _tgtB;
          final ev = _events[_ei];
          if (ev.aDown) _a++;
          if (ev.bDown) _b++;
          _ei++;
          if (_ei >= _events.length) {
            _finished = true;
          } else {
            _enterEvent(_ei);
          }
        }
      } else if (!_resultShown) {
        _endWait += dt;
        if (_endWait > 0.5) {
          _resultShown = true;
          WidgetsBinding.instance.addPostFrameCallback((_) => _showResult());
        }
      }
    });
  }

  void _skipToEnd() {
    setState(() {
      _finished = true;
      _floats.clear();
      _bursts.clear();
    });
    if (!_resultShown) {
      _resultShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _showResult());
    }
  }

  void _showResult() {
    if (!mounted) return;
    showBattleResultDialog(
      context,
      result: widget.result,
      gold: widget.gold,
      trophyDelta: widget.trophyDelta,
      onClose: () {
        Navigator.pop(context); // 다이얼로그
        Navigator.pop(context); // 아레나
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final ev = _ei < _events.length ? _events[_ei] : null;
    final round = ev?.round ?? widget.result.rounds;
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
                    // 상단: 라운드 + 닫기
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: _skipToEnd,
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
                              'ROUND $round / ${widget.result.rounds}',
                              style: const TextStyle(
                                color: arenaHoney,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const Spacer(),
                          const SizedBox(width: 48),
                        ],
                      ),
                    ),
                    // 아레나
                    Expanded(
                      child: Stack(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _a < widget.myTeam.length
                                    ? ArenaFighter(
                                        data: widget.data,
                                        bug: widget.myTeam[_a],
                                        speciesId: widget
                                            .speciesOf[widget.myTeam[_a].id],
                                        hpFrac:
                                            (_hpA[_a] / widget.myTeam[_a].maxHp)
                                                .clamp(0.0, 1.0),
                                        flip: false,
                                        stance: ev?.aStance,
                                        flash: _flashL,
                                        dx: _lungeSide == -1 ? lunge : 0.0,
                                      )
                                    : const SizedBox.shrink(),
                              ),
                              Expanded(
                                child: _b < widget.foeTeam.length
                                    ? ArenaFighter(
                                        data: widget.data,
                                        bug: widget.foeTeam[_b],
                                        speciesId: widget
                                            .speciesOf[widget.foeTeam[_b].id],
                                        hpFrac:
                                            (_hpB[_b] /
                                                    widget.foeTeam[_b].maxHp)
                                                .clamp(0.0, 1.0),
                                        flip: true,
                                        stance: ev?.bStance,
                                        flash: _flashR,
                                        dx: _lungeSide == 1 ? -lunge : 0.0,
                                      )
                                    : const SizedBox.shrink(),
                              ),
                            ],
                          ),
                          // 오행 克 버스트
                          for (final b in _bursts) ArenaBurst(fx: b),
                          // 데미지/회복 숫자
                          for (final f in _floats) ArenaFloat(f: f),
                        ],
                      ),
                    ),
                    // 하단: 속도 컨트롤
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _ctrlBtn(
                            _speed >= 2 ? '2x' : '1x',
                            Icons.fast_forward_rounded,
                            () => setState(() => _speed = _speed >= 2 ? 1 : 2),
                          ),
                          const SizedBox(width: 12),
                          _ctrlBtn(
                            l.battleSkip,
                            Icons.skip_next_rounded,
                            _skipToEnd,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ctrlBtn(String label, IconData icon, VoidCallback onTap) =>
      FilledButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF2E4D2E),
          foregroundColor: Colors.white,
        ),
      );
}

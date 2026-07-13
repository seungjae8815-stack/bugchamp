import 'dart:math' as math;

import 'package:core_battle/core_battle.dart';
import 'package:core_models/core_models.dart';
import 'package:flutter/material.dart' hide Element;
import 'package:flutter/scheduler.dart';

import '../../data/game_data.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/art.dart';
import '../../ui/format.dart';
import '../../ui/game_dialog.dart';
import '../../ui/labels.dart';

const _honey = Color(0xFFEBA52F);
const _roundDur = 0.85; // 라운드 1회 재생 시간(초, 1x)

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
  });

  final GameData data;
  final List<BattleBug> myTeam;
  final List<BattleBug> foeTeam;
  final Map<String, String> speciesOf; // battleBug.id → speciesId
  final BattleResult result;
  final int gold;
  final int trophyDelta;

  @override
  State<BattleArenaScreen> createState() => _BattleArenaScreenState();
}

class _Float {
  _Float(this.text, this.color, this.left);
  final String text;
  final Color color;
  final bool left;
  double age = 0;
  static const life = 0.9;
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
  final List<_Float> _floats = [];
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
      _floats.add(_Float('-${dmgA.round()}', const Color(0xFFFF6B6B), true));
      _flashL = 1;
    }
    if (hA >= 1) {
      _floats.add(_Float('+${hA.round()}', const Color(0xFF7CE38B), true));
    }
    if (dmgB >= 1) {
      _floats.add(_Float('-${dmgB.round()}', const Color(0xFFFF6B6B), false));
      _flashR = 1;
    }
    if (hB >= 1) {
      _floats.add(_Float('+${hB.round()}', const Color(0xFF7CE38B), false));
    }
    final ua = widget.myTeam[_a], ub = widget.foeTeam[_b];
    final crit =
        (dmgB >= 1 && ua.element.restrains(ub.element)) ||
        (dmgA >= 1 && ub.element.restrains(ua.element));
    if (crit) _shake = 1;
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
      _floats.removeWhere((f) => f.age > _Float.life);

      if (!_finished) {
        _accum += dt;
        _clashT += dt;
        _hpA[_a] = _lerp(_hpA[_a], _tgtA, dt * 7);
        _hpB[_b] = _lerp(_hpB[_b], _tgtB, dt * 7);
        if (_accum >= _roundDur) {
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
    });
    if (!_resultShown) {
      _resultShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _showResult());
    }
  }

  void _showResult() {
    if (!mounted) return;
    final l = AppLocalizations.of(context);
    final r = widget.result;
    final win = r.outcome == BattleOutcome.teamA;
    final draw = r.outcome == BattleOutcome.draw;
    final title = win ? l.battleWin : (draw ? l.battleDraw : l.battleLose);
    final color = win
        ? const Color(0xFF6FCF6F)
        : (draw ? const Color(0xFFBFC4CC) : const Color(0xFFEF9A9A));
    showGameDialog<void>(
      context,
      title: title,
      icon: win ? Icons.emoji_events_rounded : Icons.sports_mma_rounded,
      barrierDismissible: false,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _teamHpBar(l.battleMyTeam, r.teamAHpPct, const Color(0xFF6FC96F)),
          const SizedBox(height: 6),
          _teamHpBar(l.battleFoe, r.teamBHpPct, const Color(0xFFC85454)),
          const SizedBox(height: 12),
          Text(
            l.battleReward,
            style: const TextStyle(
              color: _honey,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '💰 ${formatCompact(widget.gold)}    '
            '🏆 ${widget.trophyDelta >= 0 ? '+' : ''}${widget.trophyDelta}',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
        ],
      ),
      actions: [
        gameDialogButton(l.actionClose, () {
          Navigator.pop(context); // 다이얼로그
          Navigator.pop(context); // 아레나
        }),
      ],
    );
  }

  Widget _teamHpBar(String label, double pct, Color color) => Row(
    children: [
      SizedBox(
        width: 64,
        child: Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 11.5),
        ),
      ),
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: LinearProgressIndicator(
            value: pct.clamp(0.0, 1.0),
            minHeight: 10,
            backgroundColor: const Color(0x33000000),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ),
      const SizedBox(width: 6),
      SizedBox(
        width: 38,
        child: Text(
          '${(pct * 100).round()}%',
          textAlign: TextAlign.right,
          style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 11),
        ),
      ),
    ],
  );

  String _stanceGlyph(Stance s) => switch (s) {
    Stance.attack => '⚔️',
    Stance.defend => '🛡️',
    Stance.heal => '💚',
  };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final ev = _ei < _events.length ? _events[_ei] : null;
    final round = ev?.round ?? widget.result.rounds;
    final shakeDx = _shake > 0 ? math.sin(_shake * 40) * _shake * 6 : 0.0;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF16240E), Color(0xFF0A1206)],
          ),
        ),
        child: SafeArea(
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
                          border: Border.all(color: const Color(0x55EBA52F)),
                        ),
                        child: Text(
                          'ROUND $round / ${widget.result.rounds}',
                          style: const TextStyle(
                            color: _honey,
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
                            child: _fighter(
                              team: widget.myTeam,
                              hp: _hpA,
                              idx: _a,
                              flip: false,
                              stance: ev?.aStance,
                              flash: _flashL,
                              lunge: _lungeSide == -1,
                              toRight: true,
                            ),
                          ),
                          Expanded(
                            child: _fighter(
                              team: widget.foeTeam,
                              hp: _hpB,
                              idx: _b,
                              flip: true,
                              stance: ev?.bStance,
                              flash: _flashR,
                              lunge: _lungeSide == 1,
                              toRight: false,
                            ),
                          ),
                        ],
                      ),
                      // 데미지/회복 숫자
                      for (final f in _floats) _floatWidget(f),
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

  Widget _fighter({
    required List<BattleBug> team,
    required List<double> hp,
    required int idx,
    required bool flip,
    required Stance? stance,
    required double flash,
    required bool lunge,
    required bool toRight,
  }) {
    if (idx >= team.length) return const SizedBox.shrink();
    final u = team[idx];
    final sp = widget.data.speciesById[widget.speciesOf[u.id] ?? ''];
    final hpFrac = (hp[idx] / u.maxHp).clamp(0.0, 1.0);
    // 돌진: 라운드 중반 sin 곡선.
    final lungeAmt = lunge
        ? math.sin((_clashT / _roundDur).clamp(0.0, 1.0) * math.pi) * 26
        : 0.0;
    final dx = (toRight ? lungeAmt : -lungeAmt);

    Widget img = sp == null
        ? const Icon(Icons.bug_report, color: Colors.white, size: 60)
        : bugStageImage(
            sp.id,
            LifeStage.adult,
            size: 96,
            fallback: bugAvatar(sp, size: 84),
          );
    if (flip) img = Transform.flip(flipX: true, child: img);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 이름 + 오행
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                elementGlyph(u.element),
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  u.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: elementColor(u.element),
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // HP 바
          SizedBox(
            width: 120,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Stack(
                children: [
                  Container(height: 12, color: const Color(0x55000000)),
                  FractionallySizedBox(
                    widthFactor: hpFrac,
                    child: Container(
                      height: 12,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: hpFrac > 0.3
                              ? const [Color(0xFF7CE38B), Color(0xFF3FA84E)]
                              : const [Color(0xFFFF8A6B), Color(0xFFD84A2E)],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          // 스탠스 아이콘 + 캐릭터
          SizedBox(
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                Transform.translate(
                  offset: Offset(dx, 0),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      img,
                      if (flash > 0)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFFFF3B3B,
                                ).withValues(alpha: flash * 0.5),
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (stance != null)
                  Positioned(
                    top: -14,
                    child: Text(
                      _stanceGlyph(stance),
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _floatWidget(_Float f) {
    final t = (f.age / _Float.life).clamp(0.0, 1.0);
    final w = MediaQuery.of(context).size.width;
    final x = f.left ? w * 0.25 : w * 0.72;
    return Positioned(
      left: x - 24,
      top: 150 - t * 60,
      child: Opacity(
        opacity: (1 - t).clamp(0.0, 1.0),
        child: Text(
          f.text,
          style: TextStyle(
            color: f.color,
            fontWeight: FontWeight.w900,
            fontSize: 22,
            shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
          ),
        ),
      ),
    );
  }
}

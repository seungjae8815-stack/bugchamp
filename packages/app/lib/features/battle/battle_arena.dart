import 'dart:async';
import 'dart:math' as math;

import 'package:core_battle/core_battle.dart';
import 'package:core_models/core_models.dart' show Element;
import 'package:flutter/material.dart' hide Element;
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../data/game_data.dart';
import '../../domain/audio_service.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/labels.dart';
import '../../ui/skins.dart';
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
    this.skinOf = noSkin,
    this.arenaTheme = false,
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

  /// 내 곤충의 종 id → 구매한 스킨 색 필터. 상대에는 적용하지 않는다.
  final SkinOf skinOf;

  /// 아레나 테마 스킨 보유 여부(배경 색보정).
  final bool arenaTheme;

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

  /// 이번 라운드에 **누가 때렸는가**. 때린 쪽이 달려든다(둘 다면 서로 부딪친다).
  ///
  /// 예전엔 `_lungeSide` 하나로 "더 크게 때린 쪽만" 움직였다. 그런데 이 전투는
  /// 한 라운드에 보통 양쪽이 다 때리므로, 피해량이 비슷하면 **아무도 안 움직였다**.
  bool _strikeL = false, _strikeR = false;
  double _flashL = 0, _flashR = 0, _shake = 0;
  bool _finished = false;
  bool _resultShown = false;
  double _endWait = 0;

  /// 시작 인트로 진행도(0→1). 끝나기 전엔 라운드가 진행되지 않는다.
  double _introT = 0;

  /// 히트스톱 남은 시간(초). **맞는 순간 화면을 잠깐 멈춘다** — 이게 없으면
  /// 아무리 세게 때려도 타격이 그냥 지나간다(격투 게임의 기본 문법).
  double _hitStop = 0;

  /// 이번 라운드에 쓰러지는 쪽. 넘어가는 연출이 끝난 뒤 교체된다.
  bool _downL = false, _downR = false;

  /// 승패 배너 진행도(0→1).
  double _bannerT = 0;

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
    unawaited(AudioService.instance.switchBgm('bgm_pvp'));
  }

  @override
  void dispose() {
    _ticker.dispose();
    unawaited(AudioService.instance.restoreBgm());
    super.dispose();
  }

  void _enterEvent(int idx) {
    final ev = _events[idx];
    _tgtA = ev.aHp;
    _tgtB = ev.bHp;
    _accum = 0;
    _clashT = 0;
    final dmgA = ev.dmgToA, dmgB = ev.dmgToB, hA = ev.healToA, hB = ev.healToB;
    _strikeL = dmgB >= 1;
    _strikeR = dmgA >= 1;
    _downL = ev.aDown;
    _downR = ev.bDown;
    if (dmgA >= 1) {
      _floats.add(FloatText('-${dmgA.round()}', const Color(0xFFFF6B6B), true));
      _flashL = 1;
      AudioService.instance.sfxHurt();
    }
    if (hA >= 1) {
      _floats.add(FloatText('+${hA.round()}', const Color(0xFF7CE38B), true));
    }
    if (dmgB >= 1) {
      _floats.add(
        FloatText('-${dmgB.round()}', const Color(0xFFFF6B6B), false),
      );
      _flashR = 1;
      AudioService.instance.sfxHit();
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
    // 쓰러지는 라운드는 **더 길게 멈춘다** — 한 마리가 끝나는 순간이 다른
    // 라운드와 같은 속도로 지나가면 무엇이 끝났는지 안 읽힌다.
    if (ev.aDown || ev.bDown) {
      _hitStop = 0.34;
      HapticFeedback.heavyImpact();
    } else if (foeRestrained || selfRestrained) {
      _hitStop = 0.13;
    } else if (dmgA >= 1 || dmgB >= 1) {
      _hitStop = 0.06;
    }
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t.clamp(0.0, 1.0);

  void _tick(Duration elapsed) {
    final raw = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    var dt = raw.clamp(0.0, 0.05) * _speed;
    if (dt <= 0) return;
    // 인트로가 도는 동안은 전투를 멈춰 둔다 — VS 가 찍히기도 전에 첫 라운드가
    // 지나가면 인트로를 넣은 의미가 없다.
    if (_introT < 1) {
      setState(() => _introT = math.min(1, _introT + dt / 1.15));
      return;
    }
    // 히트스톱: 그림만 멈춘다(수명·감쇠도 같이 멈춰야 번쩍임이 유지된다).
    if (_hitStop > 0) {
      setState(() => _hitStop = math.max(0, _hitStop - raw.clamp(0.0, 0.05)));
      return;
    }
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
        _bannerT = math.min(1, _bannerT + dt * 2.2);
        // 배너를 보여 준 뒤에 결과 시트를 연다 — 바로 열면 배너가 안 보인다.
        if (_endWait > 1.5) {
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

    // 예전엔 `sin(t*pi)` 라 정점이 라운드 한가운데였다 — 때리는 게 아니라 몸을
    // 천천히 흔드는 것처럼 보였다. 빠르게 뻗었다 천천히 돌아와야 타격로 읽힌다.
    final lungeT = arenaLungeCurve((_clashT / kRoundDur).clamp(0.0, 1.0)) * 26;
    final lungeL = _strikeL ? lungeT : 0.0;
    final lungeR = _strikeR ? lungeT : 0.0;

    return Scaffold(
      body: SafeArea(
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
              // 아레나 — 대각 구도(내 곤충 왼쪽 아래 크게 / 상대 오른쪽 위 작게).
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: ArenaStage(
                    background: withSkin(
                      biomeBackground(
                        widget.location,
                        fallback: const ColoredBox(color: Color(0xFF1E3B28)),
                      ),
                      // 아레나 테마 스킨 보유 시 배경 색보정.
                      widget.arenaTheme ? arenaThemeFilter : null,
                    ),
                    shake: 0,
                    mineBody: _a < widget.myTeam.length
                        ? ArenaBody(
                            data: widget.data,
                            bug: widget.myTeam[_a],
                            speciesId: widget.speciesOf[widget.myTeam[_a].id],
                            flip: false,
                            stance: ev?.aStance,
                            flash: _flashL,
                            dx: lungeL,
                            size: 104,
                            down: _downL,
                            skin: widget.skinOf(
                              widget.speciesOf[widget.myTeam[_a].id] ?? '',
                            ),
                          )
                        : const SizedBox.shrink(),
                    foeBody: _b < widget.foeTeam.length
                        ? ArenaBody(
                            data: widget.data,
                            bug: widget.foeTeam[_b],
                            speciesId: widget.speciesOf[widget.foeTeam[_b].id],
                            flip: true,
                            stance: ev?.bStance,
                            flash: _flashR,
                            dx: -lungeR,
                            size: 104,
                            down: _downR,
                          )
                        : const SizedBox.shrink(),
                    minePlate: _a < widget.myTeam.length
                        ? ArenaPlate(
                            bug: widget.myTeam[_a],
                            hpFrac: _hpA[_a] / widget.myTeam[_a].maxHp,
                            mine: true,
                          )
                        : const SizedBox.shrink(),
                    foePlate: _b < widget.foeTeam.length
                        ? ArenaPlate(
                            bug: widget.foeTeam[_b],
                            hpFrac: _hpB[_b] / widget.foeTeam[_b].maxHp,
                            mine: false,
                          )
                        : const SizedBox.shrink(),
                    overlays: [
                      // 오행 克 버스트
                      for (final b in _bursts) ArenaBurst(fx: b),
                      // 데미지/회복 숫자
                      for (final f in _floats) ArenaFloat(f: f),
                      if (_introT < 1)
                        ArenaIntro(
                          t: _introT,
                          mineName: widget.myTeam.isEmpty
                              ? ''
                              : widget.myTeam.first.name,
                          foeName: widget.foeTeam.isEmpty
                              ? ''
                              : widget.foeTeam.first.name,
                        ),
                      if (_bannerT > 0)
                        ArenaResultBanner(
                          t: _bannerT,
                          // teamA = 나. 엔진은 "누구의 팀"으로만 말한다.
                          win: widget.result.outcome == BattleOutcome.teamA,
                          text: switch (widget.result.outcome) {
                            BattleOutcome.teamA => l.battleWin,
                            BattleOutcome.teamB => l.battleLose,
                            BattleOutcome.draw => l.battleDraw,
                          },
                          sub: widget.trophyDelta == 0
                              ? null
                              : '${widget.trophyDelta > 0 ? '+' : ''}'
                                    '${widget.trophyDelta}',
                        ),
                    ],
                  ),
                ),
              ),
              // 하단: 상성 휠(표시 전용 — 현재 내 수 강조) + 속도 컨트롤
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: StanceWheel(
                  energy: 0,
                  centerLabel: l.autoBattleRunning,
                  highlight: ev?.aStance,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _ctrlBtn(
                      _speed >= 2 ? '2x' : '1x',
                      Icons.fast_forward_rounded,
                      () => setState(() => _speed = _speed >= 2 ? 1 : 2),
                    ),
                    const SizedBox(width: 12),
                    _ctrlBtn(l.battleSkip, Icons.skip_next_rounded, _skipToEnd),
                  ],
                ),
              ),
            ],
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
}

import 'dart:math' as math;

import 'package:core_battle/core_battle.dart';
import 'package:core_models/core_models.dart';
import 'package:flutter/material.dart' hide Element;
import 'package:flutter/scheduler.dart';

import '../../domain/audio_service.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/art.dart';
import '../../ui/game_dialog.dart';
import '../../ui/skins.dart';
import '../../ui/toast.dart';
import 'duel_driver.dart';

/// 곤충 배틀 스타디움 — **던질 때는 위에서, 싸울 때는 옆에서**(docs/design_duel.md §7).
///
/// 판마다: 게이지(직접 던지기만) → 위에서 본 경기장에 떨어짐 → 착지하면 옆에서 본 2.5D 무대에서
/// 서버가 확정한 궤적을 재생 → 판 결과 → 다음 판. 두 판을 먼저 이기면 결과 팝업.
///
/// 앱은 **계산하지 않는다** — 궤적·결판은 진행기([DuelDriver])가 준 그대로 그린다.
class DuelArenaScreen extends StatefulWidget {
  const DuelArenaScreen({
    super.key,
    required this.mine,
    required this.foe,
    required this.driver,
    required this.params,
    required this.arena,
    required this.onFinished,
    this.mySkins = const {},
    this.foeSkins = const {},
  });

  final List<DuelBug> mine;
  final List<DuelBug> foe;
  final DuelDriver driver;
  final DuelParams params;

  /// 경기장 오행(상대 1번 곤충) — 그림만 고른다.
  final Element arena;

  /// 경기가 끝났을 때(결과 팝업 전) — 호출자가 세이브를 채택하거나 로컬 보상을 반영한다.
  final Future<void> Function(DuelStep last) onFinished;
  final Map<String, SkinView?> mySkins;
  final Map<String, SkinView?> foeSkins;

  @override
  State<DuelArenaScreen> createState() => _DuelArenaScreenState();
}

enum _Phase { aim, waiting, drop, fight, boutEnd, done }

class _DuelArenaScreenState extends State<DuelArenaScreen>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _last = Duration.zero;

  /// 현재 단계에서 흐른 시간(초).
  double _t = 0;
  _Phase _phase = _Phase.aim;
  int _bout = 0;
  int _winsA = 0;
  int _winsB = 0;
  DuelStep? _step;
  bool _finishing = false;

  static const _gaugePeriod = 1.3;
  static const _dropSeconds = 1.1;
  static const _boutEndSeconds = 1.6;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
    AudioService.instance.switchBgm('bgm_pvp');
    if (!widget.driver.interactive) _throw(widget.params.launchAuto);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration now) {
    final dt = (now - _last).inMicroseconds / 1e6;
    _last = now;
    if (dt <= 0 || dt > 0.25) return; // 앱이 멈췄다 돌아온 틈은 건너뛴다
    setState(() => _t += dt);
    switch (_phase) {
      case _Phase.drop when _t >= _dropSeconds:
        _go(_Phase.fight);
      case _Phase.fight when _t >= _fightSeconds + 0.8:
        _endBout();
      case _Phase.boutEnd when _t >= _boutEndSeconds:
        _nextBoutOrFinish();
      default:
        break;
    }
  }

  void _go(_Phase p) {
    _phase = p;
    _t = 0;
  }

  double get _fightSeconds {
    final b = _step?.bout;
    if (b == null) return 0;
    return b.ticks / widget.params.tickHz;
  }

  /// 게이지 값(0~1) — 바늘이 가운데일수록 1.
  double get _needle => 0.5 - 0.5 * math.cos(2 * math.pi * _t / _gaugePeriod);
  double get _quality => 1 - ((_needle - 0.5).abs() * 2);

  Future<void> _throw(double launch) async {
    AudioService.instance.sfxSwipe();
    setState(() => _go(_Phase.waiting));
    final s = await widget.driver.next(launch);
    if (!mounted) return;
    if (s == null) {
      final l = AppLocalizations.of(context);
      showCenterToast(context, l.battleServerFailed);
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _step = s;
      _go(_Phase.drop);
    });
  }

  void _endBout() {
    final s = _step!;
    _winsA = s.winsA;
    _winsB = s.winsB;
    s.bout.aWon
        ? AudioService.instance.sfxWin()
        : AudioService.instance.sfxLose();
    _go(_Phase.boutEnd);
  }

  Future<void> _nextBoutOrFinish() async {
    final s = _step!;
    if (!s.done) {
      _bout++;
      _step = null;
      _go(_Phase.aim);
      if (!widget.driver.interactive) _throw(widget.params.launchAuto);
      return;
    }
    if (_finishing) return;
    _finishing = true;
    _go(_Phase.done);
    await widget.onFinished(s);
    if (!mounted) return;
    await _showResult(s);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _showResult(DuelStep s) {
    final l = AppLocalizations.of(context);
    final win = s.won;
    final color = win ? const Color(0xFF6FCF6F) : const Color(0xFFEF9A9A);
    return showGameDialog<void>(
      context,
      title: win ? l.battleWin : l.battleLose,
      iconWidget: rankImageDlg('trophy'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${s.winsA} : ${s.winsB}',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontSize: 34,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          gameRewardList(context, gold: s.gold),
          const SizedBox(height: 6),
          Text(
            l.duelTrophy(
              s.trophyDelta >= 0 ? '+${s.trophyDelta}' : '${s.trophyDelta}',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
      actions: [
        gameDialogButton(l.duelResultOk, () => Navigator.of(context).pop()),
      ],
    );
  }

  // ── 그리기 ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return PopScope(
      // 경기 중 뒤로가기 = 기권과 같다(선차감이 그대로 남는다) — 실수로 나가지 않게 막는다.
      canPop: _phase == _Phase.done,
      child: Scaffold(
        backgroundColor: const Color(0xFF1B1A14),
        body: SafeArea(
          child: Column(
            children: [
              _scoreBar(l),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, box) => switch (_phase) {
                    _Phase.aim ||
                    _Phase.waiting => _topScene(box, falling: false),
                    _Phase.drop => _topScene(box, falling: true),
                    _ => _sideScene(box, l),
                  },
                ),
              ),
              _bottomBar(l),
            ],
          ),
        ),
      ),
    );
  }

  Widget _scoreBar(AppLocalizations l) {
    final a = widget.mine[_bout.clamp(0, widget.mine.length - 1)];
    final b = widget.foe[_bout.clamp(0, widget.foe.length - 1)];
    TextStyle st(Color c) =>
        TextStyle(color: c, fontSize: 13, fontWeight: FontWeight.w800);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        children: [
          Text(
            l.duelBout(_bout + 1),
            style: const TextStyle(
              color: Color(0xCCFFFFFF),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  a.name,
                  style: st(const Color(0xFF9CE37D)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '$_winsA : $_winsB',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Expanded(
                child: Text(
                  b.name,
                  textAlign: TextAlign.right,
                  style: st(const Color(0xFFEF9A9A)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bottomBar(AppLocalizations l) {
    if (_phase == _Phase.aim && widget.driver.interactive) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _gauge(),
            const SizedBox(height: 6),
            Text(
              l.duelGaugeHint,
              style: const TextStyle(color: Color(0xAAFFFFFF), fontSize: 11.5),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: () => _throw(_quality),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFEBA52F),
                  foregroundColor: const Color(0xFF3A2410),
                ),
                child: Text(
                  l.duelThrowButton,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    if (_phase == _Phase.fight) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => setState(() => _t = _fightSeconds + 0.8),
            child: Text(
              l.duelSkip,
              style: const TextStyle(color: Color(0xCCFFFFFF)),
            ),
          ),
        ),
      );
    }
    return const SizedBox(height: 64);
  }

  Widget _gauge() => SizedBox(
    height: 26,
    child: LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        return Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFC85454),
                    Color(0xFFEBD24A),
                    Color(0xFF6FCF6F),
                    Color(0xFFEBD24A),
                    Color(0xFFC85454),
                  ],
                  stops: [0, 0.35, 0.5, 0.65, 1],
                ),
              ),
            ),
            Positioned(
              left: (w - 6) * _needle,
              top: 0,
              bottom: 0,
              width: 6,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(3),
                  boxShadow: const [
                    BoxShadow(color: Colors.black54, blurRadius: 4),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    ),
  );

  // ── 위에서 본 장면: 게이지·떨어지기 ────────────────────────────────

  Widget _topScene(BoxConstraints box, {required bool falling}) {
    final side = math.min(box.maxWidth, box.maxHeight) * 0.9;
    final a = widget.mine[_bout.clamp(0, widget.mine.length - 1)];
    final b = widget.foe[_bout.clamp(0, widget.foe.length - 1)];
    final k = falling ? (_t / _dropSeconds).clamp(0.0, 1.0) : 0.0;
    final ease = Curves.easeIn.transform(k);
    Widget bug(DuelBug d, SkinView? skin, double dir) {
      // 떨어지는 동안 크게 → 제 크기(가까웠다 멀어짐), 그림자는 반대로 커진다.
      final size = side * 0.2 * (d.radius(widget.params) / 12);
      final scale = falling ? 1.8 - 0.8 * ease : 1.8;
      final y = falling ? dir * side * (0.62 - 0.27 * ease) : dir * side * 0.62;
      return Transform.translate(
        offset: Offset(0, y),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (falling)
              Container(
                width: size * (0.4 + 0.6 * ease),
                height: size * (0.4 + 0.6 * ease),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.25 * ease),
                ),
              ),
            Transform.scale(
              scale: scale,
              child: Transform.rotate(
                angle: dir > 0 ? 0 : math.pi,
                child: gameImageChain(
                  [
                    'assets/images/duel/duel_${d.speciesId}.webp',
                    'assets/images/bugs/${d.speciesId}_adult.webp',
                  ],
                  size: size,
                  fallback: Icon(
                    Icons.bug_report,
                    size: size,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Center(
      child: SizedBox(
        width: side,
        height: side,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            ClipOval(
              child: gameImageChain(
                ['assets/images/duel/arena_${widget.arena.key}.webp'],
                size: side,
                fit: BoxFit.cover,
                fallback: Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [Color(0xFF8A6A3E), Color(0xFF4A3520)],
                    ),
                  ),
                ),
              ),
            ),
            bug(a, widget.mySkins[a.id], 1),
            bug(b, widget.foeSkins[b.id], -1),
            if (_phase == _Phase.waiting)
              const CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }

  // ── 옆에서 본 장면: 2.5D 무대 ──────────────────────────────────────

  Widget _sideScene(BoxConstraints box, AppLocalizations l) {
    final step = _step;
    if (step == null) return const SizedBox.shrink();
    final bout = step.bout;
    final w = box.maxWidth;
    final h = box.maxHeight;
    final stageW = w * 0.92;
    final cx = w / 2;
    final cy = h * 0.62;
    final r = widget.params.arenaRadius;

    // 재생 위치(초) → 프레임 보간.
    final playT = _phase == _Phase.fight
        ? _t.clamp(0.0, _fightSeconds)
        : _fightSeconds;
    final framePos = playT * widget.params.tickHz / widget.params.frameEvery;
    final fi = framePos.floor().clamp(0, bout.frames.length - 1);
    final fj = (fi + 1).clamp(0, bout.frames.length - 1);
    final frac = (framePos - fi).clamp(0.0, 1.0);
    final f0 = bout.frames[fi];
    final f1 = bout.frames[fj];
    double lerp(int k) => f0[k] + (f1[k] - f0[k]) * frac;

    final tick = (playT * widget.params.tickHz).round();
    final ended = _phase != _Phase.fight || playT >= _fightSeconds;

    // 판마다 한 쌍.
    final a = widget.mine[_bout.clamp(0, widget.mine.length - 1)];
    final b = widget.foe[_bout.clamp(0, widget.foe.length - 1)];

    ({double x, double y, double hp, int flags}) at(int side) {
      final o = side * 6;
      return (
        x: lerp(o) / 10,
        y: lerp(o + 1) / 10,
        hp: f1[o + 4] / 1000,
        flags: f0[o + 5],
      );
    }

    final pa = at(0);
    final pb = at(1);

    BugPose poseOf(int side) {
      for (final e in bout.events) {
        final dt = (tick - e.tick) / widget.params.tickHz;
        if (dt < -0.02 || dt > 0.28) continue;
        final mine = e.who == side;
        switch (e.kind) {
          case DuelEventKind.clash:
          case DuelEventKind.grip:
          case DuelEventKind.toss:
            return mine ? BugPose.attack : BugPose.hurt;
          case DuelEventKind.land:
            if (mine) return BugPose.hurt;
          default:
            break;
        }
      }
      return BugPose.idle;
    }

    // 결판 뒤의 연출(진 쪽).
    final loser = bout.winner == 0 ? 1 : 0;
    final afterEnd = ended ? (_phase == _Phase.fight ? 0.0 : _t) : 0.0;

    Widget fighter(
      DuelBug d,
      int side,
      ({double x, double y, double hp, int flags}) p,
      SkinView? skin,
    ) {
      final other = side == 0 ? pb : pa;
      final faceRight = other.x >= p.x;
      final depth = (p.y / r).clamp(-1.4, 1.4);
      var sx = cx + p.x / r * stageW * 0.42;
      var sy = cy - depth * h * 0.11;
      final scale = 1 - depth * 0.12;
      final base = w * 0.22 * (d.radius(widget.params) / 12) * scale;
      var lift = 0.0;
      if (p.flags & DuelFlag.airborne != 0) lift = base * 0.8;
      var angle = 0.0;
      var opacity = 1.0;
      if (side == loser && ended) {
        switch (bout.finish) {
          case DuelFinish.flip:
            angle = math.pi * math.min(1, afterEnd * 3);
          case DuelFinish.ringOut:
            final k = math.min(1.0, afterEnd * 1.4);
            sx += (p.x >= 0 ? 1 : -1) * w * 0.35 * k;
            sy += h * 0.25 * k * k;
            opacity = 1 - k;
          default:
            break;
        }
      }
      final pose = ended && side == loser ? BugPose.hurt : poseOf(side);
      final img = bugPoseImage(
        d.speciesId,
        pose,
        size: base,
        skin: skin,
        fallback: Icon(Icons.bug_report, size: base, color: Colors.white),
      );
      return Positioned(
        left: sx - base / 2,
        top: sy - base - lift,
        width: base,
        height: base,
        child: Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Transform.rotate(
            angle: angle,
            child: Transform.flip(flipX: !faceRight, child: img),
          ),
        ),
      );
    }

    Widget shadow(DuelBug d, ({double x, double y, double hp, int flags}) p) {
      final depth = (p.y / r).clamp(-1.4, 1.4);
      final scale = 1 - depth * 0.12;
      final base = w * 0.22 * (d.radius(widget.params) / 12) * scale;
      final sx = cx + p.x / r * stageW * 0.42;
      final sy = cy - depth * h * 0.11;
      return Positioned(
        left: sx - base * 0.4,
        top: sy - base * 0.08,
        width: base * 0.8,
        height: base * 0.16,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.35),
            borderRadius: BorderRadius.all(Radius.elliptical(base, base * 0.2)),
          ),
        ),
      );
    }

    // 뒤(깊은 쪽)부터 그린다.
    final order = [
      (0, a, pa, widget.mySkins[a.id]),
      (1, b, pb, widget.foeSkins[b.id]),
    ]..sort((x, y) => y.$3.y.compareTo(x.$3.y));

    final finishText = switch (bout.finish) {
      DuelFinish.ringOut => l.duelFinishRingOut,
      DuelFinish.flip => l.duelFinishFlip,
      DuelFinish.knockout => l.duelFinishKnockout,
      DuelFinish.timeUp => l.duelFinishTimeUp,
    };

    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        // 무대.
        Positioned(
          left: cx - stageW / 2,
          top: cy - h * 0.2,
          width: stageW,
          height: h * 0.4,
          child: gameImageChain(
            ['assets/images/duel/arena_${widget.arena.key}_side.webp'],
            size: h * 0.4,
            fit: BoxFit.fill,
            fallback: Container(
              decoration: BoxDecoration(
                gradient: const RadialGradient(
                  colors: [Color(0xFF9B7A48), Color(0xFF5A4028)],
                ),
                borderRadius: BorderRadius.all(
                  Radius.elliptical(stageW, h * 0.26),
                ),
                border: Border.all(color: const Color(0xFF3A2814), width: 4),
              ),
            ),
          ),
        ),
        shadow(a, pa),
        shadow(b, pb),
        for (final (side, d, p, skin) in order) fighter(d, side, p, skin),
        // 체력.
        Positioned(
          left: 16,
          right: 16,
          top: 8,
          child: Row(
            children: [
              Expanded(child: _hpBar(pa.hp, const Color(0xFF6FCF6F))),
              const SizedBox(width: 16),
              Expanded(child: _hpBar(pb.hp, const Color(0xFFC85454))),
            ],
          ),
        ),
        if (ended)
          Positioned(
            left: 0,
            right: 0,
            top: h * 0.14,
            child: Column(
              children: [
                Text(
                  finishText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFFFD54F),
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    shadows: [Shadow(color: Colors.black, blurRadius: 6)],
                  ),
                ),
                if (_phase == _Phase.boutEnd || _phase == _Phase.done)
                  Text(
                    bout.aWon ? l.duelBoutWin : l.duelBoutLose,
                    style: TextStyle(
                      color: bout.aWon
                          ? const Color(0xFF9CE37D)
                          : const Color(0xFFEF9A9A),
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _hpBar(double v, Color c) => ClipRRect(
    borderRadius: BorderRadius.circular(5),
    child: LinearProgressIndicator(
      value: v.clamp(0.0, 1.0),
      minHeight: 10,
      backgroundColor: const Color(0x33FFFFFF),
      valueColor: AlwaysStoppedAnimation(c),
    ),
  );
}

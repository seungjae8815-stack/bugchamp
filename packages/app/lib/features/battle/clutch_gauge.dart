import 'dart:math' as math;

import 'package:core_battle/core_battle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/audio_service.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/colors.dart';

/// 탭 반격(훈련 v2 §4) 게이지 점수(0~1) — [taps] 는 게이지가 뜬 뒤 각 탭의 시각(초, 오름차순).
///
/// 점수 = 연타 몫 × (0.75 + 0.25 × 박자 고르기). 연타 몫 = 탭 수 ÷ [target](최대 1).
/// 박자 고르기 = 1 − 탭 간격의 변동계수(간격 2개 이상일 때만, 아니면 0) — 같은 수를 쳐도 고르게 친 쪽이 높다.
/// [seconds] 이후의 탭은 세지 않는다(게이지가 닫힌 뒤 들어온 탭).
/// ⚠️ 점수는 앱이 서버로 보낸다 — 조작 앱은 늘 만점이다. 그래서 엔진이 살아나는 폭을 작게 둔다.
double clutchTapScore(
  List<double> taps, {
  double seconds = 1.2,
  int target = 10,
}) {
  final t = [
    for (final x in taps)
      if (x >= 0 && x <= seconds) x,
  ];
  if (t.isEmpty || target <= 0) return 0;
  final count = math.min(1.0, t.length / target);
  var rhythm = 0.0;
  if (t.length >= 3) {
    final gaps = [for (var i = 1; i < t.length; i++) t[i] - t[i - 1]];
    final mean = gaps.reduce((a, b) => a + b) / gaps.length;
    if (mean > 0) {
      final varc =
          gaps.fold<double>(0, (s, g) => s + (g - mean) * (g - mean)) /
          gaps.length;
      rhythm = (1 - math.sqrt(varc) / mean).clamp(0.0, 1.0);
    }
  }
  return (count * (0.75 + 0.25 * rhythm)).clamp(0.0, 1.0);
}

/// 보낼 점수 — 두드린 점수와 [floor](자동 점수 기준) 중 큰 쪽(2026-10-09 사장님 확정).
///
/// 한 번도 못 쳤을 때 0 점이면 탭 반격을 모르는 구버전 앱·상대의 자동 점수(약 0.5)보다 손해였다 —
/// 직접 하는 쪽이 불리하면 안 된다. 바닥은 엔진 자동 점수의 가운데(`clutchAutoBase + 근성 × clutchAutoPerGrit`).
double clutchSendScore(double tapScore, double floor) =>
    math.max(tapScore, floor).clamp(0.0, 1.0);

/// 탭 반격 첫 안내를 이 기기에서 봤는가(기기 플래그 — 세이브가 아니다).
///
/// 처음 위기를 맞은 유저는 게이지가 무엇인지 모른 채 1.2초를 날렸다(2026-10-09 점검). 기기당 첫 1회는
/// "화면을 연타해 흰 선을 넘기세요"를 보여 주고 **탭하면** 시작한다.
class ClutchTutorial {
  ClutchTutorial._();

  static const _key = 'duel.clutchTutorialSeen';

  /// null = 아직 안 읽었다(그동안은 안내를 띄우지 않는다 — 못 읽은 탓에 판을 붙잡지 않게).
  static bool? _seen;

  /// 결투장에 들어올 때 미리 읽는다(위기는 판이 몇 초 돈 뒤에 온다).
  static Future<void> load() async {
    if (_seen != null) return;
    try {
      final p = await SharedPreferences.getInstance();
      _seen = p.getBool(_key) ?? false;
    } catch (e) {
      debugPrint('ClutchTutorial.load 실패(안내 생략): $e');
      _seen = true;
    }
  }

  /// 이번 위기에 첫 안내를 띄울까.
  static bool get needed => _seen == false;

  static Future<void> markSeen() async {
    _seen = true;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_key, true);
    } catch (e) {
      debugPrint('ClutchTutorial.markSeen 실패: $e');
    }
  }

  @visibleForTesting
  static void resetForTest({bool? seen}) => _seen = seen;
}

/// 게이지의 단계 — 첫 안내(탭 대기) → 준비("위기!") → 연타 → 끝.
enum _Stage { tutorial, ready, run, done }

/// 위기 순간 화면 가운데에 뜨는 **큰 연타 게이지**. [seconds] 동안 아무 데나 두드리면 차오르고,
/// 시간이 끝나면 [onDone] 에 점수(0~1)를 한 번 준다.
///
/// 글씨는 크게 · 두꺼운 테두리 · 어두운 막 위에 — 경기장 그림에 묻히지 않게(2026-10 실기 지적).
///
/// 2026-10-09 보완(사장님 확정): 게이지 전에 [readySeconds] 동안 "위기!" 준비 시간(이때 탭은 세지 않는다) ·
/// [tutorial] 이면 안내를 띄우고 탭하면 바로 시작 · 보낼 점수는 [minScore] 아래로 내려가지 않는다 ·
/// 성공선에 "성공" 표시.
class ClutchGauge extends StatefulWidget {
  const ClutchGauge({
    super.key,
    required this.kind,
    required this.onDone,
    this.seconds = 1.2,
    this.target = 10,
    this.chance = 1,
    this.chances = 1,
    this.threshold,
    this.readySeconds = 0.7,
    this.tutorial = false,
    this.onTutorialDone,
    this.minScore = 0,
  });

  final DuelCrisis kind;
  final ValueChanged<double> onDone;
  final double seconds;
  final int target;

  /// 이번이 이 판 몇 번째 기회인지 / 이 판 전체 기회(근성 칸으로 늘어난다).
  final int chance;
  final int chances;

  /// 성공 문턱(0~1) — 게이지에 금 긋기. null 이면 안 긋는다.
  final double? threshold;

  /// 게이지가 돌기 전 "위기!" 준비 시간(초) — 화면 연출이다(밸런스 수치 아님).
  final double readySeconds;

  /// 첫 안내를 띄우고 탭을 기다린다(기기당 첫 1회 — [ClutchTutorial]).
  final bool tutorial;

  /// 첫 안내를 넘겼다(탭) — 기기 플래그를 적는다.
  final VoidCallback? onTutorialDone;

  /// 보낼 점수의 바닥(자동 점수 기준, [clutchSendScore]). 게이지에 옅은 띠로 보인다.
  final double minScore;

  @override
  State<ClutchGauge> createState() => _ClutchGaugeState();
}

class _ClutchGaugeState extends State<ClutchGauge>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final List<double> _taps = [];

  late _Stage _stage = widget.tutorial
      ? _Stage.tutorial
      : (widget.readySeconds > 0 ? _Stage.ready : _Stage.run);

  /// Ticker 가 시작된 뒤 흐른 시간(초).
  double _now = 0;

  /// 지금 단계가 시작된 시각([_now] 기준).
  double _stageAt = 0;

  /// 연타 단계에서 흐른 시간(초) — 탭 시각도 이 값(프레임 단위 해상도)으로 잰다.
  double get _t =>
      _stage == _Stage.run || _stage == _Stage.done ? _now - _stageAt : 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _enter(_Stage s) {
    _stage = s;
    _stageAt = _now;
  }

  void _onTick(Duration elapsed) {
    if (_stage == _Stage.done) return;
    setState(() => _now = elapsed.inMicroseconds / 1e6);
    if (_stage == _Stage.ready && _now - _stageAt >= widget.readySeconds) {
      _enter(_Stage.run);
    } else if (_stage == _Stage.run && _t >= widget.seconds) {
      _enter(_Stage.done);
      _ticker.stop();
      final score = clutchTapScore(
        _taps,
        seconds: widget.seconds,
        target: widget.target,
      );
      widget.onDone(clutchSendScore(score, widget.minScore));
    }
  }

  void _tap() {
    switch (_stage) {
      case _Stage.tutorial:
        // 안내를 읽고 누르면 **바로** 연타 시작 — 안내가 준비 시간을 대신한다.
        AudioService.instance.sfxTap();
        widget.onTutorialDone?.call();
        setState(() => _enter(_Stage.run));
      case _Stage.ready:
      case _Stage.done:
        break; // 준비 중·끝난 뒤의 탭은 세지 않는다.
      case _Stage.run:
        final at = _t;
        if (at > widget.seconds) return;
        AudioService.instance.sfxTap();
        setState(() => _taps.add(at));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final score = clutchTapScore(
      _taps,
      seconds: widget.seconds,
      target: widget.target,
    );
    final running = _stage == _Stage.run || _stage == _Stage.done;
    final left = running ? (1 - _t / widget.seconds).clamp(0.0, 1.0) : 1.0;
    final kindTitle = widget.kind == DuelCrisis.knockout
        ? l.duelClutchWake
        : l.duelClutchHold;
    // 준비·안내 중엔 "위기!"를 크게, 무엇을 해야 하는지는 아래 줄에.
    final title = running ? kindTitle : l.duelClutchCrisis;
    final hint = switch (_stage) {
      _Stage.tutorial => l.duelClutchTutorial,
      _Stage.ready => kindTitle,
      _ => l.duelClutchTapHint,
    };
    // 탭할 때마다 제목이 톡 튄다.
    final pulse = !running || _taps.isEmpty
        ? 0.0
        : math.max(0.0, 1 - (_t - _taps.last) / 0.12);
    const outline = [
      Shadow(color: Colors.black, blurRadius: 2),
      Shadow(color: Colors.black, offset: Offset(2, 2)),
      Shadow(color: Colors.black, offset: Offset(-2, -2)),
      Shadow(color: Colors.black, offset: Offset(2, -2)),
      Shadow(color: Colors.black, offset: Offset(-2, 2)),
    ];
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // 누르는 순간 센다(뗄 때 세면 빠른 연타가 씹힌다).
      onTapDown: (_) => _tap(),
      child: Container(
        color: const Color(0xA6000000),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.scale(
              scale: 1 + 0.12 * pulse,
              child: Text(
                title,
                key: const ValueKey('clutchTitle'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: running ? kHoney : const Color(0xFFFF7043),
                  fontSize: 52,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                  shadows: outline,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              hint,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                shadows: outline,
              ),
            ),
            // 성공선 위 "성공" 글씨가 들어갈 자리.
            SizedBox(height: widget.threshold == null ? 18 : 30),
            _gauge(l, score, outline),
            const SizedBox(height: 10),
            // 남은 시간 — 얇은 막대(준비·안내 중엔 가득).
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: left,
                minHeight: 8,
                backgroundColor: const Color(0x33FFFFFF),
                valueColor: const AlwaysStoppedAnimation(Colors.white),
              ),
            ),
            const SizedBox(height: 12),
            if (_stage == _Stage.tutorial)
              Text(
                l.duelClutchTapToStart,
                key: const ValueKey('clutchTapToStart'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: kHoney,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  shadows: outline,
                ),
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${_taps.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      shadows: outline,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xCC000000),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: kHoney, width: 2),
                    ),
                    child: Text(
                      l.duelClutchChance(widget.chance, widget.chances),
                      style: const TextStyle(
                        color: kHoney,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  /// 점수 게이지 — 굵고 크게. 바닥 점수는 옅은 띠, 성공 문턱에 흰 선과 "성공".
  Widget _gauge(AppLocalizations l, double score, List<Shadow> outline) {
    return SizedBox(
      height: 40,
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth;
          final th = widget.threshold;
          final floor = widget.minScore.clamp(0.0, 1.0);
          final ok = th != null && clutchSendScore(score, floor) >= th;
          final inner = math.max(0.0, w - 8);
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white, width: 4),
                ),
              ),
              // 바닥 점수 — 한 번도 못 쳐도 이만큼은 보낸다.
              if (floor > 0)
                Positioned(
                  left: 4,
                  top: 4,
                  bottom: 4,
                  width: inner * floor,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: const Color(0x40FFFFFF),
                    ),
                  ),
                ),
              Positioned(
                left: 4,
                top: 4,
                bottom: 4,
                width: inner * score,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: LinearGradient(
                      colors: ok
                          ? const [Color(0xFF6FCF6F), Color(0xFFB9F28A)]
                          : const [Color(0xFFC85454), kHoney],
                    ),
                  ),
                ),
              ),
              if (th != null) ...[
                Positioned(
                  left: 4 + inner * th - 2,
                  top: -6,
                  bottom: -6,
                  width: 4,
                  child: Container(color: Colors.white),
                ),
                // 성공선 위 "성공" — 어디까지 치면 되는지 글로도 보인다.
                Positioned(
                  left: 4 + inner * th - 40,
                  width: 80,
                  top: -30,
                  child: Text(
                    l.duelClutchSuccessMark,
                    key: const ValueKey('clutchSuccessMark'),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    style: TextStyle(
                      color: ok ? const Color(0xFFB9F28A) : Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      shadows: outline,
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

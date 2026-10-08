import 'dart:math' as math;

import 'package:core_battle/core_battle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

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

/// 위기 순간 화면 가운데에 뜨는 **큰 연타 게이지**. [seconds] 동안 아무 데나 두드리면 차오르고,
/// 시간이 끝나면 [onDone] 에 점수(0~1)를 한 번 준다.
///
/// 글씨는 크게 · 두꺼운 테두리 · 어두운 막 위에 — 경기장 그림에 묻히지 않게(2026-10 실기 지적).
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

  @override
  State<ClutchGauge> createState() => _ClutchGaugeState();
}

class _ClutchGaugeState extends State<ClutchGauge>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final List<double> _taps = [];
  double _t = 0;
  bool _done = false;

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

  /// 게이지가 뜬 뒤 흐른 시간(초) — 화면 프레임(Ticker) 기준. 탭 시각도 이 값(프레임 단위 해상도)으로 잰다.
  void _onTick(Duration elapsed) {
    if (_done) return;
    setState(() => _t = elapsed.inMicroseconds / 1e6);
    if (_t >= widget.seconds) {
      _done = true;
      _ticker.stop();
      widget.onDone(
        clutchTapScore(_taps, seconds: widget.seconds, target: widget.target),
      );
    }
  }

  void _tap() {
    if (_done) return;
    final at = _t;
    if (at > widget.seconds) return;
    AudioService.instance.sfxTap();
    setState(() => _taps.add(at));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final score = clutchTapScore(
      _taps,
      seconds: widget.seconds,
      target: widget.target,
    );
    final left = (1 - _t / widget.seconds).clamp(0.0, 1.0);
    final title = widget.kind == DuelCrisis.knockout
        ? l.duelClutchWake
        : l.duelClutchHold;
    // 탭할 때마다 제목이 톡 튄다.
    final pulse = _taps.isEmpty
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
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: kHoney,
                  fontSize: 52,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                  shadows: outline,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l.duelClutchTapHint,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                shadows: outline,
              ),
            ),
            const SizedBox(height: 18),
            // 점수 게이지 — 굵고 크게. 성공 문턱에 금.
            SizedBox(
              height: 40,
              child: LayoutBuilder(
                builder: (context, box) {
                  final w = box.maxWidth;
                  final th = widget.threshold;
                  final ok = th != null && score >= th;
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
                      Positioned(
                        left: 4,
                        top: 4,
                        bottom: 4,
                        width: math.max(0.0, (w - 8) * score),
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
                      if (th != null)
                        Positioned(
                          left: 4 + (w - 8) * th - 2,
                          top: -6,
                          bottom: -6,
                          width: 4,
                          child: Container(color: Colors.white),
                        ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            // 남은 시간 — 얇은 막대.
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
}

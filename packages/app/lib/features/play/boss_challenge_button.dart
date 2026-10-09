import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// 사냥터의 [보스 도전] 버튼(2026-10-08 강조 개편).
///
/// 잠겨 있을 땐 남은 마리 수를 센다. 게이지가 차면 **진한 빨강 판 + 밝은 글씨**로 크게 맥동한다 —
/// 신규 유저 다수가 이 버튼을 몰라 수만 마리를 잡고도 보스를 한 번도 도전하지 않았다.
/// 자동 도전 카운트다운([autoSecondsLeft])이 돌면 같은 판 **위쪽 줄**에 남은 초를 적는다.
///
/// ⚠️ 맥동은 [Transform.scale] 로만 한다 — 레이아웃 크기를 바꾸면 옆의 미션 패널이 흔들린다.
/// ⚠️ 폭은 [maxWidth] 로 묶고 글씨는 줄여 맞춘다(2026-10-09 점검 — 영어 문구가 길어 왼쪽 미션 패널을 덮었다).
class BossChallengeButton extends StatefulWidget {
  const BossChallengeButton({
    super.key,
    required this.kills,
    required this.need,
    required this.onTap,
    this.autoSecondsLeft,
    this.autoPaused = false,
  });

  /// 버튼이 차지할 수 있는 가장 넓은 폭 — 넘치는 글씨는 줄여서 맞춘다.
  static const double maxWidth = 110;

  /// 이 사냥터에서 잡은 수(게이지).
  final int kills;

  /// 보스 도전이 열리는 수.
  final int need;

  /// 자동 도전까지 남은 초. null 이면 카운트다운 없음(자동 끔·대기 중 아님).
  final int? autoSecondsLeft;

  /// 이 사냥터에서 자동 도전이 연달아 져서 멈췄다(2026-10-09) — 위쪽 줄에 "자동 멈춤"을 적는다.
  final bool autoPaused;

  final VoidCallback onTap;

  bool get ready => kills >= need;

  @override
  State<BossChallengeButton> createState() => _BossChallengeButtonState();
}

class _BossChallengeButtonState extends State<BossChallengeButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant BossChallengeButton old) {
    super.didUpdateWidget(old);
    _sync();
  }

  /// 준비됐을 때만 돈다 — 잠긴 동안 매 프레임 다시 그릴 이유가 없다.
  void _sync() {
    if (widget.ready) {
      if (!_c.isAnimating) _c.repeat(reverse: true);
    } else if (_c.isAnimating) {
      _c
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: BossChallengeButton.maxWidth),
      child: widget.ready ? _readyButton(l) : _locked(l),
    );
  }

  Widget _locked(AppLocalizations l) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0xB3101A0A),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: const Color(0x55FFFFFF)),
    ),
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        l.bossChallengeLocked(widget.need - widget.kills),
        maxLines: 1,
        style: const TextStyle(
          color: Color(0xE6FFFFFF),
          fontSize: 11.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    ),
  );

  Widget _readyButton(AppLocalizations l) {
    final secs = widget.autoSecondsLeft;
    // 위쪽 줄: 자동 도전 카운트다운, 아니면 연패로 멈춘 자동.
    final top = secs != null
        ? Text(
            l.bossAutoCountdown(secs),
            key: const ValueKey('bossAutoCountdown'),
            maxLines: 1,
            style: const TextStyle(
              color: Color(0xFFFFF59D),
              fontSize: 10,
              height: 1.1,
              fontWeight: FontWeight.w900,
              shadows: [Shadow(color: Colors.black, blurRadius: 3)],
            ),
          )
        : widget.autoPaused
        ? Text(
            l.bossAutoPausedShort,
            key: const ValueKey('bossAutoPaused'),
            maxLines: 1,
            style: const TextStyle(
              color: Color(0xFFFFE0B2),
              fontSize: 10,
              height: 1.1,
              fontWeight: FontWeight.w900,
              shadows: [Shadow(color: Colors.black, blurRadius: 3)],
            ),
          )
        : null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          final t = Curves.easeInOut.transform(_c.value);
          return Transform.scale(
            scale: 1.0 + 0.08 * t,
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color.lerp(
                      const Color(0xFFC62828),
                      const Color(0xFFE53935),
                      t,
                    )!,
                    const Color(0xFF8E1414),
                  ],
                ),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: Color.lerp(
                    const Color(0xFFFFCC80),
                    const Color(0xFFFFF59D),
                    t,
                  )!,
                  width: 1.6,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(
                      0xFFFF5252,
                    ).withValues(alpha: 0.35 + 0.45 * t),
                    blurRadius: 6 + 10 * t,
                    spreadRadius: 1 + 2 * t,
                  ),
                ],
              ),
              child: child,
            ),
          );
        },
        // 판 안에서 글씨를 줄여 맞춘다 — 폭은 [BossChallengeButton.maxWidth] 로 묶여 있다.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ?top,
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.whatshot_rounded,
                    color: Color(0xFFFFF59D),
                    size: 15,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    l.bossChallenge,
                    maxLines: 1,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      height: 1.15,
                      fontWeight: FontWeight.w900,
                      shadows: [Shadow(color: Colors.black87, blurRadius: 3)],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

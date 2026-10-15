import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../ui/art.dart';

/// 무료 버프 대기 화면의 결과.
enum BuffWaitResult {
  /// 끝까지 기다렸다 — 무료로 켠다.
  done,

  /// "젤리로 바로 켜기"를 눌렀다 — 무료 횟수를 쓰지 않고 젤리로 켠다.
  jelly,

  /// 취소·화면을 떠남 — 켜지 않는다(무료 횟수도 안 씀).
  cancel,
}

/// 버프를 **무료로** 켤 때 [seconds]초 동안 보여 주는 대기 화면(2026-10-15 사장님 확정 60초).
///
/// 예전 "광고 보고 켜기"의 자리 — 기다림이 무한 버프 패스·젤리를 살 이유가 된다. 그래서 화면에
/// "젤리로 바로 켜기"와 [passCard](무한 버프 패스)를 함께 둔다. 앱을 내리거나 창을 닫으면 취소된다
/// (앱을 끈 채 기다리면 대기의 의미가 없다).
Future<BuffWaitResult> showBuffWait(
  BuildContext context, {
  required Widget icon,
  required String buffName,
  required int seconds,
  required int jellyCost,
  Widget? passCard,
}) async {
  final r = await showGeneralDialog<BuffWaitResult>(
    context: context,
    barrierDismissible: false,
    barrierColor: const Color(0xE6000000),
    pageBuilder: (ctx, _, _) => _BuffWait(
      icon: icon,
      buffName: buffName,
      seconds: seconds,
      jellyCost: jellyCost,
      passCard: passCard,
    ),
  );
  return r ?? BuffWaitResult.cancel;
}

class _BuffWait extends StatefulWidget {
  const _BuffWait({
    required this.icon,
    required this.buffName,
    required this.seconds,
    required this.jellyCost,
    this.passCard,
  });

  final Widget icon;
  final String buffName;
  final int seconds;
  final int jellyCost;
  final Widget? passCard;

  @override
  State<_BuffWait> createState() => _BuffWaitState();
}

class _BuffWaitState extends State<_BuffWait> with WidgetsBindingObserver {
  // 지난 시간(ms) — 타이머가 100ms 마다 더한다(앱을 내리면 취소되니 벽시계와 어긋날 일이 없다).
  int _ms = 0;
  Timer? _timer;
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      _ms += 100;
      if (_ms >= widget.seconds * 1000) {
        _close(BuffWaitResult.done);
      } else {
        setState(() {});
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 앱을 내리면 취소 — 꺼 둔 채 기다리면 대기가 의미 없다.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _close(BuffWaitResult.cancel);
    }
  }

  void _close(BuffWaitResult r) {
    if (_closed) return;
    _closed = true;
    _timer?.cancel();
    Navigator.of(context).pop(r);
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final total = widget.seconds * 1000;
    final ms = _ms.clamp(0, total);
    final left = ((total - ms) / 1000).ceil();
    final mm = left ~/ 60;
    final ss = (left % 60).toString().padLeft(2, '0');
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close(BuffWaitResult.cancel);
      },
      child: Material(
        color: Colors.transparent,
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  children: [
                    // 배경 그림(없으면 숲색 그라데이션).
                    Positioned.fill(
                      child: gameImage(
                        'assets/images/buffs/buff_wait_bg.webp',
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                        fallback: const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0xFF243B1E), Color(0xFF101A0C)],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            l.buffWaitTitle(widget.buffName),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              shadows: [Shadow(blurRadius: 6)],
                            ),
                          ),
                          const SizedBox(height: 18),
                          // 가운데 = 버프 아이콘 + 진행 원.
                          SizedBox(
                            width: 150,
                            height: 150,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                SizedBox(
                                  width: 150,
                                  height: 150,
                                  child: CircularProgressIndicator(
                                    value: total == 0 ? 1 : ms / total,
                                    strokeWidth: 8,
                                    backgroundColor: const Color(0x55000000),
                                    color: const Color(0xFFEBA52F),
                                  ),
                                ),
                                widget.icon,
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '$mm:$ss',
                            style: const TextStyle(
                              color: Color(0xFFEBA52F),
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              shadows: [Shadow(blurRadius: 6)],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l.buffWaitHint,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xDDFFFFFF),
                              fontSize: 12,
                              height: 1.35,
                              shadows: [Shadow(blurRadius: 4)],
                            ),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            height: 46,
                            child: FilledButton(
                              onPressed: () => _close(BuffWaitResult.jelly),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF1E6091),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  jellyIcon(size: 18),
                                  const SizedBox(width: 6),
                                  Text(
                                    l.buffWaitJelly(widget.jellyCost),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (widget.passCard != null) ...[
                            const SizedBox(height: 10),
                            widget.passCard!,
                          ],
                          const SizedBox(height: 6),
                          TextButton(
                            onPressed: () => _close(BuffWaitResult.cancel),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xCCFFFFFF),
                            ),
                            child: Text(l.actionCancel),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

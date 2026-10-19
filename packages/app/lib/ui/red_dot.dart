import 'package:flutter/material.dart';

/// 빨간 점 하나 — 모든 화면이 같은 색·크기를 쓴다(2026-10-19 전에는 화면마다 따로 그려 색이 섞여 있었다).
/// 언제 띄우는지는 `domain/red_dots.dart`.
class RedDot extends StatelessWidget {
  const RedDot({super.key, this.size = 10});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: const Color(0xFFFF4D4D),
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 1.2),
    ),
  );
}

/// [child] 오른쪽 위에 [show] 일 때 빨간 점. 점이 없을 때도 같은 모양(Stack)이라 켜고 꺼질 때 자식 상태가 유지된다.
class RedDotBadge extends StatelessWidget {
  const RedDotBadge({
    super.key,
    required this.show,
    required this.child,
    this.top = -3,
    this.right = -3,
    this.bottom,
    this.size = 10,
  });

  final bool show;
  final Widget child;
  final double top;
  final double right;

  /// 값이 있으면 오른쪽 **아래**에 단다(위가 다른 것에 가려지는 자리 — 홈 미션 카드는 사냥터 이름표가 덮는다).
  final double? bottom;
  final double size;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      child,
      if (show)
        Positioned(
          top: bottom == null ? top : null,
          bottom: bottom,
          right: right,
          child: IgnorePointer(child: RedDot(size: size)),
        ),
    ],
  );
}

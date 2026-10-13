import 'package:flutter/widgets.dart';

/// 스크롤 격자 방어막(2026-10-13). 받은 크기가 0 이거나 끝이 없으면 격자를 그리지 않는다.
///
/// 1.0.20 Crashlytics `Infinity or NaN toInt`(`SliverGridRegularTileLayout.getMinChildIndexForScrollOffset`) —
/// 격자가 크기 0·무한 공간(화면 분할·전환 도중 등)에서 배치되면 스크롤 위치가 무한대가 되어 앱이 꺼졌다.
/// 릴리즈 빌드는 "높이 제한 없음" 검사를 건너뛰어 그대로 터진다. 한 프레임 비워 두는 편이 낫다.
class SafeGrid extends StatelessWidget {
  const SafeGrid({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final ok =
          c.maxWidth.isFinite &&
          c.maxHeight.isFinite &&
          c.maxWidth > 0 &&
          c.maxHeight > 0;
      return ok ? child : const SizedBox.shrink();
    },
  );
}

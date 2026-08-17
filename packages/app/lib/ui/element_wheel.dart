import 'dart:math' as math;

import 'package:core_models/core_models.dart';
import 'package:flutter/material.dart' hide Element;

import '../l10n/app_localizations.dart';
import 'game_dialog.dart';
import 'labels.dart';

/// 오행 관계도 — 상생(生)은 **둘레를 도는 원**, 상극(克)은 **가운데를 가로지르는 별**.
///
/// 글로만 "水克火·木生火"라고 적으면 다섯 개를 머리에 못 담는다. 이 두 관계는
/// 편성 순서(§2.3 상생 시너지)와 데미지 1.5배(상극)를 동시에 지배하는데, 그림
/// 없이는 "왜 이 순서로 짜야 하는지"가 안 보인다.
///
/// 오각형 위치가 **상생 차례**다(木→火→土→金→水→木). 그래서 이웃끼리 잇는
/// 초록 원이 곧 상생이고, 하나 건너뛰는 빨간 선이 곧 상극이 된다 — 배치 자체가
/// 규칙을 설명한다.
class ElementWheel extends StatelessWidget {
  const ElementWheel({super.key, this.size = 260, this.highlight});

  final double size;

  /// 강조할 오행(예: 다음 웨이브 속성). 이 오행이 **누구를 이기고 누구에게 지는지**만
  /// 진하게 보여 준다.
  final Element? highlight;

  /// 상생 차례대로 늘어놓은 순서. 이 순서가 곧 그림의 배치다.
  static const cycle = [
    Element.wood,
    Element.fire,
    Element.earth,
    Element.metal,
    Element.water,
  ];

  @override
  Widget build(BuildContext context) {
    final r = size / 2;
    // 아이콘 반지름만큼 안쪽으로 — 안 그러면 모서리가 잘린다.
    final ring = r - 30;
    Offset at(int i) {
      final a = -math.pi / 2 + i * 2 * math.pi / 5;
      return Offset(r + ring * math.cos(a), r + ring * math.sin(a));
    }

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _WheelPainter(
                center: Offset(r, r),
                points: [for (var i = 0; i < 5; i++) at(i)],
                highlight: highlight,
              ),
            ),
          ),
          for (var i = 0; i < 5; i++)
            Positioned(
              left: at(i).dx - 26,
              top: at(i).dy - 26,
              child: _Node(
                e: cycle[i],
                dim:
                    highlight != null &&
                    cycle[i] != highlight &&
                    !highlight!.restrains(cycle[i]) &&
                    !cycle[i].restrains(highlight!),
              ),
            ),
        ],
      ),
    );
  }
}

class _Node extends StatelessWidget {
  const _Node({required this.e, required this.dim});
  final Element e;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Opacity(
      opacity: dim ? 0.35 : 1,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF1E3B28),
              border: Border.all(color: elementColor(e), width: 2),
            ),
            child: elementIcon(e, size: 26),
          ),
          const SizedBox(height: 2),
          Text(
            elementLabel(l, e),
            style: TextStyle(
              color: elementColor(e),
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  _WheelPainter({
    required this.center,
    required this.points,
    required this.highlight,
  });

  final Offset center;
  final List<Offset> points;
  final Element? highlight;

  /// 화살표를 원 가장자리에서 시작·끝나게 줄인다(원 안으로 파고들면 지저분하다).
  (Offset, Offset) _trim(Offset a, Offset b, double pad) {
    final d = b - a;
    final len = d.distance;
    if (len <= pad * 2) return (a, b);
    final u = d / len;
    return (a + u * pad, b - u * pad);
  }

  void _arrow(Canvas c, Offset a, Offset b, Color color, double width) {
    final p = Paint()
      ..color = color
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    c.drawLine(a, b, p);
    // 화살촉 — 방향이 없으면 "누가 누구를"이 안 읽힌다.
    final ang = math.atan2(b.dy - a.dy, b.dx - a.dx);
    const head = 9.0;
    final path = Path()
      ..moveTo(b.dx, b.dy)
      ..lineTo(
        b.dx - head * math.cos(ang - 0.42),
        b.dy - head * math.sin(ang - 0.42),
      )
      ..lineTo(
        b.dx - head * math.cos(ang + 0.42),
        b.dy - head * math.sin(ang + 0.42),
      )
      ..close();
    c.drawPath(path, Paint()..color = color);
  }

  @override
  void paint(Canvas canvas, Size size) {
    const cyc = ElementWheel.cycle;
    // 상생 — 이웃끼리(둘레). 초록.
    for (var i = 0; i < 5; i++) {
      final from = cyc[i], to = cyc[(i + 1) % 5];
      final on = highlight == null || from == highlight || to == highlight;
      final (a, b) = _trim(points[i], points[(i + 1) % 5], 30);
      _arrow(
        canvas,
        a,
        b,
        const Color(0xFF7CE38B).withValues(alpha: on ? 0.95 : 0.18),
        on ? 3 : 2,
      );
    }
    // 상극 — 하나 건너뛰기(가운데를 가로지른다). 빨강.
    for (var i = 0; i < 5; i++) {
      final from = cyc[i], to = cyc[(i + 2) % 5];
      assert(from.restrains(to), '오각형 배치가 상생 차례여야 한 칸 건너 = 상극이다');
      final on = highlight == null || from == highlight || to == highlight;
      final (a, b) = _trim(points[i], points[(i + 2) % 5], 30);
      _arrow(
        canvas,
        a,
        b,
        const Color(0xFFFF6B6B).withValues(alpha: on ? 0.95 : 0.14),
        on ? 3 : 2,
      );
    }
  }

  @override
  bool shouldRepaint(_WheelPainter old) => old.highlight != highlight;
}

/// 오행 관계도를 띄운다. [highlight] 를 주면 그 오행의 상극 관계만 진하게 보인다.
Future<void> showElementWheel(BuildContext context, {Element? highlight}) {
  final l = AppLocalizations.of(context);
  return showGameDialog<void>(
    context,
    title: l.elementWheelTitle,
    icon: Icons.hub_rounded,
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ElementWheel(highlight: highlight),
        const SizedBox(height: 10),
        _legend(const Color(0xFFFF6B6B), l.elementWheelRestrain),
        const SizedBox(height: 4),
        _legend(const Color(0xFF7CE38B), l.elementWheelGenerate),
      ],
    ),
    actions: [gameDialogButton(l.actionClose, () => Navigator.pop(context))],
  );
}

Widget _legend(Color c, String text) => Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    Container(width: 18, height: 3, color: c),
    const SizedBox(width: 6),
    Flexible(
      child: Text(
        text,
        style: const TextStyle(color: Color(0xDDFFFFFF), fontSize: 12),
      ),
    ),
  ],
);

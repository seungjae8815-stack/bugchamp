import 'package:core_run/core_run.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// 스테이지 로드맵 — **아래(하위) → 위(상위)** 로 올라가는 징검다리.
///
/// 칸 하나 = `nodeStep`(기본 10) 스테이지. 한 월드(100)는 **2줄 × 5칸**이고,
/// 줄마다 방향이 바뀌어(← →) 뱀처럼 이어진다. `x-100` 은 월드 보스(뿔 테두리),
/// 마지막 `10-100` 은 맨 위 중앙에 크게 = 최종 보스.
///
/// 탭하면 그 스테이지로 이동(pop 으로 스테이지 번호 반환). 아직 도달하지 못한
/// 칸은 잠겨 있다.
class RoadmapScreen extends StatefulWidget {
  const RoadmapScreen({
    super.key,
    required this.config,
    required this.runConfig,
    required this.highestStage,
    required this.liveStage,
  });

  final RoadmapConfig config;

  /// 월드 크기(x-100 판정)·"1-30" 라벨 계산에 필요.
  final RunConfig runConfig;

  final int highestStage;
  final int liveStage;

  @override
  State<RoadmapScreen> createState() => _RoadmapScreenState();
}

/// 로드맵 칸 하나.
class _Node {
  const _Node({
    required this.stage,
    required this.chapter,
    required this.isWorldBoss,
  });

  /// 이 칸이 대표하는 **절대 스테이지**(= 구간의 마지막). 예: 1-30 → 30.
  final int stage;
  final RoadmapChapter chapter;

  /// 월드 마지막 칸(x-100) — 다음 월드로 가는 관문 보스.
  final bool isWorldBoss;
}

class _RoadmapScreenState extends State<RoadmapScreen> {
  final _scroll = ScrollController();
  bool _jumped = false;

  /// 한 줄에 놓는 칸 수(월드 10칸 = 2줄).
  static const _cols = 5;
  // 줄 간격. 보스 칸(68) + 라벨 알약(26) 이 아래 칸을 침범하지 않는 최소치.
  static const _cellH = 100.0;
  static const _cellSize = 56.0;
  // 뿔·가시 여백(_bossInsetFrac)을 빼고도 본체가 일반 칸(56)보다 커야 한다.
  // 가장 좁은 폰(360dp → 칸너비 72)에서도 이웃 칸을 침범하지 않는 상한.
  static const _bossCellSize = 68.0;
  static const _finalRowH = 168.0;
  static const _finalSize = 116.0;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// 전 월드의 칸을 스테이지 오름차순으로 편다.
  List<_Node> _buildNodes() {
    final step = widget.config.nodeStep;
    final worldSize = widget.runConfig.worldSize;
    final out = <_Node>[];
    for (final c in widget.config.chapters) {
      for (var s = c.startStage + step - 1; s <= c.endStage; s += step) {
        out.add(
          _Node(
            stage: s,
            chapter: c,
            isWorldBoss: worldSize > 0 && s % worldSize == 0,
          ),
        );
      }
    }
    return out;
  }

  /// "1-30" 표기. 월드 미설정이면 절대 스테이지 그대로.
  String _label(int stage) {
    final rc = widget.runConfig;
    if (rc.worldSize <= 0) return '$stage';
    return '${rc.worldOf(stage)}-${rc.stageInWorld(stage)}';
  }

  /// 칸의 중심 좌표(격자 원점 = 좌상단). [row] 는 **아래에서 0**.
  Offset _center(int row, int col, double width, double gridH) {
    final cellW = width / _cols;
    // 짝수 줄은 왼→오, 홀수 줄은 오→왼(뱀 모양) — 줄이 바뀔 때 세로로 이어진다.
    final c = row.isEven ? col : (_cols - 1 - col);
    return Offset(
      cellW * (c + 0.5),
      gridH - _cellH * (row + 0.5), // 아래가 하위 스테이지
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final all = _buildNodes();
    if (all.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(l.roadmapTitle)),
        body: Center(child: Text(l.comingSoon)),
      );
    }

    // 최종 보스는 격자에서 빼고 맨 위 중앙에 따로 그린다.
    final finalNode = all.last;
    final grid = all.sublist(0, all.length - 1);
    final rows = (grid.length / _cols).ceil();
    final gridH = rows * _cellH;

    return Scaffold(
      appBar: AppBar(title: Text(l.roadmapTitle)),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final totalH = gridH + _finalRowH;

          // 첫 프레임: 현재 위치가 화면 중앙에 오도록 스크롤.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_jumped || !_scroll.hasClients) return;
            _jumped = true;
            final idx = _currentIndex(all);
            final y = idx >= grid.length
                ? 0.0
                : _finalRowH +
                      _center(idx ~/ _cols, idx % _cols, width, gridH).dy;
            final target = y - constraints.maxHeight / 2;
            _scroll.jumpTo(target.clamp(0.0, _scroll.position.maxScrollExtent));
          });

          return SingleChildScrollView(
            controller: _scroll,
            // 시스템 내비게이션 바에 맨 아래 칸이 가리지 않게.
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewPaddingOf(context).bottom + 16,
            ),
            child: SizedBox(
              width: width,
              height: totalH,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.asset(
                      'assets/images/ui/roadmap_bg.webp',
                      fit: BoxFit.cover,
                      repeat: ImageRepeat.repeatY,
                      alignment: Alignment.bottomCenter,
                    ),
                  ),
                  const Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: Color(0x59000000)),
                    ),
                  ),
                  // 칸을 잇는 길(점선).
                  Positioned(
                    top: _finalRowH,
                    left: 0,
                    right: 0,
                    height: gridH,
                    child: CustomPaint(
                      painter: _PathPainter(
                        points: [
                          for (var i = 0; i < grid.length; i++)
                            _center(i ~/ _cols, i % _cols, width, gridH),
                        ],
                        clearedUpTo: _clearedCount(grid),
                      ),
                      size: Size(width, gridH),
                    ),
                  ),
                  // 최종 보스로 올라가는 마지막 한 칸.
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: _finalRowH + _cellH,
                    child: CustomPaint(
                      painter: _PathPainter(
                        points: [
                          Offset(width / 2, _finalRowH * 0.52),
                          _center(
                                (grid.length - 1) ~/ _cols,
                                (grid.length - 1) % _cols,
                                width,
                                gridH,
                              ) +
                              Offset(0, _finalRowH),
                        ],
                        clearedUpTo: widget.highestStage > finalNode.stage
                            ? 2
                            : 0,
                      ),
                      size: Size(width, _finalRowH + _cellH),
                    ),
                  ),
                  // 격자 칸들.
                  for (var i = 0; i < grid.length; i++)
                    _positioned(
                      grid[i],
                      _center(i ~/ _cols, i % _cols, width, gridH) +
                          const Offset(0, _finalRowH),
                      locale,
                      l,
                    ),
                  // 최종 보스.
                  _positioned(
                    finalNode,
                    Offset(width / 2, _finalRowH * 0.52),
                    locale,
                    l,
                    isFinal: true,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// 아직 클리어하지 못한 첫 칸의 인덱스(= 지금 도전 중인 칸).
  int _currentIndex(List<_Node> nodes) {
    for (var i = 0; i < nodes.length; i++) {
      if (widget.liveStage <= nodes[i].stage) return i;
    }
    return nodes.length - 1;
  }

  int _clearedCount(List<_Node> nodes) {
    var n = 0;
    for (final node in nodes) {
      if (widget.highestStage > node.stage) n++;
    }
    return n;
  }

  Widget _positioned(
    _Node node,
    Offset center,
    String locale,
    AppLocalizations l, {
    bool isFinal = false,
  }) {
    final size = isFinal
        ? _finalSize
        : (node.isWorldBoss ? _bossCellSize : _cellSize);
    // 라벨(어두운 알약) 높이까지 포함한 박스 — 좌표는 칸의 중심 기준.
    // 키울 땐 _cellH 도 함께 봐야 한다(줄 간격을 넘으면 위아래 칸과 겹친다).
    const labelH = 26.0;
    return Positioned(
      left: center.dx - size / 2,
      top: center.dy - size / 2,
      width: size,
      height: size + labelH,
      child: _NodeTile(
        node: node,
        size: size,
        isFinal: isFinal,
        label: _label(node.stage),
        cleared: widget.highestStage > node.stage,
        unlocked: widget.highestStage >= node.stage,
        isHere: _isHere(node),
        bossName: node.chapter.boss.resolve(locale),
        onTap: () => Navigator.pop(context, node.stage),
      ),
    );
  }

  /// 지금 캐릭터가 서 있는 칸인지(구간 안에 liveStage 가 있는지).
  bool _isHere(_Node node) {
    final step = widget.config.nodeStep;
    return widget.liveStage > node.stage - step &&
        widget.liveStage <= node.stage;
  }
}

/// 칸 하나의 그림 — 네모(징검다리) + 상태 표시 + 라벨.
class _NodeTile extends StatelessWidget {
  const _NodeTile({
    required this.node,
    required this.size,
    required this.isFinal,
    required this.label,
    required this.cleared,
    required this.unlocked,
    required this.isHere,
    required this.bossName,
    required this.onTap,
  });

  final _Node node;
  final double size;
  final bool isFinal;
  final String label;
  final bool cleared;
  final bool unlocked;
  final bool isHere;
  final String bossName;
  final VoidCallback onTap;

  static const _gold = Color(0xFFFFD24A);

  /// 보스 칸 전용 핏빛 — 챕터색과 무관하게 "여긴 보스다"를 색으로 먼저 알린다.
  static const _demon = Color(0xFFD1443E);

  @override
  Widget build(BuildContext context) {
    final isBoss = node.isWorldBoss || isFinal;
    final color = Color(node.chapter.color);
    final border = cleared
        ? _gold
        : (isHere
              ? Colors.white
              : isBoss
              ? _demon
              : (unlocked ? color : const Color(0x66FFFFFF)));

    Widget tile = Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        // 네모칸(징검다리). 보스는 살짝 더 둥글게 강조.
        borderRadius: BorderRadius.circular(isFinal ? 22 : 12),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: unlocked
              ? [color.withValues(alpha: 0.95), color.withValues(alpha: 0.55)]
              // 잠긴 보스 칸은 회색으로 덮지 않는다 — 핏빛 테두리와 붙었을 때
              // 챕터색이 옅게 남아 있어야 "잠긴 회색 칸"과 구분된다.
              : isBoss
              ? [color.withValues(alpha: 0.45), color.withValues(alpha: 0.20)]
              : [const Color(0xFF39403A), const Color(0xFF1B211D)],
        ),
        border: Border.all(
          color: border,
          width: isBoss || cleared || isHere ? 3 : 2,
        ),
        boxShadow: [
          if (isHere || isFinal)
            BoxShadow(
              color: (isFinal ? _gold : Colors.white).withValues(alpha: 0.55),
              blurRadius: isFinal ? 22 : 14,
            )
          else if (isBoss)
            BoxShadow(color: _demon.withValues(alpha: 0.45), blurRadius: 12),
        ],
      ),
      child: _inner(),
    );

    if (isBoss) {
      // 뿔·가시는 칸 안쪽 여백에 그린다 — 바깥으로 삐져나가면 상위 Stack 이 잘라낸다.
      tile = Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _BossFrame(border))),
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.all(size * _bossInsetFrac),
              child: tile,
            ),
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: unlocked ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: size, height: size, child: tile),
          const SizedBox(height: 2),
          // 배경 일러스트 위에 흰 글씨만 얹으면 밝은 부분에서 사라진다 —
          // 어두운 알약을 깔아 배경과 무관하게 읽히게 한다.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: const Color(0xC2000000),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              isFinal ? bossName : label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isFinal
                    ? _gold
                    : (unlocked ? Colors.white : const Color(0xCCFFFFFF)),
                fontWeight: FontWeight.w900,
                fontSize: isFinal ? 16 : 12.5,
                letterSpacing: isFinal ? 0.3 : 0,
                shadows: const [Shadow(color: Colors.black, blurRadius: 2)],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _inner() {
    // ★ 보스 칸(x-100)·최종 보스.
    //
    //   실제 보스 스프라이트를 쓰지 않는다: 보스 아트가 4장뿐인데 25스테이지
    //   주기로 순환해서 **10개 챕터에 같은 그림이 반복**된다(초반 구간은 전부
    //   oak_forest = 벌 한 마리). 정체를 감추고 "여긴 보스"만 알리는 편이
    //   목표로 읽히고, 아트가 늘어나도 이 화면은 손댈 필요가 없다.
    if (node.isWorldBoss || isFinal) {
      final Widget mark;
      if (cleared) {
        mark = Icon(
          Icons.check_circle_rounded,
          color: _gold,
          size: size * 0.28,
        );
      } else if (unlocked) {
        mark = Text('👹', style: TextStyle(fontSize: size * 0.30));
      } else {
        // 잠김 — 자물쇠는 일반 칸과 같은 크기로 둔다(작은 배지로 줄이지 않는다).
        mark = Icon(
          Icons.lock_rounded,
          color: const Color(0xE6FFFFFF),
          size: size * 0.28,
        );
      }
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isFinal) Text('👑', style: TextStyle(fontSize: size * 0.16)),
          mark,
          Text(
            'BOSS',
            style: TextStyle(
              color: unlocked ? Colors.white : const Color(0xCCFFFFFF),
              fontWeight: FontWeight.w900,
              fontSize: size * 0.155,
              letterSpacing: 0.6,
              height: 1.1,
              shadows: const [Shadow(color: Colors.black, blurRadius: 3)],
            ),
          ),
        ],
      );
    }
    if (!unlocked) {
      return Icon(
        Icons.lock_rounded,
        color: const Color(0xCCFFFFFF),
        size: size * 0.36,
      );
    }
    if (cleared) {
      return Icon(Icons.check_rounded, color: _gold, size: size * 0.44);
    }
    // 진행 중/미클리어 일반 칸 — 라벨은 아래에 있으니 여기선 표식만.
    return Text(
      label.split('-').last,
      style: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w900,
        fontSize: size * 0.36,
        shadows: const [
          Shadow(color: Colors.black, blurRadius: 4),
          Shadow(color: Colors.black54, offset: Offset(0, 1), blurRadius: 2),
        ],
      ),
    );
  }
}

/// 보스 칸 본체가 물러나는 여백 비율 — 그 여백에 뿔·가시를 그린다.
/// 본체가 일반 칸(56)보다 작아지지 않게 `_bossCellSize` 와 함께 조정할 것.
const _bossInsetFrac = 0.08;

/// 보스 칸 테두리 장식 — 위쪽 뿔 2개 + 좌우 가시 3쌍.
/// 일반 칸의 밋밋한 네모와 실루엣만으로 구분되게 해서, 스크롤로 훑을 때
/// "저기가 보스"가 글자를 읽기 전에 먼저 보이게 한다.
class _BossFrame extends CustomPainter {
  const _BossFrame(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color;
    final w = size.width;
    final h = size.height;
    final inset = w * _bossInsetFrac;

    // 뿔 — 위 양옆 모서리에서 바깥 위로.
    for (final left in const [true, false]) {
      final x = left ? inset : w - inset;
      final dir = left ? -1.0 : 1.0;
      canvas.drawPath(
        Path()
          ..moveTo(x + dir * w * 0.02, inset * 1.5)
          ..lineTo(x + dir * w * 0.09, 0)
          ..lineTo(x + dir * w * 0.14, inset * 1.9)
          ..close(),
        p,
      );
    }

    // 좌우 가시.
    final spike = w * 0.055;
    for (final t in const [0.40, 0.60, 0.80]) {
      final y = h * t;
      for (final left in const [true, false]) {
        final x = left ? inset : w - inset;
        final dir = left ? -1.0 : 1.0;
        canvas.drawPath(
          Path()
            ..moveTo(x, y - spike)
            ..lineTo(x + dir * inset * 0.95, y)
            ..lineTo(x, y + spike)
            ..close(),
          p,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_BossFrame old) => old.color != color;
}

/// 칸과 칸을 잇는 점선 길. 클리어한 구간은 금색, 나머지는 흐리게.
class _PathPainter extends CustomPainter {
  const _PathPainter({required this.points, required this.clearedUpTo});

  final List<Offset> points;

  /// 앞에서부터 몇 개의 칸이 클리어됐는지(그만큼의 선을 금색으로).
  final int clearedUpTo;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i + 1 < points.length; i++) {
      final done = i + 1 < clearedUpTo;
      final paint = Paint()
        ..color = done ? const Color(0xCCFFD24A) : const Color(0x66FFFFFF)
        ..strokeWidth = done ? 4 : 3
        ..strokeCap = StrokeCap.round;
      _dashed(canvas, points[i], points[i + 1], paint);
    }
  }

  /// 징검다리 느낌의 점선.
  void _dashed(Canvas canvas, Offset a, Offset b, Paint paint) {
    const dash = 7.0;
    const gap = 6.0;
    final total = (b - a).distance;
    if (total <= 0) return;
    final dir = (b - a) / total;
    var t = 0.0;
    while (t < total) {
      final end = (t + dash).clamp(0.0, total);
      canvas.drawLine(a + dir * t, a + dir * end, paint);
      t = end + gap;
    }
  }

  @override
  bool shouldRepaint(_PathPainter old) =>
      old.clearedUpTo != clearedUpTo || old.points.length != points.length;
}

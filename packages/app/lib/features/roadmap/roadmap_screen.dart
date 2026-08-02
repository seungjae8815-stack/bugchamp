import 'dart:math' as math;

import 'package:core_run/core_run.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../ui/art.dart';

/// 난이도 챕터 로드맵 — 세로 여정 배경(초원→계곡→숲→밤산) 위에 챕터 노드와
/// 내 캐릭터를 얹는다. 아래(쉬움)→위(극한). 챕터 탭 → 해당 스테이지로 이동(pop 반환).
/// [highestStage] 최고 도달, [liveStage] 현재 위치.
class RoadmapScreen extends StatefulWidget {
  const RoadmapScreen({
    super.key,
    required this.config,
    required this.highestStage,
    required this.liveStage,
  });

  final RoadmapConfig config;
  final int highestStage;
  final int liveStage;

  @override
  State<RoadmapScreen> createState() => _RoadmapScreenState();
}

class _RoadmapScreenState extends State<RoadmapScreen> {
  final _scroll = ScrollController();
  bool _jumped = false;

  /// 배경 이미지 원본 비율(assets/images/ui/roadmap_bg.webp = 1536x2752).
  static const double _imgAspect = 1536 / 2752;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// liveStage 를 포함하는 챕터(없으면 최고 해금 챕터)의 인덱스.
  int _currentIndex(List<RoadmapChapter> chapters) {
    var cur = 0;
    for (var i = 0; i < chapters.length; i++) {
      if (chapters[i].contains(widget.liveStage)) return i;
      if (chapters[i].unlockedBy(widget.highestStage)) cur = i;
    }
    return cur;
  }

  /// 챕터 i 의 배경 위 세로 위치(0=최상단 극한 … 1=최하단 쉬움).
  double _topFrac(int i, int n) =>
      n <= 1 ? 0.5 : 0.87 - (i / (n - 1)) * (0.87 - 0.15);

  /// 가로 위치 — 길을 따라 살짝 지그재그.
  double _leftFrac(int i) => 0.5 + (i.isEven ? -0.05 : 0.08);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final chapters = widget.config.chapters;
    final n = chapters.length;
    final curIndex = _currentIndex(chapters);

    return Scaffold(
      appBar: AppBar(title: Text(l.roadmapTitle)),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          // 배경은 화면 너비 기준 전체 높이. 뷰포트보다 작으면 뷰포트로 채움.
          final h = math.max(width / _imgAspect, constraints.maxHeight);

          // 첫 프레임: 현재 챕터가 화면 중앙에 오도록 스크롤.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_jumped || !_scroll.hasClients) return;
            _jumped = true;
            final target =
                (_topFrac(curIndex, n) * h) - constraints.maxHeight / 2;
            _scroll.jumpTo(
              target.clamp(0.0, _scroll.position.maxScrollExtent),
            );
          });

          return SingleChildScrollView(
            controller: _scroll,
            child: SizedBox(
              width: width,
              height: h,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.asset(
                      'assets/images/ui/roadmap_bg.webp',
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                    ),
                  ),
                  // 가독성용 약한 상·하단 스크림.
                  const Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0x33000000),
                            Color(0x00000000),
                            Color(0x22000000),
                          ],
                          stops: [0.0, 0.35, 1.0],
                        ),
                      ),
                    ),
                  ),
                  for (var i = 0; i < n; i++)
                    _nodeAt(i, n, chapters[i], width, h, locale, l),
                  _characterAt(curIndex, n, width, h),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _nodeAt(
    int i,
    int n,
    RoadmapChapter c,
    double width,
    double h,
    String locale,
    AppLocalizations l,
  ) {
    const boxW = 132.0;
    final left = (_leftFrac(i) * width) - boxW / 2;
    return Positioned(
      left: left.clamp(2.0, width - boxW - 2),
      top: (_topFrac(i, n) * h) - 34,
      width: boxW,
      child: _ChapterNode(
        chapter: c,
        locale: locale,
        l: l,
        highestStage: widget.highestStage,
        liveStage: widget.liveStage,
        onEnter: (stage) => Navigator.pop(context, stage),
      ),
    );
  }

  Widget _characterAt(int curIndex, int n, double width, double h) {
    const size = 58.0;
    // 현재 챕터 노드의 왼쪽에 캐릭터가 서 있게.
    final left = (_leftFrac(curIndex) * width) - 66 - size;
    return Positioned(
      left: left.clamp(2.0, width - size - 2),
      top: (_topFrac(curIndex, n) * h) - size / 2 - 6,
      child: IgnorePointer(
        child: characterSprite(
          size: size,
          fallback: const Text('🐛', style: TextStyle(fontSize: 34)),
        ),
      ),
    );
  }
}

/// 로드맵 위 챕터 하나 — 상태 메달 + 난이도/진행 라벨. 탭하면 입장.
class _ChapterNode extends StatelessWidget {
  const _ChapterNode({
    required this.chapter,
    required this.locale,
    required this.l,
    required this.highestStage,
    required this.liveStage,
    required this.onEnter,
  });

  final RoadmapChapter chapter;
  final String locale;
  final AppLocalizations l;
  final int highestStage;
  final int liveStage;
  final ValueChanged<int> onEnter;

  @override
  Widget build(BuildContext context) {
    final color = Color(chapter.color);
    final cleared = chapter.clearedBy(highestStage);
    final unlocked = chapter.unlockedBy(highestStage);
    final isCurrent = unlocked && !cleared;
    final hereInside = chapter.contains(liveStage);
    final progress = chapter.progressBy(highestStage);

    void tap() {
      if (!unlocked) return;
      // 라이브 위치가 이 챕터면 이어하기, 아니면 챕터 시작으로 재도전.
      onEnter(hereInside ? liveStage : chapter.startStage);
    }

    return GestureDetector(
      onTap: tap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 상태 메달.
          Container(
            width: 60,
            height: 60,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: unlocked
                    ? [
                        color.withValues(alpha: 0.95),
                        color.withValues(alpha: 0.5),
                      ]
                    : [const Color(0xFF3A403C), const Color(0xFF1A1F1D)],
              ),
              border: Border.all(
                color: cleared
                    ? const Color(0xFFFFD24A)
                    : (unlocked ? Colors.white : const Color(0x66FFFFFF)),
                width: cleared ? 3 : 2,
              ),
              boxShadow: [
                if (isCurrent)
                  BoxShadow(
                    color: color.withValues(alpha: 0.8),
                    blurRadius: 16,
                    spreadRadius: 1,
                  ),
                const BoxShadow(
                  color: Color(0x99000000),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              cleared ? '✓' : (unlocked ? '👑' : '🔒'),
              style: TextStyle(
                fontSize: cleared ? 26 : 22,
                fontWeight: FontWeight.w900,
                color: cleared ? const Color(0xFFFFF3D0) : Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 5),
          // 난이도 + 진행 라벨(배경 위 가독성용 어두운 패널).
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xCC0A1206),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: unlocked ? color : const Color(0x44FFFFFF),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  chapter.difficulty.resolve(locale),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  unlocked
                      ? l.roadmapProgress(progress, chapter.stageCount)
                      : l.roadmapLocked,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: unlocked ? color : const Color(0x99FFFFFF),
                    fontWeight: FontWeight.w700,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

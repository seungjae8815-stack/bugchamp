import 'package:core_run/core_run.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// 난이도 챕터 로드맵(세로 경로). 챕터 탭 → 해당 스테이지로 이동(pop 으로 반환).
/// [highestStage] 최고 도달, [liveStage] 현재 위치.
class RoadmapScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final chapters = config.chapters;
    return Scaffold(
      appBar: AppBar(title: Text(l.roadmapTitle)),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        itemCount: chapters.length,
        itemBuilder: (context, i) {
          final c = chapters[i];
          return _ChapterNode(
            chapter: c,
            locale: locale,
            l: l,
            highestStage: highestStage,
            liveStage: liveStage,
            isFirst: i == 0,
            isLast: i == chapters.length - 1,
            onEnter: (stage) => Navigator.pop(context, stage),
          );
        },
      ),
    );
  }
}

class _ChapterNode extends StatelessWidget {
  const _ChapterNode({
    required this.chapter,
    required this.locale,
    required this.l,
    required this.highestStage,
    required this.liveStage,
    required this.isFirst,
    required this.isLast,
    required this.onEnter,
  });

  final RoadmapChapter chapter;
  final String locale;
  final AppLocalizations l;
  final int highestStage;
  final int liveStage;
  final bool isFirst;
  final bool isLast;
  final ValueChanged<int> onEnter;

  @override
  Widget build(BuildContext context) {
    final color = Color(chapter.color);
    final cleared = chapter.clearedBy(highestStage);
    final unlocked = chapter.unlockedBy(highestStage);
    final isCurrent = unlocked && !cleared;
    final progress = chapter.progressBy(highestStage);
    final hereInside = chapter.contains(liveStage);

    // 상태 칩.
    final (String chipText, Color chipColor) = cleared
        ? (l.roadmapCleared, const Color(0xFF6FCF6F))
        : isCurrent
        ? (l.roadmapCurrent, color)
        : (l.roadmapLocked, const Color(0xFF7A7A7A));

    void tap() {
      if (!unlocked) return;
      // 현재 진행 중인 챕터(라이브 위치 포함)면 이어하기, 아니면 그 챕터 시작으로 재도전.
      onEnter(hereInside ? liveStage : chapter.startStage);
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 좌측 경로 + 보스 메달.
          SizedBox(
            width: 64,
            child: Column(
              children: [
                _connector(!isFirst, color, cleared || unlocked),
                _bossMedal(color, cleared, isCurrent, unlocked),
                Expanded(child: _connector(!isLast, color, cleared)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // 우측 카드.
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: GestureDetector(
                onTap: tap,
                child: Opacity(
                  opacity: unlocked ? 1 : 0.55,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          color.withValues(alpha: unlocked ? 0.22 : 0.08),
                          const Color(0xE60A1206),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: unlocked ? color : const Color(0x33FFFFFF),
                        width: isCurrent ? 2 : 1.3,
                      ),
                      boxShadow: isCurrent
                          ? [
                              BoxShadow(
                                color: color.withValues(alpha: 0.4),
                                blurRadius: 12,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                chapter.difficulty.resolve(locale),
                                style: TextStyle(
                                  color: unlocked
                                      ? Colors.white
                                      : Colors.white70,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 19,
                                ),
                              ),
                            ),
                            _chip(chipText, chipColor),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l.roadmapStageRange(
                            chapter.startStage,
                            chapter.endStage,
                          ),
                          style: const TextStyle(
                            color: Color(0x99FFFFFF),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Text('👑', style: TextStyle(fontSize: 14)),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                unlocked ? chapter.boss.resolve(locale) : '???',
                                style: TextStyle(
                                  color: unlocked
                                      ? const Color(0xFFFFD977)
                                      : const Color(0x88FFFFFF),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Text(
                              l.roadmapFinalBoss,
                              style: const TextStyle(
                                color: Color(0x88FFFFFF),
                                fontSize: 10.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // 진행 바.
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: progress / chapter.stageCount,
                            minHeight: 8,
                            backgroundColor: const Color(0x33000000),
                            valueColor: AlwaysStoppedAnimation(color),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              l.roadmapProgress(progress, chapter.stageCount),
                              style: const TextStyle(
                                color: Color(0xCCFFFFFF),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (unlocked)
                              Text(
                                hereInside ? l.roadmapEnter : l.roadmapReplay,
                                style: TextStyle(
                                  color: color,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _connector(bool show, Color color, bool active) => SizedBox(
    width: 4,
    height: 14,
    child: show
        ? Container(
            width: 4,
            decoration: BoxDecoration(
              color: active
                  ? color.withValues(alpha: 0.6)
                  : const Color(0x33FFFFFF),
              borderRadius: BorderRadius.circular(2),
            ),
          )
        : null,
  );

  Widget _bossMedal(Color color, bool cleared, bool current, bool unlocked) {
    return Container(
      width: 52,
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: unlocked
              ? [color.withValues(alpha: 0.9), color.withValues(alpha: 0.35)]
              : [const Color(0xFF33393B), const Color(0xFF1A1F1D)],
        ),
        border: Border.all(
          color: cleared
              ? const Color(0xFFFFD24A)
              : (unlocked ? Colors.white : const Color(0x55FFFFFF)),
          width: cleared ? 2.5 : 1.5,
        ),
        boxShadow: current
            ? [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 12)]
            : null,
      ),
      child: Text(
        cleared ? '✓' : (unlocked ? '👑' : '🔒'),
        style: TextStyle(
          fontSize: cleared ? 24 : 20,
          fontWeight: FontWeight.w900,
          color: cleared ? const Color(0xFFFFF0C0) : Colors.white,
        ),
      ),
    );
  }

  Widget _chip(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.25),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color),
    ),
    child: Text(
      text,
      style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 11),
    ),
  );
}

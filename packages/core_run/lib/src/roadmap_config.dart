import 'package:core_models/core_models.dart';
import 'package:meta/meta.dart';

/// 난이도 챕터 1개(로드맵). 스테이지 구간 + 최종보스 (JSON, §6).
@immutable
class RoadmapChapter {
  const RoadmapChapter({
    required this.id,
    required this.difficulty,
    required this.boss,
    required this.startStage,
    required this.endStage,
    required this.color,
    this.rewardGold = 0,
    this.rewardJelly = 0,
    this.rewardChitin = 0,
    this.rewardMineral = 0,
    this.rewardSap = 0,
  });

  final String id;

  /// 난이도 표기(쉬움/보통/어려움/극한).
  final LocalizedText difficulty;

  /// 챕터 최종보스 이름.
  final LocalizedText boss;

  /// 이 챕터의 스테이지 범위(포함).
  final int startStage;
  final int endStage;

  /// 대표색(ARGB int).
  final int color;

  /// 첫 클리어 보상.
  final int rewardGold;
  final int rewardJelly;
  final int rewardChitin;
  final int rewardMineral;
  final int rewardSap;

  Map<MaterialKind, int> get rewardMaterials => {
    if (rewardChitin > 0) MaterialKind.chitin: rewardChitin,
    if (rewardMineral > 0) MaterialKind.mineral: rewardMineral,
    if (rewardSap > 0) MaterialKind.sap: rewardSap,
    if (rewardJelly > 0) MaterialKind.jelly: rewardJelly,
  };

  int get stageCount => endStage - startStage + 1;

  bool contains(int stage) => stage >= startStage && stage <= endStage;

  /// [highest] 최고 도달 스테이지 기준, 이 챕터를 클리어했는지(최종보스 통과).
  bool clearedBy(int highest) => highest > endStage;

  /// 진입 가능(잠금 해제)? 시작 스테이지에 도달했으면 열림.
  bool unlockedBy(int highest) => highest >= startStage;

  /// 챕터 내 진행 스테이지 수(0~stageCount).
  int progressBy(int highest) =>
      (highest - startStage + 1).clamp(0, stageCount);

  factory RoadmapChapter.fromJson(Map<String, dynamic> json) {
    final c = json['color'] as String? ?? '0xFF888888';
    return RoadmapChapter(
      id: json['id'] as String,
      difficulty: LocalizedText.fromJson(
        json['difficulty'] as Map<String, dynamic>,
      ),
      boss: LocalizedText.fromJson(json['boss'] as Map<String, dynamic>),
      startStage: (json['startStage'] as num).toInt(),
      endStage: (json['endStage'] as num).toInt(),
      color: int.parse(c.startsWith('0x') ? c.substring(2) : c, radix: 16),
      rewardGold: (json['rewardGold'] as num?)?.toInt() ?? 0,
      rewardJelly: (json['rewardJelly'] as num?)?.toInt() ?? 0,
      rewardChitin: (json['rewardChitin'] as num?)?.toInt() ?? 0,
      rewardMineral: (json['rewardMineral'] as num?)?.toInt() ?? 0,
      rewardSap: (json['rewardSap'] as num?)?.toInt() ?? 0,
    );
  }
}

/// 로드맵 전체 설정 (assets/data/roadmap.json).
@immutable
class RoadmapConfig {
  const RoadmapConfig({required this.chapters});

  final List<RoadmapChapter> chapters;

  /// 캠페인 총 스테이지(마지막 챕터 endStage). 이후는 확장.
  int get finalStage => chapters.isEmpty ? 0 : chapters.last.endStage;

  RoadmapChapter? chapterForStage(int stage) {
    for (final c in chapters) {
      if (c.contains(stage)) return c;
    }
    return chapters.isNotEmpty && stage > chapters.last.endStage
        ? chapters.last
        : null;
  }

  factory RoadmapConfig.fromJson(Map<String, dynamic> json) => RoadmapConfig(
    chapters: (json['chapters'] as List)
        .cast<Map<String, dynamic>>()
        .map(RoadmapChapter.fromJson)
        .toList(),
  );
}

import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:flutter/material.dart';

import 'labels.dart';

/// 아트 플레이스홀더 + **AI 교체 훅**.
/// 지정 경로에 이미지 파일이 있으면 표시하고, 없으면 이모지/그라데이션으로 폴백한다.
/// 파일명·경로 규칙은 `assets/images/{카테고리}/_README.txt` 참고.

const _skyTop = Color(0xFFFCE8B6);
const _skyBottom = Color(0xFFF3CE86);
const _moss = Color(0xFF56813F);
const _soil = Color(0xFF3E2C1A);

/// 지정 asset 이 있으면 이미지, 없으면 [fallback]. (AI 아트 교체 훅)
Widget gameImage(
  String assetPath, {
  required double width,
  required double height,
  required Widget fallback,
  BoxFit fit = BoxFit.contain,
}) {
  return Image.asset(
    assetPath,
    width: width,
    height: height,
    fit: fit,
    filterQuality: FilterQuality.medium,
    errorBuilder: (_, _, _) => fallback,
  );
}

/// 여러 후보 경로를 순서대로 시도해 처음 존재하는 이미지를 표시, 다 없으면 [fallback].
/// 프레임 애니메이션용: `attack_1.webp` → `attack.webp` → `idle.webp` → 이모지 식으로 폴백.
Widget gameImageChain(
  List<String> paths, {
  required double size,
  required Widget fallback,
  BoxFit fit = BoxFit.contain,
  bool byHeight = false,
}) {
  if (paths.isEmpty) return fallback;
  return Image.asset(
    paths.first,
    width: byHeight ? null : size,
    height: size,
    fit: byHeight ? BoxFit.fitHeight : fit,
    filterQuality: FilterQuality.medium,
    errorBuilder: (_, _, _) => gameImageChain(
      paths.sublist(1),
      size: size,
      fallback: fallback,
      fit: fit,
      byHeight: byHeight,
    ),
  );
}

/// 캐릭터 스프라이트. assets/images/character/idle.webp
Widget characterSprite({required double size, required Widget fallback}) =>
    gameImage(
      'assets/images/character/idle.webp',
      width: size,
      height: size,
      fallback: fallback,
    );

/// 서식지 스프라이트. `assets/images/habitats/{kind}.webp`
Widget habitatSprite(
  HabitatKind kind, {
  required double size,
  required Widget fallback,
}) => gameImage(
  'assets/images/habitats/${kind.key}.webp',
  width: size,
  height: size,
  fallback: fallback,
);

/// 재료 아이콘. `assets/images/materials/{kind}.webp` (없으면 fallback)
Widget materialImage(
  MaterialKind kind, {
  required double size,
  required Widget fallback,
}) => gameImage(
  'assets/images/materials/${kind.key}.webp',
  width: size,
  height: size,
  fallback: fallback,
);

/// 버프 아이콘. `assets/images/buffs/{key}.webp` 또는 `.png` (없으면 fallback 글리프)
Widget buffImage(
  BuffKind kind, {
  required double size,
  required Widget fallback,
}) => gameImageChain(
  [
    'assets/images/buffs/${kind.key}.webp',
    'assets/images/buffs/${kind.key}.png',
  ],
  size: size,
  fallback: fallback,
);

/// 골드(화폐) 아이콘. `assets/images/materials/gold.webp` (없으면 이모지)
Widget goldIcon({required double size}) => gameImage(
  'assets/images/materials/gold.webp',
  width: size,
  height: size,
  fallback: Text('💰', style: TextStyle(fontSize: size * 0.85)),
);

/// 업그레이드 아이콘. `assets/images/upgrades/{key}.webp` (없으면 fallback)
Widget upgradeImage(
  UpgradeKind kind, {
  required double size,
  required Widget fallback,
}) => gameImage(
  'assets/images/upgrades/${kind.key}.webp',
  width: size,
  height: size,
  fallback: fallback,
);

/// 보스 스프라이트. `assets/images/bosses/{regionId}.webp`
Widget bossSprite(
  String regionId, {
  required double size,
  required Widget fallback,
}) => gameImage(
  'assets/images/bosses/$regionId.webp',
  width: size,
  height: size,
  fallback: fallback,
);

/// 필드 배경 씬. [assetPath] 이미지가 있으면 그것을, 없으면 그라데이션 숲.
class SceneBackground extends StatelessWidget {
  const SceneBackground({super.key, this.assetPath});

  final String? assetPath;

  @override
  Widget build(BuildContext context) {
    final gradient = Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_skyTop, _skyBottom, _moss, _soil],
          stops: [0.0, 0.42, 0.56, 1.0],
        ),
      ),
      child: Align(
        alignment: const Alignment(0.55, -0.72),
        child: Container(
          width: 150,
          height: 150,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [Color(0xFFFFF4D2), Color(0x00FFF4D2)],
            ),
          ),
        ),
      ),
    );
    final path = assetPath;
    if (path == null) return gradient;
    return Image.asset(
      path,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => gradient,
    );
  }
}

/// 종 → 생애주기 아트 그룹(알·유충·번데기 공통 세트 단위).
/// 딱정벌레류/하늘소/사마귀/메뚜기목/물장군/말벌은 초기 단계 생김새가 그룹별로 다르다.
String bugFamily(String speciesId) {
  const borer = {
    'longhorn_saw',
    'longhorn_whitespot',
    'longhorn_oak',
    'longhorn_relict',
  };
  const mantis = {'mantis_jumping', 'mantis_widebelly', 'mantis_giant'};
  const ortho = {'grasshopper_longheaded', 'katydid'};
  if (borer.contains(speciesId)) return 'borer';
  if (mantis.contains(speciesId)) return 'mantis';
  if (ortho.contains(speciesId)) return 'ortho';
  if (speciesId == 'water_bug_giant') return 'waterbug';
  if (speciesId == 'hornet_giant') return 'hornet';
  return 'scarab'; // 사슴벌레·장수풍뎅이·꽃무지 등 기본
}

/// 생애주기 단계별 곤충 이미지.
/// - 성충: 종별 `bugs/{id}_adult.webp` → `bugs/{id}.webp`
/// - 알/유충/번데기: 종별 override 있으면 우선 → **그룹 공통** `bugs/stage_{family}_{stage}.webp`
///   → 전체 공통 `bugs/stage_{stage}.webp` → 폴백.
/// [skin] 이 있으면 구매한 코스메틱 색 필터를 입힌다(§2.6 — 외형만, 스탯 무관).
Widget bugStageImage(
  String speciesId,
  LifeStage stage, {
  required double size,
  required Widget fallback,
  ColorFilter? skin,
}) {
  final List<String> paths;
  if (stage == LifeStage.adult) {
    paths = [
      'assets/images/bugs/${speciesId}_adult.webp',
      'assets/images/bugs/${speciesId}_adult.png',
      'assets/images/bugs/$speciesId.webp',
      'assets/images/bugs/$speciesId.png',
    ];
  } else {
    final fam = bugFamily(speciesId);
    final s = stage.key;
    paths = [
      'assets/images/bugs/${speciesId}_$s.webp',
      'assets/images/bugs/${speciesId}_$s.png',
      'assets/images/bugs/stage_${fam}_$s.webp',
      'assets/images/bugs/stage_${fam}_$s.png',
      'assets/images/bugs/stage_$s.webp',
      'assets/images/bugs/stage_$s.png',
    ];
  }
  final img = gameImageChain(paths, size: size, fallback: fallback);
  return skin == null ? img : ColorFiltered(colorFilter: skin, child: img);
}

/// 곤충 아바타. species.imageAsset 없으면 등급색 원 + 이모지 폴백.
Widget bugAvatar(Species s, {double size = 44, ColorFilter? skin}) {
  final placeholder = Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          gradeColor(s.grade),
          Color.lerp(gradeColor(s.grade), Colors.black, 0.28)!,
        ],
      ),
      boxShadow: [
        BoxShadow(
          color: gradeColor(s.grade).withValues(alpha: 0.4),
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Text('🪲', style: TextStyle(fontSize: size * 0.52)),
  );
  final path = s.imageAsset;
  if (path == null) return placeholder;
  final avatar = ClipOval(
    child: Image.asset(
      'assets/images/bugs/$path',
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => placeholder,
    ),
  );
  return skin == null
      ? avatar
      : ColorFiltered(colorFilter: skin, child: avatar);
}

/// 서식지 표시용 이모지 폴백.
String habitatGlyph(HabitatKind k) => switch (k) {
  HabitatKind.tree => '🌳',
  HabitatKind.flower => '🌸',
  HabitatKind.rock => '🪨',
  HabitatKind.stump => '🪵',
  HabitatKind.mushroom => '🍄',
};

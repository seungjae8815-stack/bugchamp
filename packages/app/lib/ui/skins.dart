import 'package:core_run/core_run.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/providers.dart';
import '../domain/save_controller.dart';

/// 구매한 스킨(코스메틱)을 실제 외형에 입히는 색 처리.
///
/// 새 아트 없이 **색상 필터**로 구현한다 — 스탯에는 전혀 영향이 없다(§2.6).
/// 스킨 정의(어느 종에 어떤 효과)는 `iap.json` 의 `skins` 에 있다(§6).

/// 곤충 스킨 효과 → 색 필터. 알 수 없는 효과면 null(기본 외형).
ColorFilter? bugSkinFilter(String? effect) => switch (effect) {
  // 황금: 밝기(luminance) 기준으로 금색으로 물들인다.
  'gold' => const ColorFilter.matrix(<double>[
    0.4037, 0.7925, 0.1539, 0, 12, //
    0.3140, 0.6164, 0.1197, 0, 2, //
    0.1047, 0.2055, 0.0399, 0, 0, //
    0, 0, 0, 1, 0, //
  ]),
  // 알비노: 탈색 + 밝기를 올려 창백하게.
  'albino' => const ColorFilter.matrix(<double>[
    0.299, 0.587, 0.114, 0, 46, //
    0.299, 0.587, 0.114, 0, 46, //
    0.299, 0.587, 0.114, 0, 52, //
    0, 0, 0, 1, 0, //
  ]),
  _ => null,
};

/// 아레나 테마 스킨의 배경 색보정(대비·따뜻함 상승).
const ColorFilter arenaThemeFilter = ColorFilter.matrix(<double>[
  1.18, 0, 0, 0, 6, //
  0, 1.06, 0, 0, 0, //
  0, 0, 0.92, 0, -6, //
  0, 0, 0, 1, 0, //
]);

/// [child] 에 [filter] 를 입힌다. filter 가 null 이면 원본 그대로.
Widget withSkin(Widget child, ColorFilter? filter) =>
    filter == null ? child : ColorFiltered(colorFilter: filter, child: child);

/// 내 곤충([speciesId])에 적용될 스킨 필터. 미보유/미해당이면 null.
ColorFilter? myBugSkin(
  IapConfig? cfg,
  Set<String> ownedSkins,
  String speciesId,
) {
  if (cfg == null || ownedSkins.isEmpty) return null;
  return bugSkinFilter(cfg.skinEffectFor(ownedSkins, speciesId));
}

/// 아레나 테마 스킨을 보유했는지.
bool hasArenaTheme(IapConfig? cfg, Set<String> ownedSkins) =>
    cfg != null &&
    ownedSkins.isNotEmpty &&
    cfg.ownsEffect(ownedSkins, 'arenaTheme');

/// 종 id → 내가 보유한 스킨의 색 필터(없으면 null).
/// **내 곤충에만** 쓴다. 상대 곤충에는 적용하지 않는다(상대의 스킨이 아니므로).
typedef SkinOf = ColorFilter? Function(String speciesId);

/// 스킨 없음(기본 외형). 위젯 파라미터 기본값용.
ColorFilter? noSkin(String speciesId) => null;

/// 현재 세이브의 보유 스킨 기준 해석기. 세이브/데이터 로딩 전이면 항상 null.
final skinOfProvider = Provider<SkinOf>((ref) {
  final cfg = ref.watch(gameDataProvider).value?.iapConfig;
  final owned = ref.watch(
    saveControllerProvider.select(
      (s) => s.value?.ownedSkins ?? const <String>{},
    ),
  );
  if (cfg == null || owned.isEmpty) return (_) => null;
  return (speciesId) => myBugSkin(cfg, owned, speciesId);
});

/// 아레나 테마 스킨 보유 여부.
final arenaThemeOwnedProvider = Provider<bool>((ref) {
  final cfg = ref.watch(gameDataProvider).value?.iapConfig;
  final owned = ref.watch(
    saveControllerProvider.select(
      (s) => s.value?.ownedSkins ?? const <String>{},
    ),
  );
  return hasArenaTheme(cfg, owned);
});

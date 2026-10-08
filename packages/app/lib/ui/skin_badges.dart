/// 스킨 뱃지 — 산 곤충 스킨(황금 장수풍뎅이·알비노 사슴벌레)을 **남에게 보이는** 표식(2026-10-08).
///
/// 스킨은 내 곤충 그림에만 입혀져서, 산 사람이 아니면 아무도 몰랐다. 순위표 프로필·결투 후보·
/// 결투장 이름표·길드원 시트의 이름 옆에 작게 붙인다. 목록은 서버가 그 사람 세이브의
/// `ownedSkins`(서버 소유 필드)에서 **곤충 스킨만** 골라 준다(`skins`). 비면 아무것도 안 그린다.
library;

import 'package:core_run/core_run.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/providers.dart';
import 'art.dart';

/// 스킨 뱃지 줄. [skins] 가 비면 빈 위젯(구서버·스킨 없음 → 뱃지 없음).
Widget skinBadges(
  List<String> skins, {
  double size = 18,
  EdgeInsetsGeometry margin = const EdgeInsets.only(left: 4),
}) => skins.isEmpty
    ? const SizedBox.shrink()
    : SkinBadges(skins: skins, size: size, margin: margin);

/// 서버 응답의 `skins` 값 → 스킨 id 목록. 없거나 모양이 틀리면 빈 목록.
List<String> skinsFromJson(Object? raw) => [
  if (raw is List)
    for (final x in raw)
      if (x != null) '$x',
];

/// 내 보유 스킨 중 **남에게 보이는 곤충 스킨**만(서버 `publicSkinsOf` 와 같은 규칙) —
/// iap.json `skins` 순서대로, 아레나 테마처럼 `speciesPrefix` 가 없는 스킨은 뺀다.
List<String> publicSkins(IapConfig? cfg, Set<String> owned) => [
  if (cfg != null)
    for (final d in cfg.skins)
      if (d.speciesPrefix != null && owned.contains(d.id)) d.id,
];

/// 스킨 id 의 상점 이름(iap.json 상품 `name`, 그 스킨을 주는 상품). 모르면 null.
String? skinDisplayName(IapConfig? cfg, String skinId, String locale) {
  if (cfg == null) return null;
  for (final p in cfg.products) {
    if (p.skinId == skinId) return p.name?.resolve(locale);
  }
  return null;
}

/// 스킨 id 의 상점 그림 파일명(`assets/images/shop/{image}.webp`).
String _skinImage(IapConfig? cfg, String skinId) {
  if (cfg != null) {
    for (final p in cfg.products) {
      if (p.skinId == skinId && p.image != null) return p.image!;
    }
  }
  return 'skin_$skinId';
}

/// 그림이 없을 때의 색(효과별) — 금·진주.
Color _fallbackTone(IapConfig? cfg, String skinId) {
  final effect = cfg?.skins.where((s) => s.id == skinId).firstOrNull?.effect;
  return switch (effect) {
    'gold' => const Color(0xFFFFC24D),
    'albino' => const Color(0xFFD9D2FF),
    _ => const Color(0xFFFFFFFF),
  };
}

class SkinBadges extends ConsumerWidget {
  const SkinBadges({
    super.key,
    required this.skins,
    this.size = 18,
    this.margin = const EdgeInsets.only(left: 4),
  });

  final List<String> skins;
  final double size;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (skins.isEmpty) return const SizedBox.shrink();
    final cfg = ref.watch(gameDataProvider).value?.iapConfig;
    final locale = Localizations.localeOf(context).languageCode;
    return Padding(
      padding: margin,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < skins.length; i++)
            Padding(
              padding: EdgeInsets.only(left: i == 0 ? 0 : size * 0.15),
              child: _badge(cfg, skins[i], locale),
            ),
        ],
      ),
    );
  }

  Widget _badge(IapConfig? cfg, String id, String locale) {
    final tone = _fallbackTone(cfg, id);
    final img = gameImage(
      'assets/images/shop/${_skinImage(cfg, id)}.webp',
      width: size,
      height: size,
      fit: BoxFit.cover,
      fallback: Icon(Icons.auto_awesome_rounded, size: size * 0.8, color: tone),
    );
    final badge = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0x66000000),
        border: Border.all(color: tone, width: size >= 18 ? 1.4 : 1),
        boxShadow: [
          BoxShadow(color: tone.withValues(alpha: 0.45), blurRadius: 4),
        ],
      ),
      child: ClipOval(child: img),
    );
    final name = skinDisplayName(cfg, id, locale);
    // 길게 누르면 스킨 이름 — 뱃지가 카드(누르면 상세) 안에 있어 탭은 카드 몫으로 남긴다.
    return name == null || name.isEmpty
        ? badge
        : Tooltip(message: name, child: badge);
  }
}

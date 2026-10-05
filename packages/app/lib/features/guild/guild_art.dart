import 'package:core_run/core_run.dart' show kGuildEmblemCount;
import 'package:flutter/material.dart';

import '../../ui/colors.dart';

/// 길드 그림 공용(2026-10-05) — `assets/images/ui/guild/<name>.webp`.
///
/// 파일이 없으면 [fallback](지금 아이콘)을 그린다(§6 폴백). 그래서 아직 안 뽑은 그림
/// (`war_forge`·`skill_attack` 등)도 이름만 맞춰 두면 **파일만 넣으면** 뜬다.
/// ⚠️ 폴더는 `pubspec.yaml` assets 에 `assets/images/ui/guild/` 로 실려 있다(하위 폴더를 만들면 줄을 더 적는다).
Widget guildArt(
  String name, {
  double? size,
  double? width,
  double? height,
  BoxFit fit = BoxFit.contain,
  Alignment alignment = Alignment.center,
  required Widget fallback,
}) => Image.asset(
  'assets/images/ui/guild/$name.webp',
  width: width ?? size,
  height: height ?? size,
  fit: fit,
  alignment: alignment,
  filterQuality: FilterQuality.medium,
  errorBuilder: (_, _, _) => (width ?? size) == null && (height ?? size) == null
      ? fallback
      : SizedBox(
          width: width ?? size,
          height: height ?? size,
          child: Center(child: fallback),
        ),
);

/// 문장 그림 파일 이름 — 1 → `emblem_01`. 범위 밖은 1~10 으로 접는다.
String guildEmblemAsset(int emblem) {
  final e =
      ((emblem - 1) % kGuildEmblemCount + kGuildEmblemCount) %
          kGuildEmblemCount +
      1;
  return 'emblem_${e.toString().padLeft(2, '0')}';
}

/// 길드 문장(방패) — 그림이 없으면 방패 아이콘.
class GuildEmblem extends StatelessWidget {
  const GuildEmblem({super.key, required this.emblem, this.size = 32});

  /// 보일 문장 번호(1~10) — [GuildInfo.emblemShown] 처럼 기본값까지 정해진 값을 넘긴다.
  final int emblem;
  final double size;

  @override
  Widget build(BuildContext context) => guildArt(
    guildEmblemAsset(emblem),
    size: size,
    fallback: Icon(Icons.shield_rounded, color: kHoney, size: size * 0.9),
  );
}

/// 길드 코인 아이콘 — 그림이 없으면 동전 아이콘.
Widget guildCoinIcon({double size = 14}) => guildArt(
  'coin',
  size: size,
  fallback: Icon(Icons.toll_rounded, color: kHoney, size: size),
);

/// 코인 아이콘 + 글자 한 줄(가격·잔액·보상). 글자는 넘치면 줄인다.
class GuildCoinLabel extends StatelessWidget {
  const GuildCoinLabel(
    this.text, {
    super.key,
    this.style,
    this.iconSize,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.flexible = true,
  });

  final String text;
  final TextStyle? style;
  final double? iconSize;
  final MainAxisAlignment mainAxisAlignment;

  /// 글자를 칸에 맞춰 줄이나(…). 가로가 무제한인 곳(버튼 안 등)에서는 false — Flexible 이 터진다.
  final bool flexible;

  @override
  Widget build(BuildContext context) {
    final fs = style?.fontSize ?? DefaultTextStyle.of(context).style.fontSize;
    final label = Text(
      text,
      maxLines: 1,
      overflow: flexible ? TextOverflow.ellipsis : null,
      softWrap: false,
      style: style,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: mainAxisAlignment,
      children: [
        guildCoinIcon(size: iconSize ?? (fs ?? 14) * 1.25),
        const SizedBox(width: 4),
        if (flexible) Flexible(child: label) else label,
      ],
    );
  }
}

/// 대회 회차 뱃지 — 순위표에서 닉네임 옆에 붙는 표식.
///
/// 이 표식이 존재하는 이유: 실물 경품은 **국내 배송만 가능**한데(살아있는 곤충의
/// 국제 배송은 검역 대상이다), 그렇다고 해외 1위에게 그 가치를 젤리로 환산해
/// 주면 그 유저의 경제가 그 자리에서 끝난다(≈1,200젤리 = 영구 소비처의 3배).
/// 그래서 등가를 **금액이 아니라 자랑거리**로 맞춘다 — 실물 곤충이 하는 사회적
/// 역할이 바로 이것이고, 이건 국경을 타지 않는다.
///
/// id 형식은 `종류:회차번호`(`champion:1`). 회차 번호가 붙는 이유 = 1회차
/// 챔피언과 3회차 챔피언은 다른 자랑거리다.
library;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// 뱃지 id 를 (종류, 회차) 로 가른다. 형식이 아니면 null.
({String kind, int round})? parseEventBadge(String id) {
  if (id.isEmpty) return null;
  final i = id.indexOf(':');
  if (i <= 0) return null;
  final round = int.tryParse(id.substring(i + 1));
  if (round == null) return null;
  return (kind: id.substring(0, i), round: round);
}

/// 뱃지 칩. id 가 비었거나 모르는 형식이면 **아무것도 그리지 않는다** —
/// 신버전이 뱃지 종류를 추가해도 구버전 순위표가 깨지지 않아야 한다.
class EventBadgeChip extends StatelessWidget {
  const EventBadgeChip({super.key, required this.id, this.size = 11});

  final String id;
  final double size;

  @override
  Widget build(BuildContext context) {
    final b = parseEventBadge(id);
    if (b == null) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    final (label, color, icon) = switch (b.kind) {
      'champion' => (
        l.badgeChampion(b.round),
        const Color(0xFFFFC24D),
        Icons.emoji_events_rounded,
      ),
      'finalist' => (
        l.badgeFinalist(b.round),
        const Color(0xFFB0BEC5),
        Icons.military_tech_rounded,
      ),
      _ => ('', const Color(0x00000000), Icons.circle),
    };
    if (label.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: size + 2, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: size,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

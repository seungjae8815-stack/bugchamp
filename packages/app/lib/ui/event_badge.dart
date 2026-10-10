/// 대회 회차 뱃지 — 순위표·채팅·명예의 전당에서 닉네임 옆에 붙는 표식.
///
/// 이 표식이 존재하는 이유: 실물 경품은 **국내 배송만 가능**한데(살아있는 곤충의
/// 국제 배송은 검역 대상이다), 그렇다고 해외 1위에게 그 가치를 젤리로 환산해
/// 주면 그 유저의 경제가 그 자리에서 끝난다(≈1,200젤리 = 영구 소비처의 3배).
/// 그래서 등가를 **금액이 아니라 자랑거리**로 맞춘다 — 실물 곤충이 하는 사회적
/// 역할이 바로 이것이고, 이건 국경을 타지 않는다.
///
/// id 해석·대표 뱃지 고르기는 서버와 같은 규칙이라 `core_models` 에 있다
/// (`parseEventBadge` · `bestEventBadge`).
library;

import 'package:core_models/core_models.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// 종류별 (이름, 색, 아이콘). 모르는 종류면 null.
(String, Color, IconData)? _styleOf(AppLocalizations l, String id) {
  final b = parseEventBadge(id);
  if (b == null) return null;
  return switch (b.kind) {
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
    // 참가 — 입상보다 한 톤 가라앉힌 초록. 금·은 옆에서 튀지 않되 "나도
    // 나갔다"는 건 보여야 한다(2026-09-15).
    'participant' => (
      l.badgeParticipant(b.round),
      const Color(0xFF8FD19E),
      Icons.local_florist_rounded,
    ),
    _ => null,
  };
}

/// 뱃지 이름(`1회차 챔피언`). 모르는 형식이면 빈 문자열.
///
/// 보상표·전단지는 칩이 아니라 **"무엇을 받는지"** 로 적는다 — 칩만 두면
/// 그게 상품인지 장식인지 안 읽힌다(2026-08-29 지적).
String eventBadgeName(AppLocalizations l, String id) =>
    _styleOf(l, id)?.$1 ?? '';

/// 뱃지 칩. id 가 비었거나 모르는 형식이면 **아무것도 그리지 않는다** —
/// 신버전이 뱃지 종류를 추가해도 구버전 순위표가 깨지지 않아야 한다.
///
/// [compact] 면 이름 없이 아이콘만 그린다 — 홈 상단 채팅 바처럼 한 줄에
/// 닉네임·본문이 같이 들어가는 자리용이다.
class EventBadgeChip extends StatelessWidget {
  const EventBadgeChip({
    super.key,
    required this.id,
    this.size = 11,
    this.compact = false,
    this.margin = const EdgeInsets.only(left: 6),
  });

  final String id;
  final double size;
  final bool compact;

  /// 칩 바깥 여백. 이름 **옆**에 붙일 땐 왼쪽을 띄우고(기본), 이름 **위**에
  /// 올릴 땐 아래를 띄운다([aboveName]).
  final EdgeInsetsGeometry margin;

  /// 이름 위에 올리는 칩의 여백.
  static const aboveName = EdgeInsets.only(bottom: 2);

  @override
  Widget build(BuildContext context) {
    final style = _styleOf(AppLocalizations.of(context), id);
    if (style == null) return const SizedBox.shrink();
    final (label, color, icon) = style;

    if (compact) {
      return Padding(
        padding: const EdgeInsets.only(left: 3),
        child: Tooltip(
          message: label,
          child: Icon(icon, size: size + 2, color: color),
        ),
      );
    }

    return Container(
      margin: margin,
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

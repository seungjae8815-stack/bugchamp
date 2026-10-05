import 'package:core_run/core_run.dart';
import 'package:flutter/material.dart';

import '../../domain/guild_service.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/colors.dart';
import '../../ui/format.dart';
import '../../ui/game_dialog.dart';

/// 멤버 등급(2026-10-05 사장님 확정) — 기여도 자동 · **표시 전용**(혜택·권한 없음).
/// 계산은 core_run [guildMemberRank](서버와 같은 함수), 기준은 `guild.json → memberRanks`.

/// 등급 id → 이름. 모르는 id(JSON 에 새로 넣은 것)는 id 그대로.
String guildRankLabel(AppLocalizations l, String id) => switch (id) {
  'rookie' => l.guildRankRookie,
  'worker' => l.guildRankWorker,
  'elite' => l.guildRankElite,
  'elder' => l.guildRankElder,
  _ => id,
};

/// 그림이 아직 없을 때 쓰는 아이콘·색.
(IconData, Color) _rankIcon(String id) => switch (id) {
  'worker' => (Icons.handyman_rounded, const Color(0xFF9FD18B)),
  'elite' => (Icons.military_tech_rounded, const Color(0xFF8EC5FF)),
  'elder' => (Icons.auto_awesome_rounded, const Color(0xFFFFC857)),
  _ => (Icons.eco_rounded, const Color(0xFFBFC8B5)),
};

/// 등급 뱃지 — 그림(`assets/images/ui/guild/rank_{id}.webp`)이 있으면 그림, 없으면 아이콘(§6 폴백) + 이름.
/// ⚠️ 그림을 넣을 땐 `pubspec.yaml` assets 에 `assets/images/ui/guild/` 줄도 함께 넣는다
/// (Flutter 는 하위 폴더를 자동으로 싣지 않는다 — 없는 폴더를 미리 적으면 빌드가 깨진다).
class GuildRankBadge extends StatelessWidget {
  const GuildRankBadge({super.key, required this.rankId, this.size = 14});

  final String rankId;
  final double size;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final (icon, color) = _rankIcon(rankId);
    return Container(
      key: ValueKey('guildRank:$rankId'),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/images/ui/guild/rank_$rankId.webp',
            width: size,
            height: size,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, _, _) => Icon(icon, size: size, color: color),
          ),
          const SizedBox(width: 3),
          Text(
            guildRankLabel(l, rankId),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: size * 0.78,
            ),
          ),
        ],
      ),
    );
  }
}

/// 멤버 탭 맨 위 — 내 등급 · 다음 등급까지 남은 기여도 · 직책별 권한 도움말(i).
class GuildMyRankBar extends StatelessWidget {
  const GuildMyRankBar({
    super.key,
    required this.view,
    required this.ranks,
    required this.contribution,
  });

  final GuildView view;
  final List<GuildMemberRankDef> ranks;
  final int contribution;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final r = guildMemberRank(ranks, contribution);
    final next = r.next;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
      decoration: BoxDecoration(
        color: const Color(0x22000000),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          GuildRankBadge(rankId: r.rank.id),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l.guildMyRank(
                    guildRankLabel(l, r.rank.id),
                    formatCompact(contribution),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                Text(
                  next == null
                      ? l.guildRankMax
                      : l.guildRankNext(
                          guildRankLabel(l, next.id),
                          formatCompact(next.min - contribution),
                        ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xAAFFFFFF),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            key: const ValueKey('guildPermsHelp'),
            tooltip: l.guildPermsTitle,
            visualDensity: VisualDensity.compact,
            icon: const Icon(
              Icons.info_outline_rounded,
              color: Color(0xAAFFFFFF),
              size: 20,
            ),
            onPressed: () => showGuildPermsHelp(context, view, ranks),
          ),
        ],
      ),
    );
  }
}

/// 직책별 권한 표(docs/design_guild.md §1) + 멤버 등급 안내.
Future<void> showGuildPermsHelp(
  BuildContext context,
  GuildView view,
  List<GuildMemberRankDef> ranks,
) {
  final l = AppLocalizations.of(context);
  final deputyAccept = view.guild?.deputyCanAccept ?? true;
  const yes = Icon(Icons.check_rounded, color: Color(0xFF9FD18B), size: 18);
  const no = Icon(Icons.close_rounded, color: Color(0x66FFFFFF), size: 18);
  Widget cell(Widget c) =>
      Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: c);
  Widget head(String t) => cell(
    Text(
      t,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: kHoney,
        fontWeight: FontWeight.w900,
        fontSize: 11.5,
      ),
    ),
  );
  TableRow row(String label, List<bool> can) => TableRow(
    children: [
      cell(
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ),
      for (final c in can) cell(Center(child: c ? yes : no)),
    ],
  );
  // 표의 값은 core_run 권한 함수에서 바로 읽는다 — 화면과 서버가 갈리지 않게.
  List<bool> by(bool Function(GuildRole r) f) => [
    for (final r in const [
      GuildRole.leader,
      GuildRole.deputy,
      GuildRole.member,
    ])
      f(r),
  ];
  final sorted = [...ranks]..sort((a, b) => a.min.compareTo(b.min));
  return showGameDialog<void>(
    context,
    title: l.guildPermsTitle,
    icon: Icons.info_outline_rounded,
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Table(
            columnWidths: const {0: FlexColumnWidth(2.2)},
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              TableRow(
                children: [
                  const SizedBox.shrink(),
                  head(l.guildRoleLeader),
                  head(l.guildRoleDeputy),
                  head(l.guildRoleMember),
                ],
              ),
              row(
                l.guildPermAccept,
                by((r) => r.canAnswerRequests(deputyCanAccept: deputyAccept)),
              ),
              row(l.guildPermKick, by((r) => r.canKick)),
              row(l.guildPermSettings, by((r) => r.canEditSettings)),
              row(l.guildPermSkills, by((r) => r.canEditSkills)),
              row(l.guildPermRoles, by((r) => r.canAssignRoles)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l.guildPermDeputyNote(
              deputyAccept ? l.guildSwitchOn : l.guildSwitchOff,
            ),
            style: const TextStyle(color: Color(0xAAFFFFFF), fontSize: 11.5),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final r in sorted)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GuildRankBadge(rankId: r.id, size: 13),
                    const SizedBox(width: 3),
                    Text(
                      formatCompact(r.min),
                      style: const TextStyle(
                        color: Color(0xAAFFFFFF),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l.guildPermRanksNote,
            style: const TextStyle(color: Color(0xAAFFFFFF), fontSize: 11.5),
          ),
        ],
      ),
    ),
    actions: [gameDialogButton(l.actionClose, () => Navigator.pop(context))],
  );
}

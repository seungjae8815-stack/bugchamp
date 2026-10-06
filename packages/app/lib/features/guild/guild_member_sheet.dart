import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/game_data.dart';
import '../../domain/guild_service.dart';
import '../../domain/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/art.dart';
import '../../ui/colors.dart';
import '../../ui/event_badge.dart';
import '../../ui/fairy_art.dart';
import '../../ui/format.dart';
import '../../ui/game_dialog.dart';
import '../../ui/labels.dart';
import '../../ui/tier_label.dart';
import '../battle/league_board_screen.dart' show duelProfileBugTile;
import '../character/equip_widgets.dart';
import 'guild_rank.dart';
import 'guild_screen.dart' show guildRoleLabel, guildErrorText;

const _honey = kHoney;
const _dim = Color(0x99FFFFFF);

/// 길드원 정보 시트(2026-10-05) — 멤버 탭에서 줄을 누르면 연다.
///
/// 서버 `/guild/member/<id>` 가 **같은 길드만**(403) 멤버 줄 + 그 사람 세이브의 **요약**을 준다
/// (세이브 통째가 아니다 — 크기·개인정보). 곤충·장비·요정은 채집함·장비·요정 화면과 같은 그림으로 그린다.
/// 전투력은 멤버 목록과 같은 `profiles.power`(그 사람 앱의 홈 상단 값).
Future<void> showGuildMemberSheet(BuildContext context, GuildMemberInfo m) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xF2141F0E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (ctx, scroll) => GuildMemberSheet(member: m, scroll: scroll),
      ),
    );

class GuildMemberSheet extends ConsumerStatefulWidget {
  const GuildMemberSheet({super.key, required this.member, this.scroll});

  /// 목록에서 누른 줄 — 서버 응답이 오기 전에도 이름·직책은 바로 보인다.
  final GuildMemberInfo member;
  final ScrollController? scroll;

  @override
  ConsumerState<GuildMemberSheet> createState() => _GuildMemberSheetState();
}

class _GuildMemberSheetState extends ConsumerState<GuildMemberSheet> {
  GuildMemberDetail? _detail;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    final r = await ref
        .read(guildProvider.notifier)
        .member(widget.member.userId);
    if (!mounted) return;
    setState(() {
      _detail = r.detail;
      _error = r.error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final data = ref.watch(gameDataProvider).value;
    final rules = data?.chatRules ?? const ChatRules();
    final locale = Localizations.localeOf(context).languageCode;
    final d = _detail;
    final m = d?.member ?? widget.member;
    final ranks = data?.guildConfig.memberRanks ?? kDefaultGuildMemberRanks;
    final rankId = d?.rankId ?? guildMemberRank(ranks, m.contribution).rank.id;
    return ListView(
      controller: widget.scroll,
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        16 + MediaQuery.viewPaddingOf(context).bottom,
      ),
      children: [
        Center(
          child: Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0x44FFFFFF),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 10),
        EventBadgeChip(id: m.badge, size: 11, margin: EventBadgeChip.aboveName),
        Text(
          rules.maskNickname(m.nickname, fallback: l.nicknameFallback),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            GuildRankBadge(rankId: rankId, size: 13),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                [
                  guildRoleLabel(l, m.role),
                  guildRankLabel(l, rankId),
                  l.guildMemberContribution(formatCompact(m.contribution)),
                ].join(' · '),
                maxLines: 2,
                style: const TextStyle(color: _dim, fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            Text(
              '${l.combatPowerLabel} ${formatCompact(m.power)}',
              style: const TextStyle(
                color: _honey,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
            if (d != null && d.hasSummary) ...[
              Text(
                l.guildMemberLevel(d.level),
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
              Text(
                d.inAbyss
                    ? '${tierName(l, d.tier)} · ${l.abyssFloorLabel(d.abyssFloor)}'
                    : progressLabel(
                        l,
                        data?.roadmapConfig,
                        d.tier,
                        d.stage,
                        run: data?.runConfig,
                      ),
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        if (d == null && _error == null)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (d == null)
          _note(
            _error == 'forbidden'
                ? guildErrorText(l, _error!)
                : l.guildMemberFailed,
          )
        else if (!d.hasSummary)
          _note(l.guildMemberNoSave)
        else ...[
          _section(l.guildMemberPets),
          _pets(l, data, locale, d.pets),
          _section(l.guildMemberTeam),
          d.team.isEmpty
              ? _note(l.profileNoTeam)
              : Row(
                  children: [
                    for (final t in d.team)
                      Expanded(child: duelProfileBugTile(l, data, locale, t)),
                  ],
                ),
          _section(l.guildMemberEquip),
          _equipment(l, data, locale, d.equipment),
          _section(l.guildMemberFairy),
          _fairy(l, data, locale, d.fairy),
          _section(l.guildMemberSkills),
          _skills(l, data, locale, d.skills),
        ],
      ],
    );
  }

  Widget _section(String text) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 6),
    child: Text(
      text,
      style: const TextStyle(
        color: _honey,
        fontWeight: FontWeight.w900,
        fontSize: 13,
      ),
    ),
  );

  Widget _note(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Text(text, style: const TextStyle(color: _dim, fontSize: 12)),
  );

  /// 장착 곤충 3칸 — 종 그림 · 이름 · 포텐셜 · 크기 · 오행.
  Widget _pets(
    AppLocalizations l,
    GameData? data,
    String locale,
    List<IndividualBug> pets,
  ) {
    if (pets.isEmpty) return _note(l.guildMemberNone);
    return Row(
      children: [
        for (final b in pets)
          Expanded(
            child: Column(
              key: ValueKey('guildMemberPet:${b.speciesId}'),
              children: [
                _speciesAvatar(data, b.speciesId, 52),
                const SizedBox(height: 3),
                Text(
                  _speciesName(data, b.speciesId, locale),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '${'★' * b.potential.clamp(0, 5)} · ${b.sizeMm.toStringAsFixed(1)}mm',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _honey, fontSize: 10.5),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    elementIcon(b.element, size: 12),
                    const SizedBox(width: 2),
                    Text(
                      elementLabel(l, b.element),
                      style: TextStyle(
                        color: elementColor(b.element),
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _speciesAvatar(GameData? data, String id, double size) {
    try {
      final sp = data?.species(id);
      if (sp != null) return bugAvatar(sp, size: size);
    } catch (_) {}
    return SizedBox(
      width: size,
      height: size,
      child: const Icon(Icons.bug_report, color: Colors.white54),
    );
  }

  String _speciesName(GameData? data, String id, String locale) {
    try {
      return data?.species(id).name.resolve(locale) ?? id;
    } catch (_) {
      return id;
    }
  }

  /// 장비 8부위 — 등급 색 테두리 + 그림. 누르면 이름·옵션(보기만).
  Widget _equipment(
    AppLocalizations l,
    GameData? data,
    String locale,
    List<EquipItem> items,
  ) {
    final cfg = data?.itemConfig;
    if (items.isEmpty) return _note(l.guildMemberNone);
    final bySlot = {for (final it in items) it.slot: it};
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final slot in EquipSlot.values)
          if (bySlot[slot] != null)
            _itemTile(l, cfg, locale, bySlot[slot]!)
          else
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0x18FFFFFF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0x22FFFFFF)),
              ),
              child: Icon(slotIcon(slot), size: 16, color: _dim),
            ),
      ],
    );
  }

  Widget _itemTile(
    AppLocalizations l,
    ItemConfig? cfg,
    String locale,
    EquipItem it,
  ) {
    // 장비 설정을 못 읽었으면(테스트·로딩 중) 회색 테두리 · 누르기 없음 — 그림은 그대로.
    final c = cfg == null ? const Color(0x66FFFFFF) : tierColor(cfg, it.tier);
    return GestureDetector(
      onTap: cfg == null
          ? null
          : () => showGameDialog<void>(
              context,
              title: itemName(cfg, l, locale, it),
              iconWidget: itemImage(it, size: 40),
              content: ItemOptionList(item: it, config: cfg),
              actions: [
                gameDialogButton(
                  l.actionClose,
                  () => Navigator.of(context).pop(),
                ),
              ],
            ),
      child: Container(
        key: ValueKey('guildMemberItem:${it.slot.key}'),
        width: 40,
        height: 40,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: c, width: 1.6),
        ),
        child: itemImage(it, size: 32, tint: c),
      ),
    );
  }

  Widget _fairy(AppLocalizations l, GameData? data, String locale, Fairy? f) {
    if (f == null) return _note(l.guildMemberNone);
    final def = data?.fairyConfig?.byId(f.kind);
    return Row(
      children: [
        fairyGlow(f, size: 48),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                def?.name.resolve(locale) ?? f.kind,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                '${fairyGradeLabel(l, f.grade)} · ${l.fairyLevel('${f.level}')}',
                style: TextStyle(
                  color: fairyGradeColor(f.grade),
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _skills(
    AppLocalizations l,
    GameData? data,
    String locale,
    List<({String id, int level})> skills,
  ) {
    if (skills.isEmpty) return _note(l.guildMemberNone);
    final cfg = data?.skillConfig;
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: [
        for (final s in skills)
          SizedBox(
            width: 62,
            child: Column(
              children: [
                skillImage(
                  s.id,
                  size: 36,
                  fallback: const Icon(Icons.auto_awesome, color: _honey),
                ),
                const SizedBox(height: 2),
                Text(
                  cfg?.byId(s.id)?.name.resolve(locale) ?? s.id,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 10.5),
                ),
                Text(
                  'Lv ${s.level}',
                  style: const TextStyle(color: _honey, fontSize: 10.5),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

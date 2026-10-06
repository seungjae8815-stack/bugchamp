import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/guild_service.dart';
import '../../domain/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/art.dart';
import '../../ui/fairy_art.dart';
import '../../ui/game_dialog.dart';
import '../../ui/labels.dart';
import '../../ui/toast.dart';
import '../../ui/colors.dart';
import 'guild_art.dart';

const _honey = kHoney;
const _dim = Color(0x99FFFFFF);
const _green = Color(0xFF9CE37D);

String guildGrowthErrorText(AppLocalizations l, String code) => switch (code) {
  'already_donated' => l.guildDonateDone,
  'no_points' => l.guildSkillNoPoints,
  'skill_max' => l.guildSkillMax,
  'shop_limit' => l.guildShopSoldOut,
  'not_enough_coins' => l.guildShopNoCoins,
  'forbidden' => l.guildSkillForbidden,
  'not_in_guild' => l.guildErrNotInGuild,
  'guild_not_found' => l.guildErrNotFound,
  'store_unavailable' => l.guildErrStoreUnavailable,
  _ => l.guildErrGeneric,
};

String guildSkillLabel(AppLocalizations l, String stat) => switch (stat) {
  'attack' => l.guildSkillAttack,
  'hp' => l.guildSkillHp,
  'gold' => l.guildSkillGold,
  'materialFind' => l.guildSkillMaterial,
  'xp' => l.guildSkillXp,
  _ => l.guildSkillMission,
};

/// 스킬 그림이 없을 때 아이콘 — 키는 스킬 id(= 그림 `skill_<id>`).
IconData _skillIcon(String id) => switch (id) {
  'attack' => Icons.local_fire_department_rounded,
  'hp' => Icons.favorite_rounded,
  'gold' => Icons.monetization_on_rounded,
  'material' => Icons.inventory_2_rounded,
  'xp' => Icons.auto_graph_rounded,
  _ => Icons.flag_rounded,
};

String _shopLabel(AppLocalizations l, GuildShopItem it) => switch (it.kind) {
  'materials' => l.guildShopMaterials(it.hours.toStringAsFixed(0)),
  'fossil' => l.guildShopFossil(it.amount),
  'fairyDust' => l.guildShopFairyDust(it.amount),
  'fairyEgg' => l.guildShopFairyEgg(it.amount),
  _ => l.guildShopSkillShard(
    gradeLabel(
      l,
      Grade.values.firstWhere(
        (g) => g.key == it.grade,
        orElse: () => Grade.rare,
      ),
    ),
    it.amount,
  ),
};

/// 길드 화면 머리의 레벨·경험치·코인 줄 + 출석·스킬·상점 버튼.
class GuildGrowthBar extends ConsumerWidget {
  const GuildGrowthBar({super.key, required this.view});
  final GuildView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final g = view.guild!;
    final pct = g.expNeed <= 0 ? 1.0 : (g.exp / g.expNeed).clamp(0.0, 1.0);
    Widget btn(
      String text,
      VoidCallback? onTap, {
      bool dot = false,
      required String art,
      required IconData icon,
      Key? key,
    }) => Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          OutlinedButton(
            key: key,
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              foregroundColor: _honey,
              side: BorderSide(
                color: onTap == null ? const Color(0x33FFFFFF) : _honey,
              ),
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Opacity(
                  opacity: onTap == null ? 0.45 : 1,
                  child: guildArt(
                    art,
                    size: 18,
                    fallback: Icon(icon, size: 15),
                  ),
                ),
                const SizedBox(width: 3),
                Text(
                  text,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          if (dot)
            const Positioned(
              right: -2,
              top: -2,
              child: CircleAvatar(
                radius: 4,
                backgroundColor: Color(0xFFFF5252),
              ),
            ),
        ],
      ),
    );
    const head = TextStyle(
      color: _honey,
      fontWeight: FontWeight.w900,
      fontSize: 13,
    );
    // 레벨·코인을 한 줄 위로 올리고 경험치 막대 옆에 버튼 셋 — 360dp 에서 버튼 그림 때문에 글자가 잘리지 않게.
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(l.guildLevel(g.level), style: head),
              const Text('  ·  ', style: head),
              Flexible(
                child: GuildCoinLabel(l.guildCoins(view.myCoins), style: head),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 5,
                    backgroundColor: const Color(0x33FFFFFF),
                    valueColor: const AlwaysStoppedAnimation(_green),
                  ),
                ),
              ),
              const SizedBox(width: 2),
              // 버튼 셋은 칸이 모자라면(작은 화면·긴 번역) 통째로 줄인다 — 넘치지 않게.
              Flexible(
                flex: 5,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 출석 — 누르면 출석 표(35칸)가 열린다. 출석한 날에도 표는 볼 수 있다.
                        btn(
                          view.donatedToday
                              ? l.guildDonateDoneShort
                              : l.guildDonate,
                          () => showGuildAttendDialog(context),
                          dot: !view.donatedToday,
                          art: 'attend',
                          icon: Icons.event_available_rounded,
                          key: const ValueKey('guildAttend'),
                        ),
                        btn(
                          l.guildSkills,
                          () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const GuildSkillScreen(),
                            ),
                          ),
                          dot: view.myRole.canEditSkills && g.pointsLeft > 0,
                          art: 'tab_growth',
                          icon: Icons.trending_up_rounded,
                        ),
                        btn(
                          l.guildShop,
                          () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const GuildShopScreen(),
                            ),
                          ),
                          art: 'tab_shop',
                          icon: Icons.storefront_rounded,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 출석 표(2026-10-05 사장님 확정) — 35칸(7일 × 5줄)을 출석한 날만 한 칸씩 채운다(연속 아님).
/// 7·14·21·28·35일차 칸에는 큰 보상 그림. 규칙(일차 계산)은 서버와 같은 core_run [GuildAttendConfig].
Future<void> showGuildAttendDialog(BuildContext context) {
  final l = AppLocalizations.of(context);
  return showGameDialog<void>(
    context,
    title: l.guildAttendTitle,
    iconWidget: guildArt(
      'attend',
      size: 36,
      fallback: const Icon(Icons.event_available_rounded, color: _honey),
    ),
    content: const GuildAttendCard(),
    actions: [
      gameDialogButton(
        l.actionClose,
        () => Navigator.of(context).pop(),
        primary: false,
      ),
    ],
  );
}

/// 출석 표 본문 — 달력 · 매일/큰 보상 안내 · 오늘 출석 버튼. [guildProvider] 를 지켜봐 출석하면 바로 채워진다.
class GuildAttendCard extends ConsumerStatefulWidget {
  const GuildAttendCard({super.key});

  @override
  ConsumerState<GuildAttendCard> createState() => _GuildAttendCardState();
}

class _GuildAttendCardState extends ConsumerState<GuildAttendCard> {
  bool _busy = false;

  Future<void> _attend() async {
    final l = AppLocalizations.of(context);
    setState(() => _busy = true);
    final r = await ref.read(guildProvider.notifier).donate();
    if (!mounted) return;
    setState(() => _busy = false);
    final a = r.attend;
    if (r.error != null || a == null) {
      showCenterToast(context, guildGrowthErrorText(l, r.error ?? 'network'));
      return;
    }
    showCenterToast(
      context,
      [
        l.guildAttendGot(a.day),
        if (a.coins > 0) l.guildCoins(a.coins),
        if (a.fossil > 0)
          '${materialLabel(l, MaterialKind.fossil)} ${a.fossil}',
        if (a.fairyDust > 0) '${l.fairyDust} ${a.fairyDust}',
      ].join(' · '),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final v = ref.watch(guildProvider).value;
    final cfg =
        ref.watch(gameDataProvider).value?.guildConfig ?? const GuildConfig();
    final a = cfg.attend;
    final count = v?.attendCount ?? 0;
    final done = v?.donatedToday ?? false;
    // 채운 칸 수(다 채운 날엔 35칸이 다 차 보이고, 다음 출석에 1일차부터 다시).
    final filled = a.dayOf(count);
    final next = done ? 0 : a.nextDay(count);
    final cycle = a.cycleDays < 1 ? 1 : a.cycleDays;
    // 다음이 1일차면(처음 · 한 바퀴 끝) 빈 표로 보인다 — 다 찬 표 위에 1일차 표시가 겹치지 않게.
    final shown = next == 1 ? 0 : filled;
    const perRow = 7;
    final rows = (cycle / perRow).ceil();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l.guildAttendProgress(shown, cycle),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _honey,
            fontWeight: FontWeight.w900,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        for (var r = 0; r < rows; r++)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                for (var c = 0; c < perRow; c++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: r * perRow + c < cycle
                          ? _cell(
                              l,
                              a,
                              r * perRow + c + 1,
                              filled: r * perRow + c + 1 <= shown,
                              today: r * perRow + c + 1 == next,
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 6),
        Text(
          [
            l.guildAttendDaily(cfg.donateCoins, cfg.donateExp),
            if (a.bonuses.isNotEmpty) l.guildAttendBigNote,
            l.guildAttendNote(cycle),
          ].join('\n'),
          textAlign: TextAlign.center,
          style: const TextStyle(color: _dim, fontSize: 11.5, height: 1.4),
        ),
        const SizedBox(height: 10),
        FilledButton(
          key: const ValueKey('guildAttendNow'),
          onPressed: done || _busy || v?.guild == null ? null : _attend,
          style: FilledButton.styleFrom(
            backgroundColor: _honey,
            foregroundColor: kHoneyInk,
            padding: const EdgeInsets.symmetric(vertical: 11),
          ),
          child: Text(
            done ? l.guildAttendDoneToday : l.guildAttendButton,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }

  /// 달력 한 칸 — 일차 번호 · 채운 칸(체크) · 큰 보상 칸(보상 그림) · 오늘 칸(테두리).
  Widget _cell(
    AppLocalizations l,
    GuildAttendConfig a,
    int day, {
    required bool filled,
    required bool today,
  }) {
    final bonus = a.bonusOn(day);
    final big = bonus != null;
    final Widget? art = !big
        ? null
        : bonus.fairyDust > 0 && bonus.fossil == 0
        ? fairyDustImage(size: 14)
        : bonus.fossil > 0
        ? materialImage(
            MaterialKind.fossil,
            size: 14,
            fallback: Icon(materialIcon(MaterialKind.fossil), size: 13),
          )
        : guildCoinIcon(size: 14);
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        key: ValueKey('guildAttendCell:$day'),
        decoration: BoxDecoration(
          color: filled
              ? _honey.withValues(alpha: 0.85)
              : (big ? const Color(0x33EBA52F) : const Color(0x18FFFFFF)),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: today ? _green : (big ? _honey : const Color(0x22FFFFFF)),
            width: today ? 2 : 1,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              left: 3,
              top: 1,
              child: Text(
                '$day',
                style: TextStyle(
                  color: filled ? kHoneyInk : const Color(0xCCFFFFFF),
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            if (filled)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Icon(Icons.check_rounded, size: 16, color: kHoneyInk),
              )
            else if (art != null)
              Padding(padding: const EdgeInsets.only(top: 7), child: art),
          ],
        ),
      ),
    );
  }
}

/// 길드 버프 스킬 — 길드장이 포인트를 찍는다(모두에게 적용).
class GuildSkillScreen extends ConsumerWidget {
  const GuildSkillScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final v = ref.watch(guildProvider).value;
    final defs =
        ref.watch(gameDataProvider).value?.guildConfig.skills ?? const [];
    final g = v?.guild;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.guildSkills),
        actions: [
          if (v != null && v.myRole.canEditSkills)
            TextButton(
              onPressed: () async {
                final ok = await showGameDialog<bool>(
                  context,
                  title: l.guildSkillReset,
                  icon: Icons.restart_alt_rounded,
                  content: Text(
                    l.guildSkillResetBody,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xD9FFFFFF),
                      fontSize: 13,
                    ),
                  ),
                  actions: [
                    gameDialogButton(
                      l.actionCancel,
                      () => Navigator.pop(context, false),
                      primary: false,
                    ),
                    gameDialogButton(
                      l.guildSkillReset,
                      () => Navigator.pop(context, true),
                    ),
                  ],
                );
                if (ok != true) return;
                final err = await ref.read(guildProvider.notifier).skillReset();
                if (err != null && context.mounted) {
                  showCenterToast(context, guildGrowthErrorText(l, err));
                }
              },
              child: Text(l.guildSkillReset),
            ),
        ],
      ),
      body: v == null
          ? const Center(child: CircularProgressIndicator())
          // 그 사이 길드를 나갔거나(추방·해산) 조회에 실패했다 — 무한 로딩 대신 이유를 보인다.
          : g == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  v.available ? l.guildErrNotInGuild : l.guildUnavailable,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _dim),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Text(
                  l.guildSkillHeader(g.pointsLeft),
                  style: const TextStyle(
                    color: _honey,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l.guildSkillNote,
                  style: const TextStyle(
                    color: _dim,
                    fontSize: 11.5,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                for (final d in defs)
                  _row(context, ref, l, v, d, g.skills[d.id] ?? 0),
              ],
            ),
    );
  }

  Widget _row(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l,
    GuildView v,
    GuildSkillDef d,
    int lv,
  ) {
    final can = v.myRole.canEditSkills && v.guild!.pointsLeft > 0 && lv < d.max;
    final pct = (d.perLevel * lv * 100).toStringAsFixed(1);
    final maxPct = (d.perLevel * d.max * 100).toStringAsFixed(0);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0x18000000),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          guildArt(
            'skill_${d.id}',
            size: 34,
            fallback: Icon(_skillIcon(d.id), color: _honey, size: 24),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${guildSkillLabel(l, d.stat)}  Lv $lv/${d.max}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  l.guildSkillValue(pct, maxPct),
                  style: const TextStyle(color: _dim, fontSize: 11.5),
                ),
              ],
            ),
          ),
          if (v.myRole.canEditSkills)
            FilledButton(
              onPressed: can
                  ? () async {
                      final err = await ref
                          .read(guildProvider.notifier)
                          .skillUp(d.id);
                      if (err != null && context.mounted) {
                        showCenterToast(context, guildGrowthErrorText(l, err));
                      }
                    }
                  : null,
              style: FilledButton.styleFrom(
                backgroundColor: _honey,
                foregroundColor: kHoneyInk,
              ),
              child: const Text('+1'),
            ),
        ],
      ),
    );
  }
}

/// 길드 코인 상점.
class GuildShopScreen extends ConsumerStatefulWidget {
  const GuildShopScreen({super.key});

  @override
  ConsumerState<GuildShopScreen> createState() => _GuildShopScreenState();
}

class _GuildShopScreenState extends ConsumerState<GuildShopScreen> {
  bool _busy = false;

  Future<void> _buy(GuildShopEntry e) async {
    final l = AppLocalizations.of(context);
    setState(() => _busy = true);
    final r = await ref.read(guildProvider.notifier).buy(e.item.id);
    if (!mounted) return;
    setState(() => _busy = false);
    showCenterToast(
      context,
      r.error == null
          ? l.guildShopBought(_shopLabel(l, e.item))
          : guildGrowthErrorText(l, r.error!),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final v = ref.watch(guildProvider).value;
    return Scaffold(
      appBar: AppBar(title: Text(l.guildShop)),
      body: v == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                GuildCoinLabel(
                  l.guildCoins(v.myCoins),
                  style: const TextStyle(
                    color: _honey,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l.guildShopNote,
                  style: const TextStyle(color: _dim, fontSize: 11.5),
                ),
                const SizedBox(height: 10),
                for (final e in v.shop)
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0x18000000),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _shopLabel(l, e.item),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                e.item.period == 'week'
                                    ? l.guildShopLimitWeek(
                                        e.bought,
                                        e.item.limit,
                                      )
                                    : l.guildShopLimitDay(
                                        e.bought,
                                        e.item.limit,
                                      ),
                                style: const TextStyle(
                                  color: _dim,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        FilledButton(
                          onPressed:
                              _busy || e.soldOut || v.myCoins < e.item.cost
                              ? null
                              : () => _buy(e),
                          style: FilledButton.styleFrom(
                            backgroundColor: _honey,
                            foregroundColor: kHoneyInk,
                          ),
                          // 가격 단위가 안 보이면 젤리인지 골드인지 모른다 — 코인 그림 + 문구.
                          child: e.soldOut
                              ? Text(l.guildShopSoldOutShort)
                              : GuildCoinLabel(
                                  l.guildCoins(e.item.cost),
                                  iconSize: 18,
                                  flexible: false,
                                ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

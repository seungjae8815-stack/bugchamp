import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/guild_service.dart';
import '../../domain/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/format.dart';
import '../../ui/game_dialog.dart';
import '../../ui/labels.dart';
import '../../ui/toast.dart';
import '../../ui/colors.dart';

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
    Widget btn(String text, VoidCallback? onTap, {bool dot = false}) => Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          OutlinedButton(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              foregroundColor: _honey,
              side: BorderSide(
                color: onTap == null ? const Color(0x33FFFFFF) : _honey,
              ),
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${l.guildLevel(g.level)} · ${l.guildCoins(view.myCoins)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _honey,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 5,
                    backgroundColor: const Color(0x33FFFFFF),
                    valueColor: const AlwaysStoppedAnimation(_green),
                  ),
                ),
              ],
            ),
          ),
          btn(
            view.donatedToday ? l.guildDonateDoneShort : l.guildDonate,
            view.donatedToday
                ? null
                : () async {
                    final err = await ref.read(guildProvider.notifier).donate();
                    if (!context.mounted) return;
                    showCenterToast(
                      context,
                      err == null
                          ? l.guildDonateOk
                          : guildGrowthErrorText(l, err),
                    );
                  },
            dot: !view.donatedToday,
          ),
          btn(
            l.guildSkills,
            () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const GuildSkillScreen()),
            ),
            dot: view.myRole.canManage && g.pointsLeft > 0,
          ),
          btn(
            l.guildShop,
            () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const GuildShopScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

/// 길드 버프 스킬 — 길드장·부길드장이 포인트를 찍는다(모두에게 적용).
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
          if (v != null && v.myRole == GuildRole.leader)
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
                await ref.read(guildProvider.notifier).skillReset();
              },
              child: Text(l.guildSkillReset),
            ),
        ],
      ),
      body: g == null
          ? const Center(child: CircularProgressIndicator())
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
                  _row(context, ref, l, v!, d, g.skills[d.id] ?? 0),
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
    final can = v.myRole.canManage && v.guild!.pointsLeft > 0 && lv < d.max;
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
          if (v.myRole.canManage)
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
                Text(
                  l.guildCoins(v.myCoins),
                  style: const TextStyle(
                    color: _honey,
                    fontWeight: FontWeight.w900,
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
                          child: Text(
                            e.soldOut
                                ? l.guildShopSoldOutShort
                                : formatCompact(e.item.cost),
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

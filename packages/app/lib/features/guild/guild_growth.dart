import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/guild_service.dart';
import '../../domain/providers.dart';
import '../../l10n/app_localizations.dart';
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
                        btn(
                          view.donatedToday
                              ? l.guildDonateDoneShort
                              : l.guildDonate,
                          view.donatedToday
                              ? null
                              : () async {
                                  final err = await ref
                                      .read(guildProvider.notifier)
                                      .donate();
                                  if (!context.mounted) return;
                                  showCenterToast(
                                    context,
                                    err == null
                                        ? l.guildDonateOk
                                        : guildGrowthErrorText(l, err),
                                  );
                                },
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

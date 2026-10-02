import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/guild_service.dart';
import '../../domain/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/labels.dart';
import '../../ui/toast.dart';
import 'guild_boss_tab.dart' show guildBossErrorText;

const _honey = Color(0xFFEBC24A);
const _dim = Color(0x99FFFFFF);
const _green = Color(0xFF9CE37D);
const _red = Color(0xFFE57373);

String guildWarThemeLabel(AppLocalizations l, String? theme) => switch (theme) {
  'breed' => l.guildWarBreed,
  'forge' => l.guildWarForge,
  'hunt' => l.guildWarHunt,
  'duel' => l.guildWarDuel,
  'train' => l.guildWarTrain,
  'boss' => l.guildWarBoss,
  _ => l.guildWarClash,
};

String guildWarThemeHint(AppLocalizations l, String? theme) => switch (theme) {
  'breed' => l.guildWarBreedHint,
  'forge' => l.guildWarForgeHint,
  'hunt' => l.guildWarHuntHint,
  'duel' => l.guildWarDuelHint,
  'train' => l.guildWarTrainHint,
  'boss' => l.guildWarBossHint,
  _ => l.guildWarClashHint,
};

String guildTierLabel(AppLocalizations l, String tier) => switch (tier) {
  'silver' => l.leagueSilver,
  'gold' => l.leagueGold,
  'platinum' => l.leaguePlatinum,
  'diamond' => l.leagueDiamond,
  _ => l.leagueBronze,
};

/// 주간 길드전 탭(docs/design_guild.md §4). 보일 때 한 번 새로 받는다(주기 조회 없음).
class GuildWarTab extends ConsumerStatefulWidget {
  const GuildWarTab({super.key, required this.visible});
  final bool visible;

  @override
  ConsumerState<GuildWarTab> createState() => _GuildWarTabState();
}

class _GuildWarTabState extends ConsumerState<GuildWarTab> {
  bool _busy = false;

  @override
  void didUpdateWidget(GuildWarTab old) {
    super.didUpdateWidget(old);
    if (widget.visible && !old.visible) {
      ref.read(guildWarProvider.notifier).refresh();
    }
  }

  Future<void> _claim() async {
    final l = AppLocalizations.of(context);
    setState(() => _busy = true);
    final r = await ref.read(guildWarProvider.notifier).claim();
    if (!mounted) return;
    setState(() => _busy = false);
    showCenterToast(
      context,
      r.error == null
          ? l.guildWarClaimed(r.coins, r.jelly)
          : guildBossErrorText(l, r.error!),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final async = ref.watch(guildWarProvider);
    final v = async.value;
    if (v == null && !async.hasError) {
      return const Center(child: CircularProgressIndicator());
    }
    if (v == null || !v.available) {
      return Center(
        child: TextButton(
          onPressed: () => ref.invalidate(guildWarProvider),
          child: Text(l.guildUnavailable, textAlign: TextAlign.center),
        ),
      );
    }
    final now = ref.read(clockProvider).now().toUtc();
    final claim = v.claimable;
    final result = v.result;
    return ListView(
      padding: EdgeInsets.fromLTRB(
        12,
        8,
        12,
        12 + MediaQuery.viewPaddingOf(context).bottom,
      ),
      children: [
        Text(
          l.guildWarTier(guildTierLabel(l, v.tier), v.gr),
          style: const TextStyle(color: _honey, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        if (claim != null)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            decoration: BoxDecoration(
              color: const Color(0x2255C7F2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0x8855C7F2)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l.guildWarReward(
                      claim.won ? l.guildWarWin : l.guildWarLose,
                      claim.coins,
                      claim.jelly,
                    ),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                FilledButton(
                  onPressed: _busy ? null : _claim,
                  child: Text(l.guildMissionClaim),
                ),
              ],
            ),
          ),
        if (!v.open)
          Text(
            v.startWeek.isEmpty
                ? l.guildWarClosed
                : l.guildWarOpensOn(v.startWeek),
            style: const TextStyle(color: _dim, height: 1.4),
          )
        else if (!v.hasMatch)
          Text(
            l.guildWarNeedMembers(v.minMembers),
            style: const TextStyle(color: _dim, height: 1.4),
          )
        else ...[
          Text(
            v.virtual ? l.guildWarVsVirtual : l.guildWarVs(v.opponent ?? '?'),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            [
              l.guildWarDayOf(v.day, guildWarThemeLabel(l, v.theme)),
              if (v.endsAt != null)
                l.guildMissionReset(remainLabel(l, v.endsAt!.difference(now))),
            ].join(' · '),
            style: const TextStyle(color: _dim, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0x18000000),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  guildWarThemeHint(l, v.theme),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
                if (v.cap > 0) ...[
                  const SizedBox(height: 6),
                  Text(
                    l.guildWarMyToday(v.myToday, v.cap),
                    style: const TextStyle(
                      color: _honey,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          for (var d = 1; d <= 6; d++) _dayRow(l, v, d),
          if (result != null) ...[
            const SizedBox(height: 12),
            Text(
              result['draw'] == true
                  ? l.guildWarDraw
                  : (result['won'] == true ? l.guildWarWin : l.guildWarLose),
              style: TextStyle(
                color: result['won'] == true
                    ? _green
                    : (result['draw'] == true ? _dim : _red),
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
            Text(
              l.guildWarPoints(
                result['points'] as int? ?? 0,
                result['theirPoints'] as int? ?? 0,
              ),
              style: const TextStyle(color: Colors.white),
            ),
            Text(
              l.guildWarClashResult(
                result['clash'] as int? ?? 0,
                result['theirClash'] as int? ?? 0,
              ),
              style: const TextStyle(color: _dim, fontSize: 12),
            ),
            const SizedBox(height: 6),
            for (final p in (result['pairs'] as List? ?? const []))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Icon(
                      (p as Map)['won'] == true
                          ? Icons.check_circle_rounded
                          : Icons.cancel_rounded,
                      color: p['won'] == true ? _green : _red,
                      size: 15,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${p['me'] ?? '?'}  vs  ${p['them'] ?? l.guildWarVirtualName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ],
    );
  }

  Widget _dayRow(AppLocalizations l, GuildWarView v, int d) {
    final a = d - 1 < v.mine.length ? v.mine[d - 1] : 0;
    final b = d - 1 < v.theirs.length ? v.theirs[d - 1] : 0;
    final past = d < v.day;
    final today = d == v.day;
    final color = !past && !today
        ? const Color(0x44FFFFFF)
        : (a > b ? _green : (a < b ? _red : _dim));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(
              '$d · ${guildWarThemeLabel(l, _themeOf(d))}',
              style: TextStyle(
                color: today ? _honey : _dim,
                fontSize: 12,
                fontWeight: today ? FontWeight.w900 : FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              past || today ? '$a  :  $b' : '—',
              textAlign: TextAlign.center,
              style: TextStyle(color: color, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  String? _themeOf(int d) {
    final days = ref.read(gameDataProvider).value?.guildConfig.war.days;
    return days == null || d > days.length ? null : days[d - 1].theme;
  }
}

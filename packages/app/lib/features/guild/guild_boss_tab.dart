import 'package:core_models/core_models.dart' show ChatRules;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/guild_service.dart';
import '../../domain/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/format.dart';
import '../../ui/labels.dart';
import '../../ui/toast.dart';
import '../../ui/colors.dart';
import 'guild_art.dart';
import 'guild_screen.dart' show guildDisplayName;

const _honey = kHoney;
const _dim = Color(0x99FFFFFF);
const _red = Color(0xFFE57373);

const _lastStyle = TextStyle(color: _honey, fontWeight: FontWeight.w800);

String guildBossErrorText(AppLocalizations l, String code) => switch (code) {
  'no_defense_team' => l.guildBossNoTeam,
  'no_attacks' => l.guildBossNoAttacks,
  'nothing_to_claim' || 'already_claimed' => l.guildMissionErrNothing,
  _ => l.guildErrGeneric,
};

/// 길드 보스 탭(docs/design_guild.md §3). [visible] 이 될 때 한 번 새로 받는다(주기 조회 없음).
class GuildBossTab extends ConsumerStatefulWidget {
  const GuildBossTab({super.key, required this.visible});
  final bool visible;

  @override
  ConsumerState<GuildBossTab> createState() => _GuildBossTabState();
}

class _GuildBossTabState extends ConsumerState<GuildBossTab> {
  bool _busy = false;

  /// 방금 공격 결과(피해·코인·처치) — 코인 앞에 코인 그림을 붙이려고 나눠 둔다.
  ({double damage, int coins, bool killed})? _last;

  @override
  void didUpdateWidget(GuildBossTab old) {
    super.didUpdateWidget(old);
    if (widget.visible && !old.visible) {
      ref.read(guildBossProvider.notifier).refresh();
    }
  }

  Future<void> _attack() async {
    final l = AppLocalizations.of(context);
    setState(() => _busy = true);
    final r = await ref.read(guildBossProvider.notifier).attack();
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (r.error == null) {
        _last = (damage: r.damage, coins: r.coins, killed: r.killed);
      }
    });
    if (r.error != null) {
      showCenterToast(context, guildBossErrorText(l, r.error!));
    }
  }

  Future<void> _claim() async {
    final l = AppLocalizations.of(context);
    setState(() => _busy = true);
    final r = await ref.read(guildBossProvider.notifier).claim();
    if (!mounted) return;
    setState(() => _busy = false);
    showCenterToast(
      context,
      r.error == null
          ? l.guildBossClaimed(r.jelly)
          : guildBossErrorText(l, r.error!),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final async = ref.watch(guildBossProvider);
    final v = async.value;
    if (v == null && !async.hasError) {
      return const Center(child: CircularProgressIndicator());
    }
    // 오류면 무한 로딩 대신 다시 시도.
    if (v == null || !v.available) {
      return Center(
        child: TextButton(
          onPressed: () => ref.invalidate(guildBossProvider),
          child: Text(l.guildUnavailable, textAlign: TextAlign.center),
        ),
      );
    }
    final now = ref.read(clockProvider).now().toUtc();
    final rules =
        ref.watch(gameDataProvider).value?.chatRules ?? const ChatRules();
    return ListView(
      padding: EdgeInsets.fromLTRB(
        12,
        8,
        12,
        12 + MediaQuery.viewPaddingOf(context).bottom,
      ),
      children: [
        if (v.canClaimLast)
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
                    l.guildBossLastWeek(v.lastRank ?? 0, v.lastJelly),
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
        Text(
          l.guildBossTitle(v.stage),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 4),
        // 길드 보스 전신(거대 말벌 여왕) — 체력바 바로 위. 쓰러진 만큼 살짝 어두워진다.
        SizedBox(
          key: const ValueKey('guildBossArt'),
          height: 180,
          child: Opacity(
            opacity: 1 - v.progress * 0.35,
            child: guildArt(
              'boss',
              fit: BoxFit.contain,
              fallback: const Icon(
                Icons.pest_control_rounded,
                color: _red,
                size: 96,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: LinearProgressIndicator(
            value: 1 - v.progress,
            minHeight: 12,
            backgroundColor: const Color(0x33FFFFFF),
            valueColor: const AlwaysStoppedAnimation(_red),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          [
            '${formatCompact(v.hpLeft)} / ${formatCompact(v.hpMax)}',
            if (v.endsAt != null)
              l.guildMissionReset(remainLabel(l, v.endsAt!.difference(now))),
          ].join(' · '),
          style: const TextStyle(color: _dim, fontSize: 11.5),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _busy || !v.hasTeam || v.attacksLeft <= 0 ? null : _attack,
          style: FilledButton.styleFrom(
            backgroundColor: _honey,
            foregroundColor: kHoneyInk,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          child: Text(l.guildBossAttack(v.attacksLeft)),
        ),
        const SizedBox(height: 6),
        Text(
          v.hasTeam ? l.guildBossNote : l.guildBossNoTeam,
          style: TextStyle(
            color: v.hasTeam ? _dim : _red,
            fontSize: 11.5,
            height: 1.35,
          ),
        ),
        if (_last case final last?) ...[
          const SizedBox(height: 6),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 2,
            children: [
              Text(
                l.guildBossHit(formatCompact(last.damage)),
                style: _lastStyle,
              ),
              GuildCoinLabel(
                l.guildMissionCoins(last.coins),
                style: _lastStyle,
                flexible: false,
              ),
              if (last.killed) Text(l.guildBossKilled, style: _lastStyle),
            ],
          ),
        ],
        const SizedBox(height: 6),
        Text(
          l.guildBossMine(formatCompact(v.myDamage)),
          style: const TextStyle(color: Colors.white, fontSize: 12.5),
        ),
        const SizedBox(height: 14),
        Text(
          v.rank == null ? l.guildBossRankNone : l.guildBossRank(v.rank!),
          style: const TextStyle(color: _honey, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        for (final r in v.top)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: Text(
                    '${r.rank}',
                    style: const TextStyle(
                      color: _honey,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                GuildEmblem(emblem: r.emblem, size: 22),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    guildDisplayName(l, rules, r.name),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                Text(
                  l.guildBossTopRow(r.stage, (r.progress * 100).floor()),
                  style: const TextStyle(color: _dim, fontSize: 12),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

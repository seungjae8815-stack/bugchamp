import 'dart:async';

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

const _honey = kHoney;
const _dim = Color(0x99FFFFFF);
const _green = Color(0xFF9CE37D);

/// 미션 이름(분위기) — 서버 게시판의 `kind`.
String guildMissionKindLabel(AppLocalizations l, String kind) => switch (kind) {
  'forest' => l.guildMissionForest,
  'cave' => l.guildMissionCave,
  'swamp' => l.guildMissionSwamp,
  'ruins' => l.guildMissionRuins,
  'canyon' => l.guildMissionCanyon,
  _ => l.guildMissionMeadow,
};

String guildMissionErrorText(AppLocalizations l, String code) => switch (code) {
  'no_starts_left' => l.guildMissionErrNoStarts,
  'mission_running' => l.guildMissionErrRunning,
  'mission_closed' => l.guildMissionErrClosed,
  'already_helped' => l.guildMissionErrHelped,
  'helpers_full' => l.guildMissionErrHelpersFull,
  'own_mission' => l.guildMissionErrOwn,
  'nothing_to_claim' => l.guildMissionErrNothing,
  _ => l.guildErrGeneric,
};

/// 도와주기 공용(미션 탭 · 길드 채팅 카드).
Future<void> guildHelpMission(
  BuildContext context,
  WidgetRef ref,
  String missionId,
) async {
  final l = AppLocalizations.of(context);
  final err = await ref.read(guildMissionProvider.notifier).help(missionId);
  if (!context.mounted) return;
  showCenterToast(
    context,
    err == null ? l.guildMissionHelped : guildMissionErrorText(l, err),
  );
}

/// 길드 미션 탭(docs/design_guild.md §2).
///
/// [visible] 일 때만 1초마다 남은 시간을 다시 그리고 [GuildMissionConfig.pollSeconds] 마다 서버를 조회한다
/// — 탭을 떠나면 멈춘다(요금은 조회 수에 선형).
class GuildMissionTab extends ConsumerStatefulWidget {
  const GuildMissionTab({super.key, required this.visible});

  final bool visible;

  @override
  ConsumerState<GuildMissionTab> createState() => _GuildMissionTabState();
}

class _GuildMissionTabState extends ConsumerState<GuildMissionTab> {
  Timer? _tick;
  int _sinceFetch = 0;
  bool _busy = false;

  GuildMissionConfig get _cfg =>
      ref.read(gameDataProvider).value?.guildConfig.mission ??
      const GuildMissionConfig();

  @override
  void initState() {
    super.initState();
    if (widget.visible) _resume();
  }

  @override
  void didUpdateWidget(GuildMissionTab old) {
    super.didUpdateWidget(old);
    if (widget.visible && !old.visible) _resume();
    if (!widget.visible && old.visible) _pause();
  }

  @override
  void dispose() {
    _pause();
    super.dispose();
  }

  void _resume() {
    _sinceFetch = 0;
    Future.microtask(() => ref.read(guildMissionProvider.notifier).refresh());
    _tick ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (++_sinceFetch >= _cfg.pollSeconds) {
        _sinceFetch = 0;
        ref.read(guildMissionProvider.notifier).refresh();
      }
      setState(() {});
    });
  }

  void _pause() {
    _tick?.cancel();
    _tick = null;
  }

  DateTime _now(GuildMissionsView v) =>
      ref.read(clockProvider).now().toUtc().add(v.serverOffset);

  String _mmss(Duration d) {
    final s = d.isNegative ? 0 : d.inSeconds;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  Future<void> _start(GuildMissionSlot slot) async {
    final l = AppLocalizations.of(context);
    final cfg = _cfg;
    final wait = await showGameDialog<int>(
      context,
      title: guildMissionKindLabel(l, slot.kind),
      icon: Icons.flag_rounded,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            slot.mult <= 1 ? l.guildMissionSoloHint : l.guildMissionWaitHint,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xD9FFFFFF),
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < cfg.waitSeconds.length; i++)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context, cfg.waitSeconds[i]),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _honey,
                  side: const BorderSide(color: _honey),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                child: Text(
                  l.guildMissionWaitOption(
                    cfg.waitSeconds[i] ~/ 60,
                    i < cfg.waitMults.length
                        ? cfg.waitMults[i].toStringAsFixed(2)
                        : '1.00',
                  ),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
        ],
      ),
      actions: [
        gameDialogButton(
          l.actionCancel,
          () => Navigator.pop(context),
          primary: false,
        ),
      ],
    );
    if (wait == null || !mounted) return;
    setState(() => _busy = true);
    final err = await ref
        .read(guildMissionProvider.notifier)
        .start(slot.slot, wait);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) showCenterToast(context, guildMissionErrorText(l, err));
  }

  Future<void> _claim() async {
    final l = AppLocalizations.of(context);
    setState(() => _busy = true);
    final r = await ref.read(guildMissionProvider.notifier).claim();
    if (!mounted) return;
    setState(() => _busy = false);
    if (r.error != null) {
      showCenterToast(context, guildMissionErrorText(l, r.error!));
      return;
    }
    await showGameDialog<void>(
      context,
      title: l.guildMissionClaimTitle,
      icon: Icons.card_giftcard_rounded,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          gameRewardList(
            context,
            materials: {
              MaterialKind.chitin: r.reward.chitin,
              MaterialKind.mineral: r.reward.mineral,
              MaterialKind.sap: r.reward.sap,
              MaterialKind.fossil: r.reward.fossil,
            },
          ),
          const SizedBox(height: 8),
          if (r.reward.coins > 0)
            Text(
              l.guildMissionCoins(r.reward.coins),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _honey,
                fontWeight: FontWeight.w800,
              ),
            ),
          if (r.eggs > 0)
            Text(
              l.guildMissionEgg(r.eggs),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _green,
                fontWeight: FontWeight.w800,
              ),
            ),
        ],
      ),
      actions: [
        gameDialogButton(l.eventRewardClaim, () => Navigator.pop(context)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final async = ref.watch(guildMissionProvider);
    final v = async.value;
    if (v == null && !async.hasError) {
      return const Center(child: CircularProgressIndicator());
    }
    // 오류면 무한 로딩 대신 다시 시도.
    if (v == null || !v.available) {
      return Center(
        child: TextButton(
          onPressed: () => ref.invalidate(guildMissionProvider),
          child: Text(l.guildUnavailable, textAlign: TextAlign.center),
        ),
      );
    }
    final cfg = _cfg;
    final now = _now(v);
    final reset = v.nextDayAt;
    return ListView(
      padding: EdgeInsets.fromLTRB(
        12,
        6,
        12,
        12 + MediaQuery.viewPaddingOf(context).bottom,
      ),
      children: [
        Text(
          [
            l.guildMissionStartsLeft(v.startsLeft, cfg.dailyStarts),
            l.guildMissionHelpLeft(v.helpRewardsLeft, cfg.helpRewardsPerDay),
            if (reset != null)
              l.guildMissionReset(remainLabel(l, reset.difference(now))),
          ].join(' · '),
          style: const TextStyle(color: _dim, fontSize: 11.5),
        ),
        if (v.claimable > 0) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            decoration: BoxDecoration(
              color: _green.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _green.withValues(alpha: 0.6)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l.guildMissionClaimable(v.claimable),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                FilledButton(
                  onPressed: _busy ? null : _claim,
                  style: FilledButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: const Color(0xFF10200A),
                  ),
                  child: Text(l.guildMissionClaim),
                ),
              ],
            ),
          ),
        ],
        _header(l.guildMissionActive),
        if (v.active.isEmpty)
          _empty(l.guildMissionNoActive)
        else
          for (final m in v.active) _activeCard(l, m, now),
        _header(l.guildMissionBoard),
        for (final s in v.board) _slotCard(l, v, s),
        if (v.recent.isNotEmpty) ...[
          _header(l.guildMissionRecent),
          for (final m in v.recent) _recentRow(l, m),
        ],
      ],
    );
  }

  Widget _header(String text) => Padding(
    padding: const EdgeInsets.only(top: 14, bottom: 6),
    child: Text(
      text,
      style: const TextStyle(
        color: _honey,
        fontWeight: FontWeight.w900,
        fontSize: 13,
      ),
    ),
  );

  Widget _empty(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(text, style: const TextStyle(color: _dim, fontSize: 12)),
  );

  BoxDecoration get _card => BoxDecoration(
    color: const Color(0x18000000),
    borderRadius: BorderRadius.circular(10),
  );

  Widget _activeCard(AppLocalizations l, GuildMissionInfo m, DateTime now) {
    final canHelp = !m.mine && !m.helped && m.helpers.length < m.helperMax;
    final rules =
        ref.read(gameDataProvider).value?.chatRules ?? const ChatRules();
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: _card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${guildMissionKindLabel(l, m.kind)} ×${m.mult}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                _mmss(m.endsAt.difference(now)),
                style: const TextStyle(color: _dim, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            m.mine
                ? l.guildMissionMine
                : l.guildMissionOwner(
                    rules.maskNickname(
                      m.ownerNick,
                      fallback: l.nicknameFallback,
                    ),
                  ),
            style: const TextStyle(color: _dim, fontSize: 11.5),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: m.progress,
              minHeight: 7,
              backgroundColor: const Color(0x33FFFFFF),
              valueColor: AlwaysStoppedAnimation(
                m.progress >= 1 ? _green : _honey,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  l.guildMissionProgress(
                    (m.progress * 100).floor(),
                    m.helpers.length,
                    m.helperMax,
                  ),
                  style: const TextStyle(color: _dim, fontSize: 11.5),
                ),
              ),
              if (canHelp)
                FilledButton(
                  onPressed: _busy
                      ? null
                      : () => guildHelpMission(context, ref, m.id),
                  style: FilledButton.styleFrom(
                    backgroundColor: _honey,
                    foregroundColor: kHoneyInk,
                    visualDensity: VisualDensity.compact,
                  ),
                  child: Text(l.guildMissionHelp),
                )
              else if (m.helped)
                Text(
                  l.guildMissionHelpedTag,
                  style: const TextStyle(color: _green, fontSize: 12),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _slotCard(
    AppLocalizations l,
    GuildMissionsView v,
    GuildMissionSlot s,
  ) {
    final can = !_busy && v.startsLeft > 0 && !v.hasRunning;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: _card,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  guildMissionKindLabel(l, s.kind),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  s.mult <= 1
                      ? l.guildMissionSlotSolo(s.mult)
                      : l.guildMissionSlotNeed(s.mult),
                  style: const TextStyle(color: _dim, fontSize: 11.5),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: can ? () => _start(s) : null,
            style: OutlinedButton.styleFrom(
              foregroundColor: _honey,
              side: BorderSide(color: can ? _honey : const Color(0x33FFFFFF)),
            ),
            child: Text(
              l.guildMissionStart,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _recentRow(AppLocalizations l, GuildMissionInfo m) {
    final rules =
        ref.read(gameDataProvider).value?.chatRules ?? const ChatRules();
    final who = m.mine
        ? l.guildMissionMine
        : rules.maskNickname(m.ownerNick, fallback: l.nicknameFallback);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
            m.success ? Icons.check_circle_rounded : Icons.timelapse_rounded,
            color: m.success ? _green : _dim,
            size: 16,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '$who · ${guildMissionKindLabel(l, m.kind)} ×${m.mult}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 12.5),
            ),
          ),
          Text(
            m.success
                ? l.guildMissionSuccess
                : l.guildMissionPartial((m.ratio * 100).floor()),
            style: TextStyle(color: m.success ? _green : _dim, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

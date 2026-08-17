import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:core_save/core_save.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/game_data.dart';
import '../../domain/game_server.dart';
import '../../domain/providers.dart';
import '../../domain/save_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/art.dart';
import '../../ui/format.dart';
import '../../ui/game_dialog.dart';
import '../../ui/labels.dart';
import '../../ui/toast.dart';
import 'event_replay.dart';

const _honey = Color(0xFFEBA52F);

/// 홈 배너용 이벤트 현황. 서버가 없거나 이벤트가 닫혀 있으면 null 이라
/// 배너 자체가 뜨지 않는다 — 이벤트는 서버 없이는 성립하지 않는다.
final eventStateProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final server = ref.watch(gameServerProvider);
  if (!server.available) return null;
  final r = await server.eventState();
  return r.isOk ? r.data : null;
});

/// 실물 경품 랭킹 이벤트 — 「왕충 선발대회」(docs/event_ranking_prize.md).
///
/// ⚠️ **서버 없이는 열리지 않는다.** 순위가 그대로 실물 상품이라 로컬 계산으로
/// 점수를 만들 수 있으면 안 된다. 이 화면은 서버가 확정한 결과를 보여주고
/// 재생할 뿐, 점수를 스스로 계산하지 않는다.
class EventScreen extends ConsumerStatefulWidget {
  const EventScreen({super.key});

  @override
  ConsumerState<EventScreen> createState() => _EventScreenState();
}

class _EventScreenState extends ConsumerState<EventScreen> {
  Map<String, dynamic>? _state;
  List<Map<String, dynamic>> _ranks = const [];
  final List<String> _team = [];
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final server = ref.read(gameServerProvider);
    if (!server.available) {
      setState(() {
        _loading = false;
        _error = 'no_server';
      });
      return;
    }
    final st = await server.eventState();
    final lb = await server.eventLeaderboard();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = st.isOk ? null : (st.error ?? 'failed');
      _state = st.isOk ? st.data : null;
      _ranks = lb.isOk
          ? ((lb.data?['entries'] as List?) ?? const [])
                .cast<Map<String, dynamic>>()
          : const [];
    });
  }

  Future<void> _challenge(AppLocalizations l) async {
    if (_team.length != 3 || _busy) return;
    setState(() => _busy = true);
    final server = ref.read(gameServerProvider);
    final r = await server.eventChallenge(List<String>.from(_team));
    if (!mounted) return;
    setState(() => _busy = false);
    if (!r.isOk) {
      showCenterToast(context, _errorText(l, r.error));
      return;
    }
    // 서버가 세이브를 돌려주므로 로컬도 그 값으로 맞춘다 — 참가권·피로는
    // 서버 소유라 여기서 받아야 화면이 맞는다.
    final save = r.save;
    if (save != null) {
      await ref.read(saveControllerProvider.notifier).adoptServerSave(save);
    }
    final wave = (r.data?['wave'] as num?)?.toInt() ?? 0;
    final score = (r.data?['score'] as num?)?.toInt() ?? 0;
    final isBest = r.data?['isBest'] == true;
    final seed = (r.data?['seed'] as num?)?.toInt();

    // 출전한 곤충을 **순서 그대로** 넘겨 재생한다. 세이브가 서버 값으로 바뀐
    // 뒤에도 개체는 그대로 남아 있다(피로만 붙는다).
    final current = ref.read(saveControllerProvider).requireValue;
    final byId = {for (final b in current.bugs) b.id: b};
    final team = [
      for (final id in _team)
        if (byId[id] != null) byId[id]!,
    ];
    final data = ref.read(gameDataProvider).requireValue;
    _team.clear();
    await _refresh();
    if (!mounted) return;

    // seed 가 있고 팀이 온전하면 **판을 다시 그린다**(결정론이라 서버와 같은 판).
    // 화면에 쓰는 숫자는 서버 값 그대로다 — 앱 데이터가 낡았을 때 갈리면 안 된다.
    if (seed != null && team.length == 3) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => EventReplayScreen(
            data: data,
            seed: seed,
            team: team,
            serverWave: wave,
            serverScore: score,
            isBest: isBest,
          ),
        ),
      );
      return;
    }

    // 재생할 수 없으면(구버전 서버 등) 결과만 알린다.
    final best = (r.data?['best'] as num?)?.toInt() ?? 0;
    await showGameDialog<void>(
      context,
      title: l.eventResultTitle(wave),
      icon: Icons.emoji_events_rounded,
      content: Text(
        isBest ? l.eventNewBest : l.eventKeptBest(best),
        style: const TextStyle(color: Color(0xDDFFFFFF), height: 1.4),
      ),
      actions: [gameDialogButton(l.actionClose, () => Navigator.pop(context))],
    );
  }

  String _errorText(AppLocalizations l, String? code) => switch (code) {
    'no_ticket' => l.eventNoTicket,
    'fatigued' => l.eventFatigueLeft(''),
    'ad_limit' => l.eventAdLimit,
    'ticket_full' => l.eventTicketFull,
    'event_closed' => l.eventClosed,
    _ => l.cloudFailed,
  };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final save = ref.watch(saveControllerProvider).requireValue;
    final data = ref.watch(gameDataProvider).requireValue;
    final now = ref.read(clockProvider).now().toUtc();

    return Scaffold(
      appBar: AppBar(title: Text(l.eventTitle)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _closed(l)
          : ListView(
              padding: EdgeInsets.only(
                bottom: 24 + MediaQuery.viewPaddingOf(context).bottom,
              ),
              children: [
                _header(l),
                // 실물 배송 범위는 **상시 표시**한다. 공지 한 줄로는 부족하다 —
                // 해외 유저가 1등을 하고 못 받는 게 가장 나쁜 그림이다.
                _notice(l.eventKoreaOnly, const Color(0xFFFFD08A)),
                if (_state?['rankEligible'] == false)
                  _notice(l.eventAnonWarn, const Color(0xFFFF8A65)),
                _normalizeCard(l),
                _teamPicker(context, l, data, save, now),
                _challengeButton(l, save),
                const Divider(height: 24, color: Color(0x22FFFFFF)),
                _rankList(l),
              ],
            ),
    );
  }

  Widget _closed(AppLocalizations l) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        _error == 'no_server' ? l.eventNeedServer : l.eventClosed,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Color(0x99FFFFFF), height: 1.4),
      ),
    ),
  );

  Widget _header(AppLocalizations l) {
    final tickets = (_state?['tickets'] as num?)?.toInt() ?? 0;
    final max = (_state?['ticketMax'] as num?)?.toInt() ?? 5;
    final bestWave = (_state?['bestWave'] as num?)?.toInt() ?? 0;
    final bestScore = (_state?['bestScore'] as num?)?.toInt() ?? 0;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0x22000000),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _honey.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.eventBestRecord,
                  style: const TextStyle(
                    color: Color(0x99FFFFFF),
                    fontSize: 11.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  bestWave <= 0
                      ? l.eventNoRecord
                      : '${l.eventWaveRecord(bestWave)} · ${l.eventScore(formatCompact(bestScore))}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _honey.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _honey),
            ),
            child: Text(
              l.eventTickets(tickets, max),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _notice(String text, Color color) => Padding(
    padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
    child: Text(
      text,
      style: TextStyle(color: color, fontSize: 11.5, height: 1.35),
    ),
  );

  /// 정규화 안내 — **크게 적는다.** 안 적으면 "강화한 곤충이 약해졌다"는
  /// 문의가 반드시 들어온다. 이건 UI 문제가 아니라 신뢰 문제다.
  Widget _normalizeCard(AppLocalizations l) => Container(
    margin: const EdgeInsets.fromLTRB(12, 4, 12, 10),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0x1A2E6DA4),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0x662E6DA4)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.balance_rounded, size: 16, color: _honey),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                l.eventNormalizeTitle,
                style: const TextStyle(
                  color: _honey,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          l.eventNormalizeBody,
          style: const TextStyle(
            color: Color(0xDDFFFFFF),
            fontSize: 12,
            height: 1.4,
          ),
        ),
      ],
    ),
  );

  Widget _teamPicker(
    BuildContext context,
    AppLocalizations l,
    GameData data,
    SaveGame save,
    DateTime now,
  ) {
    final cfg = data.petConfig;
    final adults = save.bugs.where((b) {
      final st = cfg == null
          ? b.stage
          : effectiveStage(b.stage, b.stageSince, now, cfg);
      return st == LifeStage.adult;
    }).toList();
    // 쉬고 있는 곤충은 뒤로 — 지금 고를 수 없으니 눈에 먼저 들어올 이유가 없다.
    int gradeIdx(IndividualBug b) =>
        data.speciesById[b.speciesId]?.grade.index ?? -1;
    adults.sort((a, b) {
      final af = save.eventOnFatigue(a.id, now) ? 1 : 0;
      final bf = save.eventOnFatigue(b.id, now) ? 1 : 0;
      if (af != bf) return af - bf;
      return gradeIdx(b).compareTo(gradeIdx(a));
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 2),
          child: Text(
            l.eventPickTeam,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 13.5,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
          child: Text(
            l.eventPickOrder,
            style: const TextStyle(color: Color(0x99FFFFFF), fontSize: 11),
          ),
        ),
        SizedBox(
          height: 116,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            itemCount: adults.length,
            itemBuilder: (c, i) {
              final bug = adults[i];
              final sp = data.speciesById[bug.speciesId];
              if (sp == null) return const SizedBox.shrink();
              final until = save.eventFatigue[bug.id];
              final resting = until != null && now.isBefore(until);
              final picked = _team.indexOf(bug.id);
              return _bugTile(
                l,
                bug,
                sp,
                order: picked < 0 ? null : picked + 1,
                resting: resting ? until.difference(now) : null,
                onTap: () => setState(() {
                  if (picked >= 0) {
                    _team.removeAt(picked);
                  } else if (_team.length < 3) {
                    _team.add(bug.id);
                  }
                }),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _bugTile(
    AppLocalizations l,
    IndividualBug bug,
    Species sp, {
    required int? order,
    required Duration? resting,
    required VoidCallback onTap,
  }) {
    final locale = Localizations.localeOf(context).languageCode;
    return GestureDetector(
      onTap: resting == null ? onTap : null,
      child: Opacity(
        opacity: resting == null ? 1 : 0.4,
        child: Container(
          width: 86,
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: order != null
                ? _honey.withValues(alpha: 0.2)
                : const Color(0x22000000),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: order != null
                  ? _honey
                  : gradeColor(sp.grade).withValues(alpha: 0.6),
              width: order != null ? 2 : 1.2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.topRight,
                children: [
                  bugStageImage(
                    bug.speciesId,
                    LifeStage.adult,
                    size: 44,
                    fallback: bugAvatar(sp, size: 40),
                  ),
                  if (order != null)
                    Container(
                      width: 18,
                      height: 18,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: _honey,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$order',
                        style: const TextStyle(
                          color: Color(0xFF3A2600),
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                sp.name.resolve(locale),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 10.5),
              ),
              Text(
                resting == null
                    ? elementGlyph(bug.element)
                    : l.eventFatigueLeft(remainLabel(l, resting)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: resting == null
                      ? const Color(0xCCFFFFFF)
                      : const Color(0xFFFFB0A0),
                  fontSize: resting == null ? 12 : 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _challengeButton(AppLocalizations l, SaveGame save) {
    final tickets = (_state?['tickets'] as num?)?.toInt() ?? 0;
    final ready = _team.length == 3 && tickets > 0 && !_busy;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: ready ? () => _challenge(l) : null,
              style: FilledButton.styleFrom(
                backgroundColor: _honey,
                foregroundColor: const Color(0xFF3A2600),
                minimumSize: const Size(0, 46),
              ),
              child: Text(
                tickets > 0 ? l.eventChallenge : l.eventNoTicket,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
          const SizedBox(height: 6),
          TextButton.icon(
            onPressed: _busy
                ? null
                : () async {
                    final r = await ref
                        .read(gameServerProvider)
                        .eventAdTicket();
                    if (!mounted) return;
                    if (!r.isOk) {
                      showCenterToast(context, _errorText(l, r.error));
                      return;
                    }
                    final save = r.save;
                    if (save != null) {
                      await ref
                          .read(saveControllerProvider.notifier)
                          .adoptServerSave(save);
                    }
                    await _refresh();
                  },
            icon: const Icon(Icons.play_circle_outline, size: 18),
            label: Text(l.eventAdTicket),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xCCFFFFFF),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rankList(AppLocalizations l) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
        child: Text(
          l.eventRanking,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 14,
          ),
        ),
      ),
      if (_ranks.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Text(
            l.eventRankEmpty,
            style: const TextStyle(color: Color(0x99FFFFFF), fontSize: 12),
          ),
        )
      else
        for (final e in _ranks)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: e['isMe'] == true
                  ? _honey.withValues(alpha: 0.16)
                  : const Color(0x18000000),
              borderRadius: BorderRadius.circular(10),
              border: e['isMe'] == true
                  ? Border.all(color: _honey.withValues(alpha: 0.7))
                  : null,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 30,
                  child: Text(
                    '${e['rank']}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xCCFFFFFF),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${e['nickname']}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 13.5),
                  ),
                ),
                Text(
                  l.eventWaveRecord((e['wave'] as num?)?.toInt() ?? 0),
                  style: const TextStyle(
                    color: _honey,
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
    ],
  );
}

import 'package:core_models/core_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/game_server.dart';
import '../../domain/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/event_badge.dart';

const _honey = Color(0xFFEBA52F);

/// 명예의 전당 — **가장 최근에 끝난 회차**의 순위를 남긴다(2026-09-15).
///
/// 대회가 끝나면 화면이 "열린 대회가 없어요" 한 줄로 닫혀서, 2주를 뛴 사람들의
/// 이름이 어디에도 안 남았다. 다음 회차를 기다리는 동안 보이는 자리에
/// 1~3위 시상대 · 4~10위 · 참가자 전원을 싣는다.
///
/// 명단과 뱃지는 **서버가 그 회차 순위로 계산해** 준다(`/event/hall`). 지금의
/// 대표 뱃지를 쓰면 다음 회차에 바뀐 뱃지가 지난 명단에 붙는다.
class EventHallSection extends ConsumerStatefulWidget {
  const EventHallSection({super.key});

  @override
  ConsumerState<EventHallSection> createState() => _EventHallSectionState();
}

class _EventHallSectionState extends ConsumerState<EventHallSection> {
  bool _loading = true;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final server = ref.read(gameServerProvider);
    if (!server.available) {
      setState(() => _loading = false);
      return;
    }
    final r = await server.eventHall();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _data = r.isOk ? r.data : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    // 못 읽었으면(오프라인·구버전 서버) 섹션을 통째로 감춘다. "아직 아무도
    // 없어요"라고 말하면 사실이 아닌 말을 하는 셈이다.
    if (_data == null) return const SizedBox.shrink();
    final round = _data?['round'] as Map<String, dynamic>?;
    final entries = ((_data?['entries'] as List?) ?? const [])
        .cast<Map<String, dynamic>>();
    final truncated = _data?['truncated'] == true;
    final rules =
        ref.watch(gameDataProvider).value?.chatRules ?? const ChatRules();
    String name(Map<String, dynamic> e) => rules.maskNickname(
      '${e['nickname'] ?? ''}',
      fallback: l.nicknameFallback,
    );

    final podium = entries.where((e) => _rank(e) <= 3).toList();
    final top10 = entries.where((e) => _rank(e) > 3 && _rank(e) <= 10);
    final rest = entries.where((e) => _rank(e) > 10).toList();

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x33EBC24A), Color(0x14000000)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x66EBC24A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.workspace_premium_rounded,
                color: Color(0xFFFFC24D),
                size: 22,
              ),
              const SizedBox(width: 6),
              Text(
                l.eventHallTitle,
                style: const TextStyle(
                  color: Color(0xFFFFD98A),
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          if (round != null) ...[
            const SizedBox(height: 4),
            Text(
              l.eventHallRound(
                (round['no'] as num?)?.toInt() ?? 0,
                '${entries.length}${truncated ? '+' : ''}',
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xAAFFFFFF),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 14),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                l.eventHallEmpty,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0x99FFFFFF),
                  fontSize: 12.5,
                ),
              ),
            )
          else ...[
            _podium(l, podium, name),
            if (top10.isNotEmpty) ...[
              const SizedBox(height: 14),
              _sectionLabel(l.eventHallTop10),
              for (final e in top10) _row(l, e, name(e)),
            ],
            if (rest.isNotEmpty) ...[
              const SizedBox(height: 14),
              _sectionLabel(l.eventHallEntrants),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final e in rest) _pill(name(e), me: e['isMe'] == true),
                  if (truncated) _pill(l.eventHallMore),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  static int _rank(Map<String, dynamic> e) => (e['rank'] as num?)?.toInt() ?? 0;

  static Color _medal(int rank) => switch (rank) {
    1 => const Color(0xFFFFC24D),
    2 => const Color(0xFFC0C7D0),
    _ => const Color(0xFFCD8A4E),
  };

  /// 1~3위 시상대 — 1위를 가운데 가장 높게, 2위 왼쪽, 3위 오른쪽.
  Widget _podium(
    AppLocalizations l,
    List<Map<String, dynamic>> top,
    String Function(Map<String, dynamic>) name,
  ) {
    Map<String, dynamic>? at(int rank) {
      for (final e in top) {
        if (_rank(e) == rank) return e;
      }
      return null;
    }

    Widget step(int rank, double height) {
      final e = at(rank);
      final color = _medal(rank);
      return Expanded(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (e != null) ...[
              Icon(
                rank == 1
                    ? Icons.emoji_events_rounded
                    : Icons.military_tech_rounded,
                color: color,
                size: rank == 1 ? 34 : 26,
                shadows: [
                  Shadow(color: color.withValues(alpha: 0.6), blurRadius: 12),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                name(e),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: e['isMe'] == true ? _honey : Colors.white,
                  fontSize: rank == 1 ? 14.5 : 12.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                l.eventWaveRecord('${(e['wave'] as num?)?.toInt() ?? 0}'),
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
            ],
            Container(
              height: height,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    color.withValues(alpha: 0.55),
                    color.withValues(alpha: 0.15),
                  ],
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(8),
                ),
                border: Border.all(color: color.withValues(alpha: 0.7)),
              ),
              alignment: Alignment.center,
              child: Text(
                '$rank',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [step(2, 44), step(1, 64), step(3, 32)],
    );
  }

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(
      text,
      style: const TextStyle(
        color: Color(0xCCFFD98A),
        fontSize: 12.5,
        fontWeight: FontWeight.w900,
      ),
    ),
  );

  Widget _row(AppLocalizations l, Map<String, dynamic> e, String nickname) {
    final me = e['isMe'] == true;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: me ? _honey.withValues(alpha: 0.16) : const Color(0x18000000),
        borderRadius: BorderRadius.circular(8),
        border: me ? Border.all(color: _honey.withValues(alpha: 0.7)) : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 26,
            child: Text(
              '${_rank(e)}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xCCFFFFFF),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            // 뱃지는 이름 **위** — 옆에 두면 이름이 잘린다(랭킹과 같은 이유).
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                EventBadgeChip(
                  id: '${e['badge'] ?? ''}',
                  size: 10,
                  margin: EventBadgeChip.aboveName,
                ),
                Text(
                  nickname,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ],
            ),
          ),
          Text(
            l.eventWaveRecord('${(e['wave'] as num?)?.toInt() ?? 0}'),
            style: const TextStyle(
              color: _honey,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(String text, {bool me = false}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: me ? _honey.withValues(alpha: 0.2) : const Color(0x22FFFFFF),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: me ? _honey : const Color(0x33FFFFFF)),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: me ? _honey : const Color(0xDDFFFFFF),
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

/// 명예의 전당 단독 화면 — 대회가 열려 있는 동안 지난 회차를 보고 싶을 때.
class EventHallScreen extends StatelessWidget {
  const EventHallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.eventHallTitle)),
      body: ListView(
        padding: EdgeInsets.only(
          top: 8,
          bottom: 24 + MediaQuery.viewPaddingOf(context).bottom,
        ),
        children: const [EventHallSection()],
      ),
    );
  }
}

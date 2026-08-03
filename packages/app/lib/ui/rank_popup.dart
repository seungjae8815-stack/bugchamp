import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/audio_service.dart';
import '../domain/providers.dart';
import '../domain/pvp_backend.dart';
import '../domain/rank_history.dart';
import '../domain/save_controller.dart';
import '../l10n/app_localizations.dart';
import 'game_dialog.dart';

const _honey = Color(0xFFEBA52F);
const _up = Color(0xFF6FD08C);
const _down = Color(0xFFEF7A6B);

/// 앱 시작 시 1회: 내 랭킹과 **직전 확인 대비 변동**을 팝업으로 보여준다.
///
/// 순위를 확정할 수 없으면(미로그인·오프라인·로컬 백엔드·순위권 밖) 조용히
/// 아무것도 하지 않는다 — 지어낸 등수를 띄우느니 안 띄우는 게 낫다.
Future<void> showRankPopupOnStart(BuildContext context, WidgetRef ref) async {
  final save = ref.read(saveControllerProvider).value;
  if (save == null) return;
  final backend = ref.read(pvpBackendProvider);
  if (!backend.isRemote) return;

  final rank = await backend.myRank(
    me: PvpProfile(
      id: 'me',
      nickname: save.nickname,
      trophies: save.pvpTrophies,
    ),
  );
  if (rank == null || !context.mounted) return;

  final report = await RankHistory.instance.record(
    rank,
    today: ref.read(clockProvider).now(), // 로컬 날짜 기준
  );
  if (!context.mounted) return;

  // 첫 확인·변동 없음은 무음 — 매일 켤 때마다 팡파레가 울리면 금방 질린다.
  if (report.gained > 0) {
    AudioService.instance.sfxRankUp();
  } else if (report.lost > 0) {
    AudioService.instance.sfxRankDown();
  }

  final l = AppLocalizations.of(context);
  await showGameDialog<void>(
    context,
    title: l.rankPopupTitle,
    icon: Icons.emoji_events_rounded,
    content: _RankBody(report: report, l: l),
    actions: [gameDialogButton(l.actionClose, () => Navigator.pop(context))],
  );
}

class _RankBody extends StatelessWidget {
  const _RankBody({required this.report, required this.l});

  final RankReport report;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 큰 순위 숫자 — 이 팝업의 주인공.
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            if (report.isTop)
              const Padding(
                padding: EdgeInsets.only(right: 6),
                child: Text('👑', style: TextStyle(fontSize: 26)),
              ),
            Text(
              '${report.rank}',
              style: const TextStyle(
                color: _honey,
                fontWeight: FontWeight.w900,
                fontSize: 44,
                height: 1.0,
              ),
            ),
            const SizedBox(width: 2),
            Text(
              l.rankSuffix,
              style: const TextStyle(
                color: Color(0xCCFFFFFF),
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _changeRow(),
        if (report.isTop && report.daysAtTop > 0) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0x33EBA52F),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0x66EBA52F)),
            ),
            child: Text(
              l.rankTopStreak(report.daysAtTop),
              style: const TextStyle(
                color: _honey,
                fontWeight: FontWeight.w800,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// 변동 줄: 첫 확인 / 변동 없음 / ▲n(이전→현재) / ▼n(이전→현재).
  Widget _changeRow() {
    if (report.isFirst) {
      return Text(
        l.rankFirstCheck,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Color(0xB3FFFFFF), fontSize: 12.5),
      );
    }
    if (report.isSame) {
      return Text(
        l.rankUnchanged,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Color(0xB3FFFFFF), fontSize: 12.5),
      );
    }
    final gained = report.gained > 0;
    final delta = gained ? report.gained : report.lost;
    final color = gained ? _up : _down;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              gained
                  ? Icons.arrow_upward_rounded
                  : Icons.arrow_downward_rounded,
              color: color,
              size: 18,
            ),
            const SizedBox(width: 2),
            Text(
              '$delta',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          l.rankChangedFromTo(report.previous!, report.rank),
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xB3FFFFFF), fontSize: 12.5),
        ),
      ],
    );
  }
}

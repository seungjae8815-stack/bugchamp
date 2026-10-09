import 'package:core_run/core_run.dart' show RunConfig;
import 'package:core_save/core_save.dart' show SaveGame;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/audio_service.dart';
import '../domain/combat_power.dart';
import '../domain/providers.dart';
import '../domain/pvp_backend.dart';
import '../domain/rank_history.dart';
import '../domain/save_controller.dart';
import '../l10n/app_localizations.dart';
import 'game_dialog.dart';
import 'colors.dart';
import 'popup_gate.dart';

const _honey = kHoney;
const _up = Color(0xFF6FD08C);
const _down = Color(0xFFEF7A6B);

/// 시작 팝업이 보여 주는 랭킹 축 — **진행도**(회차 → 사냥터 → 심연 → 전투력).
///
/// 랭킹 화면에서 트로피 탭을 없앴는데(결투 순위는 리그별로 결투 탭에 있다) 이 팝업만 서버 기본 정렬
/// (트로피) 전체 순위를 보여 주고 있었다(2026-10-09 점검).
const _popupKind = RankingKind.stage;

/// 앱 시작 시 1회: 내 **진행도 순위**가 **직전 확인 때와 달라졌을 때만** 팝업으로 보여준다.
///
/// - 같으면 띄우지 않는다(조용히 기록만) — 매일 같은 숫자를 보여 주는 팝업은 닫기 노동이다.
///   처음 확인할 때도 띄우지 않는다(비교할 값이 없다).
/// - 신규 유저(쉬움 사냥터 1 · 잡은 보스 0)에게는 띄우지 않는다 — 막 시작한 사람에게 "3,481위"는 의미가 없다.
/// - 방치 보상 팝업이 떠 있으면 **닫힌 뒤에** 띄운다([StartupPopupGate]).
///
/// 순위를 확정할 수 없으면(미로그인·오프라인·로컬 백엔드·순위권 밖) 조용히
/// 아무것도 하지 않는다 — 지어낸 등수를 띄우느니 안 띄우는 게 낫다.
Future<void> showRankPopupOnStart(BuildContext context, WidgetRef ref) async {
  final save = ref.read(saveControllerProvider).value;
  if (save == null) return;
  final backend = ref.read(pvpBackendProvider);
  if (!backend.isRemote) return;
  final data = ref.read(gameDataProvider).value;
  final run = data?.runConfig;
  if (run != null &&
      isNewPlayerForRank(
        save,
        run,
        ref.read(saveControllerProvider.notifier).collectedBossCount,
      )) {
    return;
  }

  final power = displayCombatPower(
    save,
    data,
    ref.read(clockProvider).now().toUtc(),
  );
  final rank = await backend.myRank(
    me: PvpProfile.me(save, power: power),
    kind: _popupKind,
  );
  if (rank == null || !context.mounted) return;

  // 방치 보상 팝업이 닫힐 때까지 기다린다 — 겹쳐 뜨면 뒤의 것을 못 보고 닫는다.
  await StartupPopupGate.whenIdle();
  if (!context.mounted) return;

  final report = await RankHistory.instance.record(
    rank,
    today: ref.read(clockProvider).now(), // 로컬 날짜 기준
    axis: _popupKind.key,
  );
  if (!context.mounted) return;
  if (report.isFirst || report.isSame) return;

  // 앞 팝업이 막 닫혔으면 숨을 한 번 돌리고 띄운다(닫힘 애니메이션과 겹치지 않게).
  await Future<void>.delayed(const Duration(milliseconds: 300));
  await StartupPopupGate.whenIdle();
  if (!context.mounted) return;

  if (report.gained > 0) {
    AudioService.instance.sfxRankUp();
  } else if (report.lost > 0) {
    AudioService.instance.sfxRankDown();
  }

  final l = AppLocalizations.of(context);
  // ⚠️ 닫기에서 **바깥 context 로 Navigator 를 찾지 않는다.** 팝업이 떠 있는 사이 앱 화면이
  // 타이틀로 바뀌면(끊김·로그아웃) 바깥 context 가 사라져 `Navigator.pop(context)` 가
  // "Null check operator used on a null value" 로 앱을 죽였다(2026-10-02 크래시 · 1.0.14).
  // 띄우는 순간의 네비게이터를 잡아 두고, 아직 살아 있을 때만 닫는다.
  final nav = Navigator.of(context);
  await showGameDialog<void>(
    context,
    title: l.rankPopupTitle,
    iconWidget: rankImageDlg('trophy'),
    content: _RankBody(report: report, l: l),
    actions: [
      gameDialogButton(l.actionClose, () {
        if (nav.mounted && nav.canPop()) nav.pop();
      }),
    ],
  );
}

/// 순위 팝업을 띄우지 않는 신규 유저 — 쉬움(회차 0)의 사냥터 1에서 아직 보스를 한 마리도 못 잡았다.
/// [bossesCollected] 는 도감 보스 수(옛 클리어 기록 포함, `collectedBosses`).
bool isNewPlayerForRank(SaveGame save, RunConfig run, int bossesCollected) =>
    save.maxTierReached <= 0 &&
    run.zoneOf(
          save.bestStage > save.stageNumber ? save.bestStage : save.stageNumber,
        ) <=
        1 &&
    bossesCollected <= 0;

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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/providers.dart';
import '../domain/save_controller.dart';
import '../l10n/app_localizations.dart';
import 'colors.dart';
import 'game_dialog.dart';
import 'popup_gate.dart';

/// 이 빌드의 "업데이트 내용" 판. 내용([whatsNewItems])을 바꾸면 이 값도 바꾼다 — 기기마다 판마다 한 번 뜬다.
const kWhatsNewVersion = '1.0.19';

/// 기기 플래그 — 마지막으로 보여 준 판(세이브가 아니라 기기 설정: 진행·보상과 무관한 안내라서).
const kWhatsNewSeenKey = 'whatsNew.seen';

/// 이보다 최근에 만든 세이브는 **새로 시작한 유저**로 보고 띄우지 않는다(바뀐 것이 없다 — "부위 강화가
/// 옮겨졌어요"는 처음 하는 사람에게 뜻이 없다). 첫 실행에서 본 것으로만 적는다.
const _kFreshSave = Duration(minutes: 30);

/// 업데이트 내용 한 줄.
typedef WhatsNewItem = ({IconData icon, String text});

/// 1.0.19 업데이트 내용(2026-10-10 — 이번 판에서 바뀐 것 중 유저가 알아야 할 9가지 · 프로필 그림 추가).
/// 훈련 포인트 기준 통일은 불리할 수 있는 변경이라 숨기지 않고 넣는다(공지·출시노트와 같은 원칙).
List<WhatsNewItem> whatsNewItems(AppLocalizations l) => [
  (icon: Icons.face_rounded, text: l.whatsNewAvatar),
  (icon: Icons.bolt_rounded, text: l.whatsNewDuelPower),
  (icon: Icons.auto_fix_high_rounded, text: l.whatsNewPolish),
  (icon: Icons.star_rounded, text: l.whatsNewStar),
  (icon: Icons.local_fire_department_rounded, text: l.whatsNewTranscend),
  (icon: Icons.shield_rounded, text: l.whatsNewHuntDefense),
  (icon: Icons.swap_horiz_rounded, text: l.whatsNewMissionSwap),
  (icon: Icons.fitness_center_rounded, text: l.whatsNewTrainEqual),
  (icon: Icons.extension_rounded, text: l.whatsNewSkillUnlock),
];

/// 지금 세이브가 막 시작한 유저의 것인가.
@visibleForTesting
bool isFreshSave(DateTime createdAt, DateTime now) =>
    now.toUtc().difference(createdAt.toUtc()) < _kFreshSave;

/// 앱 시작 시 1회: 이 판의 업데이트 내용을 **처음 한 번** 보여 준다.
///
/// 순서: 방치 보상 팝업(홈) → **업데이트 내용** → 순위 팝업([StartupPopupGate]).
/// 부르자마자(기다리기 전에, 같은 프레임 안에서) 자리를 잡아 순위 팝업이 먼저 뜨지 않게 하고,
/// 방치 보상 팝업만 닫히길 기다린다(`whenIdle(own: 1)`).
Future<void> showWhatsNewOnStart(BuildContext context, WidgetRef ref) async {
  StartupPopupGate.hold();
  try {
    final SharedPreferences prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (e) {
      debugPrint('업데이트 내용 플래그 읽기 실패(건너뜀): $e');
      return;
    }
    if (prefs.getString(kWhatsNewSeenKey) == kWhatsNewVersion) return;
    if (!context.mounted) return;
    final save = ref.read(saveControllerProvider).value;
    if (save == null) return;
    // 닫는 방식(버튼·바깥 탭·앱 종료)과 무관하게 다시 뜨지 않게 먼저 적는다.
    await prefs.setString(kWhatsNewSeenKey, kWhatsNewVersion);
    if (isFreshSave(save.createdAt, ref.read(clockProvider).now())) return;
    // 방치 보상 팝업이 떠 있으면 닫힌 뒤에 — 겹쳐 뜨면 뒤의 것을 못 보고 닫는다.
    final waited = StartupPopupGate.busyBeyond(1);
    await StartupPopupGate.whenIdle(own: 1);
    if (waited) await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!context.mounted) return;
    final l = AppLocalizations.of(context);
    // 닫기에서 바깥 context 로 Navigator 를 찾지 않는다(rank_popup.dart 와 같은 이유 — 2026-10-02 크래시).
    final nav = Navigator.of(context);
    await showGameDialog<void>(
      context,
      title: l.whatsNewTitle,
      subtitle: l.whatsNewSubtitle(kWhatsNewVersion),
      icon: Icons.campaign_rounded,
      content: WhatsNewBody(items: whatsNewItems(l)),
      actions: [
        gameDialogButton(l.whatsNewOk, () {
          if (nav.mounted && nav.canPop()) nav.pop();
        }),
      ],
    );
  } finally {
    StartupPopupGate.release();
  }
}

/// 업데이트 내용 본문 — 한 줄에 하나, 아이콘 + 큰 흰 글씨(경기장·사냥 화면 위 팝업이라 또렷하게).
class WhatsNewBody extends StatelessWidget {
  const WhatsNewBody({super.key, required this.items});

  final List<WhatsNewItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: 7),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0x26000000),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0x22EBA52F)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0x33EBA52F),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0x88EBA52F)),
                  ),
                  child: Icon(items[i].icon, color: kHoney, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      items[i].text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        height: 1.4,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

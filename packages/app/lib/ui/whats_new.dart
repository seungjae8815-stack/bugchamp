import 'dart:async';

import 'package:flutter/material.dart';
import 'package:core_save/core_save.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/providers.dart';
import '../domain/save_controller.dart';
import '../l10n/app_localizations.dart';
import 'art.dart';
import 'colors.dart';
import 'game_dialog.dart';
import 'popup_gate.dart';

/// 이 빌드의 "업데이트 내용" 판. 내용([whatsNewItems])을 바꾸면 이 값도 바꾼다 — 기기마다 판마다 한 번 뜬다.
const kWhatsNewVersion = '1.0.25';

/// 기기 플래그 — 마지막으로 보여 준 판(세이브가 아니라 기기 설정: 진행·보상과 무관한 안내라서).
const kWhatsNewSeenKey = 'whatsNew.seen';

/// 이보다 최근에 만든 세이브는 **새로 시작한 유저**로 보고 띄우지 않는다(바뀐 것이 없다 — "부위 강화가
/// 옮겨졌어요"는 처음 하는 사람에게 뜻이 없다). 첫 실행에서 본 것으로만 적는다.
const _kFreshSave = Duration(minutes: 30);

/// 업데이트 내용 한 줄 — [image] 는 게임 아이콘 그림 이름(`assets/images/ui/icon/<image>.webp`),
/// 그림이 없으면 [icon] 으로 그린다.
typedef WhatsNewItem = ({IconData icon, String? image, String text});

/// 1.0.25 업데이트 내용(2026-10-22 — 다듬기 소수점 · 짝짓기 특성 이름표 · 배너·버튼 정리).
List<WhatsNewItem> whatsNewItems(AppLocalizations l) => [
  (
    icon: Icons.auto_fix_high_rounded,
    image: 'equip_star',
    text: l.whatsNew25Polish,
  ),
  (icon: Icons.favorite_rounded, image: 'breeding', text: l.whatsNew25Trait),
  (icon: Icons.build_rounded, image: null, text: l.whatsNew25Fix),
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
    // 저장본이 다 읽힐 때까지 기다린다(2026-10-15 에뮬 확인) — 서버에 못 닿으면(오프라인·서버 없음) 동기화가
    // 저장본을 읽지 않고 끝나서, `.value` 로 보면 늘 비어 있어 업데이트 안내가 영영 안 떴다.
    final SaveGame save;
    try {
      save = await ref.read(saveControllerProvider.future);
    } catch (e) {
      debugPrint('업데이트 내용: 세이브 읽기 실패(건너뜀): $e');
      return;
    }
    if (!context.mounted) return;
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
                  child: items[i].image == null
                      ? Icon(items[i].icon, color: kHoney, size: 16)
                      : gameIcon(
                          items[i].image!,
                          size: 20,
                          fallback: items[i].icon,
                        ),
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

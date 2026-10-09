import '../domain/guild_service.dart' show kGuildOpen, guildHasRequestsProvider;
import 'guild/guild_screen.dart';
import 'dart:async';
import 'dart:io' show Platform;
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:core_models/core_models.dart'
    show kMaxOfflineAccrual, MaterialKind;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../domain/audio_service.dart';
import '../domain/iap_service.dart';
import '../domain/notification_service.dart';
import '../domain/notify_prefs.dart';
import '../data/save_repository.dart';
import '../domain/device_session.dart';
import '../domain/server_sync.dart';
import '../domain/update_checker.dart';
import '../domain/providers.dart';
import '../domain/save_controller.dart';
import '../l10n/app_localizations.dart';
import '../ui/art.dart';
import '../ui/labels.dart' show leagueIcon;
import 'battle/league_board_screen.dart' show leagueName;
import '../ui/event_badge.dart';
import '../ui/game_dialog.dart';
import '../ui/rank_popup.dart';
import 'battle/battle_screen.dart';
import 'play/play_screen.dart';
import 'character/character_screen.dart';
import 'shop/craft_screen.dart';
import 'title/title_screen.dart';
import 'storage/storage_screen.dart';
import '../ui/colors.dart';

/// 하단 4탭 셸: 홈 · 채집함 · 전투 · 상점. 세이브 로드 완료 후 표시.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with WidgetsBindingObserver {
  bool _notifSetup = false;

  /// 일일 알림 예약 맞추기의 줄(앞 작업이 끝나야 다음이 돈다 — [_syncDailyNotifications]).
  Future<void> _dailySync = Future.value();

  /// 기기 권위 세이브 주기 업로드(서버 연결 시에만 동작).
  late final _uploader = ServerSaveUploader(ref);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupNotifications();
      // 사운드 초기화 + 배경음 시작(설정 on 일 때).
      unawaited(
        AudioService.instance.init().then(
          (_) => AudioService.instance.startBgm(),
        ),
      );
      // ATT(앱 추적 투명성) 프롬프트 — iOS 요건. 광고 초기화와 무관하게 **앱 시작 시
      // 항상** 띄운다(예전엔 광고 프로바이더 안에 있어 지연 로딩→심사에서 프롬프트
      // 미표시로 반려됨). 앱이 완전히 활성화된 뒤 호출해야 프롬프트가 뜬다.
      unawaited(_requestTrackingIfNeeded());
      // ⚠️ 버전/점검 게이트·서버 동기화·닉네임은 **[TitleScreen] 이 이미 끝냈다.**
      //    여기로 되돌리지 말 것 — 게임 화면 위에 차단 다이얼로그가 얹히고,
      //    동기화 전에 닉네임을 묻는 경합이 다시 생긴다.
      _uploader.start();
      // 지난 실행에서 검증이 멈춘 결제를 되살린다. 상점을 열어야만 결제
      // 서비스가 만들어지던 구조라, 여기서 부르는 것이 **구매 스트림 구독의
      // 유일한 보장**이기도 하다(앱을 끈 사이 끝난 결제를 놓치지 않는다).
      unawaited(ref.read(iapServiceProvider).recoverPending());
      unawaited(showRankPopupOnStart(context, ref));
    });
  }

  /// ATT 권한 요청(iOS). 추적 데이터 수집 전에 반드시 한 번 띄워야 한다.
  /// 첫 프레임 직후 앱이 foreground-active 가 되도록 잠깐 대기한 뒤 호출한다 —
  /// 너무 이르면 iOS 가 프롬프트를 조용히 무시한다.
  Future<void> _requestTrackingIfNeeded() async {
    if (kIsWeb || !Platform.isIOS) return;
    try {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      final status = await AppTrackingTransparency.trackingAuthorizationStatus;
      if (status == TrackingStatus.notDetermined) {
        await AppTrackingTransparency.requestTrackingAuthorization();
      }
    } catch (e) {
      debugPrint('ATT 요청 실패(무시): $e');
    }
  }

  @override
  void dispose() {
    _uploader.stop();
    NotifyPrefs.instance.settings.removeListener(_onNotifyChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    final l = AppLocalizations.of(context);
    final svc = NotificationService.instance;
    if (state == AppLifecycleState.paused) {
      // 백그라운드 진입 → 놓친 진행이 없게 세이브를 즉시 올린다.
      // (배경음 일시정지는 AudioService 가 스스로 처리한다 — 타이틀 화면에서도
      //  멈춰야 하고 hidden/detached 경로도 잡아야 해서 서비스로 옮겼다.)
      unawaited(_uploader.flush());
      final notify = NotifyPrefs.instance.settings.value;
      // 오프라인 상한(8h) 도달 시 알림 예약.
      if (notify.enabled && notify.offlineFull) {
        svc.scheduleOfflineFull(
          after: kMaxOfflineAccrual,
          title: l.notifOfflineTitle,
          body: l.notifOfflineBody,
          quiet: notify.quietHours,
        );
      } else {
        // 부화·선물과 같게 — 꺼져 있으면 남은 예약도 지운다.
        unawaited(svc.cancelOfflineFull());
      }
      // 부화 완료 예정 시각마다 알림 — 앱을 꺼둔 채 기다리는 시간이라
      // 알려주지 않으면 알이 다 익은 채 방치된다.
      final save = ref.read(saveControllerProvider).value;
      if (notify.enabled && notify.hatchDone && save != null) {
        unawaited(
          svc.scheduleHatches(
            save.incubating.values.toList(),
            title: l.notifHatchTitle,
            body: l.notifHatchBody,
            quiet: notify.quietHours,
          ),
        );
      } else {
        unawaited(svc.cancelHatches());
      }
      // 깜짝선물은 10~25분마다 생긴다 — 매번 알리면 성가시므로 백그라운드
      // 진입 후 몇 개 쌓였을 무렵 **한 번만** 알린다.
      if (notify.enabled && notify.gift) {
        unawaited(
          svc.scheduleGift(
            after: const Duration(minutes: 40),
            title: l.notifGiftTitle,
            body: l.notifGiftBody,
            quiet: notify.quietHours,
          ),
        );
      } else {
        unawaited(svc.cancelGift());
      }
    } else if (state == AppLifecycleState.resumed) {
      // 복귀 → 오프라인 알림 취소(이미 접속).
      svc.cancelOfflineFull();
      unawaited(svc.cancelHatches());
      unawaited(svc.cancelGift());
      // 복귀 즉시 서버와 통신을 확인한다. 안 하면 다음 60초 주기까지
      // **백그라운드에서 끊긴 줄 모르고** 놀고, 반대로 백그라운드에서
      // 회복됐는데 "연결 끊김" 배너가 계속 떠 있기도 한다.
      // reconnect 는 변경 감지를 무력화해 반드시 한 번 올려본다 —
      // flush 만 부르면 세이브가 안 변했을 때 서버에 닿지 않아 확인이 안 된다.
      // 이 업로드가 **다른 기기에 밀려났는지**도 바로 드러낸다(한 기기만 접속, 1.0.16) —
      // 백그라운드에 둔 사이 다른 기기가 켜졌으면 409 → "다른 기기에서 접속 중" 덮개.
      // ⚠️ 복귀 때 서버 세이브를 통째로 받아 오지 않는다(2026-10-04 검토): 방치 보상은 서버가 아니라
      // 기기가 `lastSeen` 으로 정산하므로(`_settleOnResume`) 받아 와도 보상은 같고, 업로드 전 진행만 잃는다.
      unawaited(_uploader.reconnect());
      // 백그라운드에서 끝난 결제·보류된 결제를 복귀 즉시 다시 본다.
      unawaited(ref.read(iapServiceProvider).recoverPending());
      // 백그라운드에 오래 두면 그 사이 강제 업데이트·점검이 걸릴 수 있다.
      // 앱을 껐다 켜지 않는 한 게이트를 **다시 보지 않아서**, 차단된 버전으로
      // 계속 노는 상태가 됐다(2026-09-01 지적).
      unawaited(_recheckGateOnResume());
    }
  }

  /// 복귀 시 버전·점검 게이트를 다시 본다. 막혔으면 타이틀로 되돌린다.
  ///
  /// ⚠️ 타이틀이 그 판정을 다시 하므로 여기서는 **되돌리기만** 한다 —
  /// 게임 화면 위에 차단 다이얼로그를 얹지 않는다(초기화 경합의 원인이었다).
  ///
  /// soft(권장)는 되돌리지 않는다. 잠깐 다른 앱을 봤다고 게임이 끊기면
  /// 그게 더 나쁘다.
  Future<void> _recheckGateOnResume() async {
    final verdict = await checkAppVersion();
    if (!mounted) return;
    if (verdict == UpdateVerdict.none || verdict == UpdateVerdict.soft) return;
    // offline 도 되돌린다 — 시작 시 온라인 필수 규칙(2026-08)과 같은 자리다.
    await Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const TitleScreen()),
      (_) => false,
    );
  }

  /// 첫 프레임 후 1회: 알림 권한 요청 + 일일 보상 시각(daily.json)마다 반복 예약.
  /// 그 뒤로는 설정 스위치가 바뀔 때마다 예약을 다시 맞춘다([_onNotifyChanged]).
  Future<void> _setupNotifications() async {
    if (_notifSetup || !mounted) return;
    _notifSetup = true;
    await NotifyPrefs.instance.load();
    await NotificationService.instance.requestPermission();
    if (!mounted) return;
    await _syncDailyNotifications();
    // load() 가 값을 바꾼 뒤에 붙인다 — 붙이고 읽으면 위 예약이 한 번 더 돈다.
    NotifyPrefs.instance.settings.addListener(_onNotifyChanged);
  }

  /// 설정에서 알림 스위치를 바꿨다 → 꺼진 종류는 **이미 걸린 예약까지** 지우고, 켜진 일일 알림은 다시 건다.
  ///
  /// ⚠️ 점심·저녁 알림은 매일 반복 예약이라 기기에 남는다. 예전엔 꺼도 "다음 실행에 예약 안 함"뿐이라
  /// 이미 걸린 반복 예약이 계속 울렸다(2026-10-09 점검). 방치 가득·부화·선물은 백그라운드로 갈 때 걸고
  /// 돌아오면 지우는 1회 예약이라 앱이 떠 있는 지금은 남아 있지 않지만, 같은 원칙으로 함께 지운다.
  void _onNotifyChanged() {
    if (!mounted) return;
    final np = NotifyPrefs.instance.settings.value;
    final svc = NotificationService.instance;
    if (!np.enabled || !np.offlineFull) unawaited(svc.cancelOfflineFull());
    if (!np.enabled || !np.hatchDone) unawaited(svc.cancelHatches());
    if (!np.enabled || !np.gift) unawaited(svc.cancelGift());
    unawaited(_syncDailyNotifications());
  }

  /// 일일 알림 예약을 차례대로 맞춘다 — 스위치를 빠르게 껐다 켜도 마지막 설정이 이기게(앞 작업이 끝난 뒤 실행).
  Future<void> _syncDailyNotifications() => _dailySync = _dailySync
      .then((_) => _syncDailyOnce())
      .catchError((Object e) {
        debugPrint('일일 알림 예약 맞추기 실패(무시): $e');
      });

  Future<void> _syncDailyOnce() async {
    final svc = NotificationService.instance;
    final np = NotifyPrefs.instance.settings.value;
    if (!np.enabled || !np.daily) {
      await svc.cancelDaily();
      return;
    }
    // gameData 는 비동기 로드(FutureProvider) — 첫 프레임엔 .value 가 아직 null 이라
    // 예약이 통째로 건너뛰어졌다(점심/저녁 알림 미발화의 근본 원인).
    // .future 를 await 해 로드 완료를 보장한 뒤 예약한다.
    final data = await ref.read(gameDataProvider.future);
    if (!mounted) return;
    // 기다리는 사이 꺼졌으면 걸지 않는다(다음 차례가 지운다).
    final now = NotifyPrefs.instance.settings.value;
    if (!now.enabled || !now.daily) return;
    final l = AppLocalizations.of(context);
    final rewards = data.dailyConfig?.rewards ?? const [];
    for (var i = 0; i < rewards.length; i++) {
      final rw = rewards[i];
      await svc.scheduleDaily(
        id: i + 1,
        hour: rw.hour,
        title: switch (rw.id) {
          'lunch' => l.notifLunchTitle,
          'dinner' => l.notifDinnerTitle,
          _ => l.notifRewardBody,
        },
        body: l.notifRewardBody,
      );
    }
    // 보상 시각이 줄었으면 남는 옛 반복 예약을 지운다.
    await svc.cancelDaily(keep: rewards.length);
  }

  @override
  Widget build(BuildContext context) {
    final index = ref.watch(tabIndexProvider);
    final saveAsync = ref.watch(saveControllerProvider);

    // 대회 회차 보상(서버가 지급) → 1회 다이얼로그.
    //
    // ⚠️ **대회 화면이 아니라 여기서 띄운다.** 보상은 회차가 끝난 뒤에 지급되는데
    // 그때는 대회가 닫혀 화면·배너가 감춰져 있어, 거기 두면 아무도 못 본다.
    final ctrl = ref.read(saveControllerProvider.notifier);
    final reward = ctrl.pendingEventReward;
    if (reward != null) {
      ctrl.consumeEventReward();
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _showEventReward(reward),
      );
    }
    // 결투 시즌 순위 보상 — 같은 이유로 결투 화면이 아니라 여기서 띄운다
    // (시즌이 끝난 뒤 첫 업로드에서 오므로 어느 탭에 있을지 모른다).
    final pvpRank = ctrl.pendingPvpRankReward;
    if (pvpRank != null) {
      ctrl.consumePvpRankReward();
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _showPvpRankReward(pvpRank),
      );
    }
    final leagueResult = ctrl.pendingLeagueResult;
    if (leagueResult != null) {
      ctrl.consumeLeagueResult();
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _showLeagueResult(leagueResult),
      );
    }
    final abyssRank = ctrl.pendingAbyssRankReward;
    if (abyssRank != null) {
      ctrl.consumeAbyssRankReward();
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _showPvpRankReward(abyssRank, abyss: true),
      );
    }

    return saveAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
      data: (save) => PopScope(
        // 뒤로가기: 홈이 아니면 홈으로, 홈이면 종료 확인.
        canPop: false,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) return;
          if (index != 0) {
            ref.read(tabIndexProvider.notifier).set(0);
            return;
          }
          final exit = await _confirmExit(context);
          if (exit) await SystemNavigator.pop();
        },
        child: Scaffold(
          body: Stack(
            children: [
              IndexedStack(
                index: index,
                children: [
                  const PlayScreen(),
                  // 홈과 채집함 사이 — **전력을 조립하는 곳**.
                  const CharacterScreen(),
                  StorageScreen(save: save),
                  const BattleScreen(),
                  // 길드(1.0.15) — 하단 메뉴(2026-10-02 사장님). 열기 전엔 "준비 중" 화면.
                  kGuildOpen ? const GuildScreen() : const GuildComingSoon(),
                  const CraftScreen(),
                ],
              ),
              // 연결이 끊기면 **게임 위를 통째로 덮는다.** 오프라인 플레이를
              // 허용하지 않으므로(타이틀에서도 입장을 막는다) 들어온 뒤에도
              // 같은 기준을 적용한다.
              ValueListenableBuilder<bool>(
                valueListenable: serverDisconnected,
                builder: (context, lost, _) => lost
                    ? _DisconnectedOverlay(uploader: _uploader)
                    : const SizedBox.shrink(),
              ),
              // 다른 기기에 밀려났다(한 기기만 접속, 1.0.16). 끊김과 같은 자리에서 게임을 덮는다 —
              // 계속 놀게 두면 저장되지 않는 진행이 쌓인다(서버가 업로드를 거절한다).
              ValueListenableBuilder<bool>(
                valueListenable: DeviceSession.taken,
                builder: (context, taken, _) => taken
                    ? _SessionTakenOverlay(uploader: _uploader)
                    : const SizedBox.shrink(),
              ),
              // 세이브를 못 읽었으면 **끊김보다도 위**를 덮는다. 이 상태로 놀면
              // 초기 세이브 위에 진행이 쌓이고, 그게 서버로 올라가 계정을
              // 덮어쓴다(2026-08-26). 재시도 버튼을 두지 않는 이유 = 다시
              // 읽어도 같은 결과이고, 유저가 할 일은 앱 업데이트나 문의다.
              ValueListenableBuilder<SaveLoadFailure?>(
                valueListenable: saveUnreadable,
                builder: (context, why, _) => why == null
                    ? const SizedBox.shrink()
                    : _SaveBrokenOverlay(why: why),
              ),
            ],
          ),
          bottomNavigationBar: _GameNavBar(
            index: index,
            // 관리자인데 가입 신청이 쌓여 있으면 길드 아이콘에 빨간 점.
            guildDot: ref.watch(guildHasRequestsProvider),
            onTap: (i) {
              AudioService.instance.sfxTap();
              ref.read(tabIndexProvider.notifier).set(i);
            },
          ),
        ),
      ),
    );
  }

  /// 회차 종료 보상 수령 안내.
  Future<void> _showEventReward(EventRewardReport r) async {
    if (!mounted) return;
    final l = AppLocalizations.of(context);
    // 서버가 준 주소를 **먼저** 쓴다. 앱 번들 값은 서버가 구버전일 때의 폴백이다 —
    // 폼 주소를 스토어 배포 없이 바꿀 수 있어야 한다.
    final formUrl = r.prizeFormUrl.isNotEmpty
        ? r.prizeFormUrl
        : (ref.read(gameDataProvider).value?.eventConfig?.prizeFormUrl ?? '');
    // 실물 안내는 **폼이 있을 때만** 띄운다. 링크 없는 버튼은
    // "당첨됐는데 신청을 못 한다"가 된다.
    final showForm = r.physical && formUrl.isNotEmpty;

    await showGameDialog<void>(
      context,
      title: l.eventRewardTitle,
      iconWidget: rankImageDlg('trophy'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            r.rank == null
                ? l.eventRewardNone
                : l.eventRewardRank(
                    r.roundNo > 0 ? '${r.roundNo}' : r.roundId,
                    r.rank!,
                  ),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          gameRewardList(
            context,
            materials: {
              for (final k in MaterialKind.values)
                if (((k == MaterialKind.jelly ? r.jelly : 0) +
                        (r.materials[k.key] ?? 0)) >
                    0)
                  k:
                      (k == MaterialKind.jelly ? r.jelly : 0) +
                      (r.materials[k.key] ?? 0),
            },
          ),
          if (r.badge.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  l.eventRewardBadgeLabel,
                  style: const TextStyle(
                    color: Color(0xBBFFFFFF),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                EventBadgeChip(id: r.badge, size: 12),
              ],
            ),
          ],
          if (r.physical) ...[
            const SizedBox(height: 12),
            Text(
              l.eventRewardPhysical,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFFFCC80),
                fontSize: 12.5,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
      actions: [
        if (showForm)
          gameDialogButton(
            l.eventRewardApply,
            () => launchUrl(
              Uri.parse(formUrl),
              mode: LaunchMode.externalApplication,
            ),
            primary: false,
          ),
        gameDialogButton(l.eventRewardClaim, () => Navigator.pop(context)),
      ],
    );
  }

  /// 결투 시즌 순위 보상 수령 안내.
  Future<void> _showPvpRankReward(
    PvpRankRewardReport r, {
    bool abyss = false,
  }) async {
    if (!mounted) return;
    final l = AppLocalizations.of(context);
    await showGameDialog<void>(
      context,
      title: abyss ? l.abyssRankRewardTitle : l.pvpRankRewardTitle,
      iconWidget: rankImageDlg('trophy'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            abyss
                ? l.abyssRankRewardBody(r.floor, r.rank)
                : l.pvpRankRewardBody(r.rank),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          gameRewardList(context, materials: {MaterialKind.jelly: r.jelly}),
        ],
      ),
      actions: [
        gameDialogButton(l.eventRewardClaim, () => Navigator.pop(context)),
      ],
    );
  }

  /// 결투 리그 주간 결산 — 승급·유지·강등과 지난주 순위·젤리.
  Future<void> _showLeagueResult(LeagueResultReport r) async {
    if (!mounted) return;
    final l = AppLocalizations.of(context);
    final cfg = ref.read(gameDataProvider).value?.battleConfig;
    final up =
        cfg != null && cfg.leagueIndexOf(r.to) > cfg.leagueIndexOf(r.from);
    final down =
        cfg != null && cfg.leagueIndexOf(r.to) < cfg.leagueIndexOf(r.from);
    final name = leagueName(l, r.to);
    final head = up
        ? l.leagueResultUp(name)
        : (down ? l.leagueResultDown(name) : l.leagueResultStay(name));
    if (up) AudioService.instance.sfxLevelUp();
    await showGameDialog<void>(
      context,
      title: l.leagueResultTitle,
      iconWidget: leagueIcon(r.to, size: 40),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            head,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: up
                  ? const Color(0xFF9CE37D)
                  : (down ? const Color(0xFFEF9A9A) : Colors.white),
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          if (r.rank != null && r.total > 0)
            Text(
              l.leagueResultRank(r.rank!, r.total),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xCCFFFFFF)),
            ),
          if (r.inactive)
            Text(
              l.leagueResultInactive,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xAAFFFFFF), fontSize: 12),
            ),
          if (r.jelly > 0) ...[
            const SizedBox(height: 10),
            gameRewardList(context, materials: {MaterialKind.jelly: r.jelly}),
          ],
        ],
      ),
      actions: [
        gameDialogButton(l.eventRewardClaim, () => Navigator.pop(context)),
      ],
    );
  }

  Future<bool> _confirmExit(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final res = await showGameDialog<bool>(
      context,
      title: l.exitTitle,
      icon: Icons.exit_to_app_rounded,
      content: Text(
        l.exitConfirm,
        style: const TextStyle(
          color: Color(0xD9FFFFFF),
          fontSize: 13.5,
          height: 1.4,
        ),
      ),
      actions: [
        gameDialogButton(
          l.actionCancel,
          () => Navigator.pop(context, false),
          primary: false,
        ),
        gameDialogButton(
          l.exitAction,
          () => Navigator.pop(context, true),
          color: const Color(0xFFC85454),
        ),
      ],
    );
    return res ?? false;
  }
}

class _GameNavBar extends StatelessWidget {
  const _GameNavBar({
    required this.index,
    required this.onTap,
    this.guildDot = false,
  });

  final int index;
  final ValueChanged<int> onTap;
  final bool guildDot;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    // (아트 이름, 아이콘 폴백, 라벨). 아트는 assets/images/ui/nav/{이름}.webp —
    // 애셋이 없으면 예전 Material 아이콘으로 떨어진다(§6).
    final items = <(String, IconData, String)>[
      ('home', Icons.home_rounded, l.navHome),
      ('character', Icons.person_rounded, l.navCharacter),
      ('storage', Icons.menu_book_rounded, l.navStorage),
      ('battle', Icons.sports_mma_rounded, l.navBattle),
      ('guild', Icons.groups_rounded, l.guildTitle),
      ('shop', Icons.storefront_rounded, l.navShop),
    ];
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1B2A12), Color(0xFF0E1608)],
        ),
        border: Border(top: BorderSide(color: Color(0x22FFFFFF))),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: _NavTab(
                    art: items[i].$1,
                    icon: items[i].$2,
                    label: items[i].$3,
                    active: i == index,
                    dot: guildDot && i == kGuildTabIndex,
                    onTap: () => onTap(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  const _NavTab({
    required this.art,
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.dot = false,
  });

  final String art;
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  /// 아이콘 오른쪽 위 빨간 점(처리할 일이 있다).
  final bool dot;

  @override
  Widget build(BuildContext context) {
    const on = kHoney;
    const off = Color(0xB3FFFFFF);
    final color = active ? on : off;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 고른 탭만 아트를 제 색으로, 나머지는 살짝 흐리게 —
          // 아이콘 색으로 주던 선택 신호를 아트에도 유지한다.
          Stack(
            clipBehavior: Clip.none,
            children: [
              Opacity(
                opacity: active ? 1 : 0.62,
                child: navImage(
                  art,
                  size: 28,
                  fallback: Icon(icon, color: color, size: 24),
                ),
              ),
              if (dot)
                const Positioned(
                  right: -3,
                  top: -2,
                  child: CircleAvatar(
                    radius: 4.5,
                    backgroundColor: Color(0xFFFF5252),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 1),
          // 6칸이라 칸이 좁다 — "コレクション"·"Character"가 단어 중간에서 꺾였다(한 줄 · 칸에 맞게 줄임).
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 연결이 끊겼을 때 게임 위를 덮는 화면. 닫을 수 없다 — 재접속하거나
/// 타이틀로 돌아가야 한다.
class _DisconnectedOverlay extends StatefulWidget {
  const _DisconnectedOverlay({required this.uploader});

  final ServerSaveUploader uploader;

  @override
  State<_DisconnectedOverlay> createState() => _DisconnectedOverlayState();
}

class _DisconnectedOverlayState extends State<_DisconnectedOverlay> {
  bool _trying = false;
  bool _failedOnce = false;

  Future<void> _retry() async {
    setState(() => _trying = true);
    final ok = await widget.uploader.reconnect();
    if (!mounted) return;
    setState(() {
      _trying = false;
      _failedOnce = !ok;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Positioned.fill(
      child: ColoredBox(
        color: const Color(0xF20A1206),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.wifi_off_rounded,
                  size: 54,
                  color: Color(0xFFFF8A65),
                ),
                const SizedBox(height: 14),
                Text(
                  l.netLostTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l.netLostBody,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xCCFFFFFF),
                    fontSize: 13.5,
                    height: 1.4,
                  ),
                ),
                if (_failedOnce) ...[
                  const SizedBox(height: 10),
                  Text(
                    l.netStillDown,
                    style: const TextStyle(
                      color: Color(0xFFEF9A9A),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    gameDialogButton(
                      l.netToTitle,
                      () => Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute<void>(
                          builder: (_) => const TitleScreen(),
                        ),
                        (r) => false,
                      ),
                      primary: false,
                    ),
                    const SizedBox(width: 10),
                    gameDialogButton(
                      _trying ? '...' : l.netRetry,
                      _trying ? () {} : _retry,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 다른 기기에 밀려났을 때 게임을 덮는 화면(한 기기만 접속, 2026-10-03 · 1.0.16).
///
/// 나가는 버튼은 두지 않는다 — 다른 기기에서 계속할 사람은 이 앱을 닫으면 된다.
/// "이 기기에서 계속하기"는 다시 쥐고 서버 저장본(= 다른 기기의 진행)을 받는다.
class _SessionTakenOverlay extends StatefulWidget {
  const _SessionTakenOverlay({required this.uploader});

  final ServerSaveUploader uploader;

  @override
  State<_SessionTakenOverlay> createState() => _SessionTakenOverlayState();
}

class _SessionTakenOverlayState extends State<_SessionTakenOverlay> {
  bool _trying = false;
  bool _failedOnce = false;

  Future<void> _continueHere() async {
    setState(() => _trying = true);
    final ok = await widget.uploader.takeOver();
    if (!mounted) return;
    setState(() {
      _trying = false;
      _failedOnce = !ok;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Positioned.fill(
      child: ColoredBox(
        color: const Color(0xF20A1206),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.devices_rounded,
                  size: 54,
                  color: Color(0xFFFFCC80),
                ),
                const SizedBox(height: 14),
                Text(
                  l.sessionTakenTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l.sessionTakenBody,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xCCFFFFFF),
                    fontSize: 13.5,
                    height: 1.4,
                  ),
                ),
                if (_failedOnce) ...[
                  const SizedBox(height: 10),
                  Text(
                    l.sessionTakenFailed,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFEF9A9A),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                gameDialogButton(
                  _trying ? '...' : l.sessionTakenContinue,
                  _trying ? () {} : _continueHere,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 세이브를 읽지 못했을 때 게임을 통째로 덮는 화면.
///
/// **나가는 문을 주지 않는다** — 닫을 수 있으면 유저는 닫고 계속 논다.
/// 그동안 쌓인 진행은 저장되지 않고, 저장되지 않는다는 사실도 모른다.
class _SaveBrokenOverlay extends StatelessWidget {
  const _SaveBrokenOverlay({required this.why});

  final SaveLoadFailure why;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final needsUpdate = why == SaveLoadFailure.needsUpdate;
    return Positioned.fill(
      child: ColoredBox(
        color: const Color(0xF60A1206),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  needsUpdate
                      ? Icons.system_update_alt_rounded
                      : Icons.report_gmailerrorred_rounded,
                  size: 54,
                  color: const Color(0xFFFFB74D),
                ),
                const SizedBox(height: 14),
                Text(
                  l.saveBrokenTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  needsUpdate ? l.saveBrokenUpdate : l.saveBrokenCorrupt,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xCCFFFFFF),
                    fontSize: 13.5,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  l.saveBrokenKeep,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFEF9A9A),
                    fontSize: 12.5,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

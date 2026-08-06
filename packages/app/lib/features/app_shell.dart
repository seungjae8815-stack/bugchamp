import 'dart:async';
import 'dart:io' show Platform;
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:core_models/core_models.dart' show kMaxOfflineAccrual;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/audio_service.dart';
import '../domain/notification_service.dart';
import '../domain/server_sync.dart';
import '../domain/providers.dart';
import '../domain/save_controller.dart';
import '../l10n/app_localizations.dart';
import '../ui/game_dialog.dart';
import '../ui/rank_popup.dart';
import 'battle/battle_screen.dart';
import 'play/play_screen.dart';
import 'shop/craft_screen.dart';
import 'storage/storage_screen.dart';

/// 하단 4탭 셸: 홈 · 채집함 · 전투 · 상점. 세이브 로드 완료 후 표시.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with WidgetsBindingObserver {
  bool _notifSetup = false;

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
      // 오프라인 상한(8h) 도달 시 알림 예약.
      svc.scheduleOfflineFull(
        after: kMaxOfflineAccrual,
        title: l.notifOfflineTitle,
        body: l.notifOfflineBody,
      );
    } else if (state == AppLifecycleState.resumed) {
      // 복귀 → 오프라인 알림 취소(이미 접속).
      svc.cancelOfflineFull();
    }
  }

  /// 첫 프레임 후 1회: 알림 권한 요청 + 일일 보상 시각(daily.json)마다 반복 예약.
  Future<void> _setupNotifications() async {
    if (_notifSetup || !mounted) return;
    _notifSetup = true;
    final l = AppLocalizations.of(context);
    final svc = NotificationService.instance;
    await svc.requestPermission();
    // gameData 는 비동기 로드(FutureProvider) — 첫 프레임엔 .value 가 아직 null 이라
    // 예약이 통째로 건너뛰어졌다(점심/저녁 알림 미발화의 근본 원인).
    // .future 를 await 해 로드 완료를 보장한 뒤 예약한다.
    final data = await ref.read(gameDataProvider.future);
    if (!mounted) return;
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
  }

  @override
  Widget build(BuildContext context) {
    final index = ref.watch(tabIndexProvider);
    final saveAsync = ref.watch(saveControllerProvider);

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
          body: IndexedStack(
            index: index,
            children: [
              const PlayScreen(),
              StorageScreen(save: save),
              const BattleScreen(),
              const CraftScreen(),
            ],
          ),
          bottomNavigationBar: _GameNavBar(
            index: index,
            onTap: (i) {
              AudioService.instance.sfxTap();
              ref.read(tabIndexProvider.notifier).set(i);
            },
          ),
        ),
      ),
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
  const _GameNavBar({required this.index, required this.onTap});

  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final items = <(IconData, String)>[
      (Icons.home_rounded, l.navHome),
      (Icons.menu_book_rounded, l.navStorage),
      (Icons.sports_mma_rounded, l.navBattle),
      (Icons.storefront_rounded, l.navShop),
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
                    icon: items[i].$1,
                    label: items[i].$2,
                    active: i == index,
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
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const on = Color(0xFFEBA52F);
    const off = Color(0xB3FFFFFF);
    final color = active ? on : off;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: active ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

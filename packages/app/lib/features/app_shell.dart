import 'dart:async';
import 'package:core_models/core_models.dart' show kMaxOfflineAccrual;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/notification_service.dart';
import '../domain/server_sync.dart';
import '../domain/providers.dart';
import '../domain/save_controller.dart';
import '../l10n/app_localizations.dart';
import '../ui/game_dialog.dart';
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

  /// 방치 수입 주기 정산(서버 권위 모드에서만 동작).
  late final _syncTimer = ServerSyncTimer(ref);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupNotifications();
      // 서버 권위 모드면 세이브를 맞추고(최초 1회 이관 포함) 주기 정산을 건다.
      unawaited(syncWithServer(ref).then((_) => _syncTimer.start()));
    });
  }

  @override
  void dispose() {
    _syncTimer.stop();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    final l = AppLocalizations.of(context);
    final svc = NotificationService.instance;
    if (state == AppLifecycleState.paused) {
      // 백그라운드 진입 → 오프라인 상한(8h) 도달 시 알림 예약.
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
    final rewards =
        ref.read(gameDataProvider).value?.dailyConfig?.rewards ?? const [];
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
            onTap: (i) => ref.read(tabIndexProvider.notifier).set(i),
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

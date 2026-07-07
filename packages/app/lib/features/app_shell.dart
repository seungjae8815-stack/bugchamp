import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/providers.dart';
import '../domain/save_controller.dart';
import '../l10n/app_localizations.dart';
import 'play/play_screen.dart';
import 'storage/storage_screen.dart';

/// 하단 3탭 셸: 홈(플레이+강화) · 도감 · 상점. 세이브 로드 완료 후 표시.
class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(tabIndexProvider);
    final saveAsync = ref.watch(saveControllerProvider);

    return saveAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
      data: (save) => Scaffold(
        body: IndexedStack(
          index: index,
          children: [
            const PlayScreen(),
            StorageScreen(save: save),
            const _ComingSoonScreen(),
          ],
        ),
        bottomNavigationBar: _GameNavBar(
          index: index,
          onTap: (i) => ref.read(tabIndexProvider.notifier).set(i),
        ),
      ),
    );
  }
}

class _ComingSoonScreen extends StatelessWidget {
  const _ComingSoonScreen();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.navShop)),
      body: Center(child: Text(l.comingSoon)),
    );
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

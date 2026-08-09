import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/providers.dart';
import '../../l10n/app_localizations.dart';
import 'equip_widgets.dart';

/// 개발자용 — **장비 80종을 한 화면에서** 본다.
///
/// 제련은 부위가 랜덤이라 특정 그림을 보려면 수십 번 돌려야 한다. 아트를
/// 넣고 확인하는 데 그건 못 쓴다. 여기서는 8×10 격자를 통째로 보므로
/// **어느 칸이 아직 아이콘 폴백인지**(= 파일이 없거나 이름이 틀렸는지)가
/// 한눈에 보인다.
class ItemGalleryScreen extends ConsumerWidget {
  const ItemGalleryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final items = ref.watch(gameDataProvider).value?.itemConfig;
    if (items == null) return const Scaffold();

    return Scaffold(
      appBar: AppBar(title: const Text('🛠 장비 그림 확인')),
      body: ListView(
        padding: const EdgeInsets.all(10),
        children: [
          for (final slot in EquipSlot.values) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 8, 2, 6),
              child: Text(
                slotLabel(l, slot),
                style: const TextStyle(
                  color: Color(0xFFFFD54F),
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ),
            GridView.count(
              crossAxisCount: 5,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 0.82,
              children: [
                for (var t = 0; t < items.tierCount; t++)
                  _cell(items, slot, t, locale),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _cell(ItemConfig cfg, EquipSlot slot, int tier, String locale) {
    final item = EquipItem(slot: slot, tier: tier, options: const []);
    final color = tierColor(cfg, tier);
    return Container(
      decoration: BoxDecoration(
        color: const Color(0x55121A10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color, width: 1.4),
      ),
      padding: const EdgeInsets.all(4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          itemImage(item, size: 40, tint: color),
          const SizedBox(height: 3),
          Text(
            cfg.tier(tier).name.resolve(locale),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

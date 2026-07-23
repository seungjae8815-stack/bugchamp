import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/iap_service.dart';
import '../../domain/providers.dart';
import '../../domain/store_iap_service.dart';
import '../../domain/save_controller.dart';
import 'package:core_save/core_save.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/art.dart';
import '../../ui/format.dart';
import '../../ui/labels.dart';

/// 상점 탭: [제작 | 상점] 2섹션.
/// 제작 = 재료로 버프 물약(§C), 상점 = 인앱결제 카탈로그(iap.json).
class CraftScreen extends ConsumerWidget {
  const CraftScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final data = ref.watch(gameDataProvider).requireValue;
    final save = ref.watch(saveControllerProvider).requireValue;
    final cfg = data.craftConfig;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.craftTitle),
          bottom: TabBar(
            indicatorColor: const Color(0xFFEBA52F),
            labelColor: const Color(0xFFEBA52F),
            unselectedLabelColor: const Color(0x99FFFFFF),
            tabs: [
              Tab(text: l.tabCraft),
              Tab(text: l.tabStore),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            cfg == null
                ? Center(child: Text(l.comingSoon))
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: cfg.recipes.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) =>
                        _RecipeCard(recipe: cfg.recipes[i], save: save),
                  ),
            _StoreSection(save: save),
          ],
        ),
      ),
    );
  }
}

/// 인앱결제 상품 목록. 구매는 [iapServiceProvider] 를 통해 처리한다.
class _StoreSection extends ConsumerWidget {
  const _StoreSection({required this.save});

  final SaveGame save;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final data = ref.watch(gameDataProvider).requireValue;
    final cfg = data.iapConfig;
    if (cfg == null || cfg.products.isEmpty) {
      return Center(child: Text(l.comingSoon));
    }
    final now = ref.read(clockProvider).now().toUtc();
    final locale = Localizations.localeOf(context).languageCode;
    final products = cfg.sorted;
    // 스토어가 붙어 있으면 현지 통화 가격으로 덮어쓴다(없으면 원화 참고값).
    final prices = ref.watch(storePricesProvider).value ?? const {};
    final devMode = !ref.watch(iapServiceProvider).isStore;

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: products.length + (devMode ? 2 : 1),
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        if (devMode && i == 0) return _devBanner(l);
        final idx = devMode ? i - 1 : i;
        if (idx == products.length) return _restoreRow(context, ref, l);
        return _ProductCard(
          product: products[idx],
          save: save,
          now: now,
          locale: locale,
          storePrice: prices[products[idx].id],
        );
      },
    );
  }

  /// 개발용 로컬 결제일 때만 보이는 경고 — 실제 결제가 아님을 숨기지 않는다.
  Widget _devBanner(AppLocalizations l) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0x22EBA52F),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0x55EBA52F)),
    ),
    child: Row(
      children: [
        const Icon(Icons.science_rounded, color: Color(0xFFEBA52F), size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            l.storeDevMode,
            style: const TextStyle(
              color: Color(0xFFEBD24A),
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );

  /// 비소모성 구매 복원(스토어 심사 필수 항목).
  Widget _restoreRow(BuildContext ctx, WidgetRef ref, AppLocalizations l) =>
      Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Center(
          child: TextButton.icon(
            onPressed: () async {
              await ref.read(iapServiceProvider).restore();
              if (!ctx.mounted) return;
              ScaffoldMessenger.of(ctx)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(content: Text(l.storeRestoreDone)));
            },
            icon: const Icon(Icons.restore_rounded, size: 18),
            label: Text(l.storeRestore),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0x99FFFFFF),
            ),
          ),
        ),
      );
}

/// 상품 1개 카드 — 이름·설명·지급 내용·가격·구매 버튼.
class _ProductCard extends ConsumerWidget {
  const _ProductCard({
    required this.product,
    required this.save,
    required this.now,
    required this.locale,
    this.storePrice,
  });

  final IapProduct product;
  final SaveGame save;
  final DateTime now;
  final String locale;

  /// 스토어가 알려준 현지 가격 표시(예: "₩5,500", "$4.99"). null 이면 원화 참고값.
  final String? storePrice;

  /// 이미 보유해서 다시 살 수 없는 상품인지.
  bool get _owned => switch (product.type) {
    IapType.removeAds => save.adsRemoved,
    IapType.starter => save.starterBought,
    IapType.skin => save.ownedSkins.contains(product.skinId),
    _ => false, // 젤리·패스는 반복 구매 가능
  };

  (IconData, Color) get _style => switch (product.type) {
    IapType.removeAds => (Icons.block_rounded, const Color(0xFF5FD3C8)),
    IapType.starter => (Icons.card_giftcard_rounded, const Color(0xFFEBA52F)),
    IapType.pass => (Icons.workspace_premium_rounded, const Color(0xFFB98BFF)),
    IapType.jelly => (Icons.bubble_chart_rounded, const Color(0xFF7FD3F5)),
    IapType.skin => (Icons.palette_rounded, const Color(0xFFF48FB1)),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final (icon, color) = _style;
    final name = product.name?.resolve(locale) ?? product.id;
    final desc = product.desc?.resolve(locale);
    final owned = _owned;
    // 패스는 남은 기간을 보여준다.
    final passLeft = product.type == IapType.pass && save.passActive(now)
        ? save.passExpiresAt!.difference(now).inDays
        : null;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0x22000000),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (product.bonusPct > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0x333FA84E),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '+${product.bonusPct}%',
                          style: const TextStyle(
                            color: Color(0xFF7CE38B),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (desc != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    desc,
                    style: const TextStyle(
                      color: Color(0x99FFFFFF),
                      fontSize: 11,
                      height: 1.3,
                    ),
                  ),
                ],
                if (product.grant.jelly > 0 || product.grant.gold > 0) ...[
                  const SizedBox(height: 3),
                  Text(
                    [
                      if (product.grant.jelly > 0) '💎${product.grant.jelly}',
                      if (product.grant.gold > 0)
                        '💰${formatCompact(product.grant.gold)}',
                    ].join('  '),
                    style: const TextStyle(
                      color: Color(0xFFEBD24A),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
                if (passLeft != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    l.storePassLeft(passLeft),
                    style: const TextStyle(
                      color: Color(0xFFB98BFF),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 92,
            height: 38,
            child: FilledButton(
              onPressed: owned ? null : () => _buy(context, ref, l, name),
              style: FilledButton.styleFrom(
                backgroundColor: color,
                foregroundColor: const Color(0xFF1A1200),
                disabledBackgroundColor: const Color(0x33FFFFFF),
                padding: EdgeInsets.zero,
              ),
              child: Text(
                owned
                    ? l.storeOwned
                    : (storePrice ?? '₩${formatThousands(product.priceKrw)}'),
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _buy(
    BuildContext ctx,
    WidgetRef ref,
    AppLocalizations l,
    String name,
  ) async {
    final outcome = await ref.read(iapServiceProvider).buy(product);
    if (!ctx.mounted) return;
    // 결과마다 다른 안내를 준다 — 취소를 "실패"라고 하면 사용자가 불안해한다.
    final msg = switch (outcome) {
      PurchaseOutcome.success => l.storeBought(name),
      PurchaseOutcome.canceled => l.storeCanceled,
      PurchaseOutcome.pending => l.storePending,
      PurchaseOutcome.unavailable => l.storeUnavailable,
      PurchaseOutcome.notInStore => l.storeNotRegistered,
      PurchaseOutcome.failed => l.storeFailed,
    };
    // 임시 진단 — 미지급 원인 파악용(원인 확정 후 iapLastDiag 표시 제거).
    final diag = iapLastDiag.isEmpty ? '' : '\n[$iapLastDiag]';
    ScaffoldMessenger.of(ctx)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('$msg$diag'),
        duration: const Duration(seconds: 8),
      ));
  }
}

class _RecipeCard extends ConsumerWidget {
  const _RecipeCard({required this.recipe, required this.save});

  final CraftRecipe recipe;
  final SaveGame save;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final buff = recipe.buff;
    final name = recipe.allBuffs
        ? l.craftAllPotion
        : l.craftPotion(buffLabel(l, buff!));
    final color = recipe.allBuffs ? const Color(0xFF4FC3F7) : buffColor(buff!);
    final glyph = recipe.allBuffs ? '💎' : buffGlyph(buff!);

    var affordable = true;
    for (final e in recipe.inputs.entries) {
      if (save.materialCount(e.key) < e.value) affordable = false;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(glyph, style: const TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 10,
                    runSpacing: 2,
                    children: [
                      for (final e in recipe.inputs.entries)
                        _cost(e.key, e.value, save.materialCount(e.key)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: affordable
                  ? () async {
                      final ok = await ref
                          .read(saveControllerProvider.notifier)
                          .craft(recipe);
                      if (ok && context.mounted) {
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                            SnackBar(content: Text(l.craftedSnack(name))),
                          );
                      }
                    }
                  : null,
              child: Text(l.craftMake),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cost(MaterialKind kind, int need, int have) {
    final ok = have >= need;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        materialImage(
          kind,
          size: 15,
          fallback: Icon(
            materialIcon(kind),
            size: 14,
            color: ok ? const Color(0xFF9CCC65) : const Color(0xFFEF9A9A),
          ),
        ),
        const SizedBox(width: 3),
        Text(
          formatCompact(need),
          style: TextStyle(
            color: ok ? const Color(0xFF9CCC65) : const Color(0xFFEF9A9A),
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

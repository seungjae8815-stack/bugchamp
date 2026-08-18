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
import '../../ui/toast.dart';

/// 상점 탭 — 인앱결제 카탈로그(iap.json).
///
/// (2026-08) 제작 탭은 제거했다 — 물약 제작은 사용률이 낮고 광고 버프와 역할이
/// 겹쳤다. `craft.json`·`SaveController.craft` 는 남아 있어 되살리기 쉽다.
class CraftScreen extends ConsumerWidget {
  const CraftScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final save = ref.watch(saveControllerProvider).requireValue;

    return Scaffold(
      appBar: AppBar(title: Text(l.tabStore)),
      body: _StoreSection(save: save),
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
      // +1 = 교환소(맨 위), +1 = 복원 줄, 개발자 모드면 배너까지.
      itemCount: products.length + 2 + (devMode ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        if (devMode && i == 0) return _devBanner(l);
        final j = devMode ? i - 1 : i;
        // 교환소를 상품보다 **위**에 둔다 — 젤리를 이미 가진 사람이 쓸 곳을
        // 먼저 보여줘야, 젤리가 남아서 안 사는 상태를 끊는다.
        if (j == 0) return const _ExchangeCard();
        final idx = j - 1;
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
              showCenterToast(ctx, l.storeRestoreDone);
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
    // 기간제라 '보유'로 잠그지 않는다 — 재구매로 기간을 잇는다.
    IapType.buffPass => false,
    IapType.starter => save.starterBought,
    IapType.skin => save.ownedSkins.contains(product.skinId),
    _ => false, // 젤리·패스는 반복 구매 가능
  };

  (IconData, Color) get _style => switch (product.type) {
    IapType.removeAds => (Icons.block_rounded, const Color(0xFF5FD3C8)),
    IapType.buffPass => (Icons.auto_awesome_rounded, const Color(0xFFEBA52F)),
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
    showCenterToast(ctx, msg);
  }
}

/// 교환소 — 젤리를 **지금 스테이지 기준** 골드·재료로 바꾼다.
///
/// 상점 맨 위에 두는 이유: 영구 소비처를 다 산 유저는 젤리가 남아서 팩을 안
/// 산다. 쓸 곳을 먼저 보여줘야 그 상태가 끊긴다(2026-08-18 경제 분석).
class _ExchangeCard extends ConsumerStatefulWidget {
  const _ExchangeCard();

  @override
  ConsumerState<_ExchangeCard> createState() => _ExchangeCardState();
}

class _ExchangeCardState extends ConsumerState<_ExchangeCard> {
  /// 한 번에 몇 묶음 교환할지. 후반엔 10개씩 바꾸는 게 답답해서 배수를 둔다.
  int _trades = 1;
  bool _wantGold = true;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final save = ref.watch(saveControllerProvider).requireValue;
    final cfg = ref.watch(gameDataProvider).requireValue.runConfig;
    if (cfg == null) return const SizedBox.shrink();

    final ctrl = ref.read(saveControllerProvider.notifier);
    final out = ctrl.exchangeJelly(trades: _trades, wantGold: _wantGold);
    final cost = cfg.exchangeJellyPerTrade * _trades;
    final have = save.materialCount(MaterialKind.jelly);
    final enough = have >= cost;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0x22000000),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x559BE7FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.swap_horiz_rounded,
                color: Color(0xFF9BE7FF),
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                l.exchangeTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              materialImage(
                MaterialKind.jelly,
                size: 15,
                fallback: const SizedBox(width: 15),
              ),
              const SizedBox(width: 3),
              Text(
                formatCompact(have),
                style: const TextStyle(
                  color: Color(0xFF9BE7FF),
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            l.exchangeHint,
            style: const TextStyle(color: Color(0x99FFFFFF), fontSize: 11),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _pick(
                  l.exchangeToGold,
                  _wantGold,
                  Icons.paid_rounded,
                  () => setState(() => _wantGold = true),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _pick(
                  l.exchangeToMaterial,
                  !_wantGold,
                  Icons.science_rounded,
                  () => setState(() => _wantGold = false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final n in const [1, 5, 10])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _qty(n),
                ),
              const Spacer(),
              Text(
                l.exchangeCost(cost),
                style: TextStyle(
                  color: enough
                      ? const Color(0xFF9BE7FF)
                      : const Color(0xFFFF8A6B),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton.icon(
              onPressed: (out == null || !enough)
                  ? null
                  : () async {
                      final ok = await ctrl.tradeJelly(
                        trades: _trades,
                        wantGold: _wantGold,
                      );
                      if (!context.mounted) return;
                      showCenterToast(
                        context,
                        ok ? l.exchangeDone : l.notEnoughJelly,
                      );
                    },
              icon: const Icon(Icons.swap_horiz_rounded, size: 18),
              label: Text(
                out == null
                    ? l.notEnoughJelly
                    : (_wantGold
                          ? l.exchangeGetGold(formatCompact(out.gold))
                          : l.exchangeGetMaterial(
                              formatCompact(out.materials),
                            )),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2E6DA4),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pick(String label, bool on, IconData icon, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: on ? const Color(0x332E6DA4) : const Color(0x18000000),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: on ? const Color(0xFF9BE7FF) : const Color(0x22FFFFFF),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: on ? const Color(0xFF9BE7FF) : const Color(0x99FFFFFF),
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: on ? Colors.white : const Color(0x99FFFFFF),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      );

  Widget _qty(int n) {
    final on = _trades == n;
    return GestureDetector(
      onTap: () => setState(() => _trades = n),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: on ? const Color(0xFF2E6DA4) : const Color(0x18000000),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: on ? const Color(0xFF9BE7FF) : const Color(0x22FFFFFF),
          ),
        ),
        child: Text(
          '×$n',
          style: TextStyle(
            color: on ? Colors.white : const Color(0x99FFFFFF),
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

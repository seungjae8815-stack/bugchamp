import 'dart:math' as math;
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
import '../../ui/skins.dart';
import '../../domain/audio_service.dart';
import '../../ui/game_dialog.dart';
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
      // 상점 배경 — 숲속 좌판. 목록이 그 위에 얹힌다.
      // 없으면 기본 배경이라 화면이 깨지지 않는다(§6).
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/ui/shop_bg.webp',
              fit: BoxFit.cover,
              filterQuality: FilterQuality.medium,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
          // 글자가 읽히도록 어둡게 깐다.
          const Positioned.fill(child: ColoredBox(color: Color(0xCC0E1408))),
          _StoreSection(save: save),
        ],
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
      // +1 = 알 뽑기, +1 = 교환소, +1 = 복원 줄, 개발자 모드면 배너까지.
      itemCount: products.length + 3 + (devMode ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        if (devMode && i == 0) return _devBanner(l);
        final j = devMode ? i - 1 : i;
        // 젤리 소비처(뽑기·교환소)를 상품보다 **위**에 둔다 — 젤리를 이미
        // 가진 사람이 쓸 곳을 먼저 봐야, 젤리가 남아서 안 사는 상태가 끊긴다.
        if (j == 0) return const _GachaCard();
        if (j == 1) return const _ExchangeCard();
        final idx = j - 2;
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
    //
    // ⚠️ 곤충학자 패스와 **무한 버프 패스는 칸이 다르다**(`passExpiresAt` /
    // `buffPassExpiresAt`). 예전엔 곤충학자 패스만 봐서, 무한 버프 패스는
    // 사고 나서도 남은 기간이 안 보였다(2026-09-01 실기 지적).
    final passEndsAt = switch (product.type) {
      IapType.pass => save.passActive(now) ? save.passExpiresAt : null,
      IapType.buffPass =>
        save.buffPassActive(now) ? save.buffPassExpiresAt : null,
      _ => null,
    };
    final passLeft = passEndsAt?.difference(now).inDays;

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
            // 상품 그림(assets/images/shop/). 없으면 타입 아이콘.
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: gameImageChain(
                [
                  if (product.image != null)
                    'assets/images/shop/${product.image}.webp',
                  'assets/images/shop/${product.id}.webp',
                ],
                size: 44,
                fit: BoxFit.cover,
                fallback: Icon(icon, color: color, size: 24),
              ),
            ),
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
                  Row(
                    children: [
                      if (product.grant.jelly > 0) ...[
                        jellyIcon(size: 14),
                        const SizedBox(width: 3),
                        Text('${product.grant.jelly}', style: _grantStyle),
                        const SizedBox(width: 8),
                      ],
                      if (product.grant.gold > 0) ...[
                        goldIcon(size: 14),
                        const SizedBox(width: 3),
                        Text(
                          formatCompact(product.grant.gold),
                          style: _grantStyle,
                        ),
                      ],
                    ],
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

/// 곤충 알 뽑기(가챠) — 젤리의 제1 소비처(§2.6 각주, 2026-08-31 확정).
///
/// 파는 것: 고급+ 보장 · 이색 1/30 · 10회 천장(영웅+). **스탯이 아니라
/// 드롭의 시간 절약**이다 — 야생과 같은 포텐셜 분포를 쓴다.
class _GachaCard extends ConsumerWidget {
  const _GachaCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final save = ref.watch(saveControllerProvider).requireValue;
    final cfg = ref.watch(gameDataProvider).requireValue.petConfig;
    if (cfg == null || cfg.gachaJellyCost <= 0) return const SizedBox.shrink();
    final have = save.materialCount(MaterialKind.jelly);
    final enough = have >= cfg.gachaJellyCost;
    final toPity = cfg.gachaEpicPity <= 0
        ? 0
        : cfg.gachaEpicPity - save.gachaPity;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0x22000000),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x66E9A6FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🥚', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 6),
              Text(
                l.gachaTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              jellyIcon(size: 15),
              const SizedBox(width: 3),
              Text(
                formatCompact(have),
                style: const TextStyle(
                  color: Color(0xFFBFE3FF),
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            l.gachaDesc,
            style: const TextStyle(
              color: Color(0xB3FFFFFF),
              fontSize: 11.5,
              height: 1.35,
            ),
          ),
          if (toPity > 0) ...[
            const SizedBox(height: 4),
            Text(
              l.gachaPityLeft(toPity),
              style: const TextStyle(
                color: Color(0xFFE9A6FF),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: enough ? () => _draw(context, ref, l) : null,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF8E4DA8),
              ),
              child: Text(
                l.gachaDraw(cfg.gachaJellyCost),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _draw(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l,
  ) async {
    // ⚠️ **뽑기(젤리 차감·결과 확정)는 카드를 고른 뒤에 한다.**
    // 먼저 뽑아 두고 카드만 뒤집는 연출이면, 어느 카드를 골라도 같은 결과라
    // 고르는 행위가 거짓말이 된다. 실패(젤리 부족·채집함 가득)도 카드를
    // 고르기 전에 알려야 한다 — 그래서 사전 검사만 여기서 한다.
    final save = ref.read(saveControllerProvider).requireValue;
    final cfg = ref.read(gameDataProvider).requireValue.petConfig;
    if (cfg == null) return;
    if (save.storageFull) {
      showCenterToast(context, l.gachaStorageFull);
      return;
    }
    if (save.materialCount(MaterialKind.jelly) < cfg.gachaJellyCost) {
      showCenterToast(context, l.notEnoughJelly);
      return;
    }

    final picked = await showGameDialog<bool>(
      context,
      title: l.gachaPickTitle,
      icon: Icons.style_rounded,
      barrierDismissible: false,
      content: _GachaPicker(cost: cfg.gachaJellyCost, hint: l.gachaPickHint),
      actions: const [],
    );
    if (picked != true || !context.mounted) return;

    final r = await ref.read(saveControllerProvider.notifier).gachaDraw();
    if (!context.mounted) return;
    if (r.bug == null) {
      showCenterToast(context, switch (r.error) {
        'storage_full' => l.gachaStorageFull,
        'no_jelly' => l.notEnoughJelly,
        _ => l.gachaOff,
      });
      return;
    }
    final bug = r.bug!;
    final data = ref.read(gameDataProvider).requireValue;
    final sp = data.speciesById[bug.speciesId];
    if (sp == null) return;
    final locale = Localizations.localeOf(context).languageCode;
    AudioService.instance.sfxRare();
    await showGameDialog<void>(
      context,
      title: l.gachaResultTitle,
      icon: Icons.egg_rounded,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          bugStageImage(
            bug.speciesId,
            LifeStage.adult,
            size: 96,
            fallback: bugAvatar(sp, size: 84),
            skin: bug.variant == BugVariant.none
                ? null
                : SkinView(bug.variant.key),
          ),
          const SizedBox(height: 8),
          Text(
            sp.name.resolve(locale),
            style: TextStyle(
              color: gradeColor(sp.grade),
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '${gradeLabel(l, sp.grade)} · ${bug.potential}★'
            '${bug.variant != BugVariant.none ? ' · ${l.dexVariant}!' : ''}',
            style: const TextStyle(color: Color(0xDDFFFFFF), fontSize: 12.5),
          ),
          const SizedBox(height: 6),
          Text(
            l.gachaResultHint,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0x99FFFFFF), fontSize: 11),
          ),
        ],
      ),
      actions: [gameDialogButton(l.actionClose, () => Navigator.pop(context))],
    );
  }
}

/// 알 카드 3장 중 하나를 고르는 연출.
///
/// ⚠️ **결과를 정하지 않는다.** 고른 뒤에 진짜 뽑기가 돌아간다 — 미리 뽑아
/// 두고 카드만 뒤집으면 어느 카드를 골라도 같은 결과라, 고르는 행위가
/// 거짓말이 된다. 여기서 파는 건 결과가 아니라 **고르는 순간의 긴장**이다.
class _GachaPicker extends StatefulWidget {
  const _GachaPicker({required this.cost, required this.hint});

  final int cost;
  final String hint;

  @override
  State<_GachaPicker> createState() => _GachaPickerState();
}

class _GachaPickerState extends State<_GachaPicker>
    with SingleTickerProviderStateMixin {
  /// 고른 카드. null 이면 아직 고르는 중.
  int? _chosen;

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _pick(int i) async {
    if (_chosen != null) return;
    setState(() => _chosen = i);
    AudioService.instance.sfxCatch();
    // 고른 카드가 떠오르며 흔들리는 동안 기다린다 — 이 0.9초가 연출의 전부다.
    await _c.forward();
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.hint,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0x99FFFFFF), fontSize: 11.5),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 132,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < 3; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: _card(i),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            jellyIcon(size: 14),
            const SizedBox(width: 3),
            Text(
              '${widget.cost}',
              style: const TextStyle(
                color: Color(0xFFBFE3FF),
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _card(int i) {
    final chosen = _chosen == i;
    final dimmed = _chosen != null && !chosen;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        // 고른 카드는 떠오르며 커지고, 나머지는 흐려진다.
        final lift = chosen ? -14.0 * t : 0.0;
        final scale = chosen ? 1 + 0.12 * t : (dimmed ? 1 - 0.08 * t : 1.0);
        // 마지막 0.3 구간에서 좌우로 떤다 — "무엇이 나올까"의 긴장.
        final shake = chosen && t > 0.55
            ? math.sin((t - 0.55) * 40) * 3 * (1 - t)
            : 0.0;
        return Opacity(
          opacity: dimmed ? 1 - 0.6 * t : 1,
          child: Transform.translate(
            offset: Offset(shake, lift),
            child: Transform.scale(
              scale: scale,
              child: GestureDetector(
                onTap: () => _pick(i),
                child: Container(
                  width: 82,
                  height: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF6C3A80), Color(0xFF2E1740)],
                    ),
                    border: Border.all(
                      color: chosen
                          ? const Color(0xFFEBC24A)
                          : const Color(0x66E9A6FF),
                      width: chosen ? 2 : 1.2,
                    ),
                    boxShadow: chosen
                        ? [
                            BoxShadow(
                              color: const Color(
                                0xFFEBC24A,
                              ).withValues(alpha: 0.45 * t),
                              blurRadius: 18,
                            ),
                          ]
                        : null,
                  ),
                  clipBehavior: Clip.antiAlias,
                  alignment: Alignment.center,
                  // 카드 뒷면 그림이 있으면 그걸 쓰고, 없으면 이모지 폴백(§6).
                  child: Image.asset(
                    'assets/images/ui/gacha_card_back.webp',
                    fit: BoxFit.cover,
                    width: 82,
                    height: 120,
                    filterQuality: FilterQuality.medium,
                    errorBuilder: (_, _, _) =>
                        const Text('🥚', style: TextStyle(fontSize: 34)),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
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
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0x22000000),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x559BE7FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 머리그림 — 없으면 그냥 안 나온다(§6 폴백).
          Image.asset(
            'assets/images/ui/exchange.webp',
            height: 96,
            width: double.infinity,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
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
                    // 눌러서 **보유 재화·재료 전부**를 본다. 교환 결과가 재료로
                    // 가는데 지금 뭘 얼마나 가졌는지 모르면 얼마를 바꿀지 못 정한다.
                    GestureDetector(
                      onTap: () => _showHoldings(context, l, save),
                      behavior: HitTestBehavior.opaque,
                      child: Row(
                        children: [
                          jellyIcon(size: 15),
                          const SizedBox(width: 3),
                          Text(
                            formatCompact(have),
                            style: const TextStyle(
                              color: Color(0xFF9BE7FF),
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(
                            Icons.info_outline_rounded,
                            size: 13,
                            color: Color(0x99FFFFFF),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  l.exchangeHint,
                  style: const TextStyle(
                    color: Color(0x99FFFFFF),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _pick(
                        l.exchangeToGold,
                        _wantGold,
                        goldIcon(size: 16),
                        () => setState(() => _wantGold = true),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _pick(
                        l.exchangeToMaterial,
                        !_wantGold,
                        // 재료는 3종을 고루 주므로 대표로 키틴을 보인다.
                        materialImage(
                          MaterialKind.chitin,
                          size: 16,
                          fallback: const Icon(Icons.science_rounded, size: 15),
                        ),
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
                    jellyIcon(size: 14),
                    const SizedBox(width: 3),
                    Text(
                      '$cost',
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
          ),
        ],
      ),
    );
  }

  Widget _pick(String label, bool on, Widget icon, VoidCallback onTap) =>
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
              // 켜졌을 때만 또렷하게 — 아이콘은 색을 못 바꾸므로 투명도로.
              Opacity(opacity: on ? 1 : 0.55, child: icon),
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

/// 보유 재화·재료 전부를 한눈에. 교환소의 젤리 수치를 누르면 뜬다.
Future<void> _showHoldings(
  BuildContext context,
  AppLocalizations l,
  SaveGame save,
) => showGameDialog<void>(
  context,
  title: l.exchangeHoldings,
  icon: Icons.inventory_2_rounded,
  content: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      _holdRow(goldIcon(size: 20), l.curGold, formatCompact(save.gold)),
      for (final k in MaterialKind.values)
        _holdRow(
          materialImage(k, size: 20, fallback: const SizedBox(width: 20)),
          materialLabel(l, k),
          formatCompact(save.materialCount(k)),
        ),
    ],
  ),
  actions: [gameDialogButton(l.actionClose, () => Navigator.pop(context))],
);

Widget _holdRow(Widget icon, String name, String amount) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 4),
  child: Row(
    children: [
      icon,
      const SizedBox(width: 8),
      Text(
        name,
        style: const TextStyle(color: Color(0xDDFFFFFF), fontSize: 13),
      ),
      const Spacer(),
      Text(
        amount,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 13.5,
        ),
      ),
    ],
  ),
);

/// 상품 카드의 지급량 글자(젤리·골드 공통).
const _grantStyle = TextStyle(
  color: Color(0xFFEBD24A),
  fontSize: 12,
  fontWeight: FontWeight.w800,
);

import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/providers.dart';
import '../../domain/save_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/art.dart';
import '../../ui/colors.dart';
import '../../ui/game_dialog.dart';
import '../../ui/jelly_short.dart';
import '../../ui/toast.dart';
import 'equip_widgets.dart';

/// 옵션 한 줄 **다듬기** 창(2026-10-10 장비 v2, docs/design_equipment_v2.md §1).
///
/// 한 창 안에서 **종류 고르기(선택) → 화석/젤리로 굴리기 → 이전/새 값 고르기**를 하고, 닫지 않고 다시 다듬을 수 있다.
/// 어느 쪽을 골라도 그 줄의 정성이 올라 다음 굴림의 바닥이 높아진다.
/// [equipped] 면 낀 장비([slot]), 아니면 모루 맨 위.
Future<void> showPolishDialog(
  BuildContext context, {
  required int index,
  required bool equipped,
  EquipSlot? slot,
}) {
  final l = AppLocalizations.of(context);
  return showGameDialog<void>(
    context,
    title: l.polishTitle,
    icon: Icons.auto_fix_high_rounded,
    content: _PolishBody(index: index, equipped: equipped, slot: slot),
    actions: [
      gameDialogButton(
        l.actionClose,
        () => Navigator.pop(context),
        primary: false,
      ),
    ],
  );
}

class _PolishBody extends ConsumerStatefulWidget {
  const _PolishBody({
    required this.index,
    required this.equipped,
    required this.slot,
  });

  final int index;
  final bool equipped;
  final EquipSlot? slot;

  @override
  ConsumerState<_PolishBody> createState() => _PolishBodyState();
}

class _PolishBodyState extends ConsumerState<_PolishBody> {
  /// 고른 종류(null = 종류도 무작위).
  ItemOptionKind? _kind;

  /// 방금 굴린 새 값 — 고르기 전까지 화면에 이전 값과 나란히 보인다.
  ItemOption? _candidate;
  bool _busy = false;

  EquipItem? _item() {
    final s = ref.watch(saveControllerProvider).value;
    if (s == null) return null;
    if (widget.equipped) {
      return widget.slot == null ? null : s.equippedItems[widget.slot];
    }
    return s.forgeStack.isEmpty ? null : s.forgeStack.last;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final data = ref.watch(gameDataProvider).value;
    final items = data?.itemConfig;
    final forge = data?.forgeConfig;
    final item = _item();
    if (items == null || forge == null || item == null) {
      return const SizedBox.shrink();
    }
    if (widget.index >= item.options.length) return const SizedBox.shrink();
    final cur = item.options[widget.index];
    final ranges = {for (final r in items.optionPool) r.kind: r};
    final others = {
      for (var i = 0; i < item.options.length; i++)
        if (i != widget.index) item.options[i].kind,
    };
    final kinds = [
      for (final r in items.optionPool)
        if (!others.contains(r.kind)) r.kind,
    ];
    final save = ref.watch(saveControllerProvider).value;
    final cost = forge.polishCost(item.tier, pickKind: _kind != null);
    final fossils = save?.materialCount(MaterialKind.fossil) ?? 0;
    final nextPolish = (cur.polish + 1).clamp(0, items.polishMaxStacks);
    final floorPct = (nextPolish * items.polishFloorPerStack * 100).round();

    Widget line(String tag, ItemOption o, {bool hi = false}) {
      final max = ranges[o.kind]?.maxAt(item.tier);
      return Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: hi ? const Color(0x33E8B84A) : const Color(0x22000000),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: hi ? kHoney.withValues(alpha: 0.8) : const Color(0x33FFFFFF),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 46,
              child: Text(
                tag,
                style: const TextStyle(color: Color(0x99FFFFFF), fontSize: 11),
              ),
            ),
            Expanded(
              child: Text(
                optionLabel(l, o.kind),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '+${o.value.toStringAsFixed(o.value >= 10 ? 0 : 1)}%',
              style: TextStyle(
                color: hi ? kHoney : const Color(0xFFC5E1A5),
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (max != null && max > 0)
              Text(
                '/${max.toStringAsFixed(max >= 10 || max == max.roundToDouble() ? 0 : 1)}',
                style: const TextStyle(color: Color(0x66FFFFFF), fontSize: 11),
              ),
          ],
        ),
      );
    }

    // ── 굴린 뒤: 이전 / 새 값 고르기 ──
    final cand = _candidate;
    if (cand != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          line(l.polishOld, cur),
          line(l.polishNew, cand, hi: true),
          const SizedBox(height: 2),
          Text(
            l.polishChooseHint,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0x99FFFFFF), fontSize: 11),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() => _candidate = null),
                  child: Text(l.polishKeepOld),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: _busy ? null : () => _take(cand),
                  child: Text(l.polishTakeNew),
                ),
              ),
            ],
          ),
        ],
      );
    }

    // ── 굴리기 전: 지금 값 · 정성 · 종류 · 결제 ──
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        line(l.polishNow, cur),
        Text(
          l.polishStacks(
            '${cur.polish}',
            '${items.polishMaxStacks}',
            '$floorPct',
          ),
          textAlign: TextAlign.center,
          style: const TextStyle(color: kHoney, fontSize: 11.5),
        ),
        const SizedBox(height: 10),
        // 종류 고르기 — 무작위(기본) 또는 원하는 종류(비용 × polishKindMult).
        DropdownButtonHideUnderline(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: const Color(0x22000000),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0x33FFFFFF)),
            ),
            child: DropdownButton<ItemOptionKind?>(
              value: _kind,
              isExpanded: true,
              dropdownColor: const Color(0xFF2B2420),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              items: [
                DropdownMenuItem(value: null, child: Text(l.polishRandomKind)),
                for (final k in kinds)
                  DropdownMenuItem(
                    value: k,
                    child: Text(
                      l.polishPickKind(
                        optionLabel(l, k),
                        '${forge.polishKindMult}',
                      ),
                    ),
                  ),
              ],
              onChanged: _busy ? null : (v) => setState(() => _kind = v),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _busy ? null : () => _roll(payJelly: false),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    materialImage(
                      MaterialKind.fossil,
                      size: 16,
                      fallback: const Icon(Icons.diamond_outlined, size: 14),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${cost.fossils}',
                      style: TextStyle(
                        color: fossils >= cost.fossils
                            ? Colors.white
                            : const Color(0xFFEF9A9A),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                onPressed: _busy ? null : () => _roll(payJelly: true),
                child: jellyPrice(cost: cost.jelly, fontSize: 13, size: 16),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          l.polishHint('$fossils'),
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0x88FFFFFF), fontSize: 10.5),
        ),
      ],
    );
  }

  Future<void> _roll({required bool payJelly}) async {
    final l = AppLocalizations.of(context);
    setState(() => _busy = true);
    final r = await ref
        .read(saveControllerProvider.notifier)
        .polishOption(
          index: widget.index,
          equipped: widget.equipped,
          slot: widget.slot,
          kind: _kind,
          payJelly: payJelly,
        );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _candidate = r.candidate;
    });
    switch (r.error) {
      case null:
        break;
      case 'not_enough_jelly':
        await showJellyShort(context);
      case 'not_enough_fossil':
        showCenterToast(context, l.polishNoFossil);
      case 'bad_kind':
        showCenterToast(context, l.polishBadKind);
      default:
        showCenterToast(context, l.polishFailed);
    }
  }

  Future<void> _take(ItemOption cand) async {
    setState(() => _busy = true);
    await ref
        .read(saveControllerProvider.notifier)
        .choosePolish(
          index: widget.index,
          candidate: cand,
          equipped: widget.equipped,
          slot: widget.slot,
        );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _candidate = null;
      // 종류를 골라 바꿨으면 그 종류가 지금 줄이 된다 — 다음 굴림도 같은 종류로 이어 가기 쉽게 둔다.
    });
  }
}

/// 장비 머리줄의 환생 별 — `★★★☆☆ +12%`(별이 없으면 빈 칸). 다음 별까지 진행은 [progress] 로.
Widget itemStarsRow(
  AppLocalizations l,
  ItemConfig cfg,
  EquipItem item, {
  bool progress = false,
}) {
  if (item.stars <= 0 && !progress) return const SizedBox.shrink();
  final need = cfg.starNeedAt(item.stars);
  final pct = (cfg.starEffectPerStar * item.stars * 100).round();
  return Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < cfg.starMax; i++)
          Icon(
            i < item.stars ? Icons.star_rounded : Icons.star_outline_rounded,
            size: 14,
            color: i < item.stars ? kHoney : const Color(0x55FFFFFF),
          ),
        const SizedBox(width: 4),
        if (item.stars > 0)
          Text(
            l.starBonus('$pct'),
            style: const TextStyle(
              color: kHoney,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        if (progress && need > 0) ...[
          const SizedBox(width: 6),
          Text(
            l.starProgress('${item.starExp}', '$need'),
            style: const TextStyle(color: Color(0x99FFFFFF), fontSize: 10.5),
          ),
        ],
      ],
    ),
  );
}

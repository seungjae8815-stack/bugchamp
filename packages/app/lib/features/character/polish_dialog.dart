import 'dart:math' as math;
import 'dart:async';

import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/providers.dart';
import '../../domain/save_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/art.dart';
import '../../ui/colors.dart';
import '../../ui/format.dart';
import '../../ui/game_dialog.dart';
import '../../ui/jelly_confirm.dart';
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
    // 다듬은 횟수만큼 비싸진다(2026-10-16) — 컨트롤러 `polishOption` 과 같은 식.
    final cost = forge.polishCost(
      item.tier,
      pickKind: _kind != null,
      done: cur.polish,
      research:
          data?.researchFx(save?.researchLevels ?? const {}) ??
          ResearchEffects.none,
    );
    final fossils = save?.materialCount(MaterialKind.fossil) ?? 0;
    // 지금 값이 최대의 몇 %인지(다음 값은 늘 이보다 높다 — `polishOptionAt`).
    final floorPct =
        (polishPositionOf(
                  items,
                  item,
                  widget.index,
                  maxMult: forge.transcendMaxMult(save?.forgeTranscend ?? 0),
                ) *
                100)
            .round();

    Widget line(String tag, ItemOption o, {bool hi = false}) {
      final mm = forge.transcendMaxMult(save?.forgeTranscend ?? 0);
      // 화면 값 = 효과(%) — 저장 눈금 × `effectScale`(치명 피해 0.1, 2026-10-14 곱 전환).
      final sc = items.effectScaleOf(o.kind);
      final shown = o.value * sc;
      final max = ranges[o.kind] == null
          ? null
          : ranges[o.kind]!.maxAt(item.tier) * mm * sc;
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
              '+${fmtOptPct(shown)}%',
              style: TextStyle(
                color: hi ? kHoney : const Color(0xFFC5E1A5),
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (max != null && max > 0)
              Text(
                '/${fmtOptPct(max)}',
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
            // n 번을 다듬은 뒤의 n+1 번째부터 그대로(비용 = 성장^min(다듬은 횟수, 상한)) — 공략집과 같은 값.
            '${items.polishMaxStacks + 1}',
            '$floorPct',
          ),
          textAlign: TextAlign.center,
          style: const TextStyle(color: kHoney, fontSize: 11.5),
        ),
        const SizedBox(height: 10),
        // 종류 고르기 — 무작위(기본) 또는 원하는 종류(비용 × polishKindMult). 드롭다운은 기본 글자 모양이라
        // 게임 화면과 안 맞았다(2026-10-10 실기 지적) — 칩으로.
        Text(
          l.polishKindHint('${forge.polishKindMult}'),
          style: const TextStyle(color: Color(0x99FFFFFF), fontSize: 11),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _kindChip(l.polishRandomKind, _kind == null, () {
              if (!_busy) setState(() => _kind = null);
            }),
            for (final k in kinds)
              _kindChip(optionLabel(l, k), _kind == k, () {
                if (!_busy) setState(() => _kind = k);
              }),
          ],
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
                onPressed: _busy
                    ? null
                    : () async {
                        // 젤리를 쓰는 버튼은 확인부터(출시 전 점검 — 다듬을수록 ×1.5 로 비싸진다).
                        if (!await confirmJellySpend(
                          context,
                          title: l.polishTitle,
                          body: l.polishJellyConfirm(cost.jelly),
                          jelly: cost.jelly,
                          actionLabel: l.polishTitle,
                        )) {
                          return;
                        }
                        await _roll(payJelly: true);
                      },
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

  Widget _kindChip(String text, bool on, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: on ? kHoney.withValues(alpha: 0.22) : const Color(0x22000000),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: on ? kHoney : const Color(0x44FFFFFF),
          width: on ? 1.4 : 1,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: on ? kHoney : const Color(0xDDFFFFFF),
          fontSize: 12,
          fontWeight: on ? FontWeight.w900 : FontWeight.w700,
        ),
      ),
    ),
  );

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
    // 다듬기 v3 — 새 값은 늘 더 높다. 종류가 그대로면 고를 것 없이 바로 얹는다(출시 전 점검 — 매번 고르기를 거쳤다).
    final cand = r.candidate;
    final curKind = _currentKind();
    if (cand != null && curKind != null && cand.kind == curKind) {
      setState(() => _busy = false);
      await _take(cand);
      if (mounted) showCenterToast(context, l.polishApplied);
      return;
    }
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
      case 'maxed':
        showCenterToast(context, l.polishMaxed);
      default:
        showCenterToast(context, l.polishFailed);
    }
  }

  /// 지금 다듬는 줄의 종류(장비가 그 사이 바뀌었으면 null).
  ItemOptionKind? _currentKind() {
    final s = ref.read(saveControllerProvider).value;
    if (s == null) return null;
    final item = widget.equipped
        ? (widget.slot == null ? null : s.equippedItems[widget.slot])
        : (s.forgeStack.isEmpty ? null : s.forgeStack.last);
    if (item == null || widget.index >= item.options.length) return null;
    return item.options[widget.index].kind;
  }

  Future<void> _take(ItemOption cand) async {
    setState(() => _busy = true);
    final ok = await ref
        .read(saveControllerProvider.notifier)
        .choosePolish(
          index: widget.index,
          candidate: cand,
          equipped: widget.equipped,
          slot: widget.slot,
        );
    if (!mounted) return;
    // 그 사이 장비가 바뀌어 새 값을 못 얹었으면 말해 준다(조용히 사라진 것처럼 보이지 않게).
    if (!ok) {
      showCenterToast(context, AppLocalizations.of(context).polishChanged);
    }
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
  // 좁은 칸(제련 비교 카드 등)에서는 글자가 다음 줄로 내려간다 — 한 줄(Row)로 두면 "다음 별 17/200" 이
  // 칸을 넘어가거나 잘렸다(2026-10-16 사장님 지적).
  return Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Wrap(
      spacing: 6,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < cfg.starMax; i++)
              // 빈 별은 같은 그림을 흑백·반투명으로(그림이 없으면 예전 빈 별 아이콘).
              gameIcon(
                'equip_star',
                size: 16,
                fallback: i < item.stars
                    ? Icons.star_rounded
                    : Icons.star_outline_rounded,
                color: i < item.stars ? kHoney : const Color(0x55FFFFFF),
                dim: i >= item.stars,
              ),
          ],
        ),
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
          Text(
            l.starProgress('${math.min(item.starExp, need)}', '$need'),
            style: const TextStyle(color: Color(0x99FFFFFF), fontSize: 10.5),
          ),
          // 이번 별 몫을 넘긴 재료는 다음 별로 이월된다(2026-10-14).
          if (item.starExp > need) ...[
            Text(
              l.starCarry('${item.starExp - need}'),
              style: const TextStyle(color: kHoney, fontSize: 10.5),
            ),
          ],
        ],
      ],
    ),
  );
}

/// 낀 장비의 **별 강화** 칸(2026-10-10 사장님 개편 — 옛 이름 환생).
/// 재료(같은 부위 장비) 진행 → 다 모이면 강화 시작 → 남은 시간(젤리로 당기기) → 완료.
class StarUpPanel extends ConsumerStatefulWidget {
  const StarUpPanel({super.key, required this.slot});
  final EquipSlot slot;

  @override
  ConsumerState<StarUpPanel> createState() => _StarUpPanelState();
}

class _StarUpPanelState extends ConsumerState<StarUpPanel> {
  Timer? _tick;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      final it = ref
          .read(saveControllerProvider)
          .value
          ?.equippedItems[widget.slot];
      if (mounted && it?.starUntil != null) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final data = ref.watch(gameDataProvider).value;
    final items = data?.itemConfig;
    final forge = data?.forgeConfig;
    final item = ref
        .watch(saveControllerProvider)
        .value
        ?.equippedItems[widget.slot];
    if (items == null || forge == null || item == null) {
      return const SizedBox.shrink();
    }
    const hint = TextStyle(color: Color(0x99FFFFFF), fontSize: 11);
    if (item.stars >= items.starMax) {
      return Text(l.starMaxed, style: hint);
    }
    final need = items.starNeedAt(item.stars);
    final until = item.starUntil;
    final ctrl = ref.read(saveControllerProvider.notifier);
    Widget wrap(Widget child) => Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 2),
      child: child,
    );

    if (until == null) {
      if (item.starExp < need) {
        return wrap(
          Text(l.starFeedHint('${item.starExp}', '$need'), style: hint),
        );
      }
      return wrap(
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _busy
                ? null
                : () => _run(() => ctrl.startStarUp(widget.slot)),
            child: Text(
              l.starUpStart(
                '${item.stars + 1}',
                formatShortDuration(
                  items.starUpDuration(
                    item.stars,
                    tier: item.tier,
                    research:
                        data?.researchFx(
                          ref
                                  .watch(saveControllerProvider)
                                  .value
                                  ?.researchLevels ??
                              const {},
                        ) ??
                        ResearchEffects.none,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    final left = until.difference(DateTime.now().toUtc());
    if (left <= Duration.zero) {
      return wrap(
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _busy ? null : () => _finish(l, items, viaJelly: false),
            child: Text(l.starUpFinish('${item.stars + 1}')),
          ),
        ),
      );
    }
    final jelly = forge.levelUpJelly(left);
    return wrap(
      Row(
        children: [
          Expanded(
            child: Text(
              l.starUpLeft('${item.stars + 1}', formatShortDuration(left)),
              style: const TextStyle(
                color: kHoney,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          FilledButton(
            onPressed: _busy
                ? null
                : () async {
                    final ok = await confirmJellySpend(
                      context,
                      title: l.starUpInstantTitle,
                      body: l.starUpInstantBody('${item.stars + 1}'),
                      jelly: jelly,
                    );
                    if (ok && mounted) await _finish(l, items, viaJelly: true);
                  },
            child: jellyPrice(cost: jelly, fontSize: 12.5, size: 15),
          ),
        ],
      ),
    );
  }

  Future<void> _run(Future<String?> Function() f) async {
    setState(() => _busy = true);
    await f();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _finish(
    AppLocalizations l,
    ItemConfig items, {
    required bool viaJelly,
  }) async {
    setState(() => _busy = true);
    final err = await ref
        .read(saveControllerProvider.notifier)
        .finishStarUp(widget.slot, viaJelly: viaJelly);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err == null) {
      final now = ref
          .read(saveControllerProvider)
          .value
          ?.equippedItems[widget.slot];
      if (now != null) {
        showCenterToast(
          context,
          l.forgeStarUp(
            '${now.stars}',
            '${(items.starEffectPerStar * now.stars * 100).round()}',
          ),
        );
      }
    } else if (err == 'not_enough_jelly') {
      await showJellyShort(context);
    }
  }
}

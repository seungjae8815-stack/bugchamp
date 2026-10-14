import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/game_data.dart';
import '../../domain/save_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/art.dart';
import '../../ui/colors.dart';
import '../../ui/game_dialog.dart';
import '../../ui/jelly_confirm.dart';
import '../../ui/labels.dart';
import '../../ui/toast.dart';

/// 펫 패시브 v2(2026-10-14, docs/design_growth_1021.md §1·§2)의 채집함 화면 조각 —
/// 곤충 상세의 **펫 패시브 카드** + **크기 다시 굴리기**(정수 또는 젤리 → 지금 값/새 값 고르기).
///
/// 값은 반드시 `passiveOf`(core_run) 로 낸다 — 합산(`petStatOf`)과 같은 함수라야
/// "화면에 본 패시브와 실제 효과가 다르다"가 안 생긴다.

/// 곤충 상세의 펫 패시브 카드. 알([isEgg])은 **종류만** 보이고 크기는 `??`(능력치 숫자는 부화 뒤 공개).
Widget petPassiveCard(
  BuildContext ctx,
  WidgetRef r,
  GameData data,
  IndividualBug bug, {
  required bool isEgg,
}) {
  final l = AppLocalizations.of(ctx);
  final petCfg = data.petConfig!;
  final sp = data.species(bug.speciesId);
  final p = passiveOf(bug, sp, petCfg);
  final v2 = petCfg.passiveV2.enabled;
  final showRoll = v2 && p != null && !isEgg;
  final String main;
  if (p == null) {
    main = l.passiveNone;
  } else if (isEgg) {
    main = '${passiveKindLabel(l, p.statKey)} ${l.hiddenStatValue}';
  } else {
    main = passiveText(l, p);
  }
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(10, 7, 10, 8),
    decoration: BoxDecoration(
      color: const Color(0x22EBA52F),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: kHoney.withValues(alpha: 0.5)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              l.passiveCardTitle,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
            const Spacer(),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          main,
          style: TextStyle(
            color: p == null ? const Color(0x99FFFFFF) : kHoney,
            fontWeight: FontWeight.w900,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          isEgg
              ? '${l.passiveCardHint} ${l.eggStatsHidden}'
              : l.passiveCardHint,
          style: const TextStyle(
            color: Color(0x99FFFFFF),
            fontSize: 10.5,
            height: 1.3,
          ),
        ),
        if (showRoll) ...[
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: () => _openPassiveReroll(ctx, r, data, bug.id),
              icon: gameIcon(
                'passive_reroll',
                size: 19,
                fallback: Icons.casino_rounded,
              ),
              // 업데이트 전 곤충은 무료 횟수가 남아 있으면 버튼에 바로 보인다(2026-10-14).
              label: Text(
                petCfg.passiveV2.freeRerollsLeft(bug) > 0
                    ? l.passiveRerollFree(
                        '${petCfg.passiveV2.freeRerollsLeft(bug)}',
                      )
                    : l.passiveReroll,
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: kHoney,
                side: BorderSide(color: kHoney.withValues(alpha: 0.6)),
                minimumSize: const Size(0, 34),
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

/// 재굴림 — 비용(정수/젤리)을 고르고, 내고, 지금 값/새 값 중 고른다. 비용은 어느 쪽이든 쓰인다.
Future<void> _openPassiveReroll(
  BuildContext ctx,
  WidgetRef r,
  GameData data,
  String bugId,
) async {
  final l = AppLocalizations.of(ctx);
  final petCfg = data.petConfig!;
  final cfg = petCfg.passiveV2;
  final save = r.read(saveControllerProvider).requireValue;
  // 고르지 않은 결과가 남아 있으면(앱을 껐다 켬 등) 새로 굴리지 않고 그것부터 고른다(2026-10-14).
  // 다른 곤충의 결과여도 그 곤충 것으로 먼저 고르게 한다 — 비용은 이미 냈다.
  final pendingId = save.passiveRerollBug;
  final pendingRoll = save.passiveRerollRoll;
  if (pendingId != null && pendingRoll != null) {
    final pb = save.bugs.where((b) => b.id == pendingId).firstOrNull;
    if (pb == null) {
      await r
          .read(saveControllerProvider.notifier)
          .pickPassiveReroll(accept: false);
    } else {
      await _pickPassiveRoll(ctx, r, data, pb, pendingRoll);
      return;
    }
  }
  if (!ctx.mounted) return;
  final bug = save.bugs.where((b) => b.id == bugId).firstOrNull;
  if (bug == null) return;
  final sp = data.species(bug.speciesId);
  final name = sp.name.resolve(Localizations.localeOf(ctx).languageCode);
  final cur = passiveOf(bug, sp, petCfg);
  if (cur == null) return;
  final have = save.essence[bug.speciesId] ?? 0;
  final essenceOk = cfg.rerollEssence > 0 && have >= cfg.rerollEssence;
  // 업데이트 전 곤충의 무료 재굴림(2026-10-14 사장님 확정 — 곤충마다 5번).
  final freeLeft = cfg.freeRerollsLeft(bug);
  final nav = Navigator.of(ctx, rootNavigator: true);

  // 'jelly' · 'essence' · 'free' · null = 취소
  final how = await showGameDialog<String>(
    ctx,
    title: l.passiveRerollTitleBug(name),
    icon: Icons.casino_rounded,
    iconWidget: _rerollIcon(),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l.passiveRerollCurrent(passiveText(l, cur)),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: kHoney,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l.passiveRerollDesc,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 12.5),
        ),
        const SizedBox(height: 6),
        if (freeLeft > 0) ...[
          Text(
            l.passiveRerollFreeHint('${cfg.legacyFreeRerolls}'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF8FE3A0),
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
        ],
        Text(
          l.passiveRerollEssenceHave(name, '$have'),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: essenceOk
                ? const Color(0xB3FFFFFF)
                : const Color(0xFFFF8A65),
            fontSize: 11.5,
          ),
        ),
      ],
    ),
    actions: [
      TextButton(onPressed: () => nav.pop(), child: Text(l.actionCancel)),
      // 무료가 남아 있으면 그것부터(정수·젤리 버튼은 그대로 둔다 — 무료를 아끼고 싶은 사람도 있다).
      if (freeLeft > 0)
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF3E8E4E),
          ),
          onPressed: () => nav.pop('free'),
          child: Text(l.passiveRerollFree('$freeLeft')),
        ),
      if (cfg.rerollEssence > 0)
        FilledButton(
          // 정수가 모자라면 끈다 — 눌러 보고 나서야 "부족"을 알게 하지 않는다.
          onPressed: essenceOk ? () => nav.pop('essence') : null,
          child: Text(l.passiveRerollEssence('${cfg.rerollEssence}')),
        ),
      if (cfg.rerollJelly > 0)
        FilledButton(
          onPressed: () => nav.pop('jelly'),
          child: jellyPrice(cost: cfg.rerollJelly),
        ),
    ],
  );
  if (how == null || !ctx.mounted) return;
  final useJelly = how == 'jelly';
  if (useJelly) {
    // 젤리 확인 창(모자라면 상점 안내로 바뀐다).
    final ok = await confirmJellySpend(
      ctx,
      title: l.passiveReroll,
      body: l.passiveRerollJellyConfirm,
      jelly: cfg.rerollJelly,
      actionLabel: l.passiveRerollJellyAction,
    );
    if (!ok || !ctx.mounted) return;
  }
  final res = await r
      .read(saveControllerProvider.notifier)
      .rerollPassive(bugId, useJelly: useJelly, free: how == 'free');
  if (!ctx.mounted) return;
  if (!res.isOk) {
    showCenterToast(ctx, switch (res.error) {
      'no_jelly' => l.notEnoughJelly,
      'no_essence' => l.passiveRerollNoEssence,
      'egg' => l.passiveRerollEgg,
      'no_free' => l.igGradeFailed,
      _ => l.igGradeFailed,
    });
    return;
  }
  final newRoll = res.extra['roll'] as int;
  await _pickPassiveRoll(ctx, r, data, bug, newRoll);
}

/// 지금 값 / 새 값([newRoll]) 비교 창 — 고른 결과를 세이브의 대기에서 반영하고 지운다.
Future<void> _pickPassiveRoll(
  BuildContext ctx,
  WidgetRef r,
  GameData data,
  IndividualBug bug,
  int newRoll,
) async {
  final l = AppLocalizations.of(ctx);
  final petCfg = data.petConfig!;
  final sp = data.species(bug.speciesId);
  final nav = Navigator.of(ctx, rootNavigator: true);
  final cur = passiveOf(bug, sp, petCfg);
  final next = passiveOf(bug.copyWith(passiveRoll: newRoll), sp, petCfg);
  if (cur == null || next == null) return;

  Widget side(String title, SpeciesPassive p, int roll, {bool hi = false}) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0x22000000),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: hi ? kHoney : const Color(0x33FFFFFF),
              width: hi ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                title,
                style: const TextStyle(color: Color(0xB3FFFFFF), fontSize: 11),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  passiveText(l, p),
                  maxLines: 1,
                  style: const TextStyle(
                    color: kHoney,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  final oldRoll = bug.passiveRollValue;
  // 닫기로 빠져나가지 못하게 — 이미 낸 비용의 결과는 반드시 고르게 한다.
  final take = await showGameDialog<bool>(
    ctx,
    // 어느 곤충의 결과인지(대기 결과는 다른 곤충 것일 수 있다 — 2026-10-14 점검).
    title: l.passiveRerollTitleBug(
      sp.name.resolve(Localizations.localeOf(ctx).languageCode),
    ),
    icon: Icons.casino_rounded,
    iconWidget: _rerollIcon(),
    barrierDismissible: false,
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            side(l.passiveRerollNow, cur, oldRoll, hi: oldRoll > newRoll),
            const SizedBox(width: 8),
            side(l.passiveRerollNew, next, newRoll, hi: newRoll > oldRoll),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          l.passiveRerollPaid,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0x99FFFFFF), fontSize: 11),
        ),
      ],
    ),
    actions: [
      gameDialogButton(
        l.passiveRerollKeep,
        () => nav.pop(false),
        primary: false,
      ),
      gameDialogButton(l.passiveRerollTakeNew, () => nav.pop(true)),
    ],
  );
  await r
      .read(saveControllerProvider.notifier)
      .pickPassiveReroll(accept: take == true);
}

/// 패시브 재굴림 팝업 제목 그림 — 없으면 예전 주사위 아이콘.
Widget _rerollIcon() =>
    gameIcon('passive_reroll', size: 40, fallback: Icons.casino_rounded);

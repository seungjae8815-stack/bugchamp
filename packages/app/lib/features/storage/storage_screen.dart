import 'dart:math' as math;

import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ui/toast.dart';
import '../../data/game_data.dart';
import '../../domain/audio_service.dart';
import '../../domain/bug_auto_filter.dart';
import '../../domain/providers.dart';
import '../../domain/save_controller.dart';
import 'package:core_save/core_save.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/art.dart';
import '../../ui/concept_card.dart';
import '../../ui/format.dart';
import '../../ui/game_dialog.dart';
import '../../ui/jelly_confirm.dart';
import '../../ui/safe_grid.dart';
import '../../ui/labels.dart';
import '../../ui/skins.dart';
import '../battle/duel_bug_build.dart';
import '../battle/training_screen.dart';
import '../../ui/bug_grade.dart';
import 'dex_screen.dart';
import 'grade_panel.dart';
import 'hatch_reveal.dart';
import 'passive_panel.dart';
import '../../ui/colors.dart';

const _honey = kHoney;

/// 채집함 **보기 거르기**(2026-10-14 사장님 확정) — 보이는 목록만 좁힌다. 세이브에는 넣지 않는다(화면 설정).
enum StorageViewStage { all, egg, adult, other }

class StorageViewFilter {
  const StorageViewFilter({
    this.stage = StorageViewStage.all,
    this.minGrade,
    this.speciesId,
    this.passiveKey,
    this.role,
  });

  final StorageViewStage stage;

  /// 이 등급 **이상**만(null = 전체). 개체 등급이 켜지면 개체 등급, 꺼지면 종 등급(`shownGrade`).
  final Grade? minGrade;

  /// 이 종만(null = 전체).
  final String? speciesId;

  /// 이 펫 패시브 종류만(`UpgradeKind.key`, null = 전체) — 값은 `passiveOf` 로 낸다(1.0.21).
  final String? passiveKey;

  /// 이 결투 역할(종의 `duelRole`)만(null = 전체, 1.0.21).
  final DuelRole? role;

  bool get isActive =>
      stage != StorageViewStage.all ||
      minGrade != null ||
      speciesId != null ||
      passiveKey != null ||
      role != null;

  StorageViewFilter copyWith({
    StorageViewStage? stage,
    Grade? Function()? minGrade,
    String? Function()? speciesId,
    String? Function()? passiveKey,
    DuelRole? Function()? role,
  }) => StorageViewFilter(
    stage: stage ?? this.stage,
    minGrade: minGrade == null ? this.minGrade : minGrade(),
    speciesId: speciesId == null ? this.speciesId : speciesId(),
    passiveKey: passiveKey == null ? this.passiveKey : passiveKey(),
    role: role == null ? this.role : role(),
  );

  bool accepts(
    LifeStage st,
    Grade grade,
    String species, {
    String? passive,
    DuelRole? duelRole,
  }) {
    final stageOk = switch (stage) {
      StorageViewStage.all => true,
      StorageViewStage.egg => st == LifeStage.egg,
      StorageViewStage.adult => st == LifeStage.adult,
      StorageViewStage.other => st != LifeStage.egg && st != LifeStage.adult,
    };
    if (!stageOk) return false;
    if (minGrade != null && grade.index < minGrade!.index) return false;
    if (speciesId != null && species != speciesId) return false;
    if (passiveKey != null && passive != passiveKey) return false;
    if (role != null && duelRole != role) return false;
    return true;
  }

  /// [bug] 가 이 조건에 맞는가 — 그리드·보이는 수가 같은 판정을 쓴다.
  bool acceptsBug(GameData data, IndividualBug bug, LifeStage st) {
    final sp = data.species(bug.speciesId);
    return accepts(
      st,
      shownGrade(data, bug, sp),
      bug.speciesId,
      passive: passiveKey == null ? null : storagePassiveKeyOf(data, bug),
      duelRole: sp.duelRole,
    );
  }
}

/// 곤충의 펫 패시브 종류(`UpgradeKind.key`) — 화면·합산과 같은 `passiveOf`. 설정이 없으면 종 패시브.
String? storagePassiveKeyOf(GameData data, IndividualBug bug) {
  final sp = data.species(bug.speciesId);
  final cfg = data.petConfig;
  return cfg == null ? sp.passive?.statKey : passiveOf(bug, sp, cfg)?.statKey;
}

/// 앱을 켜 둔 동안 유지되는 보기 조건(자동 합성·분해 필터와 같은 방식 — 세이브 밖).
class StorageViewFilterNotifier extends Notifier<StorageViewFilter> {
  @override
  StorageViewFilter build() => const StorageViewFilter();

  void set(StorageViewFilter next) => state = next;
}

final storageViewFilterProvider =
    NotifierProvider<StorageViewFilterNotifier, StorageViewFilter>(
      StorageViewFilterNotifier.new,
    );

/// 채집함: 상단 장착 3슬롯 + 아이콘 그리드(단계·티어순) + 탭 시 상세 팝업.
class StorageScreen extends ConsumerWidget {
  const StorageScreen({super.key, required this.save});

  final SaveGame save;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final data = ref.watch(gameDataProvider).requireValue;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.storageTitle),
        actions: [
          // 도감 — 채집함은 '지금 가진 것', 도감은 '지금까지 잡은 것'이라
          // 같은 화면 계열에 둔다(탭을 하나 더 늘리면 하단바가 6개가 된다).
          // 애셋(ui/dex.webp)이 들어오면 자동으로 그림으로 바뀐다.
          IconButton(
            tooltip: l.dexTitle,
            icon: gameImage(
              'assets/images/ui/dex.webp',
              width: 26,
              height: 26,
              fallback: const Icon(Icons.menu_book_rounded),
            ),
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => const DexScreen())),
          ),
        ],
      ),
      body: Column(
        children: [
          // 재료는 **칸 수 바보다 위**에 둔다 — 강화·제작에 쓸 재고를 가장 먼저
          // 확인하는 정보라 화면 중간에 있으면 눈에 안 들어온다.
          _materialsStrip(context, l, save),
          _capacityBar(context, ref, data, l, save),
          _equipStrip(context, ref, data, l, save),
          // 정리 도구 — 장착 펫 **바로 아래**. 왼쪽은 무엇을 받을지(필터),
          // 오른쪽은 이미 가진 것을 어떻게 정리할지(합성·분해)로 나눈다.
          _toolBar(context, ref, data, l, save),
          const Divider(height: 1, color: Color(0x22FFFFFF)),
          // 보기 거르기 — 보이는 목록만 좁힌다(세이브는 그대로).
          if (save.bugs.isNotEmpty) _viewFilterBar(context, ref, data, l, save),
          Expanded(child: SafeGrid(child: _grid(context, ref, data, l, save))),
          _breedingBar(context, ref, data, l, save),
          _incubatorBar(context, ref, data, l, save),
        ],
      ),
    );
  }

  /// 채집함 칸 수 바: 사용량 게이지 + 젤리 확장 버튼.
  ///
  /// 가득 차면 새 곤충이 들어오지 않으므로(획득 차단) 상태를 눈에 띄게 보여준다.
  Widget _capacityBar(
    BuildContext context,
    WidgetRef ref,
    GameData data,
    AppLocalizations l,
    SaveGame save,
  ) {
    final cfg = data.petConfig;
    if (cfg == null) return const SizedBox.shrink();
    final used = save.bugs.length;
    final cap = save.storageCapacity;
    final full = save.storageFull;
    final atMax = cap >= cfg.storageSlotsMax;
    // ⚠️ 확장은 살수록 비싸진다(2026-08-18). UI 가 정액을 보여주면 실제
    // 차감액과 어긋나 "가격이 다르다"가 된다.
    final expandCost = cfg.storageExpandCost(cap);

    return Container(
      color: const Color(0xFF15200D),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        full
                            ? l.storageFullBanner
                            : l.storageCapacityLabel(used, cap),
                        style: TextStyle(
                          color: full
                              ? const Color(0xFFFF8A65)
                              : const Color(0xDDFFFFFF),
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                          height: 1.25,
                        ),
                      ),
                    ),
                    // 가득 찼을 때도 몇 칸인지 바로 보이게 — 안내 문구만 있으면
                    // "얼마나 늘려야 하나"를 알 수 없다.
                    const SizedBox(width: 8),
                    Text(
                      l.storageCapacityCount(used, cap),
                      style: TextStyle(
                        color: full
                            ? const Color(0xFFFF8A65)
                            : const Color(0xDDFFFFFF),
                        fontWeight: FontWeight.w900,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: cap <= 0 ? 0 : (used / cap).clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: const Color(0x33FFFFFF),
                    valueColor: AlwaysStoppedAnimation(
                      full ? const Color(0xFFFF8A65) : _honey,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (atMax)
            Text(
              l.storageExpandMaxed,
              style: const TextStyle(color: Color(0x88FFFFFF), fontSize: 11.5),
            )
          else
            FilledButton.tonalIcon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF3E7D4F),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0x553E7D4F),
                disabledForegroundColor: const Color(0x99FFFFFF),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                minimumSize: const Size(0, 40),
              ),
              onPressed: () async {
                // 확인부터 — 모자라면 확인 창이 상점 안내로 바뀐다.
                if (!await confirmJellySpend(
                  context,
                  title: l.storageExpandTitle,
                  body: l.storageExpandConfirm(
                    expandCost,
                    cfg.storageExpandAmount,
                  ),
                  jelly: expandCost,
                  actionLabel: l.jellyActExpand,
                )) {
                  return;
                }
                if (!context.mounted) return;
                final ok = await ref
                    .read(saveControllerProvider.notifier)
                    .expandStorage();
                if (ok && context.mounted) {
                  _snack(context, l.storageExpandedSnack);
                }
              },
              // 가로 아이콘+글씨는 폭이 모자라 글씨가 잘려 아이콘만 보였다.
              icon: const SizedBox.shrink(),
              label: Text(
                l.storageExpand(cfg.storageExpandAmount, expandCost),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 12.5,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 정리 도구 줄 — 왼쪽 **필터**(무엇을 받을지) / 오른쪽 **자동 합성·자동 분해**
  /// (이미 가진 것을 어떻게 정리할지). 셋 다 채집함 칸을 다루는 도구라
  /// 한 줄에 모으고, 성격만 좌우로 갈라 둔다.
  Widget _toolBar(
    BuildContext context,
    WidgetRef ref,
    GameData data,
    AppLocalizations l,
    SaveGame save,
  ) {
    final min = save.bugFilterMinGrade;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Row(
        children: [
          // 이름이 길어져(종 희귀도) 좁은 폰·영어에서 오른쪽 버튼과 부딪히지 않게 남는 폭에 맞춰 줄인다.
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: _toolButton(
                  // 이 필터는 **종 희귀도**를 본다(개체 등급이 아니다 — 2026-10-14 사장님 확정 이름).
                  label: l.rarityFilterButton,
                  // 지금 기준을 버튼에 달아 둔다 — 열어보지 않아도 무엇을 받는지 보인다.
                  badge: _rarityChipLabel(l, min),
                  badgeColor: min == Grade.common
                      ? const Color(0x66FFFFFF)
                      : gradeColor(min),
                  asset: 'assets/images/ui/icon/filter_tile.webp',
                  fallbackIcon: Icons.filter_alt_outlined,
                  onTap: () => _showBugFilter(context, ref, l),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // 개체 등급이 켜지면 합성(같은 종 3마리 → +1)은 등급 올리기로 바뀐다 — 그 자리에 정수 보관함.
          if (individualGradeOn(data))
            _toolButton(
              label: l.igVaultButton,
              asset: 'assets/images/ui/icon/essence.webp',
              fallbackIcon: Icons.blur_on_rounded,
              onTap: () => showEssenceVault(context, ref, data),
            )
          else
            _toolButton(
              label: l.autoSynthTitle,
              asset: 'assets/images/ui/auto_synth.webp',
              fallbackIcon: Icons.auto_awesome_motion_outlined,
              onTap: () => _runAutoSynth(context, ref, data, l),
            ),
          const SizedBox(width: 8),
          _toolButton(
            label: l.autoReleaseTitle,
            asset: 'assets/images/ui/auto_release.webp',
            fallbackIcon: Icons.recycling_rounded,
            onTap: () => _runAutoRelease(context, ref, data, l),
          ),
        ],
      ),
    );
  }

  /// 도구 버튼 한 개. [asset] 이 있으면 그림, 없으면 [fallbackIcon] 으로 그린다.
  Widget _toolButton({
    required String label,
    required IconData fallbackIcon,
    required VoidCallback onTap,
    String? asset,
    String? badge,
    Color? badgeColor,
  }) {
    // 아이콘 그림은 **자체 타일 프레임**을 갖고 있다(art_prompts §4c).
    // 그 위에 버튼 배경까지 그리면 테두리가 두 겹이 되므로, 그림이 있는
    // 버튼은 배경을 지우고 그림을 키워 그림 자체가 버튼이 되게 한다.
    final hasArt = asset != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: hasArt ? 4 : 10,
          vertical: hasArt ? 0 : 6,
        ),
        decoration: hasArt
            ? null
            : BoxDecoration(
                color: const Color(0x18FFFFFF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0x33FFFFFF)),
              ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (asset != null)
              gameImage(
                asset,
                width: 30,
                height: 30,
                fallback: Icon(fallbackIcon, size: 17, color: _honey),
              )
            else
              Icon(fallbackIcon, size: 17, color: _honey),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xDDFFFFFF),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: (badgeColor ?? _honey).withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: badgeColor ?? _honey),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 받을 **종 희귀도** 고르기 — 기준 미만 종은 채집함에 **안 들어오고 재료로 환산**된다(§2.1).
  /// 칸이 50~100개뿐이라 필터가 없으면 후반엔 일반 곤충이 칸을 채우고,
  /// 정작 쓸 개체가 드롭 차단에 걸린다.
  /// ⚠️ 비교 대상은 종 희귀도(`species.grade`)다 — 개체 등급으로 읽히지 않게 이름에 "종"을 붙인다(2026-10-14).
  Future<void> _showBugFilter(
    BuildContext ctx,
    WidgetRef ref,
    AppLocalizations l,
  ) => showGameDialog<void>(
    ctx,
    title: l.igFilterTitle,
    iconWidget: dialogIcon('filter'),
    content: Consumer(
      builder: (context, r, _) {
        final save = r.watch(saveControllerProvider).requireValue;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final g in Grade.values)
                  _gradeChip(
                    label: _rarityChipLabel(l, g),
                    color: gradeColor(g),
                    selected: save.bugFilterMinGrade == g,
                    onTap: () => r
                        .read(saveControllerProvider.notifier)
                        .setBugFilterMinGrade(g),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              save.bugFilterMinGrade == Grade.common
                  ? l.rarityFilterAll
                  : l.igFilterSnack(gradeLabel(l, save.bugFilterMinGrade)),
              style: const TextStyle(
                color: Color(0xCCFFFFFF),
                fontSize: 11.5,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l.rarityFilterHint,
              style: const TextStyle(
                color: Color(0x99FFFFFF),
                fontSize: 11,
                height: 1.35,
              ),
            ),
          ],
        );
      },
    ),
    actions: [gameDialogButton(l.actionClose, () => Navigator.pop(ctx))],
  );

  /// 받을 종 희귀도 칩 이름 — 일반 = 필터 없음(모든 종), 전설 = 그 종만, 나머지 = "~ 종 이상".
  String _rarityChipLabel(AppLocalizations l, Grade g) => switch (g) {
    Grade.common => l.rarityFilterAll,
    Grade.legendary => l.rarityFilterOnly(gradeLabel(l, g)),
    _ => l.rarityFilterAtLeast(gradeLabel(l, g)),
  };

  /// 등급 칩 하나(선택 표시 포함).
  Widget _gradeChip({
    required String label,
    required Color color,
    required bool selected,
    required VoidCallback onTap,
  }) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: selected
            ? color.withValues(alpha: 0.45)
            : const Color(0x18FFFFFF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: selected ? color : const Color(0x33FFFFFF)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : const Color(0x99FFFFFF),
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
  );

  /// 자동 합성 실행: 대상 조건을 고르고, **예상 결과를 보여준 뒤** 확인받는다.
  ///
  /// 곤충이 사라지는 동작이라 되돌릴 수 없다 — 무엇이 없어지는지 모르고
  /// 누르게 두면 안 된다.
  Future<void> _runAutoSynth(
    BuildContext ctx,
    WidgetRef ref,
    GameData data,
    AppLocalizations l,
  ) async {
    final ctrl = ref.read(saveControllerProvider.notifier);
    final fodder = data.petConfig?.synthFodder ?? 3;
    final ok = await showGameDialog<bool>(
      ctx,
      title: l.autoSynthTitle,
      iconWidget: dialogAsset('assets/images/ui/auto_synth.webp'),
      content: _cleanupPanel(
        ctx: ctx,
        data: data,
        l: l,
        filterProvider: autoSynthFilterProvider,
        hint: l.autoSynthHint(fodder),
        preview: (f) async {
          final p = await ctrl.autoSynthesize(dryRun: true, filter: f);
          // 아직 실행 전이므로 **예정형**으로 적는다 — 완료 문구를 그대로 쓰면
          // 이미 합성된 줄 알고 창을 닫는다.
          return (
            summary: p.fused == 0 ? null : l.autoSynthPreview(p.fused, p.used),
            consumed: p.consumed,
          );
        },
      ),
      actions: [
        gameDialogButton(l.actionClose, () => Navigator.pop(ctx, false)),
        gameDialogButton(l.autoSynthRun, () => Navigator.pop(ctx, true)),
      ],
    );
    if (ok != true) return;
    final done = await ctrl.autoSynthesize(
      filter: ref.read(autoSynthFilterProvider),
    );
    if (!ctx.mounted) return;
    _snack(
      ctx,
      done.fused == 0
          ? l.autoSynthNone
          : l.autoSynthDone(done.fused, done.used),
    );
  }

  /// 자동 분해 실행 — 조건에 맞는 곤충을 한 번에 재료로 바꾼다.
  ///
  /// ⚠️ 젤리는 나오지 않는다(§2.6, 자동으로 굴러가는 통로에 젤리 금지).
  /// 4성↑ 을 대상에 넣으면 손해라, 그 사실을 패널에 적어 둔다.
  Future<void> _runAutoRelease(
    BuildContext ctx,
    WidgetRef ref,
    GameData data,
    AppLocalizations l,
  ) async {
    final ctrl = ref.read(saveControllerProvider.notifier);
    final gradeOn = individualGradeOn(data);
    // 개체 등급이 켜지면 같은 대상을 **정수로** 바꾸는 버튼이 하나 더 붙는다(분해 = 재료, 정수 = 등급 올리기).
    final ok = await showGameDialog<Object>(
      ctx,
      title: l.autoReleaseTitle,
      iconWidget: dialogAsset('assets/images/ui/auto_release.webp'),
      content: _cleanupPanel(
        ctx: ctx,
        data: data,
        l: l,
        filterProvider: autoReleaseFilterProvider,
        hint: l.autoReleaseHint,
        preview: (f) async {
          final p = await ctrl.autoRelease(dryRun: true, filter: f);
          return (
            summary: p.released == 0
                ? null
                : l.autoReleasePreview(p.released, p.materials),
            consumed: p.consumed,
          );
        },
      ),
      actions: [
        gameDialogButton(l.actionClose, () => Navigator.pop(ctx, false)),
        if (gradeOn)
          gameDialogButton(
            l.igBulkEssence,
            () => Navigator.pop(ctx, 'essence'),
            primary: false,
          ),
        gameDialogButton(l.autoReleaseRun, () => Navigator.pop(ctx, true)),
      ],
    );
    if (ok == 'essence') {
      final p = await ctrl.autoRelease(
        dryRun: true,
        filter: ref.read(autoReleaseFilterProvider),
      );
      if (!ctx.mounted) return;
      await convertBulkToEssence(ctx, ref, data, p.consumed);
      return;
    }
    if (ok != true) return;
    final done = await ctrl.autoRelease(
      filter: ref.read(autoReleaseFilterProvider),
    );
    if (!ctx.mounted) return;
    _snack(
      ctx,
      done.released == 0
          ? l.autoReleaseNone
          : l.autoReleaseDone(done.released, done.materials),
    );
  }

  /// 자동 합성·자동 분해가 함께 쓰는 패널 — 대상 조건 + **사라지는 것 미리보기**.
  ///
  /// 조건을 바꿀 때마다 다시 계산한다. 총 마리 수만 보여주면 "몇 마리"는 알아도
  /// "무엇이" 없어지는지는 모른다 — 그래서 종 이름까지 적는다.
  Widget _cleanupPanel({
    required BuildContext ctx,
    required GameData data,
    required AppLocalizations l,
    required BugAutoFilterProvider filterProvider,
    required String hint,
    required Future<({String? summary, List<String> consumed})> Function(
      BugAutoFilter filter,
    )
    preview,
  }) => Consumer(
    builder: (context, r, _) {
      final filter = r.watch(filterProvider);
      final save = r.watch(saveControllerProvider).requireValue;
      final locale = Localizations.localeOf(context).languageCode;
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hint,
            style: const TextStyle(
              color: Color(0xDDFFFFFF),
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            individualGradeOn(data) ? l.igAutoFilterRarity : l.autoFilterGrades,
            style: const TextStyle(
              color: _honey,
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final g in Grade.values)
                _gradeChip(
                  label: gradeLabel(l, g),
                  color: gradeColor(g),
                  selected: filter.grades.contains(g),
                  onTap: () =>
                      r.read(filterProvider.notifier).set(filter.toggled(g)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            individualGradeOn(data)
                ? l.igAutoFilterGrade(
                    gradeLabel(l, gradeOfPotential(filter.maxPotential)),
                  )
                : l.autoFilterPotential(filter.maxPotential),
            style: const TextStyle(
              color: _honey,
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            children: [
              for (var p = 1; p <= 5; p++)
                _gradeChip(
                  label: individualGradeOn(data)
                      ? gradeLabel(l, gradeOfPotential(p))
                      : '$p★',
                  color: individualGradeOn(data)
                      ? gradeColor(gradeOfPotential(p))
                      : _honey,
                  selected: filter.maxPotential == p,
                  onTap: () => r
                      .read(filterProvider.notifier)
                      .set(filter.copyWith(maxPotential: p)),
                ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1, color: Color(0x22FFFFFF)),
          ),
          if (filter.grades.isEmpty)
            Text(
              l.autoFilterEmpty,
              style: const TextStyle(color: Color(0xFFFF8A65), fontSize: 12),
            )
          else
            FutureBuilder<({String? summary, List<String> consumed})>(
              // 필터가 바뀌면 다시 계산한다(키가 없으면 옛 결과가 남는다).
              key: ValueKey('${filter.grades.length}_${filter.maxPotential}'),
              future: preview(filter),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const SizedBox(
                    height: 40,
                    child: Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  );
                }
                final res = snap.data!;
                if (res.summary == null) {
                  return Text(
                    l.autoReleaseNone,
                    style: const TextStyle(
                      color: Color(0x99FFFFFF),
                      fontSize: 12,
                    ),
                  );
                }
                // 사라지는 개체를 종별로 묶어 이름과 마리 수로 보여준다.
                final byId = {for (final b in save.bugs) b.id: b};
                final counts = <String, int>{};
                for (final id in res.consumed) {
                  final sp = byId[id]?.speciesId;
                  if (sp == null) continue;
                  counts[sp] = (counts[sp] ?? 0) + 1;
                }
                final lines = counts.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value));
                const shown = 5;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      res.summary!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l.autoPreviewTitle,
                      style: const TextStyle(
                        color: Color(0x99FFFFFF),
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 4),
                    for (final e in lines.take(shown))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          l.autoPreviewLine(
                            data.speciesById[e.key]?.name.resolve(locale) ??
                                e.key,
                            e.value,
                          ),
                          style: const TextStyle(
                            color: Color(0xDDFFFFFF),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    if (lines.length > shown)
                      Text(
                        l.autoPreviewMore(lines.length - shown),
                        style: const TextStyle(
                          color: Color(0x99FFFFFF),
                          fontSize: 11.5,
                        ),
                      ),
                  ],
                );
              },
            ),
        ],
      );
    },
  );

  /// 브리딩 진입 바(슬롯 수·완료 알림 점).
  Widget _breedingBar(
    BuildContext context,
    WidgetRef ref,
    GameData data,
    AppLocalizations l,
    SaveGame save,
  ) {
    if (data.petConfig == null) return const SizedBox.shrink();
    final now = ref.read(clockProvider).now().toUtc();
    final used = save.breeding.length;
    final cap = save.breedingCapacity;
    final ready = save.breeding.where((b) => !now.isBefore(b.endsAt)).length;
    return Material(
      color: const Color(0xFF15200D),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: SizedBox(
          height: 46,
          child: FilledButton(
            onPressed: () => _showBreeding(context, ref, data),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF7E57C2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                gameImage(
                  'assets/images/ui/icon/breeding.webp',
                  width: 24,
                  height: 24,
                  fallback: const Text('🧬', style: TextStyle(fontSize: 18)),
                ),
                const SizedBox(width: 8),
                Text(
                  l.breedingTitle,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x33000000),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    l.breedingSlotsLabel(used, cap),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (ready > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    width: 9,
                    height: 9,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF5252),
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 채집함 하단(탭바 바로 위) 부화기 진입 버튼. 부화 완료 있으면 알림 점.
  /// 특정 성별의 성충 목록(브리딩 후보).
  List<IndividualBug> _adultsBySex(
    SaveGame save,
    GameData data,
    DateTime now,
    Sex sex,
  ) {
    final cfg = data.petConfig;
    final list = save.bugs.where((b) {
      if (b.sex != sex) return false;
      final st = cfg == null
          ? b.stage
          : effectiveStage(b.stage, b.stageSince, now, cfg);
      return st == LifeStage.adult;
    }).toList();
    // 좋은 개체가 위로 오게 정렬한다 — 목록이 길어지면 등급이 섞여 있는 것만으로
    // 짝을 고르는 게 일이 된다. 쿨다운 중인 개체는 지금 못 쓰므로 맨 뒤로.
    list.sort((a, b) {
      final ac = save.breedOnCooldown(a.id, now) ? 1 : 0;
      final bc = save.breedOnCooldown(b.id, now) ? 1 : 0;
      if (ac != bc) return ac - bc;
      // 켜지면 개체 등급 → 종 희귀도, 꺼지면 종 등급 → 포텐셜(`bugGradeSortKey`).
      final g = bugGradeSortKey(data, b).compareTo(bugGradeSortKey(data, a));
      if (g != 0) return g;
      return b.sizeMm.compareTo(a.sizeMm);
    });
    return list;
  }

  /// 브리딩 시트: 진행 슬롯(산란중/수령) + 슬롯 확장 + 새 브리딩(짝 선택).
  void _showBreeding(BuildContext context, WidgetRef ref, GameData data) {
    final cfg = data.petConfig;
    if (cfg == null) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xF2141F0E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Consumer(
          builder: (ctx, r, _) {
            final l = AppLocalizations.of(ctx);
            final save = r.watch(saveControllerProvider).requireValue;
            final now = r.read(clockProvider).now().toUtc();
            final locale = Localizations.localeOf(ctx).languageCode;
            final slots = [...save.breeding]
              ..sort((a, b) => a.endsAt.compareTo(b.endsAt));
            final canAdd = save.breeding.length < save.breedingCapacity;
            final canExpand = save.breedingCapacity < cfg.breedingSlotsMax;
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      gameImage(
                        'assets/images/ui/icon/breeding.webp',
                        width: 26,
                        height: 26,
                        fallback: const Text(
                          '🧬',
                          style: TextStyle(fontSize: 20),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        l.breedingTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        l.breedingSlotsLabel(
                          save.breeding.length,
                          save.breedingCapacity,
                        ),
                        style: const TextStyle(
                          color: _honey,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  for (final slot in slots) ...[
                    _breedRow(ctx, r, cfg, data, slot, now, locale),
                    const SizedBox(height: 8),
                  ],
                  if (canAdd)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _breedPickPair(ctx, r, data),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: Text(l.breedingNew),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFCBB6F0),
                          side: const BorderSide(color: Color(0x557E57C2)),
                          minimumSize: const Size(0, 44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  if (canExpand) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () async {
                          final cost = cfg.breedingExpandCost(
                            save.breedingCapacity,
                          );
                          if (!await confirmJellySpend(
                            ctx,
                            title: l.breedingExpandTitle,
                            body: l.slotExpandConfirm(cost),
                            jelly: cost,
                            actionLabel: l.jellyActExpand,
                          )) {
                            return;
                          }
                          if (!ctx.mounted) return;
                          r
                              .read(saveControllerProvider.notifier)
                              .expandBreedingSlots();
                        },
                        icon: const Icon(Icons.add_box_rounded, size: 18),
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            jellyIcon(size: 14),
                            const SizedBox(width: 3),
                            Text(
                              '${cfg.breedingExpandCost(save.breedingCapacity)}',
                            ),
                          ],
                        ),
                        style: _pillStyle(const Color(0xFF7E57C2)),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _breedRow(
    BuildContext ctx,
    WidgetRef r,
    PetConfig cfg,
    GameData data,
    BreedingSlot slot,
    DateTime now,
    String locale,
  ) {
    final l = AppLocalizations.of(ctx);
    final sp = data.speciesById[slot.speciesId];
    if (sp == null) return const SizedBox.shrink();
    final ready = !now.isBefore(slot.endsAt);
    final remaining = slot.endsAt.difference(now);
    final total =
        data.iapConfig?.skinnedBreedSeconds(
          cfg.breedingDuration(sp.grade),
          save.ownedSkins,
          sp.id,
        ) ??
        cfg.breedingDuration(sp.grade);
    final fill = ready
        ? 1.0
        : (total > 0 ? (1 - remaining.inSeconds / total).clamp(0.0, 1.0) : 1.0);
    final jelly = cfg.breedingJelly(remaining);
    final saveNow = r.watch(saveControllerProvider).requireValue;
    final storageFull = saveNow.storageFull;
    return _sectionBox(
      child: Row(
        children: [
          bugStageImage(
            sp.id,
            LifeStage.adult,
            size: 34,
            fallback: bugAvatar(sp, size: 30),
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
                        sp.name.resolve(locale),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _rowTitle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    gameImage(
                      'assets/images/ui/icon/breeding.webp',
                      width: 18,
                      height: 18,
                      fallback: const Text('🧬🥚', style: _rowTitle),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: fill,
                    minHeight: 6,
                    backgroundColor: const Color(0x33000000),
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF7E57C2)),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  ready ? l.breedingInProgress : _remainLabel(l, remaining),
                  style: _rowSub,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ready
              ? FilledButton(
                  onPressed: () async {
                    // 채집함이 가득 차면 수령이 거부된다 — 이유를 알려준다.
                    if (storageFull) {
                      AudioService.instance.sfxError();
                      return _snack(ctx, l.storageFullSnack);
                    }
                    final ok = await r
                        .read(saveControllerProvider.notifier)
                        .collectBreeding(slot.id);
                    if (!ok) return;
                    AudioService.instance.sfxBreed();
                    if (ctx.mounted) _snack(ctx, l.breedingGotEgg);
                  },
                  style: _pillStyle(const Color(0xFF3E7D4F)),
                  child: _pillText(l.incubatorCollect),
                )
              : FilledButton(
                  onPressed: () async {
                    // 채집함이 가득이면 젤리를 묻기 전에 막는다 — 확인받고 거절하면 헛걸음이다.
                    if (storageFull) {
                      AudioService.instance.sfxError();
                      return _snack(ctx, l.storageFullSnack);
                    }
                    if (!await confirmJellySpend(
                      ctx,
                      title: l.breedingInstantTitle,
                      body: l.breedingInstantConfirm(jelly),
                      jelly: jelly,
                    )) {
                      return;
                    }
                    if (!ctx.mounted) return;
                    final ok = await r
                        .read(saveControllerProvider.notifier)
                        .collectBreeding(slot.id, viaJelly: true);
                    if (!ok) return;
                    AudioService.instance.sfxBreed();
                    if (ctx.mounted) _snack(ctx, l.breedingGotEgg);
                  },
                  style: _pillStyle(const Color(0xFF7E57C2)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      jellyIcon(size: 13),
                      const SizedBox(width: 3),
                      Text('$jelly'),
                    ],
                  ),
                ),
        ],
      ),
    );
  }

  /// 짝 선택 시트(단일): 엄마(♀) 선택 → 같은 종 아빠(♂) 선택 → 산란 시작.
  void _breedPickPair(BuildContext context, WidgetRef ref, GameData data) {
    IndividualBug? mother;
    showModalBottomSheet<void>(
      context: context,
      // 기본 높이 제한(화면 9/16)에 그리드가 걸려 RenderFlex 오버플로우가 나던
      // 문제 방지 — 시트가 내용 높이만큼 커지도록 한다.
      isScrollControlled: true,
      backgroundColor: const Color(0xF2141F0E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Consumer(
          builder: (ctx, r, _) => StatefulBuilder(
            builder: (ctx, setSheet) {
              final l = AppLocalizations.of(ctx);
              final save = r.watch(saveControllerProvider).requireValue;
              final now = r.read(clockProvider).now().toUtc();
              final locale = Localizations.localeOf(ctx).languageCode;
              final picking = mother == null;
              final list = picking
                  ? _adultsBySex(save, data, now, Sex.female)
                  : _adultsBySex(
                      save,
                      data,
                      now,
                      Sex.male,
                    ).where((b) => b.speciesId == mother!.speciesId).toList();
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  // stretch: 타일 Wrap 영역이 전체 너비를 차지해야 가운데 정렬이 작동.
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        if (!picking)
                          GestureDetector(
                            onTap: () => setSheet(() => mother = null),
                            child: const Padding(
                              padding: EdgeInsets.only(right: 8),
                              child: Icon(
                                Icons.arrow_back_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        Expanded(
                          child: Text(
                            picking
                                ? l.breedingPickMother
                                : l.breedingPickFather,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // 무엇이 상속되는지 여기서 말하지 않으면, 짝짓기가 그냥
                    // "알 뽑기"로 보인다 — 개편의 요점이 안 전달된다.
                    Text(
                      l.breedInheritHint,
                      style: const TextStyle(
                        color: Color(0x99FFFFFF),
                        fontSize: 11,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (list.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Text(
                          picking ? l.breedingNoFemales : l.breedingNoMate,
                          style: const TextStyle(color: Color(0x99FFFFFF)),
                        ),
                      )
                    else
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 380),
                        child: GridView.builder(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                                childAspectRatio: 0.82,
                              ),
                          itemCount: list.length,
                          itemBuilder: (c, i) {
                            final b = list[i];
                            final until = save.breedCooldowns[b.id];
                            return _breedPickTile(
                              ctx,
                              data,
                              locale,
                              b,
                              cooldown: until == null || !now.isBefore(until)
                                  ? null
                                  : until.difference(now),
                              () async {
                                // 상세를 보여 주고 짝짓기를 확인받는다(2026-09-29 사장님 요청).
                                final go = await _confirmBug(
                                  ctx,
                                  data,
                                  locale,
                                  b,
                                  LifeStage.adult,
                                  confirm: l.breedingConfirm,
                                  extra: picking
                                      ? null
                                      : l.breedingTimeInfo(
                                          remainLabel(
                                            l,
                                            Duration(
                                              seconds: data.petConfig!
                                                  .breedingDuration(
                                                    data
                                                        .species(b.speciesId)
                                                        .grade,
                                                  ),
                                            ),
                                          ),
                                        ),
                                );
                                if (!go) return;
                                if (picking) {
                                  setSheet(() => mother = b);
                                } else {
                                  final seed = math.Random().nextInt(1 << 31);
                                  final ok = await r
                                      .read(saveControllerProvider.notifier)
                                      .startBreeding(mother!.id, b.id, seed);
                                  if (ctx.mounted && ok) Navigator.pop(ctx);
                                }
                              },
                            );
                          },
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _breedPickTile(
    BuildContext ctx,
    GameData data,
    String locale,
    IndividualBug bug,
    VoidCallback onTap, {
    Duration? cooldown,
  }) {
    final sp = data.species(bug.speciesId);
    final waiting = cooldown != null && cooldown > Duration.zero;
    return GestureDetector(
      // 쿨다운 중이면 눌러도 실패하므로 아예 막고, 왜 못 쓰는지 보여준다.
      onTap: waiting ? null : onTap,
      child: Opacity(
        opacity: waiting ? 0.45 : 1,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0x22000000),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: gradeColor(
                shownGrade(data, bug, sp),
              ).withValues(alpha: 0.7),
              width: 1.4,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 쿨다운 표시는 **그림 위에 겹친다.** 줄을 하나 더 쌓으면
              // 타일 비율(0.82)이 고정이라 세로가 넘친다(실측 10px).
              Stack(
                alignment: Alignment.bottomCenter,
                clipBehavior: Clip.none,
                children: [
                  bugStageImage(
                    bug.speciesId,
                    LifeStage.adult,
                    size: 60,
                    fallback: bugAvatar(sp, size: 50),
                  ),
                  // 켜지면 아래 줄 이름표가 이미 개체 등급이다(두 번 보이지 않게).
                  if (!individualGradeOn(data))
                    Positioned(
                      left: -6,
                      top: -4,
                      child: _eggBadge(
                        gradeLabel(
                          AppLocalizations.of(ctx),
                          shownGrade(data, bug, sp),
                        ),
                        gradeColor(shownGrade(data, bug, sp)),
                      ),
                    ),
                  if (waiting)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xCC1A1005),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0x88FFB0A0)),
                      ),
                      child: Text(
                        AppLocalizations.of(ctx).breedCooldownLeft(
                          remainLabel(AppLocalizations.of(ctx), cooldown),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFFFB0A0),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                sp.name.resolve(locale),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  sexArt(bug.sex, size: 12),
                  const SizedBox(width: 3),
                  _potentialMark(ctx, data, bug.potential, 9),
                ],
              ),
              // 오행·특성은 이제 **상속되는 값**이라(§2.5) 짝을 고르는 기준이다.
              // 여기 안 보이면 보관함을 오가며 확인해야 해서 계통 육성이 안 된다.
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  elementIcon(bug.element, size: 12),
                  if (!bug.trait.isNone) ...[
                    const SizedBox(width: 3),
                    traitIcon(bug.trait, size: 12),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _incubatorBar(
    BuildContext context,
    WidgetRef ref,
    GameData data,
    AppLocalizations l,
    SaveGame save,
  ) {
    if (data.petConfig == null) return const SizedBox.shrink();
    final now = ref.read(clockProvider).now().toUtc();
    final used = save.incubating.length;
    final cap = save.incubatorCapacity;
    final ready = save.incubating.values.where((e) => !now.isBefore(e)).length;
    return Material(
      color: const Color(0xFF15200D),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        child: SizedBox(
          height: 46,
          child: FilledButton(
            onPressed: () => _showIncubator(context, ref, data),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2E6DA4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                gameImage(
                  'assets/images/ui/icon/incubator.webp',
                  width: 24,
                  height: 24,
                  fallback: const Text('🥚', style: TextStyle(fontSize: 18)),
                ),
                const SizedBox(width: 8),
                Text(
                  l.incubatorTitle,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x33000000),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    l.incubatorSlots(used, cap),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (ready > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    width: 9,
                    height: 9,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF5252),
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 부화기 전용 시트: 슬롯(부화 중/빈) + 확장 + 대기 알 넣기.
  void _showIncubator(BuildContext context, WidgetRef ref, GameData data) {
    final cfg = data.petConfig;
    if (cfg == null) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xF2141F0E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Consumer(
          builder: (ctx, r, _) {
            final l = AppLocalizations.of(ctx);
            final save = r.watch(saveControllerProvider).requireValue;
            final now = r.read(clockProvider).now().toUtc();
            final locale = Localizations.localeOf(ctx).languageCode;
            final used = save.incubating.length;
            final cap = save.incubatorCapacity;
            final incing = save.incubating.entries.toList()
              ..sort((a, b) => a.value.compareTo(b.value));

            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      gameImage(
                        'assets/images/ui/icon/incubator.webp',
                        width: 26,
                        height: 26,
                        fallback: const Text(
                          '🥚',
                          style: TextStyle(fontSize: 20),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        l.incubatorTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        l.incubatorSlots(used, cap),
                        style: const TextStyle(
                          color: _honey,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  // 캡슐 슬롯(확장 전엔 1개만 열림).
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (var i = 0; i < cfg.incubatorSlotsMax; i++)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            child: _capsule(
                              ctx,
                              r,
                              data,
                              cfg,
                              save,
                              l,
                              locale,
                              now,
                              slotIndex: i,
                              occupant: (i < cap && i < incing.length)
                                  ? incing[i]
                                  : null,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // 완료가 2개 이상이면 한 번에 — 캡슐을 하나씩 두드리게 하는 건
                  // 확장 슬롯을 팔아 놓고 그만큼 손가락 노동을 파는 셈이다.
                  Builder(
                    builder: (_) {
                      final now2 = r.read(clockProvider).now().toUtc();
                      final doneIds = [
                        for (final e in incing)
                          if (!now2.isBefore(e.value)) e.key,
                      ];
                      if (doneIds.length < 2) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Center(
                          child: FilledButton.icon(
                            onPressed: () async {
                              final got = <String>[];
                              for (final id in doneIds) {
                                if (await r
                                    .read(saveControllerProvider.notifier)
                                    .collectIncubated(id)) {
                                  got.add(id);
                                }
                              }
                              if (got.isEmpty) return;
                              AudioService.instance.sfxHatch();
                              if (ctx.mounted) {
                                _snack(
                                  ctx,
                                  l.incubatorCollectAllDone(got.length),
                                );
                                // 부화 공개 연출(2026-10-14) — 차례로, 모두 건너뛰기 가능.
                                await showHatchReveal(ctx, r, got);
                              }
                            },
                            icon: const Icon(Icons.done_all_rounded, size: 17),
                            label: Text(l.incubatorCollectAll(doneIds.length)),
                            style: FilledButton.styleFrom(
                              backgroundColor: _honey,
                              foregroundColor: kHoneyInk,
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  Center(
                    child: Text(
                      l.incubatorHint,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0x99FFFFFF),
                        fontSize: 11.5,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// 캡슐 1개. 잠김(🔒·확장) / 빈(넣기) / 부화중(액체 차오름) / 완료(수령).
  Widget _capsule(
    BuildContext ctx,
    WidgetRef r,
    GameData data,
    PetConfig cfg,
    SaveGame save,
    AppLocalizations l,
    String locale,
    DateTime now, {
    required int slotIndex,
    required MapEntry<String, DateTime>? occupant,
  }) {
    final ctrl = r.read(saveControllerProvider.notifier);
    final unlocked = slotIndex < save.incubatorCapacity;
    final isNextUnlock = slotIndex == save.incubatorCapacity;

    late final Widget center; // 캡슐 안 콘텐츠(그림 뒤 → 유리로 은은히 비침)
    VoidCallback? onTap;
    double fill = 0;
    var done = false;
    // 부화 진행 중이면 남은 시간·대상 — 시간바와 가속 버튼이 쓴다.
    Duration? hatchRem;
    String? hatchBugId;

    if (!unlocked) {
      // 잠긴 캡슐: 자물쇠 아이콘(코드) + 회색 처리(그림). 다음 슬롯이면 젤리 확장.
      final expCost = cfg.incubatorExpandCost(save.incubatorCapacity);
      final canExp = save.materialCount(MaterialKind.jelly) >= expCost;
      // 자물쇠 **바로 밑**에 값을 붙인다. 예전엔 캡슐 아래쪽(y=0.68)에 따로
      // 떠 있어서 자물쇠와 무관한 표시로 읽혔다(실기 지적 2026-08-19).
      center = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lock_rounded, color: Color(0xCCFFFFFF), size: 26),
          const SizedBox(height: 5),
          // ⚠️ 값이 있든 없든 **같은 높이**를 차지한다. 안 그러면 값이 붙은
          // 캡슐만 Column 이 길어져 자물쇠가 위로 밀리고, 잠긴 캡슐들끼리
          // 자물쇠 높이가 어긋난다(실기 지적 2026-08-19).
          SizedBox(
            height: 16,
            child: isNextUnlock
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      jellyIcon(size: 13),
                      const SizedBox(width: 3),
                      Text(
                        '$expCost',
                        style: TextStyle(
                          color: canExp ? _honey : const Color(0x99FFFFFF),
                          fontWeight: FontWeight.w900,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  )
                : null,
          ),
        ],
      );
      if (isNextUnlock) {
        onTap = () async {
          if (!await confirmJellySpend(
            ctx,
            title: l.incubatorExpandTitle,
            body: l.slotExpandConfirm(expCost),
            jelly: expCost,
            actionLabel: l.jellyActExpand,
          )) {
            return;
          }
          if (!ctx.mounted) return;
          final ok = await ctrl.expandIncubator();
          if (ok && ctx.mounted) _snack(ctx, l.incubatorExpandedSnack);
        };
      }
    } else if (occupant == null) {
      center = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.add_circle_outline,
            color: Color(0xCCEBA52F),
            size: 26,
          ),
          const SizedBox(height: 4),
          Text(
            l.incubatorPlace,
            style: const TextStyle(color: Color(0xDDFFFFFF), fontSize: 11),
          ),
        ],
      );
      onTap = () => _showEggPicker(ctx, r, data);
    } else {
      final bug = _findBug(save, occupant.key);
      final sp = bug == null ? null : data.species(bug.speciesId);
      // 스킨으로 줄어든 시간을 총시간으로 쓴다 — 원래 시간을 쓰면 바가
      // 끝까지 안 찬 채로 부화가 끝난다.
      final total = sp == null
          ? 1
          : (data.iapConfig?.skinnedIncubateSeconds(
                  cfg.incubateDuration(sp.grade),
                  save.ownedSkins,
                  sp.id,
                ) ??
                cfg.incubateDuration(sp.grade));
      final rem = occupant.value.difference(now);
      done = rem <= Duration.zero;
      fill = total > 0 ? (1 - rem.inSeconds / total).clamp(0.0, 1.0) : 1.0;
      if (!done) {
        hatchRem = rem;
        hatchBugId = occupant.key;
      }
      center = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (bug != null)
            bugStageImage(
              bug.speciesId,
              LifeStage.egg,
              size: 46,
              fallback: bugAvatar(sp!, size: 40),
              // 이색 알은 캡슐 안에서도 색이 달라야 한다(채집함 격자와 같은 규칙, 2026-10-14).
              skin: bugView(r.watch(skinOfProvider), bug),
            ),
          const SizedBox(height: 4),
          // ⚠️ 캡슐 폭이 좁아 1시간을 넘으면(`1시간 12분`) 두 줄로 접혔고,
          // `부화 완료!` 도 마찬가지였다(2026-08-30 지적). 자르면 남은 시간의
          // 뜻이 사라지므로(`1시간 1…`) **줄여서** 한 줄에 담는다.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                done ? l.incubatorReady : _remainLabel(l, rem),
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  color: done ? _honey : Colors.white,
                  fontWeight: done ? FontWeight.w900 : FontWeight.w700,
                  fontSize: 10.5,
                  shadows: const [Shadow(color: Colors.black, blurRadius: 3)],
                ),
              ),
            ),
          ),
        ],
      );
      onTap = done
          ? () async {
              final ok = await ctrl.collectIncubated(occupant.key);
              if (!ok) return;
              AudioService.instance.sfxHatch();
              if (ctx.mounted) {
                _snack(
                  ctx,
                  (sp?.isIncompleteMetamorphosis ?? false)
                      ? l.incubatorCollectedNymphSnack
                      : l.incubatorCollectedSnack,
                );
                await showHatchReveal(ctx, r, [occupant.key]);
              }
            }
          // 부화 중 탭 → 광고 보고 시간 당기기. 대기 자체가 이탈 지점이라
          // "기다림을 줄일 수단"을 주는 대신 광고 노출을 얻는다.
          : null; // 가속은 캡슐 아래 버튼이 담당한다.
    }

    const radius = BorderRadius.vertical(
      top: Radius.circular(42),
      bottom: Radius.circular(16),
    );
    // 위: 시간바 / 가운데: 캡슐 / 아래: 가속 버튼 2개.
    // 예전엔 진행도를 캡슐 안 초록 액체로 그려서 "이게 뭔지" 알기 어려웠다.
    // ⚠️ 슬롯 높이를 **못 박는다**. 비었을 때/부화 중/완료의 내용물이 달라
    //    높이가 흔들리면 캡슐이 커졌다 작아졌다 한다.
    return SizedBox(
      height: 24 + 4 + 176 + 6 + 62,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 시간바·버튼 자리는 부화 중이 아니어도 비워서 유지한다.
          //    조건부로 넣고 빼면 부화가 끝나는 순간 칸 높이가 바뀌어 캡슐이
          //    커졌다 작아졌다 한다.
          SizedBox(
            height: 24,
            child: hatchRem == null
                ? null
                : _hatchBar(fill, _remainLabel(l, hatchRem)),
          ),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            // ⚠️ 너비까지 못 박아야 한다. 높이만 고정하면 BoxFit.contain 이
            //    칸 너비에 맞춰 스케일해 슬롯마다 그림 크기가 달라진다.
            child: Center(
              child: SizedBox(
                width: 96,
                height: 176,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (done)
                      Container(
                        margin: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          borderRadius: radius,
                          boxShadow: [
                            BoxShadow(
                              color: _honey.withValues(alpha: 0.5),
                              blurRadius: 18,
                            ),
                          ],
                        ),
                      ),
                    // 콘텐츠(알/넣기/자물쇠) — 캡슐 그림 뒤.
                    Padding(padding: const EdgeInsets.all(10), child: center),
                    // 캡슐 프레임 그림(하나). 잠김이면 회색 처리. 없으면 유리 그라데이션 폴백.
                    Positioned.fill(
                      child: IgnorePointer(
                        child: ColorFiltered(
                          colorFilter: unlocked
                              ? const ColorFilter.mode(
                                  Color(0x00000000),
                                  BlendMode.dst,
                                )
                              : const ColorFilter.matrix(<double>[
                                  0.30,
                                  0.40,
                                  0.11,
                                  0,
                                  -18,
                                  0.30,
                                  0.40,
                                  0.11,
                                  0,
                                  -18,
                                  0.30,
                                  0.40,
                                  0.11,
                                  0,
                                  -12,
                                  0,
                                  0,
                                  0,
                                  1,
                                  0,
                                ]),
                          child: Image.asset(
                            'assets/images/ui/incubator_capsule.png',
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => Container(
                              margin: const EdgeInsets.symmetric(horizontal: 6),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Color(0x3AA9D8FF),
                                    Color(0x14203040),
                                  ],
                                ),
                                borderRadius: radius,
                                border: Border.all(
                                  color: const Color(0x88A9D8FF),
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 62,
            child: hatchRem == null || hatchBugId == null
                ? null
                : _hatchActions(ctx, r, cfg, save, l, hatchBugId, hatchRem),
          ),
        ],
      ),
    );
  }

  /// 부화 진행 시간바(캡슐 **위**). 남은 시간을 숫자로도 같이 보여준다.
  Widget _hatchBar(double fill, String remainText) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: fill.clamp(0.0, 1.0),
          minHeight: 6,
          backgroundColor: const Color(0x33FFFFFF),
          valueColor: const AlwaysStoppedAnimation(Color(0xFF6FC96F)),
        ),
      ),
      const SizedBox(height: 2),
      Text(
        remainText,
        style: const TextStyle(
          color: Color(0xE6FFFFFF),
          fontWeight: FontWeight.w800,
          fontSize: 10,
          shadows: [Shadow(color: Colors.black, blurRadius: 3)],
        ),
      ),
    ],
  );

  /// 캡슐 아래 가속 버튼 — 젤리 즉시부화.
  ///
  /// "무료로 단축"(광고 자리)은 제거했다(2026-08-20). 광고가 비용이던 시절의
  /// 잔재라, 광고 없는 운영에서는 젤리 즉시부화의 값어치를 공짜로 깎기만 했다.
  Widget _hatchActions(
    BuildContext ctx,
    WidgetRef r,
    PetConfig cfg,
    SaveGame save,
    AppLocalizations l,
    String bugId,
    Duration rem,
  ) {
    final cost = cfg.incubateJelly(rem);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _hatchBtn(
          cost,
          const Color(0xFF7E57C2),
          l,
          () => _instantHatch(ctx, r, l, bugId, cost),
        ),
      ],
    );
  }

  /// 젤리 즉시 부화(확인 → 실행 → 효과음·안내). 캡슐 아래 버튼과 곤충 상세의 부화기 버튼이 함께 쓴다.
  Future<void> _instantHatch(
    BuildContext ctx,
    WidgetRef r,
    AppLocalizations l,
    String bugId,
    int cost,
  ) async {
    if (!await confirmJellySpend(
      ctx,
      title: l.incubatorInstant,
      body: l.incubatorInstantConfirm(cost),
      jelly: cost,
    )) {
      return;
    }
    if (!ctx.mounted) return;
    if (!await r.read(saveControllerProvider.notifier).instantIncubate(bugId)) {
      return;
    }
    AudioService.instance.sfxHatch();
    if (ctx.mounted) _snack(ctx, l.incubatorReady);
  }

  /// 곤충 상세(알)의 부화기 버튼 — 장착 자리에 놓인다(2026-10-14 사장님 확정).
  ///
  /// - 부화기 밖 · 빈 칸 있음 → "부화기에 넣기 · 시간"(확인 없이 바로 넣는다)
  /// - 부화기 밖 · 가득 참 · 확장 가능 → 젤리로 1칸 확장 후 넣기
  /// - 부화기 밖 · 가득 참 · 최대 → 흐린 버튼(먼저 끝나는 알 남은 시간) → 부화기 창
  /// - 부화 중 → 남은 시간 + 젤리 즉시 부화 / 끝났으면 → 수령
  Widget _eggIncubatorButton(
    BuildContext ctx,
    WidgetRef r,
    GameData data,
    PetConfig cfg,
    SaveGame save,
    IndividualBug bug,
    Species sp,
    DateTime now,
  ) {
    final l = AppLocalizations.of(ctx);
    final ctrl = r.read(saveControllerProvider.notifier);
    Widget btn({
      required String label,
      required Color bg,
      required VoidCallback onTap,
      Widget? lead,
      String? sub,
      Key? key,
    }) => FilledButton(
      key: key,
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        minimumSize: const Size(0, 40),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5),
          ),
          if (sub != null)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (lead != null) ...[lead, const SizedBox(width: 3)],
                Flexible(
                  child: Text(
                    sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );

    Future<void> place() async {
      if (!await ctrl.placeInIncubator(bug.id)) return;
      if (ctx.mounted) _snack(ctx, l.incubatorPlacedSnack);
    }

    final endsAt = save.incubating[bug.id];
    if (endsAt != null) {
      final rem = endsAt.difference(now);
      if (rem <= Duration.zero) {
        return btn(
          key: const ValueKey('eggIncubatorCollect'),
          label: l.incubatorCollect,
          bg: const Color(0xFFE08A2E),
          onTap: () async {
            if (!await ctrl.collectIncubated(bug.id)) return;
            AudioService.instance.sfxHatch();
            if (ctx.mounted) {
              _snack(
                ctx,
                sp.isIncompleteMetamorphosis
                    ? l.incubatorCollectedNymphSnack
                    : l.incubatorCollectedSnack,
              );
              await showHatchReveal(ctx, r, [bug.id]);
            }
          },
        );
      }
      final cost = cfg.incubateJelly(rem);
      return btn(
        key: const ValueKey('eggIncubatorHatching'),
        label: l.incubatorHatching(_remainLabel(l, rem)),
        bg: const Color(0xFF7E57C2),
        lead: jellyIcon(size: 12),
        sub: '$cost · ${l.incubatorInstant}',
        onTap: () => _instantHatch(ctx, r, l, bug.id, cost),
      );
    }
    if (save.incubating.length < save.incubatorCapacity) {
      return btn(
        key: const ValueKey('eggIncubatorPlace'),
        label: l.eggToIncubator(
          _remainLabel(l, Duration(seconds: _incubateSeconds(data, save, sp))),
        ),
        bg: const Color(0xFF2E6DA4),
        onTap: place,
      );
    }
    if (save.incubatorCapacity < cfg.incubatorSlotsMax) {
      final cost = cfg.incubatorExpandCost(save.incubatorCapacity);
      return btn(
        key: const ValueKey('eggIncubatorExpand'),
        label: l.eggIncubatorFullExpand('$cost'),
        bg: const Color(0xFF3E7D4F),
        onTap: () async {
          if (!await confirmJellySpend(
            ctx,
            title: l.incubatorExpandTitle,
            body: l.slotExpandConfirm(cost),
            jelly: cost,
            actionLabel: l.jellyActExpand,
          )) {
            return;
          }
          if (!ctx.mounted) return;
          if (!await ctrl.expandIncubator()) return;
          await place();
        },
      );
    }
    // 최대 칸까지 다 찼다 — 먼저 끝나는 알을 알려 주고 부화기 창으로 보낸다(흐린 색 = 지금은 못 넣는다).
    final first = save.incubating.values.isEmpty
        ? now
        : save.incubating.values.reduce((a, b) => a.isBefore(b) ? a : b);
    final wait = first.difference(now);
    return btn(
      key: const ValueKey('eggIncubatorFull'),
      label: wait <= Duration.zero
          ? '${l.incubatorFull} · ${l.incubatorReady}'
          : l.eggIncubatorFullWait(_remainLabel(l, wait)),
      bg: const Color(0x44FFFFFF),
      onTap: () => _showIncubator(ctx, r, data),
    );
  }

  /// 즉시부화 버튼 — **두 줄**(윗줄 젤리 비용 / 아랫줄 "즉시 부화").
  ///
  /// 한 줄에 다 넣으면 좁은 캡슐에서 잘리거나(말줄임) 깨알만 해진다
  /// (FittedBox 축소 — 둘 다 실기에서 지적당했다 2026-08-20). 캡슐 아래
  /// 공간은 세로 여유(62px)가 있으니 세로로 푼다.
  Widget _hatchBtn(
    int cost,
    Color bg,
    AppLocalizations l,
    VoidCallback? onTap,
  ) => SizedBox(
    width: double.infinity,
    height: 44,
    child: FilledButton(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: bg,
        disabledBackgroundColor: const Color(0x33FFFFFF),
        padding: EdgeInsets.zero,
        minimumSize: const Size(0, 44),
        visualDensity: VisualDensity.compact,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              jellyIcon(size: 12),
              const SizedBox(width: 3),
              Text(
                '$cost',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 1),
          Text(
            l.incubatorInstant,
            maxLines: 1,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
          ),
        ],
      ),
    ),
  );

  /// 부화할 알 선택 다이얼로그(빈 캡슐 탭 시).
  void _showEggPicker(BuildContext ctx, WidgetRef r, GameData data) {
    final cfg = data.petConfig;
    if (cfg == null) return;
    final l = AppLocalizations.of(ctx);
    final save = r.read(saveControllerProvider).requireValue;
    final now = r.read(clockProvider).now().toUtc();
    final locale = Localizations.localeOf(ctx).languageCode;
    final eggs = save.bugs
        .where(
          (b) =>
              effectiveStage(b.stage, b.stageSince, now, cfg) ==
                  LifeStage.egg &&
              !save.incubating.containsKey(b.id),
        )
        .toList();
    // 좋은 알부터 보여준다 — 슬롯이 1~3개뿐이라 **무엇을 먼저 넣을지**가
    // 이 화면의 유일한 결정이다. 획득 순서로 늘어놓으면 전설 알이 스크롤
    // 아래에 묻혀 일반 알을 먼저 돌리게 된다.
    // 등급 → 획득 순. ⚠️ 크기로 정렬하지 않는다 — 알의 크기는 부화 전까지 숨기므로(2026-10-14
    // 사장님 확정) 순서로 크기 순위가 새어 나간다. `List.sort` 는 안정 정렬이 아니라 획득 순(세이브 순서)을
    // 인덱스로 명시한다.
    final order = {
      for (var i = 0; i < save.bugs.length; i++) save.bugs[i].id: i,
    };
    eggs.sort((a, b) {
      final g = bugGradeSortKey(data, b).compareTo(bugGradeSortKey(data, a));
      if (g != 0) return g;
      return (order[a.id] ?? 0).compareTo(order[b.id] ?? 0);
    });
    showGameDialog<void>(
      ctx,
      title: l.incubatorPick,
      iconWidget: dialogAsset('assets/images/ui/incubator_capsule.png'),
      content: eggs.isEmpty
          ? Text(
              l.incubatorNoEggs,
              style: const TextStyle(color: Color(0x99FFFFFF)),
            )
          : ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: SizedBox(
                width: double.maxFinite,
                // ⚠️ `Wrap` 은 타일 폭(고정 96)으로 줄당 개수를 정하므로 좁은
                // 폰에서는 두 칸밖에 안 들어갔다. 3칸을 못 박고 **폭을 화면에
                // 맞춰 나눈다** — 알이 많을수록 스크롤이 줄어야 고르기 쉽다.
                child: GridView.builder(
                  padding: EdgeInsets.zero,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    // 알 42 + 이름 · 부화 시간 · 희귀도 · 등급 · 속성 다섯 줄(2026-10-14 사장님 — 한 줄에 몰려 헷갈렸다).
                    childAspectRatio: 0.58,
                  ),
                  itemCount: eggs.length,
                  itemBuilder: (_, i) =>
                      _eggPickTile(ctx, r, data, l, locale, eggs[i]),
                ),
              ),
            ),
      actions: [gameDialogButton(l.actionClose, () => Navigator.pop(ctx))],
    );
  }

  Widget _eggPickTile(
    BuildContext ctx,
    WidgetRef r,
    GameData data,
    AppLocalizations l,
    String locale,
    IndividualBug bug,
  ) {
    final sp = data.species(bug.speciesId);
    final variant = bug.variant != BugVariant.none;
    return GestureDetector(
      onTap: () async {
        // 상세를 보여 주고 부화 시작을 확인받는다(2026-09-29 사장님 요청).
        final go = await _confirmBug(
          ctx,
          data,
          locale,
          bug,
          LifeStage.egg,
          confirm: l.incubatorStartConfirm,
          // 스킨으로 줄어든 시간까지 반영한 실제 부화 시간(부화기와 같은 계산).
          extra: data.petConfig == null
              ? null
              : l.incubatorTimeInfo(
                  remainLabel(
                    l,
                    Duration(
                      seconds: _incubateSeconds(
                        data,
                        r.read(saveControllerProvider).requireValue,
                        sp,
                      ),
                    ),
                  ),
                ),
          skin: bugView(r.read(skinOfProvider), bug),
        );
        if (!go) return;
        final ok = await r
            .read(saveControllerProvider.notifier)
            .placeInIncubator(bug.id);
        if (ok && ctx.mounted) {
          Navigator.pop(ctx);
          _snack(ctx, l.incubatorPlacedSnack);
        }
      },
      child: SizedBox(
        // 폭은 **격자가 정한다**(3칸). 고정 폭을 주면 좁은 폰에서 칸을
        // 넘쳐 이름이 잘린다.
        width: double.infinity,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0x22000000),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              // 이색은 **테두리부터** 다르다 — 1/300 이라 목록에서 놓치면
              // 일반 알을 먼저 돌려 버린다.
              // 테두리는 등급·희귀도 어느 쪽 색도 쓰지 않는다 — 두 색이 섞여 헷갈렸다(2026-10-14). 줄마다 이름을 붙였다.
              color: variant ? kHoney : const Color(0x33FFFFFF),
              width: variant ? 1.8 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  bugStageImage(
                    bug.speciesId,
                    LifeStage.egg,
                    size: 42,
                    fallback: bugAvatar(sp, size: 36),
                    // 대화상자 안이라 read — 이 창이 열려 있는 동안 스킨이 바뀌지 않는다.
                    skin: bugView(r.read(skinOfProvider), bug),
                  ),
                  // 혈통 특성 — **알 단계에서 안 보이던 것**이 여기 있다.
                  // 짝짓기로 만든 알과 주운 알을 못 가르면 무엇을 먼저
                  // 부화할지 정할 수 없다. 보관함 그리드와 같은 표식(이름
                  // 뱃지)을 쓴다 — 색깔 점은 색을 외우기 전엔 뜻이 없다.
                  if (!bug.trait.isNone)
                    Positioned(
                      left: -4,
                      bottom: -2,
                      child: _eggBadge(
                        traitLabel(l, bug.trait),
                        traitColor(bug.trait),
                      ),
                    ),
                  if (variant)
                    Positioned(
                      right: -4,
                      top: -2,
                      // 이색 종류(무지개·알비노)를 적는다 — "이색"만으로는 어느 쪽인지 모른다.
                      child: _eggBadge(
                        variantLabel(l, bug.variant),
                        const Color(0xFFE0A020),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                sp.name.resolve(locale),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
              const SizedBox(height: 3),
              // 부화 시간 · 희귀도(종) · 등급(개체) · 속성 — 줄마다 이름을 붙인다(2026-10-14 사장님). 예전엔 종 희귀도와
              // 개체 등급이 이름 없이 색 글자로만 붙어 있어 어느 것이 무엇인지 헷갈렸다.
              if (data.petConfig != null)
                _eggInfoLine(
                  icon: const Icon(
                    Icons.hourglass_bottom_rounded,
                    size: 10,
                    color: Color(0xAAFFFFFF),
                  ),
                  value: remainLabel(
                    l,
                    Duration(
                      seconds: _incubateSeconds(
                        data,
                        r.read(saveControllerProvider).requireValue,
                        sp,
                      ),
                    ),
                  ),
                  color: const Color(0xCCFFFFFF),
                ),
              _eggInfoLine(
                label: l.eggPickRarity,
                value: gradeLabel(l, sp.grade),
                color: gradeColor(sp.grade),
              ),
              _eggInfoLine(
                label: l.igGradeLabel,
                value: gradeLabel(l, shownGrade(data, bug, sp)),
                color: gradeColor(shownGrade(data, bug, sp)),
              ),
              _eggInfoLine(
                label: l.bugInfoElement,
                icon: elementIcon(bug.element, size: 10),
                value: elementLabel(l, bug.element),
                color: elementColor(bug.element),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 알 고르기 칸의 한 줄 — "이름 값"(이름은 흐리게, 값은 색). 좁은 칸이라 넘치면 줄인다.
  Widget _eggInfoLine({
    String? label,
    Widget? icon,
    required String value,
    required Color color,
  }) => Padding(
    padding: const EdgeInsets.only(top: 1),
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (label != null) ...[
            Text(
              label,
              style: const TextStyle(color: Color(0x99FFFFFF), fontSize: 9),
            ),
            const SizedBox(width: 3),
          ],
          if (icon != null) ...[icon, const SizedBox(width: 2)],
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 9.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    ),
  );

  /// 알 위에 얹는 작은 이름표(특성·이색). 알 그림이 42px 뿐이라 글자를
  /// 8px 까지 줄이고 테두리를 넣어 배경과 안 섞이게 한다.
  /// 곤충(알·성충) 상세 + 확인 버튼 — 짝짓기·부화 시작 공용. 확인이면 true.
  Future<bool> _confirmBug(
    BuildContext ctx,
    GameData data,
    String locale,
    IndividualBug bug,
    LifeStage stage, {
    required String confirm,
    String? extra,
    SkinView? skin,
  }) async {
    final l = AppLocalizations.of(ctx);
    final sp = data.species(bug.speciesId);
    Widget row(String k, Widget v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(
              k,
              style: const TextStyle(color: Color(0xAAFFFFFF), fontSize: 12),
            ),
          ),
          Expanded(child: v),
        ],
      ),
    );
    Text val(String t, [Color c = Colors.white]) => Text(
      t,
      style: TextStyle(color: c, fontSize: 13, fontWeight: FontWeight.w900),
    );
    final ok = await showGameDialog<bool>(
      ctx,
      title: sp.name.resolve(locale),
      iconWidget: bugStageImage(
        bug.speciesId,
        stage,
        size: 56,
        fallback: bugAvatar(sp, size: 48),
        skin: skin,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 4,
            runSpacing: 3,
            children: [
              _eggBadge(
                gradeLabel(l, shownGrade(data, bug, sp)),
                gradeColor(shownGrade(data, bug, sp)),
              ),
              // 켜지면 종 희귀도를 작게 덧붙인다(부화·짝짓기 시간은 종 기준).
              if (individualGradeOn(data))
                _eggBadge(
                  l.igSpeciesRarity(gradeLabel(l, sp.grade)),
                  gradeColor(sp.grade).withValues(alpha: 0.7),
                ),
              if (!bug.trait.isNone)
                _eggBadge(traitLabel(l, bug.trait), traitColor(bug.trait)),
              if (bug.variant != BugVariant.none)
                _eggBadge(
                  variantLabel(l, bug.variant),
                  const Color(0xFFE0A020),
                ),
            ],
          ),
          const SizedBox(height: 8),
          row(
            individualGradeOn(data) ? l.igGradeLabel : l.bugInfoPotential,
            val(
              potentialText(l, bug.potential, individualGradeOn(data)),
              potentialColor(bug.potential, individualGradeOn(data)),
            ),
          ),
          row(
            l.bugInfoSex,
            Row(
              children: [
                sexArt(bug.sex, size: 14),
                const SizedBox(width: 4),
                val(sexLabel(l, bug.sex)),
              ],
            ),
          ),
          row(
            l.bugInfoElement,
            Row(
              children: [
                elementIcon(bug.element, size: 14),
                const SizedBox(width: 4),
                val(elementLabel(l, bug.element), elementColor(bug.element)),
              ],
            ),
          ),
          row(l.bugInfoTemperament, val(temperamentLabel(l, bug.temperament))),
          row(l.bugInfoSpecialty, val(specialtyLabel(l, sp.specialty))),
          // 알의 크기는 부화 전까지 숨긴다(2026-10-14 사장님 확정 — 능력치 숫자만 숨김).
          row(
            l.bugInfoSize,
            val(
              stage == LifeStage.egg
                  ? l.eggSizeHidden(
                      sp.sizeMinMm.toStringAsFixed(0),
                      sp.sizeMaxMm.toStringAsFixed(0),
                    )
                  : l.bugSize(bug.sizeMm.toStringAsFixed(1)),
            ),
          ),
          if (extra != null) ...[
            const SizedBox(height: 8),
            Text(
              extra,
              style: const TextStyle(
                color: Color(0xFFEBD24A),
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
      actions: [
        gameDialogButton(
          l.actionCancel,
          () => Navigator.pop(ctx, false),
          primary: false,
        ),
        gameDialogButton(confirm, () => Navigator.pop(ctx, true)),
      ],
    );
    return ok == true;
  }

  Widget _eggBadge(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: const Color(0xAA000000), width: 0.5),
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 8,
        fontWeight: FontWeight.w900,
        shadows: [Shadow(color: Colors.black, blurRadius: 2)],
      ),
    ),
  );

  // ── 정렬 ──────────────────────────────────────────────────────
  int _stageRank(LifeStage s) => switch (s) {
    LifeStage.adult => 3,
    LifeStage.pupa => 2,
    LifeStage.larva => 1,
    LifeStage.egg => 0,
  };

  /// 장착 → **등급↑** → 성장단계↑ → 포텐셜↑ → 레벨↑ → 종 순.
  ///
  /// 등급을 맨 앞에 두는 이유: 채집함을 여는 목적이 대부분 "좋은 놈 찾기"다.
  /// `Grade` enum 의 선언 순서(일반→전설)가 곧 등급 순서라 index 로 비교한다.
  List<({IndividualBug bug, LifeStage stage, bool equipped})> _sorted(
    GameData data,
    SaveGame save,
    DateTime now,
  ) {
    final cfg = data.petConfig;
    final list = save.bugs.map((b) {
      final st = cfg == null
          ? b.stage
          : effectiveStage(b.stage, b.stageSince, now, cfg);
      return (bug: b, stage: st, equipped: save.isEquipped(b.id));
    }).toList();
    // 켜지면 개체 등급 → 종 희귀도(`bugGradeSortKey`), 꺼지면 예전 순서(종 등급 → 단계 → 포텐셜) 그대로.
    final gradeOn = individualGradeOn(data);
    int gradeRank(IndividualBug b) => gradeOn
        ? bugGradeSortKey(data, b)
        : data.speciesById[b.speciesId]?.grade.index ?? -1;
    list.sort((a, b) {
      if (a.equipped != b.equipped) return a.equipped ? -1 : 1;
      final gr = gradeRank(b.bug) - gradeRank(a.bug);
      if (gr != 0) return gr;
      final sr = _stageRank(b.stage) - _stageRank(a.stage);
      if (sr != 0) return sr;
      if (a.bug.potential != b.bug.potential) {
        return b.bug.potential - a.bug.potential;
      }
      if (a.bug.level != b.bug.level) return b.bug.level - a.bug.level;
      return a.bug.speciesId.compareTo(b.bug.speciesId);
    });
    return list;
  }

  Widget _grid(
    BuildContext context,
    WidgetRef ref,
    GameData data,
    AppLocalizations l,
    SaveGame save,
  ) {
    if (save.bugs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            l.storageEmpty,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );
    }
    final view = ref.watch(storageViewFilterProvider);
    final items = _sorted(
      data,
      save,
      ref.read(clockProvider).now().toUtc(),
    ).where((it) => view.acceptsBug(data, it.bug, it.stage)).toList();
    if (items.isEmpty) {
      // 거른 결과가 비면 이유와 되돌리기를 함께 보여 준다 — 빈 화면만 있으면 곤충이 사라진 줄 안다.
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l.storageViewEmpty,
                key: const ValueKey('storageViewEmpty'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xCCFFFFFF),
                  fontSize: 13.5,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => ref
                    .read(storageViewFilterProvider.notifier)
                    .set(const StorageViewFilter()),
                child: Text(l.storageViewReset),
              ),
            ],
          ),
        ),
      );
    }
    // 결투 전투력(2026-10-12) — 세이브가 바뀔 때만 다시 계산한다(그리드 칸마다 계산하지 않는다).
    final powers = ref.watch(duelPowerByBugProvider);
    return GridView.builder(
      padding: const EdgeInsets.all(10),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.82,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final it = items[i];
        return _bugCell(
          context,
          ref,
          data,
          it.bug,
          it.stage,
          it.equipped,
          it.stage == LifeStage.adult ? powers[it.bug.id] : null,
        );
      },
    );
  }

  /// 보기 거르기 줄 — 지금 조건 요약 + 보이는 수 + 초기화. 누르면 조건 시트.
  Widget _viewFilterBar(
    BuildContext context,
    WidgetRef ref,
    GameData data,
    AppLocalizations l,
    SaveGame save,
  ) {
    final view = ref.watch(storageViewFilterProvider);
    final locale = Localizations.localeOf(context).languageCode;
    final now = ref.read(clockProvider).now().toUtc();
    final cfg = data.petConfig;
    final shown = save.bugs.where((b) {
      final st = cfg == null
          ? b.stage
          : effectiveStage(b.stage, b.stageSince, now, cfg);
      return view.acceptsBug(data, b, st);
    }).length;
    final parts = <String>[
      if (view.stage != StorageViewStage.all) _viewStageLabel(l, view.stage),
      if (view.minGrade != null)
        l.storageViewGradeAtLeast(gradeLabel(l, view.minGrade!)),
      if (view.speciesId != null)
        data.speciesById[view.speciesId]?.name.resolve(locale) ??
            view.speciesId!,
      if (view.passiveKey != null) _passiveKindName(l, view.passiveKey!),
      if (view.role != null) duelRoleLabel(l, view.role!),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              key: const ValueKey('storageViewButton'),
              onTap: () => _showViewFilter(context, data),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: view.isActive
                      ? _honey.withValues(alpha: 0.18)
                      : const Color(0x18FFFFFF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: view.isActive ? _honey : const Color(0x33FFFFFF),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.tune_rounded, size: 16, color: _honey),
                    const SizedBox(width: 5),
                    Text(
                      l.storageViewButton,
                      style: const TextStyle(
                        color: Color(0xDDFFFFFF),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        parts.isEmpty ? l.storageViewAll : parts.join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: view.isActive
                              ? Colors.white
                              : const Color(0x99FFFFFF),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      l.storageViewCount('$shown', '${save.bugs.length}'),
                      style: const TextStyle(
                        color: Color(0x99FFFFFF),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (view.isActive) ...[
            const SizedBox(width: 4),
            IconButton(
              tooltip: l.storageViewReset,
              visualDensity: VisualDensity.compact,
              icon: const Icon(
                Icons.close_rounded,
                size: 18,
                color: Color(0xCCFFFFFF),
              ),
              onPressed: () => ref
                  .read(storageViewFilterProvider.notifier)
                  .set(const StorageViewFilter()),
            ),
          ],
        ],
      ),
    );
  }

  /// 패시브 종류 이름 — 모르는 키(데이터 실수)는 키 그대로 보여 눈에 띄게.
  String _passiveKindName(AppLocalizations l, String key) {
    final t = passiveKindLabel(l, key);
    return t.isEmpty ? key : t;
  }

  String _viewStageLabel(AppLocalizations l, StorageViewStage s) => switch (s) {
    StorageViewStage.all => l.storageViewAll,
    StorageViewStage.egg => l.storageViewStageEgg,
    StorageViewStage.adult => l.storageViewStageAdult,
    StorageViewStage.other => l.storageViewStageOther,
  };

  /// 보기 조건 시트 — 단계 · 개체 등급(이상) · 종 · 패시브 종류 · 결투 역할. 칩을 누르면 바로 적용된다.
  void _showViewFilter(BuildContext context, GameData data) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xF2141F0E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Consumer(
          builder: (ctx, r, _) {
            final l = AppLocalizations.of(ctx);
            final locale = Localizations.localeOf(ctx).languageCode;
            final view = r.watch(storageViewFilterProvider);
            final save = r.watch(saveControllerProvider).requireValue;
            final ctrl = r.read(storageViewFilterProvider.notifier);
            // 종 목록 = 지금 가진 종(+ 고른 종) — 20종을 다 늘어놓으면 없는 종을 눌러 빈 화면만 보게 된다.
            final ids = {
              for (final b in save.bugs) b.speciesId,
              ?view.speciesId,
            };
            final species = [for (final id in ids) ?data.speciesById[id]]
              ..sort((a, b) {
                final g = b.grade.index - a.grade.index;
                if (g != 0) return g;
                return a.name.resolve(locale).compareTo(b.name.resolve(locale));
              });
            // 패시브 종류 = 새 곤충이 받을 수 있는 종류(표 순서) + 업데이트 전 곤충이 실제로 가진 종 패시브 종류.
            // 가진 곤충의 패시브 종류만(종 거르기와 같은 원칙 — 눌렀는데 빈 목록이 뜨지 않게). 순서는 데이터 순서.
            final owned = {
              for (final b in save.bugs) ?storagePassiveKeyOf(data, b),
            };
            final passiveKeys = <String>[
              for (final k
                  in data.petConfig?.passiveV2.kinds.keys ?? const <String>[])
                if (owned.contains(k)) k,
              for (final k in owned)
                if (!(data.petConfig?.passiveV2.kinds.containsKey(k) ?? false))
                  k,
            ];
            final selPassive = view.passiveKey;
            if (selPassive != null && !passiveKeys.contains(selPassive)) {
              passiveKeys.add(selPassive);
            }
            Widget head(String t) => Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 6),
              child: Text(
                t,
                style: const TextStyle(
                  color: _honey,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            );
            const neutral = Color(0xFF8FA3B3);
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l.storageViewTitle,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      if (view.isActive)
                        TextButton(
                          onPressed: () => ctrl.set(const StorageViewFilter()),
                          child: Text(l.storageViewReset),
                        ),
                    ],
                  ),
                  Text(
                    l.storageViewHint,
                    style: const TextStyle(
                      color: Color(0x99FFFFFF),
                      fontSize: 11.5,
                    ),
                  ),
                  head(l.storageViewStage),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final st in StorageViewStage.values)
                        _gradeChip(
                          label: _viewStageLabel(l, st),
                          color: neutral,
                          selected: view.stage == st,
                          onTap: () => ctrl.set(view.copyWith(stage: st)),
                        ),
                    ],
                  ),
                  head(l.storageViewGrade),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _gradeChip(
                        label: l.storageViewAll,
                        color: neutral,
                        selected: view.minGrade == null,
                        onTap: () =>
                            ctrl.set(view.copyWith(minGrade: () => null)),
                      ),
                      // 일반 이상 = 전체라 빼고 고급부터.
                      for (final g in Grade.values.skip(1))
                        _gradeChip(
                          label: l.storageViewGradeAtLeast(gradeLabel(l, g)),
                          color: gradeColor(g),
                          selected: view.minGrade == g,
                          onTap: () =>
                              ctrl.set(view.copyWith(minGrade: () => g)),
                        ),
                    ],
                  ),
                  head(l.storageViewSpecies),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _gradeChip(
                        label: l.storageViewAll,
                        color: neutral,
                        selected: view.speciesId == null,
                        onTap: () =>
                            ctrl.set(view.copyWith(speciesId: () => null)),
                      ),
                      for (final sp in species)
                        _gradeChip(
                          label: sp.name.resolve(locale),
                          color: gradeColor(sp.grade),
                          selected: view.speciesId == sp.id,
                          onTap: () =>
                              ctrl.set(view.copyWith(speciesId: () => sp.id)),
                        ),
                    ],
                  ),
                  head(l.storageViewPassive),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _gradeChip(
                        label: l.storageViewAll,
                        color: neutral,
                        selected: view.passiveKey == null,
                        onTap: () =>
                            ctrl.set(view.copyWith(passiveKey: () => null)),
                      ),
                      for (final k in passiveKeys)
                        _gradeChip(
                          label: _passiveKindName(l, k),
                          color: _honey,
                          selected: view.passiveKey == k,
                          onTap: () =>
                              ctrl.set(view.copyWith(passiveKey: () => k)),
                        ),
                    ],
                  ),
                  head(l.storageViewRole),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _gradeChip(
                        label: l.storageViewAll,
                        color: neutral,
                        selected: view.role == null,
                        onTap: () => ctrl.set(view.copyWith(role: () => null)),
                      ),
                      for (final r in DuelRole.values)
                        _gradeChip(
                          label: duelRoleLabel(l, r),
                          color: neutral,
                          selected: view.role == r,
                          onTap: () => ctrl.set(view.copyWith(role: () => r)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(l.actionClose),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// 아이콘 셀: 이미지 + 티어(★) + 성충 레벨 + 장착중. 등급색 테두리.
  Widget _bugCell(
    BuildContext context,
    WidgetRef ref,
    GameData data,
    IndividualBug bug,
    LifeStage stage,
    bool equipped,
    double? duelPower,
  ) {
    final species = data.species(bug.speciesId);
    final now = ref.read(clockProvider).now().toUtc();
    final injured = ref
        .read(saveControllerProvider)
        .requireValue
        .isInjured(bug.id, now);
    return GestureDetector(
      onTap: () => _showBugDetail(context, ref, data, bug.id),
      child: Container(
        // 개체 등급이 켜지면 테두리도 개체 등급(종 희귀도는 상세에 작게).
        decoration: _gradeFrame(
          individualGradeOn(data) ? bug.individualGrade : species.grade,
          equipped: equipped,
        ),
        foregroundDecoration: injured
            ? BoxDecoration(
                // 회색조 + 어둡게 = "지금은 쓸 수 없다"가 한눈에 읽힌다.
                color: const Color(0x99000000),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xAAE07A5F), width: 1.6),
              )
            : null,
        child: Column(
          children: [
            const SizedBox(height: 3),
            // 성충 레벨(상단)
            SizedBox(
              height: 13,
              child: stage == LifeStage.adult
                  ? Text(
                      'Lv.${bug.level}',
                      style: const TextStyle(
                        color: Color(0xCCFFFFFF),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : null,
            ),
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: bugStageImage(
                      bug.speciesId,
                      stage,
                      size: 48,
                      fallback: bugAvatar(species, size: 44),
                      skin: bugView(ref.watch(skinOfProvider), bug),
                    ),
                  ),
                  if (equipped)
                    Positioned(
                      top: -2,
                      left: -2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: _honey,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          AppLocalizations.of(context).equippedBadge,
                          style: const TextStyle(
                            color: kHoneyInk,
                            fontSize: 7.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  if (ref
                      .read(saveControllerProvider)
                      .requireValue
                      .lockedBugIds
                      .contains(bug.id))
                    // 안쪽에 두고 회색 판을 깐다 — 음수 좌표는 Stack 이 잘랐고 노랑은
                    // 곤충 그림에 묻혔다(2026-10-02 사장님 실기 지적).
                    Positioned(
                      top: 1,
                      right: 1,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: const BoxDecoration(
                          color: Color(0xEE3A3A3A),
                          shape: BoxShape.circle,
                          border: Border.fromBorderSide(
                            BorderSide(color: Color(0xFFE0E0E0), width: 1),
                          ),
                        ),
                        child: const Icon(
                          Icons.lock_rounded,
                          size: 11,
                          color: Color(0xFFE6E6E6),
                        ),
                      ),
                    ),
                  // 부상 표시는 칸 한가운데 크게 — 구석의 작은 이모지는
                  // 그리드에서 눈에 들어오지 않았다.
                  if (injured)
                    Positioned.fill(
                      child: Center(
                        child: gameImage(
                          'assets/images/ui/icon/injury.webp',
                          width: 38,
                          height: 38,
                          fallback: const Text(
                            '🩹',
                            style: TextStyle(fontSize: 30),
                          ),
                        ),
                      ),
                    ),
                  // 혈통 특성 표식 — 짝짓기로 만든 개체를 그리드에서 바로
                  // 골라낼 수 있어야 "키운 것"과 "주운 것"이 구분된다.
                  //
                  // **이름을 적는다.** 색깔 원은 색을 외우기 전엔 아무 뜻이
                  // 없어서, 알 위에 점 하나가 찍힌 것으로만 보였다.
                  // 장착 뱃지(좌상단)와 겹치지 않게 아래쪽에 둔다.
                  if (!bug.trait.isNone)
                    Positioned(
                      left: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: traitColor(bug.trait).withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                            color: const Color(0xAA000000),
                            width: 0.5,
                          ),
                        ),
                        child: Text(
                          traitLabel(AppLocalizations.of(context), bug.trait),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            shadows: [
                              Shadow(color: Colors.black, blurRadius: 2),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // 티어(별) + 성별.
            //
            // 성별은 **짝짓기의 전제 조건**인데(§2.5 같은 종 ♂+♀) 그리드에
            // 안 보여서, 짝을 지으려면 칸을 하나씩 열어 봐야 했다. 알·유충은
            // 아직 성별이 정해져 봐야 쓸 데가 없으므로 성충에만 붙인다.
            // 칸이 좁아 영어 "Legendary"·일본어 등급 이름이 넘쳤다(2026-10-12 출시 점검) —
            // 줄 폭에 맞춰 **줄이기만** 한다(scaleDown 이라 높이도 늘지 않아 아래 전투력 줄과 겹치지 않는다).
            Padding(
              padding: const EdgeInsets.only(bottom: 4, left: 3, right: 3),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (stage == LifeStage.adult) ...[
                      sexArt(bug.sex, size: 10),
                      const SizedBox(width: 3),
                    ],
                    _potentialMark(context, data, bug.potential, 8.5),
                  ],
                ),
              ),
            ),
            // 결투 전투력(성충만, 2026-10-12 사장님 요청) — 결투 탭·순위표와 같은 값. 칸이 좁아 줄여서 맞춘다.
            if (duelPower != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 3, left: 2, right: 2),
                child: SizedBox(
                  height: 11,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        gameImage(
                          'assets/images/ui/icon/combat_power.webp',
                          width: 11,
                          height: 11,
                          fallback: const Text(
                            '🔥',
                            style: TextStyle(fontSize: 9),
                          ),
                        ),
                        Text(
                          formatCompact(duelPower.round()),
                          key: ValueKey('duelPower_${bug.id}'),
                          style: const TextStyle(
                            color: Color(0xFFFFB27A),
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 포텐셜 표시 — 개체 등급이 켜지면 등급 이름표, 꺼지면 예전 별.
  Widget _potentialMark(
    BuildContext context,
    GameData data,
    int potential,
    double size,
  ) => individualGradeOn(data)
      ? individualGradeTag(
          AppLocalizations.of(context),
          potential,
          fontSize: size,
        )
      : _stars(potential, size);

  Widget _stars(int n, double size) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 0; i < n; i++)
        Icon(
          Icons.star_rounded,
          size: size,
          color: const Color(0xFFFFE24A),
          shadows: const [
            Shadow(
              color: Color(0xFF7A4E00),
              blurRadius: 0.5,
              offset: Offset(0, 0.6),
            ),
            Shadow(color: Colors.black87, blurRadius: 2),
          ],
        ),
    ],
  );

  /// 등급별 선명한 대표색(테두리·글로우용).
  Color _gradeBright(Grade g) => switch (g) {
    Grade.common => const Color(0xFFB6C2CC),
    Grade.uncommon => const Color(0xFF5CD65C),
    Grade.rare => const Color(0xFF3FA9FF),
    Grade.epic => const Color(0xFFC072F0),
    Grade.legendary => const Color(0xFFFFC93C),
  };

  /// 액자형 등급 프레임. 높은 등급일수록 두꺼운 테두리 + 그라데이션 + 글로우.
  BoxDecoration _gradeFrame(Grade g, {bool equipped = false}) {
    final c = _gradeBright(g);
    final lux = g.index; // 0(일반)~4(전설)
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          c.withValues(alpha: 0.16 + lux * 0.05),
          const Color(0xE60A1206),
        ],
      ),
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: c, width: 1.4 + lux * 0.5),
      boxShadow: [
        if (lux >= 2)
          BoxShadow(
            color: c.withValues(alpha: 0.35 + lux * 0.08),
            blurRadius: 6.0 + lux * 3,
            spreadRadius: lux >= 4 ? 1.0 : 0.0,
          ),
        if (equipped)
          BoxShadow(
            color: _honey.withValues(alpha: 0.7),
            blurRadius: 10,
            spreadRadius: 1,
          ),
      ],
    );
  }

  // ── 상단 장착 슬롯 ────────────────────────────────────────────
  Widget _equipStrip(
    BuildContext context,
    WidgetRef ref,
    GameData data,
    AppLocalizations l,
    SaveGame save,
  ) {
    final cfg = data.petConfig;
    final maxEquip = cfg?.maxEquip ?? 3;
    var atkPct = '0';
    var hpPct = '0';
    if (cfg != null) {
      final now = ref.read(clockProvider).now().toUtc();
      final pets = <PetStat>[];
      for (final id in save.equippedBugIds) {
        final bug = _findBug(save, id);
        if (bug == null) continue;
        final sp = data.speciesById[bug.speciesId];
        if (sp == null) continue;
        pets.add(
          petStatOf(
            bug,
            sp,
            cfg,
            now,
            trainMult: trainPetMult(
              save,
              bug.id,
              (data.battleConfig ?? const BattleConfig()).training,
            ),
          ),
        );
      }
      final pb = computePetBonus(pets, cfg);
      atkPct = ((pb.attackMult - 1) * 100).toStringAsFixed(0);
      hpPct = ((pb.hpMult - 1) * 100).toStringAsFixed(0);
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.pets, size: 15, color: _honey),
              const SizedBox(width: 5),
              // 색을 명시한다 — 기본 텍스트색이 어두워 배경에 묻혀 안 보였다.
              Text(
                l.equipTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 8),
              // 보너스는 제목 옆에 — 무엇을 얻고 있는지가 제목보다 중요하다.
              Expanded(
                child: Text(
                  l.petBonus(atkPct, hpPct),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _honey,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              _autoEquipButton(context, ref, data, l, save),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var i = 0; i < maxEquip; i++)
                Expanded(child: _equipSlot(context, ref, data, save, i)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _equipSlot(
    BuildContext context,
    WidgetRef ref,
    GameData data,
    SaveGame save,
    int index,
  ) {
    final id = index < save.equippedBugIds.length
        ? save.equippedBugIds[index]
        : null;
    final bug = id == null ? null : _findBug(save, id);
    final species = bug == null ? null : data.species(bug.speciesId);
    final cfg = data.petConfig;
    final stage = (bug == null || cfg == null)
        ? LifeStage.adult
        : effectiveStage(
            bug.stage,
            bug.stageSince,
            ref.read(clockProvider).now().toUtc(),
            cfg,
          );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: GestureDetector(
        onTap: bug == null
            ? null
            : () => _showBugDetail(context, ref, data, bug.id),
        child: Container(
          height: 118,
          decoration: bug == null
              ? BoxDecoration(
                  color: const Color(0x22000000),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0x33FFFFFF)),
                )
              : _gradeFrame(shownGrade(data, bug, species!), equipped: true),
          child: bug == null
              ? const Center(
                  child: Icon(
                    Icons.add_circle_outline,
                    color: Color(0x66FFFFFF),
                    size: 26,
                  ),
                )
              : Column(
                  children: [
                    Align(
                      alignment: Alignment.topRight,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4, right: 6),
                        child: Text(
                          'Lv.${bug.level}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: bugStageImage(
                        bug.speciesId,
                        stage,
                        size: 58,
                        fallback: bugAvatar(species!, size: 52),
                        skin: bugView(ref.watch(skinOfProvider), bug),
                      ),
                    ),
                    // 어떤 곤충을 끼웠는지 그림만으로는 헷갈린다 — 이름을 적는다.
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Text(
                        species.name.resolve(
                          Localizations.localeOf(context).languageCode,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6, top: 1),
                      child: _potentialMark(context, data, bug.potential, 11),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  /// 자동 장착 — 보너스가 가장 큰 곤충으로 슬롯을 채운다.
  ///
  /// 재화가 드는 일이 아니라 되돌리기 쉬우므로 확인 없이 바로 적용하고,
  /// 결과만 알린다(이미 최적이면 그렇다고 알린다 — 눌렀는데 아무 반응이
  /// 없으면 고장으로 보인다).
  Widget _autoEquipButton(
    BuildContext context,
    WidgetRef ref,
    GameData data,
    AppLocalizations l,
    SaveGame save,
  ) => TextButton.icon(
    onPressed: save.bugs.isEmpty
        ? null
        : () async {
            final changed = await ref
                .read(saveControllerProvider.notifier)
                .autoEquipBest();
            if (!context.mounted) return;
            if (changed) AudioService.instance.sfxReward();
            showCenterToast(
              context,
              changed ? l.autoEquipDone : l.autoEquipAlready,
            );
          },
    icon: const Icon(Icons.auto_awesome, size: 15),
    label: Text(l.autoEquip, style: const TextStyle(fontSize: 11.5)),
    style: TextButton.styleFrom(
      foregroundColor: const Color(0xFFBFE3A6),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      minimumSize: const Size(0, 30),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
  );

  // ── 재화 스트립(용도 캡션 + 탭 → 상세) ─────────────────────────
  Widget _materialsStrip(
    BuildContext context,
    AppLocalizations l,
    SaveGame save,
  ) => Container(
    padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // 재료마다 **같은 폭**을 나눠 갖고, 그 안에서 축소한다.
            // 자연 크기로 두면 수량이 K·M 단위로 올라갈 때 줄이 넘쳐 잘렸다.
            for (final k in MaterialKind.values)
              Expanded(
                child: InkWell(
                  onTap: () => _showMaterialInfo(context, l, k),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 2,
                      vertical: 2,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          materialImage(
                            k,
                            size: 26,
                            fallback: Icon(materialIcon(k), size: 22),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            formatCompact(save.materialCount(k)),
                            // 색을 안 주면 테마 기본색을 상속해 어두운 배경에 묻힌다.
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              shadows: [
                                Shadow(color: Colors.black, blurRadius: 3),
                                Shadow(
                                  color: Color(0xCC000000),
                                  offset: Offset(0, 1),
                                  blurRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        // 설명은 아이콘 **아래**에 오른쪽 정렬 — 위에 있으면 수량보다 먼저
        // 읽혀서 정작 봐야 할 숫자가 뒤로 밀린다.
        Padding(
          padding: const EdgeInsets.only(top: 2, right: 4),
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              l.materialsHint,
              style: const TextStyle(
                color: Color(0x99FFFFFF),
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    ),
  );

  void _showMaterialInfo(
    BuildContext context,
    AppLocalizations l,
    MaterialKind k,
  ) {
    showConceptCard(
      context,
      iconBox: Container(
        width: 46,
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0x22FFFFFF),
          borderRadius: BorderRadius.circular(10),
        ),
        child: materialImage(
          k,
          size: 40,
          fallback: Icon(materialIcon(k), size: 30, color: Colors.white),
        ),
      ),
      title: materialLabel(l, k),
      subtitle: materialTag(l, k),
      body: materialDesc(l, k),
      closeLabel: l.actionClose,
    );
  }

  IndividualBug? _findBug(SaveGame save, String id) {
    for (final b in save.bugs) {
      if (b.id == id) return b;
    }
    return null;
  }

  /// 이 종 알의 실제 부화 시간(초) — 스킨 편의 보너스까지(`placeInIncubator` 와 같은 계산).
  int _incubateSeconds(GameData data, SaveGame save, Species sp) {
    final cfg = data.petConfig!;
    return data.iapConfig?.skinnedIncubateSeconds(
          cfg.incubateDuration(sp.grade),
          save.ownedSkins,
          sp.id,
        ) ??
        cfg.incubateDuration(sp.grade);
  }

  static String _mmss(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  // ── 상세 팝업 ─────────────────────────────────────────────────
  void _showBugDetail(
    BuildContext context,
    WidgetRef ref,
    GameData data,
    String bugId,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      // 내용이 길면(성충·품질 카드) 시트 맨 위가 상태 표시줄 밑으로 들어갔다 — 위쪽 안전 영역을 지킨다.
      useSafeArea: true,
      backgroundColor: const Color(0xF2141F0E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Consumer(
          builder: (ctx, r, _) {
            final l = AppLocalizations.of(ctx);
            final save = r.watch(saveControllerProvider).requireValue;
            final bug = _findBug(save, bugId);
            if (bug == null) return const SizedBox.shrink();
            final species = data.species(bug.speciesId);
            final locale = Localizations.localeOf(ctx).languageCode;
            final petCfg = data.petConfig;
            final now = r.read(clockProvider).now().toUtc();
            final effStage = petCfg == null
                ? bug.stage
                : effectiveStage(bug.stage, bug.stageSince, now, petCfg);
            final equipped = save.isEquipped(bug.id);
            // 알은 능력치 숫자(품질·크기·펫 효과·훈련)를 부화 전까지 숨긴다(2026-10-14 사장님 확정).
            // 이색·기질·오행·성별·특성·종·개체 등급 같은 **타고난 표식**은 그대로 보인다.
            final isEgg = effStage == LifeStage.egg;
            // 개체 등급(2026-10-11) — 켜지면 등급 이름·테두리는 개체 등급, 종 등급은 "종 희귀도"로 작게.
            final gradeOn = individualGradeOn(data);
            final shownGrade = gradeOn ? bug.individualGrade : species.grade;
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 헤더
                  Row(
                    children: [
                      Container(
                        width: 62,
                        height: 62,
                        padding: const EdgeInsets.all(4),
                        decoration: _gradeFrame(shownGrade),
                        child: bugStageImage(
                          bug.speciesId,
                          effStage,
                          size: 54,
                          fallback: bugAvatar(species, size: 50),
                          skin: bugView(r.watch(skinOfProvider), bug),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              species.name.resolve(locale),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Text(
                                  gradeLabel(l, shownGrade),
                                  style: TextStyle(
                                    color: _gradeBright(shownGrade),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${stageLabel(l, effStage, species)}'
                                  '${effStage == LifeStage.adult ? ' Lv.${bug.level}' : ''}',
                                  style: const TextStyle(
                                    color: Color(0xCCFFFFFF),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            if (gradeOn)
                              Text(
                                l.igSpeciesRarity(gradeLabel(l, species.grade)),
                                style: TextStyle(
                                  color: gradeColor(
                                    species.grade,
                                  ).withValues(alpha: 0.9),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              )
                            else
                              _potentialMark(ctx, data, bug.potential, 13),
                            // 결투 전투력(성충만) — 홈의 캐릭터 전투력과 헷갈리지 않게 이름을 붙인다.
                            if (effStage == LifeStage.adult &&
                                r.watch(duelPowerByBugProvider)[bug.id] !=
                                    null) ...[
                              const SizedBox(height: 2),
                              // 전투력 표식은 모든 화면에서 같은 그림(2026-10-15 — 이모지가 남아 있었다).
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  gameIcon(
                                    'combat_power',
                                    size: 14,
                                    fallback: Icons.flash_on_rounded,
                                    color: const Color(0xFFFFB27A),
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    l.bugDuelPower(
                                      formatCompact(
                                        r
                                            .watch(
                                              duelPowerByBugProvider,
                                            )[bug.id]!
                                            .round(),
                                      ),
                                    ),
                                    style: const TextStyle(
                                      color: Color(0xFFFFB27A),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            // 혈통 특성(§2.5) — 짝짓기 자식만 가진다.
                            // 야생 개체와 구분되는 유일한 표식이라 이름 바로
                            // 아래, 포텐셜과 같은 줄 높이에 둔다.
                            // 특성이 없어도 **줄을 남긴다.** 아무것도 안 뜨면
                            // "이 곤충은 특성이 없다"인지 "화면이 빠뜨렸다"인지
                            // 구분이 안 된다 — 없다는 것도 정보다.
                            const SizedBox(height: 4),
                            _traitBadge(l, bug.trait),
                          ],
                        ),
                      ),
                      // 잠금 — 잠근 곤충은 합성·분해 재료로 쓰지 않는다(2026-10-02 문의).
                      _lockButton(
                        ctx,
                        r,
                        l,
                        save.lockedBugIds.contains(bug.id),
                        bug.id,
                      ),
                    ],
                  ),
                  if (species.desc != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      species.desc!.resolve(locale),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xB3FFFFFF),
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  // 개체 정보 — 예전엔 짝짓기·부화 확인 창에만 있어 채집함에서 크기·오행을
                  // 볼 수 없었다(2026-10-01 사장님 지적).
                  _bugInfoCard(
                    l,
                    species,
                    bug,
                    trainLv: trainedPointsOf(save, bug.id),
                    hideStats: isEgg,
                  ),
                  if (gradeOn) ...[
                    const SizedBox(height: 6),
                    gradeQualityCard(l, species, bug, hidden: isEgg),
                  ],
                  // 펫 패시브 v2(2026-10-14) — 개체마다 다른 패시브. 알은 종류만(크기는 부화 뒤).
                  if (petCfg != null) ...[
                    const SizedBox(height: 6),
                    petPassiveCard(ctx, r, data, bug, isEgg: isEgg),
                  ],
                  const SizedBox(height: 6),
                  if (petCfg != null)
                    _injuryCard(ctx, r, petCfg, save, bug, now),
                  // 알은 장착할 수 없고 능력치도 숨기므로 펫 효과 카드를 빼고 부화기 버튼을 둔다(아래).
                  if (petCfg != null && !isEgg)
                    _petEffectCard(
                      l,
                      species,
                      bug,
                      effStage,
                      petCfg,
                      trainMult: trainPetMult(
                        save,
                        bug.id,
                        (data.battleConfig ?? const BattleConfig()).training,
                      ),
                    ),
                  if (petCfg != null && effStage == LifeStage.adult) ...[
                    const SizedBox(height: 6),
                    _trainRow(ctx, r, petCfg, save, bug, now),
                    const SizedBox(height: 6),
                    _trainPointsRow(ctx, data, save, bug),
                  ],
                  if (petCfg != null &&
                      (effStage == LifeStage.larva ||
                          effStage == LifeStage.pupa)) ...[
                    const SizedBox(height: 6),
                    _evolveRow(
                      ctx,
                      r,
                      petCfg,
                      save,
                      bug,
                      species,
                      effStage,
                      now,
                    ),
                  ],
                  // 개체 등급이 켜지면 합성은 등급 올리기·정수로 바뀐다.
                  if (petCfg != null && gradeOn) ...[
                    const SizedBox(height: 6),
                    gradeActionsCard(ctx, r, data, save, bug),
                  ] else if (petCfg != null) ...[
                    const SizedBox(height: 6),
                    _synthRow(ctx, r, petCfg, save, bug),
                  ],
                  // 부위 강화는 훈련 v2 에서 훈련 포인트로 흡수됐다(2026-10-08 사장님 — 채집함에서는 아예 뺀다).
                  const SizedBox(height: 12),
                  // 하단 액션: 장착이면 '해제' 단독, 아니면 '장착 + 분해'
                  if (equipped)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => r
                            .read(saveControllerProvider.notifier)
                            .unequipBug(bug.id),
                        icon: const Icon(Icons.link_off, size: 18),
                        label: Text(l.unequipAction),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF556070),
                        ),
                      ),
                    )
                  else ...[
                    Builder(
                      builder: (_) {
                        final hatching = save.incubating.containsKey(bug.id);
                        return Row(
                          children: [
                            Expanded(
                              // 알은 장착 대신 **부화기 버튼**(2026-10-14 사장님 확정) — 알을 열어 본 김에 바로 넣는다.
                              child: isEgg && petCfg != null
                                  ? _eggIncubatorButton(
                                      ctx,
                                      r,
                                      data,
                                      petCfg,
                                      save,
                                      bug,
                                      species,
                                      now,
                                    )
                                  : FilledButton.icon(
                                      onPressed: () => r
                                          .read(saveControllerProvider.notifier)
                                          .equipBug(bug.id),
                                      icon: const Icon(Icons.pets, size: 18),
                                      label: Text(l.equipAction),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF2E7D32,
                                        ),
                                      ),
                                    ),
                            ),
                            // 부화 중인 알은 위 부화기 버튼이 상태(남은 시간·즉시 부화)를 보여 준다 — 아래에 같은 "부화 중"을
                            // 한 번 더 그리지 않는다(2026-10-14).
                            if (!hatching) ...[
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                onPressed: hatching
                                    ? null
                                    : () async {
                                        // 보상 팝업은 **앱 화면(네비게이터)** 기준으로 띄운다. 이 창을 연
                                        // `context` 는 곤충 칸이라, 분해로 곤충이 빠지면 칸도 사라져
                                        // `AppLocalizations.of` 가 null 로 앱을 죽였다(1.0.14 Crashlytics,
                                        // 2026-10-03). 네비게이터는 앱이 떠 있는 동안 계속 살아 있다.
                                        final host = Navigator.of(
                                          context,
                                        ).context;
                                        // 이색·키운 개체는 **한 번 더 묻는다**.
                                        // 되찾을 수 없는데 버튼 한 번에 사라지면
                                        // 그게 곧 클레임이다(2026-09-25 제보).
                                        // 훈련 v2 — 포인트를 찍은 곤충도(재료를 낸 투자).
                                        if (isPreciousBug(bug) ||
                                            trainedPointsOf(save, bug.id) > 0) {
                                          // 개체 등급이 켜졌으면 **정수라는 대안**을 알려 준다 — 분해는 재료,
                                          // 정수는 같은 종 등급 올리기(2026-10-12 출시 점검). 알·잠긴 곤충은 정수 불가라 빼고.
                                          final essence =
                                              gradeOn &&
                                                  petCfg != null &&
                                                  !save.pinnedBugIds.contains(
                                                    bug.id,
                                                  )
                                              ? petCfg.individualGrade
                                                    .essenceOf(
                                                      bug,
                                                      species.grade,
                                                    )
                                              : 0;
                                          final go =
                                              await showGameDialog<Object>(
                                                ctx,
                                                title: l.disassembleAction,
                                                icon:
                                                    Icons.warning_amber_rounded,
                                                content: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      l.disassembleConfirm,
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                    if (essence > 0) ...[
                                                      const SizedBox(height: 8),
                                                      Text(
                                                        l.disassembleEssenceHint(
                                                          species.name.resolve(
                                                            locale,
                                                          ),
                                                          '$essence',
                                                        ),
                                                        style: const TextStyle(
                                                          color: Color(
                                                            0xFFB39DDB,
                                                          ),
                                                          fontSize: 12.5,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                                actions: [
                                                  gameDialogButton(
                                                    l.actionCancel,
                                                    () => Navigator.pop(
                                                      ctx,
                                                      false,
                                                    ),
                                                    primary: false,
                                                  ),
                                                  if (essence > 0)
                                                    gameDialogButton(
                                                      l.igToEssence,
                                                      () => Navigator.pop(
                                                        ctx,
                                                        'essence',
                                                      ),
                                                      primary: false,
                                                    ),
                                                  gameDialogButton(
                                                    l.disassembleAction,
                                                    () => Navigator.pop(
                                                      ctx,
                                                      true,
                                                    ),
                                                    color: const Color(
                                                      0xFFB3452F,
                                                    ),
                                                  ),
                                                ],
                                              );
                                          if (!ctx.mounted) return;
                                          if (go == 'essence') {
                                            // 정수 쪽 확인 창(사유 경고 · 이색 두 번 확인)을 그대로 탄다.
                                            await confirmBugToEssence(
                                              ctx,
                                              r,
                                              data,
                                              bug,
                                            );
                                            return;
                                          }
                                          if (go != true) return;
                                        }
                                        final res = await r
                                            .read(
                                              saveControllerProvider.notifier,
                                            )
                                            .disassembleBug(bug.id);
                                        if (!ctx.mounted) return;
                                        if (!res.ok) {
                                          // 실패를 침묵으로 두면 "전설 알이 분해가 안 된다"가
                                          // 버그로 읽힌다 — 사유를 말해 준다.
                                          showCenterToast(context, switch (res
                                              .error) {
                                            'equipped' => l.disassembleEquipped,
                                            'incubating' =>
                                              l.disassembleIncubating,
                                            'locked' => l.disassembleLocked,
                                            _ => l.disassembleFailed,
                                          });
                                          return;
                                        }
                                        Navigator.pop(ctx);
                                        // 무엇이 얼마나 들어왔는지 **아이콘으로** 보여준다 —
                                        // 재료가 2~32 개라 "분해 완료"만으로는 아무것도 안
                                        // 들어온 것처럼 보인다(2026-09-01 지적).
                                        // 글자보다 아이콘이 어느 재화인지 즉시 갈린다.
                                        final gained = <MaterialKind, int>{
                                          if (res.kind != null)
                                            res.kind!: res.amount,
                                          if (res.jelly > 0)
                                            MaterialKind.jelly: res.jelly,
                                        };
                                        if (!host.mounted) return;
                                        if (gained.isEmpty) {
                                          showCenterToast(
                                            host,
                                            l.disassembleSnack,
                                          );
                                          return;
                                        }
                                        await showRewardPopup(
                                          host,
                                          title: l.disassembleSnack,
                                          icon: Icons.call_split,
                                          materials: gained,
                                        );
                                      },
                                icon: Icon(
                                  hatching
                                      ? Icons.hourglass_bottom_rounded
                                      : Icons.call_split,
                                  size: 18,
                                ),
                                label: Text(
                                  hatching
                                      ? l.incubatingLabel
                                      : l.disassembleAction,
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFFEF9A9A),
                                  side: const BorderSide(
                                    color: Color(0x55EF9A9A),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// 훈련 포인트 요약(사용 / 예산) + 훈련소로 가기(훈련 v2 — 부위 강화 자리를 받는다).
  Widget _trainPointsRow(
    BuildContext ctx,
    GameData data,
    SaveGame save,
    IndividualBug bug,
  ) {
    final l = AppLocalizations.of(ctx);
    final sp = data.species(bug.speciesId);
    final cfg = (data.battleConfig ?? const BattleConfig()).training;
    final rec = bugTrainOf(save, bug, sp, cfg, enhance: data.enhanceConfig);
    final budget = trainBudgetOf(
      save,
      bug,
      sp,
      cfg,
      enhance: data.enhanceConfig,
    );
    return _sectionBox(
      child: Row(
        children: [
          gameIcon(
            'train_point',
            size: 24,
            fallback: Icons.fitness_center_rounded,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l.trainPtSummaryLine('${rec.allocated}', '$budget'),
              key: const ValueKey('bugTrainPoints'),
              style: _rowTitle,
            ),
          ),
          FilledButton(
            key: const ValueKey('bugGoTraining'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE08A2E),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: const Size(0, 36),
              textStyle: const TextStyle(fontWeight: FontWeight.w900),
            ),
            onPressed: () {
              final nav = Navigator.of(ctx);
              nav.pop();
              nav.push(
                MaterialPageRoute<void>(
                  builder: (_) => TrainingScreen(initialBugId: bug.id),
                ),
              );
            },
            child: Text(l.trainGoCenter),
          ),
        ],
      ),
    );
  }

  Widget _sectionBox({required Widget child}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0x22000000),
      borderRadius: BorderRadius.circular(10),
    ),
    child: child,
  );

  /// 부상 회복 카드: 회복 중일 때만 표시(남은 시간 + 젤리 즉시회복).
  Widget _injuryCard(
    BuildContext ctx,
    WidgetRef r,
    PetConfig cfg,
    SaveGame save,
    IndividualBug bug,
    DateTime now,
  ) {
    final l = AppLocalizations.of(ctx);
    final until = save.injuredUntil(bug.id);
    if (until == null || !now.isBefore(until)) return const SizedBox.shrink();
    final remaining = until.difference(now);
    final jelly = cfg.injuryJelly(remaining);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: _sectionBox(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      gameImage(
                        'assets/images/ui/icon/injury.webp',
                        width: 18,
                        height: 18,
                        fallback: const Text(
                          '🩹',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          '${l.injuryTitle}  ${_remainLabel(l, remaining)}',
                          style: const TextStyle(
                            color: Color(0xFFEF9A9A),
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(l.injuryDesc, style: _rowSub),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () async {
                // 결투 탭 회복실(_healWithJelly)과 같은 확인 창.
                if (!await confirmJellySpend(
                  ctx,
                  title: l.injuryHealConfirmTitle,
                  body: l.injuryHealConfirm(jelly),
                  jelly: jelly,
                  actionLabel: l.injuryHealConfirmTitle,
                )) {
                  return;
                }
                if (!ctx.mounted) return;
                final ok = await r
                    .read(saveControllerProvider.notifier)
                    .healInjury(bug.id, viaJelly: true);
                if (ctx.mounted && !ok) _snack(ctx, l.notEnoughJelly);
              },
              style: _pillStyle(const Color(0xFF7E57C2)),
              child: _pillText(l.injuryHealJelly(jelly)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _petEffectCard(
    AppLocalizations l,
    Species sp,
    IndividualBug bug,
    LifeStage stage,
    PetConfig cfg, {
    double trainMult = 1,
  }) {
    // 여기만 `petStatOf` 를 안 쓴다 — 호출부가 **이미 해석한 단계**를 넘기므로
    // (다시 계산하면 같은 화면 안에서 한 프레임 어긋날 수 있다) 단계만 갈아끼운다.
    final c = petContribution((
      // `petStatOf` 와 같은 규칙 — 켜지면 개체 등급이 기여 비율을 정한다.
      grade: cfg.individualGrade.enabled ? bug.individualGrade : sp.grade,
      sizeMult: bug.statMultiplier(sp),
      potential: bug.potential,
      enhanceTotal: 0, // 훈련 v2 — 부위 강화는 trainMult(훈련 포인트)로 이전
      stage: stage,
      level: bug.level,
      trait: bug.trait,
      variant: bug.variant,
      passive: passiveOf(bug, sp, cfg), // 펫 패시브 v2 — 합산과 같은 함수
      trainMult: trainMult,
    ), cfg);
    // 폭은 다른 카드처럼 가득 — 글자 폭만큼만 좁게 떠 있었다(2026-10-15 에뮬 확인).
    return SizedBox(
      width: double.infinity,
      child: _sectionBox(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.petEffectTitle,
              style: const TextStyle(
                color: _honey,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l.petAtkBonus((c.attack * 100).toStringAsFixed(1)),
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
            Text(
              l.petHpBonus((c.hp * 100).toStringAsFixed(1)),
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  static const _rowTitle = TextStyle(
    color: Colors.white,
    fontWeight: FontWeight.w800,
    fontSize: 13.5,
  );
  static const _rowSub = TextStyle(color: Color(0xB3FFFFFF), fontSize: 11.5);

  /// 혈통 특성 배지. 색으로 계열(공격/방어/양쪽)이 먼저 읽히게 한다.
  Widget _traitBadge(AppLocalizations l, BugTrait t) {
    if (t.isNone) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0x22FFFFFF),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0x33FFFFFF)),
        ),
        child: Text(
          l.traitNoneBadge,
          style: const TextStyle(
            color: Color(0x99FFFFFF),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }
    final c = traitColor(t);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withValues(alpha: 0.75)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          traitIcon(t, size: 13),
          const SizedBox(width: 3),
          Text(
            traitLabel(l, t),
            style: TextStyle(
              color: c,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  /// 돌파 비용 한 줄: 골드 + 재료 종류별 아이콘·수량.
  ///
  /// 재료가 **여러 종류**라는 게 요점이다. 하나로 묶어 '×3' 이라 적으면
  /// 무엇을 모아야 하는지 알 수 없다. 모자란 항목은 빨갛게 칠해, 버튼을
  /// 눌러보기 전에 **무엇이 부족한지** 바로 보이게 한다.
  Widget _breakthroughCost(SaveGame save, int gold, int mat) => Wrap(
    spacing: 10,
    runSpacing: 3,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      _costChip(
        goldIcon(size: 14),
        formatCompact(gold),
        enough: save.gold >= gold,
      ),
      for (final k in kBreakthroughMaterials)
        _costChip(
          materialImage(
            k,
            size: 14,
            fallback: Icon(materialIcon(k), size: 13, color: Colors.white70),
          ),
          formatCompact(mat),
          enough: save.materialCount(k) >= mat,
        ),
    ],
  );

  Widget _costChip(Widget icon, String amount, {required bool enough}) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      icon,
      const SizedBox(width: 3),
      Text(
        amount,
        style: TextStyle(
          color: enough ? const Color(0xE6FFFFFF) : const Color(0xFFFF6B6B),
          fontSize: 11.5,
          fontWeight: enough ? FontWeight.w600 : FontWeight.w800,
        ),
      ),
    ],
  );

  ButtonStyle _pillStyle(Color bg, {Color fg = Colors.white}) =>
      FilledButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        // ⚠️ 비활성 색을 **반드시** 지정한다. 안 주면 다크 배경에 기본 회색이
        //    깔려 "재화가 모자란다"를 알려야 할 글씨가 통째로 안 보인다.
        disabledBackgroundColor: bg.withValues(alpha: 0.30),
        disabledForegroundColor: const Color(0x99FFFFFF),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        minimumSize: const Size(0, 36),
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
      );

  /// 알약 버튼 안의 글자 — **줄바꿈 금지**.
  ///
  /// 남은 시간이 1시간을 넘으면 문구가 길어져(`1시간 12분`) 버튼 안에서 두 줄로
  /// 접혔다. 부화 완료(`부화 완료!`)도 마찬가지다(2026-08-30 지적).
  /// 버튼은 높이가 36 고정이라 두 줄이 되면 글자가 잘리고 줄 높이가 흔들린다.
  ///
  /// 자르지 않고 **줄여서** 담는다 — 남은 시간은 잘리면 뜻이 사라진다
  /// ("1시간 1..."). `FittedBox` 가 폭에 맞춰 글꼴만 줄인다.
  Widget _pillText(String text) => FittedBox(
    fit: BoxFit.scaleDown,
    child: Text(text, maxLines: 1, softWrap: false),
  );

  /// 공용 포맷(`ui/labels.dart`) 로 위임 — 공방·부화기와 모양이 같아야 한다.
  String _remainLabel(AppLocalizations l, Duration d) => remainLabel(l, d);

  void _snack(BuildContext ctx, String text) => showCenterToast(ctx, text);

  /// 수련/돌파 행: 상한 미만이면 골드 수련, 상한 도달이면 돌파(타이머), 진행중이면 즉시완료/수령.
  Widget _trainRow(
    BuildContext ctx,
    WidgetRef r,
    PetConfig cfg,
    SaveGame save,
    IndividualBug bug,
    DateTime now,
  ) {
    final l = AppLocalizations.of(ctx);
    final ctrl = r.read(saveControllerProvider.notifier);
    final ends = bug.breakthroughEndsAt;

    // 돌파 진행 중.
    if (ends != null) {
      final rem = ends.difference(now);
      final done = rem <= Duration.zero;
      final jellyCost = cfg.breakthroughJelly(rem);
      return _sectionBox(
        child: Row(
          children: [
            gameIcon(
              'breakthrough',
              size: 23,
              fallback: Icons.auto_graph,
              color: _honey,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${l.breakthroughTitle} · ${l.breakthroughTier(bug.breakthroughTier + 1)}',
                    style: _rowTitle,
                  ),
                  Text(
                    done
                        ? l.breakthroughDone
                        : l.breakthroughProgress(_remainLabel(l, rem)),
                    style: _rowSub,
                  ),
                ],
              ),
            ),
            done
                ? FilledButton(
                    onPressed: () async {
                      final ok = await ctrl.completeBreakthrough(bug.id);
                      if (ok && ctx.mounted) {
                        _snack(ctx, l.breakthroughDoneSnack);
                      }
                    },
                    style: _pillStyle(_honey, fg: kHoneyInk),
                    child: _pillText(l.breakthroughCollect),
                  )
                : FilledButton.icon(
                    onPressed: () async {
                      if (!await confirmJellySpend(
                        ctx,
                        title: l.breakthroughInstantTitle,
                        body: l.breakthroughInstantConfirm(jellyCost),
                        jelly: jellyCost,
                      )) {
                        return;
                      }
                      if (!ctx.mounted) return;
                      final ok = await ctrl.completeBreakthrough(
                        bug.id,
                        viaJelly: true,
                      );
                      if (ok && ctx.mounted) {
                        _snack(ctx, l.breakthroughDoneSnack);
                      }
                    },
                    icon: gameIcon(
                      'instant',
                      size: 17,
                      fallback: Icons.bolt,
                      color: Colors.white,
                    ),
                    label: Text(l.breakthroughInstant(jellyCost)),
                    style: _pillStyle(const Color(0xFF2E6DA4)),
                  ),
          ],
        ),
      );
    }

    final tier = bug.breakthroughTier;
    final cap = cfg.levelCap(tier);

    // 일반 수련(상한 미만).
    if (bug.level < cap) {
      final cost = cfg.trainCost(bug.level);
      final can = save.gold >= cost;
      return _sectionBox(
        child: Row(
          children: [
            gameIcon(
              'train_level',
              size: 24,
              fallback: Icons.fitness_center,
              color: const Color(0xFF9CCC65),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${l.trainLevel}  Lv.${bug.level}/$cap · ${l.breakthroughTier(tier + 1)}',
                    style: _rowTitle,
                  ),
                  Text('💰 ${formatCompact(cost)}', style: _rowSub),
                ],
              ),
            ),
            FilledButton(
              onPressed: () async {
                if (!can) {
                  _snack(ctx, l.notEnoughGold);
                  return;
                }
                final ok = await ctrl.trainBug(bug.id);
                if (!ok) return;
                AudioService.instance.sfxEnhance();
                if (ctx.mounted) _snack(ctx, l.trainSnack);
              },
              style: _pillStyle(_honey, fg: kHoneyInk),
              child: _pillText(l.trainAction),
            ),
          ],
        ),
      );
    }

    // 최고 티어 달성.
    if (tier >= cfg.maxTier) {
      return _sectionBox(
        child: Row(
          children: [
            gameIcon(
              'max_grade',
              size: 23,
              fallback: Icons.workspace_premium,
              color: _honey,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${l.trainLevel} Lv.$cap · ${l.breakthroughMaxed}',
                style: _rowTitle,
              ),
            ),
          ],
        ),
      );
    }

    // 돌파 가능.
    final gold = cfg.breakthroughGoldCost(tier);
    final mat = cfg.breakthroughMatCost(tier);
    final canBreak =
        save.gold >= gold &&
        kBreakthroughMaterials.every((k) => save.materialCount(k) >= mat);
    return _sectionBox(
      child: Row(
        children: [
          gameIcon(
            'breakthrough',
            size: 23,
            fallback: Icons.auto_graph,
            color: _honey,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${l.breakthroughTitle} → ${l.breakthroughTier(tier + 2)}',
                  style: _rowTitle,
                ),
                const SizedBox(height: 3),
                // 재료를 이모지 하나로 묶어 '×3' 이라 적으면 **무엇이 3인지**
                // 알 수 없다(실제로는 키틴·미네랄·수액 각 mat 개). 종류마다
                // 아이콘과 수량을 따로 그리고, 모자란 건 빨갛게 표시한다.
                _breakthroughCost(save, gold, mat),
                const SizedBox(height: 2),
                Text(
                  '⏱${_remainLabel(l, Duration(seconds: cfg.breakthroughDuration(tier)))}',
                  style: _rowSub,
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: () async {
              if (!canBreak) {
                _snack(ctx, l.notEnoughMaterials);
                return;
              }
              final ok = await ctrl.breakthrough(bug.id);
              if (ok && ctx.mounted) {
                _snack(ctx, l.breakthroughStartedSnack);
              }
            },
            style: _pillStyle(_honey, fg: kHoneyInk),
            child: _pillText(l.breakthroughDo),
          ),
        ],
      ),
    );
  }

  Widget _evolveRow(
    BuildContext ctx,
    WidgetRef r,
    PetConfig petCfg,
    SaveGame save,
    IndividualBug bug,
    Species? species,
    LifeStage effStage,
    DateTime now,
  ) {
    final l = AppLocalizations.of(ctx);
    final rem =
        stageRemaining(bug.stage, bug.stageSince, now, petCfg) ?? Duration.zero;
    return _sectionBox(
      child: Row(
        children: [
          gameIcon(
            'growth',
            size: 23,
            fallback: Icons.spa,
            color: const Color(0xFF9CCC65),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.evolveTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                  ),
                ),
                Text(
                  effStage.isFinal
                      ? l.evolveMaxed
                      : (rem <= Duration.zero
                            ? l.evolveReady
                            : l.evolveNext(
                                _mmss(rem),
                                stageLabel(l, effStage.next, species),
                              )),
                  style: const TextStyle(
                    color: Color(0xB3FFFFFF),
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          if (!effStage.isFinal)
            FilledButton.icon(
              onPressed: () async {
                if (!await confirmJellySpend(
                  ctx,
                  title: l.evolveAccelTitle,
                  body: l.evolveAccelConfirm(
                    petCfg.accelerateJelly,
                    stageLabel(l, effStage.next, species),
                  ),
                  jelly: petCfg.accelerateJelly,
                  actionLabel: l.accelerateAction,
                )) {
                  return;
                }
                if (!ctx.mounted) return;
                r
                    .read(saveControllerProvider.notifier)
                    .accelerateEvolution(bug.id);
              },
              icon: jellyIcon(size: 16),
              label: Text('${l.accelerateAction} ${petCfg.accelerateJelly}'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2E6DA4),
                minimumSize: const Size(0, 36),
              ),
            ),
        ],
      ),
    );
  }

  Widget _synthRow(
    BuildContext ctx,
    WidgetRef r,
    PetConfig petCfg,
    SaveGame save,
    IndividualBug bug,
  ) {
    final l = AppLocalizations.of(ctx);
    final maxed = bug.potential >= petCfg.synthMaxPotential;
    // 보호(장착·부화 중·이색·투자)를 뺀 **실제 재료 수**. 예전엔 보호를 빼지 않고
    // 세어서, 버튼이 켜졌는데 아무 일도 안 일어나거나 지켜야 할 개체가 사라졌다.
    final have = r
        .read(saveControllerProvider.notifier)
        .synthFodderCount(save, bug.id, bug.speciesId);
    final need = petCfg.synthFodder;
    final can = !maxed && have >= need;
    return _sectionBox(
      child: Row(
        children: [
          gameIcon(
            'star_up',
            size: 23,
            fallback: Icons.auto_awesome_motion,
            color: _honey,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.synthTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                  ),
                ),
                Text(
                  maxed ? l.synthMaxed : l.synthDesc(have, need),
                  style: const TextStyle(
                    color: Color(0xB3FFFFFF),
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: () async {
              if (!can) {
                _snack(ctx, l.notEnoughMaterials);
                return;
              }
              final ctrl = r.read(saveControllerProvider.notifier);
              // ⚠️ **무엇이 사라지는지 먼저 보여준다.** 확인 없이 지우던 시절에
              // 이색·수련한 개체가 조용히 재료로 쓰였다(2026-09-25 제보).
              final fodder = ctrl.synthFodderFor(bug.id);
              if (fodder.length < need) {
                _snack(ctx, l.notEnoughMaterials);
                return;
              }
              final locale = Localizations.localeOf(ctx).languageCode;
              final data = r.read(gameDataProvider).value;
              final go = await showGameDialog<bool>(
                ctx,
                title: l.synthConfirmTitle,
                icon: Icons.auto_awesome_motion,
                subtitle: l.synthConfirm,
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final f in fodder)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          '· ${data?.speciesById[f.speciesId]?.name.resolve(locale) ?? f.speciesId}'
                          '  ★${f.potential} · ${f.sizeMm.toStringAsFixed(1)}mm',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                  ],
                ),
                actions: [
                  gameDialogButton(
                    l.actionCancel,
                    () => Navigator.pop(ctx, false),
                    primary: false,
                  ),
                  gameDialogButton(l.synthDo, () => Navigator.pop(ctx, true)),
                ],
              );
              if (go != true || !ctx.mounted) return;
              final ok = await ctrl.synthesize(bug.id);
              if (ok && ctx.mounted) _snack(ctx, l.synthSnack);
            },
            style: FilledButton.styleFrom(
              backgroundColor: kHoney,
              foregroundColor: kHoneyInk,
              minimumSize: const Size(0, 36),
            ),
            child: Text(l.synthDo),
          ),
        ],
      ),
    );
  }
}

/// 곤충 상세의 개체 정보(오행·성별·기질·주특기·크기). 두 칸씩 나란히.
Widget _bugInfoCard(
  AppLocalizations l,
  Species sp,
  IndividualBug bug, {
  int trainLv = 0,
  // 알이면 크기(내 값·배율)와 훈련 줄을 숨긴다(2026-10-14 사장님 확정 — 능력치 숫자는 부화 뒤 공개).
  bool hideStats = false,
}) {
  Widget cell(String k, Widget v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        // 이름 칸 — 영어 "Specialty"·"Training" 이 46px 에서 단어 중간에 꺾였다.
        SizedBox(
          width: 58,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              k,
              maxLines: 1,
              style: const TextStyle(color: Color(0xB3FFFFFF), fontSize: 11.5),
            ),
          ),
        ),
        Expanded(child: v),
      ],
    ),
  );
  Widget val(String t, [Color c = Colors.white]) => Text(
    t,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(color: c, fontSize: 12.5, fontWeight: FontWeight.w900),
  );
  // 크기 줄은 길어서(영어) 두 줄까지 — 한 줄이면 핵심인 "×배율"이 잘렸다.
  Widget val2(String t) => Text(
    t,
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
    style: const TextStyle(
      color: Colors.white,
      fontSize: 12.5,
      fontWeight: FontWeight.w900,
    ),
  );
  Widget withIcon(Widget icon, Widget text) => Row(
    children: [
      icon,
      const SizedBox(width: 4),
      Flexible(child: text),
    ],
  );
  final mult = bug.statMultiplier(sp);
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(10, 6, 10, 7),
    decoration: BoxDecoration(
      color: const Color(0x22000000),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: cell(
                l.bugInfoElement,
                withIcon(
                  elementIcon(bug.element, size: 14),
                  val(elementLabel(l, bug.element), elementColor(bug.element)),
                ),
              ),
            ),
            Expanded(
              child: cell(
                l.bugInfoSex,
                withIcon(sexArt(bug.sex, size: 14), val(sexLabel(l, bug.sex))),
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: cell(
                l.bugInfoTemperament,
                withIcon(
                  temperamentIcon(bug.temperament, size: 14),
                  val(temperamentLabel(l, bug.temperament)),
                ),
              ),
            ),
            Expanded(
              child: cell(
                l.bugInfoSpecialty,
                val(specialtyLabel(l, sp.specialty)),
              ),
            ),
          ],
        ),
        cell(
          l.bugInfoSize,
          val2(
            // 종 범위는 종 정보라 그대로 둔다 — 이 알의 크기와 배율만 가린다.
            hideStats
                ? l.eggSizeHidden(
                    sp.sizeMinMm.toStringAsFixed(0),
                    sp.sizeMaxMm.toStringAsFixed(0),
                  )
                : l.bugInfoSizeDetail(
                    bug.sizeMm.toStringAsFixed(1),
                    sp.sizeMinMm.toStringAsFixed(0),
                    sp.sizeMaxMm.toStringAsFixed(0),
                    mult.toStringAsFixed(2),
                  ),
          ),
        ),
        // 훈련소 단계 합(결투 능력치) — 훈련소에서와 같은 표기. 알은 훈련할 수 없으니 뺀다.
        if (!hideStats)
          cell(
            l.trainingCenter,
            withIcon(
              gameIcon(
                'train_point',
                size: 14,
                fallback: Icons.star_rounded,
                color: const Color(0xFF8FD8FF),
              ),
              val(
                trainLv > 0 ? l.trainPtShort('$trainLv') : l.trainingNoneShort,
                trainLv > 0 ? const Color(0xFF8FD8FF) : const Color(0xB3FFFFFF),
              ),
            ),
          ),
        // 이색 — 값은 종류(무지개·알비노). 예전엔 "이색 | 이색"으로 같은 말이 두 번 보였다.
        if (bug.variant != BugVariant.none)
          cell(
            l.dexVariant,
            val(
              bug.variant == BugVariant.rainbow
                  ? l.variantRainbow
                  : l.variantAlbino,
              const Color(0xFFE0A020),
            ),
          ),
      ],
    ),
  );
}

/// 곤충 상세의 잠금 버튼 — 켜면 **밝은 회색** 자물쇠(2026-10-02 사장님: 노랑은 안 보였다), 끄면 흐린 열린 자물쇠.
Widget _lockButton(
  BuildContext ctx,
  WidgetRef r,
  AppLocalizations l,
  bool locked,
  String bugId,
) => Tooltip(
  message: locked ? l.bugUnlock : l.bugLock,
  child: InkWell(
    borderRadius: BorderRadius.circular(20),
    onTap: () async {
      final now = await r
          .read(saveControllerProvider.notifier)
          .toggleBugLock(bugId);
      if (ctx.mounted) {
        final gradeOn = individualGradeOn(
          r.read(gameDataProvider).requireValue,
        );
        showCenterToast(
          ctx,
          now
              ? (gradeOn ? l.bugLockedToastGrade : l.bugLockedToast)
              : l.bugUnlockedToast,
        );
      }
    },
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: locked ? const Color(0xCC3A3A3A) : const Color(0x22FFFFFF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: locked ? const Color(0xFFE0E0E0) : const Color(0x44FFFFFF),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            locked ? Icons.lock_rounded : Icons.lock_open_rounded,
            size: 20,
            color: locked ? const Color(0xFFF2F2F2) : Colors.white60,
          ),
          Text(
            locked ? l.bugLocked : l.bugLock,
            style: TextStyle(
              color: locked ? const Color(0xFFF2F2F2) : Colors.white60,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    ),
  ),
);

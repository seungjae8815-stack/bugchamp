import 'dart:async';

import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/providers.dart';
import '../../domain/save_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/format.dart';
import '../../ui/game_dialog.dart';
import '../../ui/toast.dart';
import 'equip_widgets.dart';

const _honey = Color(0xFFFFD54F);

/// 장비 칸 **바로 밑**에 붙는 공방 조작부.
///
/// 가운데 [제련], 그 옆에 자동 제련 아이콘, 아래에 [공방 등급].
/// 화면을 옮기지 않는다 — 장비를 보면서 바로 돌리는 게 이 시스템의 리듬이다.
class ForgeBar extends ConsumerStatefulWidget {
  const ForgeBar({super.key});

  @override
  ConsumerState<ForgeBar> createState() => _ForgeBarState();
}

class _ForgeBarState extends ConsumerState<ForgeBar> {
  Timer? _auto;
  bool _busy = false;

  @override
  void dispose() {
    _auto?.cancel();
    super.dispose();
  }

  bool get _autoOn => _auto != null;

  void _stopAuto() {
    _auto?.cancel();
    _auto = null;
    if (mounted) setState(() {});
  }

  /// 한 번 두드린다 — 결과를 지금 낀 것과 나란히 보여주고 교체/폐기를 묻는다.
  Future<void> _forgeOnce() async {
    if (_busy) return;
    setState(() => _busy = true);
    final ctrl = ref.read(saveControllerProvider.notifier);
    final item = await ctrl.forgeOnce();
    if (!mounted) return;
    setState(() => _busy = false);
    final l = AppLocalizations.of(context);
    if (item == null) {
      showCenterToast(context, l.forgeNoFossil);
      return;
    }
    await showForgeResult(context, ref, item);
  }

  /// 자동 제련 — 망치질 간격마다 굴리고 조건에 맞으면 **자동으로 낀다**.
  /// 안 맞는 건 그냥 버려진다(가방이 없다).
  void _toggleAuto(ForgeConfig forge) {
    if (_autoOn) {
      _stopAuto();
      return;
    }
    _auto = Timer.periodic(
      Duration(milliseconds: (forge.hammerSeconds * 1000).round()),
      (_) async {
        final ctrl = ref.read(saveControllerProvider.notifier);
        final item = await ctrl.forgeOnce();
        if (!mounted) return;
        if (item == null) {
          _stopAuto(); // 화석이 떨어졌다
          return;
        }
        if (ctrl.isBetterItem(item)) {
          await ctrl.equipItem(item);
          // 목표를 찾으면 멈추는 게 기본값 — 아니면 뽑고도 계속 태운다.
          if (ref
              .read(saveControllerProvider)
              .requireValue
              .autoForgeStopOnHit) {
            _stopAuto();
          }
        }
      },
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final save = ref.watch(saveControllerProvider).requireValue;
    final data = ref.watch(gameDataProvider).value;
    final forge = data?.forgeConfig;
    if (forge == null) return const SizedBox.shrink();
    final fossil = save.materialCount(MaterialKind.fossil);

    return Column(
      children: [
        Row(
          children: [
            // 가운데가 제련 — 가장 자주 누르는 버튼이라 가장 크다.
            Expanded(
              child: InkWell(
                onTap: _busy ? null : _forgeOnce,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6B4A28), Color(0xFF3A2716)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _honey, width: 1.4),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.hardware_rounded,
                        color: _honey,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        l.forgeHammer,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        formatCompact(fossil),
                        style: const TextStyle(
                          color: _honey,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // 옆은 자동 — 아이콘 하나. 길게 누르면 목표 옵션을 고른다.
            InkWell(
              onTap: () => _toggleAuto(forge),
              onLongPress: () => showAutoForgeSettings(context, ref),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 54,
                height: 50,
                decoration: BoxDecoration(
                  color: _autoOn
                      ? const Color(0x44FFD54F)
                      : const Color(0x33121A10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _autoOn ? _honey : const Color(0x33FFFFFF),
                    width: _autoOn ? 1.6 : 1,
                  ),
                ),
                child: Icon(
                  _autoOn ? Icons.stop_rounded : Icons.autorenew_rounded,
                  color: _autoOn ? _honey : Colors.white70,
                  size: 24,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // 제련 밑 — 공방 등급. 누르면 현재 등급·확률·업그레이드 칸이 열린다.
        InkWell(
          onTap: () => showForgeGrade(context, ref),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              color: const Color(0x33121A10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0x33FFFFFF)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.workspace_premium_rounded,
                  color: _honey,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  '${l.forgeGradeButton} · ${l.forgeLevel(save.forgeLevel + 1)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                if (save.forgeUpAt != null) ...[
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.hourglass_bottom_rounded,
                    color: _honey,
                    size: 15,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 제련 결과 — **지금 낀 것과 나란히**. 가방이 없으니 여기서 정한다.
Future<void> showForgeResult(
  BuildContext context,
  WidgetRef ref,
  EquipItem item,
) async {
  final l = AppLocalizations.of(context);
  final locale = Localizations.localeOf(context).languageCode;
  final items = ref.read(gameDataProvider).value?.itemConfig;
  if (items == null) return;
  final cur = ref
      .read(saveControllerProvider)
      .requireValue
      .equippedItems[item.slot];

  await showGameDialog<void>(
    context,
    title: itemName(items, l, locale, item),
    icon: slotIcon(item.slot),
    content: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ItemOptionList(item: item, config: items, compare: cur),
        if (cur != null) ...[
          const Divider(height: 18, color: Color(0x33FFFFFF)),
          Text(
            l.forgeCurrent,
            style: const TextStyle(
              color: Color(0x99FFFFFF),
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          ItemOptionList(item: cur, config: items, dense: true),
        ],
      ],
    ),
    actions: [
      gameDialogButton(
        l.forgeResultDrop,
        () => Navigator.pop(context),
        primary: false,
      ),
      gameDialogButton(l.forgeResultKeep, () {
        ref.read(saveControllerProvider.notifier).equipItem(item);
        Navigator.pop(context);
      }),
    ],
  );
}

/// 자동 제련 설정 — 원하는 옵션과 "찾으면 멈춤".
Future<void> showAutoForgeSettings(BuildContext context, WidgetRef ref) async {
  final l = AppLocalizations.of(context);
  final ctrl = ref.read(saveControllerProvider.notifier);
  final save = ref.read(saveControllerProvider).requireValue;
  final want = {...save.autoForgeOptions};
  var stop = save.autoForgeStopOnHit;

  await showGameDialog<void>(
    context,
    title: l.forgeAutoTarget,
    icon: Icons.autorenew_rounded,
    content: StatefulBuilder(
      builder: (context, setLocal) => SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 240,
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final k in ItemOptionKind.values)
                    CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: want.contains(k),
                      onChanged: (v) => setLocal(() {
                        v == true ? want.add(k) : want.remove(k);
                      }),
                      title: Text(
                        optionLabel(l, k),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: stop,
              onChanged: (v) => setLocal(() => stop = v ?? true),
              title: Text(
                l.forgeStopOnHit,
                style: const TextStyle(color: _honey, fontSize: 12.5),
              ),
            ),
          ],
        ),
      ),
    ),
    actions: [
      gameDialogButton(l.actionClose, () {
        ctrl.setAutoForge(options: want, stopOnHit: stop);
        Navigator.pop(context);
      }),
    ],
  );
}

/// 공방 등급 — 현재/다음 확률과 **골드 10칸** 업그레이드.
Future<void> showForgeGrade(BuildContext context, WidgetRef ref) async {
  final data = ref.read(gameDataProvider).value;
  final forge = data?.forgeConfig;
  final items = data?.itemConfig;
  if (forge == null || items == null) return;

  await showGameDialog<void>(
    context,
    title: AppLocalizations.of(context).forgeGradeButton,
    icon: Icons.workspace_premium_rounded,
    content: _GradeBody(forge: forge, items: items),
    actions: [
      gameDialogButton(
        AppLocalizations.of(context).actionClose,
        () => Navigator.pop(context),
      ),
    ],
  );
}

class _GradeBody extends ConsumerWidget {
  const _GradeBody({required this.forge, required this.items});
  final ForgeConfig forge;
  final ItemConfig items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final save = ref.watch(saveControllerProvider).requireValue;
    final ctrl = ref.read(saveControllerProvider.notifier);
    final now = ref.read(clockProvider).now().toUtc();
    final maxed = save.forgeLevel >= forge.maxLevel;
    final upAt = save.forgeUpAt;

    final cur = forge.tierWeights(save.forgeLevel, items.tierCount);
    final next = forge.tierWeights(save.forgeLevel + 1, items.tierCount);

    return SizedBox(
      width: double.maxFinite,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.forgeLevel(save.forgeLevel + 1),
            style: const TextStyle(
              color: _honey,
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          // 다음 레벨 확률을 **나란히** — 무엇이 좋아지는지 보여야 올릴 마음이 든다.
          for (var i = 0; i < items.tierCount; i++)
            if (cur[i] >= 0.005 || next[i] >= 0.005)
              _oddsRow(locale, i, cur[i], next[i], maxed),
          const SizedBox(height: 12),
          if (maxed)
            Text(
              l.forgeMaxLevel,
              style: const TextStyle(color: Color(0x99FFFFFF)),
            )
          else if (upAt != null) ...[
            Text(
              l.forgeUpgrading,
              style: const TextStyle(color: Color(0x99FFFFFF), fontSize: 12),
            ),
            const SizedBox(height: 6),
            if (now.isAfter(upAt))
              _wide(l.forgeClaim, () => ctrl.claimForgeUpgrade())
            else
              _wide(
                '${l.forgeRush} · 💎${forge.levelUpJelly(upAt.difference(now))}',
                () async {
                  if (!await ctrl.rushForgeUpgrade() && context.mounted) {
                    showCenterToast(context, l.notEnoughJelly);
                  }
                },
              ),
          ] else ...[
            Row(
              children: [
                for (var i = 0; i < forge.levelUpSteps; i++)
                  Expanded(
                    child: Container(
                      height: 9,
                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                      decoration: BoxDecoration(
                        color: i < save.forgeSteps
                            ? _honey
                            : const Color(0x22FFFFFF),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            _wide(
              '${l.forgeStep(save.forgeSteps, forge.levelUpSteps)} · '
              '${formatCompact(forge.levelUpStepGold(save.forgeLevel))}',
              () async {
                if (!await ctrl.payForgeStep() && context.mounted) {
                  showCenterToast(context, l.notEnoughGold);
                }
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _oddsRow(String locale, int i, double now, double next, bool maxed) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Row(
          children: [
            SizedBox(
              width: 54,
              child: Text(
                items.tier(i).name.resolve(locale),
                style: TextStyle(
                  color: tierColor(items, i),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            SizedBox(
              width: 48,
              child: Text(
                '${(now * 100).toStringAsFixed(1)}%',
                textAlign: TextAlign.right,
                style: const TextStyle(color: Colors.white, fontSize: 11.5),
              ),
            ),
            if (!maxed) ...[
              const Icon(
                Icons.arrow_right_rounded,
                size: 16,
                color: Color(0x66FFFFFF),
              ),
              SizedBox(
                width: 48,
                child: Text(
                  '${(next * 100).toStringAsFixed(1)}%',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: next > now
                        ? const Color(0xFF9CCC65)
                        : const Color(0x66FFFFFF),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      );

  Widget _wide(String text, VoidCallback onTap) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0x33FFD54F),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _honey),
      ),
      child: Text(
        text,
        style: const TextStyle(color: _honey, fontWeight: FontWeight.w900),
      ),
    ),
  );
}

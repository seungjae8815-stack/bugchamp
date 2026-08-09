import 'dart:async';

import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/providers.dart';
import '../../domain/save_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/format.dart';
import '../../ui/toast.dart';
import 'equip_widgets.dart';

const _honey = Color(0xFFFFD54F);

/// 공방 — 화석 조각을 태워 장비를 뽑는다.
///
/// **3초에 한 번 땅!** 한 번에 다 태우지 않고 눈에 보이게 두드린다. 연출이자
/// 동시에 속도 제한이다 — 한 번에 만 개를 쏟으면 손맛도 리듬도 없다.
class ForgeScreen extends ConsumerStatefulWidget {
  const ForgeScreen({super.key});

  @override
  ConsumerState<ForgeScreen> createState() => _ForgeScreenState();
}

class _ForgeScreenState extends ConsumerState<ForgeScreen> {
  Timer? _auto;
  EquipItem? _result;
  bool _hammering = false;

  @override
  void dispose() {
    _auto?.cancel();
    super.dispose();
  }

  bool get _autoRunning => _auto != null;

  Future<void> _forgeOnce() async {
    if (_hammering) return;
    setState(() => _hammering = true);
    final item = await ref.read(saveControllerProvider.notifier).forgeOnce();
    if (!mounted) return;
    setState(() {
      _hammering = false;
      _result = item;
    });
    if (item == null) {
      _stopAuto();
      showCenterToast(context, AppLocalizations.of(context).forgeNoFossil);
    }
  }

  void _stopAuto() {
    _auto?.cancel();
    _auto = null;
    if (mounted) setState(() {});
  }

  /// 자동 제련 — 망치질 간격마다 굴리고, 조건에 맞으면 **자동으로 낀다**.
  /// 안 맞는 건 그냥 버려진다(가방이 없다).
  void _toggleAuto(ForgeConfig forge) {
    if (_autoRunning) {
      _stopAuto();
      return;
    }
    final period = Duration(milliseconds: (forge.hammerSeconds * 1000).round());
    _auto = Timer.periodic(period, (_) async {
      final ctrl = ref.read(saveControllerProvider.notifier);
      final item = await ctrl.forgeOnce();
      if (!mounted) return;
      if (item == null) {
        _stopAuto();
        return;
      }
      setState(() => _result = item);
      if (ctrl.isBetterItem(item)) {
        await ctrl.equipItem(item);
        // 목표를 찾으면 멈추는 게 기본값 — 아니면 뽑고도 계속 태운다.
        if (ref.read(saveControllerProvider).requireValue.autoForgeStopOnHit) {
          _stopAuto();
        }
      }
    });
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final save = ref.watch(saveControllerProvider).requireValue;
    final data = ref.watch(gameDataProvider).value;
    final items = data?.itemConfig;
    final forge = data?.forgeConfig;
    if (items == null || forge == null) {
      return Scaffold(appBar: AppBar(title: Text(l.forgeTitle)));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l.forgeTitle),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Row(
                children: [
                  const Icon(Icons.hardware_outlined, size: 16, color: _honey),
                  const SizedBox(width: 4),
                  Text(
                    formatCompact(save.materialCount(MaterialKind.fossil)),
                    style: const TextStyle(
                      color: _honey,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 24),
        children: [
          _ForgeResult(result: _result, config: items),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _bigButton(
                  l.forgeHammer,
                  Icons.hardware_rounded,
                  _hammering ? null : _forgeOnce,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _bigButton(
                  l.forgeAuto,
                  _autoRunning ? Icons.stop_rounded : Icons.autorenew_rounded,
                  () => _toggleAuto(forge),
                  on: _autoRunning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _ForgeUpgrade(config: forge, items: items),
        ],
      ),
    );
  }

  Widget _bigButton(
    String text,
    IconData icon,
    VoidCallback? onTap, {
    bool on = false,
  }) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: on ? const Color(0x44FFD54F) : const Color(0x33FFFFFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: on ? _honey : const Color(0x44FFFFFF)),
      ),
      child: Column(
        children: [
          Icon(icon, color: on ? _honey : Colors.white, size: 22),
          const SizedBox(height: 4),
          Text(
            text,
            style: TextStyle(
              color: on ? _honey : Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    ),
  );
}

/// 제련 결과 — **지금 낀 것과 나란히** 보여준다. 가방이 없으므로 여기서
/// 교체하거나 버린다.
class _ForgeResult extends ConsumerWidget {
  const _ForgeResult({required this.result, required this.config});
  final EquipItem? result;
  final ItemConfig config;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final save = ref.watch(saveControllerProvider).requireValue;
    final item = result;
    if (item == null) {
      return Container(
        height: 150,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0x33121A10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x22FFFFFF)),
        ),
        child: const Icon(
          Icons.hardware_rounded,
          size: 48,
          color: Color(0x33FFFFFF),
        ),
      );
    }
    final cur = save.equippedItems[item.slot];
    final ctrl = ref.read(saveControllerProvider.notifier);

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _card(
                context,
                itemName(config, l, locale, item),
                tierColor(config, item.tier),
                ItemOptionList(item: item, config: config, compare: cur),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: cur == null
                  ? _card(
                      context,
                      l.charEmptySlot,
                      const Color(0x33FFFFFF),
                      const SizedBox(height: 20),
                    )
                  : _card(
                      context,
                      l.forgeCurrent,
                      tierColor(config, cur.tier),
                      ItemOptionList(item: cur, config: config, dense: true),
                    ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _act(l.forgeResultKeep, _honey, () async {
                await ctrl.equipItem(item);
              }),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _act(l.forgeResultDrop, const Color(0x66FFFFFF), () {}),
            ),
          ],
        ),
      ],
    );
  }

  Widget _card(BuildContext context, String title, Color color, Widget body) =>
      Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: const Color(0x55121A10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color, width: 1.4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 2,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 6),
            body,
          ],
        ),
      );

  Widget _act(String text, Color color, VoidCallback onTap) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.w900),
      ),
    ),
  );
}

/// 공방 등급업 — **골드 10칸을 채우면 업그레이드가 시작된다**.
class _ForgeUpgrade extends ConsumerWidget {
  const _ForgeUpgrade({required this.config, required this.items});
  final ForgeConfig config;
  final ItemConfig items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final save = ref.watch(saveControllerProvider).requireValue;
    final ctrl = ref.read(saveControllerProvider.notifier);
    final now = ref.read(clockProvider).now().toUtc();
    final maxed = save.forgeLevel >= config.maxLevel;
    final upAt = save.forgeUpAt;
    final stepCost = config.levelUpStepGold(save.forgeLevel);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0x55121A10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x33FFFFFF)),
      ),
      child: Column(
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
          // 다음 레벨 확률을 **나란히** 보여준다 — 무엇이 좋아지는지 보여야
          // 올릴 마음이 든다.
          _odds(locale, save.forgeLevel, maxed),
          const SizedBox(height: 10),
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
                '${l.forgeRush} · ${config.levelUpJelly(upAt.difference(now))}',
                () async {
                  if (!await ctrl.rushForgeUpgrade() && context.mounted) {
                    showCenterToast(context, l.notEnoughJelly);
                  }
                },
              ),
          ] else ...[
            Row(
              children: [
                for (var i = 0; i < config.levelUpSteps; i++)
                  Expanded(
                    child: Container(
                      height: 8,
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
            _wide('${l.forgeStep(save.forgeSteps, config.levelUpSteps)} · '
                '${formatCompact(stepCost)}', () async {
              if (!await ctrl.payForgeStep() && context.mounted) {
                showCenterToast(context, l.notEnoughGold);
              }
            }),
          ],
        ],
      ),
    );
  }

  Widget _odds(String locale, int level, bool maxed) {
    final now = config.tierWeights(level, items.tierCount);
    final next = config.tierWeights(level + 1, items.tierCount);
    final rows = <Widget>[];
    for (var i = 0; i < items.tierCount; i++) {
      if (now[i] < 0.005 && next[i] < 0.005) continue;
      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: Row(
            children: [
              SizedBox(
                width: 52,
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
                width: 46,
                child: Text(
                  '${(now[i] * 100).toStringAsFixed(1)}%',
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
                  width: 46,
                  child: Text(
                    '${(next[i] * 100).toStringAsFixed(1)}%',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: next[i] > now[i]
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
        ),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows);
  }

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

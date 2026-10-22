import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:core_save/core_save.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/providers.dart';
import '../../domain/save_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/art.dart';
import '../../ui/format.dart';
import '../../ui/game_dialog.dart';
import 'character_scene.dart';
import 'equip_widgets.dart';
import 'polish_dialog.dart';
import 'forge_panel.dart';
import '../../ui/colors.dart';

const _honey = kHoney;

/// 장비 탭 — 옛 캐릭터 탭의 능력치 패널(2026-10-22 하단 탭 2쪽에서 탭 하나가 됐다).
///
/// 위 → 아래: 메인 캐릭터와 곁에 선 곤충들 · 능력치 · 장비 8칸 · **제련/자동** · **공방 등급**.
class EquipmentTab extends ConsumerStatefulWidget {
  const EquipmentTab({super.key});

  /// 장비 칸이 이보다 낮아지면 화면을 스크롤로 바꾼다(작은 폰 · 큰 글씨).
  static const double minGridHeight = 170;

  @override
  ConsumerState<EquipmentTab> createState() => _EquipmentTabState();
}

class _EquipmentTabState extends ConsumerState<EquipmentTab> {
  /// 화면 높이에 더 얹을 높이 — 장비 칸이 [EquipmentTab.minGridHeight] 에 못 미치는 만큼.
  /// 0 이면 예전처럼 한 화면에 꼭 맞고 스크롤이 생기지 않는다.
  double _extra = 0;

  /// 장비 칸이 받은 높이를 보고 [_extra] 를 맞춘다(다음 프레임 — 레이아웃 중엔 setState 못 한다).
  void _onGridHeight(double h) {
    final natural = h - _extra;
    final want = (EquipmentTab.minGridHeight - natural).clamp(0.0, 10000.0);
    if ((want - _extra).abs() < 0.5) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _extra = want);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final save = ref.watch(saveControllerProvider).requireValue;
    final items = ref.watch(gameDataProvider).value?.itemConfig;

    // **한 화면에 담는다.** 스크롤을 넣으면 기기마다 잘리는 위치가 달라서
    // "내 폰에서만 공방이 안 보인다"가 된다. 대신 남는 높이를 장비 칸에
    // 몰아주고, 씬 높이는 화면에 비례시킨다 — 작은 폰은 알아서 낮아진다.
    // 단 탭이 되며 앱바가 생겨, 작은 폰 + 큰 글씨에선 장비 칸이 145dp 까지 눌렸다(2026-10-22 검토) —
    // 그때만 모자란 높이를 얹고 스크롤로 내린다.
    return Scaffold(
      appBar: AppBar(title: Text(l.navEquip)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          child: LayoutBuilder(
            builder: (context, c) => SingleChildScrollView(
              physics: _extra > 0
                  ? const ClampingScrollPhysics()
                  : const NeverScrollableScrollPhysics(),
              child: SizedBox(
                height: c.maxHeight + _extra,
                child: Column(
                  children: [
                    SizedBox(
                      height: (c.maxHeight * 0.19).clamp(84.0, 132.0),
                      child: CharacterScene(save: save),
                    ),
                    const SizedBox(height: 8),
                    _StatsPanel(save: save),
                    const SizedBox(height: 8),
                    if (items != null) ...[
                      // 남는 높이를 전부 장비 칸이 가져간다 — 칸 모양은 자기가
                      // 받은 높이로 정한다(작은 폰에선 납작해질 뿐 안 잘린다).
                      Expanded(
                        key: const Key('equipGrid'),
                        child: LayoutBuilder(
                          builder: (context, g) {
                            _onGridHeight(g.maxHeight);
                            return _EquipGrid(save: save, config: items);
                          },
                        ),
                      ),
                      const SizedBox(height: 6),
                      // 장비 **바로 밑** — 가운데 제련, 좌우에 공방 등급·필터/자동.
                      const ForgeBar(),
                    ] else
                      const Spacer(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 능력치 — 장비까지 반영된 **지금 값**.
class _StatsPanel extends ConsumerWidget {
  const _StatsPanel({required this.save});
  final SaveGame save;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final data = ref.watch(gameDataProvider).value;
    final run = data?.runConfig;
    if (run == null) return const SizedBox.shrink();

    // 상한을 씌운 값을 보여준다 — 화면이 100%라고 하는데 실제로는 85%로
    // 굴러가면 그게 곧 버그 제보가 된다(넘친 만큼은 치명피해로 옮겨간다).
    final s = capCritChance(
      applyEquipment(
        deriveStats(
          run,
          upgradeLevels: save.upgradeLevels,
          characterLevel: save.level,
          bugsCollected: save.bugBuffCount,
        ),
        equipmentBonus(save.equippedItems.values, data?.itemConfig),
        critBudget: run.critBudgetGear,
        evadeBudget: run.evadeBudgetGear,
      ),
      run.critChanceMax,
    );

    // 8줄을 세로로 세우면 화면의 3분의 1을 먹는다 — **두 줄씩 좌우로** 접어
    // 넣어 높이를 절반으로 줄인다. 장비 탭이 한 화면에 들어와야 한다.
    final rows = <(String, String)>[
      (l.statAttack, formatCompact(s.attack)),
      (l.statAttackSpeed, '×${s.attackSpeed.toStringAsFixed(2)}'),
      (
        l.statCrit,
        '${(s.critChance * 100).toStringAsFixed(1)}%·'
            '×${s.critDamage.toStringAsFixed(2)}',
      ),
      (l.statHp, formatCompact(s.maxHp)),
      (l.statDefense, formatCompact(s.defense)),
      (l.statGoldGain, '×${s.rewardMultiplier.toStringAsFixed(2)}'),
      (l.statMaterialGain, '×${s.materialFind.toStringAsFixed(2)}'),
      (l.statBugFind, '×${s.bugFind.toStringAsFixed(2)}'),
      // 회피(옛 이동속도 강화 칸, 2026-10-09) — 물기가 빗나갈 확률(상한 포함).
      (l.statEvade, '${(evadeChance(run, s) * 100).toStringAsFixed(1)}%'),
    ];
    final half = (rows.length + 1) ~/ 2;

    return _box(
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) => Column(
                children: [
                  for (final r in rows.take(half)) _row(r.$1, r.$2, c.maxWidth),
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) => Column(
                children: [
                  for (final r in rows.skip(half)) _row(r.$1, r.$2, c.maxWidth),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String k, String v, double maxWidth) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Expanded(
          child: Text(
            k,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xB3FFFFFF), fontSize: 11.5),
          ),
        ),
        const SizedBox(width: 4),
        // 값은 줄 폭의 60% 까지 — 큰 글씨(1.3)에서 "12.5%·×2.40" 이 줄 밖으로 넘쳤다(2026-10-22). 넘치면 줄여 보인다.
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth * 0.6),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              v,
              maxLines: 1,
              style: const TextStyle(
                color: _honey,
                fontWeight: FontWeight.w900,
                fontSize: 11.5,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

/// 펫 — 지금 받고 있는 보너스. 편성은 아직 채집함에서 한다(이동은 별도 단계).
// 준비 중이라 지금은 안 쓴다. **지우지 않는다** — 다시 켤 때 그대로 붙인다.
// ignore: unused_element
class _PetsPanel extends ConsumerWidget {
  const _PetsPanel({required this.save});
  final SaveGame save;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final data = ref.watch(gameDataProvider).value;
    final cfg = data?.petConfig;
    var atk = '0';
    var hp = '0';
    if (cfg != null) {
      final now = ref.read(clockProvider).now().toUtc();
      final pets = <PetStat>[];
      for (final id in save.equippedBugIds) {
        IndividualBug? bug;
        for (final b in save.bugs) {
          if (b.id == id) {
            bug = b;
            break;
          }
        }
        final sp = bug == null ? null : data?.speciesById[bug.speciesId];
        if (bug == null || sp == null) continue;
        pets.add(
          petStatOf(
            bug,
            sp,
            cfg,
            now,
            trainMult: trainPetMult(
              save,
              bug.id,
              (data?.battleConfig ?? const BattleConfig()).training,
            ),
          ),
        );
      }
      final pb = computePetBonus(pets, cfg);
      atk = ((pb.attackMult - 1) * 100).toStringAsFixed(0);
      hp = ((pb.hpMult - 1) * 100).toStringAsFixed(0);
    }
    return _box(
      Column(
        children: [
          Text(
            l.petBonus(atk, hp),
            style: const TextStyle(
              color: _honey,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l.charPetHint,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0x99FFFFFF), fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}

/// 장비 8칸 — 부위마다 **낀 것 1개**. 가방이 없다.
class _EquipGrid extends StatelessWidget {
  const _EquipGrid({required this.save, required this.config});
  final SaveGame save;
  final ItemConfig config;

  static const _cols = 4;
  static const _gap = 5.0;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      // 받은 높이에 **두 줄이 딱 맞게** 칸 비율을 역산한다. 고정 비율로 두면
      // 세로가 짧은 폰에서 넘치고 긴 폰에서는 아래가 텅 빈다.
      final w = (c.maxWidth - _gap * (_cols - 1)) / _cols;
      final h = (c.maxHeight - _gap) / 2;
      return GridView.count(
        crossAxisCount: _cols,
        shrinkWrap: true,
        // 계산이 빗나가도 넘치는 대신 스크롤된다 — 안전판.
        physics: const ClampingScrollPhysics(),
        mainAxisSpacing: _gap,
        crossAxisSpacing: _gap,
        childAspectRatio: h <= 0 ? 1.3 : (w / h).clamp(0.7, 2.6),
        children: [
          for (final slot in EquipSlot.values)
            _EquipCell(
              slot: slot,
              item: save.equippedItems[slot],
              config: config,
            ),
        ],
      );
    },
  );
}

class _EquipCell extends ConsumerWidget {
  const _EquipCell({
    required this.slot,
    required this.item,
    required this.config,
  });

  final EquipSlot slot;
  final EquipItem? item;
  final ItemConfig config;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final color = item == null
        ? const Color(0x33FFFFFF)
        : tierColor(config, item!.tier);
    // 그림이 **칸을 꽉 채운다**. 예전엔 26px 그림 아래에 부위·등급 글씨를
    // 쌓아서 정작 아이템이 제일 작았다 — 뭘 꼈는지 한눈에 안 들어왔다.
    // 글씨는 아래에 겹쳐 얹고, 등급은 테두리 색이 이미 말해 준다.
    return InkWell(
      onTap: item == null ? null : () => _detail(context, ref, locale),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          // 등급을 **바탕색**으로도 알린다. 테두리 선만으로는 격자에서
          // 한눈에 안 들어온다 — 색 면적이 있어야 훑어보다 눈에 걸린다.
          // 그림이 죽지 않게 아주 옅게, 아래로 갈수록 어둡게.
          gradient: item == null
              ? null
              : LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    color.withValues(alpha: 0.34),
                    color.withValues(alpha: 0.10),
                  ],
                ),
          color: item == null ? const Color(0x55121A10) : null,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color, width: item == null ? 1 : 1.8),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (item == null)
              Padding(
                padding: const EdgeInsets.fromLTRB(3, 3, 3, 12),
                child: LayoutBuilder(
                  builder: (context, c) => Center(
                    child: slotGhost(
                      slot,
                      size: c.biggest.shortestSide,
                      tint: color,
                    ),
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.all(3),
                child: LayoutBuilder(
                  builder: (context, c) => Center(
                    child: itemImage(
                      item!,
                      size: c.biggest.shortestSide,
                      tint: color,
                    ),
                  ),
                ),
              ),
            // 별 강화 — 별 개수·별 재료 진행·강화 중/강화 가능(2026-10-10 사장님 요청: 자동 제련이 별 재료를
            // 먹이는 게 칸 위에 보여야 한다). 별 재료가 하나도 없는 새 장비에는 아무것도 그리지 않는다.
            if (item != null)
              ..._starMarks(item!, ref.read(clockProvider).now().toUtc()),
            // 별 재료가 들어간 순간 "★+N" 이 칸 위로 떠오른다.
            // 키를 준다 — 첫 별 재료가 들어가 막대·아이콘이 새로 생겨도 이 표시가 같은 자리로 맞춰져 애니메이션이 끊기지 않는다.
            if (item != null)
              Positioned.fill(
                key: const ValueKey('starFeedPop'),
                child: _StarFeedPop(slot: slot),
              ),
            // 낀 칸에는 **글씨를 안 넣는다.** 등급은 테두리·바탕색이 이미
            // 말하고 있어서, 이름까지 얹으면 그림 자리만 깎아먹는다.
            // 빈 칸만 어느 부위인지 알려 준다.
            if (item == null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  color: const Color(0xAA0D1408),
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: Text(
                    slotLabel(l, slot),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0x88FFFFFF),
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 칸 위의 별 표시 — 왼쪽 위 별 개수 · 아래 별 재료 막대 · 오른쪽 위 강화 중(모래시계)/강화 가능(위 화살표).
  List<Widget> _starMarks(EquipItem it, DateTime now) {
    if (config.starMax <= 0) return const [];
    final maxed = it.stars >= config.starMax;
    final need = maxed ? 0 : config.starNeedAt(it.stars);
    // 강화 시간이 끝났으면 모래시계가 아니라 "받기"(체크) — 완료 처리는 장비 상세에서 한다(2026-10-10 점검).
    final finished = it.starUntil != null && !now.isBefore(it.starUntil!);
    final upgrading = it.starUntil != null && !finished;
    final ready = !maxed && !upgrading && need > 0 && it.starExp >= need;
    final showBar = !maxed && (it.starExp > 0 || it.starUntil != null);
    return [
      if (it.stars > 0)
        Positioned(
          left: 2,
          top: 2,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
            decoration: BoxDecoration(
              color: const Color(0xAA0D1408),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                gameIcon(
                  'equip_star',
                  size: 12,
                  fallback: Icons.star_rounded,
                  color: _honey,
                ),
                Text(
                  '${it.stars}',
                  style: const TextStyle(
                    color: _honey,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      if (upgrading || ready || finished)
        Positioned(
          right: 2,
          top: 2,
          child: Container(
            padding: const EdgeInsets.all(1.5),
            decoration: const BoxDecoration(
              color: Color(0xAA0D1408),
              shape: BoxShape.circle,
            ),
            child: Icon(
              finished
                  ? Icons.check_circle_rounded
                  : (upgrading
                        ? Icons.hourglass_top_rounded
                        : Icons.keyboard_double_arrow_up_rounded),
              size: 11,
              color: upgrading ? Colors.white : _honey,
            ),
          ),
        ),
      if (showBar)
        Positioned(
          left: 4,
          right: 4,
          bottom: 3,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: upgrading || need <= 0
                  ? 1
                  : (it.starExp / need).clamp(0.0, 1.0),
              minHeight: 3.5,
              backgroundColor: const Color(0x66000000),
              valueColor: AlwaysStoppedAnimation(
                ready ? const Color(0xFFFFE082) : _honey,
              ),
            ),
          ),
        ),
    ];
  }

  /// 낀 장비의 상세 — **여기서도 옵션을 바꿀 수 있다**.
  ///
  /// 낀 것을 못 바꾸면 좋은 등급을 뽑고도 옵션이 나쁘면 버려야 해서,
  /// 등급을 모으는 의미가 줄어든다(2026-09-09 확정).
  void _detail(BuildContext context, WidgetRef ref, String locale) {
    final l = AppLocalizations.of(context);
    final forge = ref.read(gameDataProvider).value?.forgeConfig;
    showGameDialog<void>(
      context,
      title: itemName(config, l, locale, item!),
      iconWidget: itemImage(item!, size: 40),
      content: StatefulBuilder(
        builder: (ctx, setLocal) {
          // 굴린 뒤 값이 바뀌므로 **세이브에서 다시 읽는다** — 생성자로 받은
          // item 은 창을 연 순간의 사본이라 갱신되지 않는다.
          final now =
              ref.read(saveControllerProvider).value?.equippedItems[slot] ??
              item!;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 환생 별 + 다음 별까지(2026-10-10 장비 v2 — 모루에서 같은 부위 장비를 먹여 올린다).
              itemStarsRow(l, config, now, progress: true),
              StarUpPanel(slot: slot),
              ItemOptionList(
                item: now,
                config: config,
                maxMult:
                    ref
                        .read(gameDataProvider)
                        .value
                        ?.forgeConfig
                        ?.transcendMaxMult(
                          ref
                                  .read(saveControllerProvider)
                                  .value
                                  ?.forgeTranscend ??
                              0,
                        ) ??
                    1,
                onPolish: forge == null
                    ? null
                    : (i) async {
                        await showPolishDialog(
                          ctx,
                          index: i,
                          equipped: true,
                          slot: slot,
                        );
                        if (!ctx.mounted) return;
                        setLocal(() {});
                      },
              ),
            ],
          );
        },
      ),
      actions: [gameDialogButton(l.actionClose, () => Navigator.pop(context))],
    );
  }
}

Widget _box(Widget child) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  decoration: BoxDecoration(
    color: const Color(0x55121A10),
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: const Color(0x22FFFFFF)),
  ),
  child: child,
);

/// 별 재료가 들어간 순간 장비 칸 위로 "★+N" 이 떠오르는 표시(약 1.1초). 모루가 [starFeedPulseProvider] 로 알린다.
class _StarFeedPop extends ConsumerStatefulWidget {
  const _StarFeedPop({required this.slot});
  final EquipSlot slot;

  @override
  ConsumerState<_StarFeedPop> createState() => _StarFeedPopState();
}

class _StarFeedPopState extends ConsumerState<_StarFeedPop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  int _n = 0;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(starFeedPulseProvider, (_, next) {
      final n = next?.fed[widget.slot] ?? 0;
      if (n <= 0) return;
      // 자동 제련이 빠르게 이어지면 숫자를 쌓아 보인다(아직 떠 있는 동안 온 것은 더한다).
      setState(() => _n = _c.isAnimating ? _n + n : n);
      _c.forward(from: 0);
    });
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          if (!_c.isAnimating) return const SizedBox.shrink();
          final t = Curves.easeOut.transform(_c.value);
          final fade = _c.value < 0.7 ? 1.0 : (1 - (_c.value - 0.7) / 0.3);
          return Align(
            alignment: Alignment(0, 0.3 - 0.9 * t),
            child: Opacity(
              opacity: fade.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: 0.8 + 0.35 * (1 - (t - 0.3).abs().clamp(0.0, 1.0)),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xCC0D1408),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _honey, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      gameIcon(
                        'equip_star',
                        size: 14,
                        fallback: Icons.star_rounded,
                        color: _honey,
                      ),
                      Text(
                        '+$_n',
                        style: const TextStyle(
                          color: _honey,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

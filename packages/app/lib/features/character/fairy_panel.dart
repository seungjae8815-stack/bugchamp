import 'dart:math' as math;
import 'dart:async';

import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:core_save/core_save.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/providers.dart';
import '../../domain/save_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/art.dart';
import '../../ui/fairy_art.dart';
import '../../ui/format.dart';
import '../../ui/game_dialog.dart';
import '../../ui/jelly_confirm.dart';
import '../../ui/toast.dart';
import '../../ui/colors.dart';

const _honey = kHoney;

/// 요정 탭(docs/design_fairy.md §2) — 위 → 아래: [둥지][뽑기][도감][합성][분해] ·
/// 동행 요정 카드 · 요정함(요정 + 알).
///
/// 규칙은 전부 core_save `fairy_progress.dart` 이고 여기는 보여 주고 부르기만 한다.
/// 팝업은 스킬 탭과 같은 모양(`showDialog` + `GameDialog`)이다.
class FairyPanel extends ConsumerStatefulWidget {
  const FairyPanel({super.key});

  @override
  ConsumerState<FairyPanel> createState() => _FairyPanelState();
}

class _FairyPanelState extends ConsumerState<FairyPanel> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // 둥지 남은 시간·다 깼다는 표시가 세이브가 안 바뀌어도 움직여야 한다(스킬 수련 바와 같다).
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      final s = ref.read(saveControllerProvider).value;
      if (mounted && s?.fairy.nest != null) setState(() {});
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
    final save = ref.watch(saveControllerProvider).requireValue;
    final cfg = ref.watch(gameDataProvider).value?.fairyConfig;
    if (cfg == null) return const SizedBox.shrink();
    final f = save.fairy;
    final fairies = [...f.fairies]
      ..sort((a, b) {
        if (a.id == f.companionId) return -1;
        if (b.id == f.companionId) return 1;
        return _fairyOrder(a, b);
      });
    final eggs = [...f.eggs]
      ..sort((a, b) => b.grade.index.compareTo(a.grade.index));
    final body = Column(
      children: [
        _header(l, save, cfg),
        const SizedBox(height: 8),
        _CompanionCard(fairy: f.companion, cfg: cfg),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              l.fairyBoxTitle('${f.boxUsed}', '${cfg.boxCapOf(f.boxExtra)}'),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 8),
            if (eggs.isNotEmpty)
              Text(
                l.fairyEggCount('${eggs.length}'),
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
            const Spacer(),
            _BoxExpandButton(cfg: cfg, boxExtra: f.boxExtra),
          ],
        ),
        const SizedBox(height: 6),
        Expanded(
          child: fairies.isEmpty && eggs.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      l.fairyEmptyBox,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white60),
                    ),
                  ),
                )
              : GridView(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 76,
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                    childAspectRatio: 0.72,
                  ),
                  children: [
                    for (final x in fairies)
                      _FairyCell(
                        fairy: x,
                        companion: x.id == f.companionId,
                        onTap: () => _open(_FairyDetailDialog(id: x.id)),
                      ),
                    for (final e in eggs)
                      _EggCell(egg: e, onTap: () => _open(const _NestDialog())),
                  ],
                ),
        ),
      ],
    );
    // 요정 숲 배경 — 흐리게 깐다(칸·글자가 읽혀야 한다). 그림이 없으면 없는 대로.
    return Stack(
      children: [
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Opacity(
              opacity: 0.35,
              child: gameImage(
                'assets/images/fairies/fairy_bg.webp',
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                fallback: const SizedBox.shrink(),
              ),
            ),
          ),
        ),
        body,
      ],
    );
  }

  Future<void> _open(Widget dialog) => showDialog<void>(
    context: context,
    barrierColor: const Color(0xB3000000),
    builder: (_) => fairyButtons(dialog),
  );

  Widget _header(AppLocalizations l, SaveGame save, FairyConfig cfg) {
    final nest = save.fairy.nest;
    final ready =
        nest != null &&
        !ref.read(clockProvider).now().toUtc().isBefore(nest.endsAt);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0x33121A10),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0x22FFFFFF)),
          ),
          child: Row(
            children: [
              fairyDustImage(size: 16),
              const SizedBox(width: 4),
              Text(
                formatCompact(save.fairy.dust),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _btn(
            l.fairyNest,
            fairyNestImage(size: 18),
            () => _open(const _NestDialog()),
            badge: ready,
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: _btn(
            l.fairyGacha,
            fairyEggImage(FairyGrade.legendary, size: 18),
            () => _open(const _GachaDialog()),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: _btn(
            l.fairyDex,
            // 그림이 있으면 그림(docs/art_prompts_fairy_fx.md), 없으면 아이콘.
            gameImageChain(
              const ['assets/images/fairies/fairy_dex.webp'],
              size: 18,
              fallback: const Icon(
                Icons.menu_book_rounded,
                size: 15,
                color: _honey,
              ),
            ),
            () => _open(const _DexDialog()),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: _btn(
            l.fairyMerge,
            gameImageChain(
              const ['assets/images/fairies/fairy_automerge.webp'],
              size: 18,
              fallback: const Icon(
                Icons.merge_type_rounded,
                size: 15,
                color: _honey,
              ),
            ),
            () => _open(const _MergeHubDialog()),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: _btn(
            l.fairyRelease,
            gameImageChain(
              const ['assets/images/fairies/fairy_release.webp'],
              size: 18,
              fallback: const Icon(
                Icons.recycling_rounded,
                size: 15,
                color: _honey,
              ),
            ),
            () => _open(const _ReleaseHubDialog()),
            // 자동 분해가 켜져 있으면 테두리로 알린다(모르고 알이 사라진다고 느끼지 않게).
            badge: save.fairy.autoReleaseUpTo != null,
          ),
        ),
      ],
    );
  }

  Widget _btn(
    String text,
    Widget art,
    VoidCallback onTap, {
    bool badge = false,
  }) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      decoration: BoxDecoration(
        color: const Color(0x33121A10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: badge ? _honey : const Color(0x22FFFFFF)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 18, child: Center(child: art)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              text,
              maxLines: 1,
              style: TextStyle(
                color: badge ? _honey : Colors.white70,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

String _err(AppLocalizations l, String? e) => switch (e) {
  'not_enough_jelly' => l.fairyErrJelly,
  'not_enough_dust' => l.fairyErrDust,
  'reroll_cap' => l.fairyRerollCap,
  'network' => l.fairyRerollNetwork,
  _ => l.fairyErrGeneric,
};

Future<bool> _confirm(BuildContext context, String title, String body) async {
  final l = AppLocalizations.of(context);
  final ok = await showGameDialog<bool>(
    context,
    title: title,
    content: Text(
      body,
      textAlign: TextAlign.center,
      style: const TextStyle(color: Colors.white, fontSize: 13),
    ),
    actions: [
      gameDialogButton(
        l.actionCancel,
        () => Navigator.of(context, rootNavigator: true).pop(false),
        primary: false,
      ),
      gameDialogButton(
        title,
        () => Navigator.of(context, rootNavigator: true).pop(true),
      ),
    ],
  );
  return ok == true;
}

/// 이름 · 칭호(두 줄).
Widget _nameBlock(AppLocalizations l, FairyKindDef? def, String locale) =>
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          def?.name.resolve(locale) ?? '?',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 15,
          ),
        ),
        if (def != null)
          Text(
            def.title.resolve(locale),
            style: const TextStyle(color: Colors.white60, fontSize: 11),
          ),
      ],
    );

/// 등급 · 레벨 · 품질 한 줄.
Widget _gradeLine(AppLocalizations l, Fairy f) => Text(
  '${fairyGradeLabel(l, f.grade)} · ${l.fairyLevel('${f.level}')}',
  style: TextStyle(
    color: fairyGradeColor(f.grade),
    fontWeight: FontWeight.w800,
    fontSize: 12,
  ),
);

/// 기본·부가 능력치 줄.
List<Widget> _statLines(AppLocalizations l, Fairy f, FairyConfig cfg) {
  // 같은 등급·레벨에서 이 능력치가 가질 수 있는 범위 — 개체값 0 과 최대 자리의 값(비례).
  final lo = cfg.statAt(f.grade, 0), hi = cfg.statAt(f.grade, kFairyRollMax);
  Widget line(String tag, String key, double v, int roll) {
    final at = cfg.statAt(f.grade, roll);
    // [기본] 공격 +2.1%
    //        (영웅 범위 1.6%~3.2%)   ← 범위는 **아래 줄**, 값과 왼쪽 끝을 맞춘다(2026-10-01 실기).
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 1),
            decoration: BoxDecoration(
              color: const Color(0x22FFFFFF),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              tag,
              style: const TextStyle(color: Colors.white60, fontSize: 9.5),
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${fairyStatLabel(l, key)} ${fairyStatValue(key, v)}',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
                if (at > 0)
                  Text(
                    l.fairyStatRange(
                      fairyGradeLabel(l, f.grade),
                      fairyStatValue(key, v * lo / at),
                      fairyStatValue(key, v * hi / at),
                    ),
                    style: const TextStyle(color: Colors.white38, fontSize: 10),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 줄들을 한 덩어리로 — 덩어리는 부모 정렬(가운데·왼쪽)을 따르고, 줄끼리는 왼쪽 끝을 맞춘다.
  return [
    IntrinsicWidth(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final e in cfg.mainBonus(f).entries)
            line(l.fairyStatMain, e.key, e.value, f.baseRoll),
          if (cfg.subBonus(f) > 0)
            line(l.fairyStatSub, f.sub, cfg.subBonus(f), f.subRoll),
        ],
      ),
    ),
  ];
}

/// 스킬 한 줄.
Widget _skillLine(AppLocalizations l, Fairy f, FairyConfig cfg) {
  final def = cfg.byId(f.kind);
  if (def == null) return const SizedBox.shrink();
  final cd = def.skill.cooldown.inSeconds;
  return Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Text(
      '${l.fairySkill} · ${fairySkillText(l, def.skill, cfg.skillValue(f))}'
      '${cd > 0 ? ' (${l.fairyCooldown('$cd')})' : ''}',
      style: const TextStyle(color: Color(0xFF80DEEA), fontSize: 11.5),
    ),
  );
}

class _CompanionCard extends StatelessWidget {
  const _CompanionCard({required this.fairy, required this.cfg});
  final Fairy? fairy;
  final FairyConfig cfg;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final f = fairy;
    final color = f == null
        ? const Color(0x22FFFFFF)
        : fairyGradeColor(f.grade);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0x33121A10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: f == null ? 1 : 1.6),
      ),
      child: f == null
          ? Text(
              l.fairyNoCompanion,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white60, fontSize: 12.5),
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                fairyGlow(f, size: 72),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.fairyCompanion,
                        style: const TextStyle(color: _honey, fontSize: 10.5),
                      ),
                      _nameBlock(l, cfg.byId(f.kind), locale),
                      const SizedBox(height: 2),
                      _gradeLine(l, f),
                      ..._statLines(l, f, cfg),
                      _skillLine(l, f, cfg),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _FairyCell extends ConsumerWidget {
  const _FairyCell({
    required this.fairy,
    required this.onTap,
    this.companion = false,
    this.selected = false,
    this.dim = false,
    this.companionLabel,
  });
  final Fairy fairy;
  final VoidCallback onTap;
  final bool companion;
  final bool selected;

  /// 지금 고를 수 없는 칸(합성 창 — 종류·등급이 다르거나 착용 중).
  final bool dim;

  /// 동행 띠 글자(합성 창 = "착용 중"). null 이면 "동행 중".
  final String? companionLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final def = ref
        .watch(gameDataProvider)
        .value
        ?.fairyConfig
        ?.byId(fairy.kind);
    final c = fairyGradeColor(fairy.grade);
    // **가운데 정렬**(2026-10-01 실기 — Stack 기본 정렬이 왼쪽 위라 칸 안에서 왼쪽으로 쏠렸다).
    // 위: 등급 · Lv / 가운데: 그림 / 아래: 이름 · 하급~최상급.
    return Opacity(
      opacity: dim ? 0.38 : 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: BoxDecoration(
            color: selected
                ? c.withValues(alpha: 0.25)
                : const Color(0x33121A10),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected || companion ? c : c.withValues(alpha: 0.45),
              width: selected || companion ? 2 : 1,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(2, 3, 2, 3),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '${fairyGradeLabel(l, fairy.grade)} · ${l.fairyLevel('${fairy.level}')}',
                          style: TextStyle(
                            color: c,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Center(child: fairyGlow(fairy, size: 40)),
                            // 고른 표시는 **그림 위에** — 왼쪽 위 구석은 등급 글자에 가렸다(2026-10-08 실기).
                            if (selected) const _PickedMark(),
                          ],
                        ),
                      ),
                      // 동행(착용) 표시 = 이름 **바로 위** 글자 줄 — 다른 칸과 같은 짜임(2026-10-01 사장님).
                      if (companion)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xE63A2600),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              companionLabel ?? l.fairyIsCompanion,
                              style: const TextStyle(
                                color: _honey,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          def?.name.resolve(locale) ?? fairy.kind,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 분해 창에서 고른 칸 표시 — 그림 한가운데 진한 원 + 꿀색 체크.
class _PickedMark extends StatelessWidget {
  const _PickedMark();

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: Color(0xCC000000),
      shape: BoxShape.circle,
    ),
    padding: const EdgeInsets.all(1),
    child: const Icon(Icons.check_circle, size: 24, color: _honey),
  );
}

class _EggCell extends StatelessWidget {
  const _EggCell({
    required this.egg,
    required this.onTap,
    this.selected = false,
  });
  final FairyEgg egg;
  final VoidCallback onTap;

  /// 분해 창에서 고른 알.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = fairyGradeColor(egg.grade);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          color: selected ? c.withValues(alpha: 0.25) : const Color(0x22121A10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? c : c.withValues(alpha: 0.35),
            width: selected ? 2 : 1,
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      fairyEggImage(egg.grade, size: 44),
                      if (selected) const _PickedMark(),
                    ],
                  ),
                  Text(
                    fairyGradeLabel(l, egg.grade),
                    style: TextStyle(color: c, fontSize: 10.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 둥지 ─────────────────────────────────────────────────────

/// 요정 둥지(1칸). 비었으면 알·속성석을 골라 넣고, 차 있으면 남은 시간 · 가속기 · 꺼내기.
///
/// 종류는 넣는 순간 정해지지만 **깰 때까지 보여 주지 않는다**(깨는 순간이 두근거림이다).
class _NestDialog extends ConsumerStatefulWidget {
  const _NestDialog();

  @override
  ConsumerState<_NestDialog> createState() => _NestDialogState();
}

class _NestDialogState extends ConsumerState<_NestDialog> {
  FairyGrade? _grade;
  String? _stone;

  /// 속성석 목록 스크롤(막대를 늘 보이게 하려면 컨트롤러가 있어야 한다).
  final _stoneScroll = ScrollController();
  Timer? _tick;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _stoneScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final save = ref.watch(saveControllerProvider).requireValue;
    final cfg = ref.watch(gameDataProvider).value!.fairyConfig!;
    final f = save.fairy;
    final nest = f.nest;
    final close = TextButton(
      onPressed: () => Navigator.of(context).pop(),
      child: Text(l.actionClose),
    );
    if (nest == null) {
      return GameDialog(
        title: l.fairyNest,
        iconWidget: fairyNestImage(size: 40),
        actions: [
          close,
          // 알을 고르기 전에도 켜 둔다 — 꺼진 버튼(흐린 그림)이 "글씨가 안 보인다"로 읽혔다(2026-10-01).
          FilledButton(
            onPressed: _busy
                ? null
                : () => _grade == null
                      ? showCenterToast(
                          context,
                          f.eggs.isEmpty
                              ? l.fairyNestNoEgg
                              : l.fairyNestPickEgg,
                        )
                      : _place(f),
            child: Text(l.fairyNestPut),
          ),
        ],
        child: _pickBody(l, f, cfg),
      );
    }
    final left = nest.endsAt.difference(ref.read(clockProvider).now().toUtc());
    final ready = left <= Duration.zero;
    return GameDialog(
      title: l.fairyNest,
      iconWidget: fairyNestImage(size: 40),
      actions: [
        close,
        if (ready)
          FilledButton(
            onPressed: _busy ? null : _collect,
            child: Text(l.fairyNestCollect),
          ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          fairyEggImage(nest.grade, size: 92),
          const SizedBox(height: 6),
          Text(
            ready
                ? l.fairyNestReady
                : l.fairyNestLeft(formatShortDuration(left)),
            style: TextStyle(
              color: ready ? _honey : Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          if (!ready) ...[
            const SizedBox(height: 10),
            for (final a in cfg.accelerators) _accelRow(l, f, a),
          ],
        ],
      ),
    );
  }

  Widget _pickBody(AppLocalizations l, FairyState f, FairyConfig cfg) {
    if (f.eggs.isEmpty) {
      return Text(
        l.fairyNestNoEgg,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white70),
      );
    }
    final counts = <FairyGrade, int>{};
    for (final e in f.eggs) {
      counts[e.grade] = (counts[e.grade] ?? 0) + 1;
    }
    final grades = counts.keys.toList()
      ..sort((a, b) => b.index.compareTo(a.index));
    _grade ??= grades.first;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l.fairyNestEmpty,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          children: [
            for (final g in grades)
              _choice(
                selected: _grade == g,
                color: fairyGradeColor(g),
                onTap: () => setState(() => _grade = g),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    fairyEggImage(g, size: 34),
                    Text(
                      '${fairyGradeLabel(l, g)} ×${counts[g]}',
                      style: TextStyle(
                        color: fairyGradeColor(g),
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          l.fairyStone,
          style: const TextStyle(
            color: _honey,
            fontWeight: FontWeight.w800,
            fontSize: 12.5,
          ),
        ),
        const SizedBox(height: 6),
        // 속성석 = **한 줄에 하나**(이름 + 그 아래 효과) · 이 칸만 끌어서 내린다(2026-10-01 사장님 —
        // 격자일 땐 "받는 피해 감소"처럼 긴 이름이 두 줄로 내려가 칸 크기가 제각각이었다).
        SizedBox(
          height: 196,
          child: Scrollbar(
            controller: _stoneScroll,
            thumbVisibility: true,
            child: ListView(
              controller: _stoneScroll,
              padding: const EdgeInsets.only(right: 6),
              children: [
                _stoneRow(
                  l,
                  selected: _stone == null,
                  icon: const Icon(
                    Icons.block_rounded,
                    size: 22,
                    color: Colors.white38,
                  ),
                  name: l.fairyStoneNone,
                  effect: l.fairyNestKindHint('${cfg.kinds.length}'),
                  trailing: const SizedBox.shrink(),
                  onTap: () => setState(() => _stone = null),
                ),
                for (final sub in cfg.subWeight.keys)
                  _stoneRow(
                    l,
                    selected: _stone == sub,
                    icon: fairyStoneImage(sub, size: 30),
                    name: l.fairyStoneName(fairyStatLabel(l, sub)),
                    effect: l.fairyStoneEffect(
                      fairyStatLabel(l, sub),
                      (cfg.stoneChance * 100).round().toString(),
                    ),
                    trailing: (f.stones[sub] ?? 0) > 0
                        ? Text(
                            '×${f.stones[sub]}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          )
                        : jellyPrice(
                            cost: cfg.stoneJelly,
                            size: 13,
                            fontSize: 11,
                            color: const Color(0xFFFFE08A),
                          ),
                    onTap: () => _pickStone(f, cfg, sub),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _choice({
    required bool selected,
    required Color color,
    required VoidCallback onTap,
    required Widget child,
  }) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: Container(
      width: 64,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: selected
            ? color.withValues(alpha: 0.2)
            : const Color(0x22000000),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selected ? color : const Color(0x22FFFFFF),
          width: selected ? 1.6 : 1,
        ),
      ),
      child: Center(child: child),
    ),
  );

  Widget _stoneRow(
    AppLocalizations l, {
    required bool selected,
    required Widget icon,
    required String name,
    required String effect,
    required Widget trailing,
    required VoidCallback onTap,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
        decoration: BoxDecoration(
          color: selected
              ? _honey.withValues(alpha: 0.18)
              : const Color(0x22000000),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? _honey : const Color(0x22FFFFFF),
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            SizedBox(width: 32, height: 32, child: Center(child: icon)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    effect,
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 10.5,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            trailing,
          ],
        ),
      ),
    ),
  );

  /// 속성석 고르기 — 없으면 **젤리로 구입**하는 창(그 속성석의 그림·이름·효과)을 띄운다.
  Future<void> _pickStone(FairyState f, FairyConfig cfg, String sub) async {
    if ((f.stones[sub] ?? 0) > 0) {
      setState(() => _stone = sub);
      return;
    }
    final l = AppLocalizations.of(context);
    final name = l.fairyStoneName(fairyStatLabel(l, sub));
    final ok = await showGameDialog<bool>(
      context,
      title: l.fairyStoneBuyTitle,
      iconWidget: fairyStoneImage(sub, size: 40),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          fairyStoneImage(sub, size: 64),
          const SizedBox(height: 6),
          Text(
            name,
            style: const TextStyle(
              color: _honey,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l.fairyStoneEffect(
              fairyStatLabel(l, sub),
              (cfg.stoneChance * 100).round().toString(),
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 12.5),
          ),
        ],
      ),
      actions: [
        gameDialogButton(
          l.actionCancel,
          () => Navigator.of(context, rootNavigator: true).pop(false),
          primary: false,
        ),
        FilledButton(
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(true),
          child: jellyPrice(
            cost: cfg.stoneJelly,
            label: l.fairyStoneBuyAction,
            fontSize: 13,
          ),
        ),
      ],
    );
    if (ok != true || !mounted) return;
    final r = await ref
        .read(saveControllerProvider.notifier)
        .fairyBuyStone(sub);
    if (!mounted) return;
    if (!r.isOk) {
      showCenterToast(context, _err(l, r.error));
      return;
    }
    setState(() => _stone = sub);
  }

  Future<void> _place(FairyState f) async {
    final egg = f.eggs.where((e) => e.grade == _grade).firstOrNull;
    if (egg == null) {
      setState(() => _grade = null);
      showCenterToast(context, AppLocalizations.of(context).fairyNestPickEgg);
      return;
    }
    setState(() => _busy = true);
    final r = await ref
        .read(saveControllerProvider.notifier)
        .fairyPlaceEgg(egg.id, stoneSub: _stone);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!r.isOk) {
      showCenterToast(context, _err(AppLocalizations.of(context), r.error));
    }
  }

  Future<void> _collect() async {
    setState(() => _busy = true);
    final r = await ref
        .read(saveControllerProvider.notifier)
        .fairyCollectNest();
    if (!mounted) return;
    setState(() => _busy = false);
    final got = r.extra['fairy'];
    if (!r.isOk || got is! Fairy) {
      showCenterToast(context, _err(AppLocalizations.of(context), r.error));
      return;
    }
    // 둥지 창을 닫고 새 요정을 보여 준다 — 닫힌 창의 context 는 못 쓰므로 내비게이터 것을 쓴다.
    final nav = Navigator.of(context);
    nav.pop();
    await showDialog<void>(
      context: nav.context,
      barrierColor: const Color(0xB3000000),
      builder: (_) => fairyButtons(_NewFairyDialog(fairy: got)),
    );
  }

  Widget _accelRow(AppLocalizations l, FairyState f, FairyAccelDef a) {
    final owned = f.accelerators[a.id] ?? 0;
    final ctrl = ref.read(saveControllerProvider.notifier);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          fairyAccelImage(a.id, size: 30),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.fairyAccelMinutes(
                    formatShortDuration(Duration(minutes: a.minutes)),
                  ),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                  ),
                ),
                Text(
                  l.fairyOwned('$owned'),
                  style: const TextStyle(color: Colors.white60, fontSize: 10.5),
                ),
              ],
            ),
          ),
          if (owned > 0)
            FilledButton(
              onPressed: _busy
                  ? null
                  : () async {
                      // 연타로 여러 개가 쓰이지 않게 처리 중엔 막는다.
                      setState(() => _busy = true);
                      final r = await ctrl.fairyUseAccelerator(a.id);
                      if (!mounted) return;
                      setState(() => _busy = false);
                      if (!r.isOk) showCenterToast(context, _err(l, r.error));
                    },
              child: Text(l.fairyUse),
            )
          else
            OutlinedButton(
              onPressed: _busy
                  ? null
                  : () async {
                      final ok = await confirmJellySpend(
                        context,
                        title: l.fairyAccel,
                        body: l.fairyAccelMinutes(
                          formatShortDuration(Duration(minutes: a.minutes)),
                        ),
                        jelly: a.jelly,
                      );
                      if (!ok || !mounted) return;
                      setState(() => _busy = true);
                      final b = await ctrl.fairyBuyAccelerator(a.id);
                      if (!mounted) return;
                      if (!b.isOk) {
                        setState(() => _busy = false);
                        showCenterToast(context, _err(l, b.error));
                        return;
                      }
                      final u = await ctrl.fairyUseAccelerator(a.id);
                      if (!mounted) return;
                      setState(() => _busy = false);
                      if (!u.isOk) showCenterToast(context, _err(l, u.error));
                    },
              child: jellyPrice(cost: a.jelly),
            ),
        ],
      ),
    );
  }
}

/// 새 요정이 나왔을 때(부화·합성).
class _NewFairyDialog extends ConsumerWidget {
  const _NewFairyDialog({required this.fairy});
  final Fairy fairy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final cfg = ref.watch(gameDataProvider).value!.fairyConfig!;
    final def = cfg.byId(fairy.kind);
    return GameDialog(
      title: l.fairyNew,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.actionClose),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          fairyGlow(fairy, size: 120),
          _nameBlock(l, def, locale),
          const SizedBox(height: 4),
          _gradeLine(l, fairy),
          ..._statLines(l, fairy, cfg),
          _skillLine(l, fairy, cfg),
        ],
      ),
    );
  }
}

// ── 요정 상세 ─────────────────────────────────────────────────

class _FairyDetailDialog extends ConsumerStatefulWidget {
  const _FairyDetailDialog({required this.id});
  final String id;

  @override
  ConsumerState<_FairyDetailDialog> createState() => _FairyDetailState();
}

class _FairyDetailState extends ConsumerState<_FairyDetailDialog> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final save = ref.watch(saveControllerProvider).requireValue;
    final cfg = ref.watch(gameDataProvider).value!.fairyConfig!;
    final fs = save.fairy;
    final f = fs.fairyById(widget.id);
    if (f == null) return const SizedBox.shrink();
    final def = cfg.byId(f.kind);
    final isComp = fs.companionId == f.id;
    final maxLv = f.level >= cfg.maxLevelOf(f.grade);
    final cost = cfg.levelCost(f.grade, f.level);
    final ctrl = ref.read(saveControllerProvider.notifier);

    Future<void> run(Future<FairyOp> Function() op) async {
      setState(() => _busy = true);
      final r = await op();
      if (!mounted) return;
      setState(() => _busy = false);
      if (!r.isOk) showCenterToast(this.context, _err(l, r.error));
    }

    return GameDialog(
      title: def?.name.resolve(locale) ?? '?',
      subtitle: def?.title.resolve(locale),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.actionClose),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 도움말 — 등급별 능력치 범위 · 부가 능력치 종류 · 하급~최상급 · 레벨.
          Align(
            alignment: Alignment.centerRight,
            child: InkWell(
              onTap: () => _showFairyHelp(context, l, cfg, f),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.help_outline_rounded,
                      size: 16,
                      color: _honey,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      l.fairyHelpTitle,
                      style: const TextStyle(
                        color: _honey,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          fairyGlow(f, size: 110),
          _gradeLine(l, f),
          const SizedBox(height: 4),
          ..._statLines(l, f, cfg),
          _skillLine(l, f, cfg),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              // 동행 중이면 **동행 해제**(누를 수 있게) — 흐린 "동행 중"이 안 읽혔다(2026-10-01).
              FilledButton(
                onPressed: _busy
                    ? null
                    : () => run(
                        () => ctrl.fairySetCompanion(isComp ? null : f.id),
                      ),
                child: Text(isComp ? l.fairyStopCompanion : l.fairyGoCompanion),
              ),
              FilledButton.tonal(
                onPressed: maxLv || _busy
                    ? null
                    : () => run(() => ctrl.fairyLevelUp(f.id)),
                child: maxLv
                    ? Text(l.fairyMaxLevel)
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(l.fairyLevelUp),
                          const SizedBox(width: 4),
                          fairyDustImage(size: 14),
                          Text(
                            '$cost',
                            style: TextStyle(
                              color: fs.dust >= cost
                                  ? null
                                  : const Color(0xFFFF8A80),
                            ),
                          ),
                        ],
                      ),
              ),
              OutlinedButton(
                onPressed: f.grade.next == null || _busy
                    ? null
                    : isComp
                    // 동행 요정은 재료가 될 수 없다 — 눌러서 실패만 뜨면 이유를 모른다(2026-10-01 점검).
                    ? () => showCenterToast(context, l.fairyMergeEquipped)
                    : () => showDialog<void>(
                        context: context,
                        barrierColor: const Color(0xB3000000),
                        builder: (_) =>
                            fairyButtons(_MergeDialog(mainId: f.id)),
                      ),
                child: Text(l.fairyMerge),
              ),
              // 재굴림(2026-10-04) — 대기 결과가 있으면 그것부터 고르게 한다(다른 요정 것이어도).
              if (cfg.rerollJelly > 0 && cfg.rerollDailyCap > 0)
                OutlinedButton(
                  onPressed: _busy ? null : () => _reroll(f, cfg),
                  child: fs.reroll != null
                      ? Text(l.fairyRerollPending)
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 좁은 창에서 젤리 가격까지 한 줄에 안 들어가면 문구가 줄을 바꾼다(12px 넘침).
                            Flexible(
                              child: Text(
                                l.fairyReroll('${_rerollLeft(fs, cfg)}'),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            if (_rerollLeft(fs, cfg) > 0) ...[
                              const SizedBox(width: 4),
                              jellyPrice(cost: cfg.rerollJelly),
                            ],
                          ],
                        ),
                ),
              OutlinedButton(
                onPressed: isComp || _busy ? null : () => _release(f, cfg),
                child: Text(l.fairyRelease),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _reroll(Fairy f, FairyConfig cfg) async {
    final l = AppLocalizations.of(context);
    final ctrl = ref.read(saveControllerProvider.notifier);
    final fs = ref.read(saveControllerProvider).requireValue.fairy;
    // 고르지 않은 결과가 남아 있으면(앱을 껐다 켬 등) 새로 굴리지 않고 그것부터 고른다.
    if (fs.reroll == null) {
      if (_rerollLeft(fs, cfg) <= 0) {
        showCenterToast(context, l.fairyRerollCap);
        return;
      }
      final ok = await confirmJellySpend(
        context,
        title: l.fairyRerollTitle,
        body: l.fairyRerollConfirm,
        jelly: cfg.rerollJelly,
      );
      if (!ok || !mounted) return;
      setState(() => _busy = true);
      final r = await ctrl.fairyReroll(f.id);
      if (!mounted) return;
      setState(() => _busy = false);
      if (!r.isOk) {
        showCenterToast(context, _err(l, r.error));
        return;
      }
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: const Color(0xB3000000),
      builder: (_) => fairyButtons(const _RerollChooseDialog()),
    );
  }

  Future<void> _release(Fairy f, FairyConfig cfg) async {
    final l = AppLocalizations.of(context);
    final dust =
        (releaseFairy(
              ref.read(saveControllerProvider).requireValue.fairy,
              cfg,
              f.id,
            ).extra['dust']
            as int?) ??
        0;
    final ok = await _confirm(
      context,
      l.fairyRelease,
      l.fairyReleaseConfirm('$dust'),
    );
    if (!ok || !mounted) return;
    final r = await ref
        .read(saveControllerProvider.notifier)
        .fairyRelease(f.id);
    if (!mounted) return;
    if (!r.isOk) {
      showCenterToast(context, _err(l, r.error));
      return;
    }
    Navigator.of(context).pop();
  }
}

/// 오늘 남은 재굴림 횟수(KST 날짜 — 서버와 같은 기준. 실제 판정은 서버가 한다).
int _rerollLeft(FairyState fs, FairyConfig cfg) {
  final k = DateTime.now().toUtc().add(const Duration(hours: 9));
  final today =
      '${k.year}-${k.month.toString().padLeft(2, '0')}-${k.day.toString().padLeft(2, '0')}';
  final used = fs.rerollDay == today ? fs.rerollCount : 0;
  return (cfg.rerollDailyCap - used).clamp(0, cfg.rerollDailyCap);
}

/// 재굴림 결과 고르기 — 지금 값과 새 값을 나란히 보여 준다. 바깥을 눌러 닫을 수 없다
/// (고르지 않고 나가도 결과는 세이브에 남아, 다음에 재굴림을 누르면 이 창이 다시 뜬다).
class _RerollChooseDialog extends ConsumerStatefulWidget {
  const _RerollChooseDialog();

  @override
  ConsumerState<_RerollChooseDialog> createState() => _RerollChooseState();
}

class _RerollChooseState extends ConsumerState<_RerollChooseDialog> {
  bool _busy = false;

  Future<void> _choose(bool accept) async {
    setState(() => _busy = true);
    final r = await ref
        .read(saveControllerProvider.notifier)
        .fairyRerollChoose(accept: accept);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!r.isOk) {
      showCenterToast(context, _err(AppLocalizations.of(context), r.error));
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final save = ref.watch(saveControllerProvider).requireValue;
    final cfg = ref.watch(gameDataProvider).value!.fairyConfig!;
    final r = save.fairy.reroll;
    final f = r == null ? null : save.fairy.fairyById(r.fairyId);
    if (r == null || f == null) {
      // 고를 것이 없다(이미 골랐거나 요정이 사라짐). 사라진 요정의 결과는 서버에서 지운다.
      return GameDialog(
        title: l.fairyRerollTitle,
        actions: [
          FilledButton(
            onPressed: _busy
                ? null
                : r == null
                ? () => Navigator.of(context).pop()
                : () => _choose(false),
            child: Text(l.actionClose),
          ),
        ],
        child: const SizedBox.shrink(),
      );
    }
    final next = Fairy(
      id: f.id,
      kind: f.kind,
      grade: f.grade,
      sub: r.sub,
      baseRoll: r.baseRoll,
      subRoll: r.subRoll,
      level: f.level,
    );
    // 위아래로 쌓는다 — 좌우 두 열이면 360dp 에서 열마다 글자 칸이 80px 남짓이라 줄이 2~3번 꺾였다.
    Widget block(String head, Fairy x, Color color) => Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      decoration: BoxDecoration(
        color: const Color(0x22000000),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Text(
            head,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          ..._statLines(l, x, cfg),
        ],
      ),
    );
    return GameDialog(
      title: l.fairyRerollTitle,
      subtitle: l.fairyRerollPick,
      actions: [
        // 고르지 않고 닫기 — 결과는 남아 다음에 재굴림을 누르면 다시 뜬다. 연결이 끊겨 두 버튼이 다 실패해도
        // 창에 갇히지 않게(iOS 는 뒤로가기가 없다, 2026-10-04 출시 전 리뷰).
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(l.actionClose),
        ),
        TextButton(
          onPressed: _busy ? null : () => _choose(false),
          child: Text(l.fairyRerollKeep),
        ),
        FilledButton(
          onPressed: _busy ? null : () => _choose(true),
          child: Text(l.fairyRerollTake),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          fairyGlow(f, size: 72),
          _gradeLine(l, f),
          const SizedBox(height: 8),
          block(l.fairyRerollNow, f, Colors.white70),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 2),
            child: Icon(
              Icons.arrow_downward_rounded,
              size: 18,
              color: Colors.white54,
            ),
          ),
          block(l.fairyRerollNew, next, _honey),
        ],
      ),
    );
  }
}

// ── 합성 ─────────────────────────────────────────────────────

/// [mainId] 에 같은 종류·등급 요정을 더 골라 합친다. 결과 능력치는 새로 굴린다(design_fairy.md §1.6).
class _MergeDialog extends ConsumerStatefulWidget {
  const _MergeDialog({required this.mainId});
  final String mainId;

  @override
  ConsumerState<_MergeDialog> createState() => _MergeDialogState();
}

class _MergeDialogState extends ConsumerState<_MergeDialog> {
  final _picked = <String>[];
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final save = ref.watch(saveControllerProvider).requireValue;
    final cfg = ref.watch(gameDataProvider).value!.fairyConfig!;
    final fs = save.fairy;
    final main = fs.fairyById(widget.mainId);
    if (main == null) return const SizedBox.shrink();
    // 재료 등급마다 마릿수가 다르다(2026-10-04: 영웅 → 전설만 4마리).
    final need = cfg.mergeCountOf(main.grade) - 1;
    final cands = [
      for (final x in fs.fairies)
        if (x.id != main.id &&
            x.id != fs.companionId &&
            x.kind == main.kind &&
            x.grade == main.grade)
          x,
    ]..sort(_fairyOrder);
    return GameDialog(
      title: l.fairyMerge,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.actionCancel),
        ),
        FilledButton(
          onPressed: _picked.length == need && !_busy ? () => _go(main) : null,
          child: Text(l.fairyMerge),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l.fairyMergeHint('${need + 1}'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 11.5),
          ),
          const SizedBox(height: 8),
          if (cands.length < need)
            Text(
              l.fairyMergeNoMat,
              style: const TextStyle(color: Color(0xFFFF8A80), fontSize: 12),
            )
          else ...[
            Text(
              l.fairyMergePick('${_picked.length}', '$need'),
              style: const TextStyle(color: _honey, fontSize: 12),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: 280,
              height: 190,
              child: GridView(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 72,
                  mainAxisSpacing: 5,
                  crossAxisSpacing: 5,
                  childAspectRatio: 0.72,
                ),
                children: [
                  for (final x in cands)
                    _FairyCell(
                      fairy: x,
                      selected: _picked.contains(x.id),
                      onTap: () => setState(() {
                        if (_picked.remove(x.id)) return;
                        if (_picked.length < need) _picked.add(x.id);
                      }),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _go(Fairy main) async {
    if (!await _confirmInvested(context, ref, [main.id, ..._picked])) return;
    if (!mounted) return;
    setState(() => _busy = true);
    final r = await ref.read(saveControllerProvider.notifier).fairyMerge([
      main.id,
      ..._picked,
    ]);
    if (!mounted) return;
    setState(() => _busy = false);
    final made = r.extra['fairy'];
    if (!r.isOk || made is! Fairy) {
      showCenterToast(context, _err(AppLocalizations.of(context), r.error));
      return;
    }
    _toastRefund(context, r);
    // 합성 창과 (이제 없어진) 요정의 상세 창을 닫고 새 요정을 보여 준다.
    final nav = Navigator.of(context);
    nav.pop();
    nav.pop();
    await showDialog<void>(
      context: nav.context,
      barrierColor: const Color(0xB3000000),
      builder: (_) => fairyButtons(_NewFairyDialog(fairy: made)),
    );
  }
}

/// 합성 창(2026-10-01 사장님) — 재료를 **직접 고르거나** 자동 합성. 착용 중은 "착용 중"으로 보이고 못 고른다.
/// 첫 번째로 고른 요정이 종류·등급을 정하고, 나머지는 같은 종류·등급만 고를 수 있다.
class _MergeHubDialog extends ConsumerStatefulWidget {
  const _MergeHubDialog();

  @override
  ConsumerState<_MergeHubDialog> createState() => _MergeHubDialogState();
}

class _MergeHubDialogState extends ConsumerState<_MergeHubDialog> {
  final _picked = <String>[];
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final save = ref.watch(saveControllerProvider).requireValue;
    final cfg = ref.watch(gameDataProvider).value!.fairyConfig!;
    final fs = save.fairy;
    _picked.removeWhere((id) => fs.fairyById(id) == null);
    final first = _picked.isEmpty ? null : fs.fairyById(_picked.first);
    final list = [...fs.fairies]..sort(_fairyOrder);
    bool pickable(Fairy x) =>
        x.id != fs.companionId &&
        x.grade.next != null &&
        (first == null || (x.kind == first.kind && x.grade == first.grade));
    // 첫 번째로 고른 요정의 등급이 마릿수를 정한다(영웅 → 전설만 4마리, 2026-10-04).
    final need = first == null ? cfg.mergeCount : cfg.mergeCountOf(first.grade);
    final epicNeed = cfg.mergeCountOf(FairyGrade.epic);
    return GameDialog(
      title: l.fairyMerge,
      iconWidget: gameImageChain(
        const ['assets/images/fairies/fairy_automerge.webp'],
        size: 40,
        fallback: const Icon(Icons.merge_type_rounded, color: _honey),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.actionCancel),
        ),
        TextButton(
          onPressed: _busy ? null : _auto,
          child: Text(l.fairyAutoMerge),
        ),
        FilledButton(
          onPressed: _picked.length == need && !_busy ? _go : null,
          child: Text(l.fairyMerge),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l.fairyMergeHint('$need'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 11.5),
          ),
          if (epicNeed != cfg.mergeCount && first == null)
            Text(
              l.fairyMergeEpicNote('$epicNeed'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: _honey, fontSize: 11.5),
            ),
          const SizedBox(height: 6),
          Text(
            l.fairyMergePick('${_picked.length}', '$need'),
            style: const TextStyle(
              color: _honey,
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                l.fairyMergeNoMat,
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
            )
          else
            SizedBox(
              width: 290,
              height: 250,
              child: GridView(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 72,
                  mainAxisSpacing: 5,
                  crossAxisSpacing: 5,
                  childAspectRatio: 0.72,
                ),
                children: [
                  for (final x in list)
                    _FairyCell(
                      fairy: x,
                      companion: x.id == fs.companionId,
                      companionLabel: l.fairyEquippedTag,
                      selected: _picked.contains(x.id),
                      dim: !_picked.contains(x.id) && !pickable(x),
                      onTap: () {
                        if (_picked.remove(x.id)) {
                          setState(() {});
                          return;
                        }
                        if (x.id == fs.companionId) {
                          showCenterToast(context, l.fairyMergeEquipped);
                          return;
                        }
                        if (!pickable(x) || _picked.length >= need) {
                          return;
                        }
                        setState(() => _picked.add(x.id));
                      },
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _go() async {
    if (!await _confirmInvested(context, ref, [..._picked])) return;
    if (!mounted) return;
    setState(() => _busy = true);
    final r = await ref.read(saveControllerProvider.notifier).fairyMerge([
      ..._picked,
    ]);
    if (!mounted) return;
    setState(() => _busy = false);
    final made = r.extra['fairy'];
    if (!r.isOk || made is! Fairy) {
      showCenterToast(context, _err(AppLocalizations.of(context), r.error));
      return;
    }
    _picked.clear();
    _toastRefund(context, r);
    await showDialog<void>(
      context: context,
      barrierColor: const Color(0xB3000000),
      builder: (_) => fairyButtons(_NewFairyDialog(fairy: made)),
    );
  }

  /// 자동 합성 — 예상(쓰는 수 → 남는 요정의 종류·등급)을 **먼저 보여 주고** 확인받는다(§2.7).
  /// 능력치는 실행할 때 새로 굴리므로 예상에는 종류·등급만 보인다.
  Future<void> _auto() async {
    final l = AppLocalizations.of(context);
    final ctrl = ref.read(saveControllerProvider.notifier);
    final dry = await ctrl.fairyAutoMerge(dryRun: true);
    final used = (dry.extra['used'] as int?) ?? 0;
    final preview = (dry.extra['made'] as List<Fairy>?) ?? const [];
    if (!mounted) return;
    if (used == 0) {
      showCenterToast(context, l.fairyAutoMergeNone);
      return;
    }
    final ok = await showGameDialog<bool>(
      context,
      title: l.fairyAutoMerge,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l.fairyAutoMergeConfirm('$used', '${preview.length}'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 12.5),
          ),
          const SizedBox(height: 10),
          _resultWrap(l, preview, showQuality: false),
        ],
      ),
      actions: [
        gameDialogButton(
          l.actionCancel,
          () => Navigator.of(context, rootNavigator: true).pop(false),
          primary: false,
        ),
        gameDialogButton(
          l.fairyAutoMerge,
          () => Navigator.of(context, rootNavigator: true).pop(true),
        ),
      ],
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    final r = await ctrl.fairyAutoMerge();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _picked.clear();
    });
    if (!r.isOk) {
      showCenterToast(context, _err(l, r.error));
      return;
    }
    // 실제 결과(새로 굴린 능력치 포함)를 한 번 더 보여 준다.
    final made = (r.extra['made'] as List<Fairy>?) ?? const [];
    await showGameDialog<void>(
      context,
      title: l.fairyAutoMergeDone,
      content: _resultWrap(l, made, showQuality: true),
      actions: [
        gameDialogButton(
          l.actionClose,
          () => Navigator.of(context, rootNavigator: true).pop(),
        ),
      ],
    );
  }

  Widget _resultWrap(
    AppLocalizations l,
    List<Fairy> fairies, {
    required bool showQuality,
  }) => ConstrainedBox(
    constraints: const BoxConstraints(maxHeight: 220),
    child: SingleChildScrollView(
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        alignment: WrapAlignment.center,
        children: [
          for (final f in fairies)
            Container(
              width: 62,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: const Color(0x33121A10),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: fairyGradeColor(f.grade)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  fairyGlow(f, size: 38),
                  Text(
                    fairyGradeLabel(l, f.grade),
                    style: TextStyle(
                      color: fairyGradeColor(f.grade),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (showQuality)
                    for (final e
                        in (ref
                                    .read(gameDataProvider)
                                    .value
                                    ?.fairyConfig
                                    ?.mainBonus(f) ??
                                const <String, double>{})
                            .entries
                            .take(1))
                      Text(
                        fairyStatValue(e.key, e.value),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}

// ── 분해 ─────────────────────────────────────────────────────

/// 분해 창(2026-10-06 사장님) — 요정·알을 **여러 개 골라** 한 번에 요정 가루로. 위에는 알 자동 분해 설정.
///
/// 등급 버튼은 그 등급의 **레벨 1 요정 + 알**을 한꺼번에 고른다(투자한 요정·동행은 빠진다 — 자동 합성과 같은 원칙).
/// 레벨을 올린 요정은 직접 눌러야 고를 수 있고, 분해 전에 한 번 더 알린다. ❌ 젤리 없음(§2.6).
class _ReleaseHubDialog extends ConsumerStatefulWidget {
  const _ReleaseHubDialog();

  @override
  ConsumerState<_ReleaseHubDialog> createState() => _ReleaseHubDialogState();
}

class _ReleaseHubDialogState extends ConsumerState<_ReleaseHubDialog> {
  final _fairies = <String>{};
  final _eggs = <String>{};
  bool _busy = false;

  /// 등급 버튼에 띄우는 등급 — 전설 이상은 한꺼번에 고르지 않는다(실수로 잃으면 크다).
  static const _bulkGrades = [
    FairyGrade.common,
    FairyGrade.rare,
    FairyGrade.epic,
  ];

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final save = ref.watch(saveControllerProvider).requireValue;
    final cfg = ref.watch(gameDataProvider).value!.fairyConfig!;
    final fs = save.fairy;
    _fairies.removeWhere((id) => fs.fairyById(id) == null);
    _eggs.removeWhere((id) => !fs.eggs.any((e) => e.id == id));
    final list = [...fs.fairies]..sort(_fairyOrder);
    final eggs = [...fs.eggs]
      ..sort((a, b) => b.grade.index.compareTo(a.grade.index));
    final preview = (_fairies.isEmpty && _eggs.isEmpty)
        ? null
        : releaseFairiesBulk(
            fs,
            cfg,
            fairyIds: [..._fairies],
            eggIds: [..._eggs],
          );
    final dust = (preview?.extra['dust'] as int?) ?? 0;
    final count = _fairies.length + _eggs.length;
    return GameDialog(
      title: l.fairyRelease,
      iconWidget: gameImageChain(
        const ['assets/images/fairies/fairy_release.webp'],
        size: 40,
        fallback: const Icon(Icons.recycling_rounded, color: _honey),
      ),
      // 다른 팝업과 같은 게임 버튼(기본 머티리얼 버튼은 팝업 배경에 글씨가 묻혔다 — 2026-10-08 실기).
      actions: [
        gameDialogButton(
          l.actionClose,
          () => Navigator.of(context).pop(),
          primary: false,
        ),
        gameDialogButton(
          count > 0 ? '${l.fairyRelease} ($count)' : l.fairyRelease,
          () {
            if (count > 0 && !_busy) _go(cfg);
          },
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _autoRow(l, fs),
          const Divider(color: Color(0x33FFFFFF), height: 16),
          Text(
            l.fairyReleaseHint,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 11.5),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            alignment: WrapAlignment.center,
            children: [for (final g in _bulkGrades) _gradeChip(l, fs, g)],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                l.fairyReleasePicked('$count'),
                style: const TextStyle(
                  color: _honey,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 8),
              fairyDustImage(size: 14),
              const SizedBox(width: 2),
              Text(
                '+${formatCompact(dust)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (list.isEmpty && eggs.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                l.fairyEmptyBox,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
            )
          else
            SizedBox(
              width: 290,
              height: 230,
              child: GridView(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 72,
                  mainAxisSpacing: 5,
                  crossAxisSpacing: 5,
                  childAspectRatio: 0.72,
                ),
                children: [
                  for (final x in list)
                    _FairyCell(
                      fairy: x,
                      companion: x.id == fs.companionId,
                      companionLabel: l.fairyEquippedTag,
                      selected: _fairies.contains(x.id),
                      dim: x.id == fs.companionId,
                      onTap: () {
                        if (x.id == fs.companionId) {
                          showCenterToast(context, l.fairyReleaseEquipped);
                          return;
                        }
                        setState(() {
                          if (!_fairies.remove(x.id)) _fairies.add(x.id);
                        });
                      },
                    ),
                  for (final e in eggs)
                    _EggCell(
                      egg: e,
                      selected: _eggs.contains(e.id),
                      onTap: () => setState(() {
                        if (!_eggs.remove(e.id)) _eggs.add(e.id);
                      }),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// 알 자동 분해 — 끄기 · 일반 · 희귀 이하 · 영웅 이하.
  Widget _autoRow(AppLocalizations l, FairyState fs) {
    final cur = fs.autoReleaseUpTo;
    Widget opt(FairyGrade? g) {
      final on = cur == g;
      final text = g == null
          ? l.fairyAutoReleaseOff
          : g == FairyGrade.common
          ? fairyGradeLabel(l, g)
          : l.fairyAutoReleaseUpTo(fairyGradeLabel(l, g));
      return _ReleasePill(
        text: text,
        color: g == null ? Colors.white70 : fairyGradeColor(g),
        on: on,
        onTap: _busy || on
            ? null
            : () async {
                setState(() => _busy = true);
                await ref
                    .read(saveControllerProvider.notifier)
                    .fairySetAutoRelease(g);
                if (mounted) setState(() => _busy = false);
              },
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l.fairyAutoReleaseTitle,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12.5,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          alignment: WrapAlignment.center,
          children: [
            opt(null),
            for (final g in FairyGrade.values)
              if (g.index <= kFairyAutoReleaseMax.index) opt(g),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          l.fairyAutoReleaseHelp,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white54, fontSize: 10.5),
        ),
      ],
    );
  }

  /// 등급 버튼 — 그 등급의 레벨 1 요정(동행·재굴림 대기 제외) + 알을 모두 고른다. 다 골라져 있으면 푼다.
  Widget _gradeChip(AppLocalizations l, FairyState fs, FairyGrade g) {
    final fIds = [
      for (final f in fs.fairies)
        if (f.grade == g && fairyIsFodder(fs, f)) f.id,
    ];
    final eIds = [
      for (final e in fs.eggs)
        if (e.grade == g) e.id,
    ];
    final n = fIds.length + eIds.length;
    final all =
        n > 0 && fIds.every(_fairies.contains) && eIds.every(_eggs.contains);
    final c = fairyGradeColor(g);
    return _ReleasePill(
      text: l.fairyReleaseAllOf(fairyGradeLabel(l, g), '$n'),
      color: c,
      on: all,
      dim: n == 0,
      onTap: n == 0
          ? null
          : () => setState(() {
              if (all) {
                _fairies.removeAll(fIds);
                _eggs.removeAll(eIds);
              } else {
                _fairies.addAll(fIds);
                _eggs.addAll(eIds);
              }
            }),
    );
  }

  Future<void> _go(FairyConfig cfg) async {
    final l = AppLocalizations.of(context);
    final fs = ref.read(saveControllerProvider).requireValue.fairy;
    final pre = releaseFairiesBulk(
      fs,
      cfg,
      fairyIds: [..._fairies],
      eggIds: [..._eggs],
    );
    if (!pre.isOk) {
      showCenterToast(context, _err(l, pre.error));
      return;
    }
    final dust = (pre.extra['dust'] as int?) ?? 0;
    // 레벨을 올렸거나 전설 이상인 요정이 끼면 한 번 더 알린다(모르고 잃지 않게).
    final valuable = [
      for (final id in _fairies) ?fs.fairyById(id),
    ].where((f) => f.level > 1 || f.grade.index >= FairyGrade.legendary.index);
    final body = [
      l.fairyReleaseBulkConfirm('${_fairies.length + _eggs.length}', '$dust'),
      if (valuable.isNotEmpty) l.fairyReleaseValuableNote('${valuable.length}'),
    ].join('\n\n');
    final ok = await _confirm(context, l.fairyRelease, body);
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    final r = await ref
        .read(saveControllerProvider.notifier)
        .fairyReleaseBulk(fairyIds: [..._fairies], eggIds: [..._eggs]);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (r.isOk) {
        _fairies.clear();
        _eggs.clear();
      }
    });
    showCenterToast(
      context,
      r.isOk ? l.fairyReleaseDone('${r.extra['dust'] ?? 0}') : _err(l, r.error),
    );
  }
}

// ── 뽑기 ─────────────────────────────────────────────────────

class _GachaDialog extends ConsumerStatefulWidget {
  const _GachaDialog();

  @override
  ConsumerState<_GachaDialog> createState() => _GachaDialogState();
}

class _GachaDialogState extends ConsumerState<_GachaDialog> {
  bool _busy = false;
  bool _odds = false;
  List<FairyGrade> _last = const [];

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final save = ref.watch(saveControllerProvider).requireValue;
    final cfg = ref.watch(gameDataProvider).value!.fairyConfig!;
    final left = (cfg.gachaPity - save.fairy.gachaPity).clamp(1, cfg.gachaPity);
    final total = cfg.gachaWeights.values.fold<double>(0, (a, b) => a + b);
    return GameDialog(
      title: l.fairyGacha,
      iconWidget: fairyEggImage(FairyGrade.legendary, size: 40),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.actionClose),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l.fairyGachaPity('$left'),
            style: const TextStyle(color: _honey, fontSize: 12.5),
          ),
          const SizedBox(height: 10),
          // 좁은 폰에선 두 버튼이 한 줄에 안 들어간다(360 폭에서 58px 넘침) — 넘치면 내려간다.
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              FilledButton(
                onPressed: _busy ? null : () => _draw(1),
                child: jellyPrice(
                  cost: cfg.gachaJelly,
                  label: l.fairyGachaOne,
                  fontSize: 13,
                ),
              ),
              FilledButton(
                onPressed: _busy ? null : () => _draw(10),
                child: jellyPrice(
                  cost: cfg.gachaJelly * 10,
                  label: l.fairyGachaTen,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          if (_last.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              l.fairyGachaGot('${_last.length}'),
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 2,
              runSpacing: 2,
              alignment: WrapAlignment.center,
              children: [for (final g in _last) fairyEggImage(g, size: 30)],
            ),
          ],
          // 팝업 안 TextButton 은 회색 나무 그림이 깔려 꿀색 글씨가 흐렸다 — 밑줄 글자 링크로.
          InkWell(
            onTap: () => setState(() => _odds = !_odds),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              child: Text(
                l.fairyGachaOdds,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _honey,
                  fontWeight: FontWeight.w800,
                  decoration: TextDecoration.underline,
                  decorationColor: _honey,
                ),
              ),
            ),
          ),
          if (_odds && total > 0) ...[
            // 확률 공개(확률형 아이템 표시 의무, §2.8).
            for (final g in FairyGrade.values)
              if ((cfg.gachaWeights[g] ?? 0) > 0)
                Text(
                  '${fairyGradeLabel(l, g)} '
                  '${(cfg.gachaWeights[g]! / total * 100).toStringAsFixed(1)}%',
                  style: TextStyle(color: fairyGradeColor(g), fontSize: 12),
                ),
            const SizedBox(height: 4),
            Text(
              l.fairyGachaOddsNote,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white60, fontSize: 10.5),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _draw(int times) async {
    final l = AppLocalizations.of(context);
    final cfg = ref.read(gameDataProvider).value!.fairyConfig!;
    // 요정함 빈칸보다 많이 뽑으면 **넘친 알은 가루가 된다** — 젤리를 쓰기 전에 알린다(2026-10-01 점검).
    final free = math.max(
      0,
      cfg.boxCapOf(
            ref.read(saveControllerProvider).requireValue.fairy.boxExtra,
          ) -
          ref.read(saveControllerProvider).requireValue.fairy.boxUsed,
    );
    final base = times == 1 ? l.fairyGachaOne : l.fairyGachaTen;
    final ok = await confirmJellySpend(
      context,
      title: l.fairyGacha,
      body: times > free
          ? '$base\n\n${l.fairyGachaOverflowWarn('$free', '${times - free}')}'
          : base,
      jelly: cfg.gachaJelly * times,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    final r = await ref.read(saveControllerProvider.notifier).fairyDraw(times);
    if (!mounted) return;
    final kept = (r.extra['kept'] as List<FairyGrade>?) ?? const [];
    final lost = (r.extra['overflowEggs'] as int?) ?? 0;
    final auto = (r.extra['autoEggs'] as int?) ?? 0;
    setState(() {
      _busy = false;
      // 가루가 된 알(넘침·자동 분해)은 알 그림으로 보여 주지 않는다 — 실제로 들어간 알만.
      _last = kept;
    });
    if (!r.isOk) {
      showCenterToast(context, _err(l, r.error));
    } else if (lost > 0 || auto > 0) {
      showCenterToast(
        context,
        [
          if (auto > 0)
            l.fairyAutoReleaseToast('$auto', '${r.extra['autoDust'] ?? 0}'),
          if (lost > 0)
            l.fairyOverflowToast('$lost', '${r.extra['overflowDust'] ?? 0}'),
        ].join('\n'),
      );
    }
  }
}

// ── 도감 ─────────────────────────────────────────────────────

/// 종류 × 등급(5) · 종류 × 부가 능력치(7) 두 축. 모은 칸은 빛나고, 못 모은 칸은 흐리다.
class _DexDialog extends ConsumerWidget {
  const _DexDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final save = ref.watch(saveControllerProvider).requireValue;
    final cfg = ref.watch(gameDataProvider).value!.fairyConfig!;
    final dex = save.fairy.dex;
    final subs = cfg.subWeight.keys.toList();
    var gradeHave = 0;
    var subHave = 0;
    for (final k in cfg.kinds) {
      for (final g in FairyGrade.values) {
        if (dex.contains(FairyState.dexKey(k.id, g))) gradeHave++;
      }
      for (final s in subs) {
        if (dex.contains(FairyState.dexSubKey(k.id, s))) subHave++;
      }
    }
    return GameDialog(
      title: l.fairyDex,
      subtitle:
          '${l.fairyDexGrades('$gradeHave', '${cfg.kinds.length * FairyGrade.values.length}')}'
          ' · ${l.fairyDexSubs('$subHave', '${cfg.kinds.length * subs.length}')}',
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.actionClose),
        ),
      ],
      child: SizedBox(
        width: 300,
        height: 420,
        child: ListView(
          children: [
            // 도감이 무엇인지 — "점과 돌이 뭘 뜻하는지 모르겠다"(2026-10-01 실기 지적).
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0x22FFD54F),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.fairyDexHelp,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l.fairyDexLegendGrades,
                    style: const TextStyle(
                      color: _honey,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Wrap(
                    spacing: 8,
                    runSpacing: 3,
                    children: [
                      for (final g in FairyGrade.values)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: fairyGradeColor(g),
                              ),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              fairyGradeLabel(l, g),
                              style: TextStyle(
                                color: fairyGradeColor(g),
                                fontSize: 10.5,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l.fairyDexLegendSubs,
                    style: const TextStyle(
                      color: _honey,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Wrap(
                    spacing: 8,
                    runSpacing: 3,
                    children: [
                      for (final sub in subs)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            fairyStoneImage(sub, size: 14),
                            const SizedBox(width: 2),
                            Text(
                              fairyStatLabel(l, sub),
                              style: const TextStyle(
                                color: Color(0xCCFFFFFF),
                                fontSize: 10.5,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
            _DexMilestones(have: dex.length),
            const SizedBox(height: 10),
            for (final k in cfg.kinds)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Opacity(
                      opacity: dex.any((x) => x.startsWith('${k.id}:'))
                          ? 1
                          : 0.3,
                      child: fairyPortrait(k.id, size: 38),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            k.name.resolve(locale),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 2),
                          // 좁은 폰에선 등급 점 5 + 속성석 7 이 한 줄에 안 들어간다 — 넘치면 내려간다.
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            runSpacing: 2,
                            children: [
                              for (final g in FairyGrade.values)
                                Container(
                                  width: 12,
                                  height: 12,
                                  margin: const EdgeInsets.only(right: 3),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color:
                                        dex.contains(FairyState.dexKey(k.id, g))
                                        ? fairyGradeColor(g)
                                        : const Color(0x22FFFFFF),
                                  ),
                                ),
                              const SizedBox(width: 6),
                              for (final s in subs)
                                Opacity(
                                  opacity:
                                      dex.contains(
                                        FairyState.dexSubKey(k.id, s),
                                      )
                                      ? 1
                                      : 0.18,
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 1),
                                    child: fairyStoneImage(s, size: 15),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 요정 창 버튼 색(2026-10-01 실기 지적 — 기본 버튼 색이 어두운 창 배경과 겹쳐 "둥지에 넣기"·"1회/10회"
/// 글씨가 안 보였다). 주 버튼 = 꿀색 바탕 + 진한 글씨(게임 대화상자 `gameDialogButton` 과 같다),
/// 닫기·취소 = 밝은 글씨, 테두리 버튼 = 꿀색. 꺼진 버튼도 글씨가 읽히게 둔다.
Widget fairyButtons(Widget child) => Builder(
  builder: (context) {
    // ⚠️ 채움·글자 버튼(FilledButton·TextButton)은 **건드리지 않는다** — 팝업(GameDialog)이 나무·황동
    // 그림 버튼 + 크림 글씨를 입히는데, 여기서 꿀색 바탕을 깔면 크림 글씨가 노란 바탕에 묻혔다
    // (2026-10-01 실기: "닫기·둥지에 넣기 글씨가 안 보인다"). 테두리 버튼만 꿀색으로 맞춘다.
    final t = Theme.of(context);
    return Theme(
      data: t.copyWith(
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: _honey,
            side: const BorderSide(color: _honey),
            disabledForegroundColor: const Color(0x66FFFFFF),
            textStyle: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ),
      child: child,
    );
  },
);

/// 요정 창 바로 열기 — 개발자 모드 요정 메뉴가 쓴다(요정 탭으로 가지 않고 확인).
Future<void> openFairyWindow(BuildContext context, String which) =>
    showDialog<void>(
      context: context,
      barrierColor: const Color(0xB3000000),
      builder: (_) => fairyButtons(switch (which) {
        'nest' => const _NestDialog(),
        'gacha' => const _GachaDialog(),
        _ => const _DexDialog(),
      }),
    );

/// 요정 도감 마일스톤 — 칸을 모을수록 요정 가루·가속기·화석(젤리 없음). 앞에서부터 차례로 받는다.
class _DexMilestones extends ConsumerStatefulWidget {
  const _DexMilestones({required this.have});
  final int have;

  @override
  ConsumerState<_DexMilestones> createState() => _DexMilestonesState();
}

class _DexMilestonesState extends ConsumerState<_DexMilestones> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final save = ref.watch(saveControllerProvider).requireValue;
    final cfg = ref.watch(gameDataProvider).value!.fairyConfig!;
    final ms = cfg.dexMilestones;
    if (ms.isEmpty) return const SizedBox.shrink();
    final claimed = save.fairy.dexClaimed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.fairyDexRewards(widget.have, ms.last.count),
          style: const TextStyle(
            color: _honey,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        for (final (i, m) in ms.indexed)
          Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: i < claimed
                  ? const Color(0x14FFFFFF)
                  : const Color(0x22000000),
              borderRadius: BorderRadius.circular(8),
              border: i == claimed && widget.have >= m.count
                  ? Border.all(color: _honey)
                  : null,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 44,
                  child: Text(
                    '${m.count}',
                    style: TextStyle(
                      color: widget.have >= m.count ? _honey : Colors.white54,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ),
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 2,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (m.dust > 0)
                        _reward(fairyDustImage(size: 14), '${m.dust}'),
                      for (final e in m.accelerators.entries)
                        _reward(
                          fairyAccelImage(e.key, size: 14),
                          '×${e.value}',
                        ),
                      if (m.fossil > 0)
                        _reward(
                          materialImage(
                            MaterialKind.fossil,
                            size: 14,
                            fallback: const Text(
                              '🦴',
                              style: TextStyle(fontSize: 11),
                            ),
                          ),
                          '${m.fossil}',
                        ),
                    ],
                  ),
                ),
                if (i < claimed)
                  const Icon(Icons.check_circle, size: 16, color: _honey)
                else if (i == claimed && widget.have >= m.count)
                  SizedBox(
                    height: 26,
                    child: FilledButton(
                      onPressed: _busy ? null : _claim,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        textStyle: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      child: Text(l.eventRewardClaim),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _reward(Widget icon, String text) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      icon,
      const SizedBox(width: 2),
      Text(text, style: const TextStyle(color: Colors.white, fontSize: 11)),
    ],
  );

  Future<void> _claim() async {
    final l = AppLocalizations.of(context);
    setState(() => _busy = true);
    final ok = await ref.read(saveControllerProvider.notifier).fairyClaimDex();
    if (!mounted) return;
    setState(() => _busy = false);
    showCenterToast(context, ok ? l.fairyDexClaimed : l.fairyErrGeneric);
  }
}

/// 요정 도움말 — 등급별 기본 능력치 범위·최대 레벨, 부가 능력치 종류와 범위, 하급~최상급, 레벨 성장.
/// 숫자는 fairies.json 에서 읽는다(§6).
Future<void> _showFairyHelp(
  BuildContext context,
  AppLocalizations l,
  FairyConfig cfg,
  Fairy f,
) {
  String pct(double v) =>
      '${(v * 100).toStringAsFixed(v * 100 >= 10 ? 0 : 1)}%';
  TextStyle body = const TextStyle(
    color: Colors.white,
    fontSize: 12,
    height: 1.4,
  );
  Widget head(String t) => Padding(
    padding: const EdgeInsets.only(top: 10, bottom: 4),
    child: Text(
      t,
      style: const TextStyle(
        color: _honey,
        fontSize: 13,
        fontWeight: FontWeight.w900,
      ),
    ),
  );
  final sel = f.grade;
  final lo = cfg.gradeStatMin[sel] ?? 0, hi = cfg.gradeStatMax[sel] ?? 0;
  // 이 요정 종류의 기본 능력치 비중(볼테아 치명 피해 ×4 등) — 등급 범위에 곱해야 실제 값이다.
  final kindStats = cfg.byId(f.kind)?.stats ?? const <String, double>{};
  return showGameDialog<void>(
    context,
    title: l.fairyHelpTitle,
    icon: Icons.help_outline_rounded,
    content: ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 420),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            head(l.fairyHelpGradeHead),
            for (final g in FairyGrade.values)
              if (cfg.gradeStatMax[g] != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    l.fairyHelpGradeLine(
                      fairyGradeLabel(l, g),
                      [
                        for (final e in kindStats.entries)
                          '${fairyStatLabel(l, e.key)} '
                              '${pct((cfg.gradeStatMin[g] ?? 0) * e.value)}',
                      ].join(' · '),
                      [
                        for (final e in kindStats.entries)
                          pct((cfg.gradeStatMax[g] ?? 0) * e.value),
                      ].join(' · '),
                      '${cfg.maxLevelOf(g)}',
                    ),
                    style: body.copyWith(
                      color: fairyGradeColor(g),
                      fontWeight: g == sel ? FontWeight.w900 : null,
                    ),
                  ),
                ),
            Text(
              l.fairyHelpLevel(pct(cfg.levelStatPerLevel)),
              style: body.copyWith(color: Colors.white70, fontSize: 11.5),
            ),
            head(l.fairyHelpSubHead),
            Text(
              l.fairyHelpSub(pct(cfg.subRatio)),
              style: body.copyWith(color: Colors.white70, fontSize: 11.5),
            ),
            const SizedBox(height: 4),
            for (final e in cfg.subWeight.entries)
              Text(
                l.fairyHelpSubLine(
                  fairyStatLabel(l, e.key),
                  fairyGradeLabel(l, sel),
                  pct(lo * cfg.subRatio * e.value),
                  pct(hi * cfg.subRatio * e.value),
                ),
                style: body,
              ),
            head(l.fairyHelpMergeHead),
            Text(l.fairyHelpMerge('${cfg.mergeCount}'), style: body),
            if (cfg.mergeCountOf(FairyGrade.epic) != cfg.mergeCount)
              Text(
                l.fairyMergeEpicNote('${cfg.mergeCountOf(FairyGrade.epic)}'),
                style: body,
              ),
          ],
        ),
      ),
    ),
    actions: [
      gameDialogButton(
        l.actionClose,
        () => Navigator.of(context, rootNavigator: true).pop(),
      ),
    ],
  );
}

/// 직접 합성에 레벨을 올린 요정이 끼면 한 번 더 묻는다 — 돌려받는 가루(쓴 가루의 일부)를 함께 보여 준다.
/// (자동 합성은 투자한 요정을 아예 태우지 않는다. 직접 고른 것은 허용하되 모르고 잃지 않게.)
Future<bool> _confirmInvested(
  BuildContext context,
  WidgetRef ref,
  List<String> ids,
) async {
  final cfg = ref.read(gameDataProvider).value?.fairyConfig;
  final fs = ref.read(saveControllerProvider).requireValue.fairy;
  if (cfg == null) return true;
  final invested = [
    for (final id in ids) ?fs.fairyById(id),
  ].where((f) => f.level > 1).toList();
  if (invested.isEmpty) return true;
  final refund = invested.fold<int>(
    0,
    (a, f) =>
        a + (cfg.dustSpentTo(f.grade, f.level) * cfg.mergeDustRefund).floor(),
  );
  final l = AppLocalizations.of(context);
  return _confirm(
    context,
    l.fairyMerge,
    l.fairyMergeInvestedConfirm('${invested.length}', '$refund'),
  );
}

void _toastRefund(BuildContext context, FairyOp r) {
  final refund = (r.extra['refund'] as int?) ?? 0;
  if (refund > 0) {
    showCenterToast(
      context,
      AppLocalizations.of(context).fairyMergeRefund('$refund'),
    );
  }
}

/// 요정 정렬(요정함·합성 창 공용) — 등급 높은 순 → 레벨 높은 순 → 종류(같은 종류끼리 모인다) →
/// 능력치(개체값) 높은 순(2026-10-02 사장님).
int _fairyOrder(Fairy a, Fairy b) {
  final g = b.grade.index.compareTo(a.grade.index);
  if (g != 0) return g;
  final lv = b.level.compareTo(a.level);
  if (lv != 0) return lv;
  final k = a.kind.compareTo(b.kind);
  return k != 0 ? k : b.quality.compareTo(a.quality);
}

/// 분해 창의 알약 버튼(자동 분해 등급 · 등급 한꺼번에 고르기).
///
/// 머티리얼 칩은 "선택됨 + 누를 수 없음"(지금 고른 자동 분해 등급)을 비활성 회색으로 칠해 글씨가 안 보였다
/// (2026-10-08 실기). 그래서 진한 판 위에 굵은 글씨 + 그림자로 직접 그린다 — 고른 것은 그 색으로 채운다.
class _ReleasePill extends StatelessWidget {
  const _ReleasePill({
    required this.text,
    required this.color,
    required this.on,
    this.onTap,
    this.dim = false,
  });

  final String text;
  final Color color;
  final bool on;
  final bool dim;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: dim ? 0.45 : 1,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: on ? color : const Color(0xE61E1610),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: on ? Colors.white : color.withValues(alpha: 0.8),
              width: on ? 1.6 : 1.2,
            ),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: on ? const Color(0xFF1A1208) : color,
              shadows: on
                  ? null
                  : const [Shadow(color: Color(0xCC000000), blurRadius: 3)],
            ),
          ),
        ),
      ),
    );
  }
}

/// 요정함 확장 버튼(2026-10-08 사장님 확정 — 젤리 10칸씩, 첫 100젤리에서 살수록 비싸짐, 최대 60칸).
/// 채집함 확장과 같은 문구·확인창. 최대면 "최대 확장".
class _BoxExpandButton extends ConsumerWidget {
  const _BoxExpandButton({required this.cfg, required this.boxExtra});

  final FairyConfig cfg;
  final int boxExtra;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final cost = cfg.boxExpandCost(boxExtra);
    if (cfg.boxMax <= cfg.boxCap) return const SizedBox.shrink();
    if (cost == null) {
      return Text(
        l.storageExpandMaxed,
        style: const TextStyle(color: Colors.white54, fontSize: 11.5),
      );
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        if (!await confirmJellySpend(
          context,
          title: l.fairyBoxExpandTitle,
          body: l.fairyBoxExpandConfirm(cost, cfg.boxExpandAmount),
          jelly: cost,
          actionLabel: l.jellyActExpand,
        )) {
          return;
        }
        final r = await ref
            .read(saveControllerProvider.notifier)
            .fairyExpandBox();
        if (!context.mounted) return;
        showCenterToast(
          context,
          r.isOk ? l.fairyBoxExpanded : _err(l, r.error),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xE61E1610),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _honey.withValues(alpha: 0.8)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add_box_rounded, size: 14, color: _honey),
            const SizedBox(width: 3),
            Text(
              l.storageExpand(cfg.boxExpandAmount, cost),
              style: const TextStyle(
                color: _honey,
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
                shadows: [Shadow(color: Color(0xCC000000), blurRadius: 3)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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

const _honey = Color(0xFFFFD54F);

/// 요정 탭(docs/design_fairy.md §2) — 위 → 아래: [둥지][뽑기][도감][자동 합성] ·
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
        final g = b.grade.index.compareTo(a.grade.index);
        return g != 0 ? g : b.quality.compareTo(a.quality);
      });
    final eggs = [...f.eggs]
      ..sort((a, b) => b.grade.index.compareTo(a.grade.index));
    return Column(
      children: [
        _header(l, save, cfg),
        const SizedBox(height: 8),
        _CompanionCard(fairy: f.companion, cfg: cfg),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              l.fairyBoxTitle('${f.boxUsed}', '${cfg.boxCap}'),
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
                    childAspectRatio: 0.82,
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
  }

  Future<void> _open(Widget dialog) => showDialog<void>(
    context: context,
    barrierColor: const Color(0xB3000000),
    builder: (_) => dialog,
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
            const Icon(Icons.menu_book_rounded, size: 15, color: _honey),
            () => _open(const _DexDialog()),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: _btn(
            l.fairyAutoMerge,
            const Icon(Icons.merge_type_rounded, size: 15, color: _honey),
            _autoMerge,
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
          Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: badge ? _honey : Colors.white70,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    ),
  );

  /// 자동 합성 — 예상을 먼저 보여 주고 확인받는다(§2.7).
  Future<void> _autoMerge() async {
    final l = AppLocalizations.of(context);
    final ctrl = ref.read(saveControllerProvider.notifier);
    final dry = await ctrl.fairyAutoMerge(dryRun: true);
    final used = (dry.extra['used'] as int?) ?? 0;
    final made = (dry.extra['made'] as List<Fairy>?) ?? const [];
    if (!mounted) return;
    if (used == 0) {
      showCenterToast(context, l.fairyAutoMergeNone);
      return;
    }
    final ok = await _confirm(
      context,
      l.fairyAutoMerge,
      l.fairyAutoMergeConfirm('$used', '${made.length}'),
    );
    if (!ok) return;
    final r = await ctrl.fairyAutoMerge();
    if (!mounted) return;
    if (!r.isOk) showCenterToast(context, _err(l, r.error));
  }
}

String _err(AppLocalizations l, String? e) => switch (e) {
  'not_enough_jelly' => l.fairyErrJelly,
  'not_enough_dust' => l.fairyErrDust,
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
      TextButton(
        onPressed: () => Navigator.of(context, rootNavigator: true).pop(false),
        child: Text(l.actionCancel),
      ),
      FilledButton(
        onPressed: () => Navigator.of(context, rootNavigator: true).pop(true),
        child: Text(title),
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
  '${fairyGradeLabel(l, f.grade)} · ${l.fairyLevel('${f.level}')} · '
  '${l.fairyQuality((f.quality * 100).round().toString())}',
  style: TextStyle(
    color: fairyGradeColor(f.grade),
    fontWeight: FontWeight.w800,
    fontSize: 12,
  ),
);

/// 기본·부가 능력치 줄.
List<Widget> _statLines(AppLocalizations l, Fairy f, FairyConfig cfg) {
  Widget line(String tag, String key, double v) => Padding(
    padding: const EdgeInsets.only(top: 2),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: const Color(0x22FFFFFF),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            tag,
            style: const TextStyle(color: Colors.white60, fontSize: 9.5),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          '${fairyStatLabel(l, key)} ${fairyStatValue(key, v)}',
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ],
    ),
  );
  return [
    for (final e in cfg.mainBonus(f).entries)
      line(l.fairyStatMain, e.key, e.value),
    if (cfg.subBonus(f) > 0) line(l.fairyStatSub, f.sub, cfg.subBonus(f)),
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

class _FairyCell extends StatelessWidget {
  const _FairyCell({
    required this.fairy,
    required this.onTap,
    this.companion = false,
    this.selected = false,
  });
  final Fairy fairy;
  final VoidCallback onTap;
  final bool companion;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = fairyGradeColor(fairy.grade);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          color: selected ? c.withValues(alpha: 0.25) : const Color(0x33121A10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected || companion ? c : c.withValues(alpha: 0.45),
            width: selected || companion ? 2 : 1,
          ),
        ),
        child: Stack(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                fairyGlow(fairy, size: 46),
                Text(
                  'Lv.${fairy.level}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '${(fairy.quality * 100).round()}%',
                  style: TextStyle(color: c, fontSize: 9.5),
                ),
              ],
            ),
            if (companion)
              const Positioned(
                top: 3,
                right: 3,
                child: Icon(Icons.star_rounded, size: 13, color: _honey),
              ),
            if (selected)
              const Positioned(
                top: 3,
                left: 3,
                child: Icon(Icons.check_circle, size: 14, color: _honey),
              ),
          ],
        ),
      ),
    );
  }
}

class _EggCell extends StatelessWidget {
  const _EggCell({required this.egg, required this.onTap});
  final FairyEgg egg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = fairyGradeColor(egg.grade);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0x22121A10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: c.withValues(alpha: 0.35)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            fairyEggImage(egg.grade, size: 44),
            Text(
              fairyGradeLabel(l, egg.grade),
              style: TextStyle(color: c, fontSize: 10.5),
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
          FilledButton(
            onPressed: _grade == null || _busy ? null : () => _place(f),
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
        Wrap(
          spacing: 5,
          runSpacing: 5,
          alignment: WrapAlignment.center,
          children: [
            _choice(
              selected: _stone == null,
              color: Colors.white54,
              onTap: () => setState(() => _stone = null),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  l.fairyStoneNone,
                  style: const TextStyle(color: Colors.white70, fontSize: 10.5),
                ),
              ),
            ),
            for (final sub in cfg.subWeight.keys)
              _choice(
                selected: _stone == sub,
                color: _honey,
                onTap: () => _pickStone(f, cfg, sub),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    fairyStoneImage(sub, size: 22),
                    Text(
                      fairyStatLabel(l, sub),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9.5,
                      ),
                    ),
                    Text(
                      '×${f.stones[sub] ?? 0}',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _stone == null
              ? l.fairyNestKindHint
              : l.fairyStoneHint((cfg.stoneChance * 100).round().toString()),
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white60, fontSize: 11),
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

  /// 속성석 고르기 — 없으면 한 개 사서(젤리 확인) 고른다.
  Future<void> _pickStone(FairyState f, FairyConfig cfg, String sub) async {
    if ((f.stones[sub] ?? 0) > 0) {
      setState(() => _stone = sub);
      return;
    }
    final l = AppLocalizations.of(context);
    final ok = await confirmJellySpend(
      context,
      title: l.fairyStone,
      body: '${fairyStatLabel(l, sub)} · ${l.fairyBuy}',
      jelly: cfg.stoneJelly,
    );
    if (!ok || !mounted) return;
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
    if (egg == null) return;
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
    if (got is! Fairy) return;
    // 둥지 창을 닫고 새 요정을 보여 준다 — 닫힌 창의 context 는 못 쓰므로 내비게이터 것을 쓴다.
    final nav = Navigator.of(context);
    nav.pop();
    await showDialog<void>(
      context: nav.context,
      barrierColor: const Color(0xB3000000),
      builder: (_) => _NewFairyDialog(fairy: got),
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
                      final r = await ctrl.fairyUseAccelerator(a.id);
                      if (!mounted) return;
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
                      final b = await ctrl.fairyBuyAccelerator(a.id);
                      if (!mounted) return;
                      if (!b.isOk) {
                        showCenterToast(context, _err(l, b.error));
                        return;
                      }
                      final u = await ctrl.fairyUseAccelerator(a.id);
                      if (!mounted) return;
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
              FilledButton(
                onPressed: isComp || _busy
                    ? null
                    : () => run(() => ctrl.fairySetCompanion(f.id)),
                child: Text(isComp ? l.fairyIsCompanion : l.fairyGoCompanion),
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
                    : () => showDialog<void>(
                        context: context,
                        barrierColor: const Color(0xB3000000),
                        builder: (_) => _MergeDialog(mainId: f.id),
                      ),
                child: Text(l.fairyMerge),
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
    final need = cfg.mergeCount - 1;
    final cands = [
      for (final x in fs.fairies)
        if (x.id != main.id &&
            x.id != fs.companionId &&
            x.kind == main.kind &&
            x.grade == main.grade)
          x,
    ]..sort((a, b) => a.quality.compareTo(b.quality));
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
            l.fairyMergeHint('${cfg.mergeCount}'),
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
                  maxCrossAxisExtent: 70,
                  mainAxisSpacing: 5,
                  crossAxisSpacing: 5,
                  childAspectRatio: 0.82,
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
    // 합성 창과 (이제 없어진) 요정의 상세 창을 닫고 새 요정을 보여 준다.
    final nav = Navigator.of(context);
    nav.pop();
    nav.pop();
    await showDialog<void>(
      context: nav.context,
      barrierColor: const Color(0xB3000000),
      builder: (_) => _NewFairyDialog(fairy: made),
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
                  color: const Color(0xFF3A2600),
                ),
              ),
              FilledButton(
                onPressed: _busy ? null : () => _draw(10),
                child: jellyPrice(
                  cost: cfg.gachaJelly * 10,
                  label: l.fairyGachaTen,
                  color: const Color(0xFF3A2600),
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
          TextButton(
            onPressed: () => setState(() => _odds = !_odds),
            child: Text(l.fairyGachaOdds),
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
    final ok = await confirmJellySpend(
      context,
      title: l.fairyGacha,
      body: times == 1 ? l.fairyGachaOne : l.fairyGachaTen,
      jelly: cfg.gachaJelly * times,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    final r = await ref.read(saveControllerProvider.notifier).fairyDraw(times);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _last = (r.extra['grades'] as List<FairyGrade>?) ?? const [];
    });
    if (!r.isOk) showCenterToast(context, _err(l, r.error));
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
        height: 360,
        child: ListView(
          children: [
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
                          Row(
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

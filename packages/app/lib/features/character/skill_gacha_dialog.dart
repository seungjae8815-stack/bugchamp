import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:core_save/core_save.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/audio_service.dart';
import '../../domain/providers.dart';
import '../../domain/save_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/art.dart';
import '../../ui/game_dialog.dart';
import '../../ui/labels.dart';
import '../../ui/tier_label.dart';
import '../../ui/toast.dart';

/// 스킬 뽑기 창(§2.8) — 하루 무료 1회 · 1회 · 10회, 천장 표시, **확률 공개**.
///
/// ⚠️ 확률은 반드시 화면에서 볼 수 있어야 한다(확률형 아이템 표시 의무).
class SkillGachaDialog extends ConsumerStatefulWidget {
  const SkillGachaDialog({super.key, required this.cfg, required this.locale});
  final SkillConfig cfg;
  final String locale;

  @override
  ConsumerState<SkillGachaDialog> createState() => _SkillGachaDialogState();
}

class _SkillGachaDialogState extends ConsumerState<SkillGachaDialog> {
  List<SkillDraw> _last = const [];
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cfg = widget.cfg;
    final save = ref.watch(saveControllerProvider).requireValue;
    final ctrl = ref.read(saveControllerProvider.notifier);
    final used = ctrl.skillDailyUsedToday;
    final freeLeft = (cfg.gachaFreePerDay - used.freeDraws).clamp(0, 99);
    final pityLeft = (cfg.gachaPity - save.skillGachaPity).clamp(
      1,
      cfg.gachaPity,
    );
    final jelly = save.materialCount(MaterialKind.jelly);

    return GameDialog(
      title: l.skillGachaTitle,
      iconWidget: skillButtonImage(
        'gacha',
        size: 26,
        fallback: const Icon(Icons.auto_awesome_rounded, size: 22),
      ),
      subtitle: l.skillGachaPityLeft(
        gradeLabel(l, cfg.gachaPityGrade),
        '$pityLeft',
      ),
      actions: [
        TextButton(
          onPressed: () => _showOdds(l),
          child: Text(l.skillGachaOdds),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.actionClose),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_last.isNotEmpty) ...[
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  alignment: WrapAlignment.center,
                  children: [for (final d in _last) _resultChip(l, d)],
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (freeLeft > 0)
            FilledButton(
              onPressed: _busy ? null : () => _draw(l, 1, free: true),
              child: Text(
                '${l.skillGachaFree} · ${l.skillGachaFreeLeft('$freeLeft')}',
              ),
            ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonal(
                  onPressed: _busy || jelly < cfg.gachaJellyCost
                      ? null
                      : () => _draw(l, 1),
                  child: jellyPrice(
                    cost: cfg.gachaJellyCost,
                    times: l.skillTimes('1'),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: FilledButton.tonal(
                  onPressed: _busy || jelly < cfg.gachaJellyCost * 10
                      ? null
                      : () => _draw(l, 10),
                  child: jellyPrice(
                    cost: cfg.gachaJellyCost * 10,
                    times: l.skillTimes('10'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _resultChip(AppLocalizations l, SkillDraw d) {
    final color = gradeColor(d.grade);
    final name = widget.cfg.byId(d.id)?.name.resolve(widget.locale) ?? d.id;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      child: Text(
        l.skillGachaResult(name, '${d.shards}'),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Future<void> _draw(AppLocalizations l, int times, {bool free = false}) async {
    setState(() => _busy = true);
    final r = await ref
        .read(saveControllerProvider.notifier)
        .drawSkills(times: times, free: free);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (r.error == null) _last = r.draws;
    });
    if (r.error != null) {
      showCenterToast(
        context,
        r.error == 'not_enough_jelly' ? l.notEnoughJelly : r.error!,
      );
      return;
    }
    AudioService.instance.sfxReward();
  }

  void _showOdds(AppLocalizations l) {
    final cfg = widget.cfg;
    final odds = cfg.gachaGradeOdds;
    String pct(double v) => (v * 100).toStringAsFixed(v * 100 < 10 ? 2 : 1);
    showGameDialog<void>(
      context,
      title: l.skillGachaOddsTitle,
      icon: Icons.percent_rounded,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final g in kSkillGrades)
            if (odds[g] != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text(
                  l.skillGachaOddsGrade(
                    gradeLabel(l, g),
                    pct(odds[g]!),
                    pct(
                      odds[g]! /
                          cfg.skills
                              .where((s) => s.grade == g)
                              .length
                              .clamp(1, 99),
                    ),
                  ),
                  style: TextStyle(color: gradeColor(g), fontSize: 13),
                ),
              ),
          const SizedBox(height: 8),
          Text(
            l.skillGachaOddsNote(
              '${cfg.gachaShards}',
              '${cfg.gachaPity}',
              gradeLabel(l, cfg.gachaPityGrade),
            ),
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
          child: Text(l.actionClose),
        ),
      ],
    );
  }
}

/// 보스 소탕 창(§2.8) — 잡아 본 가장 높은 난이도 보스를 다시 잡은 것으로 쳐서 조각 확정.
class SkillSweepDialog extends ConsumerStatefulWidget {
  const SkillSweepDialog({super.key, required this.cfg, required this.locale});
  final SkillConfig cfg;
  final String locale;

  @override
  ConsumerState<SkillSweepDialog> createState() => _SkillSweepDialogState();
}

class _SkillSweepDialogState extends ConsumerState<SkillSweepDialog> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cfg = widget.cfg;
    final save = ref.watch(saveControllerProvider).requireValue;
    final run = ref.watch(gameDataProvider).value?.runConfig;
    final used = ref.read(saveControllerProvider.notifier).skillDailyUsedToday;
    final tier = run == null ? -1 : bestSweepTier(save, run);
    final freeLeft = (cfg.sweepFreePerDay - used.sweeps).clamp(0, 99);
    final limit = used.sweeps >= cfg.sweepMaxPerDay;

    // 유료 소탕만 젤리 가격표(아이콘+숫자)로 — 무료·상한은 글자가 맞다.
    final Widget label;
    if (tier < 0) {
      label = Text(l.skillSweepNoBoss);
    } else if (limit) {
      label = Text(l.skillSweepLimit);
    } else if (freeLeft > 0) {
      label = Text(l.skillSweepFree('$freeLeft'));
    } else {
      label = jellyPrice(cost: cfg.sweepJellyCost, label: l.skillSweep);
    }

    return GameDialog(
      title: l.skillSweepTitle,
      iconWidget: skillButtonImage(
        'sweep',
        size: 26,
        fallback: const Icon(Icons.flash_on_rounded, size: 22),
      ),
      subtitle: l.skillSweepToday('${used.sweeps}', '${cfg.sweepMaxPerDay}'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.actionClose),
        ),
        FilledButton(
          onPressed: _busy || tier < 0 || limit ? null : () => _sweep(l),
          child: label,
        ),
      ],
      child: Text(
        tier < 0
            ? l.skillSweepNoBoss
            : l.skillSweepDesc(
                tierName(l, tier),
                '${cfg.sweepShardsFor(tier)}',
              ),
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontSize: 13),
      ),
    );
  }

  Future<void> _sweep(AppLocalizations l) async {
    setState(() => _busy = true);
    final r = await ref.read(saveControllerProvider.notifier).sweepSkillBoss();
    if (!mounted) return;
    setState(() => _busy = false);
    if (r.error != null) {
      showCenterToast(context, switch (r.error) {
        'not_enough_jelly' => l.notEnoughJelly,
        'sweep_limit' => l.skillSweepLimit,
        'no_boss' => l.skillSweepNoBoss,
        _ => r.error!,
      });
      return;
    }
    AudioService.instance.sfxReward();
    final parts = [
      for (final e in r.shards.entries)
        l.skillGachaResult(
          widget.cfg.byId(e.key)?.name.resolve(widget.locale) ?? e.key,
          '${e.value}',
        ),
    ];
    showCenterToast(context, l.skillShardsGot(parts.join(', ')));
  }
}

import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:core_save/core_save.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/save_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/game_dialog.dart';
import '../../ui/labels.dart';
import '../../ui/toast.dart';

/// 등급 승급 창(§2.8) — 아래 등급을 고르고, 재료로 쓸 조각을 **직접 체크**한다.
///
/// 자동으로 고르지 않는 이유: 수련하려고 모은 조각까지 태우면 되돌릴 수 없다.
/// 기본은 아무것도 체크하지 않는다.
class SkillGradeUpDialog extends ConsumerStatefulWidget {
  const SkillGradeUpDialog({
    super.key,
    required this.cfg,
    required this.locale,
  });
  final SkillConfig cfg;
  final String locale;

  @override
  ConsumerState<SkillGradeUpDialog> createState() => _SkillGradeUpDialogState();
}

class _SkillGradeUpDialogState extends ConsumerState<SkillGradeUpDialog> {
  Grade _from = Grade.common;
  final Set<String> _picked = {};
  int _times = 1;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final save = ref.watch(saveControllerProvider).requireValue;
    final cfg = widget.cfg;
    final to = SkillConfig.nextGrade(_from)!;
    final sources = gradeUpSources(save, cfg, _from);
    final pickedTotal = [
      for (final id in _picked) sources[id] ?? 0,
    ].fold(0, (a, b) => a + b);
    final maxTimes = cfg.gradeUpRatio <= 0
        ? 0
        : pickedTotal ~/ cfg.gradeUpRatio;
    final times = maxTimes == 0 ? 0 : _times.clamp(1, maxTimes);
    final fromLabel = gradeLabel(l, _from);
    final toLabel = gradeLabel(l, to);

    return GameDialog(
      title: l.skillGradeUpTitle(fromLabel, toLabel),
      icon: Icons.diamond_rounded,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.actionCancel),
        ),
        FilledButton(
          onPressed: times <= 0 ? null : () => _make(l, to, times),
          child: Text(
            times <= 0 ? l.skillGradeUpPick : l.skillGradeUpMake('$times'),
          ),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 6,
            alignment: WrapAlignment.center,
            children: [
              for (final g in kSkillGrades.take(kSkillGrades.length - 1))
                ChoiceChip(
                  label: Text(
                    '${gradeLabel(l, g)} → '
                    '${gradeLabel(l, SkillConfig.nextGrade(g)!)}',
                  ),
                  selected: _from == g,
                  onSelected: (_) => setState(() {
                    _from = g;
                    _picked.clear();
                    _times = 1;
                  }),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l.skillGradeUpDesc('${cfg.gradeUpRatio}', fromLabel, toLabel),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final e in sources.entries)
                  CheckboxListTile(
                    dense: true,
                    value: _picked.contains(e.key),
                    onChanged: (v) => setState(() {
                      if (v == true) {
                        _picked.add(e.key);
                      } else {
                        _picked.remove(e.key);
                      }
                    }),
                    title: Text(
                      e.key == kGradeShardSource
                          ? l.skillGradeWild(fromLabel)
                          : (cfg.byId(e.key)?.name.resolve(widget.locale) ??
                                e.key),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                    subtitle: e.key == kGradeShardSource
                        ? null
                        : Text(
                            'Lv.${save.skillLevels[e.key] ?? 0}',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                            ),
                          ),
                    secondary: Text(
                      '${e.value}',
                      style: TextStyle(
                        color: gradeColor(_from),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (maxTimes > 1)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: times > 1
                      ? () => setState(() => _times = times - 1)
                      : null,
                  icon: const Icon(Icons.remove_rounded),
                  color: Colors.white,
                ),
                Text(
                  '$times / $maxTimes',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
                IconButton(
                  onPressed: times < maxTimes
                      ? () => setState(() => _times = times + 1)
                      : null,
                  icon: const Icon(Icons.add_rounded),
                  color: Colors.white,
                ),
                TextButton(
                  onPressed: () => setState(() => _times = maxTimes),
                  child: const Text('MAX'),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _make(AppLocalizations l, Grade to, int times) async {
    // 체크한 순서가 아니라 **목록 순서**로 꺼낸다 — 만능 조각이 맨 뒤라
    // 스킬 조각을 먼저 쓰고, 모자랄 때만 만능을 쓴다.
    final save = ref.read(saveControllerProvider).requireValue;
    final order = [
      for (final id in gradeUpSources(save, widget.cfg, _from).keys)
        if (_picked.contains(id)) id,
    ];
    final err = await ref
        .read(saveControllerProvider.notifier)
        .gradeUpSkillShards(from: _from, sources: order, times: times);
    if (!mounted) return;
    if (err != null) {
      showCenterToast(context, l.skillErrNotEnoughShards);
      return;
    }
    showCenterToast(context, l.skillGradeUpDone('$times', gradeLabel(l, to)));
    setState(() {
      _picked.clear();
      _times = 1;
    });
  }
}

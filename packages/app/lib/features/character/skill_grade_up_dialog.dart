import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:core_save/core_save.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/save_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/art.dart';
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
      // 제목은 **짧게**. "일반 조각 → 희귀 만능 조각" 은 제목 칸에서 어중간하게
      // 접혔다(실기 지적 2026-09-20). 무엇을 무엇으로 바꾸는지는 부제로 내린다.
      title: l.skillGradeUpShort,
      subtitle: l.skillGradeUpTitle(fromLabel, toLabel),
      iconWidget: skillButtonImage(
        'gradeup',
        size: 26,
        fallback: const Icon(Icons.diamond_rounded, size: 22),
      ),
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
          // 무엇을 무엇으로 바꾸는지 **그림으로** 보여 준다(사장님 지시
          // 2026-09-20). 글자 칩('일반 → 희귀')은 무슨 뜻인지도 모호했고,
          // 고른 것과 안 고른 것이 흰 판으로 똑같이 보였다.
          _ladder(l, cfg, save),
          const SizedBox(height: 10),
          // 이번에 고른 변환: 조각 N 개 → 만능 1 개.
          _recipe(l, cfg, fromLabel, toLabel),
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
                    // 무엇을 태우는지 그림으로도 보여 준다 — 이름만으로는
                    // 스킬 조각인지 만능 조각인지 헷갈린다.
                    secondary: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        skillShardImage(
                          _from,
                          size: 15,
                          wild: e.key == kGradeShardSource,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${e.value}',
                          style: TextStyle(
                            color: gradeColor(_from),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
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

  /// 등급 사다리 — `조각 ▸ 조각 ▸ 조각 ▸ 조각`. 사이의 화살표를 누르면
  /// 그 구간(아래 등급 → 위 등급)이 선택된다.
  ///
  /// 고른 구간은 화살표가 **꿀색으로 차고**, 양 끝 조각이 커진다. 무엇에서
  /// 무엇으로 가는지 한 줄에 다 보인다.
  Widget _ladder(AppLocalizations l, SkillConfig cfg, SaveGame save) {
    final grades = kSkillGrades;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < grades.length; i++) ...[
          if (i > 0) _arrow(grades[i - 1]),
          _rung(l, cfg, save, grades[i]),
        ],
      ],
    );
  }

  /// 사다리 한 칸 — 그 등급의 조각 그림과 보유 수.
  Widget _rung(AppLocalizations l, SkillConfig cfg, SaveGame save, Grade g) {
    // 이번 변환에 관계된 등급(출발·도착)만 또렷하게.
    final to = SkillConfig.nextGrade(_from);
    final lit = g == _from || g == to;
    var own = save.gradeShards(g);
    for (final def in cfg.skills) {
      if (def.grade == g) own += save.skillShards[def.id] ?? 0;
    }
    return Opacity(
      opacity: lit ? 1 : 0.4,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          skillShardImage(g, size: lit ? 34 : 26),
          const SizedBox(height: 2),
          Text(
            '$own',
            style: TextStyle(
              color: gradeColor(g),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  /// 사다리의 화살표 = 그 구간을 고르는 버튼.
  Widget _arrow(Grade from) {
    final on = _from == from;
    return InkWell(
      onTap: () => setState(() {
        _from = from;
        _picked.clear();
        _times = 1;
      }),
      borderRadius: BorderRadius.circular(9),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 8),
        child: Icon(
          Icons.chevron_right_rounded,
          size: on ? 26 : 20,
          color: on ? const Color(0xFFFFD54F) : const Color(0x55FFFFFF),
        ),
      ),
    );
  }

  /// 이번 변환의 셈 — `조각 그림 ×N  →  만능 그림 ×1`.
  Widget _recipe(
    AppLocalizations l,
    SkillConfig cfg,
    String fromLabel,
    String toLabel,
  ) {
    final to = SkillConfig.nextGrade(_from)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x33000000),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x22FFFFFF)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              skillShardImage(_from, size: 26),
              const SizedBox(width: 3),
              Text(
                '×${cfg.gradeUpRatio}',
                style: TextStyle(
                  color: gradeColor(_from),
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Icon(
                  Icons.east_rounded,
                  size: 18,
                  color: Color(0xFFFFD54F),
                ),
              ),
              skillShardImage(to, size: 26, wild: true),
              const SizedBox(width: 3),
              Text(
                '×1',
                style: TextStyle(
                  color: gradeColor(to),
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            l.skillGradeUpDesc('${cfg.gradeUpRatio}', fromLabel, toLabel),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 11.5),
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

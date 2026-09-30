import 'dart:async';

import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:core_save/core_save.dart';
import 'package:flutter/material.dart' hide Element;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/game_data.dart';
import '../../domain/audio_service.dart';
import '../../domain/providers.dart';
import '../../domain/save_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/art.dart';
import '../../ui/jelly_confirm.dart';
import '../../ui/format.dart';
import '../../ui/game_dialog.dart';
import '../../ui/labels.dart';
import '../../ui/skins.dart';
import '../../ui/toast.dart';

const _honey = Color(0xFFEBA52F);

/// 능력치 이름(훈련소·곤충 상세 공용).
String trainStatLabel(AppLocalizations l, TrainStat s) => switch (s) {
  TrainStat.attack => l.trainAttack,
  TrainStat.defense => l.trainDefense,
  TrainStat.evade => l.trainEvade,
  TrainStat.crit => l.trainCrit,
  TrainStat.recovery => l.trainRecovery,
};

IconData trainStatIcon(TrainStat s) => switch (s) {
  TrainStat.attack => Icons.flash_on_rounded,
  TrainStat.defense => Icons.shield_rounded,
  TrainStat.evade => Icons.air_rounded,
  TrainStat.crit => Icons.gps_fixed_rounded,
  TrainStat.recovery => Icons.favorite_rounded,
};

Color trainStatColor(TrainStat s) => switch (s) {
  TrainStat.attack => const Color(0xFFFF8A65),
  TrainStat.defense => const Color(0xFF64B5F6),
  TrainStat.evade => const Color(0xFF81C784),
  TrainStat.crit => const Color(0xFFFFD54F),
  TrainStat.recovery => const Color(0xFFF48FB1),
};

/// 훈련소(2026-09-29 사장님 확정) — 곤충마다 결투 능력치 5종을 훈련한다.
///
/// 모든 능력치를 끝까지 올릴 수 있지만 **끝이 곤충마다 다르다**(포텐셜·기질·주특기·혈통 특성).
/// 훈련소는 한 칸 — 훈련 중인 곤충은 출정할 수 없다. 젤리로 즉시 완료할 수 있다.
class TrainingScreen extends ConsumerStatefulWidget {
  const TrainingScreen({super.key, this.initialBugId});

  final String? initialBugId;

  @override
  ConsumerState<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends ConsumerState<TrainingScreen> {
  String? _bugId;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _bugId = widget.initialBugId;
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  TrainingConfig _cfg(GameData d) =>
      (d.battleConfig ?? const BattleConfig()).training;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final data = ref.watch(gameDataProvider).requireValue;
    final save = ref.watch(saveControllerProvider).requireValue;
    final now = ref.read(clockProvider).now().toUtc();
    final locale = Localizations.localeOf(context).languageCode;
    final cfg = _cfg(data);
    final pet = data.petConfig;
    final adults = [
      for (final b in save.bugs)
        if ((pet == null
                ? b.stage
                : effectiveStage(b.stage, b.stageSince, now, pet)) ==
            LifeStage.adult)
          b,
    ];
    // 등급 높은 순 → 포텐셜 높은 순(2026-09-29 사장님 요청). 같으면 크기·id 로 고정.
    adults.sort((a, b) {
      final ga = data.species(a.speciesId).grade.index;
      final gb = data.species(b.speciesId).grade.index;
      if (ga != gb) return gb.compareTo(ga);
      if (a.potential != b.potential) return b.potential.compareTo(a.potential);
      final sz = b.sizeMm.compareTo(a.sizeMm);
      return sz != 0 ? sz : a.id.compareTo(b.id);
    });
    final selected =
        adults.where((b) => b.id == _bugId).firstOrNull ?? adults.firstOrNull;

    return Scaffold(
      backgroundColor: const Color(0xFF1C1A12),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2A2417),
        title: Text(l.trainingCenter),
      ),
      body: adults.isEmpty
          ? Center(
              child: Text(
                l.battleNeedBugs,
                style: const TextStyle(color: Color(0xB3FFFFFF)),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
              children: [
                _jobCard(l, data, save, cfg, now, locale),
                const SizedBox(height: 12),
                Text(
                  l.trainingPickBug,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 92,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: adults.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 6),
                    itemBuilder: (_, i) => _bugChip(
                      data,
                      save,
                      adults[i],
                      adults[i].id == selected?.id,
                      locale,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (selected != null)
                  _bugPanel(l, data, save, cfg, selected, now, locale),
              ],
            ),
    );
  }

  Widget _jobCard(
    AppLocalizations l,
    GameData data,
    SaveGame save,
    TrainingConfig cfg,
    DateTime now,
    String locale,
  ) {
    final job = save.trainingJob;
    final bug = job == null
        ? null
        : save.bugs.where((b) => b.id == job.bugId).firstOrNull;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2417),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x55EBA52F)),
      ),
      child: job == null || bug == null
          ? Row(
              children: [
                gameImageChain(
                  ['assets/images/duel/hub_training.webp'],
                  size: 44,
                  fallback: const Icon(
                    Icons.fitness_center_rounded,
                    color: _honey,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l.trainingNone,
                    style: const TextStyle(color: Color(0xCCFFFFFF)),
                  ),
                ),
              ],
            )
          : Row(
              children: [
                SizedBox(
                  width: 52,
                  height: 52,
                  child: bugStageImage(
                    bug.speciesId,
                    LifeStage.adult,
                    size: 52,
                    fallback: const Icon(Icons.bug_report),
                    skin: bugView(ref.read(skinOfProvider), bug),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.trainingNow(trainStatLabel(l, job.stat), job.level),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        job.doneAt(now)
                            ? l.trainingDone
                            : formatClock(job.until.difference(now)),
                        style: const TextStyle(
                          color: _honey,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!job.doneAt(now))
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7DBA),
                    ),
                    onPressed: () async {
                      final jelly = cfg.instantJelly(job.until.difference(now));
                      if (!await confirmJellySpend(
                        context,
                        title: l.trainingInstantTitle,
                        body: l.skillTrainConfirm('$jelly'),
                        jelly: jelly,
                      )) {
                        return;
                      }
                      if (!mounted) return;
                      final err = await ref
                          .read(saveControllerProvider.notifier)
                          .finishDuelTrainingWithJelly();
                      if (!mounted) return;
                      if (err == null) {
                        AudioService.instance.sfxEnhance();
                      } else {
                        showCenterToast(context, l.notEnoughJelly);
                      }
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        jellyIcon(size: 16),
                        const SizedBox(width: 3),
                        Text(
                          '${cfg.instantJelly(job.until.difference(now))}',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _bugChip(
    GameData data,
    SaveGame save,
    IndividualBug b,
    bool on,
    String locale,
  ) {
    final sp = data.species(b.speciesId);
    final lv = trainLevelsOf(save, b.id).values.fold<int>(0, (a, x) => a + x);
    return GestureDetector(
      onTap: () => setState(() => _bugId = b.id),
      child: Container(
        width: 74,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: on ? const Color(0x33EBA52F) : const Color(0x22FFFFFF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: on ? _honey : gradeColor(sp.grade).withValues(alpha: 0.6),
            width: on ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: bugStageImage(
                b.speciesId,
                LifeStage.adult,
                size: 48,
                fallback: bugAvatar(sp, size: 40),
                skin: bugView(ref.read(skinOfProvider), b),
              ),
            ),
            Text(
              sp.name.resolve(locale),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 10),
            ),
            Text(
              lv > 0 ? 'T$lv · ${'★' * b.potential}' : '★' * b.potential,
              style: const TextStyle(
                color: Color(0xFFFFC928),
                fontSize: 9,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bugPanel(
    AppLocalizations l,
    GameData data,
    SaveGame save,
    TrainingConfig cfg,
    IndividualBug bug,
    DateTime now,
    String locale,
  ) {
    final sp = data.species(bug.speciesId);
    final levels = trainLevelsOf(save, bug.id);
    final busy = save.trainingJob != null && !save.trainingJob!.doneAt(now);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2417),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 60,
                height: 60,
                child: bugStageImage(
                  bug.speciesId,
                  LifeStage.adult,
                  size: 60,
                  fallback: bugAvatar(sp, size: 52),
                  skin: bugView(ref.read(skinOfProvider), bug),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sp.name.resolve(locale),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 4,
                      runSpacing: 3,
                      children: [
                        _chip(gradeLabel(l, sp.grade), gradeColor(sp.grade)),
                        _chip('★' * bug.potential, const Color(0xFFFFC928)),
                        _chip(
                          temperamentLabel(l, bug.temperament),
                          const Color(0xFFE9D9A6),
                        ),
                        _chip(
                          specialtyLabel(l, sp.specialty),
                          const Color(0xFFBFE3A6),
                        ),
                        if (!bug.trait.isNone)
                          _chip(
                            traitLabel(l, bug.trait),
                            traitColor(bug.trait),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            l.trainingCapHint,
            style: const TextStyle(color: Color(0x99FFFFFF), fontSize: 11),
          ),
          const SizedBox(height: 8),
          for (final st in TrainStat.values)
            _statRow(l, save, cfg, bug, sp, st, levels[st] ?? 0, busy),
          const SizedBox(height: 6),
          if (levels.isNotEmpty)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _confirmReset(l, cfg, bug, sp, levels),
                icon: const Icon(Icons.restart_alt_rounded, size: 18),
                label: Text(l.trainingReset),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFEF9A9A),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _chip(String t, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: c.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      t,
      style: TextStyle(color: c, fontSize: 10.5, fontWeight: FontWeight.w900),
    ),
  );

  String _pct(double v) {
    final p = v * 100;
    return p == p.roundToDouble()
        ? '${p.round()}%'
        : '${p.toStringAsFixed(1)}%';
  }

  Widget _statRow(
    AppLocalizations l,
    SaveGame save,
    TrainingConfig cfg,
    IndividualBug bug,
    Species sp,
    TrainStat st,
    int lv,
    bool busy,
  ) {
    final cap = trainCapOf(bug, sp, st, cfg);
    final maxed = lv >= cap;
    final per = cfg.perLevel[st] ?? 0;
    final cost = maxed ? 0 : cfg.costFor(lv + 1, sp.grade);
    final enough = kTrainingMaterials.every(
      (k) => save.materialCount(k) >= cost,
    );
    final c = trainStatColor(st);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
      decoration: BoxDecoration(
        color: const Color(0x22FFFFFF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(trainStatIcon(st), color: c, size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      trainStatLabel(l, st),
                      style: TextStyle(
                        color: c,
                        fontWeight: FontWeight.w900,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      l.trainingLevel(lv, cap),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: cap <= 0 ? 0 : lv / cap,
                    minHeight: 5,
                    backgroundColor: const Color(0x33FFFFFF),
                    valueColor: AlwaysStoppedAnimation(c),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  maxed
                      ? '+${_pct(per * lv)}'
                      : '+${_pct(per * lv)} → +${_pct(per * (lv + 1))} · ${remainLabel(l, cfg.timeFor(lv + 1))}',
                  style: const TextStyle(
                    color: Color(0xCCFFFFFF),
                    fontSize: 11,
                  ),
                ),
                if (!maxed)
                  Row(
                    children: [
                      for (final k in kTrainingMaterials) ...[
                        materialImage(
                          k,
                          size: 14,
                          fallback: const SizedBox(width: 14),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          formatCompact(cost),
                          style: TextStyle(
                            color: save.materialCount(k) >= cost
                                ? const Color(0xCCFFFFFF)
                                : const Color(0xFFEF9A9A),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: maxed
                  ? const Color(0xFF55504A)
                  : const Color(0xFFE08A2E),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: const Size(0, 38),
            ),
            onPressed: maxed
                ? null
                : () async {
                    if (busy) {
                      showCenterToast(context, l.trainingBusy);
                      return;
                    }
                    if (!enough) {
                      showCenterToast(context, l.trainingNoMaterials);
                      return;
                    }
                    final err = await ref
                        .read(saveControllerProvider.notifier)
                        .startDuelTraining(bug.id, st);
                    if (!mounted) return;
                    if (err == null) {
                      AudioService.instance.sfxEnhance();
                    } else {
                      showCenterToast(
                        context,
                        err == 'busy'
                            ? l.trainingBusy
                            : err == 'materials'
                            ? l.trainingNoMaterials
                            : l.battleServerFailed,
                      );
                    }
                  },
            child: Text(
              maxed ? l.trainingMaxed : l.trainingStart,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmReset(
    AppLocalizations l,
    TrainingConfig cfg,
    IndividualBug bug,
    Species sp,
    Map<TrainStat, int> levels,
  ) async {
    var spent = 0;
    for (final n in levels.values) {
      for (var i = 1; i <= n; i++) {
        spent += cfg.costFor(i, sp.grade);
      }
    }
    final refund = (spent * cfg.resetRefund).floor();
    final ok = await showGameDialog<bool>(
      context,
      title: l.trainingReset,
      icon: Icons.restart_alt_rounded,
      content: Text(
        l.trainingResetAsk(formatCompact(refund)),
        style: const TextStyle(color: Color(0xDDFFFFFF), height: 1.4),
      ),
      actions: [
        gameDialogButton(
          l.actionCancel,
          () => Navigator.pop(context, false),
          primary: false,
        ),
        gameDialogButton(l.trainingReset, () => Navigator.pop(context, true)),
      ],
    );
    if (ok != true || !mounted) return;
    final r = await ref
        .read(saveControllerProvider.notifier)
        .resetDuelTraining(bug.id);
    if (!mounted) return;
    showCenterToast(context, r == null ? l.trainingBusy : l.trainingResetDone);
  }
}

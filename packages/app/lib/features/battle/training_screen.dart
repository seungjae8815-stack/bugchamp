import 'dart:async';
import 'dart:math' as math;

import 'package:core_battle/core_battle.dart';
import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:core_save/core_save.dart';
import 'package:flutter/material.dart' hide Element;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/game_data.dart';
import '../../domain/audio_service.dart';
import '../../domain/game_server.dart';
import '../../domain/providers.dart';
import '../../domain/save_controller.dart';
import '../../domain/server_sync.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/art.dart';
import '../../ui/colors.dart';
import '../../ui/format.dart';
import '../../ui/game_dialog.dart';
import '../../ui/jelly_confirm.dart';
import '../../ui/labels.dart';
import '../../ui/skins.dart';
import '../../ui/toast.dart';

const _honey = kHoney;

/// 판·글씨 색 — 진한 판 위 밝은 글씨(2026-10 실기 지적: 머티리얼 기본 버튼·칩은 글씨가 묻힌다).
const _bg = Color(0xFF1C1A12);
const _panel = Color(0xFF2A2417);
const _row = Color(0xFF353024);
const _text = Color(0xFFF5F0E0);
const _dim = Color(0xD9F5F0E0);
const _bad = Color(0xFFFF9E8F);

/// 옛 능력치 이름(결투 화면·가이드가 아직 쓴다).
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
  TrainStat.crit => kHoney,
  TrainStat.recovery => const Color(0xFFF48FB1),
};

/// 훈련 v2 칸 이름(훈련소·곤충 상세 공용).
String trainSlotLabel(AppLocalizations l, TrainSlot s) => switch (s) {
  TrainSlot.attack => l.trainAttack,
  TrainSlot.defense => l.trainDefense,
  TrainSlot.hp => l.trainSlotHp,
  TrainSlot.speed => l.trainSlotSpeed,
  TrainSlot.evade => l.trainEvade,
  TrainSlot.crit => l.trainCrit,
  TrainSlot.recovery => l.trainRecovery,
  TrainSlot.mass => l.trainSlotMass,
  TrainSlot.tech => l.trainSlotTech,
  TrainSlot.grit => l.trainSlotGrit,
};

IconData trainSlotIcon(TrainSlot s) => switch (s) {
  TrainSlot.attack => Icons.flash_on_rounded,
  TrainSlot.defense => Icons.shield_rounded,
  TrainSlot.hp => Icons.favorite_rounded,
  TrainSlot.speed => Icons.speed_rounded,
  TrainSlot.evade => Icons.air_rounded,
  TrainSlot.crit => Icons.gps_fixed_rounded,
  TrainSlot.recovery => Icons.healing_rounded,
  TrainSlot.mass => Icons.fitness_center_rounded,
  TrainSlot.tech => Icons.sports_martial_arts_rounded,
  TrainSlot.grit => Icons.touch_app_rounded,
};

Color trainSlotColor(TrainSlot s) => switch (s) {
  TrainSlot.attack => const Color(0xFFFF8A65),
  TrainSlot.defense => const Color(0xFF64B5F6),
  TrainSlot.hp => const Color(0xFFEF6F7E),
  TrainSlot.speed => const Color(0xFF80DEEA),
  TrainSlot.evade => const Color(0xFF81C784),
  TrainSlot.crit => kHoney,
  TrainSlot.recovery => const Color(0xFFF48FB1),
  TrainSlot.mass => const Color(0xFFBCAAA4),
  TrainSlot.tech => const Color(0xFFB39DDB),
  TrainSlot.grit => const Color(0xFFFFB74D),
};

String _pct(double v) {
  final p = (v * 1000).round() / 10;
  return p == p.roundToDouble() ? '${p.round()}%' : '${p.toStringAsFixed(1)}%';
}

String _signed(double v) => v < 0 ? '−${_pct(-v)}' : '+${_pct(v)}';

/// 훈련소(훈련 v2, 2026-10-08 · docs/design_training_v2.md).
///
/// 곤충마다 **훈련 포인트**(포텐셜·수련 레벨·돌파로 무료로 생긴다)를 칸 10종에 골라 찍는다.
/// 포인트를 처음 쓸 때만 재료·시간이 든다(훈련소 1칸). **다시 찍기**는 무료 + 대기(첫 1회는 대기 없음).
/// 결투석(오행석·기질석)으로 오행·기질을 원하는 값으로 바꾼다.
class TrainingScreen extends ConsumerStatefulWidget {
  const TrainingScreen({super.key, this.initialBugId});

  final String? initialBugId;

  @override
  ConsumerState<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends ConsumerState<TrainingScreen> {
  String? _bugId;
  Timer? _tick;

  /// 다시 찍기 편집 중인 새 배분(null = 편집 안 함).
  Map<TrainSlot, int>? _draft;
  bool _working = false;

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

  /// 지금 바로 서버에 올린다(60초 주기를 기다리지 않는다 — 훈련은 누르고 바로 나가는 행동이다).
  /// 화면의 `ref` 를 쥔 업로더를 쓰지 않는다 — 업로드 중에 화면을 닫으면 닫힌 `ref` 에서 예외가 났다
  /// (2026-10-05 출시 전 점검). 올릴 세이브는 업로드 잠금을 잡은 뒤 컨트롤러에서 읽는다.
  void _pushNow() {
    final ctrl = ref.read(saveControllerProvider.notifier);
    unawaited(
      flushSaveBeforeServerAction(
        ref.read(gameServerProvider),
        () => ctrl.latestSave,
      ),
    );
  }

  SaveController get _ctrl => ref.read(saveControllerProvider.notifier);

  TrainingConfig _cfg(GameData d) =>
      (d.battleConfig ?? const BattleConfig()).training;

  DuelParams _params(GameData d) =>
      DuelParams.fromJson((d.battleConfig ?? const BattleConfig()).duelJson);

  /// 연속 탭으로 같은 동작이 두 번 나가지 않게.
  Future<void> _guard(Future<void> Function() f) async {
    if (_working) return;
    _working = true;
    try {
      await f();
    } finally {
      _working = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final data = ref.watch(gameDataProvider).requireValue;
    final raw = ref.watch(saveControllerProvider).requireValue;
    final now = ref.read(clockProvider).now().toUtc();
    // 화면은 끝난 찍기·다시 찍기를 반영한 모습으로 보여준다(세이브에는 다음 저장 때 들어간다).
    final save = finishTrainPointsIfDue(raw, now);
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
    // 등급 높은 순 → 포텐셜 → 많이 찍은 곤충 → 수련 레벨 → 크기 → id(고정).
    adults.sort((a, b) {
      final ga = data.species(a.speciesId).grade.index;
      final gb = data.species(b.speciesId).grade.index;
      if (ga != gb) return gb.compareTo(ga);
      if (a.potential != b.potential) return b.potential.compareTo(a.potential);
      final tr = trainedPointsOf(
        save,
        b.id,
      ).compareTo(trainedPointsOf(save, a.id));
      if (tr != 0) return tr;
      if (a.level != b.level) return b.level.compareTo(a.level);
      final sz = b.sizeMm.compareTo(a.sizeMm);
      return sz != 0 ? sz : a.id.compareTo(b.id);
    });
    final selected =
        adults.where((b) => b.id == _bugId).firstOrNull ?? adults.firstOrNull;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _panel,
        foregroundColor: Colors.white,
        title: Text(l.trainingCenter),
      ),
      body: adults.isEmpty
          ? Center(
              child: Text(
                l.battleNeedBugs,
                style: const TextStyle(color: _dim),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
              children: [
                _jobCard(l, data, save, cfg, now),
                const SizedBox(height: 12),
                Text(
                  l.trainingPickBug,
                  style: const TextStyle(
                    color: _text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 124,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: adults.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 6),
                    itemBuilder: (_, i) => _bugChip(
                      l,
                      data,
                      save,
                      adults[i],
                      adults[i].id == selected?.id,
                      locale,
                      now,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (selected != null)
                  ..._bugPanel(l, data, save, cfg, selected, now, locale),
              ],
            ),
    );
  }

  // ── 훈련소 1칸(지금 찍는 중) ────────────────────────────────────────

  Widget _jobCard(
    AppLocalizations l,
    GameData data,
    SaveGame save,
    TrainingConfig cfg,
    DateTime now,
  ) {
    final job = save.trainPointJob;
    final bug = job == null
        ? null
        : save.bugs.where((b) => b.id == job.bugId).firstOrNull;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _panel,
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
                    style: const TextStyle(color: _dim),
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
                    fallback: const Icon(Icons.bug_report, color: _text),
                    skin: bugView(ref.read(skinOfProvider), bug),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.trainPtJobNow(
                          trainSlotLabel(l, job.slot),
                          '${job.count}',
                        ),
                        style: const TextStyle(
                          color: _text,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formatClock(job.until.difference(now)),
                        style: const TextStyle(
                          color: _honey,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                _jellyButton(
                  cfg.instantJelly(job.until.difference(now)),
                  key: const ValueKey('trainJobInstant'),
                  onTap: () => _guard(() async {
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
                    final err = await _ctrl.finishTrainPointWithJelly();
                    if (!mounted) return;
                    if (err == null) {
                      _pushNow();
                      AudioService.instance.sfxEnhance();
                    } else {
                      showCenterToast(context, l.notEnoughJelly);
                    }
                  }),
                ),
              ],
            ),
    );
  }

  // ── 곤충 고르기 ──────────────────────────────────────────────────────

  Widget _bugChip(
    AppLocalizations l,
    GameData data,
    SaveGame save,
    IndividualBug b,
    bool on,
    String locale,
    DateTime now,
  ) {
    final sp = data.species(b.speciesId);
    final pts = trainedPointsOf(save, b.id);
    final busy = trainBusy(save, b.id, now);
    return GestureDetector(
      key: ValueKey('trainBug:${b.id}'),
      onTap: () => setState(() {
        if (_bugId != b.id) _draft = null;
        _bugId = b.id;
      }),
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
            Text(
              gradeLabel(l, sp.grade),
              style: TextStyle(
                color: gradeColor(sp.grade),
                fontSize: 9,
                fontWeight: FontWeight.w900,
              ),
            ),
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  bugStageImage(
                    b.speciesId,
                    LifeStage.adult,
                    size: 48,
                    fallback: bugAvatar(sp, size: 40),
                    skin: bugView(ref.read(skinOfProvider), b),
                  ),
                  if (busy)
                    const Positioned(
                      right: 0,
                      top: 0,
                      child: Icon(
                        Icons.hourglass_bottom_rounded,
                        color: _honey,
                        size: 14,
                      ),
                    ),
                ],
              ),
            ),
            Text(
              '★' * b.potential,
              style: const TextStyle(
                color: Color(0xFFFFC928),
                fontSize: 9,
                fontWeight: FontWeight.w800,
              ),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                pts > 0 ? l.trainPtShort('$pts') : l.trainingNoneShort,
                style: TextStyle(
                  color: pts > 0
                      ? const Color(0xFF8FD8FF)
                      : const Color(0xAAFFFFFF),
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              sp.name.resolve(locale),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _text, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  // ── 곤충 판 ──────────────────────────────────────────────────────────

  List<Widget> _bugPanel(
    AppLocalizations l,
    GameData data,
    SaveGame save,
    TrainingConfig cfg,
    IndividualBug bug,
    DateTime now,
    String locale,
  ) {
    final sp = data.species(bug.speciesId);
    final enh = data.enhanceConfig;
    final rec = bugTrainOf(save, bug, sp, cfg, enhance: enh);
    final legacy = legacyTrainPoints(save, bug, sp, cfg, enhance: enh);
    final budget = trainBudgetOf(save, bug, sp, cfg, enhance: enh);
    final bonus = math.max(0, budget - trainBaseBudget(bug, cfg));
    int capOf(TrainSlot sl) =>
        trainSlotCapOf(save, bug, sp, sl, cfg, enhance: enh, legacy: legacy);
    final job = save.trainPointJob;
    final jobHere = job != null && job.bugId == bug.id ? job : null;
    final used = rec.allocated + (jobHere?.count ?? 0);
    final left = math.max(0, budget - used);
    final free = math.max(0, rec.paid - rec.allocated);
    final levelCap = data.petConfig?.levelCap(bug.breakthroughTier);
    final lv = levelCap == null ? bug.level : bug.level.clamp(1, levelCap);
    final lm = 1 + (lv - 1) * cfg.duelLevelBonus;
    final current = trainingBonusOf(
      save,
      bug,
      sp,
      cfg,
      levelCap: levelCap,
      enhance: enh,
    );
    final draft = _draft;
    final respecMax = math.min(rec.paid, budget);
    final preview = draft == null
        ? null
        : cfg.slotBonuses(
            clampAlloc(draft, capOf: capOf, budget: respecMax),
            sp.specialty,
          );
    final params = _params(data);

    return [
      _header(l, sp, bug, locale),
      const SizedBox(height: 10),
      _pointsCard(
        l,
        data,
        save,
        cfg,
        bug,
        sp,
        rec,
        used: used,
        budget: budget,
        bonus: bonus,
        left: left,
        free: free,
        jobBusy: job != null,
      ),
      if (trainBusy(save, bug.id, now)) ...[
        const SizedBox(height: 8),
        _note(l.trainBusyNote, Icons.info_outline_rounded),
      ],
      const SizedBox(height: 10),
      _summaryCard(l, current, preview, lm),
      const SizedBox(height: 10),
      _respecBar(
        l,
        cfg,
        bug,
        sp,
        rec,
        now,
        busyHere: jobHere != null,
        respecMax: respecMax,
      ),
      const SizedBox(height: 6),
      for (final sl in TrainSlot.values)
        _slotRow(
          l,
          save,
          cfg,
          params,
          bug,
          sp,
          rec,
          sl,
          cap: capOf(sl),
          jobPlus: jobHere?.slot == sl ? jobHere!.count : 0,
          free: free,
          left: left,
          jobBusy: job != null,
          respecMax: respecMax,
        ),
      if (draft != null) ...[
        const SizedBox(height: 6),
        _respecActions(l, cfg, bug, rec, respecMax),
      ],
      const SizedBox(height: 12),
      _stoneCard(l, cfg, save, bug),
    ];
  }

  Widget _header(
    AppLocalizations l,
    Species sp,
    IndividualBug bug,
    String locale,
  ) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: _panel,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
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
                  color: _text,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                runSpacing: 3,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _chip(gradeLabel(l, sp.grade), gradeColor(sp.grade)),
                  _chip('★' * bug.potential, const Color(0xFFFFC928)),
                  _chip('Lv.${bug.level}', const Color(0xFFCFD8DC)),
                  _chip(
                    elementLabel(l, bug.element),
                    elementColor(bug.element),
                  ),
                  _chip(
                    temperamentLabel(l, bug.temperament),
                    const Color(0xFFE9D9A6),
                  ),
                  _chip(
                    specialtyLabel(l, sp.specialty),
                    const Color(0xFFBFE3A6),
                  ),
                  _chip(
                    l.bugSize(bug.sizeMm.toStringAsFixed(1)),
                    const Color(0xFFCFD8DC),
                  ),
                  if (!bug.trait.isNone)
                    _chip(traitLabel(l, bug.trait), traitColor(bug.trait)),
                  if (bug.variant != BugVariant.none)
                    _chip(l.dexVariant, const Color(0xFFE0A020)),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _chip(String t, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: c.withValues(alpha: 0.22),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      t,
      style: TextStyle(color: c, fontSize: 10.5, fontWeight: FontWeight.w900),
    ),
  );

  Widget _note(String text, IconData icon, {Color color = _honey}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withValues(alpha: 0.45)),
    ),
    child: Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: _text,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
        ),
      ],
    ),
  );

  // ── 포인트 ───────────────────────────────────────────────────────────

  Widget _pointsCard(
    AppLocalizations l,
    GameData data,
    SaveGame save,
    TrainingConfig cfg,
    IndividualBug bug,
    Species sp,
    BugTrain rec, {
    required int used,
    required int budget,
    required int bonus,
    required int left,
    required int free,
    required bool jobBusy,
  }) {
    final quote = trainPointQuote(rec, cfg, sp.grade);
    // 다음 포인트가 생기는 조건.
    final k = cfg.levelsPerPoint;
    final cap = data.petConfig?.levelCap(bug.breakthroughTier);
    final nextLv = k <= 0 ? null : (bug.level ~/ k + 1) * k;
    final tier = bug.breakthroughTier;
    final how = <String>[
      if (nextLv != null)
        cap != null && nextLv > cap
            ? l.trainPtHowLevelCap('$nextLv')
            : l.trainPtHowLevel('$nextLv', '$k'),
      if (tier < cfg.breakthroughPoints.length)
        l.trainPtHowBreak('${tier + 1}', '${cfg.breakthroughPoints[tier]}'),
      if (bug.potential < 5) l.trainPtHowPotential('${cfg.pointsPerPotential}'),
    ];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x558FD8FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                l.trainPtUsed('$used', '$budget'),
                key: const ValueKey('trainPoints'),
                style: const TextStyle(
                  color: _text,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (bonus > 0) ...[
                const SizedBox(width: 6),
                _chip(l.trainPtBonus('$bonus'), const Color(0xFFFFC928)),
              ],
              const Spacer(),
              Text(
                l.trainPtLeft('$left'),
                style: TextStyle(
                  color: left > 0 ? const Color(0xFF8FD8FF) : _dim,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: budget <= 0 ? 0 : (used / budget).clamp(0, 1).toDouble(),
              minHeight: 7,
              backgroundColor: const Color(0x33FFFFFF),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF8FD8FF)),
            ),
          ),
          const SizedBox(height: 8),
          if (free > 0)
            Text(
              l.trainPtFree('$free'),
              style: const TextStyle(
                color: Color(0xFF9CE59C),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            )
          else if (left > 0)
            Row(
              children: [
                Text(
                  '${l.trainPtNext} ',
                  style: const TextStyle(
                    color: _dim,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                for (final m in kTrainingMaterials) ...[
                  materialImage(
                    m,
                    size: 15,
                    fallback: Icon(materialIcon(m), size: 14, color: _dim),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    formatCompact(quote.cost),
                    style: TextStyle(
                      color: save.materialCount(m) >= quote.cost ? _text : _bad,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                const Icon(Icons.schedule_rounded, size: 14, color: _dim),
                const SizedBox(width: 2),
                Flexible(
                  child: Text(
                    remainLabel(l, quote.time),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _text,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          if (how.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              l.trainPtHowTitle,
              style: const TextStyle(
                color: _honey,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
            for (final h in how)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '· $h',
                  style: const TextStyle(color: _dim, fontSize: 11.5),
                ),
              ),
          ],
        ],
      ),
    );
  }

  // ── 결투 능력치 요약 ─────────────────────────────────────────────────

  Widget _summaryCard(
    AppLocalizations l,
    ({
      double atkMult,
      double defMult,
      double hpMult,
      double spdMult,
      double evade,
      double crit,
      double recovery,
      double massMult,
      double tech,
      int grit,
    })
    now,
    ({
      double atkMult,
      double defMult,
      double hpMult,
      double spdMult,
      double evade,
      double crit,
      double recovery,
      double massMult,
      double tech,
      int grit,
    })?
    edit,
    double lm,
  ) {
    // (이름, 지금, 편집 후, 확률 축인가)
    final rows = <(String, double, double?, bool)>[
      (
        l.trainAttack,
        now.atkMult - 1,
        edit == null ? null : edit.atkMult * lm - 1,
        false,
      ),
      (
        l.trainDefense,
        now.defMult - 1,
        edit == null ? null : edit.defMult - 1,
        false,
      ),
      (
        l.trainSlotHp,
        now.hpMult - 1,
        edit == null ? null : edit.hpMult * lm - 1,
        false,
      ),
      (
        l.trainSlotSpeed,
        now.spdMult - 1,
        edit == null ? null : edit.spdMult - 1,
        false,
      ),
      (l.trainEvade, now.evade, edit?.evade, true),
      (l.trainCrit, now.crit, edit?.crit, true),
      (l.trainRecovery, now.recovery, edit?.recovery, false),
      (
        l.trainWeight,
        now.massMult - 1,
        edit == null ? null : edit.massMult - 1,
        false,
      ),
    ];
    String fmt(double v, bool p) => '${_signed(v)}${p ? 'p' : ''}';
    return Container(
      key: const ValueKey('trainSummary'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            edit == null ? l.trainDuelSummary : l.trainEditPreview,
            style: TextStyle(
              color: edit == null ? _text : const Color(0xFF9CE59C),
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (_, c) {
              final w = (c.maxWidth - 3 * 6) / 4;
              return Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final r in rows)
                    Container(
                      width: w,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _row,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Text(
                            r.$1,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _dim,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              fmt(r.$3 ?? r.$2, r.$4),
                              style: TextStyle(
                                color:
                                    r.$3 == null || (r.$3! - r.$2).abs() < 1e-9
                                    ? _text
                                    : r.$3! > r.$2
                                    ? const Color(0xFF9CE59C)
                                    : _bad,
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ── 칸 ───────────────────────────────────────────────────────────────

  /// 칸 효과 한 줄(1포인트 효과 · 지금 합계). 근성은 탭 반격 설명.
  String _effectLine(
    AppLocalizations l,
    TrainingConfig cfg,
    DuelParams params,
    Species sp,
    TrainSlot sl,
    int pts,
  ) {
    final e = cfg.slotEffect[sl] ?? 0;
    switch (sl) {
      case TrainSlot.evade:
      case TrainSlot.crit:
        return l.trainPtEffect('${_signed(e)}p', '${_signed(e * pts)}p');
      case TrainSlot.mass:
        return l.trainPtEffect(
          l.trainMassPer(_signed(e), _signed(-cfg.massSpeedPenalty)),
          '${l.trainWeight} ${_signed(e * pts)}',
        );
      case TrainSlot.tech:
        final t = cfg.techBySpecialty[sp.specialty] ?? 0;
        return switch (sp.specialty) {
          Specialty.strike => l.trainPtEffect(
            l.trainTechFlip(_signed(t)),
            _signed(t * pts),
          ),
          Specialty.grip => l.trainPtEffect(
            l.trainTechBite(_signed(t)),
            _signed(t * pts),
          ),
          Specialty.toss => l.trainPtEffect(
            l.trainTechCooldown(_signed(-t)),
            _signed(-t * pts),
          ),
        };
      case TrainSlot.grit:
        final g = pts.clamp(0, params.clutchGritMax);
        final th = params.clutchThreshold - g * params.clutchThresholdPerGrit;
        final uses =
            params.clutchUses + (g >= params.clutchBonusUseGrit ? 1 : 0);
        final hp = params.clutchWakeHp + g * params.clutchWakeHpPerGrit;
        final base = l.trainGritDesc(th.toStringAsFixed(2), '$uses', _pct(hp));
        return g < params.clutchBonusUseGrit
            ? '$base · ${l.trainGritBonusUse('${params.clutchBonusUseGrit}')}'
            : base;
      default:
        return l.trainPtEffect(_signed(e), _signed(e * pts));
    }
  }

  Widget _slotRow(
    AppLocalizations l,
    SaveGame save,
    TrainingConfig cfg,
    DuelParams params,
    IndividualBug bug,
    Species sp,
    BugTrain rec,
    TrainSlot sl, {
    required int cap,
    required int jobPlus,
    required int free,
    required int left,
    required bool jobBusy,
    required int respecMax,
  }) {
    final draft = _draft;
    final editing = draft != null;
    final pts = editing ? (draft[sl] ?? 0) : (rec.alloc[sl] ?? 0);
    final c = trainSlotColor(sl);
    final full = pts + jobPlus >= cap;
    final shown = editing ? pts : pts + jobPlus;
    final draftSum = editing
        ? draft.values.fold<int>(0, (a, v) => a + math.max(0, v))
        : 0;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
      decoration: BoxDecoration(
        color: _row,
        borderRadius: BorderRadius.circular(12),
        border: editing && pts != (rec.alloc[sl] ?? 0)
            ? Border.all(color: const Color(0xAA9CE59C))
            : null,
      ),
      child: Row(
        children: [
          Icon(trainSlotIcon(sl), color: c, size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        trainSlotLabel(l, sl),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: c,
                          fontWeight: FontWeight.w900,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$shown / $cap',
                      key: ValueKey('trainSlot:${sl.key}:value'),
                      style: const TextStyle(
                        color: _text,
                        fontWeight: FontWeight.w900,
                        fontSize: 12.5,
                      ),
                    ),
                    if (!editing && jobPlus > 0) ...[
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.hourglass_bottom_rounded,
                        color: _honey,
                        size: 13,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: cap <= 0 ? 0 : (shown / cap).clamp(0, 1).toDouble(),
                    minHeight: 5,
                    backgroundColor: const Color(0x33FFFFFF),
                    valueColor: AlwaysStoppedAnimation(c),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _effectLine(l, cfg, params, sp, sl, shown),
                  style: const TextStyle(
                    color: _dim,
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          if (editing)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _roundBtn(
                  Icons.remove_rounded,
                  key: ValueKey('trainSlot:${sl.key}:minus'),
                  enabled: pts > 0,
                  onTap: () => setState(() {
                    final d = Map<TrainSlot, int>.from(draft);
                    d[sl] = math.max(0, (d[sl] ?? 0) - 1);
                    _draft = d;
                  }),
                ),
                const SizedBox(width: 6),
                _roundBtn(
                  Icons.add_rounded,
                  key: ValueKey('trainSlot:${sl.key}:plus'),
                  enabled: pts < cap && draftSum < respecMax,
                  onTap: () => setState(() {
                    final d = Map<TrainSlot, int>.from(draft);
                    d[sl] = (d[sl] ?? 0) + 1;
                    _draft = d;
                  }),
                ),
              ],
            )
          else
            _roundBtn(
              Icons.add_rounded,
              key: ValueKey('trainSlot:${sl.key}:plus'),
              enabled: !full && rec.pending == null,
              big: true,
              onTap: () => _addPoint(
                l,
                save,
                cfg,
                bug,
                sp,
                rec,
                sl,
                full: full,
                free: free,
                left: left,
                jobBusy: jobBusy,
              ),
            ),
        ],
      ),
    );
  }

  Widget _roundBtn(
    IconData icon, {
    required bool enabled,
    required VoidCallback onTap,
    bool big = false,
    Key? key,
  }) {
    final s = big ? 40.0 : 34.0;
    return GestureDetector(
      key: key,
      behavior: HitTestBehavior.opaque,
      // 비활성도 눌러서 이유를 들을 수 있게(찍기 [+] 만) — 편집 스테퍼는 그냥 막는다.
      onTap: enabled || big ? onTap : null,
      child: Container(
        width: s,
        height: s,
        decoration: BoxDecoration(
          color: enabled ? const Color(0xFFE08A2E) : const Color(0xFF4A453E),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: enabled ? const Color(0xFFFFC27A) : const Color(0x33FFFFFF),
          ),
        ),
        child: Icon(
          icon,
          color: enabled ? Colors.white : const Color(0x99FFFFFF),
          size: big ? 24 : 20,
        ),
      ),
    );
  }

  Future<void> _addPoint(
    AppLocalizations l,
    SaveGame save,
    TrainingConfig cfg,
    IndividualBug bug,
    Species sp,
    BugTrain rec,
    TrainSlot sl, {
    required bool full,
    required int free,
    required int left,
    required bool jobBusy,
  }) => _guard(() async {
    if (rec.pending != null) {
      showCenterToast(context, l.trainPtRespecBusy);
      return;
    }
    if (full) {
      showCenterToast(context, l.trainPtMaxed);
      return;
    }
    if (free <= 0) {
      if (jobBusy) {
        showCenterToast(context, l.trainingBusy);
        return;
      }
      if (left <= 0) {
        showCenterToast(context, l.trainPtNoPoints);
        return;
      }
      final q = trainPointQuote(rec, cfg, sp.grade);
      if (kTrainingMaterials.any((k) => save.materialCount(k) < q.cost)) {
        showCenterToast(context, l.trainingNoMaterials);
        return;
      }
    }
    final err = await _ctrl.allocTrainPointNow(bug.id, sl);
    if (!mounted) return;
    if (err == null) {
      // 훈련은 누르고 바로 앱을 나가는 행동이라 60초 주기를 기다리지 않고 올린다(2026-10-05 제보).
      _pushNow();
      AudioService.instance.sfxEnhance();
      return;
    }
    showCenterToast(context, switch (err) {
      'busy' => l.trainingBusy,
      'materials' => l.trainingNoMaterials,
      'maxed' => l.trainPtMaxed,
      'points' => l.trainPtNoPoints,
      'respec' => l.trainPtRespecBusy,
      _ => l.battleServerFailed,
    });
  });

  // ── 다시 찍기 ────────────────────────────────────────────────────────

  Widget _respecBar(
    AppLocalizations l,
    TrainingConfig cfg,
    IndividualBug bug,
    Species sp,
    BugTrain rec,
    DateTime now, {
    required bool busyHere,
    required int respecMax,
  }) {
    // 대기 중 — 남은 시간 · 젤리로 당기기 · 취소.
    final pending = rec.pending;
    final until = rec.respecUntil;
    if (pending != null && until != null) {
      final rem = until.difference(now);
      final jelly = cfg.instantJelly(rem);
      final parts = [
        for (final sl in TrainSlot.values)
          if ((pending[sl] ?? 0) > 0) '${trainSlotLabel(l, sl)} ${pending[sl]}',
      ];
      return Container(
        key: const ValueKey('trainRespecPending'),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0x88FFB74D)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.trainRespecWaiting(formatClock(rem)),
              style: const TextStyle(
                color: _honey,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${l.trainRespecPending}: ${parts.isEmpty ? '-' : parts.join(' · ')}',
              style: const TextStyle(color: _dim, fontSize: 11.5),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _jellyButton(
                    jelly,
                    key: const ValueKey('trainRespecInstant'),
                    onTap: () => _guard(() async {
                      final j = cfg.instantJelly(
                        until.difference(ref.read(clockProvider).now().toUtc()),
                      );
                      if (!await confirmJellySpend(
                        context,
                        title: l.trainRespecInstantTitle,
                        body: l.skillTrainConfirm('$j'),
                        jelly: j,
                      )) {
                        return;
                      }
                      if (!mounted) return;
                      final err = await _ctrl.finishTrainRespecWithJelly(
                        bug.id,
                      );
                      if (!mounted) return;
                      if (err == null) {
                        _pushNow();
                        AudioService.instance.sfxEnhance();
                        showCenterToast(context, l.trainRespecDone);
                      } else {
                        showCenterToast(context, l.notEnoughJelly);
                      }
                    }),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _solidButton(
                    l.trainRespecCancel,
                    const Color(0xFF6B4A44),
                    key: const ValueKey('trainRespecCancel'),
                    onTap: () => _guard(() async {
                      final ok = await _ask(
                        l.trainRespecCancel,
                        l.trainRespecCancelAsk,
                        l.trainRespecCancel,
                        icon: Icons.undo_rounded,
                      );
                      if (!ok || !mounted) return;
                      final err = await _ctrl.cancelTrainRespecNow(bug.id);
                      if (!mounted) return;
                      if (err == null) _pushNow();
                    }),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // 편집 중 — 남은 포인트 안내.
    final draft = _draft;
    if (draft != null) {
      final sum = draft.values.fold<int>(0, (a, v) => a + math.max(0, v));
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF243322),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xAA9CE59C)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.trainRespecEditTitle('${respecMax - sum}'),
              key: const ValueKey('trainRespecLeft'),
              style: const TextStyle(
                color: Color(0xFF9CE59C),
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l.trainRespecHint('$respecMax'),
              style: const TextStyle(color: _dim, fontSize: 11.5),
            ),
            const SizedBox(height: 4),
            Text(
              rec.freeRespec
                  ? l.trainRespecFreeBadge
                  : l.trainRespecWaitInfo(
                      remainLabel(l, cfg.respecWait(rec.paid)),
                    ),
              style: const TextStyle(
                color: _honey,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
    }

    // 평소 — 다시 찍기 버튼(찍은 포인트가 있고, 이 곤충이 찍는 중이 아닐 때).
    final can = rec.paid > 0 && !busyHere;
    return Row(
      children: [
        Expanded(
          child: Text(
            rec.paid <= 0
                ? ''
                : rec.freeRespec
                ? l.trainRespecFreeBadge
                : l.trainRespecWaitInfo(
                    remainLabel(l, cfg.respecWait(rec.paid)),
                  ),
            style: const TextStyle(
              color: _dim,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        _solidButton(
          l.trainRespec,
          can ? const Color(0xFF2E7DBA) : const Color(0xFF4A453E),
          key: const ValueKey('trainRespecBtn'),
          icon: Icons.restart_alt_rounded,
          onTap: () {
            if (!can) {
              showCenterToast(
                context,
                busyHere ? l.trainingBusy : l.trainingNoneShort,
              );
              return;
            }
            setState(() => _draft = Map<TrainSlot, int>.from(rec.alloc));
          },
        ),
      ],
    );
  }

  Widget _respecActions(
    AppLocalizations l,
    TrainingConfig cfg,
    IndividualBug bug,
    BugTrain rec,
    int respecMax,
  ) => Row(
    children: [
      Expanded(
        child: _solidButton(
          l.actionCancel,
          const Color(0xFF5A544A),
          key: const ValueKey('trainRespecDiscard'),
          onTap: () => setState(() => _draft = null),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        flex: 2,
        child: _solidButton(
          l.trainRespecApply,
          const Color(0xFF2E8B57),
          key: const ValueKey('trainRespecApply'),
          icon: Icons.check_rounded,
          onTap: () => _guard(() async {
            final draft = _draft;
            if (draft == null) return;
            final same = TrainSlot.values.every(
              (sl) => (draft[sl] ?? 0) == (rec.alloc[sl] ?? 0),
            );
            if (same) {
              showCenterToast(context, l.trainRespecSame);
              return;
            }
            final ok = await _ask(
              l.trainRespec,
              rec.freeRespec
                  ? l.trainRespecAskFree
                  : l.trainRespecAskWait(
                      remainLabel(l, cfg.respecWait(rec.paid)),
                    ),
              l.trainRespecApply,
              icon: Icons.restart_alt_rounded,
            );
            if (!ok || !mounted) return;
            final err = await _ctrl.startTrainRespecNow(bug.id, draft);
            if (!mounted) return;
            if (err == null) {
              final instant = rec.freeRespec;
              setState(() => _draft = null);
              _pushNow();
              AudioService.instance.sfxEnhance();
              showCenterToast(
                context,
                instant ? l.trainRespecDone : l.trainRespecStarted,
              );
              return;
            }
            showCenterToast(context, switch (err) {
              'same' => l.trainRespecSame,
              'busy' => l.trainingBusy,
              'respec' => l.trainPtRespecBusy,
              'maxed' => l.trainPtMaxed,
              'points' => l.trainPtNoPoints,
              _ => l.battleServerFailed,
            });
          }),
        ),
      ),
    ],
  );

  // ── 결투석 ───────────────────────────────────────────────────────────

  Widget _stoneCard(
    AppLocalizations l,
    TrainingConfig cfg,
    SaveGame save,
    IndividualBug bug,
  ) {
    Widget half(DuelStone kind) {
      final n = save.duelStoneCount(kind);
      final isEl = kind == DuelStone.element;
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _row,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(
                    isEl ? Icons.diamond_rounded : Icons.psychology_rounded,
                    color: isEl
                        ? const Color(0xFF7FD3FF)
                        : const Color(0xFFE6B3FF),
                    size: 22,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      duelStoneLabel(l, kind),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _text,
                        fontWeight: FontWeight.w900,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                  Text(
                    l.duelStoneOwned('$n'),
                    key: ValueKey('duelStone:${kind.key}:count'),
                    style: const TextStyle(
                      color: _honey,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: _solidButton(
                  isEl
                      ? l.duelStoneChangeElement
                      : l.duelStoneChangeTemperament,
                  const Color(0xFF6A4FB3),
                  key: ValueKey('duelStone:${kind.key}:use'),
                  onTap: () => _useStone(l, cfg, bug, kind),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.duelStoneTitle,
            style: const TextStyle(
              color: _text,
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l.duelStoneHint,
            style: const TextStyle(color: _dim, fontSize: 11.5),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              half(DuelStone.element),
              const SizedBox(width: 8),
              half(DuelStone.temperament),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _useStone(
    AppLocalizations l,
    TrainingConfig cfg,
    IndividualBug bug,
    DuelStone kind,
  ) => _guard(() async {
    final name = duelStoneLabel(l, kind);
    var save = ref.read(saveControllerProvider).requireValue;
    if (save.duelStoneCount(kind) < 1) {
      final price = cfg.stones.jelly[kind] ?? 0;
      if (price <= 0) return;
      if (!await confirmJellySpend(
        context,
        title: l.duelStoneBuyTitle(name),
        body: l.duelStoneBuyBody(name, '$price'),
        jelly: price,
        actionLabel: l.duelStoneBuyAction,
      )) {
        return;
      }
      if (!mounted) return;
      final err = await _ctrl.buyDuelStoneNow(kind);
      if (!mounted) return;
      if (err != null) {
        showCenterToast(context, l.notEnoughJelly);
        return;
      }
      _pushNow();
      save = ref.read(saveControllerProvider).requireValue;
    }
    final cur = save.bugs.where((b) => b.id == bug.id).firstOrNull;
    if (cur == null) return;
    final isEl = kind == DuelStone.element;
    final picked = await showGameDialog<Object>(
      context,
      title: isEl ? l.duelStonePickElement : l.duelStonePickTemperament,
      icon: isEl ? Icons.diamond_rounded : Icons.psychology_rounded,
      content: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: [
          if (isEl)
            for (final e in Element.values)
              _pickOption(
                key: ValueKey('stonePick:${e.name}'),
                icon: elementIcon(e, size: 20),
                label: elementLabel(l, e),
                color: elementColor(e),
                current: e == cur.element,
                onTap: () => Navigator.pop(context, e),
              )
          else
            for (final t in Temperament.values)
              _pickOption(
                key: ValueKey('stonePick:${t.name}'),
                icon: temperamentIcon(t, size: 18),
                label: temperamentLabel(l, t),
                color: const Color(0xFFE9D9A6),
                current: t == cur.temperament,
                onTap: () => Navigator.pop(context, t),
              ),
        ],
      ),
      actions: [
        gameDialogButton(
          l.actionCancel,
          () => Navigator.pop(context),
          primary: false,
        ),
      ],
    );
    if (picked == null || !mounted) return;
    final from = isEl
        ? elementLabel(l, cur.element)
        : temperamentLabel(l, cur.temperament);
    final to = picked is Element
        ? elementLabel(l, picked)
        : temperamentLabel(l, picked as Temperament);
    final ok = await _ask(
      name,
      l.duelStoneAsk(from, to, name),
      isEl ? l.duelStoneChangeElement : l.duelStoneChangeTemperament,
      icon: isEl ? Icons.diamond_rounded : Icons.psychology_rounded,
    );
    if (!ok || !mounted) return;
    final err = await _ctrl.useDuelStoneNow(
      bug.id,
      element: picked is Element ? picked : null,
      temperament: picked is Temperament ? picked : null,
    );
    if (!mounted) return;
    if (err == null) {
      _pushNow();
      AudioService.instance.sfxEnhance();
      showCenterToast(context, l.duelStoneDone);
    } else {
      showCenterToast(
        context,
        err == 'same' ? l.trainRespecSame : l.battleServerFailed,
      );
    }
  });

  Widget _pickOption({
    required Key key,
    required Widget icon,
    required String label,
    required Color color,
    required bool current,
    required VoidCallback onTap,
  }) => GestureDetector(
    key: key,
    onTap: current ? null : onTap,
    child: Opacity(
      opacity: current ? 0.45 : 1,
      child: Container(
        width: 96,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2417),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.8), width: 1.5),
        ),
        child: Column(
          children: [
            icon,
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  // ── 공용 ─────────────────────────────────────────────────────────────

  Future<bool> _ask(
    String title,
    String body,
    String ok, {
    IconData icon = Icons.help_outline_rounded,
  }) async {
    final r = await showGameDialog<bool>(
      context,
      title: title,
      icon: icon,
      content: Text(
        body,
        style: const TextStyle(color: _text, fontSize: 13.5, height: 1.4),
      ),
      actions: [
        gameDialogButton(
          l10n.actionCancel,
          () => Navigator.pop(context, false),
          primary: false,
        ),
        gameDialogButton(ok, () => Navigator.pop(context, true)),
      ],
    );
    return r == true;
  }

  AppLocalizations get l10n => AppLocalizations.of(context);

  /// 진한 단색 판 + 흰 글씨 버튼(머티리얼 기본 버튼은 다크 판에서 글씨가 묻혔다).
  Widget _solidButton(
    String label,
    Color color, {
    required VoidCallback onTap,
    IconData? icon,
    Key? key,
  }) => Material(
    key: key,
    color: color,
    borderRadius: BorderRadius.circular(10),
    child: InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 38),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0x44FFFFFF)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _jellyButton(int jelly, {required VoidCallback onTap, Key? key}) =>
      Material(
        key: key,
        color: const Color(0xFF2E7DBA),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 38),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                jellyIcon(size: 16),
                const SizedBox(width: 3),
                Text(
                  '$jelly',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

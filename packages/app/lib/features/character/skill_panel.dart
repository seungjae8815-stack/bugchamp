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
import '../../ui/format.dart';
import '../../ui/game_dialog.dart';
import '../../ui/labels.dart';
import '../../ui/toast.dart';
import 'skill_gacha_dialog.dart';
import 'skill_grade_up_dialog.dart';

const _honey = Color(0xFFFFD54F);

/// 장착 칸 한 변(논리 px). 칸 5개가 한 줄에 들어가야 한다.
const double _kSlotChip = 44;

/// 캐릭터 탭 · 스킬 패널(CLAUDE.md §2.8).
///
/// 위: 장착 칸 · 만능 조각 · 수련 중 막대. 아래: 12종을 **등급 순**으로.
/// 한 줄 = 이름·등급·레벨 · 효과 · 조각 진행 · [장착][수련].
class SkillPanel extends ConsumerStatefulWidget {
  const SkillPanel({super.key, required this.save});
  final SaveGame save;

  @override
  ConsumerState<SkillPanel> createState() => _SkillPanelState();
}

class _SkillPanelState extends ConsumerState<SkillPanel> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // 수련 남은 시간을 1초마다 다시 그린다 — 세이브는 안 바뀌어도 시계는 간다.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && widget.save.skillTrainingId != null) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  SaveController get _ctrl => ref.read(saveControllerProvider.notifier);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cfg = ref.watch(gameDataProvider).value?.skillConfig;
    if (cfg == null) return const SizedBox.shrink();
    final save = widget.save;
    final locale = Localizations.localeOf(context).languageCode;
    final slots = cfg.slotsFor(save.topTier);
    final sorted = [...cfg.skills]
      ..sort((a, b) => a.grade.index.compareTo(b.grade.index));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(l, cfg, save, slots, locale),
        if (save.skillTrainingId != null) ...[
          const SizedBox(height: 6),
          _trainingBar(l, cfg, save, locale),
        ],
        const SizedBox(height: 6),
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              for (final def in sorted) _row(l, cfg, save, def, locale, slots),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  l.skillHowToGet,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _header(
    AppLocalizations l,
    SkillConfig cfg,
    SaveGame save,
    int slots,
    String locale,
  ) {
    final more = slots < cfg.maxSlots;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: _box(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                l.skillSlotsInfo('${save.equippedSkills.length}', '$slots'),
                style: const TextStyle(
                  color: _honey,
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                ),
              ),
              const Spacer(),
              _button(
                l.skillGacha,
                () => _open(SkillGachaDialog(cfg: cfg, locale: locale)),
                accent: _honey,
                art: 'gacha',
              ),
              const SizedBox(width: 5),
              _button(
                l.skillSweep,
                () => _open(SkillSweepDialog(cfg: cfg, locale: locale)),
                accent: const Color(0xFF4FC3F7),
                art: 'sweep',
              ),
              const SizedBox(width: 5),
              _button(
                l.skillGradeUp,
                () => _open(SkillGradeUpDialog(cfg: cfg, locale: locale)),
                accent: const Color(0xFFCE93D8),
                art: 'gradeup',
              ),
            ],
          ),
          const SizedBox(height: 6),
          // 등급 만능 조각 = **스킬 재료**. 일반은 아래 등급이 없어 만들 수 없으니 뺀다.
          //
          // 제목 없이 '희귀 만능 0' 만 있으면 그게 재료인지 모른다(실기 지적
          // 2026-09-16). 무엇을 모으는 중인지 한 줄로 말해 준다.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.skillShardsTitle,
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                // 순서: **조각 4등급 먼저, 그 뒤에 만능 조각**(사장님 지시
                // 2026-09-20). 등급마다 조각·만능을 붙여 놓으니 같은 줄에
                // 두 종류가 번갈아 나와 무엇이 무엇인지 읽기 어려웠다.
                child: Wrap(
                  spacing: 8,
                  runSpacing: 3,
                  children: [
                    for (final g in kSkillGrades) _shardTally(l, cfg, save, g),
                    // 만능은 일반 등급이 없다 — 아래 등급이 없어 만들 수 없다.
                    for (final g in kSkillGrades.skip(1))
                      if (save.gradeShards(g) > 0)
                        _shardTally(l, cfg, save, g, wild: true),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: [
              for (var i = 0; i < cfg.maxSlots; i++)
                _slotChip(cfg, save, i, slots, locale),
            ],
          ),
          if (more)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                l.skillNextSlotHint,
                style: const TextStyle(color: Colors.white38, fontSize: 10.5),
              ),
            ),
        ],
      ),
    );
  }

  void _open(Widget dialog) => showDialog<void>(
    context: context,
    barrierColor: const Color(0xB3000000),
    builder: (_) => dialog,
  );

  /// 등급 한 칸 — **그 등급 스킬 조각의 합**과 **만능 조각 수**.
  ///
  /// 예전엔 만능 조각만 '희귀 만능 0' 식으로 있어서, 정작 모으고 있는
  /// 스킬 조각이 몇 개인지 화면 어디에도 없었다(실기 지적 2026-09-20).
  /// 승급이 **같은 등급 10개** 단위라 등급별 합계가 바로 쓰이는 숫자다.
  /// 만능은 겹치지 않게 뒤에 따로 붙인다 — 합쳐 세면 승급 계산이 틀어진다.
  Widget _shardTally(
    AppLocalizations l,
    SkillConfig cfg,
    SaveGame save,
    Grade g, {
    bool wild = false,
  }) {
    int count;
    if (wild) {
      count = save.gradeShards(g);
    } else {
      count = 0;
      for (final def in cfg.skills) {
        if (def.grade == g) count += save.skillShards[def.id] ?? 0;
      }
    }
    return Tooltip(
      message: wild
          ? '${l.skillGradeWild(gradeLabel(l, g))} $count'
          : '${gradeLabel(l, g)} ${l.skillShardsTitle} $count',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          skillShardImage(g, size: 14, wild: wild),
          const SizedBox(width: 2),
          Text(
            '$count',
            style: TextStyle(
              color: gradeColor(g),
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _slotChip(
    SkillConfig cfg,
    SaveGame save,
    int i,
    int slots,
    String locale,
  ) {
    final open = i < slots;
    final def = i < save.equippedSkills.length
        ? cfg.byId(save.equippedSkills[i])
        : null;
    final color = def == null ? Colors.white24 : gradeColor(def.grade);
    // 액티브는 **원**, 패시브는 **둥근 사각**(사장님 지시 2026-09-20).
    // 홈 스킬 바에서 누를 수 있는 칸이 원이라 모양이 곧 "누르는 것"이라는
    // 뜻이 된다. 글자를 넣기엔 칸이 작아 모양으로 가른다 — 무엇을 꼈는지는
    // 그림이 말하고, 이름은 길게 눌러(툴팁) 확인한다.
    final active = def?.isActive ?? false;
    final chip = Container(
      width: _kSlotChip,
      height: _kSlotChip,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: def == null
            ? const Color(0x22000000)
            : color.withValues(alpha: 0.25),
        shape: active ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: active ? null : BorderRadius.circular(9),
        border: Border.all(
          color: open ? color : const Color(0x11FFFFFF),
          width: active ? 1.6 : 1.2,
        ),
      ),
      child: !open
          ? const Icon(Icons.lock_rounded, size: 14, color: Colors.white24)
          : def == null
          ? const Icon(Icons.add_rounded, size: 16, color: Colors.white38)
          : skillImage(
              def.id,
              size: _kSlotChip - 11,
              fallback: Icon(
                active ? Icons.flash_on_rounded : Icons.shield_moon_rounded,
                size: 17,
                color: Colors.white,
              ),
            ),
    );
    if (def == null) return chip;
    return Tooltip(
      message:
          '${def.name.resolve(locale)} · '
          '${def.isActive ? AppLocalizations.of(context).skillKindActive : AppLocalizations.of(context).skillKindPassive}',
      child: chip,
    );
  }

  Widget _trainingBar(
    AppLocalizations l,
    SkillConfig cfg,
    SaveGame save,
    String locale,
  ) {
    final def = cfg.byId(save.skillTrainingId!);
    final endsAt = save.skillTrainingEndsAt!;
    final now = ref.read(clockProvider).now().toUtc();
    final left = endsAt.difference(now);
    final done = left <= Duration.zero;
    final lv = (save.skillLevels[save.skillTrainingId!] ?? 0) + 1;
    final total = def == null ? Duration.zero : cfg.trainDuration(def, lv - 1);
    final progress = total.inSeconds <= 0
        ? 1.0
        : (1 - left.inSeconds / total.inSeconds).clamp(0.0, 1.0);
    final jelly = cfg.trainJelly(left);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
      decoration: _box(border: const Color(0xAA4FC3F7)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.skillTrainingNow(
                    def?.name.resolve(locale) ?? '?',
                    '$lv',
                    done ? '0s' : formatShortDuration(left),
                  ),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 5,
                    backgroundColor: const Color(0x33FFFFFF),
                    color: const Color(0xFF4FC3F7),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (done)
            _button(l.skillTrainClaim, () => _complete(l, cfg, locale))
          else
            _button(
              l.actionInstant,
              () => _confirmInstant(l, cfg, jelly, locale),
              accent: const Color(0xFF4FC3F7),
              jellyCost: jelly,
            ),
        ],
      ),
    );
  }

  Widget _row(
    AppLocalizations l,
    SkillConfig cfg,
    SaveGame save,
    SkillDef def,
    String locale,
    int slots,
  ) {
    final lv = save.skillLevels[def.id] ?? 0;
    final owned = lv > 0;
    final maxed = lv >= cfg.maxLevel;
    final equipped = save.equippedSkills.contains(def.id);
    final have = save.skillShards[def.id] ?? 0;
    final need = owned ? cfg.shardsForLevel(def, lv) : cfg.unlockShards;
    final color = gradeColor(def.grade);
    final training = save.skillTrainingId == def.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(0, 0, 8, 0),
      decoration: _box(border: equipped ? _honey : const Color(0x22FFFFFF)),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: color),
            const SizedBox(width: 6),
            // 스킬 아트. 미보유는 흑백 실루엣으로 — 채워 갈 대상이 보여야 한다.
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: _SkillArt(
                id: def.id,
                owned: owned,
                active: def.isActive,
                size: 38,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          def.isActive
                              ? Icons.bolt_rounded
                              : Icons.auto_awesome_rounded,
                          size: 15,
                          color: def.isActive
                              ? const Color(0xFF4FC3F7)
                              : _honey,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            def.name.resolve(locale),
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: owned ? Colors.white : Colors.white60,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${gradeLabel(l, def.grade)} · '
                          '${def.isActive ? l.skillKindActive : l.skillKindPassive}',
                          style: TextStyle(color: color, fontSize: 10.5),
                        ),
                        const Spacer(),
                        Text(
                          !owned
                              ? l.skillLocked
                              : maxed
                              ? l.skillMaxLevel
                              : 'Lv.$lv',
                          style: TextStyle(
                            color: owned ? _honey : Colors.white38,
                            fontWeight: FontWeight.w800,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _effectText(l, def, lv.clamp(1, cfg.maxLevel)),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                    if (!maxed) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: need <= 0
                                    ? 1
                                    : (have / need).clamp(0.0, 1.0),
                                minHeight: 4,
                                backgroundColor: const Color(0x22FFFFFF),
                                color: color,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            l.skillShardProgress('$have', '$need'),
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (owned) ...[
              const SizedBox(width: 8),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _button(
                    equipped ? l.skillUnequip : l.skillEquip,
                    () => _toggle(l, def),
                    on: equipped,
                  ),
                  if (!maxed && !training) ...[
                    const SizedBox(height: 4),
                    _button(
                      l.skillTrain,
                      () => _train(l, cfg, save, def, locale),
                      dim: save.skillTrainingId != null,
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _effectText(AppLocalizations l, SkillDef def, int lv) {
    final v = def.valueAt(lv);
    String pct(double x) => (x * 100).toStringAsFixed(x * 100 < 10 ? 1 : 0);
    String mult(double x) => x.toStringAsFixed(x == x.roundToDouble() ? 0 : 1);
    final d = '${def.duration.inSeconds}';
    final text = switch (def.effect) {
      'materialFind' when def.isActive => l.skillFxMaterialBurst(mult(v), d),
      'materialFind' => l.skillFxMaterialFind(pct(v)),
      'bugFind' => l.skillFxBugFind(pct(v)),
      'bossDamage' => l.skillFxBossDamage(pct(v)),
      'perPetAttack' => l.skillFxPerPetAttack(pct(v)),
      'killHeal' => l.skillFxKillHeal(pct(v)),
      'revive' => l.skillFxRevive(pct(v)),
      'attackSpeed' => l.skillFxAttackSpeed(mult(v), d),
      'areaDamage' => l.skillFxAreaDamage(mult(v)),
      'petPower' => l.skillFxPetPower(mult(v), d),
      'burstDamage' => l.skillFxBurstDamage(mult(v)),
      'invulnerable' => l.skillFxInvulnerable(d),
      _ => def.effect,
    };
    if (def.cooldown <= Duration.zero) return text;
    return '$text · ${l.skillCooldown('${def.cooldown.inSeconds}')}';
  }

  Future<void> _toggle(AppLocalizations l, SkillDef def) async {
    final err = await _ctrl.toggleSkill(def.id);
    if (!mounted || err == null) return;
    showCenterToast(context, err == 'slots_full' ? l.skillSlotsFull : err);
  }

  Future<void> _train(
    AppLocalizations l,
    SkillConfig cfg,
    SaveGame save,
    SkillDef def,
    String locale,
  ) async {
    if (save.skillTrainingId != null) {
      showCenterToast(context, l.skillErrTrainingBusy);
      return;
    }
    final lv = save.skillLevels[def.id] ?? 0;
    final cost = skillTrainCost(save, cfg, def);
    final time = formatShortDuration(cfg.trainDuration(def, lv));
    final costText = cost.gradeShards > 0
        ? l.skillTrainCostWithAny('${cost.shards}', '${cost.gradeShards}', time)
        : l.skillTrainCostShards('${cost.shards}', time);
    final ok = await showGameDialog<bool>(
      context,
      title: l.skillTrainTitle(def.name.resolve(locale)),
      icon: Icons.auto_awesome_rounded,
      subtitle: 'Lv.$lv → Lv.${lv + 1}',
      content: Text(
        '${_effectText(l, def, lv + 1)}\n\n$costText',
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontSize: 13),
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.of(context, rootNavigator: true).pop(false),
          child: Text(l.actionCancel),
        ),
        FilledButton(
          onPressed: cost.enough
              ? () => Navigator.of(context, rootNavigator: true).pop(true)
              : null,
          child: Text(cost.enough ? l.skillTrain : l.skillErrNotEnoughShards),
        ),
      ],
    );
    if (ok != true || !mounted) return;
    final err = await _ctrl.startSkillTraining(def.id);
    if (!mounted || err == null) return;
    showCenterToast(context, _errText(l, err));
  }

  Future<void> _confirmInstant(
    AppLocalizations l,
    SkillConfig cfg,
    int jelly,
    String locale,
  ) async {
    final ok = await showGameDialog<bool>(
      context,
      title: l.skillTrainConfirmTitle,
      icon: Icons.bolt_rounded,
      content: Text(
        l.skillTrainConfirm('$jelly'),
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontSize: 13),
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.of(context, rootNavigator: true).pop(false),
          child: Text(l.actionCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(true),
          child: jellyPrice(cost: jelly, label: l.actionInstant),
        ),
      ],
    );
    if (ok != true || !mounted) return;
    await _complete(l, cfg, locale, viaJelly: true);
  }

  Future<void> _complete(
    AppLocalizations l,
    SkillConfig cfg,
    String locale, {
    bool viaJelly = false,
  }) async {
    final id = widget.save.skillTrainingId;
    final err = await _ctrl.completeSkillTraining(viaJelly: viaJelly);
    if (!mounted) return;
    if (err != null) {
      showCenterToast(context, _errText(l, err));
      return;
    }
    final save = ref.read(saveControllerProvider).value;
    final def = id == null ? null : cfg.byId(id);
    if (save == null || def == null) return;
    showCenterToast(
      context,
      l.skillLevelUpDone(def.name.resolve(locale), '${save.skillLevels[id]}'),
    );
  }

  String _errText(AppLocalizations l, String err) => switch (err) {
    'not_enough_shards' => l.skillErrNotEnoughShards,
    'training_busy' => l.skillErrTrainingBusy,
    'not_enough_jelly' => l.notEnoughJelly,
    'slots_full' => l.skillSlotsFull,
    _ => err,
  };

  Widget _button(
    String text,
    VoidCallback onTap, {
    bool on = false,
    bool dim = false,
    Color? accent,
    String? art,

    /// 값이 있으면 글자 대신 **젤리 가격표**(아이콘+숫자)를 그린다.
    int? jellyCost,
  }) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: Container(
      constraints: const BoxConstraints(minWidth: 54),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        // 장착은 **꽉 찬 꿀색**, 해제는 어두운 판(사장님 지시 2026-09-20).
        // 옅은 칠(0x33)로만 갈랐더니 무엇을 끼고 있는지 한눈에 안 보였다.
        color: on ? _honey : (accent ?? Colors.white).withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: on ? _honey : (accent ?? Colors.white).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 버튼 아트(없으면 글자만) — 있어도 없어도 배치가 같아야 한다.
          if (art != null) ...[
            skillButtonImage(art, size: 16, fallback: const SizedBox.shrink()),
            const SizedBox(width: 4),
          ],
          if (jellyCost != null)
            jellyPrice(
              cost: jellyCost,
              label: text,
              size: 13,
              fontSize: 11.5,
              color: dim ? const Color(0x66FFFFFF) : Colors.white,
            )
          else
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                // 꿀색 판 위에서는 흰 글자가 묻는다.
                color: on
                    ? const Color(0xFF3A2600)
                    : (dim ? const Color(0x66FFFFFF) : Colors.white),
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
        ],
      ),
    ),
  );

  BoxDecoration _box({Color border = const Color(0x22FFFFFF)}) => BoxDecoration(
    color: const Color(0x55121A10),
    borderRadius: BorderRadius.circular(10),
    border: Border.all(color: border),
  );
}

/// 스킬 카드·스킬 바의 아트 썸네일.
///
/// 미보유 스킬은 **흑백 실루엣**으로 둔다(도감의 미수집 보스와 같은 규칙) —
/// 무엇을 모으는 중인지 보이지 않으면 해금이 목표가 되지 않는다.
/// 애셋이 없으면 예전 Material 아이콘으로 폴백한다.
class _SkillArt extends StatelessWidget {
  const _SkillArt({
    required this.id,
    required this.owned,
    required this.active,
    required this.size,
  });

  final String id;
  final bool owned;
  final bool active;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallback = Icon(
      active ? Icons.bolt_rounded : Icons.auto_awesome_rounded,
      size: size * 0.62,
      color: active ? const Color(0xFF4FC3F7) : _honey,
    );
    final art = skillImage(id, size: size, fallback: fallback);
    if (owned) return art;
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix(<double>[
        0.2126, 0.7152, 0.0722, 0, 0, //
        0.2126, 0.7152, 0.0722, 0, 0, //
        0.2126, 0.7152, 0.0722, 0, 0, //
        0, 0, 0, 0.45, 0,
      ]),
      child: art,
    );
  }
}

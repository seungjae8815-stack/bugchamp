import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:core_save/core_save.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/game_data.dart';
import '../../domain/audio_service.dart';
import '../../domain/save_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/art.dart';
import '../../ui/bug_grade.dart';
import '../../ui/colors.dart';
import '../../ui/game_dialog.dart';
import '../../ui/labels.dart';
import '../../ui/toast.dart';

/// 개체 등급(2026-10-11, docs/design_individual_grade.md)의 채집함 화면 조각 —
/// 능력치 품질 막대 · 정수로 바꾸기 · 등급 올리기 · 정수 보관함 · 일괄 정수.
/// 모두 `individualGradeOn` 일 때만 불린다(꺼져 있으면 채집함은 예전 그대로).

/// 능력치 이름(롤 칸 순서).
String statRollLabel(AppLocalizations l, StatRoll s) => switch (s) {
  StatRoll.hp => l.igStatHp,
  StatRoll.atk => l.igStatAtk,
  StatRoll.def => l.igStatDef,
  StatRoll.spd => l.igStatSpd,
  StatRoll.crit => l.igStatCrit,
  StatRoll.evade => l.igStatEvade,
  StatRoll.recovery => l.igStatRecovery,
  StatRoll.push => l.igStatPush,
};

/// 크기 롤(0~100) — 종 크기 범위 안에서의 위치.
int sizeRollOf(Species sp, IndividualBug bug) {
  final span = sp.sizeMaxMm - sp.sizeMinMm;
  if (span <= 0) return 50;
  return ((bug.sizeMm - sp.sizeMinMm) / span * 100).round().clamp(0, 100);
}

/// 롤 값 색 — 낮으면 붉게, 가운데 노랗게, 높으면 푸르게.
Color rollQualityColor(int v) {
  if (v >= 85) return const Color(0xFF4FC3F7);
  if (v >= 60) return const Color(0xFF81C784);
  if (v >= 35) return const Color(0xFFFFD54F);
  return const Color(0xFFFF8A65);
}

/// 곤충 상세의 **능력치 품질** — 9칸(체력·공격·방어·속도·크기·치명·회피·회복력·밀어내기) + 평균.
/// 롤은 알 때부터 정해져 있지만 **알이면 숫자를 숨긴다**([hidden]) — 처음엔 알도 보여 주기로 했으나
/// 2026-10-14 사장님 확정으로 뒤집었다(능력치 숫자만 부화 뒤 공개, 등급·이색 같은 표식은 그대로).
Widget gradeQualityCard(
  AppLocalizations l,
  Species sp,
  IndividualBug bug, {
  bool hidden = false,
}) {
  final r = bug.statRolls;
  int at(StatRoll s) => s.index < r.length ? r[s.index] : 50;
  final rows = <(String, int)>[
    (l.igStatHp, at(StatRoll.hp)),
    (l.igStatAtk, at(StatRoll.atk)),
    (l.igStatDef, at(StatRoll.def)),
    (l.igStatSpd, at(StatRoll.spd)),
    (l.igStatSize, sizeRollOf(sp, bug)),
    (l.igStatCrit, at(StatRoll.crit)),
    (l.igStatEvade, at(StatRoll.evade)),
    (l.igStatRecovery, at(StatRoll.recovery)),
    (l.igStatPush, at(StatRoll.push)),
  ];
  final avg = rows.fold<int>(0, (a, e) => a + e.$2) / rows.length;
  Widget bar((String, int) e) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 1.5),
    child: Row(
      children: [
        SizedBox(
          width: 52,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              e.$1,
              maxLines: 1,
              style: const TextStyle(color: Color(0xB3FFFFFF), fontSize: 11),
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: hidden ? 0 : e.$2 / 100,
              minHeight: 6,
              backgroundColor: const Color(0x22FFFFFF),
              valueColor: AlwaysStoppedAnimation(rollQualityColor(e.$2)),
            ),
          ),
        ),
        SizedBox(
          width: 28,
          child: Text(
            hidden ? l.hiddenStatValue : '${e.$2}',
            textAlign: TextAlign.right,
            style: TextStyle(
              color: hidden ? const Color(0x88FFFFFF) : rollQualityColor(e.$2),
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    ),
  );
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
    decoration: BoxDecoration(
      color: const Color(0x22000000),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              l.igQualityTitle,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
            const Spacer(),
            Text(
              l.igQualityAvg(
                hidden ? l.hiddenStatValue : avg.toStringAsFixed(0),
              ),
              style: TextStyle(
                color: hidden
                    ? const Color(0x88FFFFFF)
                    : rollQualityColor(avg.round()),
                fontWeight: FontWeight.w900,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        for (final e in rows) bar(e),
        const SizedBox(height: 3),
        Text(
          hidden ? l.eggStatsHidden : l.igQualityHint,
          style: const TextStyle(color: Color(0x88FFFFFF), fontSize: 10.5),
        ),
      ],
    ),
  );
}

/// 곤충 상세의 개체 등급 동작 — **등급 올리기** + **정수로 바꾸기**.
Widget gradeActionsCard(
  BuildContext ctx,
  WidgetRef r,
  GameData data,
  SaveGame save,
  IndividualBug bug,
) {
  final l = AppLocalizations.of(ctx);
  final cfg = data.petConfig!.individualGrade;
  final sp = data.species(bug.speciesId);
  final locale = Localizations.localeOf(ctx).languageCode;
  final isEgg = bug.stage == LifeStage.egg;
  final pinned = save.pinnedBugIds.contains(bug.id);
  final maxed = bug.potential >= kPotentialMax;
  final need = cfg.upgradeCost(bug.potential);
  final have = save.essence[bug.speciesId] ?? 0;
  final name = sp.name.resolve(locale);

  // 정수가 모자라면 버튼을 끈다 — 켜 둔 채 누르게 하면 창까지 열고 나서야 "부족"을 알게 된다.
  final short = !isEgg && !maxed && have < need;
  final upDesc = isEgg
      ? l.igGradeUpEgg
      : maxed
      ? l.igGradeUpMax
      : short
      ? '${l.igGradeUpDesc(name, '$have', '$need')} · ${l.igNeedMoreEssence('${need - have}')}'
      : l.igGradeUpDesc(name, '$have', '$need');
  final essenceReason = isEgg
      ? l.igToEssenceEgg
      : pinned
      ? l.igToEssencePinned
      : null;

  return Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0x22000000),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            gameIcon('star_up', size: 23, fallback: Icons.trending_up_rounded),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.igGradeUp,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                    ),
                  ),
                  Text(
                    upDesc,
                    style: TextStyle(
                      color: short
                          ? const Color(0xFFFF8A65)
                          : const Color(0xB3FFFFFF),
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            FilledButton(
              onPressed: isEgg || maxed || short
                  ? null
                  : () => _openGradeUp(ctx, r, data, bug.id),
              style: FilledButton.styleFrom(
                backgroundColor: kHoney,
                foregroundColor: kHoneyInk,
                minimumSize: const Size(0, 36),
              ),
              child: Text(l.igGradeUp),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Text(
                essenceReason ?? l.igVaultHint,
                style: const TextStyle(color: Color(0x99FFFFFF), fontSize: 11),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: essenceReason != null
                  ? null
                  : () => confirmBugToEssence(ctx, r, data, bug),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFB39DDB),
                side: const BorderSide(color: Color(0x66B39DDB)),
                minimumSize: const Size(0, 34),
              ),
              child: Text(l.igToEssence),
            ),
          ],
        ),
      ],
    ),
  );
}

/// 이 곤충을 정수로 바꾸면 잃는 것(사유 문구) — 이색·수련·돌파·부위 강화·물약 롤.
///
/// 장착·훈련 포인트·잠금(`pinnedBugIds`)은 여기 없다 — 그런 곤충은 버튼부터 꺼져 있고 규칙 함수도 거절한다.
List<String> preciousReasons(AppLocalizations l, IndividualBug bug) => [
  if (bug.variant != BugVariant.none) l.igEssenceWarnVariant,
  if (bug.level > 1) l.igEssenceWarnLevel('${bug.level}'),
  if (bug.breakthroughTier > 0) l.igEssenceWarnBreak('${bug.breakthroughTier}'),
  if (bug.enhancement.total > 0) l.igEssenceWarnEnhance,
  if (bug.rolls != null) l.igToEssencePotionWarn,
];

/// 정수로 바꾸기 — 받을 양을 보여 주고 확인받는다.
///
/// 아끼던 곤충(`isPreciousBug` — 이색·수련·돌파·부위 강화·물약 롤)이면 **무엇을 잃는지 사유를 적은 경고**로 묻고,
/// 이색이면 한 번 더 묻는다(설계 문서 §2.4 — 1/300 개체가 버튼 한 번에 사라지면 그게 곧 클레임이다).
/// 분해 확인 창의 "정수로 바꾸기"도 이 함수를 탄다.
Future<void> confirmBugToEssence(
  BuildContext ctx,
  WidgetRef r,
  GameData data,
  IndividualBug bug,
) async {
  final l = AppLocalizations.of(ctx);
  final cfg = data.petConfig!.individualGrade;
  final sp = data.species(bug.speciesId);
  final name = sp.name.resolve(Localizations.localeOf(ctx).languageCode);
  final gain = cfg.essenceOf(bug, sp.grade);
  final reasons = preciousReasons(l, bug);
  final precious = reasons.isNotEmpty;
  // 결과 알림은 앱 화면 기준으로 — 곤충이 사라지면 이 창도 닫힌다(분해와 같은 이유).
  final host = Navigator.of(ctx).context;
  const warn = Color(0xFFFF8A65);
  final go = await showGameDialog<bool>(
    ctx,
    title: l.igToEssence,
    icon: precious ? Icons.warning_amber_rounded : Icons.blur_on_rounded,
    iconWidget: precious ? null : _essenceIcon(),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l.igToEssenceConfirm('$gain', name),
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 13),
        ),
        if (precious) ...[
          const SizedBox(height: 10),
          Text(
            l.igEssenceWarnTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: warn,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          for (final s in reasons)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                '· $s',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: warn,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ],
    ),
    actions: [
      gameDialogButton(
        l.actionCancel,
        () => Navigator.pop(ctx, false),
        primary: false,
      ),
      gameDialogButton(
        l.igToEssence,
        () => Navigator.pop(ctx, true),
        color: precious ? const Color(0xFFB3452F) : null,
      ),
    ],
  );
  if (go != true || !ctx.mounted) return;
  // 이색은 반드시 한 번 더 — 되찾을 수 없는 1/300 개체다.
  if (bug.variant != BugVariant.none) {
    final again = await showGameDialog<bool>(
      ctx,
      title: l.igToEssence,
      icon: Icons.warning_amber_rounded,
      content: Text(
        l.igEssenceVariantAgain(name),
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: warn,
          fontSize: 13.5,
          fontWeight: FontWeight.w900,
        ),
      ),
      actions: [
        gameDialogButton(
          l.actionCancel,
          () => Navigator.pop(ctx, false),
          primary: false,
        ),
        gameDialogButton(
          l.igToEssence,
          () => Navigator.pop(ctx, true),
          color: const Color(0xFFB3452F),
        ),
      ],
    );
    if (again != true || !ctx.mounted) return;
  }
  final res = await r
      .read(saveControllerProvider.notifier)
      .convertBugsToEssence([bug.id]);
  if (!ctx.mounted) return;
  if (!res.isOk) {
    showCenterToast(ctx, switch (res.error) {
      'egg' => l.igToEssenceEgg,
      'pinned' => l.igToEssencePinned,
      _ => l.igGradeFailed,
    });
    return;
  }
  Navigator.pop(ctx); // 곤충 상세(바텀시트) 닫기 — 곤충이 사라졌다.
  if (host.mounted) showCenterToast(host, l.igEssenceGot(name, '$gain'));
}

/// 등급 올리기 창 — 지금/다음 등급 · 정수 보유/필요 · 물약 0~min(한 번 최대, 보유).
Future<void> _openGradeUp(
  BuildContext ctx,
  WidgetRef r,
  GameData data,
  String bugId,
) async {
  final l = AppLocalizations.of(ctx);
  final cfg = data.petConfig!.individualGrade;
  final save = r.read(saveControllerProvider).requireValue;
  IndividualBug? bug;
  for (final b in save.bugs) {
    if (b.id == bugId) bug = b;
  }
  if (bug == null) return;
  final sp = data.species(bug.speciesId);
  final name = sp.name.resolve(Localizations.localeOf(ctx).languageCode);
  final need = cfg.upgradeCost(bug.potential);
  final have = save.essence[bug.speciesId] ?? 0;
  final maxPotions = save.growthPotions < cfg.potionMaxPerUse
      ? save.growthPotions
      : cfg.potionMaxPerUse;
  final from = gradeOfPotential(bug.potential);
  final to = gradeOfPotential(bug.potential + 1);
  var potions = 0;

  final go = await showGameDialog<bool>(
    ctx,
    title: l.igGradeUp,
    icon: Icons.trending_up_rounded,
    iconWidget: gameIcon(
      'star_up',
      size: 40,
      fallback: Icons.trending_up_rounded,
    ),
    content: StatefulBuilder(
      builder: (context, setState) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: gradeLabel(l, from),
                  style: TextStyle(color: gradeColor(from)),
                ),
                const TextSpan(
                  text: '  →  ',
                  style: TextStyle(color: Colors.white70),
                ),
                TextSpan(
                  text: gradeLabel(l, to),
                  style: TextStyle(color: gradeColor(to)),
                ),
              ],
            ),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            l.igGradeUpDesc(name, '$have', '$need'),
            style: TextStyle(
              color: have >= need ? Colors.white : const Color(0xFFFF8A65),
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (have < need)
            Text(
              l.igNeedMoreEssence('${need - have}'),
              style: const TextStyle(color: Color(0xFFFF8A65), fontSize: 12),
            ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: potions > 0
                    ? () => setState(() => potions -= 1)
                    : null,
                icon: const Icon(Icons.remove_circle_outline),
                color: Colors.white,
              ),
              _potionIcon(20),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  l.igPotionUse('$potions', '${save.growthPotions}'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFB2EBF2),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                onPressed: potions < maxPotions
                    ? () => setState(() => potions += 1)
                    : null,
                icon: const Icon(Icons.add_circle_outline),
                color: Colors.white,
              ),
            ],
          ),
          Text(
            l.igPotionHint('${cfg.potionRollBonus}'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0x99FFFFFF), fontSize: 11),
          ),
        ],
      ),
    ),
    actions: [
      gameDialogButton(
        l.actionCancel,
        () => Navigator.pop(ctx, false),
        primary: false,
      ),
      // 정수가 모자라면 올리기 버튼을 두지 않는다(필요/보유는 위 줄이 말한다).
      if (have >= need)
        gameDialogButton(l.igGradeUp, () => Navigator.pop(ctx, true)),
    ],
  );
  if (go != true || !ctx.mounted) return;
  final res = await r
      .read(saveControllerProvider.notifier)
      .gradeUpBug(bugId, potions: potions);
  if (!ctx.mounted) return;
  if (!res.isOk) {
    showCenterToast(ctx, switch (res.error) {
      'no_essence' => l.igNoEssence,
      'egg' => l.igGradeUpEgg,
      'max' => l.igGradeUpMax,
      _ => l.igGradeFailed,
    });
    return;
  }
  AudioService.instance.sfxLevelUp();
  final before = (res.extra['before'] as List?)?.cast<int>() ?? const [];
  final after = (res.extra['after'] as List?)?.cast<int>() ?? const [];
  // 펫 패시브 이전 → 이후(1.0.21) — 크기가 개체 등급을 따라 커진다. 값은 화면·합산과 같은 `passiveOf`.
  String? passiveLine;
  final petCfg = data.petConfig;
  if (petCfg != null) {
    IndividualBug? upgraded;
    for (final b in r.read(saveControllerProvider).requireValue.bugs) {
      if (b.id == bugId) upgraded = b;
    }
    final pb = passiveOf(bug, sp, petCfg);
    final pa = upgraded == null ? null : passiveOf(upgraded, sp, petCfg);
    if (pb != null && pa != null) {
      passiveLine = l.igGradeUpPassive(
        passiveKindLabel(l, pa.statKey),
        _passiveValuePart(l, pb),
        _passiveValuePart(l, pa),
      );
    }
  }
  await _showGradeUpResult(ctx, l, to, before, after, passiveLine);
}

/// 패시브 한 줄("골드 +5.4%")에서 크기만("+5.4%") — 종류 이름은 한 번만 쓴다.
String _passiveValuePart(AppLocalizations l, SpeciesPassive p) {
  final full = passiveText(l, p);
  final kind = passiveKindLabel(l, p.statKey);
  return kind.isNotEmpty && full.startsWith('$kind ')
      ? full.substring(kind.length + 1)
      : full;
}

/// 등급 올리기 결과 — 칸마다 이전 → 이후(좋아진 칸은 강조).
Future<void> _showGradeUpResult(
  BuildContext ctx,
  AppLocalizations l,
  Grade to,
  List<int> before,
  List<int> after, [
  String? passiveLine,
]) {
  var improved = 0;
  final rows = <Widget>[];
  for (final s in StatRoll.values) {
    if (s.index >= before.length || s.index >= after.length) continue;
    final b = before[s.index], a = after[s.index];
    final up = a > b;
    if (up) improved++;
    rows.add(
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 1.5),
        child: Row(
          children: [
            SizedBox(
              width: 64,
              child: Text(
                statRollLabel(l, s),
                style: const TextStyle(color: Color(0xB3FFFFFF), fontSize: 12),
              ),
            ),
            Text(
              '$b',
              style: const TextStyle(color: Color(0x99FFFFFF), fontSize: 12.5),
            ),
            const Text(
              '  →  ',
              style: TextStyle(color: Color(0x66FFFFFF), fontSize: 12),
            ),
            Text(
              '$a',
              style: TextStyle(
                color: up ? const Color(0xFF81C784) : Colors.white,
                fontSize: 13,
                fontWeight: up ? FontWeight.w900 : FontWeight.w600,
              ),
            ),
            if (up)
              Text(
                '  +${a - b}',
                style: const TextStyle(
                  color: Color(0xFF81C784),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
          ],
        ),
      ),
    );
  }
  return showGameDialog<void>(
    ctx,
    title: l.igGradeUpDone(gradeLabel(l, to)),
    icon: Icons.auto_awesome_rounded,
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.igGradeUpImproved('$improved'),
          style: TextStyle(
            color: gradeColor(to),
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        ...rows,
        if (passiveLine != null) ...[
          const SizedBox(height: 8),
          Text(
            passiveLine,
            style: const TextStyle(
              color: kHoney,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ],
    ),
    actions: [gameDialogButton(l.actionClose, () => Navigator.pop(ctx))],
  );
}

/// 정수 보관함 — 종별 정수 + 성장물약 수.
Future<void> showEssenceVault(BuildContext ctx, WidgetRef ref, GameData data) {
  final l = AppLocalizations.of(ctx);
  final save = ref.read(saveControllerProvider).requireValue;
  final locale = Localizations.localeOf(ctx).languageCode;
  final entries = save.essence.entries.where((e) => e.value > 0).toList()
    ..sort((a, b) {
      final ga = data.speciesById[a.key]?.grade.index ?? 0;
      final gb = data.speciesById[b.key]?.grade.index ?? 0;
      if (ga != gb) return gb - ga;
      return b.value - a.value;
    });
  return showGameDialog<void>(
    ctx,
    title: l.igVaultTitle,
    icon: Icons.blur_on_rounded,
    iconWidget: _essenceIcon(),
    content: ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 360),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _potionIcon(20),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    l.igPotionOwned('${save.growthPotions}'),
                    style: const TextStyle(
                      color: Color(0xFFB2EBF2),
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (entries.isEmpty)
              Text(
                l.igVaultEmpty,
                style: const TextStyle(color: Color(0x99FFFFFF), fontSize: 12),
              )
            else
              for (final e in entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          data.speciesById[e.key]?.name.resolve(locale) ??
                              e.key,
                          style: TextStyle(
                            color: data.speciesById[e.key] == null
                                ? Colors.white
                                : gradeColor(data.speciesById[e.key]!.grade),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        '${e.value}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
            const SizedBox(height: 8),
            Text(
              l.igVaultHint,
              style: const TextStyle(color: Color(0x88FFFFFF), fontSize: 11),
            ),
          ],
        ),
      ),
    ),
    actions: [gameDialogButton(l.actionClose, () => Navigator.pop(ctx))],
  );
}

/// 여러 곤충을 한 번에 정수로(자동 분해 창의 대안 버튼).
///
/// 곤충이 사라지는 동작이라 **받을 정수를 먼저 보여 주고 확인받는다** — 미리보기는 저장하지 않는
/// 같은 규칙 함수(`convertToEssence`)로 계산해 실제 결과와 어긋나지 않는다.
Future<void> convertBulkToEssence(
  BuildContext ctx,
  WidgetRef ref,
  GameData data,
  List<String> ids,
) async {
  final l = AppLocalizations.of(ctx);
  final cfg = data.petConfig?.individualGrade;
  if (ids.isEmpty || cfg == null) {
    showCenterToast(ctx, l.igBulkNone);
    return;
  }
  final save = ref.read(saveControllerProvider).requireValue;
  final preview = convertToEssence(save, ids, cfg, data.speciesById);
  if (!preview.isOk) {
    // 대상이 모두 알·보호 곤충이면 왜 못 바꾸는지 알려 준다(자동 분해 목록엔 알도 들어 있다).
    showCenterToast(ctx, switch (preview.error) {
      'egg' => l.igToEssenceEgg,
      'pinned' => l.igToEssencePinned,
      _ => l.igBulkNone,
    });
    return;
  }
  final gained =
      (preview.extra['gained'] as Map?)?.cast<String, int>() ??
      const <String, int>{};
  final total = gained.values.fold<int>(0, (a, b) => a + b);
  final n = preview.extra['converted'] as int? ?? 0;
  final potionBugs = preview.extra['potionBugs'] as int? ?? 0;
  final locale = Localizations.localeOf(ctx).languageCode;
  final lines = gained.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  const shown = 6;
  final go = await showGameDialog<bool>(
    ctx,
    title: l.igToEssence,
    icon: Icons.blur_on_rounded,
    iconWidget: _essenceIcon(),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.igBulkConfirm('$n'),
          style: const TextStyle(color: Colors.white, fontSize: 13),
        ),
        const SizedBox(height: 8),
        Text(
          l.igBulkConfirmTotal('$total'),
          style: const TextStyle(
            color: Color(0xFFB39DDB),
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        for (final e in lines.take(shown))
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              l.igEssenceGot(
                data.speciesById[e.key]?.name.resolve(locale) ?? e.key,
                '${e.value}',
              ),
              style: const TextStyle(color: Color(0xDDFFFFFF), fontSize: 12),
            ),
          ),
        if (lines.length > shown)
          Text(
            l.autoPreviewMore(lines.length - shown),
            style: const TextStyle(color: Color(0x99FFFFFF), fontSize: 11.5),
          ),
        if (potionBugs > 0) ...[
          const SizedBox(height: 8),
          Text(
            l.igBulkPotionWarn('$potionBugs'),
            style: const TextStyle(
              color: Color(0xFFFF8A65),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ],
    ),
    actions: [
      gameDialogButton(
        l.actionCancel,
        () => Navigator.pop(ctx, false),
        primary: false,
      ),
      gameDialogButton(l.igToEssence, () => Navigator.pop(ctx, true)),
    ],
  );
  if (go != true || !ctx.mounted) return;
  final res = await ref
      .read(saveControllerProvider.notifier)
      .convertBugsToEssence(ids);
  if (!ctx.mounted) return;
  if (!res.isOk) {
    showCenterToast(ctx, switch (res.error) {
      'egg' => l.igToEssenceEgg,
      'pinned' => l.igToEssencePinned,
      _ => l.igBulkNone,
    });
    return;
  }
  final done = res.extra['converted'] as int? ?? 0;
  final got =
      ((res.extra['gained'] as Map?)?.cast<String, int>() ??
              const <String, int>{})
          .values
          .fold<int>(0, (a, b) => a + b);
  final eggs = res.extra['skippedEggs'] as int? ?? 0;
  final pinned = res.extra['skippedPinned'] as int? ?? 0;
  final head = l.igBulkDoneGain('$done', '$got');
  showCenterToast(
    ctx,
    eggs + pinned > 0 ? '$head\n${l.igBulkSkipped('$eggs', '$pinned')}' : head,
  );
}

/// 정수 팝업 제목 그림(`essence.webp`) — 없으면 예전 아이콘.
Widget _essenceIcon() =>
    gameIcon('essence', size: 40, fallback: Icons.blur_on_rounded);

/// 성장물약 그림(`potion.webp`) — 없으면 플라스크 아이콘.
Widget _potionIcon(double size) => gameIcon(
  'potion',
  size: size,
  fallback: Icons.science_rounded,
  color: const Color(0xFFB2EBF2),
);

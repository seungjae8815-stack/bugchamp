import 'package:core_models/core_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/audio_service.dart';
import '../../domain/providers.dart';
import '../../domain/save_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/art.dart';
import '../../ui/colors.dart';
import '../../ui/game_dialog.dart';
import '../../ui/bug_grade.dart';
import '../../ui/skins.dart';
import 'grade_panel.dart';

/// 부화 공개 연출(2026-10-14 사장님 확정) — 알일 때 숨겼던 능력치 9칸이 **부화하는 순간** 하나씩 차오른다.
/// 평균이 [_greatAvg] 이상이면 반짝이는 문구와 희귀 효과음. 여러 마리를 한꺼번에 받으면 차례로 보여 주고
/// "모두 건너뛰기"로 끝낼 수 있다. 연출만 한다 — 세이브는 이미 바뀐 뒤다.
///
/// **정수로 바꾸기**(2026-10-14 사장님 확정): 핵심 반복(부화 → 능력치 확인 → 남길지 정수로 바꿀지)을 이 창에서 끝낸다.
/// 확인 창은 채집함과 같은 [confirmBugToEssence](아끼던 곤충 경고 포함). 평균 [_greatAvg] 이상이면 버튼을 흐리게 두고
/// 한 번 더 묻는다 — 좋은 개체를 실수로 잃지 않게.
const _greatAvg = 85;

/// 공개 창에 보이는 9칸 평균([_RevealBody] 와 같은 값).
int _revealAvg(IndividualBug bug, Species sp, List<int>? preview) {
  final List<int> v;
  if (preview != null && preview.length >= 9) {
    v = preview.take(9).toList();
  } else {
    final r = bug.statRolls;
    int at(StatRoll s) => s.index < r.length ? r[s.index] : 50;
    v = [
      at(StatRoll.hp),
      at(StatRoll.atk),
      at(StatRoll.def),
      at(StatRoll.spd),
      sizeRollOf(sp, bug),
      at(StatRoll.crit),
      at(StatRoll.evade),
      at(StatRoll.recovery),
      at(StatRoll.push),
    ];
  }
  return (v.fold<int>(0, (a, e) => a + e) / v.length).round();
}

Future<void> showHatchReveal(
  BuildContext context,
  WidgetRef ref,
  List<String> bugIds, {
  // 개발자 모드 미리보기 전용 — 9칸 값을 이것으로 바꿔 보여 준다(세이브와 무관).
  List<int>? previewRolls,
}) async {
  var animate = true;
  for (var i = 0; i < bugIds.length; i++) {
    if (!context.mounted) return;
    final save = ref.read(saveControllerProvider).value;
    final data = ref.read(gameDataProvider).value;
    if (save == null || data == null) return;
    final bug = save.bugs.where((b) => b.id == bugIds[i]).firstOrNull;
    final sp = bug == null ? null : data.speciesById[bug.speciesId];
    if (bug == null || sp == null) continue;
    final l = AppLocalizations.of(context);
    final more = bugIds.length - i - 1;
    final great = _revealAvg(bug, sp, previewRolls) >= _greatAvg;
    // 정수로 바꿀 수 있나 — 개체 등급이 켜져 있고, 장착·잠금 등 보호 곤충이 아니어야 한다(채집함 버튼과 같은 조건).
    final canEssence =
        previewRolls == null &&
        individualGradeOn(data) &&
        !save.pinnedBugIds.contains(bug.id);
    final nav = Navigator.of(context, rootNavigator: true);
    // 'next' 다음 · 'skip' 모두 건너뛰기 · 'essence' 정수로 바꾸기 · null 닫음
    final act = await showGameDialog<String>(
      context,
      title: l.hatchRevealTitle,
      icon: Icons.egg_alt_rounded,
      content: _RevealBody(
        bug: bug,
        species: sp,
        skin: bugView(ref.read(skinOfProvider), bug),
        previewRolls: previewRolls,
        animate: animate,
      ),
      actions: [
        if (canEssence)
          gameDialogButton(
            l.igToEssence,
            () => nav.pop('essence'),
            primary: false,
            // 아주 좋은 개체는 흐린 색 — 눈에 덜 띄게(사장님 확정 제안).
            color: great ? const Color(0x66B39DDB) : const Color(0xFF7E57C2),
          ),
        if (more > 0)
          gameDialogButton(
            l.hatchRevealSkipAll,
            () => nav.pop('skip'),
            primary: false,
          ),
        gameDialogButton(
          more > 0 ? l.hatchRevealNext('$more') : l.hatchRevealOk,
          () => nav.pop('next'),
        ),
      ],
    );
    animate = true;
    if (act == 'essence') {
      if (!context.mounted) return;
      // 아주 좋은 개체는 한 번 더 묻는다.
      if (great) {
        final sure = await showGameDialog<bool>(
          context,
          title: l.igToEssence,
          icon: Icons.warning_amber_rounded,
          content: Text(
            l.hatchRevealGreatEssenceWarn(
              '${_revealAvg(bug, sp, previewRolls)}',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
          actions: [
            gameDialogButton(
              l.actionCancel,
              () => nav.pop(false),
              primary: false,
            ),
            gameDialogButton(
              l.igToEssence,
              () => nav.pop(true),
              color: const Color(0xFFB3452F),
            ),
          ],
        );
        if (sure != true || !context.mounted) {
          i--; // 같은 곤충 창으로 돌아간다(연출 없이).
          animate = false;
          continue;
        }
      }
      if (!context.mounted) return;
      await confirmBugToEssence(context, ref, data, bug);
      if (!context.mounted) return;
      final still = ref
          .read(saveControllerProvider)
          .value
          ?.bugs
          .any((b) => b.id == bug.id);
      if (still ?? false) {
        // 확인 창에서 취소 — 같은 곤충 창으로 돌아간다(연출 없이).
        i--;
        animate = false;
      }
      continue;
    }
    if (act != 'next') return;
  }
}

class _RevealBody extends StatefulWidget {
  const _RevealBody({
    required this.bug,
    required this.species,
    this.skin,
    this.previewRolls,
    this.animate = true,
  });
  final IndividualBug bug;
  final Species species;
  final SkinView? skin;
  final List<int>? previewRolls;

  /// 거짓이면 차오르는 연출 없이 바로 다 보인다(정수 바꾸기를 취소하고 돌아왔을 때).
  final bool animate;

  @override
  State<_RevealBody> createState() => _RevealBodyState();
}

class _RevealBodyState extends State<_RevealBody>
    with SingleTickerProviderStateMixin {
  // 한 칸 0.18초씩 9칸 + 마지막 평균 — 약 2초.
  static const _per = 180;
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _per * 10),
    value: widget.animate ? 0 : 1,
  )..forward();
  late var _cheered = !widget.animate;

  List<(String, int)> _rows(AppLocalizations l) {
    final r = widget.bug.statRolls;
    int at(StatRoll s) => s.index < r.length ? r[s.index] : 50;
    final p = widget.previewRolls;
    if (p != null && p.length >= 9) {
      final names = [
        l.igStatHp,
        l.igStatAtk,
        l.igStatDef,
        l.igStatSpd,
        l.igStatSize,
        l.igStatCrit,
        l.igStatEvade,
        l.igStatRecovery,
        l.igStatPush,
      ];
      return [for (var i = 0; i < 9; i++) (names[i], p[i])];
    }
    return [
      (l.igStatHp, at(StatRoll.hp)),
      (l.igStatAtk, at(StatRoll.atk)),
      (l.igStatDef, at(StatRoll.def)),
      (l.igStatSpd, at(StatRoll.spd)),
      (l.igStatSize, sizeRollOf(widget.species, widget.bug)),
      (l.igStatCrit, at(StatRoll.crit)),
      (l.igStatEvade, at(StatRoll.evade)),
      (l.igStatRecovery, at(StatRoll.recovery)),
      (l.igStatPush, at(StatRoll.push)),
    ];
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final rows = _rows(l);
    final avg = (rows.fold<int>(0, (a, e) => a + e.$2) / rows.length).round();
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value * 10; // 0~10 칸
        final done = t >= 9.5;
        if (done && !_cheered) {
          _cheered = true;
          // 빌드 중에 소리를 내지 않는다 — 다음 프레임에.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (avg >= _greatAvg) AudioService.instance.sfxRare();
          });
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            bugStageImage(
              widget.bug.speciesId,
              LifeStage.larva,
              size: 72,
              fallback: bugAvatar(widget.species, size: 64),
              skin: widget.skin,
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < rows.length; i++)
              _bar(rows[i].$1, rows[i].$2, ((t - i)).clamp(0.0, 1.0)),
            const SizedBox(height: 8),
            AnimatedOpacity(
              opacity: done ? 1 : 0,
              duration: const Duration(milliseconds: 250),
              child: Column(
                children: [
                  Text(
                    l.hatchRevealAvg('$avg'),
                    style: TextStyle(
                      color: rollQualityColor(avg),
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (avg >= _greatAvg)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        l.hatchRevealGreat,
                        style: const TextStyle(
                          color: kHoney,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _bar(String label, int value, double p) {
    final shown = (value * p).round();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                label,
                maxLines: 1,
                style: const TextStyle(color: Color(0xB3FFFFFF), fontSize: 11),
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: shown / 100,
                minHeight: 6,
                backgroundColor: const Color(0x22FFFFFF),
                valueColor: AlwaysStoppedAnimation(rollQualityColor(value)),
              ),
            ),
          ),
          SizedBox(
            width: 28,
            child: Text(
              p <= 0 ? '' : '$shown',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: rollQualityColor(value),
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

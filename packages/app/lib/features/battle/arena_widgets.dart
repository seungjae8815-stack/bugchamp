import 'package:core_battle/core_battle.dart';
import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:flutter/material.dart' hide Element;

import '../../data/game_data.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/art.dart';
import '../../ui/format.dart';
import '../../ui/game_dialog.dart';
import '../../ui/labels.dart';

/// 오토 아레나(`battle_arena.dart`)와 수동 배틀(`manual_battle_screen.dart`)이
/// 공유하는 순수 표시 위젯. 파이터/데미지 플로트/결과 다이얼로그를 한 곳에 둔다.

const arenaHoney = Color(0xFFEBA52F);
const kRoundDur = 0.85; // 라운드 1회 재생 시간(초, 1x)

String stanceGlyph(Stance s) => switch (s) {
  Stance.attack => '⚔️',
  Stance.defend => '🛡️',
  Stance.heal => '💚',
};

String stanceLabel(AppLocalizations l, Stance s) => switch (s) {
  Stance.attack => l.stanceAttack,
  Stance.defend => l.stanceDefend,
  Stance.heal => l.stanceHeal,
};

Color stanceColor(Stance s) => switch (s) {
  Stance.attack => const Color(0xFFC1502E),
  Stance.defend => const Color(0xFF2E6DA4),
  Stance.heal => const Color(0xFF3E7D4F),
};

IconData stanceIcon(Stance s) => switch (s) {
  Stance.attack => Icons.sports_mma_rounded,
  Stance.defend => Icons.shield_rounded,
  Stance.heal => Icons.favorite_rounded,
};

/// 떠오르는 데미지/회복 숫자(가변 age 를 가진 애니메이션 상태).
class FloatText {
  FloatText(this.text, this.color, this.left);
  final String text;
  final Color color;
  final bool left;
  double age = 0;
  static const life = 0.9;
}

/// 오행 상극(克) 히트 시 터지는 링 버스트(가변 age).
class BurstFx {
  BurstFx({required this.left, required this.color});
  final bool left;
  final Color color;
  double age = 0;
  static const life = 0.45;
}

/// 아레나 한쪽 파이터: 이름·오행·HP바·캐릭터·스탠스 글리프.
/// [dx] 는 이미 방향이 반영된 최종 돌진 오프셋. [stanceHidden] 이면 스탠스를 ❓로 가림(심리전).
class ArenaFighter extends StatelessWidget {
  const ArenaFighter({
    super.key,
    required this.data,
    required this.bug,
    required this.speciesId,
    required this.hpFrac,
    required this.flip,
    required this.stance,
    required this.flash,
    required this.dx,
    this.stanceHidden = false,
  });

  final GameData data;
  final BattleBug bug;
  final String? speciesId;
  final double hpFrac;
  final bool flip;
  final Stance? stance;
  final double flash;
  final double dx;
  final bool stanceHidden;

  @override
  Widget build(BuildContext context) {
    final u = bug;
    final sp = data.speciesById[speciesId ?? ''];
    Widget img = sp == null
        ? const Icon(Icons.bug_report, color: Colors.white, size: 60)
        : bugStageImage(
            sp.id,
            LifeStage.adult,
            size: 96,
            fallback: bugAvatar(sp, size: 84),
          );
    if (flip) img = Transform.flip(flipX: true, child: img);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                elementGlyph(u.element),
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  u.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: elementColor(u.element),
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 120,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Stack(
                children: [
                  Container(height: 12, color: const Color(0x55000000)),
                  FractionallySizedBox(
                    widthFactor: hpFrac,
                    child: Container(
                      height: 12,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: hpFrac > 0.3
                              ? const [Color(0xFF7CE38B), Color(0xFF3FA84E)]
                              : const [Color(0xFFFF8A6B), Color(0xFFD84A2E)],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                Transform.translate(
                  offset: Offset(dx, 0),
                  // 교대 시 슬라이드-인/아웃(KO 퇴장 + 다음 파이터 등장).
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    switchInCurve: Curves.easeOutBack,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position: Tween(
                          begin: Offset(flip ? 0.7 : -0.7, 0),
                          end: Offset.zero,
                        ).animate(anim),
                        child: child,
                      ),
                    ),
                    child: KeyedSubtree(
                      key: ValueKey(bug.id),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          img,
                          if (flash > 0)
                            Positioned.fill(
                              child: IgnorePointer(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFFFF3B3B,
                                    ).withValues(alpha: flash * 0.5),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (stance != null || stanceHidden)
                  Positioned(
                    top: -14,
                    child: Text(
                      stanceHidden ? '❓' : stanceGlyph(stance!),
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 떠오르는 데미지/회복 숫자 위젯.
class ArenaFloat extends StatelessWidget {
  const ArenaFloat({super.key, required this.f});
  final FloatText f;

  @override
  Widget build(BuildContext context) {
    final t = (f.age / FloatText.life).clamp(0.0, 1.0);
    final w = MediaQuery.of(context).size.width;
    final x = f.left ? w * 0.25 : w * 0.72;
    return Positioned(
      left: x - 24,
      top: 150 - t * 60,
      child: Opacity(
        opacity: (1 - t).clamp(0.0, 1.0),
        child: Text(
          f.text,
          style: TextStyle(
            color: f.color,
            fontWeight: FontWeight.w900,
            fontSize: 22,
            shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
          ),
        ),
      ),
    );
  }
}

/// 오행 상극(克) 링 버스트 이펙트.
class ArenaBurst extends StatelessWidget {
  const ArenaBurst({super.key, required this.fx});
  final BurstFx fx;

  @override
  Widget build(BuildContext context) {
    final t = (fx.age / BurstFx.life).clamp(0.0, 1.0);
    final size = 28 + t * 92;
    final w = MediaQuery.of(context).size.width;
    final cx = fx.left ? w * 0.25 : w * 0.72;
    return Positioned(
      left: cx - size / 2,
      top: 178 - size / 2,
      child: IgnorePointer(
        child: Opacity(
          opacity: (1 - t).clamp(0.0, 1.0),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: fx.color, width: 3 * (1 - t) + 1),
              boxShadow: [
                BoxShadow(
                  color: fx.color.withValues(alpha: 0.5 * (1 - t)),
                  blurRadius: 14,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 결과 다이얼로그의 팀 HP% 막대.
Widget arenaTeamHpBar(String label, double pct, Color color) => Row(
  children: [
    SizedBox(
      width: 64,
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 11.5),
      ),
    ),
    Expanded(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: LinearProgressIndicator(
          value: pct.clamp(0.0, 1.0),
          minHeight: 10,
          backgroundColor: const Color(0x33000000),
          valueColor: AlwaysStoppedAnimation(color),
        ),
      ),
    ),
    const SizedBox(width: 6),
    SizedBox(
      width: 38,
      child: Text(
        '${(pct * 100).round()}%',
        textAlign: TextAlign.right,
        style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 11),
      ),
    ),
  ],
);

/// 전투 종료 결과 다이얼로그(오토/수동 공용). [onClose] 로 닫힘 동작 주입.
Future<void> showBattleResultDialog(
  BuildContext context, {
  required BattleResult result,
  required int gold,
  required int trophyDelta,
  required VoidCallback onClose,
}) {
  final l = AppLocalizations.of(context);
  final win = result.outcome == BattleOutcome.teamA;
  final draw = result.outcome == BattleOutcome.draw;
  final title = win ? l.battleWin : (draw ? l.battleDraw : l.battleLose);
  final color = win
      ? const Color(0xFF6FCF6F)
      : (draw ? const Color(0xFFBFC4CC) : const Color(0xFFEF9A9A));
  return showGameDialog<void>(
    context,
    title: title,
    icon: win ? Icons.emoji_events_rounded : Icons.sports_mma_rounded,
    barrierDismissible: false,
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        arenaTeamHpBar(
          l.battleMyTeam,
          result.teamAHpPct,
          const Color(0xFF6FC96F),
        ),
        const SizedBox(height: 6),
        arenaTeamHpBar(l.battleFoe, result.teamBHpPct, const Color(0xFFC85454)),
        const SizedBox(height: 12),
        Text(
          l.battleReward,
          style: const TextStyle(
            color: arenaHoney,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '💰 ${formatCompact(gold)}    '
          '🏆 ${trophyDelta >= 0 ? '+' : ''}$trophyDelta',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
      ],
    ),
    actions: [gameDialogButton(l.actionClose, onClose)],
  );
}

/// 내 팀(A)에서 이번 전투 중 KO된 파이터 id들.
/// 1:1 순차전이라 `aDown` 이벤트 수 = 앞에서부터 쓰러진 곤충 수.
List<String> koedTeamAIds(List<BattleBug> teamA, List<BattleEvent> events) {
  final n = events.where((e) => e.aDown).length;
  return [for (var i = 0; i < n && i < teamA.length; i++) teamA[i].id];
}

/// PvP 승패 → 보상(골드·트로피). 오토/수동 공용. 수치는 `battle.json`(§6).
/// [rewardMult] 는 스카우트 난이도 티어 보상 배율(승리 보상에만 적용).
({int gold, int trophyDelta}) pvpReward(
  BattleOutcome outcome,
  int trophies,
  BattleConfig cfg, {
  double rewardMult = 1.0,
}) {
  final win = outcome == BattleOutcome.teamA;
  final draw = outcome == BattleOutcome.draw;
  return (
    gold: win ? cfg.winGold(trophies, rewardMult) : 0,
    trophyDelta: win
        ? cfg.trophyOnWin(rewardMult)
        : (draw ? cfg.trophyDraw : cfg.trophyLose),
  );
}

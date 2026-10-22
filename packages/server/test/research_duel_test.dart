// 연구소 결투 분야(설계 §9) — 공격·방어·체력 연구가 서버 결투 팀(리그·방어팀·대회)에 곱으로 입혀진다.
import 'package:core_battle/core_battle.dart';
import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:core_save/core_save.dart';
import 'package:server/src/actions.dart';
import 'package:server/src/game_config.dart';
import 'package:test/test.dart';

final t0 = DateTime.utc(2026, 10, 22, 12);

void main() {
  late GameConfig cfg;
  late GameActions actions;

  setUpAll(() async {
    cfg = await GameConfig.load(dir: '../app/assets/data');
    actions = GameActions(config: cfg, now: () => t0);
  });

  IndividualBug adult(String id) => IndividualBug(
    id: id,
    speciesId: 'stag_giant',
    sizeMm: 60,
    potential: 3,
    temperament: Temperament.steadfast,
    sex: Sex.male,
    element: Element.wood,
    stage: LifeStage.adult,
    stageSince: t0.subtract(const Duration(days: 30)),
  );

  SaveGame saveWith(Map<String, int> levels) =>
      SaveGame.initial(
        createdAt: t0.subtract(const Duration(days: 40)),
      ).copyWith(
        bugs: [adult('a'), adult('b'), adult('c')],
        pvpDefenseIds: const ['a', 'b', 'c'],
        researchLevels: levels,
        lastSeen: t0,
      );

  Map<String, int> duelMaxed() => {
    for (final d in cfg.research!.defs)
      if (d.branch == ResearchBranch.duel) d.id: d.maxLevel,
  };

  List<DuelBug> team(SaveGame s, {int? teamSize}) {
    final ids = teamSize == 1 ? const ['a'] : const ['a', 'b', 'c'];
    final v = actions.validateDuelTeam(
      s,
      ids,
      speciesById: cfg.speciesById,
      petConfig: cfg.pet,
      enhance: cfg.enhance,
      teamSize: teamSize,
    );
    expect(v.error, isNull);
    return v.team;
  }

  void expectScaled(List<DuelBug> got, List<DuelBug> base, ResearchEffects fx) {
    final a = 1 + fx.of(ResearchEffect.duelAtk);
    final d = 1 + fx.of(ResearchEffect.duelDef);
    final h = 1 + fx.of(ResearchEffect.duelHp);
    for (var i = 0; i < got.length; i++) {
      expect(got[i].atk, closeTo(base[i].atk * a, 1e-6));
      expect(got[i].def, closeTo(base[i].def * d, 1e-6));
      expect(got[i].maxHp, closeTo(base[i].maxHp * h, 1e-6));
      expect(got[i].spd, base[i].spd);
      // 급소 공략 = 치명 확률 %p 가산(엔진 critMax 그대로) · 근성 단련 = 탭 반격 문턱 낮춤.
      expect(
        got[i].crit,
        closeTo(base[i].crit + fx.of(ResearchEffect.duelCrit), 1e-9),
      );
      expect(
        got[i].clutchEase,
        closeTo(base[i].clutchEase + fx.of(ResearchEffect.duelGrit), 1e-9),
      );
      expect(got[i].grit, base[i].grit);
    }
  }

  test('결투 연구가 없으면 팀 능력치 그대로, 다 찍으면 공격·방어·체력 × (1 + 효과)', () {
    final base = team(saveWith(const {}));
    final maxed = duelMaxed();
    final fx = researchEffects(cfg.research!, maxed);
    expect(fx.of(ResearchEffect.duelAtk), greaterThan(0));
    expect(fx.of(ResearchEffect.duelDef), greaterThan(0));
    expect(fx.of(ResearchEffect.duelHp), greaterThan(0));
    expect(fx.of(ResearchEffect.duelCrit), greaterThan(0));
    expect(fx.of(ResearchEffect.duelGrit), greaterThan(0));
    // 연구 0 레벨 맵 = 연구 없음.
    final zero = team(saveWith({for (final k in maxed.keys) k: 0}));
    for (var i = 0; i < 3; i++) {
      expect(zero[i].atk, base[i].atk);
      expect(zero[i].maxHp, base[i].maxHp);
      expect(zero[i].crit, base[i].crit);
      expect(zero[i].clutchEase, 0);
    }
    expectScaled(team(saveWith(maxed)), base, fx);
  });

  test('근육 단련만 다 찍으면 공격만 × (1 + 최대 효과)', () {
    final muscle = cfg.research!.defs.firstWhere(
      (d) => d.effect == ResearchEffect.duelAtk,
    );
    final base = team(saveWith(const {}));
    final got = team(saveWith({muscle.id: muscle.maxLevel}));
    final cap = cfg.research!.effectAt(muscle, muscle.maxLevel);
    for (var i = 0; i < 3; i++) {
      expect(got[i].atk, closeTo(base[i].atk * (1 + cap), 1e-6));
      expect(got[i].def, base[i].def);
      expect(got[i].maxHp, base[i].maxHp);
    }
  });

  test('방어팀은 상대 세이브의 연구로 만든다', () {
    final maxed = duelMaxed();
    final fx = researchEffects(cfg.research!, maxed);
    final base = actions.defenderDuelTeam(
      saveWith(const {}),
      speciesById: cfg.speciesById,
      petConfig: cfg.pet,
      enhance: cfg.enhance,
    )!;
    final got = actions.defenderDuelTeam(
      saveWith(maxed),
      speciesById: cfg.speciesById,
      petConfig: cfg.pet,
      enhance: cfg.enhance,
    )!;
    expectScaled(got, base, fx);
  });

  test('대회 팀(1마리)에도 입혀진다', () {
    final maxed = duelMaxed();
    final fx = researchEffects(cfg.research!, maxed);
    expectScaled(
      team(saveWith(maxed), teamSize: 1),
      team(saveWith(const {}), teamSize: 1),
      fx,
    );
  });
}

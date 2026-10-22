// 연구소 시간 단축(설계 §3.7) — 서버 산란·돌파 시작 시각이 앱과 같은 값으로 줄어든다.
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
  final sp = Species.fromJson({
    'id': 'a',
    'name': {'ko': 'a', 'en': 'a', 'ja': 'a'},
    'grade': 'common',
    'specialty': 'strike',
    'baseStats': {'hp': 100, 'atk': 40, 'def': 30, 'spd': 20},
    'sizeMinMm': 20,
    'sizeMaxMm': 60,
  });

  setUpAll(() async {
    cfg = await GameConfig.load(dir: '../app/assets/data');
    actions = GameActions(config: cfg, now: () => t0);
  });

  IndividualBug parent(String id, Sex sex) => IndividualBug(
    id: id,
    speciesId: 'a',
    sizeMm: 40,
    potential: 3,
    temperament: Temperament.aggressive,
    sex: sex,
    element: Element.wood,
    stage: LifeStage.adult,
    stageSince: t0.subtract(const Duration(days: 30)),
  );

  SaveGame pair(Map<String, int> levels) =>
      SaveGame.initial(createdAt: t0).copyWith(
        bugs: [parent('mom', Sex.female), parent('dad', Sex.male)],
        breedingCapacity: 1,
        researchLevels: levels,
      );

  ActionResult start(SaveGame s) => actions.startBreeding(
    s,
    motherId: 'mom',
    fatherId: 'dad',
    speciesById: {'a': sp},
    petConfig: cfg.pet,
  );

  test('산란 연구가 있으면 서버 endsAt 이 줄고, 없으면 그대로', () {
    final base = start(pair(const {})).save!.breeding.first.endsAt;
    final maxed = {for (final d in cfg.research!.defs) d.id: d.maxLevel};
    final fx = researchEffects(cfg.research!, maxed);
    final v = fx.of(ResearchEffect.breedTime);
    expect(v, greaterThan(0));
    final cut = start(pair(maxed)).save!.breeding.first.endsAt;
    final baseSec = base.difference(t0).inSeconds;
    expect(
      cut.difference(t0).inSeconds,
      researchScaledSeconds(baseSec, fx, ResearchEffect.breedTime),
    );
    expect(cut.isBefore(base), isTrue);
  });
}

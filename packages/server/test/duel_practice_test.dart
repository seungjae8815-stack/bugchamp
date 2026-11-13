import 'package:core_battle/core_battle.dart';
import 'package:core_models/core_models.dart';
import 'package:core_save/core_save.dart';
import 'package:server/src/actions.dart';
import 'package:server/src/duel_session.dart';
import 'package:server/src/game_config.dart';
import 'package:test/test.dart';

/// 연습 결투(2026-11-10, 친구 결투) — 경기가 끝나도 트로피·부상·보상·세이브가 바뀌지 않는다.
void main() {
  final t0 = DateTime.utc(2026, 11, 10, 3);
  late GameConfig cfg;
  late GameActions actions;

  setUpAll(() async {
    cfg = await GameConfig.load(dir: '../app/assets/data');
    actions = GameActions(config: cfg, now: () => t0);
  });

  IndividualBug adult(String id, String sp, double size) => IndividualBug(
    id: id,
    speciesId: sp,
    sizeMm: size,
    potential: 3,
    temperament: Temperament.aggressive,
    sex: Sex.male,
    element: Element.wood,
    stage: LifeStage.adult,
    stageSince: t0.subtract(const Duration(days: 30)),
  );

  test('끝까지 싸워도 세이브가 그대로 · 결과에 practice 표식', () {
    final ids = ['b1', 'b2', 'b3'];
    final save = SaveGame.initial(createdAt: t0).copyWith(
      bugs: [
        adult('b1', 'stag_giant', 70),
        adult('b2', 'rhino_japanese', 60),
        adult('b3', 'mantis_giant', 80),
      ],
      pvpTrophies: 100,
      lastSeen: t0,
    );
    final foe = [
      for (var i = 0; i < 3; i++)
        DuelBug(
          id: 'f$i',
          name: 'f$i',
          speciesId: 'stag_dorcus',
          element: Element.metal,
          temperament: Temperament.steadfast,
          specialty: Specialty.grip,
          sizeMm: 40,
          maxHp: 100,
          atk: 30,
          def: 30,
          spd: 25,
        ),
    ];
    var session = DuelSession(
      id: 'p1',
      userId: 'u1',
      seed: 7,
      myTeamBugIds: ids,
      foe: foe,
      foeSpecies: [for (final b in foe) b.speciesId],
      foeSkins: List<String?>.filled(3, null),
      rewardMult: 0,
      winners: const [],
      launches: const [],
      finished: false,
      trophiesAtStart: 100,
      trophyPrepaid: 0,
      winPoints: 0,
      practice: true,
    );
    expect(DuelSession.fromJson(session.toJson()).practice, isTrue);
    Map<String, dynamic>? last;
    for (var i = 0; i < 6 && !session.finished; i++) {
      final r = actions.duelThrow(
        save,
        session,
        launch: 0.6,
        speciesById: cfg.speciesById,
        petConfig: cfg.pet,
        enhance: cfg.enhance,
      );
      expect(r.result.isOk, isTrue, reason: r.result.error);
      session = r.session!;
      last = r.result.extra;
      expect(identical(r.result.save, save), isTrue);
    }
    expect(session.finished, isTrue);
    expect(last!['done'], isTrue);
    expect(last['practice'], isTrue);
  });
}

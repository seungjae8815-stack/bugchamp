import 'package:core_battle/core_battle.dart';
import 'package:core_models/core_models.dart';
import 'package:core_save/core_save.dart';
import 'package:server/src/actions.dart';
import 'package:server/src/duel_session.dart';
import 'package:server/src/game_config.dart';
import 'package:test/test.dart';

final t0 = DateTime.utc(2026, 9, 28, 12);

void main() {
  late GameConfig cfg;
  late GameActions actions;

  setUpAll(() async {
    cfg = await GameConfig.load(dir: '../app/assets/data');
    actions = GameActions(config: cfg, now: () => t0);
  });

  IndividualBug adult(String id, String sp, {double size = 60}) =>
      IndividualBug(
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

  SaveGame saveWith(List<IndividualBug> bugs, {int trophies = 100}) =>
      SaveGame.initial(
        createdAt: t0,
      ).copyWith(bugs: bugs, pvpTrophies: trophies, lastSeen: t0);

  final ids = ['b1', 'b2', 'b3'];
  SaveGame myBase({int trophies = 100}) => saveWith([
    adult('b1', 'stag_giant', size: 70),
    adult('b2', 'rhino_japanese', size: 60),
    adult('b3', 'mantis_giant', size: 80),
  ], trophies: trophies);

  group('편성 검증', () {
    test('3마리 · 중복 없음 · 보유한 성충만', () {
      final s = myBase();
      final ok = actions.validateDuelTeam(
        s,
        ids,
        speciesById: cfg.speciesById,
        petConfig: cfg.pet,
        enhance: cfg.enhance,
      );
      expect(ok.error, isNull);
      expect(ok.team.map((b) => b.speciesId), [
        'stag_giant',
        'rhino_japanese',
        'mantis_giant',
      ]);
      expect(ok.team.first.sizeMm, 70);
      expect(ok.team.first.specialty, Specialty.grip);

      String? err(List<String> t) => actions
          .validateDuelTeam(
            s,
            t,
            speciesById: cfg.speciesById,
            petConfig: cfg.pet,
          )
          .error;
      expect(err(['b1', 'b2']), 'team_size');
      expect(err(['b1', 'b1', 'b2']), 'duplicate_bug');
      expect(err(['b1', 'b2', 'nope']), 'bug_not_owned');
    });

    test('훈련소 — 보너스는 최대 단계로 잘라 입히고, 훈련 중인 곤충은 출정 불가', () {
      final tr = cfg.battle.training;
      final plain = actions
          .validateDuelTeam(
            myBase(),
            ids,
            speciesById: cfg.speciesById,
            petConfig: cfg.pet,
          )
          .team
          .first;
      final forged = myBase().copyWith(
        duelTraining: {
          'b1': {TrainStat.attack: 99, TrainStat.evade: 99},
        },
      );
      final b1 = forged.bugs.first;
      final sp = cfg.speciesById[b1.speciesId]!;
      final trained = actions
          .validateDuelTeam(
            forged,
            ids,
            speciesById: cfg.speciesById,
            petConfig: cfg.pet,
          )
          .team
          .first;
      final capAtk = trainCapOf(b1, sp, TrainStat.attack, tr);
      expect(
        trained.atk,
        closeTo(
          plain.atk * (1 + capAtk * tr.perLevel[TrainStat.attack]!),
          1e-6,
        ),
      );
      expect(
        trained.evade,
        closeTo(
          trainCapOf(b1, sp, TrainStat.evade, tr) *
              tr.perLevel[TrainStat.evade]!,
          1e-9,
        ),
      );
      final training = myBase().copyWith(
        trainingJob: TrainingJob(
          bugId: 'b2',
          stat: TrainStat.crit,
          level: 1,
          until: t0.add(const Duration(hours: 1)),
        ),
      );
      expect(
        actions
            .validateDuelTeam(
              training,
              ids,
              speciesById: cfg.speciesById,
              petConfig: cfg.pet,
            )
            .error,
        'bug_training',
      );
    });

    test('방어팀은 상대 세이브의 방어 순서로 서버가 만든다', () {
      final opp = myBase().copyWith(pvpDefenseIds: ['b3', 'b1', 'b2']);
      final team = actions.defenderDuelTeam(
        opp,
        speciesById: cfg.speciesById,
        petConfig: cfg.pet,
        enhance: cfg.enhance,
      );
      expect(team!.map((b) => b.id), ['b3', 'b1', 'b2']);
      // 방어 순서가 없으면 null — 옛 defenders 행으로 떨어진다.
      expect(
        actions.defenderDuelTeam(
          myBase(),
          speciesById: cfg.speciesById,
          petConfig: cfg.pet,
        ),
        isNull,
      );
    });
  });

  group('세션(판마다 던지기)', () {
    ({SaveGame save, DuelSession session}) start({
      required SaveGame save,
      required List<DuelBug> foe,
      int? winPoints,
    }) {
      final r = actions.startDuel(
        save,
        myTeamBugIds: ids,
        rewardMult: 1.0,
        speciesById: cfg.speciesById,
        petConfig: cfg.pet,
        winPoints: winPoints,
      );
      expect(r.isOk, isTrue, reason: r.error);
      return (
        save: r.save!,
        session: DuelSession(
          id: 's1',
          userId: 'u1',
          seed: 777,
          myTeamBugIds: ids,
          foe: foe,
          foeSpecies: [for (final b in foe) b.speciesId],
          foeSkins: List<String?>.filled(foe.length, null),
          rewardMult: 1.0,
          winners: const [],
          launches: const [],
          finished: false,
          trophiesAtStart: r.extra['trophiesAtStart'] as int,
          trophyPrepaid: r.extra['trophyPrepaid'] as int,
          winPoints: winPoints,
        ),
      );
    }

    /// 끝까지 던진다.
    ({SaveGame save, DuelSession session}) playOut(
      ({SaveGame save, DuelSession session}) st,
    ) {
      var save = st.save;
      var session = st.session;
      while (!session.finished) {
        final r = actions.duelThrow(
          save,
          session,
          launch: 0.8,
          speciesById: cfg.speciesById,
          petConfig: cfg.pet,
          enhance: cfg.enhance,
        );
        expect(r.result.isOk, isTrue, reason: r.result.error);
        save = r.result.save!;
        session = r.session!;
      }
      return (save: save, session: session);
    }

    List<DuelBug> foeOf(double scale) => [
      for (var i = 0; i < 3; i++)
        DuelBug(
          id: 'f$i',
          name: 'f$i',
          speciesId: 'stag_dorcus',
          element: Element.metal,
          temperament: Temperament.steadfast,
          specialty: Specialty.grip,
          sizeMm: 40,
          maxHp: 100 * scale,
          atk: 30 * scale,
          def: 30 * scale,
          spd: 25 * scale,
        ),
    ];

    test('시작하면 티켓 1장 · 트로피 패배분 · 세 마리 부상을 먼저 깎는다', () {
      final before = myBase();
      final st = start(save: before, foe: foeOf(1));
      expect(st.save.pvpTrophies, lessThan(before.pvpTrophies));
      expect(st.session.trophyPrepaid, st.save.pvpTrophies - 100);
      for (final id in ids) {
        expect(st.save.isInjured(id, t0), isTrue, reason: id);
      }
    });

    test('약한 상대면 2판으로 끝나고, 이기면 선차감을 돌려받고 부상도 풀린다', () {
      final st = start(save: myBase(), foe: foeOf(0.2));
      var save = st.save;
      DuelSession? session = st.session;
      var done = false;
      var throws = 0;
      while (!done) {
        final r = actions.duelThrow(
          save,
          session!,
          launch: 0.8,
          speciesById: cfg.speciesById,
          petConfig: cfg.pet,
          enhance: cfg.enhance,
        );
        expect(r.result.isOk, isTrue, reason: r.result.error);
        save = r.result.save!;
        session = r.session;
        done = r.result.extra['done'] == true;
        throws++;
        expect(r.result.extra['bout'], isA<Map<String, dynamic>>());
      }
      expect(throws, 3, reason: '승자 연속 — 첫 곤충이 세 마리를 다 쓰러뜨린다');
      expect(session!.finished, isTrue);
      expect(session.winsA, 3);
      expect(session.hpA, lessThanOrEqualTo(1.0));
      // 이겼으니 트로피는 시작 전보다 올라가고(선차감 차액 반환), 부상은 없다.
      expect(save.pvpTrophies, greaterThan(100));
      for (final id in ids) {
        expect(save.isInjured(id, t0), isFalse, reason: id);
      }
      // 끝난 세션은 다시 못 던진다(보상 두 번 방지).
      final again = actions.duelThrow(
        save,
        session,
        launch: 0.5,
        speciesById: cfg.speciesById,
        petConfig: cfg.pet,
      );
      expect(again.result.error, 'session_finished');
    });

    test('지면 진 판의 곤충만 부상, 트로피는 선차감만큼만 깎인다', () {
      final st = start(save: myBase(), foe: foeOf(8));
      var save = st.save;
      DuelSession? session = st.session;
      var done = false;
      while (!done) {
        final r = actions.duelThrow(
          save,
          session!,
          launch: 0.5,
          speciesById: cfg.speciesById,
          petConfig: cfg.pet,
        );
        save = r.result.save!;
        session = r.session;
        done = r.result.extra['done'] == true;
      }
      expect(session!.winsB, 3);
      expect(save.pvpTrophies, st.save.pvpTrophies, reason: '패배는 이미 선차감됐다');
      // 세 마리 모두 나가서 졌다 — 모두 부상.
      for (final id in ['b1', 'b2', 'b3']) {
        expect(save.isInjured(id, t0), isTrue, reason: id);
      }
    });

    test('승리 점수 방식 — 선차감 없음, 이기면 후보 점수만큼', () {
      final st = start(save: myBase(), foe: foeOf(0.2), winPoints: 4);
      expect(st.save.pvpTrophies, 100, reason: '지면 0점이라 미리 깎지 않는다');
      final end = playOut(st);
      expect(end.session.winsA, 3);
      expect(end.save.pvpTrophies, 104);
      // 첫 곤충 혼자 다 이겼다 — 안 나간 곤충(2·3번)은 회복실에 가지 않는다.
      expect(end.save.isInjured('b2', t0), isFalse);
      expect(end.save.isInjured('b3', t0), isFalse);
    });

    test('승리 점수 방식 — 지면 트로피가 깎이지 않는다', () {
      final end = playOut(start(save: myBase(), foe: foeOf(8), winPoints: 5));
      expect(end.session.winsB, 3);
      expect(end.save.pvpTrophies, 100);
    });

    test('같은 세션·같은 게이지면 같은 결과(결정론)', () {
      final st = start(save: myBase(), foe: foeOf(1));
      Map<String, dynamic> once() =>
          actions
                  .duelThrow(
                    st.save,
                    st.session,
                    launch: 0.42,
                    speciesById: cfg.speciesById,
                    petConfig: cfg.pet,
                    enhance: cfg.enhance,
                  )
                  .result
                  .extra['bout']
              as Map<String, dynamic>;
      expect(once().toString(), once().toString());
    });
  });
}

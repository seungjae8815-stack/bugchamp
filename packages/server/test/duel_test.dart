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

    test('훈련 v2 — 배분은 예산·칸 상한으로 잘라 입히고, 찍는 중·다시 찍기 대기 중인 곤충은 출정 불가', () {
      final tr = cfg.battle.training;
      DuelBug first(SaveGame s) => actions
          .validateDuelTeam(
            s,
            ids,
            speciesById: cfg.speciesById,
            petConfig: cfg.pet,
            enhance: cfg.enhance,
          )
          .team
          .first;
      final plain = first(myBase());
      // 세이브를 고쳐 칸에 99를 적었다 — 3성 1레벨 예산은 18포인트.
      final forged = myBase().copyWith(
        trainPoints: {
          'b1': const BugTrain(
            alloc: {
              TrainSlot.attack: 99,
              TrainSlot.evade: 99,
              TrainSlot.mass: 99,
              TrainSlot.grit: 99,
            },
            paid: 999,
            bonus: 999,
          ),
        },
      );
      final b1 = forged.bugs.first;
      final sp = cfg.speciesById[b1.speciesId]!;
      final eff = effectiveAllocOf(
        forged,
        b1,
        sp,
        tr,
        levelCap: cfg.pet.levelCap(0),
        enhance: cfg.enhance,
      );
      expect(eff.values.fold<int>(0, (a, b) => a + b), 18);
      expect(eff[TrainSlot.attack], lessThanOrEqualTo(18));
      final trained = first(forged);
      final atkPts = eff[TrainSlot.attack] ?? 0;
      expect(trained.atk, closeTo(plain.atk * (1 + atkPts * 0.03), 1e-6));
      expect(trained.evade, closeTo((eff[TrainSlot.evade] ?? 0) * 0.006, 1e-9));
      expect(trained.grit, eff[TrainSlot.grit] ?? 0);
      expect(
        trained.massMult,
        closeTo(1 + (eff[TrainSlot.mass] ?? 0) * 0.015, 1e-9),
      );

      // 찍는 중(훈련소 1칸)
      final busy = myBase().copyWith(
        trainPoints: {'b2': const BugTrain()},
        trainPointJob: TrainPointJob(
          bugId: 'b2',
          slot: TrainSlot.hp,
          count: 1,
          until: t0.add(const Duration(hours: 1)),
        ),
      );
      String? err(SaveGame s) => actions
          .validateDuelTeam(
            s,
            ids,
            speciesById: cfg.speciesById,
            petConfig: cfg.pet,
          )
          .error;
      expect(err(busy), 'bug_training');
      // 다시 찍기 대기 중
      final respec = myBase().copyWith(
        trainPoints: {
          'b3': BugTrain(
            alloc: const {TrainSlot.hp: 1},
            paid: 1,
            pending: const {TrainSlot.attack: 1},
            respecUntil: t0.add(const Duration(minutes: 33)),
          ),
        },
      );
      expect(err(respec), 'bug_training');
      // 대기가 끝났으면 출정할 수 있다
      final done = myBase().copyWith(
        trainPoints: {
          'b3': BugTrain(
            alloc: const {TrainSlot.hp: 1},
            paid: 1,
            pending: const {TrainSlot.attack: 1},
            respecUntil: t0.subtract(const Duration(minutes: 1)),
          ),
        },
      );
      expect(err(done), isNull);
    });

    test('훈련 v2 — 옛 부위 강화는 이전 전이어도 같은 값(가상 이전) · 날개 회피는 회피 칸으로', () {
      final old = myBase();
      final b1 = old.bugs.first.copyWith(
        enhancement: const PartLevels(hornJaw: 10, wing: 10),
      );
      final s = old.copyWith(bugs: [b1, ...old.bugs.skip(1)]);
      DuelBug first(SaveGame x) => actions
          .validateDuelTeam(
            x,
            ids,
            speciesById: cfg.speciesById,
            petConfig: cfg.pet,
            enhance: cfg.enhance,
          )
          .team
          .first;
      final plain = first(old);
      final before = first(s);
      // 뿔 10 → 공격 +40% 를 3% 칸으로 덮는 14포인트 = +42% (같거나 크다)
      expect(before.atk, greaterThanOrEqualTo(plain.atk * 1.4 - 1e-6));
      // 날개 10 → 속도 15포인트(+30%) · 회피 0.3%p×10 = 3% → 5포인트(3%)
      expect(before.spd, greaterThanOrEqualTo(plain.spd * 1.3 - 1e-6));
      expect(before.evade, closeTo(0.03, 1e-9));
      // 저장된 이전과 같은 값
      final migrated = migrateTrainingV2(
        s,
        cfg.battle.training,
        speciesOf: (id) => cfg.speciesById[id],
        enhance: cfg.enhance,
      );
      final after = first(migrated);
      expect(after.atk, closeTo(before.atk, 1e-9));
      expect(after.evade, closeTo(before.evade, 1e-9));
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

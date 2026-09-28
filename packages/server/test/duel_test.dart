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
    }) {
      final r = actions.startDuel(
        save,
        myTeamBugIds: ids,
        rewardMult: 1.0,
        speciesById: cfg.speciesById,
        petConfig: cfg.pet,
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
        ),
      );
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
      expect(throws, 2);
      expect(session!.finished, isTrue);
      expect(session.winsA, 2);
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
      expect(session!.winsB, 2);
      expect(save.pvpTrophies, st.save.pvpTrophies, reason: '패배는 이미 선차감됐다');
      expect(save.isInjured('b1', t0), isTrue);
      expect(save.isInjured('b2', t0), isTrue);
      // 3판째는 안 뛰었다 — 선차감 부상을 풀어 준다.
      expect(save.isInjured('b3', t0), isFalse);
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

  test('빠른 결투 — 한 번에 끝나고 판 결과가 실려 온다', () {
    final r = actions.runDuelAuto(
      myBase(),
      myTeamBugIds: ids,
      foeTeam: [
        for (var i = 0; i < 3; i++)
          DuelBug(
            id: 'f$i',
            name: 'f$i',
            speciesId: 'stag_dorcus',
            element: Element.fire,
            temperament: Temperament.cunning,
            specialty: Specialty.strike,
            sizeMm: 40,
            maxHp: 90,
            atk: 30,
            def: 30,
            spd: 25,
          ),
      ],
      seed: 99,
      rewardMult: 1.0,
      speciesById: cfg.speciesById,
      petConfig: cfg.pet,
      enhance: cfg.enhance,
    );
    expect(r.isOk, isTrue, reason: r.error);
    final bouts = r.extra['bouts'] as List;
    expect(bouts.length, inInclusiveRange(2, 3));
    final winsA = r.extra['winsA'] as int;
    expect(r.extra['outcome'], winsA >= 2 ? 'teamA' : 'teamB');
  });
}

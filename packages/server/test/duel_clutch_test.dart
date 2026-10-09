import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:core_battle/core_battle.dart';
import 'package:core_models/core_models.dart';
import 'package:core_save/core_save.dart';
import 'package:server/src/actions.dart';
import 'package:server/src/duel_session.dart';
import 'package:server/src/game_config.dart';
import 'package:test/test.dart';

/// 훈련 v2 — 탭 반격 서버 흐름(설계 §4) · 크기는 결투에서 무게로만 · 대회 전력 압축 분리.
///
/// 탭 반격 계약: 앱이 `clutch` 를 안다고 알리면 내 곤충 위기에서 판이 멈추고(`clutch`), 점수를 받으면
/// **같은 seed 로 처음부터** 다시 계산해 이어 간다. 모르는 앱(1.0.17)은 자동 점수로 끝까지.
/// `clutchEnabled` 가 false 면 지금과 완전히 같다.
final t0 = DateTime.utc(2026, 10, 8, 3); // 대회 2회차 기간 안(KST 10-08 12시)

void main() {
  // 실데이터의 clutchEnabled 값(1.0.18 출시 때 true)과 상관없이 끈 것·켠 것을 둘 다 만든다.
  late GameConfig cfg; // 같은 데이터 + clutchEnabled false
  late GameConfig cfgOn; // 같은 데이터 + clutchEnabled true
  late GameActions off;
  late GameActions on;

  setUpAll(() async {
    Future<GameConfig> withClutch(bool enabled) async {
      final tmp = Directory.systemTemp.createTempSync('duel_clutch_test');
      for (final f in Directory(
        '../app/assets/data',
      ).listSync().whereType<File>()) {
        f.copySync('${tmp.path}/${f.uri.pathSegments.last}');
      }
      final bf = File('${tmp.path}/battle.json');
      final b = jsonDecode(bf.readAsStringSync()) as Map<String, dynamic>;
      (b['duel'] as Map<String, dynamic>)['clutchEnabled'] = enabled;
      bf.writeAsStringSync(jsonEncode(b));
      return GameConfig.load(dir: tmp.path);
    }

    cfg = await withClutch(false);
    cfgOn = await withClutch(true);
    off = GameActions(config: cfg, now: () => t0);
    on = GameActions(config: cfgOn, now: () => t0);
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

  final ids = ['b1', 'b2', 'b3'];
  SaveGame myBase() => SaveGame.initial(createdAt: t0).copyWith(
    bugs: [
      adult('b1', 'stag_giant', size: 70),
      adult('b2', 'rhino_japanese', size: 60),
      adult('b3', 'mantis_giant', size: 80),
    ],
    pvpTrophies: 100,
    lastSeen: t0,
  );

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

  DuelSession sessionOf(int seed, List<DuelBug> foe) => DuelSession(
    id: 's$seed',
    userId: 'u1',
    seed: seed,
    myTeamBugIds: ids,
    foe: foe,
    foeSpecies: [for (final b in foe) b.speciesId],
    foeSkins: List<String?>.filled(foe.length, null),
    rewardMult: 1.0,
    winners: const [],
    launches: const [],
    finished: false,
    trophiesAtStart: 100,
    trophyPrepaid: 0,
    winPoints: 3,
  );

  ({ActionResult result, DuelSession? session}) throwWith(
    GameActions a,
    SaveGame s,
    DuelSession session, {
    required bool clutch,
    double launch = 0.6,
  }) => a.duelThrow(
    s,
    session,
    launch: launch,
    speciesById: cfg.speciesById,
    petConfig: cfg.pet,
    enhance: cfg.enhance,
    clutch: clutch,
  );

  ({ActionResult result, DuelSession? session}) clutchWith(
    GameActions a,
    SaveGame s,
    DuelSession session, {
    required int index,
    required double score,
  }) => a.duelClutch(
    s,
    session,
    index: index,
    score: score,
    speciesById: cfg.speciesById,
    petConfig: cfg.pet,
    enhance: cfg.enhance,
  );

  /// 첫 판에서 위기로 멈추는 세션을 찾는다(대등한 상대 · seed 를 바꿔 가며).
  ({DuelSession session, Map<String, dynamic> extra, DuelSession paused})
  firstPause(SaveGame s) {
    for (var seed = 1; seed < 400; seed++) {
      final sess = sessionOf(seed, foeOf(3));
      final r = throwWith(on, s, sess, clutch: true);
      expect(r.result.isOk, isTrue, reason: r.result.error);
      if (r.result.extra['clutch'] != null) {
        return (session: sess, extra: r.result.extra, paused: r.session!);
      }
    }
    fail('400 seed 안에 위기가 없다');
  }

  group('탭 반격 — 서버 흐름', () {
    test('멈춤 → 점수 → 이어짐: 앞부분 궤적이 같고, 판은 점수를 받은 뒤에야 넘어간다', () {
      final s = myBase();
      final p = firstPause(s);
      final c = p.extra['clutch'] as Map<String, dynamic>;
      expect(c['index'], 0);
      expect(c['bout'], 0);
      expect(DuelCrisis.values.map((e) => e.key), contains(c['kind']));
      expect(p.extra['done'], isFalse);
      // 판을 넘기지 않았다 — 승패 기록은 그대로, 세션에 던지기 값·위기 번호가 남는다.
      expect(p.paused.winners, isEmpty);
      expect(p.paused.clutchPending, isTrue);
      expect(p.paused.pendingIndex, 0);
      expect(p.paused.pendingLaunch, 0.6);
      final paused = DuelBout.fromJson(p.extra['bout'] as Map<String, dynamic>);
      expect(paused.pending, isNotNull);
      expect(paused.winner, -1);

      // 세션 JSON 왕복(DB 저장)도 같은 상태.
      final rt = DuelSession.fromJson(p.paused.toJson());
      expect(rt.clutchPending, isTrue);
      expect(rt.clutchScores, isEmpty);

      final r = clutchWith(on, s, rt, index: 0, score: 1.0);
      expect(r.result.isOk, isTrue, reason: r.result.error);
      final full = DuelBout.fromJson(
        r.result.extra['bout'] as Map<String, dynamic>,
      );
      // 같은 판을 처음부터 다시 계산했다 — 멈춘 판의 프레임·사건이 앞부분과 정확히 같다.
      expect(
        full.frames.take(paused.frames.length).toList().toString(),
        paused.frames.toString(),
      );
      expect(
        [
          for (final e in full.events.take(paused.events.length)) e.toJson(),
        ].toString(),
        [for (final e in paused.events) e.toJson()].toString(),
      );
      // 만점이면 이 위기는 살아난다(문턱 0.55 − 근성).
      expect(
        full.events.any(
          (e) =>
              e.who == 0 &&
              e.kind == DuelEventKind.clutchSave &&
              e.tick == paused.pending!.tick,
        ),
        isTrue,
      );
      if (full.pending == null) {
        expect(r.session!.winners, hasLength(1), reason: '점수를 받고 판이 끝났다');
        expect(r.session!.clutchPending, isFalse);
      } else {
        // 두 번째 기회(근성 10)가 또 왔다 — 다음 번호를 기다린다.
        expect(r.session!.pendingIndex, 1);
        expect(r.session!.winners, isEmpty);
      }
    });

    test('같은 점수면 같은 판(재현) · 범위 밖 점수는 0~1 로 자른다', () {
      final s = myBase();
      final p = firstPause(s);
      String boutOf(double score) => clutchWith(
        on,
        s,
        p.paused,
        index: 0,
        score: score,
      ).result.extra['bout'].toString();
      expect(boutOf(0.3), boutOf(0.3));
      expect(boutOf(5), boutOf(1));
      expect(boutOf(-2), boutOf(0));
      expect(boutOf(double.nan), boutOf(0));
    });

    test('위기 번호 검증 · 멈춘 동안 다음 판 던지기 금지 · 멈춘 판이 없으면 점수 거부', () {
      final s = myBase();
      final p = firstPause(s);
      final wrong = clutchWith(on, s, p.paused, index: 1, score: 1);
      expect(wrong.result.error, 'clutch_index');
      expect(wrong.result.status, 409);
      final skip = throwWith(on, s, p.paused, clutch: true);
      expect(skip.result.error, 'clutch_pending');
      expect(skip.result.status, 409);
      final none = clutchWith(on, s, p.session, index: 0, score: 1);
      expect(none.result.error, 'no_clutch');
      // 같은 위기에 두 번 — 첫 점수로 판이 넘어갔으면 두 번째는 번호가 안 맞거나 멈춘 판이 없다.
      final once = clutchWith(on, s, p.paused, index: 0, score: 0);
      final twice = clutchWith(on, s, once.session!, index: 0, score: 1);
      expect(twice.result.isOk, isFalse);
    });

    test('끝까지 — 점수를 다 보내면 경기가 끝나고 보상이 한 번 반영된다', () {
      var save = myBase();
      var session = firstPause(save).session;
      var n = 0;
      while (!session.finished) {
        final r = session.clutchPending
            ? clutchWith(
                on,
                save,
                session,
                index: session.pendingIndex!,
                score: 0.2,
              )
            : throwWith(on, save, session, clutch: true);
        expect(r.result.isOk, isTrue, reason: r.result.error);
        save = r.result.save!;
        session = r.session!;
        if (++n > 50) fail('끝나지 않는다');
      }
      expect(session.winsA >= 3 || session.winsB >= 3, isTrue);
    });

    test('구버전 앱(clutch 모름) — clutchEnabled 여도 멈추지 않고 자동 점수로 끝까지', () {
      for (var seed = 1; seed < 40; seed++) {
        var save = myBase();
        var session = sessionOf(seed, foeOf(3));
        while (!session.finished) {
          final r = throwWith(on, save, session, clutch: false);
          expect(r.result.isOk, isTrue, reason: r.result.error);
          expect(r.result.extra['clutch'], isNull);
          final bout = DuelBout.fromJson(
            r.result.extra['bout'] as Map<String, dynamic>,
          );
          expect(bout.pending, isNull);
          expect(bout.winner, isNot(-1));
          save = r.result.save!;
          session = r.session!;
        }
      }
    });

    test('clutchEnabled false — 앱이 clutch 를 알려도 예전과 완전히 같다(끄는 스위치가 살아 있다)', () {
      final s = myBase();
      for (var seed = 1; seed < 30; seed++) {
        final sess = sessionOf(seed, foeOf(3));
        final a = throwWith(off, s, sess, clutch: true);
        final b = throwWith(off, s, sess, clutch: false);
        expect(a.result.extra['clutch'], isNull);
        expect(a.result.extra.toString(), b.result.extra.toString());
        expect(a.session!.toJson().toString(), b.session!.toJson().toString());
      }
    });
  });

  group('크기는 결투에서 무게로만', () {
    test('편성 곤충은 스탯에 구워진 사이즈 배율을 싣는다(엔진이 sizeStatExp 로 덜어낸다)', () {
      final s = myBase();
      final v = off.validateDuelTeam(
        s,
        ids,
        speciesById: cfg.speciesById,
        petConfig: cfg.pet,
        enhance: cfg.enhance,
      );
      expect(v.error, isNull);
      for (var i = 0; i < 3; i++) {
        final bug = s.bugs[i];
        final sp = cfg.speciesById[bug.speciesId]!;
        expect(v.team[i].sizeStatMult, closeTo(bug.statMultiplier(sp), 1e-12));
        expect(v.team[i].sizeStatMult, inInclusiveRange(0.85, 1.20));
      }
      // 직렬화(세션·대회 응답)에도 남는다.
      expect(
        DuelBug.fromJson(v.team.first.toJson()).sizeStatMult,
        v.team.first.sizeStatMult,
      );
    });

    test('같은 곤충의 크기만 다르면 — 결투 전투 수치(덜어낸 뒤)는 같고 무게·몸 반경만 다르다', () {
      final sp = cfg.speciesById['stag_giant']!;
      DuelBug one(double mm) => off
          .validateDuelTeam(
            SaveGame.initial(
              createdAt: t0,
            ).copyWith(bugs: [adult('x', 'stag_giant', size: mm)]),
            ['x'],
            speciesById: cfg.speciesById,
            petConfig: cfg.pet,
            enhance: cfg.enhance,
            teamSize: 1,
          )
          .team
          .first;
      final big = one(sp.sizeMaxMm), small = one(sp.sizeMinMm);
      final p = off.duelParams;
      expect(p.sizeStatExp, 0, reason: 'battle.json duel.sizeStatExp');
      double unsized(DuelBug b, double v) =>
          v / b.sizeStatMult * math.pow(b.sizeStatMult, p.sizeStatExp);
      expect(unsized(big, big.atk), closeTo(unsized(small, small.atk), 1e-6));
      expect(
        unsized(big, big.maxHp),
        closeTo(unsized(small, small.maxHp), 1e-6),
      );
      expect(big.mass(p), greaterThan(small.mass(p)));
    });

    test('야생 상대도 중간 크기 배율로 덜어낸다', () {
      final s = myBase();
      final tier = cfg.battle.scoutTiers.first.id;
      final w = off.buildWildDuelTeam(
        s,
        tierId: tier,
        speciesById: cfg.speciesById,
        petConfig: cfg.pet,
        enhance: cfg.enhance,
      );
      expect(w, isNotNull);
      for (final b in w!.team) {
        final sp = cfg.speciesById[b.speciesId]!;
        expect(
          b.sizeStatMult,
          closeTo(
            sizeToStatMultiplier(b.sizeMm, sp.sizeMinMm, sp.sizeMaxMm),
            1e-12,
          ),
        );
      }
    });
  });

  group('대회 전력 압축 분리', () {
    test('대회는 duelWave.statCompress(0.65), 결투는 duel.statCompress(0.3)', () {
      expect(off.duelParams.statCompress, 0.3);
      expect(off.eventDuelSpec.statCompress, 0.65);
      expect(off.eventDuelParams.statCompress, 0.65);
      // 나머지 수치는 결투와 같다.
      expect(off.eventDuelParams.sizeStatExp, off.duelParams.sizeStatExp);
      expect(off.eventDuelParams.clutchEnabled, off.duelParams.clutchEnabled);
      // duelWave 에 없으면 결투 값.
      final noOverride = eventDuelParamsOf(
        cfg.battle.duelJson,
        EventDuelSpec.fromJson(const {}),
      );
      expect(noOverride.statCompress, 0.3);
    });
  });

  group('대회 탭 반격', () {
    SaveGame eventSave() => SaveGame.initial(createdAt: t0).copyWith(
      bugs: [adult('a', 'stag_dorcus', size: 30)],
      eventTickets: 5,
      eventTicketsAt: t0,
      lastSeen: t0,
    );

    test('멈춤 → 점수 → 이어짐 · 번호 검증 · 구버전은 자동', () {
      final s0 = eventSave();
      final st = on.eventDuelStart(
        s0,
        bugId: 'a',
        speciesById: cfg.speciesById,
        petConfig: cfg.pet,
        enhance: cfg.enhance,
      );
      expect(st.isOk, isTrue, reason: st.error);
      var save = st.save!;
      var session = Map<String, dynamic>.from(st.extra['session'] as Map);
      Map<String, dynamic>? paused;
      Map<String, dynamic>? pausedExtra;
      // 웨이브를 이어 가다 내 곤충 위기가 오면 멈춘다(약한 곤충이라 곧 온다).
      for (var n = 0; n < 200 && session['done'] != true; n++) {
        final cards = session['cards'] as List? ?? const [];
        final r = on.eventDuelThrow(
          save,
          session: session,
          launch: 0.7,
          cardId: cards.isEmpty ? null : '${cards.first}',
          speciesById: cfg.speciesById,
          petConfig: cfg.pet,
          enhance: cfg.enhance,
          clutch: true,
        );
        expect(r.isOk, isTrue, reason: r.error);
        save = r.save!;
        session = Map<String, dynamic>.from(r.extra['session'] as Map);
        if (r.extra['clutch'] != null) {
          paused = session;
          pausedExtra = r.extra;
          break;
        }
      }
      expect(paused, isNotNull, reason: '위기가 한 번은 와야 한다');
      expect(pausedExtra!['done'], isFalse);
      expect((pausedExtra['clutch'] as Map)['index'], 0);
      expect(paused!['cl'], isA<Map>());
      expect(paused['cards'], isEmpty, reason: '카드는 멈추기 전에 썼다');

      // 멈춘 동안 던지기 금지 · 번호 검증.
      final skip = on.eventDuelThrow(
        save,
        session: paused,
        launch: 0.7,
        speciesById: cfg.speciesById,
        petConfig: cfg.pet,
        clutch: true,
      );
      expect(skip.error, 'clutch_pending');
      ActionResult clutch(int i, double sc) => on.eventDuelClutch(
        save,
        session: paused!,
        index: i,
        score: sc,
        speciesById: cfg.speciesById,
        petConfig: cfg.pet,
        enhance: cfg.enhance,
      );
      expect(clutch(3, 1).error, 'clutch_index');
      final r = clutch(0, 1);
      expect(r.isOk, isTrue, reason: r.error);
      final full = DuelBout.fromJson(r.extra['bout'] as Map<String, dynamic>);
      final part = DuelBout.fromJson(
        pausedExtra['bout'] as Map<String, dynamic>,
      );
      expect(
        full.frames.take(part.frames.length).toList().toString(),
        part.frames.toString(),
      );
      expect(clutch(0, 1).extra['bout'].toString(), r.extra['bout'].toString());
      if (full.pending == null) {
        expect((r.extra['session'] as Map).containsKey('cl'), isFalse);
      }

      // 구버전 앱 — 같은 세션 상태에서 clutch 를 모르면 멈추지 않는다.
      final s2 = on.eventDuelStart(
        eventSave(),
        bugId: 'a',
        speciesById: cfg.speciesById,
        petConfig: cfg.pet,
        enhance: cfg.enhance,
      );
      var sess2 = Map<String, dynamic>.from(s2.extra['session'] as Map);
      var save2 = s2.save!;
      for (var n = 0; n < 200 && sess2['done'] != true; n++) {
        final cards = sess2['cards'] as List? ?? const [];
        final r2 = on.eventDuelThrow(
          save2,
          session: sess2,
          launch: 0.7,
          cardId: cards.isEmpty ? null : '${cards.first}',
          speciesById: cfg.speciesById,
          petConfig: cfg.pet,
          enhance: cfg.enhance,
        );
        expect(r2.isOk, isTrue, reason: r2.error);
        expect(r2.extra['clutch'], isNull);
        save2 = r2.save!;
        sess2 = Map<String, dynamic>.from(r2.extra['session'] as Map);
      }
      expect(sess2['done'], isTrue);
    });
  });
}

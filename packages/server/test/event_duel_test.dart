import 'package:core_battle/core_battle.dart';
import 'package:core_models/core_models.dart';
import 'package:core_save/core_save.dart';
import 'package:server/src/actions.dart';
import 'package:test/test.dart';

import 'actions_test.dart' show testSpecies;
import 'event_test.dart' show buildEventCfg;

/// 왕충 선발대회 2회차부터 — **곤충 1마리 · 결투 엔진 웨이브전 · 출전 피로 대신 결투 부상**
/// (2026-09-29 사장님 확정). 점수가 실물 경품이 되므로 서버가 판마다 확정하는 계약을 검사한다.
void main() {
  final cfg = buildEventCfg(legacy: false);
  final t0 = cfg.event!.startsAt!.add(const Duration(hours: 12));
  final species = {'test_bug': testSpecies};
  final actions = GameActions(config: cfg, now: () => t0);

  IndividualBug adult(String id) => IndividualBug(
    id: id,
    speciesId: 'test_bug',
    sizeMm: 40,
    potential: 3,
    temperament: Temperament.steadfast,
    sex: Sex.male,
    element: Element.wood,
    stage: LifeStage.adult,
    stageSince: t0.subtract(const Duration(days: 30)),
  );

  SaveGame saveOf({int tickets = 3}) =>
      SaveGame.initial(createdAt: t0).copyWith(
        bugs: [adult('a'), adult('b')],
        eventTickets: tickets,
        eventTicketsAt: t0,
      );

  ActionResult start(SaveGame s, [String id = 'a']) => actions.eventDuelStart(
    s,
    bugId: id,
    speciesById: species,
    petConfig: cfg.pet,
  );

  ActionResult throwOnce(
    SaveGame s,
    Map<String, dynamic> session, {
    String? cardId,
  }) => actions.eventDuelThrow(
    s,
    session: session,
    launch: 0.8,
    cardId: cardId,
    speciesById: species,
    petConfig: cfg.pet,
  );

  /// 끝까지 — 카드는 늘 첫 장.
  ({SaveGame save, Map<String, dynamic> last, int throws}) playOut(
    SaveGame s,
    Map<String, dynamic> session,
  ) {
    var save = s;
    var sess = session;
    Map<String, dynamic> last = const {};
    String? card;
    var n = 0;
    while (true) {
      final r = throwOnce(save, sess, cardId: card);
      expect(r.isOk, isTrue, reason: r.error);
      n++;
      save = r.save!;
      last = r.extra;
      sess = Map<String, dynamic>.from(r.extra['session'] as Map);
      if (r.extra['done'] == true) break;
      final cards = r.extra['cards'] as List;
      card = cards.isEmpty ? null : (cards.first as Map)['id'] as String;
      if (n > 2000) fail('끝나지 않는다');
    }
    return (save: save, last: last, throws: n);
  }

  test('옛 3마리 경로는 닫힌다(구버전 앱이 옛 규칙으로 뛰지 못하게)', () {
    final r = actions.eventStart(
      saveOf(),
      teamIds: ['a', 'b', 'a'],
      speciesById: species,
    );
    expect(r.error, 'event_update');
  });

  test('시작 — 참가권 −1 · 그 곤충만 부상 · 세션 생성', () {
    final r = start(saveOf());
    expect(r.isOk, isTrue, reason: r.error);
    expect(r.save!.eventTickets, 2);
    expect(r.save!.isInjured('a', t0), isTrue);
    expect(r.save!.isInjured('b', t0), isFalse);
    final sess = r.extra['session'] as Map<String, dynamic>;
    expect(sess['bugId'], 'a');
    expect(sess['done'], isFalse);
    expect(r.extra['bug'], isA<Map<String, dynamic>>());
  });

  test('다친 곤충은 나갈 수 없다(피로 대신 부상)', () {
    final after = start(saveOf()).save!;
    expect(start(after).error, 'bug_injured');
    expect(start(after, 'b').isOk, isTrue);
  });

  test('참가권이 없으면 거부', () {
    expect(start(saveOf(tickets: 0)).error, 'no_ticket');
  });

  test('끝까지 치르면 점수·최고 기록이 확정된다', () {
    final r = start(saveOf());
    final out = playOut(r.save!, r.extra['session'] as Map<String, dynamic>);
    expect(out.last['done'], isTrue);
    expect(out.last['isBest'], isTrue);
    expect(out.save.eventBestScore, out.last['score']);
    expect(out.save.eventBestWave, out.last['cleared']);
  });

  test('카드가 걸려 있으면 카드 없이 못 던지고, 제시되지 않은 카드는 거부', () {
    final r = start(saveOf());
    var save = r.save!;
    var sess = r.extra['session'] as Map<String, dynamic>;
    // 이길 때까지(카드가 나올 때까지) 던진다.
    for (var i = 0; i < 50; i++) {
      final x = throwOnce(save, sess);
      save = x.save!;
      sess = Map<String, dynamic>.from(x.extra['session'] as Map);
      if ((x.extra['cards'] as List).isNotEmpty || x.extra['done'] == true) {
        break;
      }
    }
    if (sess['done'] == true) return; // 1웨이브에서 끝난 판 — 카드 검사 불가
    expect(throwOnce(save, sess).error, 'card_required');
    expect(throwOnce(save, sess, cardId: 'nope').error, 'bad_card');
  });

  test('끝난 세션은 다시 진행할 수 없다', () {
    final r = start(saveOf());
    final out = playOut(r.save!, r.extra['session'] as Map<String, dynamic>);
    final sess = {
      ...(r.extra['session'] as Map<String, dynamic>),
      'done': true,
    };
    expect(throwOnce(out.save, sess).error, 'session_done');
  });

  test('적은 회차 seed 로 정해진다 — 같은 회차면 모두 같은 웨이브', () {
    final a = actions.eventDuelEnemyOf(123, 5, species);
    final b = actions.eventDuelEnemyOf(123, 5, species);
    expect(a.toJson(), b.toJson());
    expect(
      actions.eventDuelEnemyOf(123, 6, species).maxHp,
      greaterThan(a.maxHp),
    );
  });

  test('세션의 진행 상태는 공용 규칙(EventDuelRun)과 같은 모양', () {
    final r = start(saveOf());
    final sess = r.extra['session'] as Map<String, dynamic>;
    final x = throwOnce(r.save!, sess);
    final run = EventDuelRun.fromJson(
      Map<String, dynamic>.from(x.extra['run'] as Map),
    );
    expect(run.cleared, x.extra['cleared']);
  });

  test('그만하기 — 기록 확정 · 체력을 남기면 부상이 줄어든다', () {
    final r = start(saveOf());
    final sess = r.extra['session'] as Map<String, dynamic>;
    final full = cfg.pet.injuryDuration(testSpecies.grade);
    // 시작하자마자 그만두면 체력 100% → 최소 비율(20%)만 쉰다.
    final q = actions.eventDuelQuit(
      r.save!,
      session: sess,
      speciesById: species,
      petConfig: cfg.pet,
    );
    expect(q.isOk, isTrue, reason: q.error);
    expect(q.extra['done'], isTrue);
    final until = q.save!.injuredUntil('a')!;
    final sec = until.difference(t0).inSeconds;
    expect(sec, closeTo(full * 0.2, 2));
    expect(sec, lessThan(full));
    // 끝난 세션은 다시 그만둘 수 없다.
    final again = actions.eventDuelQuit(
      q.save!,
      session: Map<String, dynamic>.from(q.extra['session'] as Map),
      speciesById: species,
      petConfig: cfg.pet,
    );
    expect(again.error, 'session_done');
  });

  test('체력이 바닥나서 끝나면 최대 부상', () {
    final r = start(saveOf());
    final out = playOut(r.save!, r.extra['session'] as Map<String, dynamic>);
    final full = cfg.pet.injuryDuration(testSpecies.grade);
    final sec = out.save.injuredUntil('a')!.difference(t0).inSeconds;
    expect(sec, closeTo(full, 2));
  });

  // ── 2026-09-30 출시 전 점검 ──

  test('회차가 바뀌면 최고 기록을 비운다(1회차 옛 단위 점수가 2회차 기록을 막던 버그)', () {
    final old = saveOf().copyWith(
      eventRoundId: 'old-round',
      eventBestScore: 12000000,
      eventBestWave: 40,
    );
    final r = start(old);
    expect(r.isOk, isTrue, reason: r.error);
    expect(r.save!.eventBestScore, 0);
    expect(r.save!.eventBestWave, 0);
    final out = playOut(r.save!, r.extra['session'] as Map<String, dynamic>);
    expect(out.last['isBest'], isTrue);
    expect(out.save.eventBestScore, out.last['score']);
  });

  test('같은 회차 안에서는 최고 기록을 지우지 않는다', () {
    final r1 = start(saveOf());
    final done = playOut(r1.save!, r1.extra['session'] as Map<String, dynamic>);
    final best = done.save.eventBestScore;
    final r2 = start(done.save, 'b');
    expect(r2.save!.eventBestScore, best);
  });

  test('지난 회차에 연 판은 더 못 싸우고, 그만둬도 이번 회차 기록이 되지 않는다', () {
    final r = start(saveOf());
    final stale = {
      ...(r.extra['session'] as Map<String, dynamic>),
      'roundId': 'old-round',
    };
    expect(throwOnce(r.save!, stale).error, 'event_closed');
    final withBest = r.save!.copyWith(eventBestScore: 5);
    final q = actions.eventDuelQuit(
      withBest,
      session: stale,
      speciesById: species,
      petConfig: cfg.pet,
    );
    expect(q.isOk, isTrue, reason: q.error);
    expect(q.extra['isBest'], isFalse);
    expect(q.save!.eventBestScore, 5);
    // 부상은 그대로 건다.
    expect(q.save!.isInjured('a', t0), isTrue);
  });

  test('대회 seed 는 시각에서 복원되지 않는다(같은 순간 같은 곤충이어도 다르다)', () {
    final seeds = {
      for (var i = 0; i < 8; i++)
        (start(saveOf()).extra['session'] as Map)['seed'],
    };
    expect(seeds.length, greaterThan(1));
  });

  test('대회 부상은 서버 소유 — 세이브에서 injured 를 지워도 다시 못 나간다', () {
    final r = start(saveOf());
    expect(r.save!.eventOnFatigue('a', t0), isTrue);
    // 앱이 젤리 없이 injured 만 지운 세이브를 올린 상황.
    final forged = r.save!.copyWith(injured: const {});
    expect(start(forged).error, 'bug_injured');
  });

  test('끝난 뒤 부상도 서버 기록에 남는다(그만두면 줄어든 값으로)', () {
    final r = start(saveOf());
    final q = actions.eventDuelQuit(
      r.save!,
      session: r.extra['session'] as Map<String, dynamic>,
      speciesById: species,
      petConfig: cfg.pet,
    );
    expect(q.save!.eventFatigue['a'], q.save!.injuredUntil('a'));
  });

  test('대회 부상 젤리 즉시 회복 — 서버가 젤리를 깎고 두 기록을 함께 지운다', () {
    final r = start(saveOf());
    final hurt = r.save!.copyWith(materials: {MaterialKind.jelly: 1000});
    final h = actions.eventHealJelly(hurt, bugId: 'a', petConfig: cfg.pet);
    expect(h.isOk, isTrue, reason: h.error);
    final cost = h.extra['jelly'] as int;
    expect(cost, greaterThan(0));
    expect(h.save!.materialCount(MaterialKind.jelly), 1000 - cost);
    expect(h.save!.eventOnFatigue('a', t0), isFalse);
    expect(h.save!.isInjured('a', t0), isFalse);
    expect(start(h.save!).error, isNot('bug_injured'));
    // 젤리가 모자라면 거부, 안 다친 곤충도 거부.
    final poor = r.save!.copyWith(materials: const {});
    expect(
      actions.eventHealJelly(poor, bugId: 'a', petConfig: cfg.pet).error,
      'no_jelly',
    );
    expect(
      actions.eventHealJelly(hurt, bugId: 'b', petConfig: cfg.pet).error,
      'not_injured',
    );
  });
}

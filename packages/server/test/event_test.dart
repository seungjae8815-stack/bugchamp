import 'dart:convert';
import 'dart:io';

import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:core_save/core_save.dart';
import 'package:server/src/actions.dart';
import 'package:test/test.dart';

import 'actions_test.dart' show testSpecies;

/// 실물 경품 랭킹 이벤트(웨이브 방어전) — **서버가 확정하는 것들**.
///
/// 이 모드의 점수는 그대로 실물 상품이 된다. 그래서 앱이 계산한 값을 받아 적는
/// 경로가 없어야 하고, 참가권·출전 피로·최고 기록은 전부 서버가 소유해야 한다
/// (`_serverOwnedKeys`). 여기서 검사하는 것은 그 계약이다.
class _Cfg implements GameConfigLike {
  @override
  final IapConfig iap = IapConfig.fromJson({
    'passDurationDays': 30,
    'products': <dynamic>[],
  });
  @override
  final BattleConfig battle = const BattleConfig();
  @override
  final RunConfig run = RunConfig.fromJson(
    jsonDecode(File('../app/assets/data/run_config.json').readAsStringSync())
        as Map<String, dynamic>,
  );
  @override
  final PetConfig pet = PetConfig.fromJson(
    jsonDecode(File('../app/assets/data/pets.json').readAsStringSync())
        as Map<String, dynamic>,
  );
  @override
  final EnhanceConfig? enhance = null;
  @override
  final ForgeConfig? forge = null;
  @override
  final MissionConfig? mission = null;
  @override
  final GiftConfig? gift = null;
  @override
  final DailyConfig? daily = null;
  @override
  final RoadmapConfig? roadmap = null;
  @override
  final EventConfig? event = EventConfig.fromJson(
    jsonDecode(File('../app/assets/data/event.json').readAsStringSync())
        as Map<String, dynamic>,
  );
  @override
  List<Species> get speciesList => [testSpecies];
}

/// 다른 이벤트 테스트도 같은 설정을 쓴다(실제 event.json 로드).
GameConfigLike buildEventCfg() => _Cfg();

void main() {
  final t0 = DateTime.utc(2026, 8, 17, 3); // KST 12:00 — 일일 지급 경계 이후
  final species = {'test_bug': testSpecies};
  final cfg = _Cfg();
  final actions = GameActions(config: cfg, now: () => t0);

  IndividualBug adult(String id, {Element el = Element.wood}) => IndividualBug(
    id: id,
    speciesId: 'test_bug',
    sizeMm: 40,
    potential: 3,
    temperament: Temperament.steadfast,
    sex: Sex.male,
    element: el,
    stage: LifeStage.adult,
    stageSince: t0.subtract(const Duration(days: 30)),
  );

  SaveGame withTeam({int tickets = 3}) => SaveGame.initial(createdAt: t0)
      .copyWith(
        bugs: [
          adult('a', el: Element.wood),
          adult('b', el: Element.fire),
          adult('c', el: Element.earth),
          adult('d', el: Element.metal),
          adult('e', el: Element.water),
          adult('f', el: Element.wood),
        ],
        eventTickets: tickets,
        eventTicketsAt: t0,
      );

  ActionResult go(SaveGame s, [List<String>? ids]) => actions.eventChallenge(
    s,
    teamIds: ids ?? ['a', 'b', 'c'],
    speciesById: species,
  );

  test('도전하면 참가권이 깎이고 점수·웨이브가 확정된다', () {
    final r = go(withTeam());
    expect(r.isOk, isTrue);
    expect(r.save!.eventTickets, 2);
    expect(r.extra['wave'], greaterThan(0));
    expect(r.extra['score'], greaterThan(0));
    expect(r.extra['isBest'], isTrue);
  });

  test('같은 회차·같은 팀이면 결과가 같다 — 앱이 재생할 수 있는 근거', () {
    final a = go(withTeam());
    final b = go(withTeam());
    expect(a.extra['seed'], b.extra['seed']);
    expect(a.extra['wave'], b.extra['wave']);
    expect(a.extra['score'], b.extra['score']);
  });

  test('출전한 곤충은 피로가 걸려 다시 못 나간다', () {
    final first = go(withTeam());
    expect(first.isOk, isTrue);
    final after = first.save!;
    expect(after.eventOnFatigue('a', t0), isTrue);
    expect(after.eventOnFatigue('d', t0), isFalse);

    expect(go(after).error, 'fatigued');
    // 쉬고 있지 않은 곤충으로는 도전할 수 있다.
    expect(go(after, ['d', 'e', 'f']).isOk, isTrue);
  });

  test('피로가 풀리면 다시 나갈 수 있다', () {
    final after = go(withTeam()).save!;
    final later = GameActions(
      config: cfg,
      now: () => t0.add(const Duration(hours: 25)),
    );
    final r = later.eventChallenge(
      after,
      teamIds: ['a', 'b', 'c'],
      speciesById: species,
    );
    expect(r.isOk, isTrue);
  });

  test('참가권이 없으면 거부 — 판수를 늘릴 수 없다', () {
    expect(go(withTeam(tickets: 0)).error, 'no_ticket');
  });

  test('편성이 3마리·중복 없음·보유 개체여야 한다', () {
    final s = withTeam();
    expect(go(s, ['a', 'b']).error, 'bad_team');
    expect(go(s, ['a', 'a', 'b']).error, 'bad_team');
    expect(go(s, ['a', 'b', 'nope']).error, 'bad_team');
  });

  test('성충이 아니면 거부', () {
    final s = withTeam().copyWith(
      bugs: [
        adult('a').copyWith(stage: LifeStage.egg, stageSince: t0),
        adult('b'),
        adult('c'),
      ],
    );
    expect(go(s).error, 'not_adult');
  });

  test('최고 기록만 갱신된다 — 낮은 점수로 덮이지 않는다', () {
    final first = go(withTeam(tickets: 5)).save!;
    final best = first.eventBestScore;
    // 오행을 몰아 짠 약한 편성으로 한 판 더.
    final weak = first.copyWith(
      bugs: [
        ...first.bugs,
        adult('x', el: Element.wood),
        adult('y', el: Element.wood),
        adult('z', el: Element.wood),
      ],
    );
    final second = go(weak, ['x', 'y', 'z']);
    expect(second.isOk, isTrue);
    expect(
      second.save!.eventBestScore,
      greaterThanOrEqualTo(best),
      reason: '최고 기록은 내려가지 않는다',
    );
  });

  test('참가권은 하루에 한 번만 지급된다 — 여러 날 비워도 몰아 받지 않는다', () {
    final s = SaveGame.initial(createdAt: t0).copyWith(
      eventTickets: 0,
      eventTicketsAt: t0.subtract(const Duration(days: 5)),
    );
    final now = actions.eventTicketsNow(s);
    expect(now.tickets, cfg.event!.ticketDailyGrant);
  });

  test('같은 날 다시 정산해도 더 주지 않는다', () {
    final s = SaveGame.initial(
      createdAt: t0,
    ).copyWith(eventTickets: 1, eventTicketsAt: t0);
    expect(actions.eventTicketsNow(s).tickets, 1);
  });

  test('참가권은 상한을 넘지 않는다', () {
    final s = SaveGame.initial(createdAt: t0).copyWith(
      eventTickets: cfg.event!.ticketMax,
      eventTicketsAt: t0.subtract(const Duration(days: 2)),
    );
    expect(actions.eventTicketsNow(s).tickets, cfg.event!.ticketMax);
  });

  test('광고 참가권은 하루 상한이 있다 — 광고제거 구매자도 동일', () {
    var s = SaveGame.initial(
      createdAt: t0,
    ).copyWith(eventTickets: 0, eventTicketsAt: t0, adsRemoved: true);
    for (var i = 0; i < cfg.event!.ticketAdDailyLimit; i++) {
      final r = actions.grantEventAdTicket(s);
      expect(r.isOk, isTrue, reason: '${i + 1}번째 광고는 되어야 한다');
      s = r.save!;
    }
    expect(actions.grantEventAdTicket(s).error, 'ad_limit');
  });
}

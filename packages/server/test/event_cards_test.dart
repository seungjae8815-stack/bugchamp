import 'dart:convert';
import 'dart:io';

import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:core_save/core_save.dart';
import 'package:server/src/actions.dart';
import 'package:test/test.dart';

import 'actions_test.dart' show testSpecies;
import 'event_test.dart' show buildEventCfg;

/// 웨이브 사이 **카드 선택**(로그라이크) — 이게 이 모드의 유일한 개입 지점이다.
///
/// 검사하는 계약:
///  1. 제시되지 않은 카드는 받지 않는다(받으면 로그라이크가 아니라 치트가 된다).
///  2. 카드는 회차 seed + 웨이브로 뽑히므로 **누구에게나 같다**.
///  3. 고른 카드가 실제로 다음 웨이브 계산에 반영된다.
///  4. 판이 끝나야 점수가 확정된다.
void main() {
  final t0 = DateTime.utc(2026, 8, 17, 3);
  final species = {'test_bug': testSpecies};
  final cfg = buildEventCfg();
  final actions = GameActions(config: cfg, now: () => t0);
  final ev = cfg.event!;

  IndividualBug adult(String id, Element el) => IndividualBug(
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

  SaveGame seed() => SaveGame.initial(createdAt: t0).copyWith(
    bugs: [
      adult('a', Element.wood),
      adult('b', Element.fire),
      adult('c', Element.earth),
    ],
    eventTickets: 3,
    eventTicketsAt: t0,
  );

  ActionResult start(SaveGame s) =>
      actions.eventStart(s, teamIds: ['a', 'b', 'c'], speciesById: species);

  test('시작하면 1웨이브만 치르고 카드를 준다', () {
    final r = start(seed());
    expect(r.isOk, isTrue);
    expect(r.extra['wave'], 1);
    final cards = r.extra['cards'] as List;
    if (r.extra['won'] == true) {
      expect(cards.length, ev.cardPicks);
      expect(r.extra['done'], isFalse);
    }
    // 참가권은 시작할 때 이미 나간다 — 도중에 앱을 꺼도 되돌아오지 않는다.
    expect(r.save!.eventTickets, 2);
    expect(r.save!.eventOnFatigue('a', t0), isTrue);
  });

  test('제시되지 않은 카드는 거부한다', () {
    final r = start(seed());
    final session = r.extra['session'] as Map<String, dynamic>;
    final bad = actions.eventPick(
      r.save!,
      session: session,
      cardId: 'not_offered_card',
      speciesById: species,
    );
    expect(bad.error, 'bad_card');
  });

  test('카드는 회차 seed 로 정해진다 — 누구에게나 같다', () {
    final a = ev.drawCards(12345, 3).map((c) => c.id).toList();
    final b = ev.drawCards(12345, 3).map((c) => c.id).toList();
    expect(a, b);
    expect(a.toSet().length, a.length, reason: '같은 카드가 중복 제시되면 안 된다');
    final other = ev.drawCards(999, 3).map((c) => c.id).toList();
    expect(a, isNot(other));
  });

  test('고른 카드가 다음 웨이브에 반영된다 (공격 카드 → 더 멀리)', () {
    // 같은 판을 두 번 돌리되, 한쪽은 공격 카드를 계속 고른다.
    int runWith(String Function(List<dynamic>) choose) {
      var r = start(seed());
      var save = r.save!;
      var guard = 0;
      while (r.isOk && r.extra['done'] != true && guard < 40) {
        final cards = r.extra['cards'] as List;
        if (cards.isEmpty) break;
        r = actions.eventPick(
          save,
          session: r.extra['session'] as Map<String, dynamic>,
          cardId: choose(cards),
          speciesById: species,
        );
        if (!r.isOk) break;
        save = r.save!;
        guard++;
      }
      return (r.extra['cleared'] as num?)?.toInt() ?? 0;
    }

    // 공격/체력 계열을 우선, 없으면 첫 카드.
    String strong(List<dynamic> cards) {
      for (final c in cards) {
        final k = (c as Map)['kind'];
        if (k == 'atk' || k == 'maxHp') return '${c['id']}';
      }
      return '${(cards.first as Map)['id']}';
    }

    String weak(List<dynamic> cards) => '${(cards.last as Map)['id']}';

    final withStrong = runWith(strong);
    final withWeak = runWith(weak);
    // 카드가 계산에 안 들어가면 두 값이 항상 같다.
    expect(
      withStrong == withWeak && withStrong > 0,
      isFalse,
      reason: '카드 선택이 결과를 바꾸지 못하면 개입 지점이 없는 것이다',
    );
  });

  test('판이 끝나야 최고 기록이 확정된다', () {
    var r = start(seed());
    var save = r.save!;
    // 진행 중에는 기록이 비어 있다(1웨이브에서 끝난 경우 제외).
    if (r.extra['done'] != true) {
      expect(save.eventBestScore, 0);
    }
    var guard = 0;
    while (r.isOk && r.extra['done'] != true && guard < 40) {
      final cards = r.extra['cards'] as List;
      if (cards.isEmpty) break;
      r = actions.eventPick(
        save,
        session: r.extra['session'] as Map<String, dynamic>,
        cardId: '${(cards.first as Map)['id']}',
        speciesById: species,
      );
      if (!r.isOk) break;
      save = r.save!;
      guard++;
    }
    expect(r.extra['done'], isTrue);
    expect(save.eventBestScore, greaterThan(0));
    expect(save.eventBestWave, greaterThan(0));
  });

  test('끝난 세션은 다시 진행할 수 없다', () {
    var r = start(seed());
    var save = r.save!;
    var guard = 0;
    while (r.isOk && r.extra['done'] != true && guard < 40) {
      final cards = r.extra['cards'] as List;
      if (cards.isEmpty) break;
      r = actions.eventPick(
        save,
        session: r.extra['session'] as Map<String, dynamic>,
        cardId: '${(cards.first as Map)['id']}',
        speciesById: species,
      );
      if (!r.isOk) break;
      save = r.save!;
      guard++;
    }
    final done = r.extra['session'] as Map<String, dynamic>;
    final again = actions.eventPick(
      save,
      session: done,
      cardId: 'heal_s',
      speciesById: species,
    );
    expect(again.error, 'session_done');
  });
}

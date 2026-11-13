import 'dart:io';

import 'package:app/domain/funnel_log.dart';
import 'package:core_models/core_models.dart';
import 'package:core_save/core_save.dart';
import 'package:flutter_test/flutter_test.dart';

/// 신규 유저 이정표(2026-11-09) — 세이브 상태에서 파생한다. 이름은 SQL check 목록과 같아야 한다.
void main() {
  final t0 = DateTime.utc(2026, 11, 9);
  IndividualBug bug(String id, LifeStage stage) => IndividualBug(
    id: id,
    speciesId: 'rhino',
    sizeMm: 40,
    potential: 1,
    temperament: Temperament.steadfast,
    sex: Sex.male,
    stage: stage,
    stageSince: t0,
  );

  test('새 세이브는 이정표가 없다', () {
    expect(funnelMilestones(SaveGame.initial(createdAt: t0)), isEmpty);
  });

  test('쉬움 사냥터 도착은 역대 최고 스테이지로 · 보통에 들어서면 쉬움 이정표 전부', () {
    final s = SaveGame.initial(createdAt: t0);
    expect(funnelMilestones(s.copyWith(bestStage: 201)), {'zone2', 'zone3'});
    expect(
      funnelMilestones(s.copyWith(maxTierReached: 1)),
      containsAll(['zone2', 'zone3', 'zone5', 'easy_clear']),
    );
  });

  test('알만 있으면 egg · 알이 아닌 곤충이 생기면 hatch', () {
    final s = SaveGame.initial(createdAt: t0);
    expect(funnelMilestones(s.copyWith(bugs: [bug('a', LifeStage.egg)])), {
      'egg',
    });
    expect(
      funnelMilestones(
        s.copyWith(bugs: [bug('a', LifeStage.egg), bug('b', LifeStage.larva)]),
      ),
      {'egg', 'hatch'},
    );
  });

  test('일일보상은 점심·저녁 어느 쪽이든 · 보너스 키만으로는 아니다', () {
    final s = SaveGame.initial(createdAt: t0);
    expect(
      funnelMilestones(s.copyWith(dailyClaims: {'dinner': '2026-11-09'})),
      {'daily'},
    );
    expect(
      funnelMilestones(s.copyWith(dailyClaims: {'gift:x': '2026-11-09'})),
      isEmpty,
    );
  });

  test('판정이 내는 이름은 모두 kFunnelEvents 안에 있다(SQL check 와 같은 목록)', () {
    final all = funnelMilestones(
      SaveGame.initial(createdAt: t0).copyWith(
        maxTierReached: 1,
        bugs: [bug('b', LifeStage.adult)],
        equippedBugIds: ['b'],
        dailyClaims: {'lunch': '2026-11-09'},
        level: 10,
        pvpTrophies: 3,
      ),
    );
    expect(kFunnelEvents.toSet(), all);
  });

  test('SQL 의 허용 목록이 kFunnelEvents 와 같다(다르면 DB 가 조용히 거절한다)', () {
    final sql = File(
      '../../docs/_sql_20261109_funnel_events.sql',
    ).readAsStringSync();
    final list = RegExp(
      r'check \(event in \(([^)]*)\)',
    ).firstMatch(sql)!.group(1)!;
    final names = RegExp(
      r"'([a-z0-9_]+)'",
    ).allMatches(list).map((m) => m.group(1)).toSet();
    expect(names, kFunnelEvents.toSet());
  });
}

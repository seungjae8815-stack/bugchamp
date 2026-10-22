import 'dart:convert';
import 'dart:io';

import 'package:app/data/game_data.dart';
import 'package:app/domain/red_dots.dart';
import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart' show dailyDateKey;
import 'package:core_save/core_save.dart';
import 'package:flutter_test/flutter_test.dart';

/// 빨간 점 판정(2026-10-19) — 놓치면 손해인 것만, 그리고 해소되면 꺼지는지.
Map<String, dynamic> _json(String f) =>
    jsonDecode(File('assets/data/$f').readAsStringSync())
        as Map<String, dynamic>;

Map<String, dynamic> _name(String s) => {'ko': s, 'en': s, 'ja': s};

GameData _data() => GameData.fromDecoded(
  species: {
    'species': [
      {
        'id': 'stag',
        'name': _name('stag'),
        'grade': 'common',
        'specialty': 'grip',
        'baseStats': {'hp': 100, 'atk': 40, 'def': 30, 'spd': 20},
        'sizeMinMm': 20,
        'sizeMaxMm': 60,
      },
    ],
  },
  traps: {
    'traps': [
      {'id': 'sap_trap', 'name': _name('S')},
    ],
  },
  fields: {
    'fields': [
      {'id': 'oak_forest', 'name': _name('O'), 'unlockOrder': 0},
    ],
  },
  spawns: {
    'schemaVersion': 1,
    'defaultPotentialWeights': [
      {'potential': 1, 'weight': 1},
    ],
    'spawns': <dynamic>[],
  },
  petConfig: _json('pets.json'),
  battleConfig: _json('battle.json'),
  skillConfig: _json('skills.json'),
);

// 수요일 낮(KST) — 결투 정산 기간(일 09시~월 09시)이 아니다.
final _now = DateTime.utc(2026, 10, 21, 3);

IndividualBug _bug(
  String id, {
  Sex sex = Sex.male,
  LifeStage stage = LifeStage.adult,
  DateTime? breakthroughEndsAt,
}) => IndividualBug(
  id: id,
  speciesId: 'stag',
  sizeMm: 40,
  potential: 1,
  temperament: Temperament.steadfast,
  sex: sex,
  stage: stage,
  stageSince: _now.subtract(const Duration(days: 30)),
  breakthroughEndsAt: breakthroughEndsAt,
);

RedDots _dots(GameData d, SaveGame s) =>
    computeRedDots(save: s, data: d, nowUtc: _now, localNow: _now);

void main() {
  final data = _data();
  final base = SaveGame.initial(createdAt: DateTime.utc(2026, 1, 1));

  test('부화기 — 빈 칸에 넣을 알이 있으면 켜지고, 알이 없으면 꺼진다', () {
    final egg = _bug('e1', stage: LifeStage.egg);
    expect(_dots(data, base.copyWith(bugs: [egg])).incubator, isTrue);
    expect(_dots(data, base.copyWith(bugs: [_bug('a1')])).incubator, isFalse);
    // 넣은 알이 아직 부화 중이면 꺼진다 · 끝나면 켜진다.
    final busy = base.copyWith(
      bugs: [egg],
      incubating: {'e1': _now.add(const Duration(hours: 1))},
    );
    expect(_dots(data, busy).incubator, isFalse);
    final done = base.copyWith(
      bugs: [egg],
      incubating: {'e1': _now.subtract(const Duration(minutes: 1))},
    );
    expect(_dots(data, done).incubator, isTrue);
  });

  test('짝짓기 — 같은 종 성충 암수가 있으면 켜지고, 한쪽뿐이면 꺼진다', () {
    final pair = [_bug('m'), _bug('f', sex: Sex.female)];
    expect(_dots(data, base.copyWith(bugs: pair)).breeding, isTrue);
    expect(_dots(data, base.copyWith(bugs: [_bug('m')])).breeding, isFalse);
  });

  test('돌파가 끝난 곤충만 칸에 점 · 채집함 탭도 켜진다', () {
    final s = base.copyWith(
      bugs: [
        _bug('done', breakthroughEndsAt: _now),
        _bug('busy', breakthroughEndsAt: _now.add(const Duration(hours: 1))),
      ],
    );
    final d = _dots(data, s);
    expect(d.breakthroughBugs, {'done'});
    expect(d.storageTab, isTrue);
  });

  test('결투 티켓 — 가득이면 "가득" 점, 모자라면 무료 충전 점, 무료를 다 쓰면 없음', () {
    final cfg = data.battleConfig!;
    final full = _dots(
      data,
      base.copyWith(pvpTickets: cfg.ticketMax, ticketsAt: _now),
    );
    expect(full.ticketFull, isTrue);
    expect(full.ticketFree, isFalse);

    final low = base.copyWith(pvpTickets: 0, ticketsAt: _now);
    expect(_dots(data, low).ticketFree, isTrue);

    final used = low.copyWith(
      adUseDate: dailyDateKey(_now),
      adUseCounts: {kAdFeaturePvpTicket: cfg.ticketAdDailyLimit},
    );
    expect(_dots(data, used).ticketFree, isFalse);
    expect(_dots(data, used).ticketFull, isFalse);
  });

  test('스킬 무료 뽑기 — 오늘 안 썼으면 켜지고 다 쓰면 꺼진다 · 소탕은 잡은 보스가 없으면 없다', () {
    final cfg = data.skillConfig!;
    final d = _dots(data, base);
    expect(d.skillDraw, isTrue);
    expect(d.skillSweep, isFalse, reason: '보스를 한 마리도 안 잡았으면 소탕할 수 없다');
    final used = base.copyWith(
      skillDayKey: dailyDateKey(_now),
      skillFreeDrawsUsed: cfg.gachaFreePerDay,
    );
    expect(_dots(data, used).skillDraw, isFalse);
  });

  test('끝난 타이머 — 스킬 수련 · 공방 등급업', () {
    expect(_dots(data, base).skillTraining, isFalse);
    expect(
      _dots(data, base.copyWith(skillTrainingEndsAt: _now)).skillTraining,
      isTrue,
    );
    expect(_dots(data, base.copyWith(forgeUpAt: _now)).equipTab, isTrue);
    expect(
      _dots(
        data,
        base.copyWith(forgeUpAt: _now.add(const Duration(minutes: 5))),
      ).forge,
      isFalse,
    );
  });
}

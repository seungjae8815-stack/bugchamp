import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:core_save/core_save.dart';
import 'package:test/test.dart';

/// 도감(§2.1) — 곤충이 **사라져도 남는** 기록.
///
/// 분해·방생·상한 정리로 개체는 없어지지만 "이 종을 잡아봤다 / 성충까지
/// 키웠다"는 남아야 한다. 그게 무너지면 수집 게임인데 수집한 흔적이 없어진다.
void main() {
  IndividualBug bug(
    String speciesId, {
    double size = 40,
    int potential = 2,
    LifeStage stage = LifeStage.egg,
  }) => IndividualBug(
    id: '$speciesId-$size-$potential-${stage.key}',
    speciesId: speciesId,
    sizeMm: size,
    potential: potential,
    temperament: Temperament.steadfast,
    sex: Sex.male,
    stage: stage,
  );

  /// 저장된 단계를 그대로 실제 단계로 본다(시간 계산은 호출부 책임).
  LifeStage asStored(IndividualBug b) => b.stage;

  group('updatedDex — 보유 곤충 → 기록', () {
    test('처음 보는 종이 등록된다', () {
      final dex = updatedDex(
        current: const {},
        bugs: [bug('alpha', size: 42, potential: 3)],
        stageOf: asStored,
      );
      expect(dex.keys, ['alpha']);
      expect(dex['alpha']!.maxSizeMm, 42);
      expect(dex['alpha']!.maxPotential, 3);
      expect(dex['alpha']!.raisedToAdult, isFalse);
    });

    test('최대치만 남는다 — 더 작은 개체가 기록을 덮어쓰지 않는다', () {
      var dex = updatedDex(
        current: const {},
        bugs: [bug('alpha', size: 60, potential: 4)],
        stageOf: asStored,
      );
      dex = updatedDex(
        current: dex,
        bugs: [bug('alpha', size: 30, potential: 1)],
        stageOf: asStored,
      );
      expect(dex['alpha']!.maxSizeMm, 60);
      expect(dex['alpha']!.maxPotential, 4);
    });

    test('성충까지 키우면 정복 표시가 붙고, 이후 알을 잡아도 안 풀린다', () {
      var dex = updatedDex(
        current: const {},
        bugs: [bug('alpha', stage: LifeStage.adult)],
        stageOf: asStored,
      );
      expect(dex['alpha']!.raisedToAdult, isTrue);

      dex = updatedDex(
        current: dex,
        bugs: [bug('alpha', stage: LifeStage.egg)],
        stageOf: asStored,
      );
      expect(dex['alpha']!.raisedToAdult, isTrue, reason: '한 번 정복하면 유지');
    });

    test('바뀔 게 없으면 **같은 인스턴스**를 돌려준다 — 헛 저장·업로드 방지', () {
      final first = updatedDex(
        current: const {},
        bugs: [bug('alpha', size: 50, potential: 3)],
        stageOf: asStored,
      );
      final again = updatedDex(
        current: first,
        bugs: [bug('alpha', size: 50, potential: 3)],
        stageOf: asStored,
      );
      expect(identical(again, first), isTrue);
    });

    test('여러 종을 한 번에 집계한다', () {
      final dex = updatedDex(
        current: const {},
        bugs: [
          bug('alpha', size: 30),
          bug('beta', size: 70, stage: LifeStage.adult),
          bug('alpha', size: 55),
        ],
        stageOf: asStored,
      );
      expect(dex.length, 2);
      expect(dex['alpha']!.maxSizeMm, 55);
      expect(dex['beta']!.raisedToAdult, isTrue);
    });
  });

  group('SaveGame 도감 집계', () {
    SaveGame withDex(Map<String, DexEntry> dex) => SaveGame.initial(
      createdAt: DateTime.utc(2026, 1, 1),
    ).copyWith(dex: dex);

    test('발견·정복 수와 역대 최대 크기', () {
      final s = withDex(const {
        'a': DexEntry(maxSizeMm: 30, maxPotential: 2),
        'b': DexEntry(
          maxSizeMm: 88,
          maxPotential: 4,
          raisedToAdult: true,
          maxLevel: 12,
        ),
        // 기준을 올리기 **전에** 만든 기록 — lv 는 0 이지만 인정된다.
        // 안 그러면 업데이트 순간 기존 유저의 도감 보너스가 사라진다.
        'c': DexEntry(
          maxSizeMm: 51,
          maxPotential: 1,
          raisedToAdult: true,
          legacyConquered: true,
        ),
      });
      expect(s.dexDiscovered, 3);
      expect(s.dexConqueredWith(10), 2);
      expect(s.dexBestSizeMm, 88);
    });

    test('빈 도감은 0 이고, JSON 에 키를 싣지 않는다', () {
      final s = SaveGame.initial(createdAt: DateTime.utc(2026, 1, 1));
      expect(s.dexDiscovered, 0);
      expect(s.dexBestSizeMm, 0);
      expect(s.toJson().containsKey('dex'), isFalse);
    });

    test('JSON 왕복에서 보존된다', () {
      final s = withDex(const {
        'a': DexEntry(maxSizeMm: 62.5, maxPotential: 3, raisedToAdult: true),
      });
      final back = SaveGame.fromJson(s.toJson());
      expect(back.dex['a']!.maxSizeMm, 62.5);
      expect(back.dex['a']!.maxPotential, 3);
      expect(back.dex['a']!.raisedToAdult, isTrue);
    });

    test('도감 JSON 이 망가져 있어도 세이브는 열린다 — 어차피 파생 집계다', () {
      final json = SaveGame.initial(
        createdAt: DateTime.utc(2026, 1, 1),
      ).toJson()..['dex'] = 'not-a-map';
      expect(SaveGame.fromJson(json).dex, isEmpty);

      final json2 =
          SaveGame.initial(createdAt: DateTime.utc(2026, 1, 1)).toJson()
            ..['dex'] = {
              'a': 'garbage',
              'b': <String, dynamic>{'s': 40},
            };
      final back = SaveGame.fromJson(json2);
      expect(back.dex.containsKey('a'), isFalse);
      expect(back.dex['b']!.maxSizeMm, 40);
    });
  });

  group('DexConfig — 마일스톤·영구 보너스', () {
    final cfg = DexConfig.fromJson(const {
      'discoverMilestones': [
        {'count': 5, 'gold': 100, 'jelly': 10},
        {'count': 10, 'gold': 200, 'jelly': 20},
      ],
      'conquerMilestones': [
        {'count': 3, 'gold': 300, 'jelly': 15},
      ],
      'attackPerConquer': 0.015,
      'hpPerConquer': 0.02,
      'rewardPerDiscover': 0.01,
    });

    test('문턱에 닿아야 받을 수 있다(경계 포함)', () {
      expect(cfg.claimable(4, 0, {}), isEmpty);
      expect(cfg.claimable(5, 0, {}).map((m) => m.id), ['dex_d_5']);
      expect(cfg.claimable(10, 3, {}).map((m) => m.id), [
        'dex_d_5',
        'dex_d_10',
        'dex_c_3',
      ]);
    });

    test('이미 받은 건 다시 안 나온다', () {
      expect(cfg.claimable(10, 3, {'dex_d_5', 'dex_c_3'}).map((m) => m.id), [
        'dex_d_10',
      ]);
    });

    test('마일스톤 id 는 개수 기반 — JSON 을 늘려도 받은 기록이 유지된다', () {
      // 마일스톤을 하나 더 끼워 넣어도 기존 id 는 그대로여야 한다.
      final bigger = DexConfig.fromJson(const {
        'discoverMilestones': [
          {'count': 3, 'gold': 50},
          {'count': 5, 'gold': 100},
          {'count': 10, 'gold': 200},
        ],
      });
      expect(
        bigger.claimable(10, 0, {'dex_d_5', 'dex_d_10'}).map((m) => m.id),
        ['dex_d_3'],
      );
    });

    test('정복 수에 비례해 공격·체력이 오른다', () {
      const base = CharacterStats(
        attack: 100,
        attackSpeed: 2,
        rewardMultiplier: 1,
        critChance: 0,
        critDamage: 2,
        bossDamage: 1,
        maxHp: 1000,
        defense: 0,
        hpRegen: 0,
        xpMultiplier: 1,
        bugFind: 1,
        materialFind: 1,
        moveSpeed: 1,
        boostBonus: 1,
      );
      final out = cfg.apply(base, 10, 20);
      expect(out.attack, closeTo(100 * (1 + 0.015 * 20), 1e-9));
      expect(out.maxHp, closeTo(1000 * (1 + 0.02 * 20), 1e-9));
      expect(out.rewardMultiplier, closeTo(1 + 0.01 * 10, 1e-9));
      // 나머지는 건드리지 않는다.
      expect(out.attackSpeed, base.attackSpeed);
      expect(out.defense, base.defense);
    });

    test('진행도 0 이면 원본 그대로', () {
      const base = CharacterStats(
        attack: 7,
        attackSpeed: 1,
        rewardMultiplier: 1,
        critChance: 0,
        critDamage: 2,
        bossDamage: 1,
        maxHp: 9,
        defense: 0,
        hpRegen: 0,
        xpMultiplier: 1,
        bugFind: 1,
        materialFind: 1,
        moveSpeed: 1,
        boostBonus: 1,
      );
      final out = cfg.apply(base, 0, 0);
      expect(out.attack, 7);
      expect(out.maxHp, 9);
    });
  });

  group('정복 기준(수련 레벨)', () {
    test('새 기록은 수련 레벨이 기준에 닿아야 정복이다', () {
      const grown = DexEntry(raisedToAdult: true, maxLevel: 10);
      const young = DexEntry(raisedToAdult: true, maxLevel: 3);
      expect(grown.conquered(10), isTrue);
      expect(young.conquered(10), isFalse);
      // 성충이 아니면 레벨이 높아도 정복이 아니다(있을 수 없는 조합이지만
      // 세이브 편집으로는 만들 수 있다).
      expect(const DexEntry(maxLevel: 99).conquered(10), isFalse);
    });

    test('lv 키가 없는 옛 기록은 정복으로 인정하고, 저장하면 g 로 굳는다', () {
      final old = DexEntry.fromJson({'s': 40.0, 'a': true});
      expect(old.legacyConquered, isTrue);
      expect(old.conquered(10), isTrue);
      final back = DexEntry.fromJson(old.toJson());
      expect(back.legacyConquered, isTrue, reason: 'g 플래그로 굳어야 한다');
    });

    test('lv 를 항상 쓴다 — 생략하면 새 기록이 옛 기록으로 오해된다', () {
      const fresh = DexEntry(raisedToAdult: true);
      expect(fresh.toJson().containsKey('lv'), isTrue);
      final back = DexEntry.fromJson(fresh.toJson());
      expect(back.legacyConquered, isFalse);
      expect(back.conquered(10), isFalse, reason: '공짜 정복이 되면 안 된다');
    });
  });
}

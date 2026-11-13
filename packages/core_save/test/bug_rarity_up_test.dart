import 'dart:math';
import 'dart:convert';
import 'dart:io';

import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:core_save/core_save.dart';
import 'package:test/test.dart';

// 희귀도 올리기(2026-10-16 사장님 확정, 1.0.22) — 같은 종 · 같은 희귀도 3마리 → +1.
void main() {
  final pet = PetConfig.fromJson(
    jsonDecode(File('../app/assets/data/pets.json').readAsStringSync())
        as Map<String, dynamic>,
  );
  const sp = Species(
    id: 'stag_saw',
    name: LocalizedText(ko: '톱사슴벌레', en: 's', ja: 's'),
    grade: Grade.common,
    specialty: Specialty.grip,
    baseStats: Stats(hp: 90, atk: 34, def: 30, spd: 28),
    sizeMinMm: 20,
    sizeMaxMm: 60,
  );
  final byId = {sp.id: sp};
  final t0 = DateTime.utc(2026, 10, 16);

  IndividualBug bug(
    String id, {
    Grade r = Grade.common,
    String species = 'stag_saw',
    int level = 1,
    LifeStage stage = LifeStage.adult,
  }) => IndividualBug(
    id: id,
    speciesId: species,
    sizeMm: 40,
    potential: 1,
    temperament: Temperament.cunning,
    sex: Sex.male,
    stage: stage,
    level: level,
    rarity: r,
  );

  SaveGame save(List<IndividualBug> bugs) =>
      SaveGame.initial(createdAt: t0).copyWith(bugs: bugs);

  test('실데이터 — 켜져 있고 재료 3마리', () {
    expect(pet.bugRarity.enabled, isTrue);
    expect(pet.bugRarity.upFodder, 3);
  });

  test('같은 종 · 같은 희귀도 3마리를 쓰고 한 단계 오른다 · 키운 것은 그대로', () {
    final s = save([
      bug('t', level: 5),
      bug('a'),
      bug('b'),
      bug('c'),
      bug('d'),
    ]);
    final r = rarityUp(s, 't', pet, byId);
    expect(r.isOk, isTrue);
    final out = r.save!;
    final t = out.bugs.firstWhere((b) => b.id == 't');
    expect(pet.rarityOf(t, sp), Grade.uncommon);
    expect(t.level, 5);
    expect(out.bugs.length, 2); // 재료 3마리 사라짐
    expect((r.extra['fodder'] as List).length, 3);
  });

  test('재료가 아닌 것 — 다른 종 · 다른 희귀도 · 알 · 투자한 곤충 · 잠금', () {
    final s = save([
      bug('t'),
      bug('other', species: 'stag_flat'),
      bug('rare', r: Grade.rare),
      bug('egg', stage: LifeStage.egg),
      bug('trained', level: 3),
      bug('locked'),
    ]).copyWith(lockedBugIds: {'locked'});
    expect(rarityUpFodder(s, s.bugs.first, pet, byId), isEmpty);
    expect(rarityUp(s, 't', pet, byId).error, 'no_fodder');
  });

  test('재료가 아닌 것(2026-10-16) — 등급 올린 · 옛 합성 · 뽑기·결제 출신 · 패시브 재굴림 · 이색', () {
    final s = save([
      bug('t'),
      bug('pot').copyWith(potential: 2),
      bug('su').copyWith(potential: 2, synthUps: 1),
      bug('gc').copyWith(fromGacha: true),
      bug('pr').copyWith(passiveRoll: 80),
      bug('var').copyWith(variant: BugVariant.rainbow),
      bug('ok'),
    ]);
    expect(
      [for (final b in rarityUpFodder(s, s.bugs.first, pet, byId)) b.id],
      ['ok'],
    );
  });

  test('전설은 더 못 올린다 · 알은 못 올린다', () {
    final s = save([
      bug('l', r: Grade.legendary),
      bug('a', r: Grade.legendary),
      bug('b', r: Grade.legendary),
      bug('c', r: Grade.legendary),
      bug('e', stage: LifeStage.egg),
    ]);
    expect(rarityUp(s, 'l', pet, byId).error, 'max');
    expect(rarityUp(s, 'e', pet, byId).error, 'egg');
  });

  test('정수가 늘지 않는다 — 일반 3마리 정수 > 고급 1마리 정수(올리기·바꾸기 반복으로 못 불린다)', () {
    final g = pet.individualGrade;
    final three = 3 * g.essenceOf(bug('x'), Grade.common);
    final one = g.essenceOf(bug('y', r: Grade.uncommon), Grade.uncommon);
    expect(one, lessThan(three + g.essenceOf(bug('t'), Grade.common)));
  });

  test('서버 검사 rarityUpAllowed — 단계마다 그 희귀도 재료 3마리 · 모자라면 아무것도 안 쓴다', () {
    final cfg = pet.bugRarity;
    List<({String id, String speciesId, Grade rarity})> gone(
      int common,
      int uncommon,
    ) => [
      for (var i = 0; i < common; i++)
        (id: 'c$i', speciesId: 'stag_saw', rarity: Grade.common),
      for (var i = 0; i < uncommon; i++)
        (id: 'u$i', speciesId: 'stag_saw', rarity: Grade.uncommon),
    ];
    final used = <String>{};
    final g1 = gone(3, 0);
    expect(
      rarityUpAllowed(
        from: Grade.common,
        to: Grade.uncommon,
        speciesId: 'stag_saw',
        gone: g1,
        cfg: cfg,
        used: used,
      ),
      isTrue,
    );
    expect(used, {'c0', 'c1', 'c2'});
    expect(g1, isEmpty);
    // 두 단계(일반 → 희귀) = 일반 3 + 고급 3.
    expect(
      rarityUpAllowed(
        from: Grade.common,
        to: Grade.rare,
        speciesId: 'stag_saw',
        gone: gone(3, 3),
        cfg: cfg,
      ),
      isTrue,
    );
    // 모자라면 false 이고 목록·사용 기록을 건드리지 않는다.
    final g2 = gone(2, 0);
    final used2 = <String>{};
    expect(
      rarityUpAllowed(
        from: Grade.common,
        to: Grade.uncommon,
        speciesId: 'stag_saw',
        gone: g2,
        cfg: cfg,
        used: used2,
      ),
      isFalse,
    );
    expect(g2.length, 2);
    expect(used2, isEmpty);
    // 다른 종 재료는 안 된다.
    expect(
      rarityUpAllowed(
        from: Grade.common,
        to: Grade.uncommon,
        speciesId: 'stag_flat',
        gone: gone(3, 0),
        cfg: cfg,
      ),
      isFalse,
    );
  });

  test('자동 올리기 — 아끼는 곤충부터 · 올린 곤충이 다시 재료로 이어진다 · 서버 검사도 같은 이음을 센다', () {
    // 키운 곤충 t + 일반 15마리. 양분 게이지(2026-11-09, pets.json worth 4·16·64)면 t 에 바로 먹인다:
    // 일반 3마리(4+12=16) → 고급 · 나머지 12마리(16+48=64) → 희귀 = 2번, 재료 15(옛 3마리 규칙이면 5번 — 같은 총량).
    final s = save([
      bug('t', level: 5),
      for (var i = 0; i < 15; i++) bug('w$i'),
    ]);
    final r = autoRarityUp(s, pet, byId);
    expect(r.isOk, isTrue);
    expect(r.extra['ups'], pet.bugRarity.worthOn ? 2 : 5);
    expect(r.extra['fodder'], 15);
    expect(r.save!.bugs.map((b) => b.id), ['t']);
    expect(r.save!.bugs.single.rarity, Grade.rare);
    expect(r.extra['bugs'], {'t': 'rare'});
    // 서버: 15마리가 모두 저장본의 일반으로 사라져도 일반 → 희귀를 인정한다(아래 단계 4마리 = 재료 하나).
    final gone = [
      for (var i = 0; i < 15; i++)
        (id: 'w$i', speciesId: 'stag_saw', rarity: Grade.common),
    ];
    final used = <String>{};
    expect(
      rarityUpAllowed(
        from: Grade.common,
        to: Grade.rare,
        speciesId: 'stag_saw',
        gone: gone,
        cfg: pet.bugRarity,
        used: used,
      ),
      isTrue,
    );
    expect(used.length, 15);
    // 14마리면 모자란다(재료를 늘려 주지 않는다).
    expect(
      rarityUpAllowed(
        from: Grade.common,
        to: Grade.rare,
        speciesId: 'stag_saw',
        gone: [
          for (var i = 0; i < 14; i++)
            (id: 'w$i', speciesId: 'stag_saw', rarity: Grade.common),
        ],
        cfg: pet.bugRarity,
      ),
      isFalse,
    );
    // 올릴 게 없으면 none.
    expect(autoRarityUp(save([bug('x')]), pet, byId).error, 'none');
  });

  test('올릴 수 있음 표시(rarityUpReadyIds) = rarityUp 이 성공하는 곤충과 같다', () {
    final s = save([
      bug('t', level: 5), // 키운 곤충 — 재료는 아니지만 올릴 수는 있다
      bug('a'),
      bug('b'),
      bug('c'),
      bug('u', r: Grade.uncommon), // 고급 재료 없음
      bug('e', stage: LifeStage.egg), // 알은 못 올림
    ]);
    final ready = rarityUpReadyIds(s, pet, byId);
    for (final b in s.bugs) {
      expect(
        ready.contains(b.id),
        rarityUp(s, b.id, pet, byId).isOk,
        reason: b.id,
      );
    }
    // a·b·c 는 재료가 둘뿐(t 는 키운 곤충이라 재료가 아니다).
    expect(ready, {'t'});
  });

  // 곤충 양분 게이지(2026-11-09 사장님 확정) — 희귀도가 달라도 먹이고, 낮을수록 적게 채운다.
  group('양분 게이지', () {
    final cfg = pet.bugRarity;
    int worth(IndividualBug b) => bugRarityWorth(b, cfg);

    test('실데이터 — 켜져 있고 4배씩(옛 4마리 규칙과 총량이 같다)', () {
      expect(cfg.worthOn, isTrue);
      for (var g = 1; g < Grade.values.length; g++) {
        expect(cfg.worth[g], cfg.worth[g - 1] * (cfg.upFodder + 1));
      }
    });

    test('희귀도가 다른 재료를 섞어 먹이면 가치 합으로 오르고 남는 몫은 게이지에 남는다', () {
      // 채우는 양 2배씩(4·8·16·32): 고급 t(문턱 16) + 고급 2(8×2) + 일반 12(4×12) = 80 → 희귀(64) · 남은 16.
      final s = save([
        bug('t', r: Grade.uncommon, level: 5),
        bug('u1', r: Grade.uncommon),
        bug('u2', r: Grade.uncommon),
        for (var i = 0; i < 12; i++) bug('c$i'),
      ]);
      final r = rarityFeed(
        s,
        't',
        ['u1', 'u2', for (var i = 0; i < 12; i++) 'c$i'],
        pet,
        byId,
      );
      expect(r.isOk, isTrue);
      final t = r.save!.bugs.single;
      expect(t.rarity, Grade.rare);
      expect(t.rarityWorth, 80 - cfg.worth[Grade.rare.index]);
      expect(worth(t), 80);
      expect(t.level, 5); // 키운 것은 그대로
    });

    test('목표보다 높은 희귀도는 재료가 아니다 · 다른 종도 아니다', () {
      final s = save([
        bug('t'),
        bug('hi', r: Grade.rare),
        bug('other', species: 'x'),
        bug('c'),
      ]);
      final f = rarityUpFodder(s, s.bugs.first, pet, byId).map((b) => b.id);
      expect(f, ['c']);
      expect(rarityFeed(s, 't', ['hi'], pet, byId).error, 'bad_fodder');
    });

    test('다음 단계까지만 먹일 땐 가치 작은 것부터, 모자라면 아무것도 안 먹인다', () {
      final s = save([bug('t'), bug('c1'), bug('c2'), bug('c3'), bug('c4')]);
      final plan = rarityFeedPlan(s, s.bugs.first, pet, byId, toNext: true);
      expect(plan.length, 3); // 4 + 12 = 16(고급)
      final short = save([bug('t'), bug('c1'), bug('c2')]);
      expect(
        rarityFeedPlan(short, short.bugs.first, pet, byId, toNext: true),
        isEmpty,
      );
    });

    test('높은 희귀도 하나가 지름길이 되지 않는다(2배씩) · 채우는 양은 문턱을 넘지 않는다', () {
      // 영웅 하나 = 전설 문턱의 약 3%(사장님 확정 — "영웅이 나오면 전설이 쉬워진다").
      expect(
        cfg.feedOfRarity(Grade.epic) / cfg.worthOfRarity(Grade.legendary),
        lessThan(0.05),
      );
      // 서버 검사가 총량 보존에 기대는 불변식.
      for (final g in Grade.values) {
        expect(cfg.feedOfRarity(g), lessThanOrEqualTo(cfg.worthOfRarity(g)));
      }
    });

    test('전설에 닿으면 게이지는 0 · 전설은 더 먹이지 않는다', () {
      // 영웅 t(문턱 256) + 모은 양분 760 + 영웅 하나(32) = 1,048 → 전설.
      final s = save([
        bug('t', r: Grade.epic).copyWith(rarityWorth: 760),
        bug('e0', r: Grade.epic),
        bug('c'),
      ]);
      final r = rarityFeed(s, 't', ['e0'], pet, byId);
      final t = r.save!.bugs.firstWhere((b) => b.id == 't');
      expect(t.rarity, Grade.legendary);
      expect(t.rarityWorth, 0);
      // 전설이어도 더 먹일 수 있다(정수 흡수, 2026-11-09) — 희귀도 양분은 0 그대로, 등급 양분만 쌓인다.
      final more = rarityFeed(r.save!, 't', ['c'], pet, byId);
      expect(more.isOk, isTrue);
      final t2 = more.save!.bugs.single;
      expect(t2.rarity, Grade.legendary);
      expect(t2.rarityWorth, 0);
      expect(t2.gradeWorth, greaterThan(t.gradeWorth));
    });

    test('게이지는 세이브를 오가도 같다 · 0 이면 싣지 않는다', () {
      final b = bug('t').copyWith(rarityWorth: 12);
      expect(IndividualBug.fromJson(b.toJson()).rarityWorth, 12);
      expect(bug('t').toJson().containsKey('rw'), isFalse);
    });

    test('서버 풀: 같은 종 사라진 가치만큼만 · 넘친 몫은 같은 종 다음 곤충에 · 모자라면 안 건드린다', () {
      final pool = <String, List<({String id, int worth})>>{
        'stag_saw': [(id: 'a', worth: 16), (id: 'b', worth: 16)],
      };
      final used = <String>{};
      expect(
        takeRarityWorth(
          speciesId: 'stag_saw',
          gain: 20,
          pool: pool,
          used: used,
        ),
        isTrue,
      );
      expect(used, {'a', 'b'});
      // 남은 12 로 다음 곤충 12 까지.
      expect(
        takeRarityWorth(speciesId: 'stag_saw', gain: 13, pool: pool),
        isFalse,
      );
      expect(
        takeRarityWorth(speciesId: 'stag_saw', gain: 12, pool: pool),
        isTrue,
      );
      expect(takeRarityWorth(speciesId: 'other', gain: 1, pool: pool), isFalse);
    });
  });

  // 정수를 먹이기에 흡수(2026-11-09 사장님 확정) — 먹이면 등급 양분도 차고, 등급 올리기·재굴림은 옛 정수를 먼저 쓴다.
  group('등급 양분(정수 흡수)', () {
    final grade = pet.individualGrade;

    test('먹이면 재료의 정수 가치만큼 등급 양분이 쌓인다', () {
      final s = save([bug('t', level: 5), bug('c1'), bug('c2'), bug('c3')]);
      final r = rarityFeed(s, 't', ['c1', 'c2', 'c3'], pet, byId);
      final want = [
        for (final id in ['c1', 'c2', 'c3'])
          grade.essenceOf(
            s.bugs.firstWhere((b) => b.id == id),
            pet.rarityOf(s.bugs.firstWhere((b) => b.id == id), sp),
          ),
      ].fold(0, (a, v) => a + v);
      expect(want, greaterThan(0));
      expect(r.save!.bugs.single.gradeWorth, want);
      expect(r.extra['grade'], want);
    });

    test('등급 올리기는 옛 정수를 먼저, 모자라면 등급 양분에서 낸다 · 둘 다 모자라면 실패', () {
      final cost = grade.upgradeCost(1);
      final t = bug('t').copyWith(gradeWorth: cost);
      final s = save([t]).copyWith(essence: {sp.id: 1});
      final r = gradeUp(s, 't', grade, byId, Random(1));
      expect(r.isOk, isTrue);
      expect(r.save!.essence.containsKey(sp.id), isFalse); // 옛 정수 1 을 먼저
      expect(r.save!.bugs.single.gradeWorth, 1); // 나머지 cost - 1 은 등급 양분에서
      expect(r.save!.bugs.single.potential, 2);
      final poor = save([bug('t').copyWith(gradeWorth: cost - 1)]);
      expect(gradeUp(poor, 't', grade, byId, Random(1)).error, 'no_essence');
    });

    test('패시브 재굴림도 옛 정수 → 등급 양분 순서로 낸다', () {
      final p2 = pet.passiveV2;
      if (!p2.enabled || p2.rerollEssence <= 0) return;
      final s = save([bug('t').copyWith(gradeWorth: p2.rerollEssence)]);
      final r = rollPassiveReroll(s, p2, 't', Random(1), useJelly: false);
      expect(r.isOk, isTrue);
      expect(r.save!.bugs.single.gradeWorth, 0);
    });

    test('등급 양분은 세이브를 오가도 같다 · 0 이면 싣지 않는다', () {
      final b = bug('t').copyWith(gradeWorth: 7);
      expect(IndividualBug.fromJson(b.toJson()).gradeWorth, 7);
      expect(bug('t').toJson().containsKey('gw'), isFalse);
    });
  });
}

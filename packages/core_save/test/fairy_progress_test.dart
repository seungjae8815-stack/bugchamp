import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:core_save/core_save.dart';
import 'package:test/test.dart';

/// 실제 게임 데이터(fairies.json)로 돈다 — 수치를 바꾸면 규칙이 여기서 먼저 깨진다.
FairyConfig _cfg() => FairyConfig.fromJson(
  jsonDecode(File('../app/assets/data/fairies.json').readAsStringSync())
      as Map<String, dynamic>,
);

final _t = DateTime.utc(2026, 10, 1, 12);

void main() {
  final cfg = _cfg();
  final kind = cfg.kinds.first.id;
  final subs = cfg.subWeight.keys.toList();
  final sub = subs.first;

  FairyState withFairies(List<Fairy> fs) =>
      FairyState(fairies: fs, seq: fs.length);
  Fairy f(
    int n, {
    FairyGrade g = FairyGrade.common,
    String? k,
    String? b,
    int lv = 1,
  }) => Fairy(id: 'f$n', kind: k ?? kind, grade: g, sub: b ?? sub, level: lv);

  group('데이터 검사', () {
    test('기본·부가 능력치·스킬 효과 키는 모두 아는 키(오타는 조용히 사라진다)', () {
      for (final k in cfg.kinds) {
        for (final key in k.stats.keys) {
          expect(kFairyStatKeys, contains(key), reason: '${k.id}.$key');
        }
        expect(kFairySkillEffects, contains(k.skill.effect), reason: k.id);
      }
      expect(subs, isNotEmpty);
      for (final key in subs) {
        expect(kFairyStatKeys, contains(key), reason: 'subWeight.$key');
      }
    });

    test('종류는 8가지 · id 는 겹치지 않는다 · 이름·칭호가 3개 언어 모두 있다', () {
      final ids = cfg.kinds.map((k) => k.id).toList();
      expect(ids.length, 8);
      expect(ids.toSet().length, ids.length);
      for (final k in cfg.kinds) {
        for (final t in [k.name, k.title]) {
          expect(t.ko, isNotEmpty, reason: k.id);
          expect(t.en, isNotEmpty, reason: k.id);
          expect(t.ja, isNotEmpty, reason: k.id);
        }
      }
    });

    test('젤리 소비 금액은 5·10 단위(§2.6)', () {
      final prices = [
        cfg.gachaJelly,
        cfg.stoneJelly,
        for (final a in cfg.accelerators) a.jelly,
      ];
      for (final p in prices) {
        expect(p, roundJellyCost(p), reason: '$p');
      }
    });

    test('모든 등급에 레벨 상한·부화 시간·분해 가루·능력치가 있다', () {
      for (final g in FairyGrade.values) {
        expect(cfg.maxLevel[g], isNotNull, reason: g.key);
        expect(cfg.hatchSec[g], isNotNull, reason: g.key);
        expect(cfg.releaseDust[g], isNotNull, reason: g.key);
        expect(cfg.gradeStatMin[g], isNotNull, reason: g.key);
        expect(cfg.gradeStatMax[g], greaterThan(cfg.gradeStatMin[g]!));
      }
    });

    test('등급이 오를수록 최소·최대가 모두 커진다(등급마다 최대치가 다르다)', () {
      for (var i = 1; i < FairyGrade.values.length; i++) {
        final lo = FairyGrade.values[i - 1];
        final hi = FairyGrade.values[i];
        expect(cfg.gradeStatMax[hi], greaterThan(cfg.gradeStatMax[lo]!));
        expect(cfg.gradeStatMin[hi], greaterThan(cfg.gradeStatMin[lo]!));
        // 한 등급 위의 가장 약한 개체가 아래 등급의 가장 센 개체보다 약하지 않다.
        expect(
          cfg.gradeStatMin[hi],
          greaterThanOrEqualTo(cfg.gradeStatMax[lo]!),
        );
      }
    });

    test('신화는 뽑기로 나오지 않는다(합성으로만)', () {
      expect(cfg.gachaWeights[FairyGrade.mythic] ?? 0, 0);
    });
  });

  group('부가 능력치', () {
    test('기본 능력치에 부가 능력치가 하나 더 붙는다', () {
      final def = cfg.byId(kind)!;
      final other = subs.firstWhere((k) => !def.stats.containsKey(k));
      final bonus = cfg.statBonus(f(1, b: other));
      expect(bonus.keys, containsAll([...def.stats.keys, other]));
      final base = cfg.statAt(FairyGrade.common, 0);
      expect(
        bonus[other],
        closeTo(base * cfg.subRatio * cfg.subWeight[other]!, 1e-12),
      );
    });

    test('부가가 기본 능력치와 같으면 두 겹으로 더해진다', () {
      final def = cfg.byId(kind)!;
      final main = def.stats.keys.firstWhere(subs.contains);
      final plain = cfg.statBonus(f(1, b: subs.firstWhere((k) => k != main)));
      final doubled = cfg.statBonus(f(1, b: main));
      expect(doubled[main], greaterThan(plain[main]!));
    });

    test('모르는 부가는 무시(기본 능력치만)', () {
      final bonus = cfg.statBonus(f(1, b: 'nope'));
      expect(bonus.keys, cfg.byId(kind)!.stats.keys);
    });
  });

  group('개체값', () {
    test('개체값 0 = 등급 최소 · 최대 = 등급 최대', () {
      for (final g in FairyGrade.values) {
        expect(cfg.statAt(g, 0), cfg.gradeStatMin[g]);
        expect(
          cfg.statAt(g, kFairyRollMax),
          closeTo(cfg.gradeStatMax[g]!, 1e-12),
        );
      }
    });

    test('같은 등급·종류라도 개체값이 다르면 세기가 다르다', () {
      final weak = cfg.statBonus(
        Fairy(id: 'a', kind: kind, grade: FairyGrade.epic, sub: sub),
      );
      final strong = cfg.statBonus(
        Fairy(
          id: 'b',
          kind: kind,
          grade: FairyGrade.epic,
          sub: sub,
          baseRoll: kFairyRollMax,
          subRoll: kFairyRollMax,
        ),
      );
      for (final k in weak.keys) {
        expect(strong[k], greaterThan(weak[k]!), reason: k);
      }
    });

    test('최대치 근처는 드물다(rollSkew)', () {
      final rng = Random(11);
      const n = 20000;
      var top = 0;
      var sum = 0;
      for (var i = 0; i < n; i++) {
        final r = cfg.rollQuality(rng);
        expect(r, inInclusiveRange(0, kFairyRollMax));
        if (r >= 900) top++;
        sum += r;
      }
      expect(top / n, lessThan(0.1), reason: '균등이면 10%');
      expect(sum / n / kFairyRollMax, lessThan(0.5), reason: '평균은 가운데보다 아래');
    });

    test('부화한 요정은 둥지에 적힌 개체값을 그대로 받는다', () {
      var s = grantFairyEggs(FairyState.empty, cfg, [FairyGrade.rare]).state!;
      s = placeFairyEgg(
        s,
        cfg,
        Random(4),
        eggId: s.eggs.single.id,
        now: _t,
      ).state!;
      final n = s.nest!;
      final got = collectFairyNest(s, now: n.endsAt).extra['fairy']! as Fairy;
      expect(got.baseRoll, n.baseRoll);
      expect(got.subRoll, n.subRoll);
    });

    test('합성 결과는 새로 굴린다 — 같은 seed 면 같고, seed 가 다르면 갈린다', () {
      Fairy q(int n) => Fairy(
        id: 'f$n',
        kind: kind,
        grade: FairyGrade.common,
        sub: sub,
        baseRoll: 1000,
        subRoll: 1000,
      );
      final s = withFairies([q(1), q(2), q(3)]);
      Fairy made(int seed) =>
          mergeFairies(s, cfg, ['f1', 'f2', 'f3'], Random(seed)).extra['fairy']!
              as Fairy;
      expect(made(5), made(5));
      final outs = {
        for (var seed = 0; seed < 40; seed++)
          (made(seed).sub, made(seed).baseRoll, made(seed).subRoll),
      };
      expect(outs.length, greaterThan(30), reason: '재료 개체값을 이어받지 않는다');
      for (var seed = 0; seed < 40; seed++) {
        final m = made(seed);
        expect(m.kind, kind, reason: '종류는 재료와 같다');
        expect(subs, contains(m.sub));
        expect(m.baseRoll, inInclusiveRange(0, kFairyRollMax));
      }
    });

    test('자동 합성은 품질 낮은 것부터 태운다(좋은 개체가 남는다)', () {
      Fairy q(int n, int roll) => Fairy(
        id: 'f$n',
        kind: kind,
        grade: FairyGrade.common,
        sub: sub,
        baseRoll: roll,
        subRoll: roll,
      );
      final s = withFairies([q(1, 10), q(2, 800), q(3, 20), q(4, 30)]);
      final out = autoMergeFairies(s, cfg, Random(1)).state!;
      expect(out.fairies.map((x) => x.id), contains('f2'));
      expect(out.fairies.length, 2);
    });
  });

  group('알 · 둥지', () {
    test('알을 넣고 시간이 지나면 레벨 1 요정 · 도감 두 축 기록', () {
      var s = grantFairyEggs(FairyState.empty, cfg, [FairyGrade.rare]).state!;
      final eggId = s.eggs.single.id;
      s = placeFairyEgg(s, cfg, Random(1), eggId: eggId, now: _t).state!;
      expect(s.eggs, isEmpty);
      expect(s.nest!.endsAt, _t.add(cfg.hatchDuration(FairyGrade.rare)));
      expect(subs, contains(s.nest!.sub));

      expect(collectFairyNest(s, now: _t).error, 'not_ready');
      final op = collectFairyNest(s, now: s.nest!.endsAt);
      final got = op.extra['fairy']! as Fairy;
      expect(got.grade, FairyGrade.rare);
      expect(got.level, 1);
      expect(got.sub, s.nest!.sub);
      expect(op.state!.nest, isNull);
      expect(
        op.state!.dex,
        containsAll([
          FairyState.dexKey(got.kind, got.grade),
          FairyState.dexSubKey(got.kind, got.sub),
        ]),
      );
    });

    test('둥지는 1칸 — 차 있으면 못 넣는다', () {
      var s = grantFairyEggs(FairyState.empty, cfg, [
        FairyGrade.common,
        FairyGrade.common,
      ]).state!;
      s = placeFairyEgg(s, cfg, Random(1), eggId: s.eggs[0].id, now: _t).state!;
      expect(
        placeFairyEgg(s, cfg, Random(1), eggId: s.eggs[0].id, now: _t).error,
        'nest_busy',
      );
    });

    test('종류·부가는 넣을 때 정해진다 — 같은 seed 면 같은 결과(결정론)', () {
      final s = grantFairyEggs(FairyState.empty, cfg, [
        FairyGrade.common,
      ]).state!;
      final id = s.eggs.single.id;
      final a = placeFairyEgg(s, cfg, Random(7), eggId: id, now: _t).state!;
      final b = placeFairyEgg(s, cfg, Random(7), eggId: id, now: _t).state!;
      expect(a.nest, b.nest);
    });

    test('종류는 8가지가 고르게 나온다', () {
      final rng = Random(5);
      final seen = <String, int>{};
      const n = 8000;
      for (var i = 0; i < n; i++) {
        final k = cfg.rollKind(rng);
        seen[k] = (seen[k] ?? 0) + 1;
      }
      expect(seen.length, cfg.kinds.length);
      for (final c in seen.values) {
        expect(c / n, closeTo(1 / cfg.kinds.length, 0.02));
      }
    });

    test('요정함이 차면 넘친 알은 가루로', () {
      final full = FairyState(
        fairies: [for (var i = 0; i < cfg.boxCap; i++) f(i)],
        seq: cfg.boxCap,
      );
      final op = grantFairyEggs(full, cfg, [FairyGrade.epic]);
      expect(op.state!.eggs, isEmpty);
      expect(op.state!.dust, cfg.releaseDust[FairyGrade.epic]);
      expect(op.extra['overflowDust'], cfg.releaseDust[FairyGrade.epic]);
    });
  });

  group('속성석', () {
    test('속성석을 넣으면 그 부가 능력치 확률이 stoneChance 근처', () {
      final target = subs.last;
      var hit = 0;
      const n = 4000;
      final rng = Random(42);
      for (var i = 0; i < n; i++) {
        if (cfg.rollSub(rng, stoneSub: target) == target) hit++;
      }
      expect(hit / n, closeTo(cfg.stoneChance, 0.03));
    });

    test('속성석 없이는 부가가 고르게 나온다', () {
      final rng = Random(9);
      var hit = 0;
      const n = 7000;
      for (var i = 0; i < n; i++) {
        if (cfg.rollSub(rng) == sub) hit++;
      }
      expect(hit / n, closeTo(1 / subs.length, 0.02));
    });

    test('속성석이 없으면 못 쓰고, 쓰면 1개 줄어든다 · 모르는 부가는 거부', () {
      var s = grantFairyEggs(FairyState.empty, cfg, [FairyGrade.common]).state!;
      final id = s.eggs.single.id;
      expect(
        placeFairyEgg(
          s,
          cfg,
          Random(1),
          eggId: id,
          now: _t,
          stoneSub: sub,
        ).error,
        'no_stone',
      );
      expect(
        placeFairyEgg(
          s,
          cfg,
          Random(1),
          eggId: id,
          now: _t,
          stoneSub: 'nope',
        ).error,
        'bad_sub',
      );
      s = grantFairyItems(s, stones: {sub: 2});
      s = placeFairyEgg(
        s,
        cfg,
        Random(1),
        eggId: id,
        now: _t,
        stoneSub: sub,
      ).state!;
      expect(s.stones[sub], 1);
    });

    test('속성석은 젤리로 산다', () {
      final op = buyFairyStone(
        FairyState.empty,
        cfg,
        sub: sub,
        count: 2,
        jellyHave: 1000,
      );
      expect(op.jelly, cfg.stoneJelly * 2);
      expect(op.state!.stones[sub], 2);
      expect(
        buyFairyStone(
          FairyState.empty,
          cfg,
          sub: sub,
          count: 1,
          jellyHave: 0,
        ).error,
        'not_enough_jelly',
      );
    });
  });

  group('가속기', () {
    final acc = cfg.accelerators.first;

    FairyState nested() {
      final s = grantFairyEggs(FairyState.empty, cfg, [
        FairyGrade.legendary,
      ]).state!;
      return placeFairyEgg(
        s,
        cfg,
        Random(1),
        eggId: s.eggs.single.id,
        now: _t,
      ).state!;
    }

    test('사서 쓰면 남은 시간이 줄어든다', () {
      var s = nested();
      final before = s.nest!.endsAt;
      final buy = buyFairyAccelerator(
        s,
        cfg,
        accelId: acc.id,
        count: 1,
        jellyHave: 999,
      );
      expect(buy.jelly, acc.jelly);
      s = useFairyAccelerator(buy.state!, cfg, accelId: acc.id, now: _t).state!;
      expect(s.nest!.endsAt, before.subtract(Duration(minutes: acc.minutes)));
      expect(s.accelerators[acc.id], isNull);
    });

    test('남은 시간보다 크게 줄여도 지금 시각 아래로는 안 간다', () {
      final big = cfg.accelerators.last;
      var s = grantFairyItems(nested(), accelerators: {big.id: 99});
      final late = s.nest!.endsAt.subtract(const Duration(minutes: 1));
      s = useFairyAccelerator(s, cfg, accelId: big.id, now: late).state!;
      expect(s.nest!.endsAt, late);
      expect(collectFairyNest(s, now: late).isOk, isTrue);
    });

    test('가속기가 없거나 둥지가 비면 실패', () {
      expect(
        useFairyAccelerator(nested(), cfg, accelId: acc.id, now: _t).error,
        'no_accel',
      );
      expect(
        useFairyAccelerator(
          FairyState.empty,
          cfg,
          accelId: acc.id,
          now: _t,
        ).error,
        'nest_empty',
      );
    });
  });

  group('합성', () {
    test('같은 종류·등급 3마리 → 같은 종류 한 등급 위 · 레벨 1 · 가루 일부 환급', () {
      final s = withFairies([f(1, b: subs[1]), f(2), f(3, lv: 3)]);
      final op = mergeFairies(s, cfg, ['f1', 'f2', 'f3'], Random(1));
      final made = op.extra['fairy']! as Fairy;
      expect(made.grade, FairyGrade.rare);
      expect(made.kind, kind);
      expect(made.level, 1);
      expect(op.state!.fairies, [made]);
      final spent = cfg.dustSpentTo(FairyGrade.common, 3);
      expect(op.state!.dust, (spent * cfg.mergeDustRefund).floor());
      expect(op.state!.dex, contains(FairyState.dexKey(kind, FairyGrade.rare)));
    });

    test('부가가 달라도 종류·등급이 같으면 합성된다', () {
      final s = withFairies([
        f(1, b: subs[0]),
        f(2, b: subs[1]),
        f(3, b: subs[2]),
      ]);
      expect(mergeFairies(s, cfg, ['f1', 'f2', 'f3'], Random(1)).isOk, isTrue);
    });

    test('종류나 등급이 다르면 · 동행 중이면 · 신화면 실패', () {
      final other = cfg.kinds[1].id;
      expect(
        mergeFairies(withFairies([f(1), f(2), f(3, k: other)]), cfg, [
          'f1',
          'f2',
          'f3',
        ], Random(1)).error,
        'mismatch',
      );
      final withComp = withFairies([
        f(1),
        f(2),
        f(3),
      ]).copyWith(companionId: 'f1');
      expect(
        mergeFairies(withComp, cfg, ['f1', 'f2', 'f3'], Random(1)).error,
        'companion',
      );
      final myth = withFairies([
        for (var i = 1; i <= 3; i++) f(i, g: FairyGrade.mythic),
      ]);
      expect(
        mergeFairies(myth, cfg, ['f1', 'f2', 'f3'], Random(1)).error,
        'max_grade',
      );
    });

    test('자동 합성은 연쇄로 끝까지 · 투자한 요정·동행은 재료에서 뺀다', () {
      // 일반 9마리 → 희귀 3 → 영웅 1. 레벨 2 요정과 동행 요정은 남는다.
      final s = withFairies([
        for (var i = 1; i <= 9; i++) f(i),
        f(10, lv: 2),
        f(11),
      ]).copyWith(companionId: 'f11');
      final dry = autoMergeFairies(s, cfg, Random(1), dryRun: true);
      expect(dry.state, s, reason: 'dryRun 은 상태를 바꾸지 않는다');
      final made = dry.extra['made']! as List<Fairy>;
      expect(made.map((x) => x.grade), [FairyGrade.epic]);
      expect(dry.extra['used'], 9, reason: '원래 있던 일반 9마리(연쇄 중간 희귀 3은 빼고)');

      final run = autoMergeFairies(s, cfg, Random(1)).state!;
      expect(run.fairies.map((x) => x.id), containsAll(['f10', 'f11']));
      expect(run.fairies.length, 3);
    });

    test('자동 합성은 부가가 달라도 종류·등급이 같으면 합친다(결과는 새로 굴린다)', () {
      final s = withFairies([
        f(1, b: subs[0]),
        f(2, b: subs[1]),
        f(3, b: subs[2]),
      ]);
      final op = autoMergeFairies(s, cfg, Random(1));
      expect(op.extra['used'], 3);
      expect(op.state!.fairies.single.grade, FairyGrade.rare);
    });
  });

  group('레벨 · 분해 · 동행', () {
    test('가루로 레벨업 · 상한에서 멈춘다', () {
      final max = cfg.maxLevelOf(FairyGrade.common);
      var s = withFairies([f(1)]).copyWith(dust: 1 << 30);
      for (var i = 1; i < max; i++) {
        s = levelUpFairy(s, cfg, 'f1').state!;
      }
      expect(s.fairyById('f1')!.level, max);
      expect(levelUpFairy(s, cfg, 'f1').error, 'max_level');
      expect(
        levelUpFairy(withFairies([f(1)]), cfg, 'f1').error,
        'not_enough_dust',
      );
    });

    test('레벨이 오르면 기본·부가 능력치가 함께 오른다', () {
      final a = cfg.statBonus(f(1));
      final b = cfg.statBonus(f(1, lv: 10));
      for (final k in a.keys) {
        expect(b[k], greaterThan(a[k]!), reason: k);
      }
    });

    test('분해는 가루만(젤리 없음) · 동행 중이면 안 된다', () {
      final s = withFairies([f(1, g: FairyGrade.legendary)]);
      final op = releaseFairy(s, cfg, 'f1');
      expect(op.jelly, 0);
      expect(op.state!.dust, cfg.releaseDust[FairyGrade.legendary]);
      expect(
        releaseFairy(s.copyWith(companionId: 'f1'), cfg, 'f1').error,
        'companion',
      );
    });

    test('동행 요정만 능력치를 준다(보유효과 없음)', () {
      final s = withFairies([f(1), f(2, g: FairyGrade.epic)]);
      expect(fairyCompanionBonus(s, cfg), isEmpty);
      final on = setFairyCompanion(s, 'f2').state!;
      expect(
        fairyCompanionBonus(on, cfg),
        cfg.statBonus(f(2, g: FairyGrade.epic)),
      );
      expect(setFairyCompanion(s, 'nope').error, 'no_fairy');
    });
  });

  group('뽑기', () {
    test('천장: 천장 회차째는 전설 이상 확정', () {
      // 천장 직전까지 전설이 안 나왔다고 친다.
      final s = FairyState(gachaPity: cfg.gachaPity - 1);
      for (var seed = 0; seed < 50; seed++) {
        final op = drawFairyEggs(
          s,
          cfg,
          Random(seed),
          times: 1,
          jellyHave: 999,
        );
        final g = (op.extra['grades']! as List<FairyGrade>).single;
        expect(g.index, greaterThanOrEqualTo(cfg.gachaPityGrade.index));
        expect(op.state!.gachaPity, 0);
      }
    });

    test('젤리가 모자라면 실패 · 쓴 젤리를 알려 준다', () {
      expect(
        drawFairyEggs(
          FairyState.empty,
          cfg,
          Random(1),
          times: 10,
          jellyHave: 0,
        ).error,
        'not_enough_jelly',
      );
      final op = drawFairyEggs(
        FairyState.empty,
        cfg,
        Random(1),
        times: 10,
        jellyHave: 9999,
      );
      expect(op.jelly, cfg.gachaJelly * 10);
      expect(op.state!.eggs.length, 10);
    });
  });

  group('상한 정리 · 등급 가치', () {
    // 2026-10-04 사장님 확정(B안): 영웅 → 전설만 4마리.
    test('영웅 → 전설은 4마리 · 3마리면 실패 · 다른 등급은 3마리', () {
      expect(cfg.mergeCountOf(FairyGrade.epic), 4);
      expect(cfg.mergeCountOf(FairyGrade.rare), 3);
      final four = withFairies([
        for (var i = 1; i <= 4; i++) f(i, g: FairyGrade.epic),
      ]);
      expect(
        mergeFairies(four, cfg, ['f1', 'f2', 'f3'], Random(1)).error,
        'bad_count',
      );
      final ok = mergeFairies(four, cfg, ['f1', 'f2', 'f3', 'f4'], Random(1));
      expect(ok.state!.fairies.single.grade, FairyGrade.legendary);
      expect(fairyStateValue(ok.state!), lessThan(fairyStateValue(four)));
    });

    test('자동 합성도 영웅은 4마리씩 — 3마리면 남겨 둔다', () {
      final three = withFairies([
        for (var i = 1; i <= 3; i++) f(i, g: FairyGrade.epic),
      ]);
      expect(
        (autoMergeFairies(three, cfg, Random(1)).extra['made']! as List),
        isEmpty,
      );
      final four = withFairies([
        for (var i = 1; i <= 4; i++) f(i, g: FairyGrade.epic),
      ]);
      final made =
          autoMergeFairies(four, cfg, Random(1)).extra['made']! as List<Fairy>;
      expect(made.single.grade, FairyGrade.legendary);
    });

    // 2026-10-04 사장님 확정(C안): 재굴림 — 대기 결과 → 고르기.
    test('재굴림: 결정론 · 젤리 · 하루 상한 · 대기 중엔 못 굴린다', () {
      final s = withFairies([f(1, g: FairyGrade.legendary)]);
      final a = rollFairyReroll(
        s,
        cfg,
        Random(7),
        fairyId: 'f1',
        today: 'd',
        jellyHave: 999,
      );
      final b = rollFairyReroll(
        s,
        cfg,
        Random(7),
        fairyId: 'f1',
        today: 'd',
        jellyHave: 999,
      );
      expect(a.state!.reroll, b.state!.reroll);
      expect(a.jelly, cfg.rerollJelly);
      expect(
        rollFairyReroll(
          a.state!,
          cfg,
          Random(1),
          fairyId: 'f1',
          today: 'd',
          jellyHave: 999,
        ).error,
        'reroll_pending',
      );
      expect(
        rollFairyReroll(
          s,
          cfg,
          Random(1),
          fairyId: 'f1',
          today: 'd',
          jellyHave: 0,
        ).error,
        'not_enough_jelly',
      );
      final capped = s.copyWith(
        rerollDay: 'd',
        rerollCount: cfg.rerollDailyCap,
      );
      expect(
        rollFairyReroll(
          capped,
          cfg,
          Random(1),
          fairyId: 'f1',
          today: 'd',
          jellyHave: 999,
        ).error,
        'reroll_cap',
      );
      // 날이 바뀌면 다시 쓸 수 있다.
      expect(
        rollFairyReroll(
          capped,
          cfg,
          Random(1),
          fairyId: 'f1',
          today: 'e',
          jellyHave: 999,
        ).isOk,
        isTrue,
      );
    });

    test('재굴림 고르기: 받으면 부가·개체값만 바뀌고(레벨·등급 그대로) 도감에 적힌다', () {
      final s = withFairies([f(1, g: FairyGrade.legendary, lv: 7)]);
      final rolled = rollFairyReroll(
        s,
        cfg,
        Random(3),
        fairyId: 'f1',
        today: 'd',
        jellyHave: 999,
      ).state!;
      final r = rolled.reroll!;
      final take = chooseFairyReroll(rolled, accept: true).state!;
      final x = take.fairyById('f1')!;
      expect(
        [x.sub, x.baseRoll, x.subRoll, x.level, x.grade],
        [r.sub, r.baseRoll, r.subRoll, 7, FairyGrade.legendary],
      );
      expect(take.reroll, isNull);
      expect(take.dex, contains(FairyState.dexSubKey(x.kind, r.sub)));
      final keep = chooseFairyReroll(rolled, accept: false).state!;
      expect(keep.fairyById('f1'), s.fairyById('f1'));
      expect(keep.reroll, isNull);
    });

    test('합성은 등급 가치 합을 바꾸지 않는다(서버 위조 판정의 근거)', () {
      final s = withFairies([
        for (var i = 1; i <= 3; i++) f(i, g: FairyGrade.legendary),
      ]);
      final merged = mergeFairies(s, cfg, ['f1', 'f2', 'f3'], Random(1)).state!;
      expect(fairyStateValue(merged), fairyStateValue(s));
      expect(merged.fairies.single.grade, FairyGrade.mythic);
    });

    test('레벨은 등급 상한으로 자른다', () {
      final s = enforceFairyRules(withFairies([f(1, lv: 999)]), cfg);
      expect(s.fairies.single.level, cfg.maxLevelOf(FairyGrade.common));
    });

    test('요정함을 넘으면 알부터, 그다음 품질 낮은 요정부터 가루로 · 동행은 남긴다', () {
      Fairy q(int n, int roll) => Fairy(
        id: 'f$n',
        kind: kind,
        grade: FairyGrade.common,
        sub: sub,
        baseRoll: roll,
        subRoll: roll,
      );
      final s =
          FairyState(
            fairies: [for (var i = 0; i < cfg.boxCap; i++) q(i, 500 + i)],
            eggs: const [FairyEgg(id: 'e1', grade: FairyGrade.rare)],
            companionId: 'f0', // 품질이 가장 낮지만 동행이라 남는다.
            seq: cfg.boxCap + 1,
          ).copyWith(
            fairies: [
              for (var i = 0; i < cfg.boxCap; i++) q(i, 500 + i),
              q(900, 999),
            ],
          );
      final out = enforceFairyRules(s, cfg);
      expect(out.boxUsed, cfg.boxCap);
      expect(out.eggs, isEmpty);
      expect(out.fairies.map((x) => x.id), contains('f0'));
      expect(out.fairies.map((x) => x.id), isNot(contains('f1')));
      expect(out.fairies.map((x) => x.id), contains('f900'));
      expect(
        out.dust,
        cfg.releaseDust[FairyGrade.rare]! + cfg.releaseDust[FairyGrade.common]!,
      );
    });

    test('상한 안이면 그대로', () {
      final s = withFairies([f(1), f(2)]);
      expect(enforceFairyRules(s, cfg), s);
    });
  });

  group('세이브(SaveGame.fairy)', () {
    test('세이브 왕복 · feat 15', () {
      final fs = withFairies([
        f(1, lv: 3),
      ]).copyWith(companionId: 'f1', dust: 7);
      final save = SaveGame.initial(createdAt: _t).copyWith(fairy: fs);
      final j = jsonDecode(jsonEncode(save.toJson())) as Map<String, dynamic>;
      expect(j['feat'], greaterThanOrEqualTo(15), reason: '요정은 feat 15 부터');
      expect(SaveGame.fromJson(j).fairy, fs);
    });

    test('요정이 없으면 키를 싣지 않는다 · 키가 없는 옛 세이브는 빈 요정', () {
      final save = SaveGame.initial(createdAt: _t);
      final j = save.toJson();
      expect(j.containsKey('fairy'), isFalse);
      expect(SaveGame.fromJson(j).fairy, FairyState.empty);
    });

    test('깨진 요정 칸이 있어도 세이브 전체는 읽힌다', () {
      final j = SaveGame.initial(createdAt: _t).toJson()
        ..['fairy'] = {
          'f': ['x', 42],
          'd': 'bad',
        };
      expect(() => SaveGame.fromJson(j), returnsNormally);
    });
  });

  group('무료 획득(§2.8)', () {
    test('보스 첫 처치 = 난이도별 알 1개 확정 + 속성석 · 다시 잡으면 없음', () {
      for (var tier = 0; tier < 4; tier++) {
        final op = fairyBossDrop(
          FairyState.empty,
          cfg,
          Random(tier),
          tier: tier,
          firstKill: true,
        );
        expect(op.state!.eggs.single.grade, cfg.drops.bossFirstEggGrade(tier));
        expect(
          op.state!.stones.values.fold<int>(0, (a, b) => a + b),
          cfg.drops.bossFirstStones,
        );
      }
      final again = fairyBossDrop(
        FairyState.empty,
        cfg,
        Random(1),
        tier: 3,
        firstKill: false,
      );
      expect(again.state, FairyState.empty);
    });

    test('정예 드롭 확률이 설정 근처 · 알 등급은 전설 이상이 없다', () {
      final rng = Random(77);
      const n = 20000;
      var eggs = 0;
      var stones = 0;
      var accel = 0;
      for (var i = 0; i < n; i++) {
        final op = fairyEliteDrop(FairyState.empty, cfg, rng);
        final e = op.extra['eggs']! as List<FairyGrade>;
        eggs += e.length;
        for (final g in e) {
          expect(g.index, lessThan(FairyGrade.legendary.index));
        }
        if ((op.extra['stones'] as Map?)?.isNotEmpty ?? false) stones++;
        if (op.extra['accel'] != null) accel++;
      }
      expect(eggs / n, closeTo(cfg.drops.eliteEggChance, 0.005));
      expect(stones / n, closeTo(cfg.drops.eliteStoneChance, 0.004));
      expect(accel / n, closeTo(cfg.drops.eliteAccelChance, 0.005));
    });

    test('정예 알은 뽑기보다 나쁘다(돈을 내면 확률이 좋아져야 한다, §2.6)', () {
      double epicUp(Map<FairyGrade, double> w) {
        final total = w.values.fold<double>(0, (a, b) => a + b);
        final hi = w.entries
            .where((e) => e.key.index >= FairyGrade.epic.index)
            .fold<double>(0, (a, e) => a + e.value);
        return hi / total;
      }

      expect(
        epicUp(cfg.drops.eliteEggWeights),
        lessThan(epicUp(cfg.gachaWeights)),
      );
    });

    test('요정함이 가득이면 보스 알도 가루로(버리지 않는다)', () {
      final full = FairyState(
        fairies: [for (var i = 0; i < cfg.boxCap; i++) f(i)],
        seq: cfg.boxCap,
      );
      final op = fairyBossDrop(full, cfg, Random(1), tier: 3, firstKill: true);
      expect(op.state!.eggs, isEmpty);
      expect(op.state!.dust, greaterThan(0));
    });
  });

  group('저장', () {
    test('JSON 왕복', () {
      var s = grantFairyEggs(FairyState.empty, cfg, [
        FairyGrade.rare,
        FairyGrade.epic,
      ]).state!;
      s = placeFairyEgg(
        s,
        cfg,
        Random(3),
        eggId: s.eggs.first.id,
        now: _t,
      ).state!;
      s = grantFairyItems(
        s.copyWith(
          fairies: [f(90, lv: 4, b: subs.last)],
          companionId: 'f90',
          dex: {'$kind:common', '$kind+$sub'},
          gachaPity: 3,
        ),
        stones: {sub: 2},
        accelerators: {'acc2h': 1},
        dust: 55,
      );
      final back = FairyState.fromJson(
        jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>,
      );
      expect(back, s);
    });

    test('비어 있으면 아무 키도 안 쓴다(세이브 크기)', () {
      expect(FairyState.empty.toJson(), isEmpty);
      expect(FairyState.fromJson(null), FairyState.empty);
    });

    test('모르는 등급·깨진 칸은 건너뛰고 · 없는 요정을 가리키는 동행은 버린다', () {
      final s = FairyState.fromJson({
        'f': [
          {'i': 'f1', 'k': 'ignis', 'g': 'common', 'b': 'attack', 'l': 2},
          {'i': 'f2', 'k': 'ignis', 'g': 'cosmic', 'b': 'attack'},
          {'i': 'f3', 'k': 'ignis', 'g': 'common'},
          'garbage',
        ],
        'e': [
          {'i': 'e1', 'g': 'nope'},
        ],
        'n': {'i': 'e9', 'g': 'rare', 'k': 'ignis'},
        'c': 'f2',
        's': {'attack': -3, 'hp': 2},
      });
      expect(s.fairies.map((x) => x.id), ['f1']);
      expect(s.eggs, isEmpty);
      expect(s.nest, isNull);
      expect(s.companionId, isNull);
      expect(s.stones, {'hp': 2});
    });
  });
}

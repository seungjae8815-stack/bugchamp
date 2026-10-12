import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:core_battle/core_battle.dart';
import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:core_save/core_save.dart';
import 'package:server/src/actions.dart';
import 'package:server/src/game_config.dart';
import 'package:test/test.dart';

/// 개체 등급(2026-10-11 · feat 24) 업로드 — 구버전 보존 · 롤 정리 · 정수·물약 급증 · 곤충 등급 필드 위조.
final t0 = DateTime.utc(2026, 10, 11, 12);

void main() {
  late GameActions off;
  late GameActions on;
  late IndividualGradeConfig g;

  setUpAll(() async {
    // pets.json 은 켜진 채(1.0.20 출시값) — 끈 설정은 데이터 폴더 사본에서 enabled 만 끈다.
    on = GameActions(
      config: await GameConfig.load(dir: '../app/assets/data'),
      now: () => t0,
    );
    g = on.config.pet.individualGrade;
    final tmp = Directory.systemTemp.createTempSync('grade_upload');
    for (final f in Directory(
      '../app/assets/data',
    ).listSync().whereType<File>()) {
      f.copySync('${tmp.path}/${f.uri.pathSegments.last}');
    }
    final pf = File('${tmp.path}/pets.json');
    final pets = jsonDecode(pf.readAsStringSync()) as Map<String, dynamic>;
    (pets['individualGrade'] as Map<String, dynamic>)['enabled'] = false;
    pf.writeAsStringSync(jsonEncode(pets));
    off = GameActions(
      config: await GameConfig.load(dir: tmp.path),
      now: () => t0,
    );
  });

  test('실데이터 — 1.0.20 은 켠 채 출시한다', () {
    expect(g.enabled, isTrue);
    expect(off.config.pet.individualGrade.enabled, isFalse);
  });

  IndividualBug bug(
    String id, {
    int su = 0,
    int? pot,
    List<int>? rolls,
    bool gc = false,
    bool ng = true,
    int? ls,
    LifeStage stage = LifeStage.adult,
    String sp = 'stag_dorcus',
  }) => IndividualBug(
    id: id,
    speciesId: sp,
    sizeMm: 40,
    potential: pot ?? 1 + su,
    temperament: Temperament.cunning,
    sex: Sex.male,
    stage: stage,
    synthUps: su,
    rolls: rolls,
    fromGacha: gc,
    newGen: ng,
    legacySynthUps: ls,
  );

  SaveGame stored(List<IndividualBug> bugs) => SaveGame.initial(
    createdAt: t0,
  ).copyWith(lastSeen: t0.subtract(const Duration(seconds: 60)), bugs: bugs);

  Map<String, Species> byId(GameActions a) => {
    for (final s in a.config.speciesList) s.id: s,
  };

  Grade rarity(String sp) =>
      on.config.speciesList.firstWhere((x) => x.id == sp).grade;

  test('구버전 앱(feat 23)이 올려도 정수·물약·롤·뽑기 출신·표식·옛 합성 단계·전설 천장을 지킨다', () {
    const good = [90, 90, 90, 90, 90, 90, 90, 90];
    final s =
        stored([
          bug('a', su: 1, rolls: good, gc: true),
          bug('b', su: 2, ng: false, ls: 1),
        ]).copyWith(
          essence: {'stag_dorcus': 40},
          growthPotions: 7,
          gachaLegendPity: 12,
        );
    final j = s.toJson()
      ..['feat'] = 23
      ..remove('essence')
      ..remove('potions')
      ..remove('gLp');
    j['bugs'] = [
      for (final b in j['bugs'] as List)
        (Map<String, dynamic>.from(b as Map)
          ..remove('rl')
          ..remove('gc')
          ..remove('ng')
          ..remove('ls')),
    ];
    final out = off.mergeSave(s, j).save!;
    expect(out.essence, {'stag_dorcus': 40});
    expect(out.growthPotions, 7);
    expect(out.gachaLegendPity, 12);
    expect(out.bugs.first.rolls, good);
    expect(out.bugs.first.fromGacha, isTrue);
    expect(out.bugs.first.newGen, isTrue);
    expect(out.bugs.last.newGen, isFalse);
    expect(out.bugs.last.legacySynthUps, 1);
  });

  test('등급 올리기를 안 한 곤충(합성 0)의 롤은 처음 롤로 되돌린다(위조 차단)', () {
    final s = stored([bug('a')]);
    final j = stored([
      bug('a', rolls: const [100, 100, 100, 100, 100, 100, 100, 100]),
    ]).toJson();
    final out = off.mergeSave(s, j).save!;
    expect(out.bugs.first.rolls, isNull);
  });

  group('정수', () {
    test('사라진 곤충 가치만큼만 늘 수 있다', () {
      final s = stored([bug('a'), bug('b')]);
      // 근거 없이 1,000 — 저장본(0) + 사라진 곤충 없음 = 0 으로 자른다.
      final fake = s.copyWith(essence: {'stag_dorcus': 1000}).toJson();
      expect(on.mergeSave(s, fake).save!.essence['stag_dorcus'] ?? 0, 0);
      // a 를 정수로 바꿨다 — 일반 1마리 = 1 × 희귀도.
      final v = g.essenceOf(bug('a'), rarity('stag_dorcus'));
      final ok = s
          .copyWith(bugs: [bug('b')], essence: {'stag_dorcus': v})
          .toJson();
      final r = on.mergeSave(s, ok);
      expect(r.save!.essence['stag_dorcus'], v);
      expect(r.extra['clamped'], isFalse);
    });

    test('A — 저장본에 알로 있던 곤충을 부화 → 바로 정수로 바꿔도 정수가 남는다(곤충·정수 둘 다 잃던 버그)', () {
      for (final sp in ['stag_dorcus', 'longhorn_relict']) {
        final egg = bug('e', pot: 3, stage: LifeStage.egg, sp: sp);
        final s = stored([egg, bug('keep')]);
        final v = g.essenceOf(egg.copyWith(stage: LifeStage.larva), rarity(sp));
        expect(v, greaterThan(0));
        final up = s.copyWith(bugs: [bug('keep')], essence: {sp: v}).toJson();
        final r = on.mergeSave(s, up);
        expect(r.save!.essence[sp], v, reason: sp);
        expect(r.extra['clamped'], isFalse, reason: sp);
      }
    });

    test('A — 저장본에 없던 곤충(젤리로 바로 부화해 바꿈)은 쓴 젤리만큼 여유를 준다', () {
      final s = stored([]).copyWith(materials: {MaterialKind.jelly: 100});
      // 뽑기 30젤리 → 영웅(216, 뽑기 출신은 희귀도 1) → 바로 정수.
      final up = s
          .copyWith(
            materials: {MaterialKind.jelly: 70},
            essence: {'stag_dorcus': 216},
          )
          .toJson();
      expect(on.mergeSave(s, up).save!.essence['stag_dorcus'], 216);
      // 젤리를 안 썼으면 여유 없음.
      final free = stored([]).copyWith(essence: {'stag_dorcus': 216}).toJson();
      expect(
        on.mergeSave(stored([]), free).save!.essence['stag_dorcus'] ?? 0,
        0,
      );
    });
  });

  group('곤충 등급 필드 위조(B·F)', () {
    test('합성 단계는 줄지 않고 태생 등급은 오르지 않는다', () {
      final s = stored([bug('a', pot: 5, su: 4)]);
      // 합성 단계를 지워 태생 5성 → 정수 2,160 × 희귀도로 부풀리기.
      final j = stored([bug('a', pot: 5)]).toJson();
      expect(on.mergeSave(s, j).save!.bugs.first.synthUps, 4);
      // 합성 단계는 그대로 두고 포텐셜만 올리기 — 합성 단계가 같이 오른다.
      final s2 = stored([bug('b', pot: 2, su: 1)]);
      final j2 = stored([bug('b', pot: 4, su: 1)]).toJson();
      final b2 = on.mergeSave(s2, j2).save!.bugs.first;
      expect(b2.bornPotential, 1);
    });

    test('뽑기 출신 표식은 지워지지 않는다', () {
      final s = stored([bug('a', pot: 4, gc: true)]);
      final j = stored([bug('a', pot: 4)]).toJson();
      expect(on.mergeSave(s, j).save!.bugs.first.fromGacha, isTrue);
    });

    test('켜진 뒤 생김(ng) — 같은 id 에 새로 붙이지 못하고, 새 id 에는 붙는다', () {
      final s = stored([bug('old', pot: 5, ng: false)]);
      final j = stored([bug('old', pot: 5), bug('new', pot: 2)]).toJson();
      final out = on.mergeSave(s, j).save!;
      expect(out.bugs.firstWhere((b) => b.id == 'old').newGen, isFalse);
      expect(out.bugs.firstWhere((b) => b.id == 'new').newGen, isTrue);
      // 지운 경우도 저장본 값으로.
      final s2 = stored([bug('n', pot: 2)]);
      final j2 = stored([bug('n', pot: 2, ng: false)]).toJson();
      expect(on.mergeSave(s2, j2).save!.bugs.first.newGen, isTrue);
    });

    test('옛 합성 단계(ls) — 한 번 적히면 고정, 처음 적힐 때는 저장본 합성 단계까지', () {
      final s = stored([bug('a', pot: 4, su: 3, ng: false, ls: 1)]);
      final drop = stored([bug('a', pot: 4, su: 3, ng: false)]).toJson();
      expect(on.mergeSave(s, drop).save!.bugs.first.legacySynthUps, 1);
      final raise = stored([
        bug('a', pot: 4, su: 3, ng: false, ls: 3),
      ]).toJson();
      expect(on.mergeSave(s, raise).save!.bugs.first.legacySynthUps, 1);
      // 처음 올린 업로드 — 저장본 합성 2 · 올라온 3 · 적은 ls 2 는 그대로, 3 은 2 로.
      final s2 = stored([bug('b', pot: 3, su: 2, ng: false)]);
      final first = stored([
        bug('b', pot: 4, su: 3, ng: false, ls: 3),
      ]).toJson();
      expect(on.mergeSave(s2, first).save!.bugs.first.legacySynthUps, 2);
    });

    test('업데이트 전 곤충 — 들인 마릿수만큼(옛 합성 5★ = 13 × 희귀도)', () {
      final old = bug('a', pot: 5, su: 4, ng: false, sp: 'longhorn_relict');
      expect(
        g.essenceOf(old, Grade.legendary),
        (13 * g.essenceRarity[Grade.legendary]!).round(),
      );
      final s = stored([old]);
      final v = g.essenceOf(old, rarity('longhorn_relict'));
      final up = s
          .copyWith(bugs: [], essence: {'longhorn_relict': 100000})
          .toJson();
      expect(on.mergeSave(s, up).save!.essence['longhorn_relict'], v);
    });
  });

  group('물약(C·D)', () {
    test('쓴 젤리 ÷ 가격 + 하루 확률 드롭 몫만큼만 늘 수 있다', () {
      final s = stored([]).copyWith(materials: {MaterialKind.jelly: 200});
      final up = s
          .copyWith(materials: {MaterialKind.jelly: 150}, growthPotions: 40)
          .toJson();
      // 50젤리 = 5개 + 하루 드롭 3 = 8.
      final out = on.mergeSave(s, up).save!;
      expect(out.growthPotions, 5 + g.potionDropDaily);
      expect(out.potionSrvDay, dailyDateKey(t0));
      expect(out.potionSrvBought, 5);
      expect(out.potionSrvDrops, g.potionDropDaily);
    });

    test('업로드마다 여유가 쌓이지 않는다 — 같은 서버 날짜엔 드롭 몫을 다 쓰면 0', () {
      var s = stored([]);
      for (var i = 0; i < 5; i++) {
        final up = s.copyWith(growthPotions: s.growthPotions + 5).toJson();
        s = on.mergeSave(s, up).save!;
      }
      expect(s.growthPotions, g.potionDropDaily);
    });

    test('하루 구매 상한은 서버 날짜 기준 — 업로드를 나눠도 10개', () {
      var s = stored([]).copyWith(materials: {MaterialKind.jelly: 1000});
      for (var i = 0; i < 3; i++) {
        final jelly = s.materialCount(MaterialKind.jelly);
        final up = s
            .copyWith(
              materials: {MaterialKind.jelly: jelly - 100},
              growthPotions: s.growthPotions + 10,
            )
            .toJson();
        s = on.mergeSave(s, up).save!;
      }
      expect(s.growthPotions, g.potionDailyBuy + g.potionDropDaily);
    });

    test('보스 첫 처치 · 심연 10층 · 그날 첫 미션은 근거만큼 받는다', () {
      final boss = bossDexSlots(on.config.run).first.id;
      final s = stored(
        [],
      ).copyWith(dailyClaims: const {'potion:mission': '2026-10-10'});
      final up = s
          .copyWith(
            bossDex: {boss},
            dailyClaims: {'potion:mission': dailyDateKey(t0)},
            growthPotions: 100,
          )
          .toJson();
      final out = on.mergeSave(s, up).save!;
      expect(
        out.growthPotions,
        g.potionBossFirst + 1 + g.potionDropDaily,
        reason: '보스 1 + 미션 1 + 하루 드롭',
      );
      // 가짜 보스 id 는 세지 않는다.
      final fake = s.copyWith(bossDex: {'nope'}, growthPotions: 100).toJson();
      expect(on.mergeSave(s, fake).save!.growthPotions, g.potionDropDaily);
    });

    test('미션 물약 날짜는 되돌려 다시 받지 못한다', () {
      final s = stored(
        [],
      ).copyWith(dailyClaims: {'potion:mission': dailyDateKey(t0)});
      final up = s
          .copyWith(dailyClaims: const {'potion:mission': '2026-10-01'})
          .toJson();
      final out = on.mergeSave(s, up).save!;
      expect(out.dailyClaims['potion:mission'], dailyDateKey(t0));
    });

    test('구매 기록 날짜는 뒤로 가지 않는다', () {
      final s = stored(
        [],
      ).copyWith(potionBuyDay: dailyDateKey(t0), potionBuyCount: 10);
      final back = s
          .copyWith(potionBuyDay: '2026-10-01', potionBuyCount: 0)
          .toJson();
      final out = on.mergeSave(s, back).save!;
      expect(out.potionBuyDay, dailyDateKey(t0));
      expect(out.potionBuyCount, 10);
      // 같은 날 개수를 줄여 올려도 줄지 않는다.
      final less = s.copyWith(potionBuyCount: 2).toJson();
      expect(on.mergeSave(s, less).save!.potionBuyCount, 10);
      // 먼 미래 날짜는 받지 않는다.
      final future = s.copyWith(potionBuyDay: '2099-01-01').toJson();
      expect(on.mergeSave(s, future).save!.potionBuyDay, dailyDateKey(t0));
    });

    test('서버 하루 기록은 서버 소유 — 올라온 값을 믿지 않는다', () {
      final s = stored(
        [],
      ).copyWith(potionSrvDay: dailyDateKey(t0), potionSrvDrops: 3);
      final reset = s.toJson()
        ..remove('psD')
        ..remove('psR')
        ..['potions'] = 3;
      final out = on.mergeSave(s, reset).save!;
      expect(out.growthPotions, 0);
      expect(out.potionSrvDrops, 3);
    });
  });

  group('서버 스위치(O)', () {
    test('INDIVIDUAL_GRADE — 없으면 pets.json 그대로, 0 이면 끈다, 1 이면 켠다', () {
      final pets = {
        'individualGrade': {'enabled': true, 'potionJelly': 10},
      };
      Map<String, dynamic> ig(String? env) =>
          GameConfig.withIndividualGradeEnv(pets, env)['individualGrade']
              as Map<String, dynamic>;
      expect(ig(null)['enabled'], isTrue);
      expect(ig('')['enabled'], isTrue);
      expect(ig('0')['enabled'], isFalse);
      expect(ig('0')['potionJelly'], 10, reason: '다른 값은 그대로');
      expect(
        GameConfig.withIndividualGradeEnv(const {}, '1')['individualGrade'],
        {'enabled': true},
      );
    });
  });

  group('결투(H·P)', () {
    final t = t0;
    IndividualBug adult(String id, int pot, {List<int>? rolls}) =>
        IndividualBug(
          id: id,
          speciesId: 'stag_giant',
          sizeMm: 60,
          potential: pot,
          temperament: Temperament.aggressive,
          sex: Sex.male,
          element: Element.wood,
          stage: LifeStage.adult,
          stageSince: t.subtract(const Duration(days: 30)),
          synthUps: rolls == null ? 0 : 1,
          rolls: rolls,
          newGen: true,
        );

    test('H — 야생 상대 기준(내 상위 3마리 평균)에 등급 보정이 실린다', () {
      final s = SaveGame.initial(
        createdAt: t,
      ).copyWith(bugs: [adult('a', 1), adult('b', 1), adult('c', 1)]);
      BattleBug firstOf(GameActions a) => a
          .buildWildTeam(
            s,
            tierId: a.config.battle.scoutTiers.first.id,
            speciesById: byId(a),
            petConfig: a.config.pet,
            enhance: a.config.enhance,
            rng: Random(3),
          )!
          .team
          .first;
      final sp = byId(on)['stag_giant']!;
      // 상위 3마리 = 세 마리 전부(같은 종·등급) — 야생 체력·공격 비율 = 세 마리 보정의 평균.
      final ms = [
        for (final id in ['a', 'b', 'c']) g.battleMods(adult(id, 1), sp),
      ];
      final mHp = ms.fold(0.0, (a, m) => a + m.hp) / 3;
      final mAtk = ms.fold(0.0, (a, m) => a + m.atk) / 3;
      final wOn = firstOf(on);
      final wOff = firstOf(off);
      expect(wOn.maxHp / wOff.maxHp, closeTo(mHp, 0.01));
      expect(wOn.atk / wOff.atk, closeTo(mAtk, 0.01));
    });

    test('P — 켠 상태 편성 검증 = 공용 계산(앱 duelBugFor 와 같은 순서·같은 함수)', () {
      final rolls = [10, 95, 40, 70, 50, 100, 0, 80];
      final bugs = [adult('x', 2, rolls: rolls), adult('y', 5), adult('z', 3)];
      final s = SaveGame.initial(
        createdAt: t,
      ).copyWith(bugs: bugs, lastSeen: t);
      final team = on
          .validateDuelTeam(
            s,
            ['x', 'y', 'z'],
            speciesById: byId(on),
            petConfig: on.config.pet,
            enhance: on.config.enhance,
          )
          .team;
      final pet = on.config.pet;
      for (var i = 0; i < 3; i++) {
        final bug = bugs[i];
        final sp = byId(on)[bug.speciesId]!;
        final tb = trainingBonusOf(
          s,
          bug,
          sp,
          on.config.battle.training,
          levelCap: pet.levelCap(bug.breakthroughTier),
          enhance: on.config.enhance,
        );
        final m = pet.individualGrade.battleMods(bug, sp);
        final want =
            DuelBug.fromBattleBug(
                  buildBattleBug(
                    bug: bug,
                    species: sp,
                    locale: 'ko',
                    trainAtkMult: tb.atkMult,
                    trainDefMult: tb.defMult,
                    trainHpMult: tb.hpMult,
                    trainSpdMult: tb.spdMult,
                    traitAtkBonus: pet.traitBattleAtk(bug.trait),
                    variantAtkBonus: pet.variantBattleAtk(bug.variant),
                    variantHpBonus: pet.variantBattleHp(bug.variant),
                    traitHpBonus: pet.traitBattleHp(bug.trait),
                  ),
                  speciesId: bug.speciesId,
                  sizeMm: bug.sizeMm,
                  specialty: sp.specialty,
                  sizeStatMult: bug.statMultiplier(sp),
                )
                .withTraining(
                  evade: tb.evade,
                  crit: tb.crit,
                  recovery: tb.recovery,
                  massMult: tb.massMult,
                  pushMult: tb.pushMult,
                  tech: tb.tech,
                  grit: tb.grit,
                )
                .withTraining(
                  hpMult: m.hp,
                  atkMult: m.atk,
                  defMult: m.def,
                  spdMult: m.spd,
                  crit: m.crit,
                  evade: m.evade,
                  recovery: m.recovery,
                  pushMult: m.push,
                );
        final got = team[i];
        expect(got.maxHp, closeTo(want.maxHp, 1e-6), reason: bug.id);
        expect(got.atk, closeTo(want.atk, 1e-6), reason: bug.id);
        expect(got.def, closeTo(want.def, 1e-6), reason: bug.id);
        expect(got.spd, closeTo(want.spd, 1e-6), reason: bug.id);
        expect(got.crit, closeTo(want.crit, 1e-9), reason: bug.id);
        expect(got.evade, closeTo(want.evade, 1e-9), reason: bug.id);
        expect(got.recovery, closeTo(want.recovery, 1e-9), reason: bug.id);
        expect(got.pushMult, closeTo(want.pushMult, 1e-9), reason: bug.id);
      }
    });
  });
}

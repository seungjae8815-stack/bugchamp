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

  /// 곤충 희귀도(1.0.22 — 서버 `_enforceGrade` 와 같은 `PetConfig.rarityOf`).
  Grade bugRarity(IndividualBug b) =>
      on.config.pet.rarityOf(b, byId(on)[b.speciesId]!);

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
      final v = g.essenceOf(bug('a'), bugRarity(bug('a')));
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
        final v = g.essenceOf(
          egg.copyWith(stage: LifeStage.larva),
          bugRarity(egg),
        );
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

    test('뽑기 출신 표식은 옛 곤충에 새로 붙이지 못한다(1.0.22 — gc 면 희귀도가 뽑기 표로 굴려진다)', () {
      final s = stored([bug('a', pot: 2)]);
      final j = stored([bug('a', pot: 2, gc: true)]).toJson();
      expect(on.mergeSave(s, j).save!.bugs.first.fromGacha, isFalse);
    });

    test('곤충 희귀도 ry(1.0.22) — 옛 곤충에 적지 못하고, 떨궈도 되돌리고, 다른 값으로 바꾸지 못한다', () {
      final s = stored([bug('old', pot: 2)]);
      final j = stored([
        bug('old', pot: 2).copyWith(rarity: Grade.legendary),
      ]).toJson();
      expect(on.mergeSave(s, j).save!.bugs.first.rarity, isNull);
      // 구버전 앱(ry 를 모름)이 떨궈 올려도 저장본 값.
      final s2 = stored([bug('r', pot: 1).copyWith(rarity: Grade.rare)]);
      final j2 = stored([bug('r', pot: 1)]).toJson();
      expect(on.mergeSave(s2, j2).save!.bugs.first.rarity, Grade.rare);
      final j3 = stored([
        bug('r', pot: 1).copyWith(rarity: Grade.legendary),
      ]).toJson();
      expect(on.mergeSave(s2, j3).save!.bugs.first.rarity, Grade.rare);
    });

    test(
      '곤충 희귀도 ry(1.0.22) — 새 곤충은 희귀 천장 id 롤과 같은 값만 · 허용치까지 · 뽑기 출신은 안 됨',
      () {
        const r = BugRarityConfig(enabled: true);
        IndividualBug pity(String id) =>
            bug(id, pot: 1).copyWith(rarity: r.pityRarityOf(id));
        final s = stored(const []);
        // 맞는 값 2개 + 위조(전설로 고친 것) + 뽑기 출신에 적은 것 + 허용치 넘는 것.
        var forged = 'f0';
        for (var i = 0; r.pityRarityOf(forged) == Grade.legendary; i++) {
          forged = 'f$i';
        }
        final client = stored([
          pity('a'),
          pity('b'),
          bug(forged, pot: 1).copyWith(rarity: Grade.legendary),
          bug('g', pot: 1, gc: true).copyWith(rarity: r.pityRarityOf('g')),
          pity('c'),
        ]);
        final out = GameActions.guardGradeBugFields(
          s,
          client,
          rarity: r,
          newRarityAllowance: 2,
        );
        Grade? ry(String id) => out.bugs.firstWhere((b) => b.id == id).rarity;
        expect(ry('a'), r.pityRarityOf('a'));
        expect(ry('b'), r.pityRarityOf('b'));
        expect(ry(forged), isNull);
        expect(ry('g'), isNull);
        expect(ry('c'), isNull); // 허용치(2) 초과
        // 꺼져 있으면 새 곤충의 ry 도 지운다(쓰이지 않는 값).
        final off = GameActions.guardGradeBugFields(s, stored([pity('a')]));
        expect(off.bugs.first.rarity, isNull);
      },
    );

    test('희귀도 올리기(1.0.22) — 재료 3마리가 사라진 업로드만 인정 · 재료로 정수를 또 받지 못한다', () {
      IndividualBug c(String id) =>
          bug(id, pot: 1).copyWith(rarity: Grade.common);
      final s = stored([c('t'), c('a'), c('b'), c('c')]);
      final up = rarityUp(s, 't', on.config.pet, {
        for (final x in on.config.speciesList) x.id: x,
      });
      expect(up.isOk, isTrue);
      final out = on.mergeSave(s, up.save!.toJson()).save!;
      expect(out.bugs.single.rarity, Grade.uncommon);
      // 재료를 남긴 채 희귀도만 올리면 저장본 값.
      final forged = stored([
        c('t').copyWith(rarity: Grade.uncommon),
        c('a'),
        c('b'),
        c('c'),
      ]).toJson();
      expect(
        on
            .mergeSave(s, forged)
            .save!
            .bugs
            .firstWhere((b) => b.id == 't')
            .rarity,
        Grade.common,
      );
      // 재료를 정수로도 받겠다고 하면 정수는 잘린다(재료 3마리분은 이미 희귀도로 썼다).
      final greedy = up.save!.copyWith(essence: {'stag_dorcus': 3}).toJson();
      final r = on.mergeSave(s, greedy).save!;
      expect(r.bugs.single.rarity, Grade.uncommon);
      expect(r.essence['stag_dorcus'] ?? 0, lessThan(3));
    });

    test('희귀도 올리기 — 저장본에 알이던 곤충(마지막 업로드 뒤 부화)도 재료로 센다', () {
      IndividualBug c(String id, {LifeStage stage = LifeStage.adult}) =>
          bug(id, pot: 1, stage: stage).copyWith(rarity: Grade.common);
      final s = stored([
        c('t'),
        c('a', stage: LifeStage.egg),
        c('b', stage: LifeStage.egg),
        c('c', stage: LifeStage.egg),
      ]);
      // 앱: 알 3마리 부화 → 바로 재료로.
      final client = stored([c('t').copyWith(rarity: Grade.uncommon)]).toJson();
      final out = on.mergeSave(s, client).save!;
      expect(out.bugs.single.rarity, Grade.uncommon);
    });

    test('희귀도 자동 올리기 — 업로드 사이에 올린 곤충을 바로 재료로 써도 인정한다(이어 올리기)', () {
      IndividualBug c(String id, {int lv = 1}) =>
          bug(id, pot: 1).copyWith(rarity: Grade.common, level: lv);
      final s = stored([c('t', lv: 5), for (var i = 0; i < 15; i++) c('w$i')]);
      final up = autoRarityUp(s, on.config.pet, {
        for (final x in on.config.speciesList) x.id: x,
      });
      expect(up.isOk, isTrue);
      expect(up.save!.bugs.single.rarity, Grade.rare);
      final out = on.mergeSave(s, up.save!.toJson()).save!;
      expect(out.bugs.single.rarity, Grade.rare);
    });

    test('새 곤충의 뽑기 출신 gc — 쓴 젤리 ÷ 뽑기 가격 개 + 결제 알(iap-) 업로드당 4개까지', () {
      final cost = on.config.pet.gachaJellyCost;
      expect(cost, greaterThan(0));
      final s = stored([
        // 서버가 먼저 지급한 결제 알(저장본에 있음)은 그대로.
        bug('iap-old-0', pot: 4, gc: true, stage: LifeStage.egg),
      ]).copyWith(materials: {MaterialKind.jelly: cost * 3});
      final client = s.copyWith(
        materials: {MaterialKind.jelly: cost}, // 2번 뽑을 만큼 썼다
        bugs: [
          bug('iap-old-0', pot: 4, gc: true, stage: LifeStage.egg),
          for (var i = 0; i < 4; i++)
            bug('g$i', pot: 3, gc: true, stage: LifeStage.egg),
          for (var i = 0; i < 6; i++)
            bug('iap-x-$i', pot: 4, gc: true, stage: LifeStage.egg),
        ],
      );
      final out = on.mergeSave(s, client.toJson()).save!;
      bool gc(String id) => out.bugs.firstWhere((b) => b.id == id).fromGacha;
      expect(gc('iap-old-0'), isTrue);
      expect(
        [for (var i = 0; i < 4; i++) gc('g$i')].where((x) => x).length,
        2 + GameActions.kGachaSlackPerUpload,
      );
      expect(
        [for (var i = 0; i < 6; i++) gc('iap-x-$i')].where((x) => x).length,
        GameActions.kNewIapEggsPerUpload,
      );
      // 젤리를 안 썼으면 새 곤충의 gc 는 여유분만 남기고 지운다.
      final free = stored([]).copyWith(
        bugs: [
          for (var i = 0; i < 3; i++)
            bug('f$i', pot: 3, gc: true, stage: LifeStage.egg),
        ],
      );
      expect(
        on
            .mergeSave(stored([]), free.toJson())
            .save!
            .bugs
            .where((b) => b.fromGacha)
            .length,
        GameActions.kGachaSlackPerUpload,
      );
      // 10회 뽑기와 같은 구간에 젤리를 벌어(선물 2배 등) 순감소가 9번 값뿐이어도 10마리 모두 남는다(2026-10-17 점검).
      final s10 = stored(
        [],
      ).copyWith(materials: {MaterialKind.jelly: cost * 10});
      final c10 = s10.copyWith(
        materials: {MaterialKind.jelly: 5}, // 10번(전부) 썼고 같은 구간에 젤리 5를 받았다
        bugs: [
          for (var i = 0; i < 10; i++)
            bug('t$i', pot: 3, gc: true, stage: LifeStage.egg),
        ],
      );
      expect(
        on
            .mergeSave(s10, c10.toJson())
            .save!
            .bugs
            .where((b) => b.fromGacha)
            .length,
        10,
      );
    });

    test('놓친 굴리기 횟수(lru)는 놓친 횟수를 넘지 못한다 · 새 곤충엔 붙지 않고 롤도 지운다', () {
      const full = [100, 100, 100, 100, 100, 100, 100, 100];
      // 새 곤충(켜진 뒤 생김)에 lru + 만점 롤.
      final fresh = stored([
        bug('n', pot: 1).copyWith(legacyRollUps: 1, rolls: full),
      ]);
      final n = on.mergeSave(stored([]), fresh.toJson()).save!.bugs.single;
      expect(n.legacyRollUps, 0);
      expect(n.rolls, isNull);
      // 옛 곤충(3성 · 놓친 2번)에 lru 9 → 2.
      final s = stored([bug('o', pot: 3, ng: false)]);
      final j = stored([
        bug('o', pot: 3, ng: false).copyWith(legacyRollUps: 9, rolls: full),
      ]).toJson();
      final o = on.mergeSave(s, j).save!.bugs.single;
      expect(o.legacyRollUps, 2);
      expect(o.rolls, full);
    });

    test('놓친 능력치 굴리기 횟수(lru, 1.0.22)는 줄지 않는다 — 0 으로 고쳐 무료 굴리기를 되살리지 못한다', () {
      final s = stored([
        bug('o', pot: 5, su: 4, ng: false).copyWith(legacyRollUps: 3),
      ]);
      final j = stored([bug('o', pot: 5, su: 4, ng: false)]).toJson();
      expect(on.mergeSave(s, j).save!.bugs.single.legacyRollUps, 3);
    });

    test(
      '옛 상태의 클라이언트(굴리기 전) — 횟수(lru·su)를 저장본으로 되돌릴 때 롤도 저장본 것(2026-10-24 문의)',
      () {
        // 실제 사고: 굴리기 뒤 서버에는 lru 2 + 새 롤이 있는데, 앱이 굴리기 전 상태(lru 0 · 롤 없음 · 물약 더 많음)를
        // 다시 올렸다. 서버가 lru 만 2 로 되돌리고 롤은 클라이언트 것을 두어 "횟수는 사라지고 능력치는 원래대로"가 됐다.
        const rolled = [80, 70, 90, 60, 75, 85, 65, 95];
        final s = stored([
          bug('o', pot: 3, ng: false).copyWith(legacyRollUps: 2, rolls: rolled),
        ]);
        final stale = stored([bug('o', pot: 3, ng: false)]).toJson();
        final o = on.mergeSave(s, stale).save!.bugs.single;
        expect(o.legacyRollUps, 2);
        expect(o.rolls, rolled);
        // 등급 올리기(su)도 같은 길 — 저장본 su 3 · 롤 있음, 옛 클라이언트 su 1 · 옛 롤.
        const older = [50, 50, 50, 50, 50, 50, 50, 50];
        final s2 = stored([
          bug('g', pot: 4, su: 3, ng: false).copyWith(rolls: rolled),
        ]);
        final stale2 = stored([
          bug('g', pot: 2, su: 1, ng: false).copyWith(rolls: older),
        ]).toJson();
        final g = on.mergeSave(s2, stale2).save!.bugs.single;
        expect(g.synthUps, 3);
        expect(g.rolls, rolled);
        // 진행이 같거나 클라이언트가 앞서면 클라이언트 롤 그대로(정상 굴리기 업로드).
        final s3 = stored([
          bug('f', pot: 3, ng: false).copyWith(legacyRollUps: 1, rolls: older),
        ]);
        final fresh3 = stored([
          bug('f', pot: 3, ng: false).copyWith(legacyRollUps: 2, rolls: rolled),
        ]).toJson();
        expect(on.mergeSave(s3, fresh3).save!.bugs.single.rolls, rolled);
      },
    );

    test(
      '운영 수선 fix:lru — 저장본에 pending 이면 다음 업로드에서 lru 를 지우고 물약을 돌려주고 done 으로 바꾼다',
      () {
        const stale = [50, 50, 50, 50, 50, 50, 50, 50];
        final s =
            stored([
              bug(
                'a',
                pot: 3,
                ng: false,
              ).copyWith(legacyRollUps: 2, rolls: stale),
              bug(
                'b',
                pot: 4,
                su: 1,
                ng: false,
              ).copyWith(legacyRollUps: 1, rolls: stale),
            ]).copyWith(
              growthPotions: 5,
              dailyClaims: {GameActions.kLruFixKey: 'pending:60'},
            );
        final j = stored([
          bug('a', pot: 3, ng: false).copyWith(legacyRollUps: 2, rolls: stale),
          bug(
            'b',
            pot: 4,
            su: 1,
            ng: false,
          ).copyWith(legacyRollUps: 1, rolls: stale),
        ]).copyWith(growthPotions: 5).toJson();
        final r = on.mergeSave(s, j);
        final out = r.save!;
        expect(r.extra['clamped'], isTrue);
        final a = out.bugs.firstWhere((b) => b.id == 'a');
        final b = out.bugs.firstWhere((b) => b.id == 'b');
        expect(a.legacyRollUps, 0);
        expect(a.rolls, isNull); // 등급 올리기 없는 곤충은 처음 롤로 돌아간다
        expect(b.legacyRollUps, 0);
        expect(b.rolls, stale); // 등급 올리기(su) 몫의 롤은 남는다
        expect(out.growthPotions, 65);
        expect(out.dailyClaims[GameActions.kLruFixKey], startsWith('done:'));
        // 두 번째 업로드(앱이 채택한 뒤) — 다시 적용되지 않는다.
        final r2 = on.mergeSave(out, out.toJson());
        expect(r2.save!.growthPotions, 65);
        expect(r2.save!.bugs.every((x) => x.legacyRollUps == 0), isTrue);
      },
    );

    test(
      '운영 수선 fix:* 는 앱이 적지 못한다 — 올린 값은 버리고 저장본 값만 남는다 · 물약 상한(2026-10-25 출시 전 점검)',
      () {
        // 1) 저장본에 표식이 없는데 앱이 pending 을 적어 올림 → 버린다(저장되지 않는다).
        final s = stored([
          bug('a', pot: 3, ng: false),
        ]).copyWith(growthPotions: 5);
        final forged = stored([bug('a', pot: 3, ng: false)])
            .copyWith(
              growthPotions: 5,
              dailyClaims: {GameActions.kLruFixKey: 'pending:100000'},
            )
            .toJson();
        final r1 = on.mergeSave(s, forged).save!;
        expect(r1.dailyClaims.containsKey(GameActions.kLruFixKey), isFalse);
        // 다음 업로드에서도 물약이 늘지 않는다.
        final r2 = on.mergeSave(r1, r1.toJson()).save!;
        expect(r2.growthPotions, 5);
        // 2) done 뒤에 앱이 pending 을 다시 적어 올림 → 저장본 done 이 남는다.
        final done = s.copyWith(
          dailyClaims: {GameActions.kLruFixKey: 'done:2026-10-24'},
        );
        final again = s
            .copyWith(dailyClaims: {GameActions.kLruFixKey: 'pending:100000'})
            .toJson();
        final r3 = on.mergeSave(done, again).save!;
        expect(r3.dailyClaims[GameActions.kLruFixKey], 'done:2026-10-24');
        // 3) 운영이 적은 pending 도 물약은 상한까지만.
        final big = s.copyWith(
          dailyClaims: {GameActions.kLruFixKey: 'pending:100000'},
        );
        final r4 = on.mergeSave(big, s.toJson()).save!;
        expect(r4.growthPotions, 5 + GameActions.kLruFixMaxPotions);
      },
    );

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
      // 곤충 희귀도(1.0.22) — 옛 곤충도 id 롤로 새로 굴려진 희귀도로 정수를 받는다.
      final v = g.essenceOf(old, bugRarity(old));
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
      // 오늘 확률 드롭 몫을 다 쓴 상태(한도는 설정값 — 2026-10-14 3 → 10).
      final daily = on.config.pet.individualGrade.potionDropDaily;
      final s = stored(
        [],
      ).copyWith(potionSrvDay: dailyDateKey(t0), potionSrvDrops: daily);
      final reset = s.toJson()
        ..remove('psD')
        ..remove('psR')
        ..['potions'] = 3;
      final out = on.mergeSave(s, reset).save!;
      expect(out.growthPotions, 0);
      expect(out.potionSrvDrops, daily);
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
      final wants = <DuelBug>[];
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
        final m = pet.individualGrade.battleMods(
          bug,
          sp,
          rarityMult: pet.duelRarityMultOf(bug, sp),
        );
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
        // 팀 역할 오라(1.0.21 D3) — 3마리 결투는 같은 공용 함수로 오라를 붙이고 입힌다.
        final aura = duelAuraOf(
          s,
          bug,
          sp,
          on.config.battle.training,
          on.config.battle.teamAura,
          levelCap: pet.levelCap(bug.breakthroughTier),
          enhance: on.config.enhance,
        );
        wants.add(want.withAura(aura.role, aura.value));
      }
      final auraed = applyTeamAura(
        wants,
        capPerStat: on.config.battle.teamAura.capPerStat,
      );
      for (var i = 0; i < 3; i++) {
        final bug = bugs[i];
        final want = auraed[i];
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

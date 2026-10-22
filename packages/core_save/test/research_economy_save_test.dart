import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:core_save/core_save.dart';
import 'package:test/test.dart';

/// 연구소 추가 연구 2부(설계 §10) — core_save 공용 함수: 혈통 연구(짝짓기) · 약초학(물약) · 분해 기술(방치 방생) ·
/// 제련 비법(초월). "연구 0 이면 그대로 · 다 찍으면 기대 배율".
void main() {
  Map<String, dynamic> read(String f) =>
      jsonDecode(File('../app/assets/data/$f').readAsStringSync())
          as Map<String, dynamic>;
  final run = RunConfig.fromJson(read('run_config.json'));
  final pets = PetConfig.fromJson(read('pets.json'));
  final forge = ForgeConfig.fromJson(read('forge.json'));
  final rc = ResearchConfig.fromJson(read('research.json'));
  final species = (read('species.json')['species'] as List)
      .cast<Map<String, dynamic>>()
      .map(Species.fromJson)
      .toList();
  final maxed = researchEffects(rc, {
    for (final d in rc.defs) d.id: d.maxLevel,
  });
  const none = ResearchEffects.none;
  final t0 = DateTime.utc(2026, 10, 23, 3);

  group('혈통 연구 — 짝짓기 혈통 특성 새로 열림', () {
    final sp = species.first;
    IndividualBug parent(Sex sex) => IndividualBug(
      id: 'p_${sex.key}',
      speciesId: sp.id,
      sizeMm: (sp.sizeMinMm + sp.sizeMaxMm) / 2,
      potential: 3,
      temperament: Temperament.cunning,
      sex: sex,
      element: Element.fire,
    );
    // 실데이터 확률이 작아 차이를 보려고 확률을 키운 설정(규칙은 같다).
    final cfg = PetConfig.fromJson({
      ...read('pets.json'),
      'breedingTraitNew': 0.3,
    });
    BreedingSlot slot(int seed) => BreedingSlot.from(
      id: 's$seed',
      mother: parent(Sex.female),
      father: parent(Sex.male),
      endsAt: t0,
      seed: seed,
    );

    test(
      '연구 0 이면 그대로 · 다 찍으면 확률 × (1 + v) — 다른 롤(크기·포텐셜·오행·기질·성별·이색)은 같은 seed 그대로',
      () {
        final v = maxed.of(ResearchEffect.traitChance);
        expect(v, greaterThan(0));
        var before = 0, after = 0;
        const n = 4000;
        for (var seed = 0; seed < n; seed++) {
          final a = slot(seed).hatch(id: 'e', species: sp, cfg: cfg);
          final z = slot(
            seed,
          ).hatch(id: 'e', species: sp, cfg: cfg, research: none);
          final b = slot(
            seed,
          ).hatch(id: 'e', species: sp, cfg: cfg, research: maxed);
          expect(z.toJson(), a.toJson());
          expect(b.sizeMm, a.sizeMm);
          expect(b.potential, a.potential);
          expect(b.element, a.element);
          expect(b.temperament, a.temperament);
          expect(b.sex, a.sex);
          expect(b.variant, a.variant);
          // 특성이 이미 열린 자식은 연구가 있어도 같은 특성(같은 pick).
          if (!a.trait.isNone) expect(b.trait, a.trait);
          if (!a.trait.isNone) before++;
          if (!b.trait.isNone) after++;
        }
        expect(before / n, closeTo(0.3, 0.03));
        expect(after / n, closeTo(0.3 * (1 + v), 0.03));
      },
    );
  });

  group('약초학 — 성장물약 확률 드롭(하루 한도 그대로)', () {
    final grade = pets.individualGrade;
    final base = SaveGame.initial(createdAt: t0).copyWith(lastSeen: t0);

    test('연구 0 이면 그대로 · 다 찍으면 확률 × (1 + v)', () {
      final v = maxed.of(ResearchEffect.potionChance);
      expect(
        potionDropChance(grade.potionEliteChance, none),
        grade.potionEliteChance,
      );
      expect(
        potionDropChance(grade.potionEliteChance, maxed),
        closeTo(grade.potionEliteChance * (1 + v), 1e-12),
      );
      // 같은 seed 로 굴려 비교(한도 없이 — now 를 안 넘긴다).
      var a = 0, b = 0;
      const n = 200000;
      final r1 = Random(7), r2 = Random(7);
      for (var i = 0; i < n; i++) {
        a += rollPotionDrop(base, grade, r1, PotionSource.elite).got;
        b += rollPotionDrop(
          base,
          grade,
          r2,
          PotionSource.elite,
          research: maxed,
        ).got;
      }
      expect(b, greaterThan(a));
      expect(b / n, closeTo(grade.potionEliteChance * (1 + v), 0.0006));
    });

    test('하루 한도(potionDropDaily)는 연구가 있어도 그대로', () {
      var s = base;
      var total = 0;
      final rng = Random(3);
      for (var i = 0; i < 200000; i++) {
        final r = rollPotionDrop(
          s,
          grade,
          rng,
          PotionSource.elite,
          now: t0,
          research: maxed,
        );
        s = r.save;
        total += r.got;
      }
      expect(total, grade.potionDropDaily);
    });

    test('방치 기댓값(expectedOfflineGain)도 같은 확률', () {
      final buffs = BuffConfig.fromJson(read('buffs.json'));
      final s = base.copyWith(
        buffExpiry: {BuffKind.gatherer: t0.add(const Duration(hours: 8))},
      );
      final stats = deriveStats(
        run,
        upgradeLevels: s.upgradeLevels,
        characterLevel: s.level,
        bugsCollected: s.bugBuffCount,
      );
      final plan = planOffline(
        config: run,
        base: stats,
        buffs: buffs,
        spans: offlineBuffSpans(s, t0, const Duration(hours: 8)),
        stageNumber: s.stageNumber,
        efficiency: run.offlineEfficiency,
      );
      OfflineGain g(ResearchEffects r) => expectedOfflineGain(
        plan,
        save: s,
        run: run,
        species: species,
        grade: grade,
        now: t0,
        research: r,
      );
      final a = g(none).potions, b = g(maxed).potions;
      // 8시간 채집꾼이라 기댓값이 0 보다 크고 하루 한도엔 안 닿는다 — 먼저 확인해 조건 없이 비교한다.
      expect(a, greaterThan(0));
      expect(
        b,
        lessThan(grade.potionDropDaily.toDouble()),
        reason: '한도에 닿으면 배율을 못 본다',
      );
      expect(b / a, closeTo(1 + maxed.of(ResearchEffect.potionChance), 1e-6));
    });
  });

  test('분해 기술 — 방치 정산 자동 방생 재료 × (1 + v)', () {
    final s = SaveGame.initial(
      createdAt: t0,
    ).copyWith(lastSeen: t0, bugFilterMinGrade: Grade.legendary);
    int mats(ResearchEffects r) {
      var id = 0;
      final d = rollIdleDrops(
        save: s,
        rolls: 3000,
        species: species,
        run: run,
        pet: pets,
        bugFind: 1,
        materialFind: 0, // 재료 드롭을 빼고 방생 재료만 본다.
        now: t0,
        rng: Random(11),
        newId: () => 'b${id++}',
        research: r,
      );
      return kRegularMaterials.fold<int>(
        0,
        (a, k) => a + (d.materials[k] ?? 0),
      );
    }

    final a = mats(none);
    expect(a, greaterThan(0));
    final b = mats(maxed);
    final v = maxed.of(ResearchEffect.salvageMat);
    expect(b / a, closeTo(1 + v, 0.05));
  });

  test('제련 비법 — 초월 시간(startForgeTranscend)', () {
    final s = SaveGame.initial(createdAt: t0).copyWith(
      lastSeen: t0,
      forgeLevel: forge.maxLevel,
      materials: {MaterialKind.fossil: 1 << 30},
    );
    final a = startForgeTranscend(s, forge, t0).save!;
    final z = startForgeTranscend(s, forge, t0, research: none).save!;
    final b = startForgeTranscend(s, forge, t0, research: maxed).save!;
    expect(z.forgeTranscendAt, a.forgeTranscendAt);
    expect(a.forgeTranscendAt, t0.add(forge.transcendDuration(0)));
    expect(
      b.forgeTranscendAt,
      t0.add(forge.transcendDuration(0, research: maxed)),
    );
    expect(b.forgeTranscendAt!.isBefore(a.forgeTranscendAt!), isTrue);
  });
}

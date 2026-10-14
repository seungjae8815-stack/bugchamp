import 'dart:convert';
import 'dart:io';

import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:core_save/core_save.dart';
import 'package:test/test.dart';

/// 결투 팀 역할 오라 · 훈련 지휘 칸(1.0.21 D3, docs/design_growth_1021.md §3).
void main() {
  Map<String, dynamic> read(String f) =>
      jsonDecode(File('../app/assets/data/$f').readAsStringSync())
          as Map<String, dynamic>;
  final battle = BattleConfig.fromJson(read('battle.json'));
  final cfg = battle.training;
  final aura = battle.teamAura;
  const sp = Species(
    id: 'stag_dorcus',
    name: LocalizedText(ko: '애사슴벌레', en: 'Stag', ja: 'クワガタ'),
    grade: Grade.common,
    specialty: Specialty.grip,
    baseStats: Stats(hp: 95, atk: 30, def: 35, spd: 22),
    sizeMinMm: 20,
    sizeMaxMm: 55,
    duelRole: DuelRole.defense,
  );
  IndividualBug bug({int potential = 5, Temperament t = Temperament.cunning}) =>
      IndividualBug(
        id: 'b1',
        speciesId: sp.id,
        sizeMm: 40,
        potential: potential,
        temperament: t,
        sex: Sex.male,
        element: Element.fire,
        level: 80,
        breakthroughTier: 4,
      );
  SaveGame withAlloc(IndividualBug b, Map<TrainSlot, int> alloc) =>
      SaveGame.initial(createdAt: DateTime.utc(2026, 10, 14)).copyWith(
        bugs: [b],
        trainPoints: {
          b.id: BugTrain(
            alloc: alloc,
            paid: alloc.values.fold<int>(0, (a, x) => a + x),
          ),
        },
      );

  test(
    'JSON 값 = 코드 기본값(battle.json → duel.teamAura · training.slots.command)',
    () {
      const d = TeamAuraConfig();
      expect(aura.enabled, d.enabled);
      expect(aura.baseByGrade, d.baseByGrade);
      expect(aura.capPerStat, d.capPerStat);
      expect(
        cfg.slotEffect[TrainSlot.command],
        kDefaultSlotEffect[TrainSlot.command],
      );
      expect(cfg.slotBaseCap[TrainSlot.command], 10);
      expect(kDefaultSlotCap[TrainSlot.command], 10);
    },
  );

  test('기질은 지휘 칸 상한만 ±2(우직·신중 +2 · 호전적·변덕 −2 · 교활 0)', () {
    int cap(Temperament t) =>
        cfg.slotCap(TrainSlot.command, temperament: t, specialty: sp.specialty);
    expect(cap(Temperament.steadfast), 12);
    expect(cap(Temperament.cautious), 12);
    expect(cap(Temperament.cunning), 10);
    expect(cap(Temperament.aggressive), 8);
    expect(cap(Temperament.fickle), 8);
  });

  test('오라 = 개체 등급 기본 + 지휘 포인트 × 1점 효과', () {
    final per = cfg.slotEffect[TrainSlot.command]!;
    for (var p = 1; p <= 5; p++) {
      final b = bug(potential: p);
      final a = duelAuraOf(withAlloc(b, const {}), b, sp, cfg, aura);
      expect(a.role, DuelRole.defense);
      expect(a.value, closeTo(aura.baseByGrade[p - 1], 1e-12));
    }
    final b = bug();
    final a = duelAuraOf(
      withAlloc(b, const {TrainSlot.command: 7}),
      b,
      sp,
      cfg,
      aura,
    );
    expect(a.value, closeTo(aura.baseByGrade[4] + 7 * per, 1e-12));
  });

  test('지휘 포인트도 칸 상한·예산으로 잘린다(위조 배분)', () {
    final b = bug(t: Temperament.aggressive); // 지휘 상한 8
    final forged = withAlloc(b, const {TrainSlot.command: 50});
    final a = duelAuraOf(forged, b, sp, cfg, aura);
    expect(
      a.value,
      closeTo(
        aura.baseByGrade[4] + 8 * cfg.slotEffect[TrainSlot.command]!,
        1e-12,
      ),
    );
    // 업로드 정리도 같은 상한.
    final fixed = sanitizeTrainPoints(
      forged,
      cfg,
      speciesOf: (_) => sp,
      levelCapOf: (_) => 80,
    );
    expect(fixed.trainPoints[b.id]!.alloc[TrainSlot.command], 8);
  });

  test('예산을 넘치면 맨 뒤 칸(지휘)부터 깎인다 — 기존 칸 배분은 그대로', () {
    final b = bug(t: Temperament.steadfast); // 예산 102 · 지휘 상한 12
    final s = SaveGame.initial(createdAt: DateTime.utc(2026, 10, 14)).copyWith(
      bugs: [b],
      trainPoints: {
        b.id: const BugTrain(
          alloc: {
            TrainSlot.attack: 30,
            TrainSlot.defense: 30,
            TrainSlot.hp: 30,
            TrainSlot.command: 12,
          },
          paid: 102,
        ),
      },
    );
    expect(
      sanitizeTrainPoints(
        s,
        cfg,
        speciesOf: (_) => sp,
        levelCapOf: (_) => 80,
      ).trainPoints[b.id]!.alloc,
      {
        TrainSlot.attack: 30,
        TrainSlot.defense: 30,
        TrainSlot.hp: 30,
        TrainSlot.command: 12,
      },
    );
    final over = s.copyWith(
      trainPoints: {
        b.id: const BugTrain(
          alloc: {
            TrainSlot.attack: 30,
            TrainSlot.defense: 30,
            TrainSlot.hp: 30,
            TrainSlot.grit: 10,
            TrainSlot.command: 12,
          },
          paid: 112,
        ),
      },
    );
    final alloc = sanitizeTrainPoints(
      over,
      cfg,
      speciesOf: (_) => sp,
      levelCapOf: (_) => 80,
    ).trainPoints[b.id]!.alloc;
    expect(alloc[TrainSlot.command], 2);
    expect(alloc[TrainSlot.grit], 10);
  });

  test('역할 없는 종 · 꺼진 오라는 (null, 0)', () {
    final b = bug();
    const noRole = Species(
      id: 'x',
      name: LocalizedText(ko: 'x', en: 'x', ja: 'x'),
      grade: Grade.common,
      specialty: Specialty.grip,
      baseStats: Stats(hp: 1, atk: 1, def: 1, spd: 1),
      sizeMinMm: 1,
      sizeMaxMm: 2,
    );
    final s = withAlloc(b, const {TrainSlot.command: 5});
    expect(duelAuraOf(s, b, noRole, cfg, aura), (role: null, value: 0.0));
    expect(
      duelAuraOf(
        s,
        b,
        sp,
        cfg,
        TeamAuraConfig.fromJson(const {'enabled': false}),
      ),
      (role: null, value: 0.0),
    );
  });

  test('지휘 칸 키는 세이브에 그대로 남는다(BugTrain JSON 왕복)', () {
    const rec = BugTrain(alloc: {TrainSlot.command: 4}, paid: 4);
    expect(BugTrain.fromJson(rec.toJson())!.alloc, {TrainSlot.command: 4});
    expect(rec.toJson()['a'], {'command': 4});
  });
}

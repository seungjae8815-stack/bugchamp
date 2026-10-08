import 'package:core_models/core_models.dart';
import 'package:core_save/core_save.dart';
import 'package:server/src/actions.dart';
import 'package:server/src/game_config.dart';
import 'package:test/test.dart';

/// 훈련 v2 업로드 검사(2026-10-08, docs/design_training_v2.md §5·§6) —
/// 이전(멱등) · 배분 상한 자르기 · 구버전 앱 업로드 보존 · 결투석 급증.
final t0 = DateTime.utc(2026, 10, 8, 12);

void main() {
  late GameConfig cfg;
  late GameActions actions;

  setUpAll(() async {
    cfg = await GameConfig.load(dir: '../app/assets/data');
    actions = GameActions(config: cfg, now: () => t0);
  });

  IndividualBug adult(String id, {PartLevels enh = PartLevels.zero}) =>
      IndividualBug(
        id: id,
        speciesId: 'stag_giant',
        sizeMm: 70,
        potential: 3,
        temperament: Temperament.aggressive,
        sex: Sex.male,
        element: Element.wood,
        stage: LifeStage.adult,
        stageSince: t0.subtract(const Duration(days: 30)),
        enhancement: enh,
      );

  SaveGame stored({List<IndividualBug>? bugs}) =>
      SaveGame.initial(createdAt: t0).copyWith(
        lastSeen: t0.subtract(const Duration(seconds: 60)),
        bugs:
            bugs ?? [adult('b1', enh: const PartLevels(hornJaw: 10, build: 6))],
        materials: const {MaterialKind.jelly: 500},
      );

  /// 1.0.17 앱이 올리는 모양 — `feat` 18, v2 필드 없음.
  Map<String, dynamic> oldAppJson(SaveGame s) {
    final j = s.toJson()..['feat'] = 18;
    for (final k in ['trainPoints', 'trainPointJob', 'duelStones']) {
      j.remove(k);
    }
    return j;
  }

  test('1.0.17 앱의 업로드도 서버가 이전한다 — 알리지 않는다(clamped 아님)', () {
    final s = stored();
    final r = actions.mergeSave(s, oldAppJson(s));
    expect(r.isOk, isTrue);
    final rec = r.save!.trainPoints['b1']!;
    // 뿔 10 → 공격 +40% → 14포인트 · 체격 6 → 체력 +30% → 8포인트
    expect(rec.alloc, {TrainSlot.attack: 14, TrainSlot.hp: 8});
    expect(rec.freeRespec, isTrue);
    expect(r.extra['clamped'], isFalse);
    // 부위 강화 원본은 세이브에 남는다(구버전 호환 · 이전 상한의 근거).
    expect(r.save!.bugs.single.enhancement.levelOf(BugPart.hornJaw), 10);
  });

  test('구버전 업로드는 v2 기록·결투석을 지우지 못하고 옛 훈련 단계는 얼어 있다', () {
    final s = stored().copyWith(
      trainPoints: {
        'b1': const BugTrain(alloc: {TrainSlot.mass: 3}, paid: 3),
      },
      duelStones: {DuelStone.element: 2},
      duelTraining: {
        'b1': {TrainStat.crit: 1},
      },
    );
    final client = s.copyWith(
      duelTraining: {
        'b1': {TrainStat.crit: 9},
      },
    );
    final r = actions.mergeSave(s, oldAppJson(client));
    expect(r.save!.trainPoints['b1']!.alloc, {TrainSlot.mass: 3});
    expect(r.save!.duelStoneCount(DuelStone.element), 2);
    expect(r.save!.duelTraining['b1']![TrainStat.crit], 1);
  });

  test('새 앱의 위조 배분은 예산·칸 상한으로 잘린다(clampReasons: train)', () {
    final s = stored(bugs: [adult('b1')]);
    final client = s.copyWith(
      trainPoints: {
        'b1': const BugTrain(
          alloc: {TrainSlot.attack: 99, TrainSlot.grit: 99},
          paid: 999,
          bonus: 999,
        ),
      },
    );
    final r = actions.mergeSave(s, client.toJson());
    final rec = r.save!.trainPoints['b1']!;
    // 3성 1레벨 = 18포인트, 옛 투자 없음 → 보너스 0
    expect(rec.allocated, 18);
    expect(rec.paid, 18);
    expect(rec.bonus, 0);
    expect(r.extra['clamped'], isTrue);
    expect(r.extra['clampReasons'], contains('train'));
  });

  test('정상 배분은 그대로 — 잘리지 않는다', () {
    final s = stored(bugs: [adult('b1')]);
    final client = s.copyWith(
      trainPoints: {
        'b1': const BugTrain(
          alloc: {TrainSlot.attack: 10, TrainSlot.tech: 5},
          paid: 15,
        ),
      },
    );
    final r = actions.mergeSave(s, client.toJson());
    expect(r.save!.trainPoints['b1']!.alloc, {
      TrainSlot.attack: 10,
      TrainSlot.tech: 5,
    });
    expect(r.extra['clamped'], isFalse);
  });

  group('결투석 급증', () {
    test('젤리 없이 쏟아 넣으면 저장본 수로', () {
      final s = stored();
      final client = s.copyWith(duelStones: {DuelStone.temperament: 500});
      final r = actions.mergeSave(s, client.toJson());
      expect(r.save!.duelStoneCount(DuelStone.temperament), 0);
      expect(r.extra['clampReasons'], contains('train'));
    });

    test('쓴 젤리로 산 만큼은 인정한다', () {
      final s = stored();
      final bought = buyDuelStone(
        migrateTrainingV2(
          s,
          cfg.battle.training,
          speciesOf: (id) => cfg.speciesById[id],
          enhance: cfg.enhance,
        ),
        cfg.battle.training.stones,
        DuelStone.element,
        count: 10, // 400젤리 → 10개 (여유 밖)
      ).save!;
      final client = bought.copyWith(
        duelStones: {DuelStone.element: 10 + kDuelStoneDropSlack},
      );
      final r = actions.mergeSave(s, client.toJson());
      expect(
        r.save!.duelStoneCount(DuelStone.element),
        10 + kDuelStoneDropSlack,
      );
    });
  });
}

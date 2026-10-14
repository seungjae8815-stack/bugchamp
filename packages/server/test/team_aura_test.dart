import 'package:core_battle/core_battle.dart';
import 'package:core_models/core_models.dart';
import 'package:core_save/core_save.dart';
import 'package:server/src/actions.dart';
import 'package:server/src/game_config.dart';
import 'package:test/test.dart';

/// 결투 팀 역할 오라 · 훈련 지휘 칸(1.0.21 D3, docs/design_growth_1021.md §3) — 서버 편성 · 구버전 업로드 보존.
final t0 = DateTime.utc(2026, 10, 14, 12);

void main() {
  late GameConfig cfg;
  late GameActions actions;

  setUpAll(() async {
    cfg = await GameConfig.load(dir: '../app/assets/data');
    actions = GameActions(config: cfg, now: () => t0);
  });

  IndividualBug adult(String id, String speciesId) => IndividualBug(
    id: id,
    speciesId: speciesId,
    sizeMm: 45,
    potential: 5,
    level: 80,
    breakthroughTier: 4,
    temperament: Temperament.steadfast,
    sex: Sex.male,
    element: Element.wood,
    stage: LifeStage.adult,
    stageSince: t0.subtract(const Duration(days: 30)),
  );

  // 공격형(장수말벌) · 방어형(왕사슴벌레) · 체력형(장수풍뎅이).
  final bugs = [
    adult('a', 'hornet_giant'),
    adult('d', 'stag_giant'),
    adult('h', 'rhino_japanese'),
  ];

  SaveGame save({Map<String, BugTrain> train = const {}}) =>
      SaveGame.initial(createdAt: t0).copyWith(
        lastSeen: t0.subtract(const Duration(seconds: 60)),
        bugs: bugs,
        trainPoints: train,
        pvpDefenseIds: const ['a', 'd', 'h'],
        materials: const {MaterialKind.jelly: 500},
      );

  List<DuelBug> team(SaveGame s, {int? teamSize}) {
    final v = actions.validateDuelTeam(
      s,
      teamSize == null ? const ['a', 'd', 'h'] : const ['a'],
      speciesById: cfg.speciesById,
      petConfig: cfg.pet,
      enhance: cfg.enhance,
      teamSize: teamSize,
    );
    expect(v.error, isNull);
    return v.team;
  }

  DuelBug alone(SaveGame s, String id) => actions
      .validateDuelTeam(
        s,
        [id],
        speciesById: cfg.speciesById,
        petConfig: cfg.pet,
        enhance: cfg.enhance,
        teamSize: 1,
      )
      .team
      .single;

  test('3마리 결투는 팀 오라를 입힌다 — 전설 개체 3마리 = 공격·방어·체력 각 +6%', () {
    final s = save();
    final base = cfg.battle.teamAura.baseByGrade[4];
    final t = team(s);
    for (final b in t) {
      final solo = alone(s, b.id);
      expect(b.auraApplied, isTrue);
      expect(b.atk, closeTo(solo.atk * (1 + base), 1e-6));
      expect(b.def, closeTo(solo.def * (1 + base), 1e-6));
      expect(b.maxHp, closeTo(solo.maxHp * (1 + base), 1e-6));
    }
    expect(t.first.auraRole, DuelRole.attack);
  });

  test('왕충 선발대회(1마리)에는 오라가 없다 — 대회 기록 비교 유지', () {
    final s = save();
    final b = team(s, teamSize: 1).single;
    expect(b.auraApplied, isFalse);
    // 역할·크기 표시는 붙어 있어도 능력치에는 입히지 않는다.
    expect(applyTeamAura([b], capPerStat: 0.2).single.atk, greaterThan(b.atk));
  });

  test('지휘 포인트는 그 역할 능력치를 팀 전체에 더 올린다', () {
    final per = cfg.battle.training.slotEffect[TrainSlot.command]!;
    final base = cfg.battle.teamAura.baseByGrade[4];
    final s = save(
      train: {
        'd': const BugTrain(alloc: {TrainSlot.command: 10}, paid: 10),
      },
    );
    final t = team(s);
    final solo = alone(s, 'h');
    final hp = t.firstWhere((b) => b.id == 'h');
    expect(
      hp.def,
      closeTo(solo.def * (1 + (base + 10 * per).clamp(0, 0.2)), 1e-6),
    );
    expect(hp.atk, closeTo(solo.atk * (1 + base), 1e-6));
  });

  test('방어팀(defenderDuelTeam)도 같은 오라 · 세션 JSON 을 다시 읽어도 두 번 입히지 않는다', () {
    final s = save();
    final def = actions.defenderDuelTeam(
      s,
      speciesById: cfg.speciesById,
      petConfig: cfg.pet,
      enhance: cfg.enhance,
    )!;
    final mine = team(s);
    for (var i = 0; i < 3; i++) {
      expect(def[i].atk, closeTo(mine[i].atk, 1e-9));
    }
    final reloaded = [for (final b in def) DuelBug.fromJson(b.toJson())];
    final again = applyTeamAura(reloaded, capPerStat: 0.2);
    expect(again.first.atk, closeTo(def.first.atk, 1e-9));
  });

  group('구버전 앱(feat 25) 업로드 — 모르는 지휘 칸을 저장본에서 되돌린다', () {
    Map<String, dynamic> oldAppJson(SaveGame s) {
      final j = s.toJson()..['feat'] = 25;
      // 1.0.20 앱은 `command` 키를 모르고 건너뛰어 읽고(TrainSlot.fromKeyOrNull) 그대로 다시 올린다.
      final tp = Map<String, dynamic>.from(j['trainPoints'] as Map);
      for (final id in tp.keys.toList()) {
        final rec = Map<String, dynamic>.from(tp[id] as Map);
        for (final f in ['a', 'n']) {
          if (rec[f] is Map) {
            rec[f] = Map<String, dynamic>.from(rec[f] as Map)
              ..remove('command');
          }
        }
        tp[id] = rec;
      }
      j['trainPoints'] = tp;
      if ((j['trainPointJob'] as Map?)?['s'] == 'command') {
        j.remove('trainPointJob');
      }
      return j;
    }

    test('배분의 지휘 점수를 지킨다', () {
      final s = save(
        train: {
          'a': const BugTrain(
            alloc: {TrainSlot.attack: 20, TrainSlot.command: 6},
            paid: 26,
          ),
        },
      );
      final r = actions.mergeSave(s, oldAppJson(s));
      expect(r.isOk, isTrue);
      expect(r.save!.trainPoints['a']!.alloc, {
        TrainSlot.attack: 20,
        TrainSlot.command: 6,
      });
    });

    test('다시 찍기 대기 배분의 지휘 점수와 지휘 칸 대기열도 지킨다', () {
      final until = t0.add(const Duration(hours: 1));
      final s =
          save(
            train: {
              'a': BugTrain(
                alloc: const {TrainSlot.command: 4},
                paid: 12,
                pending: const {TrainSlot.hp: 4, TrainSlot.command: 8},
                respecUntil: until,
              ),
            },
          ).copyWith(
            trainPointJob: TrainPointJob(
              bugId: 'd',
              slot: TrainSlot.command,
              count: 2,
              until: until,
            ),
          );
      final r = actions.mergeSave(s, oldAppJson(s));
      expect(r.isOk, isTrue);
      final rec = r.save!.trainPoints['a']!;
      expect(rec.alloc, {TrainSlot.command: 4});
      expect(rec.pending, {TrainSlot.hp: 4, TrainSlot.command: 8});
      expect(r.save!.trainPointJob?.slot, TrainSlot.command);
      expect(r.save!.trainPointJob?.bugId, 'd');
    });

    test('새 앱(feat 26)이 지휘 칸을 비웠으면 그대로 받는다', () {
      final s = save(
        train: {
          'a': const BugTrain(alloc: {TrainSlot.command: 6}, paid: 6),
        },
      );
      final client = s.copyWith(
        trainPoints: {
          'a': const BugTrain(alloc: {TrainSlot.attack: 6}, paid: 6),
        },
      );
      final r = actions.mergeSave(
        s,
        client.toJson()..['feat'] = kSaveFeatureLevel,
      );
      expect(r.save!.trainPoints['a']!.alloc, {TrainSlot.attack: 6});
    });
  });
}

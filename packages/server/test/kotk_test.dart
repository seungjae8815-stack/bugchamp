import 'package:core_models/core_models.dart';
import 'package:core_save/core_save.dart';
import 'package:server/src/actions.dart';
import 'package:server/src/game_config.dart';
import 'package:test/test.dart';

/// 왕중왕전 결과 반영 · 표본(2026-11-10).
void main() {
  final t0 = DateTime.utc(2026, 11, 10, 3);
  late GameConfig cfg;
  late GameActions actions;

  setUpAll(() async {
    cfg = await GameConfig.load(dir: '../app/assets/data');
    actions = GameActions(config: cfg, now: () => t0);
  });

  IndividualBug adult(String id) => IndividualBug(
    id: id,
    speciesId: 'stag_giant',
    sizeMm: 70,
    potential: 3,
    temperament: Temperament.aggressive,
    sex: Sex.male,
    element: Element.wood,
    stage: LifeStage.adult,
    stageSince: t0.subtract(const Duration(days: 30)),
  );

  final base = SaveGame.initial(createdAt: t0).copyWith(
    bugs: [adult('b1'), adult('b2'), adult('b3')],
    kotkEntryWeek: 'w1',
    kotkEntryBug: 'b1',
  );

  test('지면 참가 곤충이 표본 · 최고 성적 · 참가 기록을 비운다', () {
    final out = actions.kotkApply(base, 'w1', 8)!;
    expect(out.retiredBugs, {'b1'});
    expect(out.kotkBest, 8);
    expect(out.kotkEntryWeek, isNull);
    expect(out.kotkDoneWeek, 'w1');
    // 서버가 보상을 넣은 저장본이 앞서가야 앱의 낡은 업로드가 덮지 못한다(stale_save).
    expect(out.saveRev, base.saveRev + 1);
    // 표본은 칸을 차지하지 않는다.
    expect(out.storageUsed, 2);
  });

  test('우승은 표본이 아니다 · 대진에 못 오르면 성적 없이 비운다', () {
    final champ = actions.kotkApply(base, 'w1', 1)!;
    expect(champ.retiredBugs, isEmpty);
    expect(champ.kotkBest, 1);
    final out = actions.kotkApply(base, 'w1', null)!;
    expect(out.retiredBugs, isEmpty);
    expect(out.kotkBest, 0);
    expect(actions.kotkApply(base, 'w2', 4), isNull);
  });

  test('표본은 결투·대회·왕중왕전에 못 나간다', () {
    final s = base.copyWith(retiredBugs: {'b1'});
    final r = actions.validateDuelTeam(
      s,
      ['b1'],
      speciesById: cfg.speciesById,
      petConfig: cfg.pet,
      enhance: cfg.enhance,
      teamSize: 1,
    );
    expect(r.error, 'bug_retired');
  });

  test('표본·참가 기록은 서버 소유 — 앱이 지워 올려도 되살아난다', () {
    final stored = base.copyWith(retiredBugs: {'b2'}, lastSeen: t0);
    final json = stored.toJson()
      ..remove('rtB')
      ..remove('ktP')
      ..remove('ktE');
    final r = actions.mergeSave(stored, json);
    expect(r.save!.retiredBugs, {'b2'});
    expect(r.save!.kotkEntryBug, 'b1');
  });

  test('표본은 펫으로도 못 단다 — 결과 반영 때 떼고, 달아 올려도 서버가 뗀다', () {
    final eq = base.copyWith(equippedBugIds: ['b1', 'b2']);
    expect(actions.kotkApply(eq, 'w1', 4)!.equippedBugIds, ['b2']);
    final stored = base.copyWith(retiredBugs: {'b1'}, lastSeen: t0);
    final r = actions.mergeSave(
      stored,
      stored.copyWith(equippedBugIds: ['b1', 'b3']).toJson(),
    );
    expect(r.save!.equippedBugIds, ['b3']);
  });

  test('성적 보상(2026-11-12) — battle.json 표대로 젤리·화석·물약·결투석, 우승은 왕관·뱃지', () {
    final kotk = cfg.battle.kotk;
    final jelly0 = base.materials[MaterialKind.jelly] ?? 0;
    final champ = actions.kotkApply(
      base.copyWith(kotkEntryWeek: '2026-11-16'),
      '2026-11-16',
      1,
    )!;
    final r1 = kotk.rewardFor(1)!;
    expect(r1.jelly, 50);
    expect(champ.materials[MaterialKind.jelly], jelly0 + r1.jelly);
    expect(champ.growthPotions, base.growthPotions + r1.potions);
    expect(
      champ.duelStones[DuelStone.element] ?? 0,
      (base.duelStones[DuelStone.element] ?? 0) + r1.elementStones,
    );
    expect(champ.kotkChampBugs, {'b1'});
    expect(champ.eventBadges, contains('kotk:1'));
    expect(bestEventBadge(champ.eventBadges), 'kotk:1');
    // 4강은 젤리 10 · 왕관 없음 · 표본.
    final semi = actions.kotkApply(base, 'w1', 4)!;
    expect(semi.materials[MaterialKind.jelly], jelly0 + 10);
    expect(semi.kotkChampBugs, isEmpty);
    expect(semi.retiredBugs, {'b1'});
    // 8강은 젤리 없음 · 대진 밖은 보상 없음.
    expect(
      actions.kotkApply(base, 'w1', 8)!.materials[MaterialKind.jelly] ?? 0,
      jelly0,
    );
    expect(
      actions.kotkApply(base, 'w1', null)!.growthPotions,
      base.growthPotions,
    );
  });

  test('회차 — 제1회 전 주는 준비 중(null), 그 뒤로 주마다 1씩', () {
    final kotk = cfg.battle.kotk;
    expect(kotk.roundOf('2026-11-09'), isNull);
    expect(kotk.roundOf('2026-11-16'), 1);
    expect(kotk.roundOf('2026-11-23'), 2);
    expect(kotk.roundOf('2027-01-04'), 8);
  });

  test('우승 곤충 표시(ktC)는 서버 소유 — 지워 올려도 되살아난다', () {
    final stored = base.copyWith(kotkChampBugs: {'b3'}, lastSeen: t0);
    final json = stored.toJson()..remove('ktC');
    expect(actions.mergeSave(stored, json).save!.kotkChampBugs, {'b3'});
  });

  test('표본·참가 곤충은 업로드로 지울 수 없다(재료로 가치가 옮겨 가지 않게) — 서버가 되돌린다', () {
    final stored = base.copyWith(retiredBugs: {'b2'}, lastSeen: t0);
    final json = stored
        .copyWith(
          bugs: [
            for (final b in stored.bugs)
              if (b.id == 'b3') b,
          ],
        )
        .toJson();
    final ids = {
      for (final b in actions.mergeSave(stored, json).save!.bugs) b.id,
    };
    expect(ids, containsAll(['b1', 'b2'])); // b1 = 참가 중(ktE), b2 = 표본
  });

  test('방어팀의 표본 자리는 남은 성충으로 채운다(옛 능력치 행으로 떨어지지 않게)', () {
    final s = base.copyWith(
      bugs: [...base.bugs, adult('b4')],
      retiredBugs: {'b2'},
      pvpDefenseIds: ['b1', 'b2', 'b3'],
    );
    final team = actions.defenderDuelTeam(
      s,
      speciesById: cfg.speciesById,
      petConfig: cfg.pet,
      enhance: cfg.enhance,
    );
    expect(team, isNotNull);
    expect(team!.length, 3);
  });

  test('참가가 적은 주(minEntrants 미만)는 젤리·뱃지·왕관 없이 재료만', () {
    expect(cfg.battle.kotk.minEntrants, 8);
    final jelly0 = base.materials[MaterialKind.jelly] ?? 0;
    final out = actions.kotkApply(base, 'w1', 1, prize: false)!;
    expect(out.materials[MaterialKind.jelly] ?? 0, jelly0);
    expect(out.kotkChampBugs, isEmpty);
    expect(out.eventBadges.where((b) => b.startsWith('kotk:')), isEmpty);
    expect(
      out.growthPotions,
      base.growthPotions + cfg.battle.kotk.rewardFor(1)!.potions,
    );
  });
}

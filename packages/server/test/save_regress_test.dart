import 'package:core_run/core_run.dart';
import 'package:core_save/core_save.dart';
import 'package:server/src/actions.dart';
import 'package:server/src/game_config.dart';
import 'package:test/test.dart';

/// 업로드 되돌림 기록(2026-11-12) — 누가 저장본을 뒤로 돌렸는지 로그로 찾을 수 있게.
void main() {
  final t0 = DateTime.utc(2026, 11, 12);
  final base = SaveGame.initial(createdAt: t0).copyWith(
    level: 62,
    maxTierReached: 3,
    difficultyTier: 3,
    gold: 27000000000000,
    saveRev: 500,
    researchLevels: {'jaw': 5, 'nest': 8},
    upgradeLevels: {UpgradeKind.attack: 200},
  );

  test('연구·레벨·강화·골드가 크게 줄면 적는다', () {
    final regressed = base.copyWith(
      level: 40,
      gold: 100,
      saveRev: 501,
      researchLevels: const {},
      upgradeLevels: {UpgradeKind.attack: 50},
    );
    final note = GameActions.regressionNote(base, regressed)!;
    expect(note, contains('연구 합 13→0'));
    expect(note, contains('레벨 62→40'));
    expect(note, contains('강화 합 200→50'));
    expect(note, contains('골드'));
    expect(note, contains('rev 500→501'));
  });

  test('정상 진행·골드 쓰기는 적지 않는다', () {
    final spent = base.copyWith(
      gold: base.gold ~/ 2,
      level: 63,
      saveRev: 520,
      upgradeLevels: {UpgradeKind.attack: 210},
    );
    expect(GameActions.regressionNote(base, spent), isNull);
  });

  test('낡은 업로드 판정 — 횟수가 낮을 때만 · 횟수가 없으면 보지 않는다', () {
    expect(GameActions.staleUploadRev(base, {'rev': 400}), 400);
    expect(GameActions.staleUploadRev(base, {'rev': 500}), isNull);
    expect(GameActions.staleUploadRev(base, {'rev': 600}), isNull);
    expect(GameActions.staleUploadRev(base, const {}), isNull);
  });

  test('첫 1회 무료 기록·신규 부화 횟수는 서버가 줄지 않게 합친다', () async {
    final cfg = await GameConfig.load(dir: '../app/assets/data');
    final actions = GameActions(config: cfg, now: () => t0);
    final stored = SaveGame.initial(
      createdAt: t0,
    ).copyWith(lastSeen: t0, firstFreeUsed: {'hatch'}, beginnerHatches: 3);
    final cleared = stored.copyWith(
      firstFreeUsed: const {},
      beginnerHatches: 0,
    );
    final r = actions.mergeSave(stored, cleared.toJson());
    expect(r.save!.firstFreeUsed, {'hatch'});
    expect(r.save!.beginnerHatches, 3);
  });
}

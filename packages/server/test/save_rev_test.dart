import 'package:core_save/core_save.dart';
import 'package:server/src/actions.dart';
import 'package:server/src/game_config.dart';
import 'package:test/test.dart';

/// 저장 횟수(`rev`, 2026-10-05) — 앱을 켤 때 진행도가 같으면 이 값이 큰 쪽을 남긴다.
/// 서버는 이 값을 **줄이지 않는다**(모르는 구버전 앱은 키 없이 올린다).
void main() {
  late GameActions actions;
  final t0 = DateTime.utc(2026, 10, 5, 3);

  setUpAll(() async {
    final cfg = await GameConfig.load(dir: '../app/assets/data');
    actions = GameActions(config: cfg, now: () => t0);
  });

  SaveGame stored(int rev) => SaveGame.initial(
    createdAt: t0,
  ).copyWith(lastSeen: t0.subtract(const Duration(seconds: 60)), saveRev: rev);

  test('올라온 횟수가 크면 그대로 저장한다', () {
    final s = stored(10);
    final r = actions.mergeSave(s, s.copyWith(saveRev: 25).toJson());
    expect(r.save!.saveRev, 25);
    expect(r.extra['clamped'], isFalse);
  });

  test('횟수를 모르는 구버전 앱이 올려도 저장본 횟수가 남는다', () {
    final s = stored(10);
    final json = s.toJson()..remove('rev');
    expect(actions.mergeSave(s, json).save!.saveRev, 10);
  });

  test('작은 횟수가 올라와도 줄지 않는다', () {
    final s = stored(40);
    final r = actions.mergeSave(s, s.copyWith(saveRev: 7).toJson());
    expect(r.save!.saveRev, 40);
  });

  // 올라갈 수 있는 한계(1.0.17) — 모르는 1.0.16 앱이 올려도 저장본의 한계가 남는다.
  test('구버전 앱(feat 16)이 올리면 저장본의 한계를 지킨다', () {
    final s = stored(1).copyWith(capTier: 1, capStage: 401);
    final json = s.toJson()
      ..remove('capT')
      ..remove('capS')
      ..['feat'] = 16;
    final r = actions.mergeSave(s, json);
    expect((r.save!.capTier, r.save!.capStage), (1, 401));
  });

  test('새 앱이 한계를 풀어 올리면 풀린다', () {
    final s = stored(1).copyWith(capTier: 1, capStage: 401);
    final json = s.copyWith(clearClimbCap: true).toJson();
    expect(actions.mergeSave(s, json).save!.capStage, 0);
  });
}

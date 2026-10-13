import 'package:core_save/core_save.dart';
import 'package:server/src/actions.dart';
import 'package:server/src/game_config.dart';
import 'package:test/test.dart';

/// 등급 업로드 검사가 무엇을 되돌렸는지 운영 요약에 싣는다(2026-10-13 — `grade ×3` 만으로는
/// 정상 유저의 물약이 사라진 것인지 알 수 없었다, f17b46e0).
void main() {
  late GameConfig cfg;
  final t0 = DateTime.utc(2026, 10, 13, 9);
  late GameActions actions;

  setUpAll(() async {
    cfg = await GameConfig.load(dir: '../app/assets/data');
    actions = GameActions(config: cfg, now: () => t0);
  });

  test('근거 없이 늘어난 물약 — 증가량과 허용치 내역이 남는다', () {
    if (!cfg.pet.individualGrade.enabled) return;
    final s = SaveGame.initial(
      createdAt: t0,
    ).copyWith(lastSeen: t0.subtract(const Duration(seconds: 60)));
    final r = actions.mergeSave(
      s,
      s.copyWith(growthPotions: s.growthPotions + 50).toJson(),
    );
    expect(r.extra['clampReasons'], contains('grade'));
    final detail = (r.extra['clampDetail'] as Map)['grade'] as String;
    expect(detail, allOf(contains('물약 +50'), contains('허용')));
  });
}

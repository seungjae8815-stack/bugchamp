import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:test/test.dart';

void main() {
  group('PetConfig 부상 회복', () {
    final cfg = PetConfig.fromJson({
      'gradeAttackPct': {'common': 0.05},
      'gradeHpPct': {'common': 0.05},
      'stageMult': {'adult': 1.0},
      'stageDurationsSec': {'egg': 60},
      'injuryDurationsSec': {'common': 300, 'legendary': 4800},
      'injuryJellyPerMinute': 0.5,
    });

    test('등급별 회복 시간(미설정 등급은 기본 600초)', () {
      expect(cfg.injuryDuration(Grade.common), 300);
      expect(cfg.injuryDuration(Grade.legendary), 4800);
      expect(cfg.injuryDuration(Grade.rare), 600);
    });

    test('즉시회복 젤리 = 남은분 × rate, 올림·최소 1', () {
      expect(cfg.injuryJelly(const Duration(minutes: 10)), 5); // 10 × 0.5
      expect(cfg.injuryJelly(const Duration(seconds: 30)), 1); // 올림 + 최소 1
      expect(cfg.injuryJelly(Duration.zero), 0);
    });
  });
}

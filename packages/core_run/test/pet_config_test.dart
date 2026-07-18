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

  group('PetConfig 브리딩', () {
    final cfg = PetConfig.fromJson({
      'gradeAttackPct': {'common': 0.05},
      'gradeHpPct': {'common': 0.05},
      'stageMult': {'adult': 1.0},
      'stageDurationsSec': {'egg': 60},
      'breedingDurationsSec': {'common': 600, 'legendary': 9600},
      'breedingJellyPerMinute': 0.5,
    });

    test('등급별 산란 시간(미설정 등급은 기본 1200초)', () {
      expect(cfg.breedingDuration(Grade.common), 600);
      expect(cfg.breedingDuration(Grade.legendary), 9600);
      expect(cfg.breedingDuration(Grade.rare), 1200);
    });

    test('즉시완료 젤리 = 남은분 × rate, 올림·최소 1', () {
      expect(cfg.breedingJelly(const Duration(minutes: 20)), 10);
      expect(cfg.breedingJelly(const Duration(seconds: 10)), 1);
      expect(cfg.breedingJelly(Duration.zero), 0);
    });

    test('기본 상속 계수(유지60/상승10/하락30·돌연변이5%)', () {
      const d = PetConfig(
        gradeAttackPct: {},
        gradeHpPct: {},
        stageMult: {},
        stageDurationsSec: {},
      );
      expect(d.breedingPotUpChance, 0.10);
      expect(d.breedingPotDownChance, 0.30);
      expect(d.breedingMutationChance, 0.05);
    });
  });

  group('PetConfig 분해 보상', () {
    test('기본값: 보상 = 포텐셜(base 0 · perPotential 1)', () {
      const d = PetConfig(
        gradeAttackPct: {},
        gradeHpPct: {},
        stageMult: {},
        stageDurationsSec: {},
      );
      expect(d.disassembleJellyBase, 0);
      expect(d.disassembleJellyPerPotential, 1.0);
      for (var p = 1; p <= 5; p++) {
        expect(d.disassembleJelly(p), p);
      }
    });

    test('JSON 계수 반영: base + perPotential × 포텐셜, 반올림·0 클램프', () {
      final cfg = PetConfig.fromJson({
        'gradeAttackPct': {'common': 0.05},
        'gradeHpPct': {'common': 0.05},
        'stageMult': {'adult': 1.0},
        'stageDurationsSec': {'egg': 60},
        'disassembleJellyBase': 2,
        'disassembleJellyPerPotential': 1.5,
      });
      expect(cfg.disassembleJelly(1), 4); // 2 + 1.5×1 = 3.5 → 4(반올림)
      expect(cfg.disassembleJelly(4), 8); // 2 + 1.5×4 = 8
      expect(cfg.disassembleJelly(0), 2); // 2 + 0
    });
  });
}

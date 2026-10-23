// 연구소 시간 단축(설계 §3.7) — 올림·최소 1초·0 이면 그대로, 훈련 찍기/다시 찍기 대기 단축.
import 'package:core_run/core_run.dart';
import 'package:test/test.dart';

ResearchEffects fx(ResearchEffect k, double v) => ResearchEffects({k: v});

void main() {
  test('절반이면 반, 0 이면 그대로, 올림·최소 1초', () {
    final half = fx(ResearchEffect.hatchTime, 0.5);
    expect(researchScaledSeconds(100, half, ResearchEffect.hatchTime), 50);
    expect(researchScaledSeconds(101, half, ResearchEffect.hatchTime), 51);
    expect(researchScaledSeconds(1, half, ResearchEffect.hatchTime), 1);
    expect(
      researchScaledSeconds(
        100,
        ResearchEffects.none,
        ResearchEffect.hatchTime,
      ),
      100,
    );
    // 다른 종류 효과는 영향 없음.
    expect(researchScaledSeconds(100, half, ResearchEffect.breedTime), 100);
  });

  test('스킨 먼저, 연구 나중 — 곱', () {
    final e = fx(ResearchEffect.hatchTime, 0.2);
    const skinned = 75; // 100 × 0.75
    expect(researchScaledSeconds(skinned, e, ResearchEffect.hatchTime), 60);
  });
}

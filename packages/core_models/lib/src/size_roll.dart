import 'dart:math';

import 'game_rules.dart';

/// 개체 사이즈(정규분포) 롤과 사이즈→스탯배율 매핑 (§2.1).
///
/// **결정론**: 모든 무작위는 호출자가 주입한 [Random] 만 사용한다.
/// 같은 seed 로 만든 Random 은 항상 같은 결과를 낸다.

/// 표준정규 N(0,1) 표본 하나를 Box–Muller 변환으로 뽑는다.
double nextGaussian(Random rng) {
  // u1 은 log(0) 회피를 위해 (0,1] 로 보정.
  double u1 = rng.nextDouble();
  while (u1 <= 1e-12) {
    u1 = rng.nextDouble();
  }
  final u2 = rng.nextDouble();
  return sqrt(-2.0 * log(u1)) * cos(2.0 * pi * u2);
}

/// [minMm, maxMm] 범위에서 정규분포로 사이즈(mm)를 롤한다.
///
/// 평균 = 중앙값, σ = (max-min)/[kSizeSigmaDivisor]. 범위 밖 값은 경계로 clamp.
/// min>=max(퇴화 범위)면 그 값을 그대로 돌려준다.
double rollSizeMm(Random rng, double minMm, double maxMm) {
  if (maxMm <= minMm) return minMm;
  final mean = (minMm + maxMm) / 2.0;
  final sigma = (maxMm - minMm) / kSizeSigmaDivisor;
  final raw = mean + nextGaussian(rng) * sigma;
  return raw.clamp(minMm, maxMm).toDouble();
}

/// 사이즈(mm)를 스탯 배율([kStatMultiplierMin]~[kStatMultiplierMax])로 선형 매핑한다.
/// min→최소배율, max→최대배율. 범위 밖 사이즈는 clamp.
double sizeToStatMultiplier(double sizeMm, double minMm, double maxMm) {
  if (maxMm <= minMm) {
    return (kStatMultiplierMin + kStatMultiplierMax) / 2.0;
  }
  final t = ((sizeMm - minMm) / (maxMm - minMm)).clamp(0.0, 1.0);
  return kStatMultiplierMin + t * (kStatMultiplierMax - kStatMultiplierMin);
}

import 'package:core_models/core_models.dart';

import 'save_game.dart';

/// 암컷 곤충의 `sizeMm` 을 **암컷 범위**로 옮긴다(2026-10-24 §12 암수, 한 번만 — 표식 `sxm`).
///
/// 예전엔 암수 모두 수컷 범위로 굴렸다. 지금은 암컷이 자기 범위(`femaleSizeMinMm~Max`)를 쓰므로,
/// 수컷 범위 안의 위치를 그대로 암컷 범위로 옮겨 **수컷 환산 크기(결투 무게·짝짓기 평균)를 지킨다**.
/// 수컷·모르는 종·암컷 범위가 없는 종은 그대로. 이미 옮긴 세이브는 같은 객체를 돌려준다.
SaveGame migrateFemaleSizes(
  SaveGame s,
  Species? Function(String speciesId) speciesOf,
) {
  if (s.sexSizeMigrated) return s;
  final bugs = [
    for (final b in s.bugs)
      if (b.sex == Sex.female) _moved(b, speciesOf(b.speciesId)) else b,
  ];
  return s.copyWith(bugs: bugs, sexSizeMigrated: true);
}

IndividualBug _moved(IndividualBug b, Species? sp) {
  if (sp == null || sp.femaleSizeMinMm == null || sp.femaleSizeMaxMm == null) {
    return b;
  }
  final male = b.sizeMm.clamp(sp.sizeMinMm, sp.sizeMaxMm).toDouble();
  return b.copyWith(sizeMm: sp.remapFromMale(male, Sex.female));
}

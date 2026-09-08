import 'package:core_run/core_run.dart';

/// 장착 곤충 목록 → 타격자 분배.
///
/// `play_screen` 밖에 두는 이유: 위젯 안에 있으면 단위테스트가 안 되고,
/// 이 계산은 **총 DPS 중립성**이라는 검사할 값이 있는 부분이다.
({double playerMult, List<PetAttacker> pets}) buildPetAttackers({
  required List<PetAttackerInput> equipped,
  required double playerInterval,
  required PetConfig petConfig,
}) => splitAttack(
  pets: equipped,
  playerInterval: playerInterval,
  spdReference: petConfig.attackSpdReference,
  intervalMin: petConfig.attackIntervalMin,
  intervalMax: petConfig.attackIntervalMax,
);

import 'package:meta/meta.dart';

/// 곤충 배틀 스타디움(결투) 물리·규칙 수치 — `battle.json → duel` (§6).
///
/// core_battle 은 core_run 을 모르므로(형제) 설정 모델을 여기 두고,
/// 앱·서버가 같은 JSON 을 읽어 넘긴다. **코드 기본값은 JSON 이 없을 때의 폴백**일 뿐이다.
///
/// 단위: 거리 = 경기장 반지름 100 기준, 시간 = 초.
@immutable
class DuelParams {
  const DuelParams({
    this.arenaRadius = 100,
    this.roundSeconds = 30,
    this.tickHz = 30,
    this.frameEvery = 3,
    this.bestOf = 3,
    this.friction = 1.4,
    this.bowlPull = 0.5,
    this.rimPull = 6,
    this.sizeRefMm = 50,
    this.radiusBase = 6,
    this.radiusPerMm = 0.12,
    this.radiusMin = 6,
    this.radiusMax = 18,
    this.massExp = 0.3,
    this.defMassWeight = 0.35,
    this.speedBase = 34,
    this.speedPerSpd = 0.35,
    this.speedCap = 95,
    this.accelMult = 2.2,
    this.dashMult = 2.1,
    this.dashRange = 55,
    this.dashCooldown = 1.7,
    this.restitution = 0.55,
    this.damageK = 0.06,
    this.impactRef = 70,
    this.impactMin = 0.25,
    this.impactMax = 1.8,
    this.strikeFlipBase = 0.13,
    this.strikeFlipCooldown = 1.4,
    this.strikePushMult = 2.6,
    this.gripSeconds = 1.3,
    this.gripForce = 1100,
    this.gripCooldown = 3.2,
    this.gripDps = 0.12,
    this.tossCooldown = 3.2,
    this.tossSpeed = 145,
    this.tossAirSeconds = 0.55,
    this.tossLandDamage = 0.18,
    this.restrainMult = 1.3,
    this.launchSpeedMult = 1.1,
    this.launchBonusMax = 0.10,
    this.launchAuto = 0.6,
    this.cautiousRim = 0.7,
    this.dodgeChance = 0.35,
    this.flankOffset = 28,
    this.aggressiveCooldownMult = 0.7,
    this.steadfastPushResist = 0.25,
    this.critChance = 0.12,
    this.critMult = 1.5,
    this.weakMult = 1.3,
    this.weakCos = 0.35,
    this.carryHealBase = 0.05,
    this.hpGuard = 1.2,
    this.flipHpGuard = 0.75,
    this.rimHpGuard = 1.2,
    this.damageSpread = 0.5,
  });

  /// 경기장 반지름. 곤충 중심이 이 밖이면 장외.
  final double arenaRadius;

  /// 한 판 제한 시간. 끝나면 남은 체력 % 판정.
  final double roundSeconds;

  /// 물리 틱(초당). 결정론이라 바꾸면 같은 시드의 결과가 달라진다.
  final int tickHz;

  /// 몇 틱마다 궤적 프레임을 하나 남기나(30Hz / 3 = 초당 10프레임).
  final int frameEvery;

  /// 몇 판 중 과반(3 → 2선승).
  final int bestOf;

  /// 마찰(초당 속도 감쇠율).
  final double friction;

  /// 가운데로 모이는 경사 힘(거리 비례).
  final double bowlPull;

  /// 테두리 근처(바깥 20%)에서 추가로 안쪽으로 당기는 힘 — 스치기만 해도
  /// 떨어지지 않게 하는 "턱". 0 이면 가장자리가 미끄럼틀이 된다.
  final double rimPull;

  /// 사이즈 → 무게·반경 기준 길이(mm).
  final double sizeRefMm;
  final double radiusBase;
  final double radiusPerMm;
  final double radiusMin;
  final double radiusMax;

  /// 무게 = (사이즈/기준)^massExp × (1 + defMassWeight × DEF 비중).
  final double massExp;
  final double defMassWeight;

  /// 이동 속도 = speedBase + SPD × speedPerSpd (상한 speedCap).
  final double speedBase;
  final double speedPerSpd;
  final double speedCap;

  /// 가속 = 최고 속도 × accelMult (초당).
  final double accelMult;

  /// 돌진 속도 = 최고 속도 × dashMult. 거리 dashRange 안에서, dashCooldown 마다.
  final double dashMult;
  final double dashRange;
  final double dashCooldown;

  /// 충돌 반발 계수.
  final double restitution;

  /// 충돌 피해 = 상대 ATK × damageK × 충격(상대속도/impactRef, [impactMin, impactMax]) × 100/(100+DEF).
  final double damageK;
  final double impactRef;
  final double impactMin;
  final double impactMax;

  /// 치기: 충돌 때 뒤집기 확률 기본값 · 재판정 쿨타임 · 밀어내기 배율.
  final double strikeFlipBase;
  final double strikeFlipCooldown;
  final double strikePushMult;

  /// 집기: 물고 버티는 시간 · 미는 힘 · 쿨타임 · 물고 있는 동안 초당 피해(ATK 비율).
  final double gripSeconds;
  final double gripForce;
  final double gripCooldown;
  final double gripDps;

  /// 던지기: 쿨타임 · 내던지는 속도 · 공중 시간 · 착지 피해(ATK 비율).
  final double tossCooldown;
  final double tossSpeed;
  final double tossAirSeconds;
  final double tossLandDamage;

  /// 오행 상극 배율(피해·밀어내기).
  final double restrainMult;

  /// 첫 돌진(던져진 직후) 속도 = 최고 속도 × launchSpeedMult × (1 + 게이지 × launchBonusMax).
  final double launchSpeedMult;
  final double launchBonusMax;

  /// 게이지 없이 던질 때(자동 결투·방어 측)의 게이지 값.
  final double launchAuto;

  /// 신중: 반지름의 이 비율 밖이면 먼저 가운데로 돌아온다.
  final double cautiousRim;

  /// 신중: 상대 돌진을 옆으로 피할 확률.
  final double dodgeChance;

  /// 교활: 상대 옆으로 돌아 들어가는 거리.
  final double flankOffset;

  /// 호전적: 돌진 쿨타임 배율.
  final double aggressiveCooldownMult;

  /// 우직: 밀림 저항 보너스(집기·던지기·충돌 밀림에 적용).
  final double steadfastPushResist;

  /// 크리티컬 — 부딪힐 때 기본 확률(+ 곤충의 `crit`) · 피해 배율.
  final double critChance;
  final double critMult;

  /// 약점 공격 — 맞는 쪽이 **옆구리·뒤**를 보일 때 피해 배율. 맞는 쪽이 바라보는 방향과
  /// 때린 쪽 방향의 cos 이 [weakCos] 보다 작으면(약 70° 밖) 약점이다.
  final double weakMult;
  final double weakCos;

  /// 승자 연속(2026-09-29): 이긴 곤충은 **남은 체력 그대로** 다음 상대를 맞는다.
  /// 판 사이 회복 = 최대 체력 × ([carryHealBase] + 곤충의 `recovery`).
  final double carryHealBase;

  /// 기세(2026-09-29) — **체력이 많이 남을수록** 밀림·뒤집기·장외에 버틴다. 가득 찬 곤충은 첫 충돌에
  /// 밀려나지 않고, 두들겨 맞아 체력이 깎일수록 마무리(장외·뒤집기)가 쉬워진다.
  /// [hpGuard]: 밀림 저항 += hpGuard × 체력% · [flipHpGuard]: 뒤집기 확률 × (1 − flipHpGuard × 체력%)
  /// · [rimHpGuard]: 테두리 버팀 × (1 + rimHpGuard × 체력%).
  final double hpGuard;
  final double flipHpGuard;
  final double rimHpGuard;

  /// 부딪힘 피해 흔들림 — 한 방마다 ×(1 ± damageSpread) 균등. 체력 싸움은 한 방이 늘 같으면
  /// 센 쪽이 거의 정해진 대로 이긴다(전력 +20% 가 92%) — 약한 쪽에도 운의 여지를 둔다.
  final double damageSpread;

  int get maxTicks => (roundSeconds * tickHz).round();
  double get dt => 1 / tickHz;

  /// 승자 연속 — 상대 [bestOf]마리(팀 크기)를 모두 쓰러뜨려야 이긴다.
  int get winsNeeded => bestOf;

  /// 한 경기의 최대 판 수(3마리씩이면 5판).
  int get maxBouts => bestOf * 2 - 1;

  factory DuelParams.fromJson(Map<String, dynamic>? j) {
    if (j == null) return const DuelParams();
    const d = DuelParams();
    double n(String k, double def) => (j[k] as num?)?.toDouble() ?? def;
    int i(String k, int def) => (j[k] as num?)?.toInt() ?? def;
    return DuelParams(
      arenaRadius: n('arenaRadius', d.arenaRadius),
      roundSeconds: n('roundSeconds', d.roundSeconds),
      tickHz: i('tickHz', d.tickHz),
      frameEvery: i('frameEvery', d.frameEvery),
      bestOf: i('bestOf', d.bestOf),
      friction: n('friction', d.friction),
      bowlPull: n('bowlPull', d.bowlPull),
      rimPull: n('rimPull', d.rimPull),
      sizeRefMm: n('sizeRefMm', d.sizeRefMm),
      radiusBase: n('radiusBase', d.radiusBase),
      radiusPerMm: n('radiusPerMm', d.radiusPerMm),
      radiusMin: n('radiusMin', d.radiusMin),
      radiusMax: n('radiusMax', d.radiusMax),
      massExp: n('massExp', d.massExp),
      defMassWeight: n('defMassWeight', d.defMassWeight),
      speedBase: n('speedBase', d.speedBase),
      speedPerSpd: n('speedPerSpd', d.speedPerSpd),
      speedCap: n('speedCap', d.speedCap),
      accelMult: n('accelMult', d.accelMult),
      dashMult: n('dashMult', d.dashMult),
      dashRange: n('dashRange', d.dashRange),
      dashCooldown: n('dashCooldown', d.dashCooldown),
      restitution: n('restitution', d.restitution),
      damageK: n('damageK', d.damageK),
      impactRef: n('impactRef', d.impactRef),
      impactMin: n('impactMin', d.impactMin),
      impactMax: n('impactMax', d.impactMax),
      strikeFlipBase: n('strikeFlipBase', d.strikeFlipBase),
      strikeFlipCooldown: n('strikeFlipCooldown', d.strikeFlipCooldown),
      strikePushMult: n('strikePushMult', d.strikePushMult),
      gripSeconds: n('gripSeconds', d.gripSeconds),
      gripForce: n('gripForce', d.gripForce),
      gripCooldown: n('gripCooldown', d.gripCooldown),
      gripDps: n('gripDps', d.gripDps),
      tossCooldown: n('tossCooldown', d.tossCooldown),
      tossSpeed: n('tossSpeed', d.tossSpeed),
      tossAirSeconds: n('tossAirSeconds', d.tossAirSeconds),
      tossLandDamage: n('tossLandDamage', d.tossLandDamage),
      restrainMult: n('restrainMult', d.restrainMult),
      launchSpeedMult: n('launchSpeedMult', d.launchSpeedMult),
      launchBonusMax: n('launchBonusMax', d.launchBonusMax),
      launchAuto: n('launchAuto', d.launchAuto),
      cautiousRim: n('cautiousRim', d.cautiousRim),
      dodgeChance: n('dodgeChance', d.dodgeChance),
      flankOffset: n('flankOffset', d.flankOffset),
      aggressiveCooldownMult: n(
        'aggressiveCooldownMult',
        d.aggressiveCooldownMult,
      ),
      steadfastPushResist: n('steadfastPushResist', d.steadfastPushResist),
      critChance: n('critChance', d.critChance),
      critMult: n('critMult', d.critMult),
      weakMult: n('weakMult', d.weakMult),
      weakCos: n('weakCos', d.weakCos),
      carryHealBase: n('carryHealBase', d.carryHealBase),
      hpGuard: n('hpGuard', d.hpGuard),
      flipHpGuard: n('flipHpGuard', d.flipHpGuard),
      rimHpGuard: n('rimHpGuard', d.rimHpGuard),
      damageSpread: n('damageSpread', d.damageSpread),
    );
  }
}

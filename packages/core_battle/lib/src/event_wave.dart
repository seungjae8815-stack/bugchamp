import 'dart:math';

import 'package:core_models/core_models.dart';

import 'core_battle_base.dart';

/// 웨이브 적 생성 계수. 값 자체는 밸런스라 `event.json` 에서 온다(§6).
///
/// 이 스펙이 **`core_battle` 에 있는 이유**: 앱과 서버가 같은 웨이브를 만들어야
/// 한다. 규칙이 두 벌이 되면 "서버는 졌다는데 화면에선 이겼다"가 생긴다.
/// (`core_run` 에 둘 수 없다 — `core_run` 은 `core_battle` 을 모른다, §4.)
class WaveEnemySpec {
  const WaveEnemySpec({
    required this.baseHp,
    required this.baseAtk,
    required this.baseDef,
    required this.baseSpd,
    required this.growth,
    this.count = 3,
  });

  final double baseHp;
  final double baseAtk;
  final double baseDef;
  final double baseSpd;

  /// 웨이브당 스탯 배율(지수). 1.0 이면 영원히 같은 적이 나온다.
  final double growth;

  /// 한 웨이브의 적 수.
  final int count;
}

/// 웨이브 [wave] 의 적 팀. **회차 seed 하나로 전부 결정**된다.
///
/// 같은 회차라면 모든 유저가 **같은 웨이브**를 만난다 — 판마다 적이 달라지면
/// "좋은 적이 나올 때까지 돌리는" 운 게임이 되고, 그건 실물 경품에 쓸 수 없는
/// 구조다(기획 §1).
///
/// **한 웨이브 = 하나의 오행.** 웨이브마다 색이 바뀐다.
///
/// 예전엔 한 웨이브 안에서 적마다 오행이 달랐다. 그러면 "다음 웨이브는 불"이라고
/// 예고해도 2·3번째 적에는 대응할 수 없어, **선봉을 고르는 선택이 무의미**해진다
/// (실기 지적). 웨이브가 한 색이어야 "이번엔 물을 앞세우자"가 성립하고,
/// 그때 비로소 오행 상성이 전략이 된다(§2.3).
///
/// 대신 한 속성으로 몰아 짠 팀은 **자기가 약한 색의 웨이브에서 통째로 무너진다** —
/// 그게 편성을 고르게 만드는 압력이다.
List<BattleBug> eventWaveEnemies(int roundSeed, int wave, WaveEnemySpec spec) {
  final rng = Random(roundSeed * 100003 + wave);
  final mult = pow(spec.growth, wave - 1).toDouble();
  final elements = Element.values;
  // 회차 seed 로 시작 색을 섞어, 회차마다 순서가 달라지게 한다.
  final element = elements[(roundSeed + wave) % elements.length];
  return [
    for (var i = 0; i < spec.count; i++)
      BattleBug(
        id: 'w${wave}_$i',
        name: 'W$wave-${i + 1}',
        element: element,
        temperament: Temperament.values[rng.nextInt(Temperament.values.length)],
        preferredStance: Stance.values[rng.nextInt(Stance.values.length)],
        maxHp: spec.baseHp * mult,
        atk: spec.baseAtk * mult,
        def: spec.baseDef * mult,
        spd: spec.baseSpd * mult,
      ),
  ];
}

/// 웨이브 방어전 한 판의 결과(실물 경품 이벤트 §3-1).
///
/// 점수는 여기서 계산하지 않는다 — 점수식은 밸런스라 `event.json` 에 있고,
/// 이 패키지는 **전투만** 안다(§4 의존 방향).
class WaveRunResult {
  const WaveRunResult({
    required this.clearedWaves,
    required this.hpPctAtLastWave,
    required this.survivors,
    required this.totalRounds,
    required this.waves,
  });

  /// **클리어한** 웨이브 수. 1웨이브에서 지면 0이다.
  final int clearedWaves;

  /// 마지막으로 **시작한** 웨이브 진입 시점의 팀 잔여 체력 비율(0~1).
  ///
  /// 종료 시점이 아니라 진입 시점인 이유: 마지막 웨이브는 대개 전멸로 끝나므로
  /// 종료 시점을 쓰면 상위권이 전부 0이 되어 동점이 쏟아진다.
  final double hpPctAtLastWave;

  /// 판이 끝난 시점에 살아 있던 곤충 수.
  final int survivors;

  /// 전 웨이브 합계 라운드 수(같은 웨이브까지 갔다면 빨리 끝낸 쪽이 낫다).
  final int totalRounds;

  /// 웨이브별 전투 기록 — 앱이 재생하는 데 쓴다.
  final List<BattleResult> waves;
}

/// **웨이브 방어전**: 팀 하나로 적 웨이브를 연속으로 상대한다.
///
/// - 체력은 **이월**된다. 웨이브를 깨면 [waveHealPct] 만큼만 회복하고,
///   쓰러진 곤충은 **되살아나지 않는다**. 완전 회복이면 "한 웨이브를 이기면
///   무한히 간다"가 되어 순위가 갈리지 않는다.
/// - 적 팀은 [enemyOf] 가 만든다. 웨이브 구성 규칙(오행 회전·스탯 성장)은
///   밸런스이므로 호출부(서버)가 정하고, 이 함수는 전투만 돌린다.
/// - 같은 `seed`·팀·`enemyOf` 면 **항상 같은 결과**다(§2.3 결정론). 서버가 계산한
///   판을 앱이 그대로 재생할 수 있는 근거다.
WaveRunResult simulateWaveRun({
  required int seed,
  required List<BattleBug> team,
  required List<BattleBug> Function(int wave) enemyOf,
  required int maxWave,
  required double waveHealPct,
}) {
  final maxHp = [for (final u in team) u.maxHp];
  final hp = [...maxHp];
  final totalMax = maxHp.fold(0.0, (s, v) => s + v);
  final waves = <BattleResult>[];

  var cleared = 0;
  var rounds = 0;
  // 마지막으로 **진입한** 웨이브의 시작 체력 — 첫 웨이브는 만피로 들어간다.
  var hpPctAtEntry = totalMax <= 0 ? 0.0 : 1.0;

  for (var w = 1; w <= maxWave; w++) {
    if (hp.every((v) => v <= 0)) break;
    hpPctAtEntry = totalMax <= 0
        ? 0.0
        : hp.fold(0.0, (s, v) => s + v) / totalMax;

    // 웨이브마다 다른 스트림을 쓴다 — 같은 seed 로 매 웨이브가 똑같이 흐르면
    // 상성이 아니라 난수 패턴을 외우는 게임이 된다.
    //
    // `simulate` 대신 상태를 직접 굴린다 — 결과와 **개체별 체력**이 둘 다
    // 필요한데(체력 이월), `BattleResult` 는 팀 합계 비율만 준다.
    final st = initBattle(
      seed + w * 7919,
      team,
      enemyOf(w),
      initialHpA: hp,
      maxRounds: kMaxEventRounds,
    );
    var guard = 0;
    while (!st.done && guard < kMaxEventRounds * 2) {
      st.step();
      guard++;
    }
    final result = st.toResult();
    waves.add(result);
    rounds += result.rounds;
    for (var i = 0; i < hp.length; i++) {
      hp[i] = st.hpA[i];
    }

    if (result.outcome != BattleOutcome.teamA) break;
    cleared = w;

    // 클리어 보상 회복 — **살아 있는 곤충만**. 전멸한 자리는 그대로 둔다.
    if (waveHealPct > 0) {
      for (var i = 0; i < hp.length; i++) {
        if (hp[i] > 0) {
          hp[i] = (hp[i] + maxHp[i] * waveHealPct).clamp(0.0, maxHp[i]);
        }
      }
    }
  }

  return WaveRunResult(
    clearedWaves: cleared,
    hpPctAtLastWave: hpPctAtEntry,
    survivors: hp.where((v) => v > 0).length,
    totalRounds: rounds,
    waves: waves,
  );
}

/// 웨이브 [wave] 의 [index] 번째 적이 **어떤 종의 모습인가**.
///
/// 적 스탯은 `eventWaveEnemies` 가 만들지만 그림은 종에서 온다. 새 아트를 그리지
/// 않고 **이미 있는 곤충 20종을 돌려쓴다** — 대회 적도 결국 이 숲의 곤충이다.
///
/// 앱만 쓰는 함수다(서버는 그림을 모른다). 그래도 여기 두는 이유는 **같은 seed 로
/// 같은 종**이 나와야 재생이 서버 판과 어긋나 보이지 않기 때문이다.
String? eventWaveSpeciesId(
  int roundSeed,
  int wave,
  int index,
  List<String> speciesIds,
) {
  if (speciesIds.isEmpty) return null;
  final rng = Random(roundSeed * 100003 + wave * 31 + index * 7);
  return speciesIds[rng.nextInt(speciesIds.length)];
}

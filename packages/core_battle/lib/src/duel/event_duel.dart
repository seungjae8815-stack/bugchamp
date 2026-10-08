import 'dart:math' as math;

import 'package:core_models/core_models.dart';
import 'package:meta/meta.dart';

import 'duel_bug.dart';
import 'duel_engine.dart';
import 'duel_params.dart';

/// 왕충 선발대회 — **곤충 1마리 · 결투 엔진 웨이브전**(2026-09-29 사장님 확정, 2회차부터).
///
/// 내가 제일 잘 키운 곤충 한 마리가 결투와 **같은 능력치**로 나가 적을 한 마리씩 연속으로 상대한다.
/// 체력은 이월되고(웨이브를 깨면 [EventDuelSpec.healPct] + 곤충 회복력만큼 회복), 지면 끝.
/// 웨이브를 깰 때마다 카드 3장 중 1장(로그라이크 — 판단이 개입하는 자리).
///
/// 이 규칙이 **core_battle 에 있는 이유**: 앱(재생·개발자 체험)과 서버(점수 확정)가 같은 함수로
/// 같은 판을 만들어야 한다. 두 벌이면 "서버는 졌다는데 화면은 이겼다"가 생긴다.
/// 수치는 `event.json → duelWave`(§6) — 여기 기본값은 폴백일 뿐이다.
@immutable
class EventDuelSpec {
  const EventDuelSpec({
    this.baseHp = 90,
    this.baseAtk = 35,
    this.baseDef = 30,
    this.baseSpd = 30,
    this.growth = 1.08,
    this.enemySizeMm = 50,
    this.healPct = 0.2,
    this.maxWave = 200,
    this.fallPenalty = 0.3,
    this.injuryMinRatio = 0.2,
    this.cardCaps = const {'evade': 0.24, 'crit': 0.3, 'size': 0.8},
  });

  /// 1웨이브 적의 능력치. 웨이브마다 × [growth].
  final double baseHp;
  final double baseAtk;
  final double baseDef;
  final double baseSpd;
  final double growth;

  /// 적의 몸 크기(mm) — 무게·반경. 종마다 다르게 하면 웨이브 난이도가 종 뽑기 운이 된다.
  final double enemySizeMm;

  /// 웨이브를 깼을 때 회복(최대 체력 비율). 곤충 회복력(훈련소)이 더해진다.
  final double healPct;

  /// 집계 상한. 닿으면 동점이 쏟아지므로 아무도 닿지 않을 만큼 크게 둔다.
  final int maxWave;

  /// 장외·뒤집기·시간으로 졌을 때 깎이는 체력(최대 체력 비율) — 그 뒤 **같은 웨이브를 다시** 싸운다.
  /// 물리 결투는 체력이 많아도 한 판을 장외로 질 수 있어서, 한 번 지면 끝이면 센 곤충도 2웨이브에서
  /// 끝나는 운 게임이 됐다(시뮬: 전 등급 최소 1웨이브). 체력이 목숨이라 잘 키운 곤충이 오래 버틴다.
  /// 체력이 0 이 되면(기절 또는 이 벌칙으로 바닥) 끝.
  final double fallPenalty;

  /// 끝난 뒤 부상 = 등급별 최대 부상 × max(이 값, 잃은 체력 비율)(2026-09-30 사장님 확정 A안).
  /// 체력을 남기고 **그만두면** 덜 쉬고, 바닥나서 끝나면 최대. 앱을 강제로 끄면 시작할 때 건 최대가 남는다.
  final double injuryMinRatio;

  /// 카드 종류(kind)별 **누적 상한**(더한 값의 합). 없는 kind 는 상한 없음.
  /// 무게 싣기만 계속 고르면 300판 중 92% 가 [maxWave] 에 닿았고, 날렵함은 회피가 100% 를 넘었다
  /// (2026-09-30 점검). 상한에 닿은 카드는 뽑혀도 효과가 없다 — 다른 카드를 고르게 된다.
  final Map<String, double> cardCaps;

  /// [kind] 카드를 [value] 만큼 더한 뒤 상한으로 자른 값.
  double capCard(String kind, double current, double value) {
    final cap = cardCaps[kind];
    final next = current + value;
    return cap == null ? next : math.min(cap, next);
  }

  /// [kind] 카드가 이미 상한([cardCaps])에 닿았나 — [current] 는 지금 쌓인 값.
  /// 카드 화면이 "최대치"로 표시한다(2026-10-05 문의: 여러 장 골라도 수치가 그대로).
  bool cardMaxed(String kind, double current) {
    final cap = cardCaps[kind];
    return cap != null && current >= cap - 1e-9;
  }

  /// 끝난 체력 [hpLeft](0~1)에 맞춘 부상 비율(0~1).
  double injuryRatio(double hpLeft) =>
      math.max(injuryMinRatio, 1 - hpLeft.clamp(0.0, 1.0));

  factory EventDuelSpec.fromJson(Map<String, dynamic>? j) {
    if (j == null) return const EventDuelSpec();
    const d = EventDuelSpec();
    double n(String k, double v) => (j[k] as num?)?.toDouble() ?? v;
    return EventDuelSpec(
      baseHp: n('baseHp', d.baseHp),
      baseAtk: n('baseAtk', d.baseAtk),
      baseDef: n('baseDef', d.baseDef),
      baseSpd: n('baseSpd', d.baseSpd),
      growth: n('growth', d.growth),
      enemySizeMm: n('enemySizeMm', d.enemySizeMm),
      healPct: n('healPct', d.healPct),
      maxWave: (j['maxWave'] as num?)?.toInt() ?? d.maxWave,
      fallPenalty: n('fallPenalty', d.fallPenalty),
      injuryMinRatio: n('injuryMinRatio', d.injuryMinRatio),
      cardCaps: j['cardCaps'] is Map
          ? {
              for (final e in (j['cardCaps'] as Map).entries)
                if (e.value is num) '${e.key}': (e.value as num).toDouble(),
            }
          : d.cardCaps,
    );
  }
}

/// 웨이브 [wave] 의 적 한 마리 — **회차 seed 하나로 전부 결정**된다(같은 회차면 모두 같은 적).
///
/// 모습(종)은 호출자가 `eventWaveSpeciesId` 로 고르고 그 종의 주특기를 넘긴다. 오행은 웨이브마다
/// 회전한다 — 한 속성 곤충은 자기가 약한 색의 웨이브에서 반드시 고비를 맞는다.
DuelBug eventDuelEnemy({
  required int roundSeed,
  required int wave,
  required EventDuelSpec spec,
  required String speciesId,
  required Specialty specialty,
  String? name,
}) {
  final rng = math.Random(roundSeed * 100003 + wave);
  final mult = math.pow(spec.growth, wave - 1).toDouble();
  return DuelBug(
    id: 'w$wave',
    name: name ?? 'W$wave',
    speciesId: speciesId,
    element: Element.values[(roundSeed + wave) % Element.values.length],
    temperament: Temperament.values[rng.nextInt(Temperament.values.length)],
    specialty: specialty,
    sizeMm: spec.enemySizeMm,
    maxHp: spec.baseHp * mult,
    atk: spec.baseAtk * mult,
    def: spec.baseDef * mult,
    spd: spec.baseSpd * mult,
  );
}

/// 한 판(대회 1회 도전)의 진행 상태 — 서버 세션에 그대로 저장되고 앱이 받아 그린다.
@immutable
class EventDuelRun {
  const EventDuelRun({
    this.wave = 1,
    this.cleared = 0,
    this.hpPct = 1,
    this.hpAtEntry = 1,
    this.atk = 0,
    this.def = 0,
    this.maxHp = 0,
    this.revives = 0,
    this.reviveHp = 0,
    this.ticks = 0,
    this.over = false,
    this.evade = 0,
    this.crit = 0,
    this.recover = 0,
    this.size = 0,
    this.spd = 0,
    this.lastStand = 0,
  });

  /// 다음에 싸울 웨이브(1부터).
  final int wave;

  /// 깬 웨이브 수(점수의 본체).
  final int cleared;

  /// 지금 체력(0~1).
  final double hpPct;

  /// 마지막으로 **들어간** 웨이브의 시작 체력 — 동점 가르기(끝 체력은 늘 0 이라 못 쓴다).
  final double hpAtEntry;

  /// 카드로 쌓인 강화(+비율).
  final double atk;
  final double def;
  final double maxHp;

  /// 남은 부활 수와 부활 체력.
  final int revives;
  final double reviveHp;

  /// 누적 틱(같은 웨이브면 빨리 끝낸 쪽이 위).
  final int ticks;

  /// 끝났나(졌고 부활이 없다 · 상한 도달).
  final bool over;

  // ── 카드 2차(2026-09-30 사장님 확정: A 결투 능력치 전부 + B 대가 있는 카드 셋) ──

  /// 회피 확률 가산(날렵함).
  final double evade;

  /// 치명 확률 가산(급소 노리기).
  final double crit;

  /// 웨이브 사이 회복 가산(숨 고르기) — 곤충 회복력처럼 더해진다.
  final double recover;

  /// 몸집 배율 가산(무게 싣기) — 무게·반경이 커져 장외에 버틴다.
  final double size;

  /// 속도 배율 가산(철갑의 대가로 음수).
  final double spd;

  /// 배수진 — 체력 50% 미만으로 들어가는 웨이브에서만 공격 +.
  final double lastStand;

  EventDuelRun _copy({
    int? wave,
    int? cleared,
    double? hpPct,
    double? hpAtEntry,
    double? atk,
    double? def,
    double? maxHp,
    int? revives,
    double? reviveHp,
    int? ticks,
    bool? over,
    double? evade,
    double? crit,
    double? recover,
    double? size,
    double? spd,
    double? lastStand,
  }) => EventDuelRun(
    wave: wave ?? this.wave,
    cleared: cleared ?? this.cleared,
    hpPct: hpPct ?? this.hpPct,
    hpAtEntry: hpAtEntry ?? this.hpAtEntry,
    atk: atk ?? this.atk,
    def: def ?? this.def,
    maxHp: maxHp ?? this.maxHp,
    revives: revives ?? this.revives,
    reviveHp: reviveHp ?? this.reviveHp,
    ticks: ticks ?? this.ticks,
    over: over ?? this.over,
    evade: evade ?? this.evade,
    crit: crit ?? this.crit,
    recover: recover ?? this.recover,
    size: size ?? this.size,
    spd: spd ?? this.spd,
    lastStand: lastStand ?? this.lastStand,
  );

  /// 카드 적용 — `heal`(즉시 회복) · `atk`/`def`/`maxHp`(판 끝까지 +비율) ·
  /// `revive`(지면 한 번 그 체력으로 같은 웨이브 재도전) · `skip`(다음 웨이브 건너뛰기).
  /// 모르는 종류는 무시한다(앱·서버 배포 시점이 달라도 안 깨지게).
  /// [kind] 카드를 더 골라도 효과가 없나(누적 상한에 닿음) — 카드 화면의 "최대치" 표시.
  bool cardMaxed(String kind, EventDuelSpec spec) => switch (kind) {
    'evade' => spec.cardMaxed(kind, evade),
    'crit' => spec.cardMaxed(kind, crit),
    'recover' => spec.cardMaxed(kind, recover),
    'size' => spec.cardMaxed(kind, size),
    _ => false,
  };

  EventDuelRun applyCard(String kind, double value, EventDuelSpec spec) =>
      switch (kind) {
        'heal' => _copy(hpPct: math.min(1.0, hpPct + value)),
        'atk' => _copy(atk: atk + value),
        'def' => _copy(def: def + value),
        'maxHp' => _copy(maxHp: maxHp + value),
        'revive' => _copy(
          revives: revives + 1,
          reviveHp: math.max(reviveHp, value),
        ),
        'skip' => _copy(
          cleared: wave,
          wave: wave + 1,
          over: wave >= spec.maxWave,
        ),
        // A — 결투 능력치
        'evade' => _copy(evade: spec.capCard(kind, evade, value)),
        'crit' => _copy(crit: spec.capCard(kind, crit, value)),
        'recover' => _copy(recover: spec.capCard(kind, recover, value)),
        'size' => _copy(size: spec.capCard(kind, size, value)),
        // B — 대가가 있는 카드(대가 비율은 규칙값: 광폭화 방어 −0.6배 · 철갑 속도 −0.4배)
        'berserk' => _copy(atk: atk + value, def: def - value * 0.6),
        'ironhide' => _copy(def: def + value, spd: spd - value * 0.4),
        'lastStand' => _copy(lastStand: lastStand + value),
        _ => this,
      };

  /// 배수진이 켜지는 체력(이 아래로 들어가는 웨이브).
  static const lastStandBelow = 0.5;

  /// 그만하기 — 지금까지의 기록으로 끝낸다(체력은 그대로 — 부상이 줄어든다).
  EventDuelRun quit() => _copy(over: true);

  /// 카드가 입혀진 내 곤충(배수진은 지금 체력이 [lastStandBelow] 미만일 때만).
  DuelBug dress(DuelBug bug) {
    final rage = hpPct < lastStandBelow ? lastStand : 0.0;
    final b = bug
        .withTraining(
          atkMult: 1 + atk + rage,
          // 광폭화를 겹쳐도 방어가 0 이 되지 않게.
          defMult: math.max(0.3, 1 + def),
          hpMult: 1 + maxHp,
          evade: evade,
          crit: crit,
        )
        .copyWith(sizeMm: bug.sizeMm * (1 + size));
    return b.withCombatStats(
      maxHp: b.maxHp,
      atk: b.atk,
      def: b.def,
      spd: b.spd * math.max(0.4, 1 + spd),
    );
  }

  /// 판 사이 회복에 더해지는 몫(곤충 회복력 + 숨 고르기).
  double recoveryOf(DuelBug bug) => bug.recovery + recover;

  Map<String, dynamic> toJson() => {
    'w': wave,
    'c': cleared,
    'hp': hpPct,
    'he': hpAtEntry,
    'atk': atk,
    'def': def,
    'mhp': maxHp,
    'rv': revives,
    'rvh': reviveHp,
    't': ticks,
    'o': over,
    if (evade != 0) 'ev': evade,
    if (crit != 0) 'cr': crit,
    if (recover != 0) 'rc': recover,
    if (size != 0) 'sz': size,
    if (spd != 0) 'sp': spd,
    if (lastStand != 0) 'ls': lastStand,
  };

  factory EventDuelRun.fromJson(Map<String, dynamic> j) => EventDuelRun(
    wave: (j['w'] as num?)?.toInt() ?? 1,
    cleared: (j['c'] as num?)?.toInt() ?? 0,
    hpPct: (j['hp'] as num?)?.toDouble() ?? 1,
    hpAtEntry: (j['he'] as num?)?.toDouble() ?? 1,
    atk: (j['atk'] as num?)?.toDouble() ?? 0,
    def: (j['def'] as num?)?.toDouble() ?? 0,
    maxHp: (j['mhp'] as num?)?.toDouble() ?? 0,
    revives: (j['rv'] as num?)?.toInt() ?? 0,
    reviveHp: (j['rvh'] as num?)?.toDouble() ?? 0,
    ticks: (j['t'] as num?)?.toInt() ?? 0,
    over: j['o'] as bool? ?? false,
    evade: (j['ev'] as num?)?.toDouble() ?? 0,
    crit: (j['cr'] as num?)?.toDouble() ?? 0,
    recover: (j['rc'] as num?)?.toDouble() ?? 0,
    size: (j['sz'] as num?)?.toDouble() ?? 0,
    spd: (j['sp'] as num?)?.toDouble() ?? 0,
    lastStand: (j['ls'] as num?)?.toDouble() ?? 0,
  );
}

/// 웨이브 한 판을 싸운 결과.
typedef EventDuelStep = ({EventDuelRun run, DuelBout bout, bool won});

/// 지금 웨이브를 싸운다(게이지 [launch] 는 이 판 던지기 값, null 이면 자동값).
///
/// 이기면 다음 웨이브로(체력 = 끝 체력 + 회복 + 곤충 회복력). 장외·뒤집기·시간으로 지면 체력이
/// [EventDuelSpec.fallPenalty] 깎이고 같은 웨이브를 다시. 체력이 바닥나면(기절 포함) 부활이 있으면
/// 그 체력으로 같은 웨이브를, 없으면 끝. 판 시드는 도전 시드·웨이브·누적 틱에서 갈라진다
/// (다시 싸울 때 같은 판이 되풀이되지 않게).
///
/// 탭 반격: [clutchScores] 는 이 웨이브 한 판에서 내 곤충 위기에 순서대로 넣을 점수. 다 떨어졌는데
/// 새 위기가 오면 판이 멈추고 `bout.pending` 이 채워진다 — 그때 돌려주는 run 은 **입력 그대로**
/// (won = false)이고, 점수를 하나 늘려 같은 인자로 다시 부르면 같은 판이 이어진다. null 이면 자동 점수.
/// 적은 늘 자동 점수.
EventDuelStep eventDuelFight({
  required int seed,
  required EventDuelRun run,
  required DuelBug bug,
  required DuelBug enemy,
  required DuelParams params,
  required EventDuelSpec spec,
  double? launch,
  List<double>? clutchScores,
}) {
  final bout = simulateBout(
    seed: duelBoutSeed(seed ^ run.ticks, run.wave),
    a: run.dress(bug),
    b: enemy,
    params: params,
    launchA: launch,
    hpA: run.hpPct,
    clutchScores: clutchScores,
  );
  // 내 곤충 위기에서 멈췄다 — 진행 상태는 그대로(점수를 늘려 같은 인자로 다시 부르면 이어진다).
  if (bout.pending != null) return (run: run, bout: bout, won: false);
  final ticks = run.ticks + bout.ticks;
  if (bout.aWon) {
    final next = run._copy(
      cleared: run.wave,
      wave: run.wave + 1,
      hpPct: (bout.hpPctA + spec.healPct + run.recoveryOf(bug)).clamp(
        0.05,
        1.0,
      ),
      ticks: ticks,
      over: run.wave >= spec.maxWave,
    );
    return (run: next._copy(hpAtEntry: next.hpPct), bout: bout, won: true);
  }
  // 장외·뒤집기·시간 — 체력이 남으면 깎고 같은 웨이브를 다시.
  if (bout.finish != DuelFinish.knockout) {
    final left = bout.hpPctA - spec.fallPenalty;
    if (left > 0) {
      return (
        run: run._copy(hpPct: left, hpAtEntry: left, ticks: ticks),
        bout: bout,
        won: false,
      );
    }
  }
  if (run.revives > 0) {
    final hp = run.reviveHp.clamp(0.05, 1.0);
    return (
      run: run._copy(
        revives: run.revives - 1,
        hpPct: hp,
        hpAtEntry: hp,
        ticks: ticks,
      ),
      bout: bout,
      won: false,
    );
  }
  return (
    run: run._copy(hpPct: 0, ticks: ticks, over: true),
    bout: bout,
    won: false,
  );
}

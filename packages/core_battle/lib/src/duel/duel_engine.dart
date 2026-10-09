import 'dart:math' as math;

import 'package:core_models/core_models.dart';
import 'package:meta/meta.dart';

import 'duel_bug.dart';
import 'duel_params.dart';

/// 한 판이 끝난 방법.
enum DuelFinish {
  ringOut('ringOut'), // 장외
  flip('flip'), // 뒤집기
  knockout('knockout'), // 기절(체력 0)
  timeUp('timeUp'); // 시간 종료 — 체력 % 판정

  const DuelFinish(this.key);
  final String key;

  static DuelFinish fromKey(String k) =>
      values.firstWhere((e) => e.key == k, orElse: () => timeUp);
}

/// 궤적 위의 사건 — 앱이 효과를 띄우는 시점.
enum DuelEventKind {
  clash('clash'),
  grip('grip'),
  toss('toss'),
  land('land'),
  dodge('dodge'),
  flip('flip'),
  ringOut('ringOut'),
  knockout('knockout'),

  /// 크리티컬(who = 때린 쪽, value = 그 피해).
  crit('crit'),

  /// 약점 공격(who = 때린 쪽, value = 그 피해).
  weak('weak'),

  /// 회피 — 부딪힘 피해를 통째로 피했다(who = 피한 쪽).
  evade('evade'),

  /// 탭 반격 위기가 시작됐다(who = 위기에 빠진 쪽, value = [DuelCrisis.index]).
  /// 플레이어 쪽이고 점수가 아직 없으면 판이 **이 사건에서 멈춘다**(`DuelBout.pending`).
  clutch('clutch'),

  /// 탭 반격 성공(who = 살아난 쪽, value = 점수 천분율).
  clutchSave('clutchSave'),

  /// 탭 반격 실패(who = 위기에 빠진 쪽, value = 점수 천분율) — 뒤이어 결판 사건이 온다.
  clutchFail('clutchFail');

  const DuelEventKind(this.key);
  final String key;

  static DuelEventKind fromKey(String k) =>
      values.firstWhere((e) => e.key == k, orElse: () => clash);
}

/// 탭 반격 위기의 종류(docs/design_training_v2.md §4).
enum DuelCrisis {
  /// 버티기(장외) — 성공하면 반지름 `clutchRestoreRatio` 지점으로 되돌아가고 속도 0.
  ringOut('ringOut'),

  /// 버티기(뒤집기) — 성공하면 뒤집기 취소.
  flip('flip'),

  /// 깨우기(기절) — 성공하면 체력 = 최대 × (`clutchWakeHp` + 근성 × `clutchWakeHpPerGrit`).
  knockout('knockout');

  const DuelCrisis(this.key);
  final String key;

  static DuelCrisis fromKey(String k) =>
      values.firstWhere((e) => e.key == k, orElse: () => knockout);
}

/// 플레이어 쪽 위기에서 **점수를 기다리며 멈춘** 자리.
///
/// 서버는 상태를 들고 있지 않는다 — 앱이 점수를 보내면 **같은 seed 로 처음부터** 점수 목록을 늘려
/// 다시 계산한다(같은 입력이면 같은 판이 재현된다).
@immutable
class DuelClutchPending {
  const DuelClutchPending({
    required this.kind,
    required this.tick,
    required this.index,
    this.bout = 0,
  });

  final DuelCrisis kind;

  /// 멈춘 틱(이 틱의 `clutch` 사건이 마지막 사건이다).
  final int tick;

  /// 몇 번째 플레이어 위기인지(0부터) = 지금까지 받은 점수 수. 다음 점수가 이 자리에 들어간다.
  /// 경기(`simulateDuel`)에서는 경기 전체에서 센다.
  final int index;

  /// 경기 안의 판 번호(0부터, 한 판 시뮬에서는 0).
  final int bout;

  DuelClutchPending withBout(int bout, int index) =>
      DuelClutchPending(kind: kind, tick: tick, index: index, bout: bout);

  Map<String, dynamic> toJson() => {
    'k': kind.key,
    't': tick,
    'i': index,
    'b': bout,
  };

  factory DuelClutchPending.fromJson(Map<String, dynamic> j) =>
      DuelClutchPending(
        kind: DuelCrisis.fromKey('${j['k']}'),
        tick: (j['t'] as num).toInt(),
        index: (j['i'] as num).toInt(),
        bout: (j['b'] as num?)?.toInt() ?? 0,
      );
}

@immutable
class DuelEvent {
  const DuelEvent({
    required this.tick,
    required this.kind,
    required this.who,
    this.value = 0,
  });

  final int tick;
  final DuelEventKind kind;

  /// 행위자(0 = A, 1 = B). 결판 사건(flip·ringOut·knockout)은 **진 쪽**.
  final int who;

  /// 부가 값(충돌 = 준 피해 합, 잡기·던지기 = 준 피해).
  final int value;

  List<Object> toJson() => [tick, kind.key, who, value];

  factory DuelEvent.fromJson(List<dynamic> j) => DuelEvent(
    tick: (j[0] as num).toInt(),
    kind: DuelEventKind.fromKey('${j[1]}'),
    who: (j[2] as num).toInt(),
    value: (j[3] as num).toInt(),
  );
}

/// 프레임 플래그(비트). 앱이 자세·효과를 고른다.
abstract final class DuelFlag {
  static const airborne = 1;
  static const gripping = 2;
  static const gripped = 4;
  static const dashing = 8;
  static const flipped = 16;
  static const out = 32;
  static const knocked = 64;
}

/// 한 판의 결과 + 재생용 궤적.
///
/// 프레임 한 줄 = `[ax, ay, avx, avy, ahp, aflags, bx, by, bvx, bvy, bhp, bflags]`.
/// 좌표·속도는 ×10 정수(경기장 반지름 100 → ±1000), 체력은 천분율. **y 는 위쪽이 +** 다.
/// 정수로 양자화해 응답 크기를 줄인다(한 판 수 KB).
@immutable
class DuelBout {
  const DuelBout({
    required this.winner,
    required this.finish,
    required this.ticks,
    required this.hpPctA,
    required this.hpPctB,
    required this.frames,
    required this.events,
    required this.launchA,
    required this.launchB,
    this.pending,
  });

  /// 0 = A 승, 1 = B 승. 무승부는 없다(시간 판정 → SPD → 무게 → 시드).
  /// 위기에서 멈춘 판([pending] 이 있음)은 -1 — 아직 끝나지 않았다.
  final int winner;
  final DuelFinish finish;
  final int ticks;
  final double hpPctA;
  final double hpPctB;
  final List<List<int>> frames;
  final List<DuelEvent> events;

  /// 이 판에 쓴 게이지 값(0~1).
  final double launchA;
  final double launchB;

  /// 플레이어(A) 위기에서 점수를 기다리며 멈췄으면 그 자리. 멈춘 판의 [frames] 는 멈춘 틱 **전까지**의
  /// 정규 프레임이라, 점수를 넣고 다시 계산한 판의 frames 앞부분과 정확히 같다(events 도 앞부분이 같다).
  final DuelClutchPending? pending;

  bool get aWon => winner == 0;

  /// 끝난 판인가(위기에서 멈추지 않았다).
  bool get done => pending == null;

  /// 이 판에서 플레이어(A)가 점수를 쓴 위기 수(멈춘 위기는 빼고).
  int get playerClutches => events
      .where(
        (e) =>
            e.who == 0 &&
            (e.kind == DuelEventKind.clutchSave ||
                e.kind == DuelEventKind.clutchFail),
      )
      .length;

  Map<String, dynamic> toJson() => {
    'w': winner,
    'f': finish.key,
    't': ticks,
    'ha': (hpPctA * 1000).round(),
    'hb': (hpPctB * 1000).round(),
    'la': (launchA * 1000).round(),
    'lb': (launchB * 1000).round(),
    'fr': frames,
    'ev': [for (final e in events) e.toJson()],
    if (pending != null) 'pc': pending!.toJson(),
  };

  factory DuelBout.fromJson(Map<String, dynamic> j) => DuelBout(
    winner: (j['w'] as num).toInt(),
    finish: DuelFinish.fromKey('${j['f']}'),
    ticks: (j['t'] as num).toInt(),
    hpPctA: (j['ha'] as num).toDouble() / 1000,
    hpPctB: (j['hb'] as num).toDouble() / 1000,
    launchA: ((j['la'] as num?) ?? 0).toDouble() / 1000,
    launchB: ((j['lb'] as num?) ?? 0).toDouble() / 1000,
    frames: [
      for (final f in (j['fr'] as List))
        [for (final v in (f as List)) (v as num).toInt()],
    ],
    events: [for (final e in (j['ev'] as List)) DuelEvent.fromJson(e as List)],
    pending: j['pc'] is Map
        ? DuelClutchPending.fromJson(Map<String, dynamic>.from(j['pc'] as Map))
        : null,
  );
}

/// 판마다 다른 시드 — 같은 경기 시드에서 판 번호로 갈라진다(결정론).
int duelBoutSeed(int matchSeed, int boutIndex) =>
    (matchSeed ^ (0x9E3779B1 * (boutIndex + 1))) & 0x7fffffff;

/// 탭 반격 자동 점수 전용 난수 — 판 seed 에서 쪽마다 갈라진다. 물리 난수(`Random(seed)`)와 **따로**
/// 둬서 위기 처리가 물리 난수 소비 순서를 바꾸지 않는다(리플레이·옛 테스트 결정론).
int duelClutchSeed(int boutSeed, int side) =>
    (boutSeed ^ (side == 0 ? 0x6E8A5F13 : 0x2C1B3C6D)) & 0x7fffffff;

class _Body {
  _Body(this.bug, this.p, this.side)
    : r = bug.radius(p),
      m = bug.mass(p),
      maxSpeed = bug.maxSpeed(p),
      hp = bug.maxHp;

  final DuelBug bug;
  final DuelParams p;
  final int side;
  final double r;
  final double m;
  final double maxSpeed;
  double hp;

  double x = 0, y = 0, vx = 0, vy = 0;
  Temperament style = Temperament.steadfast;
  int flankSide = 1;

  double dashCd = 0;
  double dashTimer = 0;
  double strikeCd = 0;
  double gripCd = 0;
  double tossCd = 0;
  double gripTimer = 0;
  double air = 0;
  double landDamage = 0;
  bool flipped = false;
  int dodgedDash = -1;
  int dashId = 0;

  /// 이 판에서 남은 탭 반격 횟수.
  int clutchLeft = 0;

  bool get grounded => air <= 0;
  double get hpPct => bug.maxHp <= 0 ? 0 : (hp / bug.maxHp).clamp(0, 1);
  double get dist => math.sqrt(x * x + y * y);
}

/// 한 판(1:1) 시뮬레이션 — **완전 결정론**(시드·입력이 같으면 결과가 같다, §2.3).
///
/// [launchA]·[launchB] 는 던지기 게이지 값(0~1). 게이지 없이 던지면 `params.launchAuto`.
///
/// **탭 반격**(`params.clutchEnabled`): A 가 플레이어 쪽이다. [clutchScores] 는 A 의 위기에 **순서대로**
/// 넣을 탭 점수(0~1). 목록이 다 떨어졌는데 A 에게 새 위기가 오면 그 틱에서 멈추고
/// [DuelBout.pending] 에 자리를 적어 돌려준다(winner = -1). null 이면 A 도 자동 점수(구버전 앱·시뮬).
/// B 는 늘 자동 점수다(판 seed 기반 전용 난수 — [duelClutchSeed]).
DuelBout simulateBout({
  required int seed,
  required DuelBug a,
  required DuelBug b,
  required DuelParams params,
  double? launchA,
  double? launchB,
  double hpA = 1,
  double hpB = 1,
  List<double>? clutchScores,
}) {
  final p = params;
  final rng = math.Random(seed);
  final clutchRng = [
    math.Random(duelClutchSeed(seed, 0)),
    math.Random(duelClutchSeed(seed, 1)),
  ];
  var scoreAt = 0;
  DuelClutchPending? pending;
  final la = (launchA ?? p.launchAuto).clamp(0.0, 1.0);
  final lb = (launchB ?? p.launchAuto).clamp(0.0, 1.0);
  // 전력 압축(A안) — 두 값의 비율만 지수로 누른다(기하평균 유지). 게이지 보너스(B안)는 누른 뒤에 곱한다.
  (double, double) squeeze(double x, double y) {
    if (p.statCompress >= 1 || x <= 0 || y <= 0) return (x, y);
    final m = math.sqrt(x * y);
    return (
      m * math.pow(x / m, p.statCompress).toDouble(),
      m * math.pow(y / m, p.statCompress).toDouble(),
    );
  }

  double launchPower(double q) => p.launchPowerMax <= 0 || p.launchAuto >= 1
      ? 1
      : 1 +
            p.launchPowerMax *
                ((q - p.launchAuto) / (1 - p.launchAuto)).clamp(0.0, 1.0);
  // 사이즈 몫 덜어내기 — 스탯에 구워진 사이즈 배율을 결투에서는 sizeStatExp 만큼만 남긴다.
  double unsize(DuelBug x) => p.sizeStatExp == 1 || x.sizeStatMult == 1
      ? 1
      : math.pow(x.sizeStatMult, p.sizeStatExp - 1).toDouble();
  final ua = unsize(a), ub = unsize(b);
  final (hpa, hpb) = squeeze(a.maxHp * ua, b.maxHp * ub);
  final (atka, atkb) = squeeze(a.atk * ua, b.atk * ub);
  final (defa, defb) = squeeze(a.def * ua, b.def * ub);
  final (spda, spdb) = squeeze(a.spd * ua, b.spd * ub);
  final bodies = [
    _Body(
      a.withCombatStats(
        maxHp: hpa,
        atk: atka * launchPower(la),
        def: defa,
        spd: spda,
      ),
      p,
      0,
    ),
    _Body(
      b.withCombatStats(
        maxHp: hpb,
        atk: atkb * launchPower(lb),
        def: defb,
        spd: spdb,
      ),
      p,
      1,
    ),
  ];
  // 승자 연속 — 이긴 곤충은 남은 체력으로 들어온다.
  bodies[0].hp = bodies[0].bug.maxHp * hpA.clamp(0.01, 1.0);
  bodies[1].hp = bodies[1].bug.maxHp * hpB.clamp(0.01, 1.0);
  for (final s in bodies) {
    s.clutchLeft = !p.clutchEnabled
        ? 0
        : p.clutchUses + (s.bug.gritOf(p) >= p.clutchBonusUseGrit ? 1 : 0);
  }
  final dt = p.dt;
  final radius = p.arenaRadius;

  // 기질 — 변덕은 판마다 넷 중 하나(시드).
  for (final s in bodies) {
    var t = s.bug.temperament;
    if (t == Temperament.fickle) {
      const pick = [
        Temperament.aggressive,
        Temperament.cautious,
        Temperament.cunning,
        Temperament.steadfast,
      ];
      t = pick[rng.nextInt(pick.length)];
    }
    s.style = t;
    s.flankSide = rng.nextBool() ? 1 : -1;
  }

  // 던져져 테두리 안쪽에 떨어진 자리에서 가운데로 돌진하며 시작한다.
  void launch(_Body s, double q, double dir) {
    s.x = (rng.nextDouble() * 2 - 1) * radius * 0.12;
    s.y = -dir * radius * 0.78;
    final sp = s.maxSpeed * p.launchSpeedMult * (1 + q * p.launchBonusMax);
    s.vx = -s.x * 0.2;
    s.vy = dir * sp;
    s.dashCd = p.dashCooldown * 0.5;
  }

  launch(bodies[0], la, 1);
  launch(bodies[1], lb, -1);

  final frames = <List<int>>[];
  final events = <DuelEvent>[];
  int? winner;
  var finish = DuelFinish.timeUp;
  var tick = 0;
  _Body? gripper;

  double restrain(_Body from, _Body to) =>
      from.bug.element.restrains(to.bug.element) ? p.restrainMult : 1.0;
  double defFactor(_Body to) => 100 / (100 + to.bug.def);
  double resist(_Body s) =>
      1 + (s.style == Temperament.steadfast ? p.steadfastPushResist : 0);
  // 기세 — 체력이 많을수록 **밀려나는 양**이 준다(주특기 발동 조건 `leverage` 에는 넣지 않는다 —
  // 넣으면 던지기가 체력 많은 상대에게 아예 발동하지 않아 집기가 던지기를 99% 이겼다).
  double guard(_Body s) => 1 + p.hpGuard * s.hpPct;
  // 들어 올리거나 밀어낼 수 있는 힘의 몫(0~1) — 공격 쪽 ATK×무게 대 방어 쪽 DEF×무게.
  // 체구 비중(C안): 스탯 지수를 낮추고 무게 지수를 올리면 밀기 싸움이 몸집 싸움이 된다.
  // 밀어내기 힘 칸(pushMult)은 **미는 쪽 몫에만** 곱한다(체급과 달리 버티는 힘은 안 는다).
  double heft(double stat, double m) =>
      math.pow(math.max(stat, 1e-6), p.leverageStatExp).toDouble() *
      math.pow(m, p.leverageMassExp).toDouble();
  double leverage(_Body from, _Body to) {
    final f =
        heft(from.bug.atk, from.m) * restrain(from, to) * from.bug.pushMult;
    final r = heft(to.bug.def, to.m) * resist(to);
    return f / (f + r);
  }

  // 0 아래로도 내려간다 — 한 충돌에 둘 다 쓰러지면 **더 깊이 깎인 쪽**이 진다
  // (0 에서 자르면 동점이 되고, 동점 처리가 한쪽에 몰려 대칭 대전이 50% 가 안 나왔다).
  void hit(_Body to, double dmg) {
    to.hp -= dmg;
  }

  // 탭 반격 — 위기에 빠진 [s] 가 살아나나. true = 성공(호출자가 효과를 입힌다), false = 실패·횟수 없음,
  // null = 플레이어 점수를 기다리며 멈춤([pending] 이 채워진다). 물리 난수(rng)는 건드리지 않는다.
  bool? tryClutch(_Body s, DuelCrisis kind) {
    if (s.clutchLeft <= 0) return false;
    final grit = s.bug.gritOf(p);
    events.add(
      DuelEvent(
        tick: tick,
        kind: DuelEventKind.clutch,
        who: s.side,
        value: kind.index,
      ),
    );
    final double score;
    final scores = clutchScores;
    if (s.side == 0 && scores != null) {
      if (scoreAt >= scores.length) {
        pending = DuelClutchPending(kind: kind, tick: tick, index: scoreAt);
        return null;
      }
      score = scores[scoreAt++].clamp(0.0, 1.0);
    } else {
      score =
          p.clutchAutoBase +
          grit * p.clutchAutoPerGrit +
          (clutchRng[s.side].nextDouble() * 2 - 1) * p.clutchAutoSpread;
    }
    s.clutchLeft--;
    final ok = score >= p.clutchThreshold - grit * p.clutchThresholdPerGrit;
    events.add(
      DuelEvent(
        tick: tick,
        kind: ok ? DuelEventKind.clutchSave : DuelEventKind.clutchFail,
        who: s.side,
        value: (score.clamp(0.0, 1.0) * 1000).round(),
      ),
    );
    return ok;
  }

  // 버티기(장외·뒤집기) 성공의 대가 — 최대 체력 × clutchHoldHpCost 를 잃되, 남은 체력의 clutchHoldKeepRatio
  // 아래로는 안 내려간다(이것으로는 쓰러지지 않는다). 공짜로 버티면 조작 앱(늘 만점)이 74% 를 이겼다 — 판을 통째로
  // 살리는 게 아니라 한 번 더 기회를 준다. 바닥을 "최대 체력 1%"로 두던 시절엔 약할 때 버티면 1% 만 남아
  // 다음 한 대에 기절했다(2026-10-09 사장님 확정 B안: 버틴 뒤 1초 안 기절 50% → 18%).
  void holdCost(_Body s) {
    if (p.clutchHoldHpCost <= 0 || s.hp <= 0) return;
    s.hp = math.max(
      s.hp - s.bug.maxHp * p.clutchHoldHpCost,
      s.hp * p.clutchHoldKeepRatio.clamp(0.0, 1.0),
    );
  }

  // 장외 위기 성공 — 테두리 안쪽으로 버티고 멈춘다. 물려 있었으면 놓친다(안 놓으면 곧바로 다시 밀린다).
  void holdRim(_Body s) {
    final d = s.dist;
    final ux = d > 1e-6 ? s.x / d : 0.0, uy = d > 1e-6 ? s.y / d : 1.0;
    s.x = ux * radius * p.clutchRestoreRatio;
    s.y = uy * radius * p.clutchRestoreRatio;
    s.vx = 0;
    s.vy = 0;
    s.air = 0;
    s.landDamage = 0;
    final g = gripper;
    if (g != null) {
      gripper = null;
      g.gripCd = p.gripCooldown;
    }
    holdCost(s);
  }

  // 뒤집기 위기 성공 — 그 자리에 버텨 선다. 치기는 뒤집기 판정 **전에** 밀치기 속도를 넣으므로, 뒤집기만 취소하면
  // 밀쳐진 속도가 남아 "버텼다!" 직후 테두리 밖으로 미끄러져 장외로 졌다(2026-10-09 실기 지적 — 상대가 세면
  // 버틴 판의 3~4% 가 0.3초 안팎에 장외). 장외 버티기([holdRim])처럼 속도를 버리고, 테두리 근처면 안쪽으로 되돌린다.
  void holdFlip(_Body s) {
    s.vx = 0;
    s.vy = 0;
    final d = s.dist;
    final inner = radius * p.clutchRestoreRatio;
    if (d > inner) {
      s.x = s.x / d * inner;
      s.y = s.y / d * inner;
    }
    holdCost(s);
  }

  // 깨우기 성공 체력.
  void wake(_Body s) {
    s.hp =
        s.bug.maxHp *
        (p.clutchWakeHp + s.bug.gritOf(p) * p.clutchWakeHpPerGrit);
  }

  void frame() {
    final row = <int>[];
    for (final s in bodies) {
      var flags = 0;
      if (!s.grounded) flags |= DuelFlag.airborne;
      if (identical(gripper, s)) flags |= DuelFlag.gripping;
      if (gripper != null && !identical(gripper, s)) flags |= DuelFlag.gripped;
      if (s.dashTimer > 0) flags |= DuelFlag.dashing;
      if (s.flipped) flags |= DuelFlag.flipped;
      if (s.grounded && s.dist > radius) flags |= DuelFlag.out;
      if (s.hp <= 0) flags |= DuelFlag.knocked;
      row.addAll([
        (s.x * 10).round(),
        (s.y * 10).round(),
        (s.vx * 10).round(),
        (s.vy * 10).round(),
        (s.hpPct * 1000).round(),
        flags,
      ]);
    }
    frames.add(row);
  }

  frame();
  while (tick < p.maxTicks && winner == null) {
    tick++;
    // 순서 편향을 없애려고 틱마다 먼저 움직이는 쪽을 바꾼다.
    final order = tick.isEven ? bodies : bodies.reversed.toList();

    // ── 1. 조종(AI) ──────────────────────────────────────────────
    for (final s in order) {
      final o = bodies[1 - s.side];
      s.dashCd = math.max(0, s.dashCd - dt);
      s.dashTimer = math.max(0, s.dashTimer - dt);
      s.strikeCd = math.max(0, s.strikeCd - dt);
      s.gripCd = math.max(0, s.gripCd - dt);
      s.tossCd = math.max(0, s.tossCd - dt);
      if (!s.grounded || gripper != null) continue;

      final dx = o.x - s.x, dy = o.y - s.y;
      final d = math.max(math.sqrt(dx * dx + dy * dy), 1e-6);
      final ux = dx / d, uy = dy / d;
      var tx = o.x, ty = o.y;
      switch (s.style) {
        case Temperament.cautious:
          if (s.dist > radius * p.cautiousRim) {
            tx = 0;
            ty = 0;
          }
        case Temperament.cunning:
          if (d > s.r + o.r + 12) {
            tx = o.x - uy * p.flankOffset * s.flankSide;
            ty = o.y + ux * p.flankOffset * s.flankSide;
          }
        case Temperament.steadfast:
          if (d > p.dashRange) {
            tx = o.x * 0.4;
            ty = o.y * 0.4;
          }
        case Temperament.aggressive:
        case Temperament.fickle:
          break;
      }
      final gx = tx - s.x, gy = ty - s.y;
      final gd = math.max(math.sqrt(gx * gx + gy * gy), 1e-6);
      final acc = s.maxSpeed * p.accelMult * dt;
      s.vx += gx / gd * acc;
      s.vy += gy / gd * acc;
      if (s.dashTimer <= 0) {
        final sp = math.sqrt(s.vx * s.vx + s.vy * s.vy);
        if (sp > s.maxSpeed) {
          s.vx = s.vx / sp * s.maxSpeed;
          s.vy = s.vy / sp * s.maxSpeed;
        }
      }

      // 신중: 날아오는 돌진을 옆으로 피한다(돌진 하나에 한 번만 판정).
      if (s.style == Temperament.cautious &&
          o.dashTimer > 0 &&
          o.dashId != s.dodgedDash &&
          d < p.dashRange) {
        s.dodgedDash = o.dashId;
        if (rng.nextDouble() < p.dodgeChance) {
          s.vx += -uy * s.maxSpeed * 1.6 * s.flankSide;
          s.vy += ux * s.maxSpeed * 1.6 * s.flankSide;
          events.add(
            DuelEvent(tick: tick, kind: DuelEventKind.dodge, who: s.side),
          );
        }
      }

      // 돌진.
      if (s.dashCd <= 0 && d < p.dashRange + s.r + o.r) {
        final sp = s.maxSpeed * p.dashMult;
        s.vx = ux * sp;
        s.vy = uy * sp;
        s.dashTimer = 0.35;
        s.dashId++;
        final spdScale = (60 / (s.bug.spd * 0.5 + 30)).clamp(0.5, 1.5);
        var cd = p.dashCooldown * spdScale;
        if (s.style == Temperament.aggressive) cd *= p.aggressiveCooldownMult;
        if (s.style == Temperament.steadfast) cd *= 1.3;
        s.dashCd = cd;
      }
    }

    // ── 2. 힘·이동 ──────────────────────────────────────────────
    for (final s in bodies) {
      if (!s.grounded) {
        s.x += s.vx * dt;
        s.y += s.vy * dt;
        s.air -= dt;
        if (s.grounded) {
          s.vx *= 0.3;
          s.vy *= 0.3;
          if (s.landDamage > 0) hit(s, s.landDamage);
          events.add(
            DuelEvent(
              tick: tick,
              kind: DuelEventKind.land,
              who: s.side,
              value: s.landDamage.round(),
            ),
          );
          s.landDamage = 0;
        }
        continue;
      }
      // 경사(가운데로) + 테두리 턱.
      final dist = s.dist;
      var ax = -s.x * p.bowlPull, ay = -s.y * p.bowlPull;
      final lip = radius * 0.8;
      if (dist > lip) {
        final k =
            p.rimPull *
            (dist - lip) /
            (radius - lip) *
            s.maxSpeed /
            10 *
            (1 + p.rimHpGuard * s.hpPct);
        ax -= s.x / dist * k;
        ay -= s.y / dist * k;
      }
      s.vx += ax * dt;
      s.vy += ay * dt;
      final fr = math.max(0.0, 1 - p.friction * dt);
      s.vx *= fr;
      s.vy *= fr;
    }

    // 잡기 — 물고 있는 동안 둘이 붙어서 바깥으로 밀려간다.
    if (gripper != null) {
      final g = gripper!;
      final o = bodies[1 - g.side];
      var dx = o.x - g.x, dy = o.y - g.y;
      var d = math.max(math.sqrt(dx * dx + dy * dy), 1e-6);
      dx /= d;
      dy /= d;
      // 미는 방향: 상대가 가운데에서 떨어져 있으면 바깥으로, 아니면 물린 방향으로.
      var px = dx, py = dy;
      final od = o.dist;
      if (od > 8) {
        px = (o.x / od + dx) / 2;
        py = (o.y / od + dy) / 2;
        final pl = math.max(math.sqrt(px * px + py * py), 1e-6);
        px /= pl;
        py /= pl;
      }
      final lev = leverage(g, o);
      final acc =
          p.gripForce *
          (1 + g.bug.techOf(p)) *
          (lev * 2 - p.gripLevOffset).clamp(0.0, 1.4) /
          (g.m + o.m) /
          guard(o);
      g.vx += px * acc * dt;
      g.vy += py * acc * dt;
      o.vx = g.vx;
      o.vy = g.vy;
      hit(o, g.bug.atk * p.gripDps * dt * defFactor(o) * restrain(g, o));
      g.gripTimer -= dt;
      o.x = g.x + dx * (g.r + o.r);
      o.y = g.y + dy * (g.r + o.r);
      if (g.gripTimer <= 0) {
        gripper = null;
        g.gripCd = p.gripCooldown;
      }
    }

    for (final s in bodies) {
      if (!s.grounded) continue;
      s.x += s.vx * dt;
      s.y += s.vy * dt;
    }
    if (gripper != null) {
      final g = gripper!;
      final o = bodies[1 - g.side];
      var dx = o.x - g.x, dy = o.y - g.y;
      final d = math.max(math.sqrt(dx * dx + dy * dy), 1e-6);
      o.x = g.x + dx / d * (g.r + o.r);
      o.y = g.y + dy / d * (g.r + o.r);
    }

    // ── 3. 충돌 ──────────────────────────────────────────────────
    final A = bodies[0], B = bodies[1];
    if (gripper == null && A.grounded && B.grounded) {
      var dx = B.x - A.x, dy = B.y - A.y;
      final d = math.sqrt(dx * dx + dy * dy);
      final minD = A.r + B.r;
      if (d < minD) {
        final nx = d > 1e-6 ? dx / d : 1.0, ny = d > 1e-6 ? dy / d : 0.0;
        // 겹침을 무게 반비례로 푼다.
        final over = minD - d;
        final wa = B.m / (A.m + B.m), wb = A.m / (A.m + B.m);
        A.x -= nx * over * wa;
        A.y -= ny * over * wa;
        B.x += nx * over * wb;
        B.y += ny * over * wb;
        final rel = (B.vx - A.vx) * nx + (B.vy - A.vy) * ny;
        if (rel < 0) {
          final impact = -rel;
          final j = -(1 + p.restitution) * rel / (1 / A.m + 1 / B.m);
          A.vx -= j / A.m * nx;
          A.vy -= j / A.m * ny;
          B.vx += j / B.m * nx;
          B.vy += j / B.m * ny;
          final im = (impact / p.impactRef).clamp(p.impactMin, p.impactMax);
          // 약점 — 맞는 쪽이 바라보는 방향(움직이는 방향, 멈췄으면 상대 쪽)에서 벗어난 곳을 맞았나.
          bool weakSpot(_Body v, double tx, double ty) {
            final sp = math.sqrt(v.vx * v.vx + v.vy * v.vy);
            if (sp < 8) return false;
            return (v.vx * tx + v.vy * ty) / sp < p.weakCos;
          }

          double spread() => 1 + p.damageSpread * (rng.nextDouble() * 2 - 1);
          final critA =
              rng.nextDouble() < math.min(p.critMax, p.critChance + A.bug.crit);
          final critB =
              rng.nextDouble() < math.min(p.critMax, p.critChance + B.bug.crit);
          final weakB = weakSpot(B, -nx, -ny);
          final weakA = weakSpot(A, nx, ny);
          // 회피(훈련소) — 맞는 쪽이 확률로 피해를 통째로 피한다. 밀림은 그대로.
          final evadeB =
              B.bug.evade > 0 &&
              rng.nextDouble() < math.min(p.evadeMax, B.bug.evade);
          final evadeA =
              A.bug.evade > 0 &&
              rng.nextDouble() < math.min(p.evadeMax, A.bug.evade);
          final toB =
              A.bug.atk *
              p.damageK *
              im *
              defFactor(B) *
              restrain(A, B) *
              (critA ? p.critMult : 1) *
              (weakB ? p.weakMult : 1) *
              spread() *
              (evadeB ? 0 : 1);
          final toA =
              B.bug.atk *
              p.damageK *
              im *
              defFactor(A) *
              restrain(B, A) *
              (critB ? p.critMult : 1) *
              (weakA ? p.weakMult : 1) *
              spread() *
              (evadeA ? 0 : 1);
          hit(B, toB);
          hit(A, toA);
          // 흡혈(회복력) — 준 피해의 일부를 되찾는다. 이번 충돌로 쓰러졌으면 없다.
          if (p.lifestealMult > 0) {
            for (final (me, dealt) in [(A, toB), (B, toA)]) {
              final gain = dealt * me.bug.recovery * p.lifestealMult;
              if (gain > 0 && me.hp > 0) {
                me.hp = math.min(me.bug.maxHp, me.hp + gain);
              }
            }
          }
          for (final (side, ev) in [(1, evadeB), (0, evadeA)]) {
            if (ev) {
              events.add(
                DuelEvent(tick: tick, kind: DuelEventKind.evade, who: side),
              );
            }
          }
          for (final (side, crit, weak, dmg) in [
            (0, critA, weakB, toB),
            (1, critB, weakA, toA),
          ]) {
            if (crit) {
              events.add(
                DuelEvent(
                  tick: tick,
                  kind: DuelEventKind.crit,
                  who: side,
                  value: dmg.round(),
                ),
              );
            }
            if (weak) {
              events.add(
                DuelEvent(
                  tick: tick,
                  kind: DuelEventKind.weak,
                  who: side,
                  value: dmg.round(),
                ),
              );
            }
          }
          events.add(
            DuelEvent(
              tick: tick,
              kind: DuelEventKind.clash,
              who: toB >= toA ? 0 : 1,
              value: (toA + toB).round(),
            ),
          );

          // 주특기 — 상대 쪽으로 더 세게 달려든 쪽이 먼저 쓸 **확률**이 높다.
          // 무조건 빠른 쪽이 먼저면 속도 10% 차이가 주특기를 독점해 결과가 거의 정해졌다.
          final appA = math.max(0.01, A.vx * nx + A.vy * ny + impact * 0.5);
          final appB = math.max(0.01, -(B.vx * nx + B.vy * ny) + impact * 0.5);
          final first = rng.nextDouble() * (appA + appB) < appA ? A : B;
          for (final s in [first, first == A ? B : A]) {
            final o = s == A ? B : A;
            if (!s.grounded || !o.grounded || gripper != null) break;
            if (o.flipped || s.flipped) break;
            // 상대 방향 단위 벡터.
            final sx = s == A ? nx : -nx, sy = s == A ? ny : -ny;
            final lev = leverage(s, o);
            switch (s.bug.specialty) {
              case Specialty.strike:
                if (s.strikeCd > 0) continue;
                s.strikeCd = p.strikeFlipCooldown;
                final push =
                    impact *
                    (p.strikePushMult - 1) *
                    s.m /
                    o.m *
                    s.bug.pushMult;
                o.vx += sx * push / resist(o) / guard(o);
                o.vy += sy * push / resist(o) / guard(o);
                final chance =
                    p.strikeFlipBase *
                    lev *
                    2 *
                    im *
                    (1 - p.flipHpGuard * o.hpPct).clamp(0.0, 1.0) *
                    (1 + s.bug.techOf(p));
                if (rng.nextDouble() < chance) {
                  // 버티기(뒤집기) — 성공하면 뒤집기 취소.
                  final held = tryClutch(o, DuelCrisis.flip);
                  if (held == null) break;
                  if (held) {
                    holdFlip(o);
                  } else {
                    o.flipped = true;
                    winner = s.side;
                    finish = DuelFinish.flip;
                    events.add(
                      DuelEvent(
                        tick: tick,
                        kind: DuelEventKind.flip,
                        who: o.side,
                      ),
                    );
                  }
                }
              case Specialty.grip:
                if (s.gripCd > 0) continue;
                gripper = s;
                s.gripTimer = p.gripSeconds;
                // 물기 시작할 때 **부딪혀 튕겨 나가던 속도를 버린다**(2026-10-08 버그 수정). 안 버리면 문 쪽이
                // 뒤로 튕기던 속도로 상대를 문 채(물린 쪽은 문 쪽 속도를 따라간다) 자기 테두리 밖으로 미끄러졌다 —
                // 118mm 풀강 하늘소가 38mm 말벌에게 장외로 45% 만 이겼다(실측, 진 판 전부가 문 지 1.5초 안).
                // 이 버그가 집기를 깎아 겉보기 균형을 맞추고 있어서 gripForce 를 함께 낮췄다(battle.json).
                s.vx = 0;
                s.vy = 0;
                o.vx = 0;
                o.vy = 0;
                events.add(
                  DuelEvent(tick: tick, kind: DuelEventKind.grip, who: s.side),
                );
              case Specialty.toss:
                if (s.tossCd > 0 || lev < p.tossLevMin) continue;
                s.tossCd =
                    p.tossCooldown *
                    math.max(p.tossCooldownMin, 1 - s.bug.techOf(p));
                final sp = p.tossSpeed * (0.5 + lev) / resist(o) / guard(o);
                o.vx = sx * sp;
                o.vy = sy * sp;
                o.air = p.tossAirSeconds;
                o.landDamage =
                    s.bug.atk *
                    p.tossLandDamage *
                    defFactor(o) *
                    restrain(s, o);
                events.add(
                  DuelEvent(
                    tick: tick,
                    kind: DuelEventKind.toss,
                    who: s.side,
                    value: o.landDamage.round(),
                  ),
                );
            }
            if (winner != null || pending != null) break;
          }
        }
      }
    }

    if (pending != null) break;

    // ── 4. 결판 ──────────────────────────────────────────────────
    // 탭 반격(위기)은 **질 쪽**에게 건다 — 실패하면 예전과 똑같이 결판, 성공하면 되살리고 다시 본다.
    // 위기 처리는 물리 난수를 쓰지 않으므로, 위기가 모두 실패한 판은 예전 엔진과 같은 판이다.
    if (winner == null && p.clutchEnabled && p.clutchRimRatio < 1) {
      // 테두리 근처에서 바깥으로 밀려나는 중이면 미리 건다(clutchRimRatio < 1 일 때만).
      for (final s in bodies) {
        if (s.clutchLeft <= 0 || !s.grounded) continue;
        final d = s.dist;
        if (d <= radius * p.clutchRimRatio) continue;
        if (d <= radius && s.x * s.vx + s.y * s.vy <= 0) continue;
        final held = tryClutch(s, DuelCrisis.ringOut);
        if (held == null) break;
        if (held) holdRim(s);
      }
      if (pending != null) break;
    }
    while (winner == null) {
      final outA = A.grounded && A.dist > radius;
      final outB = B.grounded && B.dist > radius;
      if (!outA && !outB) break;
      // 같은 틱에 둘 다 나가면 더 멀리 나간 쪽이 진다.
      final loser = outA && outB ? (A.dist >= B.dist ? A : B) : (outA ? A : B);
      final held = tryClutch(loser, DuelCrisis.ringOut);
      if (held == null) break;
      if (held) {
        holdRim(loser);
        continue;
      }
      winner = 1 - loser.side;
      finish = DuelFinish.ringOut;
      events.add(
        DuelEvent(tick: tick, kind: DuelEventKind.ringOut, who: loser.side),
      );
    }
    if (pending != null) break;
    while (winner == null && (A.hp <= 0 || B.hp <= 0)) {
      final _Body loser;
      if (A.hp <= 0 && B.hp <= 0) {
        final ra = A.hp / A.bug.maxHp, rb = B.hp / B.bug.maxHp;
        loser = ra == rb ? (rng.nextBool() ? A : B) : (ra < rb ? A : B);
      } else {
        loser = A.hp <= 0 ? A : B;
      }
      // 깨우기(기절) — 성공하면 체력 일부로 일어난다.
      final held = tryClutch(loser, DuelCrisis.knockout);
      if (held == null) break;
      if (held) {
        wake(loser);
        continue;
      }
      winner = 1 - loser.side;
      finish = DuelFinish.knockout;
      events.add(
        DuelEvent(tick: tick, kind: DuelEventKind.knockout, who: loser.side),
      );
    }
    if (pending != null) break;
    if (tick % p.frameEvery == 0 || winner != null) frame();
  }

  // 플레이어 위기에서 멈췄다 — 멈춘 틱 전까지의 궤적과 자리를 돌려준다(winner = -1).
  final stop = pending;
  if (stop != null) {
    return DuelBout(
      winner: -1,
      finish: DuelFinish.timeUp,
      ticks: tick,
      hpPctA: bodies[0].hpPct,
      hpPctB: bodies[1].hpPct,
      frames: frames,
      events: events,
      launchA: la,
      launchB: lb,
      pending: stop,
    );
  }

  if (winner == null) {
    final A = bodies[0], B = bodies[1];
    finish = DuelFinish.timeUp;
    if ((A.hpPct - B.hpPct).abs() > 1e-9) {
      winner = A.hpPct > B.hpPct ? 0 : 1;
    } else if (A.bug.spd != B.bug.spd) {
      winner = A.bug.spd > B.bug.spd ? 0 : 1;
    } else if (A.m != B.m) {
      winner = A.m > B.m ? 0 : 1;
    } else {
      winner = rng.nextInt(2);
    }
  }

  return DuelBout(
    winner: winner,
    finish: finish,
    ticks: tick,
    hpPctA: bodies[0].hpPct,
    hpPctB: bodies[1].hpPct,
    frames: frames,
    events: events,
    launchA: la,
    launchB: lb,
  );
}

/// 승자 연속 경기 결과(2026-09-29 사장님 확정) — 이긴 곤충이 남아 다음 상대를 맞고,
/// 한 팀의 곤충이 모두 쓰러지면 끝(3마리씩이면 3~5판).
@immutable
class DuelMatch {
  const DuelMatch({required this.bouts, this.pending});

  /// 판 목록. [pending] 이 있으면 마지막 판이 위기에서 멈춘 판이다.
  final List<DuelBout> bouts;

  /// 플레이어(A) 위기에서 멈췄으면 그 자리 — [DuelClutchPending.bout] 판의
  /// [DuelClutchPending.index] 번째(경기 전체에서 센다) 점수를 기다린다.
  final DuelClutchPending? pending;

  /// A 가 이긴 판 수 = 쓰러뜨린 B 곤충 수.
  int get winsA => bouts.where((b) => b.winner == 0).length;
  int get winsB => bouts.where((b) => b.winner == 1).length;

  /// 한쪽 팀이 모두 쓰러졌나.
  bool decided(DuelParams p) => winsA >= p.winsNeeded || winsB >= p.winsNeeded;

  /// 0 = A 승, 1 = B 승. 아직 안 끝났으면 null.
  int? winner(DuelParams p) => winsA >= p.winsNeeded
      ? 0
      : winsB >= p.winsNeeded
      ? 1
      : null;
}

/// 승자 연속의 **다음 판 대진·시작 체력** — 지금까지의 판 결과에서 나온다(앱·서버 공용).
///
/// 대진: A 의 [DuelDuelState.ia] 번째 대 B 의 [DuelDuelState.ib] 번째(진 쪽만 다음 곤충으로 바뀐다).
/// 체력: 이긴 곤충은 끝난 체력 + 판 사이 회복, 새로 나온 곤충은 가득.
typedef DuelDuelState = ({int ia, int ib, double hpA, double hpB});

DuelDuelState duelNextState(
  List<DuelBout> bouts,
  List<DuelBug> teamA,
  List<DuelBug> teamB,
  DuelParams p,
) {
  var ia = 0, ib = 0;
  var ha = 1.0, hb = 1.0;
  for (final b in bouts) {
    if (b.pending != null) break; // 위기에서 멈춘 판은 아직 끝나지 않았다.
    if (b.winner == 0) {
      ha = duelCarryHp(b.hpPctA, teamA[math.min(ia, teamA.length - 1)], p);
      ib++;
      hb = 1;
    } else {
      hb = duelCarryHp(b.hpPctB, teamB[math.min(ib, teamB.length - 1)], p);
      ia++;
      ha = 1;
    }
  }
  return (ia: ia, ib: ib, hpA: ha, hpB: hb);
}

/// 이긴 곤충이 다음 판에 들고 가는 체력(0~1) = 남은 체력 + 기본 회복 + 회복력.
double duelCarryHp(double endPct, DuelBug bug, DuelParams p) =>
    (endPct + p.carryHealBase + bug.recovery).clamp(0.05, 1.0);

/// 자동 결투 — 게이지 없이 끝까지(승자 연속).
///
/// [launchesA] 를 주면 그 판의 게이지 값을 쓴다(없으면 자동값).
/// [clutchScores] 는 A(플레이어) 위기에 경기 전체에서 순서대로 넣을 탭 점수 — 다 떨어지면
/// 그 위기에서 멈추고 [DuelMatch.pending] 을 채워 돌려준다. null 이면 A 도 자동 점수.
DuelMatch simulateDuel({
  required int seed,
  required List<DuelBug> teamA,
  required List<DuelBug> teamB,
  required DuelParams params,
  List<double>? launchesA,
  List<double>? clutchScores,
}) {
  final bouts = <DuelBout>[];
  var used = 0;
  for (var i = 0; i < params.maxBouts; i++) {
    final st = duelNextState(bouts, teamA, teamB, params);
    if (st.ia >= teamA.length || st.ib >= teamB.length) break;
    final bout = simulateBout(
      seed: duelBoutSeed(seed, i),
      a: teamA[st.ia],
      b: teamB[st.ib],
      params: params,
      hpA: st.hpA,
      hpB: st.hpB,
      launchA: launchesA != null && i < launchesA.length ? launchesA[i] : null,
      clutchScores: clutchScores?.sublist(math.min(used, clutchScores.length)),
    );
    bouts.add(bout);
    final stop = bout.pending;
    if (stop != null) {
      return DuelMatch(
        bouts: bouts,
        pending: stop.withBout(i, used + stop.index),
      );
    }
    used += bout.playerClutches;
  }
  return DuelMatch(bouts: bouts);
}

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
  knockout('knockout');

  const DuelEventKind(this.key);
  final String key;

  static DuelEventKind fromKey(String k) =>
      values.firstWhere((e) => e.key == k, orElse: () => clash);
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
  });

  /// 0 = A 승, 1 = B 승. 무승부는 없다(시간 판정 → SPD → 무게 → 시드).
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

  bool get aWon => winner == 0;

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
  );
}

/// 판마다 다른 시드 — 같은 경기 시드에서 판 번호로 갈라진다(결정론).
int duelBoutSeed(int matchSeed, int boutIndex) =>
    (matchSeed ^ (0x9E3779B1 * (boutIndex + 1))) & 0x7fffffff;

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

  bool get grounded => air <= 0;
  double get hpPct => bug.maxHp <= 0 ? 0 : (hp / bug.maxHp).clamp(0, 1);
  double get dist => math.sqrt(x * x + y * y);
}

/// 한 판(1:1) 시뮬레이션 — **완전 결정론**(시드·입력이 같으면 결과가 같다, §2.3).
///
/// [launchA]·[launchB] 는 던지기 게이지 값(0~1). 게이지 없이 던지면 `params.launchAuto`.
DuelBout simulateBout({
  required int seed,
  required DuelBug a,
  required DuelBug b,
  required DuelParams params,
  double? launchA,
  double? launchB,
}) {
  final p = params;
  final rng = math.Random(seed);
  final la = (launchA ?? p.launchAuto).clamp(0.0, 1.0);
  final lb = (launchB ?? p.launchAuto).clamp(0.0, 1.0);
  final bodies = [_Body(a, p, 0), _Body(b, p, 1)];
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
  // 들어 올리거나 밀어낼 수 있는 힘의 몫(0~1) — 공격 쪽 ATK×무게 대 방어 쪽 DEF×무게.
  double leverage(_Body from, _Body to) {
    final f = from.bug.atk * from.m * restrain(from, to);
    final r = to.bug.def * to.m * resist(to);
    return f / (f + r);
  }

  // 0 아래로도 내려간다 — 한 충돌에 둘 다 쓰러지면 **더 깊이 깎인 쪽**이 진다
  // (0 에서 자르면 동점이 되고, 동점 처리가 한쪽에 몰려 대칭 대전이 50% 가 안 나왔다).
  void hit(_Body to, double dmg) {
    to.hp -= dmg;
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
        final k = p.rimPull * (dist - lip) / (radius - lip) * s.maxSpeed / 10;
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
      final g = gripper;
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
      final acc = p.gripForce * (lev * 2 - 0.6).clamp(0.0, 1.4) / (g.m + o.m);
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
      final g = gripper;
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
          final toB =
              A.bug.atk * p.damageK * im * defFactor(B) * restrain(A, B);
          final toA =
              B.bug.atk * p.damageK * im * defFactor(A) * restrain(B, A);
          hit(B, toB);
          hit(A, toA);
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
                final push = impact * (p.strikePushMult - 1) * s.m / o.m;
                o.vx += sx * push / resist(o);
                o.vy += sy * push / resist(o);
                final chance = p.strikeFlipBase * lev * 2 * im;
                if (rng.nextDouble() < chance) {
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
              case Specialty.grip:
                if (s.gripCd > 0) continue;
                gripper = s;
                s.gripTimer = p.gripSeconds;
                events.add(
                  DuelEvent(tick: tick, kind: DuelEventKind.grip, who: s.side),
                );
              case Specialty.toss:
                if (s.tossCd > 0 || lev < 0.35) continue;
                s.tossCd = p.tossCooldown;
                final sp = p.tossSpeed * (0.5 + lev) / resist(o);
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
            if (winner != null) break;
          }
        }
      }
    }

    // ── 4. 결판 ──────────────────────────────────────────────────
    if (winner == null) {
      final outA = A.grounded && A.dist > radius;
      final outB = B.grounded && B.dist > radius;
      if (outA || outB) {
        // 같은 틱에 둘 다 나가면 더 멀리 나간 쪽이 진다.
        final loser = outA && outB
            ? (A.dist >= B.dist ? A : B)
            : (outA ? A : B);
        winner = 1 - loser.side;
        finish = DuelFinish.ringOut;
        events.add(
          DuelEvent(tick: tick, kind: DuelEventKind.ringOut, who: loser.side),
        );
      }
    }
    if (winner == null && (A.hp <= 0 || B.hp <= 0)) {
      final _Body loser;
      if (A.hp <= 0 && B.hp <= 0) {
        final ra = A.hp / A.bug.maxHp, rb = B.hp / B.bug.maxHp;
        loser = ra == rb ? (rng.nextBool() ? A : B) : (ra < rb ? A : B);
      } else {
        loser = A.hp <= 0 ? A : B;
      }
      winner = 1 - loser.side;
      finish = DuelFinish.knockout;
      events.add(
        DuelEvent(tick: tick, kind: DuelEventKind.knockout, who: loser.side),
      );
    }
    if (tick % p.frameEvery == 0 || winner != null) frame();
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

/// 3판 2선승 경기 결과.
@immutable
class DuelMatch {
  const DuelMatch({required this.bouts});

  final List<DuelBout> bouts;

  int get winsA => bouts.where((b) => b.winner == 0).length;
  int get winsB => bouts.where((b) => b.winner == 1).length;

  /// 두 팀 중 한쪽이 과반을 이겼나.
  bool decided(DuelParams p) => winsA >= p.winsNeeded || winsB >= p.winsNeeded;

  /// 0 = A 승, 1 = B 승. 아직 안 끝났으면 null.
  int? winner(DuelParams p) => winsA >= p.winsNeeded
      ? 0
      : winsB >= p.winsNeeded
      ? 1
      : null;
}

/// 자동 결투 — 게이지 없이 끝까지. 판 i 는 A[i] 대 B[i].
///
/// [launchesA] 를 주면 그 판의 게이지 값을 쓴다(없으면 자동값).
DuelMatch simulateDuel({
  required int seed,
  required List<DuelBug> teamA,
  required List<DuelBug> teamB,
  required DuelParams params,
  List<double>? launchesA,
}) {
  final bouts = <DuelBout>[];
  final n = math.min(teamA.length, teamB.length);
  for (var i = 0; i < n; i++) {
    final m = DuelMatch(bouts: bouts);
    if (m.decided(params)) break;
    bouts.add(
      simulateBout(
        seed: duelBoutSeed(seed, i),
        a: teamA[i],
        b: teamB[i],
        params: params,
        launchA: launchesA != null && i < launchesA.length
            ? launchesA[i]
            : null,
      ),
    );
  }
  return DuelMatch(bouts: bouts);
}

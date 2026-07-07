import 'dart:math' as math;

import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../data/game_data.dart';
import '../../domain/providers.dart';
import '../../domain/save_controller.dart';
import '../../domain/save_game.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/art.dart';
import '../../ui/format.dart';

const _uuid = Uuid();
const _honey = Color(0xFFEBA52F);
const _onScene = Color(0xFFFFFFFF);
const _walkDuration = 0.6;
const _boostDuration = 3.0;
const _deathDuration = 0.4;
const _defeatDuration = 2.5;

BoxDecoration _glass([double r = 999]) => BoxDecoration(
  color: const Color(0x66121A10),
  borderRadius: BorderRadius.circular(r),
  border: Border.all(color: const Color(0x28FFFFFF)),
);

String _statLabel(AppLocalizations l, UpgradeKind k) => switch (k) {
  UpgradeKind.attack => l.upAttack,
  UpgradeKind.attackSpeed => l.upAttackSpeed,
  UpgradeKind.crit => l.upCrit,
  UpgradeKind.critDamage => l.upCritDamage,
  UpgradeKind.bossDamage => l.upBossDamage,
  UpgradeKind.maxHp => l.upMaxHp,
  UpgradeKind.defense => l.upDefense,
  UpgradeKind.regen => l.upRegen,
  UpgradeKind.reward => l.upReward,
  UpgradeKind.xp => l.upXp,
  UpgradeKind.bugFind => l.upBugFind,
  UpgradeKind.materialFind => l.upMaterialFind,
  UpgradeKind.moveSpeed => l.upMoveSpeed,
  UpgradeKind.boost => l.upBoost,
  UpgradeKind.bugBuff => l.upBugBuff,
};

IconData _statIcon(UpgradeKind k) => switch (k) {
  UpgradeKind.attack => Icons.bolt,
  UpgradeKind.attackSpeed => Icons.speed,
  UpgradeKind.crit => Icons.gps_fixed,
  UpgradeKind.critDamage => Icons.whatshot,
  UpgradeKind.bossDamage => Icons.local_fire_department,
  UpgradeKind.maxHp => Icons.favorite,
  UpgradeKind.defense => Icons.shield,
  UpgradeKind.regen => Icons.healing,
  UpgradeKind.reward => Icons.paid,
  UpgradeKind.xp => Icons.school,
  UpgradeKind.bugFind => Icons.pest_control,
  UpgradeKind.materialFind => Icons.inventory_2,
  UpgradeKind.moveSpeed => Icons.directions_run,
  UpgradeKind.boost => Icons.flash_on,
  UpgradeKind.bugBuff => Icons.menu_book,
};

Color _statColor(UpgradeKind k) {
  switch (k) {
    case UpgradeKind.attack:
    case UpgradeKind.attackSpeed:
    case UpgradeKind.crit:
    case UpgradeKind.critDamage:
    case UpgradeKind.bossDamage:
      return const Color(0xFFB5432E); // 전투
    case UpgradeKind.maxHp:
    case UpgradeKind.defense:
    case UpgradeKind.regen:
      return const Color(0xFF2E6DA4); // 생존
    case UpgradeKind.reward:
    case UpgradeKind.xp:
    case UpgradeKind.bugFind:
    case UpgradeKind.materialFind:
      return const Color(0xFF3E7D4F); // 보상
    case UpgradeKind.moveSpeed:
    case UpgradeKind.boost:
    case UpgradeKind.bugBuff:
      return const Color(0xFF7E57C2); // 편의
  }
}

String _valuePair(UpgradeKind k, double cur, double next) {
  switch (k) {
    case UpgradeKind.attack:
    case UpgradeKind.maxHp:
    case UpgradeKind.defense:
      return '${cur.toStringAsFixed(0)} → ${next.toStringAsFixed(0)}';
    case UpgradeKind.attackSpeed:
    case UpgradeKind.regen:
      return '${cur.toStringAsFixed(2)}/s → ${next.toStringAsFixed(2)}/s';
    case UpgradeKind.crit:
      return '${(cur * 100).toStringAsFixed(0)}% → ${(next * 100).toStringAsFixed(0)}%';
    default:
      return 'x${cur.toStringAsFixed(2)} → x${next.toStringAsFixed(2)}';
  }
}

class _Pop {
  _Pop(this.text, this.dx, this.color, this.size, {this.baseX = 0.4});
  final String text;
  final double dx;
  final Color color;
  final double size;
  final double baseX;
  double age = 0;
}

class _Impact {
  _Impact(this.crit);
  final bool crit;
  double age = 0;
}

class _Particle {
  _Particle(this.vx, this.vy, this.color);
  double x = 0;
  double y = 0;
  double vx;
  double vy;
  final Color color;
  double age = 0;
}

/// 적 히트 반응: 뒤로 밀림 + 찌그러짐 + 하얀 번쩍.
class _EnemyArt extends StatelessWidget {
  const _EnemyArt({required this.art, required this.hitFlash});
  final Widget art;
  final double hitFlash;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(hitFlash * 12, 0),
      child: Transform.scale(
        scaleX: 1 + hitFlash * 0.14,
        scaleY: 1 - hitFlash * 0.12,
        alignment: Alignment.bottomCenter,
        child: Stack(
          alignment: Alignment.center,
          children: [
            art,
            if (hitFlash > 0.02)
              Positioned.fill(
                child: Opacity(
                  opacity: (hitFlash * 0.85).clamp(0.0, 1.0),
                  child: ColorFiltered(
                    colorFilter: const ColorFilter.mode(
                      Colors.white,
                      BlendMode.srcATop,
                    ),
                    child: art,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 타격 임팩트 스파크(원 + 방사 스파이크).
class _ImpactPainter extends CustomPainter {
  _ImpactPainter(this.t, this.crit);
  final double t; // 0..1
  final bool crit;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final op = (1 - t).clamp(0.0, 1.0);
    final color = (crit ? const Color(0xFFFFCA28) : Colors.white).withValues(
      alpha: op,
    );
    final radius = size.width / 2 * (0.35 + t * 0.85);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = crit ? 4 : 2.5
        ..color = color,
    );
    final n = crit ? 8 : 6;
    final spike = Paint()
      ..strokeWidth = crit ? 4 : 3
      ..strokeCap = StrokeCap.round
      ..color = color;
    for (var i = 0; i < n; i++) {
      final a = i / n * 2 * math.pi;
      final d = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(
        center + d * (radius * 0.55),
        center + d * (radius * 1.2),
        spike,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ImpactPainter old) => true;
}

/// 유리 깨짐 균열 오버레이 (때릴 때 하양 / 맞을 때 빨강).
class _CrackPainter extends CustomPainter {
  _CrackPainter(this.cracks, this.progress, this.color);
  final List<List<Offset>> cracks;
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final op = progress.clamp(0.0, 1.0);
    final line = Paint()
      ..color = color.withValues(alpha: op)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final glow = Paint()
      ..color = color.withValues(alpha: op * 0.35)
      ..strokeWidth = 5.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    for (final crack in cracks) {
      final path = Path()
        ..moveTo(crack.first.dx * size.width, crack.first.dy * size.height);
      for (final pt in crack.skip(1)) {
        path.lineTo(pt.dx * size.width, pt.dy * size.height);
      }
      canvas.drawPath(path, glow);
      canvas.drawPath(path, line);
    }
  }

  @override
  bool shouldRepaint(covariant _CrackPainter old) =>
      old.progress != progress || old.color != color;
}

/// 홈: 상단 전투 뷰포트(자동 사냥, 적 반격) + 하단 능력치 업그레이드 목록.
class PlayScreen extends ConsumerStatefulWidget {
  const PlayScreen({super.key});

  @override
  ConsumerState<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends ConsumerState<PlayScreen>
    with SingleTickerProviderStateMixin {
  late final GameData _data;
  late final RunConfig _config;
  late final Ticker _ticker;
  final _rng = math.Random();

  Duration _lastElapsed = Duration.zero;

  int _stage = 1;
  int _habitatIndex = 0;
  bool _isBoss = false;
  HabitatKind _kind = HabitatKind.tree;
  double _hpMax = 1;
  double _hp = 1;

  double _playerHp = 100;
  double _playerHpMax = 100;
  double _retreatFlash = 0;

  bool _walking = false;
  double _walkT = 0;
  double _attackAcc = 0;
  double _attackPulse = 0;
  double _hitFlash = 0;
  double _boost = 0;
  double _bgOffset = 0;
  double _dmgCooldown = 0;
  double _enemyAtkAcc = 0;
  double _bossLunge = 0;
  double _playerHitFlash = 0;
  double _screenShake = 0;

  int _buyAmount = 1;
  final List<_Pop> _pops = [];
  final List<_Impact> _impacts = [];
  final List<_Particle> _particles = [];
  late final List<List<Offset>> _cracks;
  bool _dying = false;
  double _dyingT = 0;
  bool _defeated = false;
  double _defeatT = 0;

  @override
  void initState() {
    super.initState();
    _cracks = _makeCracks();
    _data = ref.read(gameDataProvider).requireValue;
    _config = _data.runConfig!;
    final save = ref.read(saveControllerProvider).requireValue;
    _stage = save.stageNumber;
    final stats = _stats(save);
    _playerHpMax = stats.maxHp;
    _playerHp = stats.maxHp;
    _spawn();
    _ticker = createTicker(_tick)..start();

    // 오프라인 복귀 보상 알림 (1회)
    final controller = ref.read(saveControllerProvider.notifier);
    final offline = controller.pendingOffline;
    if (offline != null) {
      controller.consumeOffline();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final l = AppLocalizations.of(context);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                l.offlineReward(
                  formatCompact(offline.gold),
                  formatCompact(offline.xp),
                ),
              ),
            ),
          );
      });
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  // 유리 깨짐 균열 패턴을 한 번 생성(시드 고정 → 프레임마다 안 흔들림).
  List<List<Offset>> _makeCracks() {
    final rng = math.Random(7);
    const origin = Offset(0.6, 0.42);
    final out = <List<Offset>>[];
    const mains = 9;
    for (var i = 0; i < mains; i++) {
      var a = i / mains * 2 * math.pi + (rng.nextDouble() - 0.5) * 0.5;
      var p = origin;
      final pts = <Offset>[p];
      final segs = 4 + rng.nextInt(3);
      for (var s = 0; s < segs; s++) {
        a += (rng.nextDouble() - 0.5) * 0.55;
        final len = 0.07 + rng.nextDouble() * 0.09;
        p = p + Offset(math.cos(a), math.sin(a)) * len;
        pts.add(p);
        if (s > 0 && rng.nextDouble() < 0.45) {
          var ba = a + (rng.nextBool() ? 0.8 : -0.8);
          var bp = p;
          final bpts = <Offset>[bp];
          for (var b = 0; b < 2; b++) {
            ba += (rng.nextDouble() - 0.5) * 0.4;
            bp =
                bp +
                Offset(math.cos(ba), math.sin(ba)) *
                    (0.04 + rng.nextDouble() * 0.05);
            bpts.add(bp);
          }
          out.add(bpts);
        }
      }
      out.add(pts);
    }
    return out;
  }

  void _spawn() {
    _isBoss = _habitatIndex >= _config.habitatsPerStage;
    final depth = _stage - 1;
    _hpMax =
        (_isBoss ? bossMaxHp(_config, depth) : habitatMaxHp(_config, depth))
            .toDouble();
    _hp = _hpMax;
    _kind = habitatKindAt(_config, _stage, _isBoss ? 0 : _habitatIndex);
    _walking = false;
    _walkT = 0;
    _attackAcc = 0;
    _enemyAtkAcc = 0;
    _bossLunge = 0;
    _dying = false;
  }

  CharacterStats _stats(SaveGame save) => deriveStats(
    _config,
    upgradeLevels: save.upgradeLevels,
    characterLevel: save.level,
    bugsCollected: save.bugs.length,
  );

  void _tick(Duration elapsed) {
    final raw = (elapsed - _lastElapsed).inMicroseconds / 1000000.0;
    _lastElapsed = elapsed;
    final dt = raw.clamp(0.0, 0.05);
    if (dt <= 0) return;
    setState(() => _step(dt));
  }

  void _step(double dt) {
    if (_boost > 0) _boost = math.max(0, _boost - dt);
    if (_attackPulse > 0) _attackPulse = math.max(0, _attackPulse - dt * 2.6);
    if (_hitFlash > 0) _hitFlash = math.max(0, _hitFlash - dt * 7);
    if (_retreatFlash > 0) _retreatFlash = math.max(0, _retreatFlash - dt);
    if (_bossLunge > 0) _bossLunge = math.max(0, _bossLunge - dt * 3);
    if (_playerHitFlash > 0) {
      _playerHitFlash = math.max(0, _playerHitFlash - dt * 4);
    }
    if (_dmgCooldown > 0) _dmgCooldown -= dt;
    for (final p in _pops) {
      p.age += dt;
    }
    _pops.removeWhere((p) => p.age > 1.0);
    if (_screenShake > 0) _screenShake = math.max(0, _screenShake - dt * 4);
    for (final im in _impacts) {
      im.age += dt;
    }
    _impacts.removeWhere((im) => im.age > 0.28);
    for (final pt in _particles) {
      pt.x += pt.vx * dt;
      pt.y += pt.vy * dt;
      pt.vy += 900 * dt;
      pt.age += dt;
    }
    _particles.removeWhere((pt) => pt.age > 0.5);

    if (_defeated) {
      _defeatT -= dt;
      if (_defeatT <= 0) _resumeAfterDefeat();
      return;
    }

    if (_dying) {
      _dyingT -= dt;
      if (_dyingT <= 0) _advanceAfterDeath();
      return;
    }

    final stats = _stats(ref.read(saveControllerProvider).requireValue);
    _playerHpMax = stats.maxHp;

    if (_walking) {
      _walkT += dt;
      _bgOffset += dt * 130;
      _playerHp = math.min(_playerHpMax, _playerHp + stats.hpRegen * 2 * dt);
      if (_walkT >= _walkDuration / stats.moveSpeed) _spawn();
      return;
    }

    // 적 반격
    final depth = _stage - 1;
    final threat = habitatThreat(_config, depth, boss: _isBoss);
    final incoming = threat * 100 / (100 + stats.defense);
    if (_isBoss) {
      // 보스는 주기적으로 달려들어 큰 피해
      _playerHp = math.min(_playerHpMax, _playerHp + stats.hpRegen * dt);
      _enemyAtkAcc += dt;
      const bossInterval = 1.3;
      if (_enemyAtkAcc >= bossInterval) {
        _enemyAtkAcc -= bossInterval;
        final burst = incoming * bossInterval * 1.4;
        _playerHp -= burst;
        _bossLunge = 1;
        _playerHitFlash = 1;
        _pops.add(
          _Pop(
            '-${formatCompact(burst)}',
            (_rng.nextDouble() - 0.5) * 0.2,
            const Color(0xFFFF5252),
            18,
            baseX: -0.55,
          ),
        );
      }
    } else {
      // 일반 서식지는 곤충이 지속적으로 갉아먹음
      _playerHp = math.min(
        _playerHpMax,
        _playerHp + (stats.hpRegen - incoming) * dt,
      );
    }
    if (_playerHp <= 0) {
      _beginDefeat();
      return;
    }

    // 플레이어 공격
    final boosting = _boost > 0;
    final dmgMul = boosting ? (1 + stats.boostBonus) : 1.0;
    final speedMul = boosting ? (1 + stats.boostBonus * 0.6) : 1.0;
    final atkSpeed = stats.attackSpeed * speedMul;
    var perHit = stats.attack * dmgMul;
    if (_isBoss) perHit *= stats.bossDamage;

    final interval = 1.0 / atkSpeed;
    _attackAcc += dt;
    var guard = 0;
    while (_attackAcc >= interval && _hp > 0 && guard < 20) {
      _attackAcc -= interval;
      var dmg = perHit;
      final crit = _rng.nextDouble() < stats.critChance;
      if (crit) dmg *= stats.critDamage;
      _hp -= dmg;
      _attackPulse = 1;
      _hitFlash = 1;
      if (_dmgCooldown <= 0) {
        _pops.add(
          _Pop(
            formatCompact(dmg),
            (_rng.nextDouble() - 0.5) * 0.4,
            crit ? const Color(0xFFFFCA28) : Colors.white,
            crit ? 26 : 20,
          ),
        );
        _impacts.add(_Impact(crit));
        final n = crit ? 7 : 4;
        for (var i = 0; i < n; i++) {
          final ang = _rng.nextDouble() * math.pi * 2;
          final sp = 120 + _rng.nextDouble() * 200;
          _particles.add(
            _Particle(
              math.cos(ang) * sp,
              math.sin(ang) * sp - 120,
              crit ? const Color(0xFFFFCA28) : Colors.white,
            ),
          );
        }
        if (_particles.length > 40) {
          _particles.removeRange(0, _particles.length - 40);
        }
        _screenShake = crit ? 0.7 : 0.4;
        _dmgCooldown = 0.12;
      }
      guard++;
    }
    if (_hp <= 0) _beginDeath(stats);
  }

  void _beginDeath(CharacterStats stats) {
    final depth = _stage - 1;
    final gold = rewardGold(
      _config,
      depth,
      stats.rewardMultiplier,
      boss: _isBoss,
    );
    final xp = (rewardXp(_config, depth, boss: _isBoss) * stats.xpMultiplier)
        .round();

    IndividualBug? bug;
    final bugChance = _isBoss ? 1.0 : _config.bugDropChance * stats.bugFind;
    if (_rng.nextDouble() < bugChance) {
      final sp = _data.allSpecies[_rng.nextInt(_data.allSpecies.length)];
      final potential = 1 + (_rng.nextDouble() * _rng.nextDouble() * 4).floor();
      bug = IndividualBug.roll(
        id: _uuid.v4(),
        species: sp,
        rng: _rng,
        potential: potential.clamp(1, 5),
      );
    }

    Map<MaterialKind, int>? mats;
    if (_rng.nextDouble() < _config.materialDropChance * stats.materialFind) {
      final kind =
          MaterialKind.values[_rng.nextInt(MaterialKind.values.length)];
      mats = {kind: 1 + _rng.nextInt(2)};
    }

    ref
        .read(saveControllerProvider.notifier)
        .applyReward(gold: gold, xp: xp, bug: bug, materials: mats);

    _pops.add(
      _Pop(
        '+${formatCompact(gold)}',
        (_rng.nextDouble() - 0.5) * 0.3,
        _honey,
        18,
      ),
    );
    if (bug != null) _pops.add(_Pop('🐛', 0.25, Colors.white, 20));

    // 적이 쓰러지는 연출(죽음 애니) 후 다음으로.
    _dying = true;
    _dyingT = _deathDuration;
  }

  void _advanceAfterDeath() {
    _dying = false;
    _playerHp = math.min(_playerHpMax, _playerHp + _playerHpMax * 0.3);
    if (_isBoss) {
      _stage++;
      ref.read(saveControllerProvider.notifier).reachStage(_stage);
      _habitatIndex = 0;
    } else {
      _habitatIndex++;
    }
    // 다음 몬스터를 즉시 스폰해 걷는 동안 이전 몬스터가 다시 보이지 않게 함.
    _spawn();
    _walking = true;
    _walkT = 0;
  }

  void _beginDefeat() {
    // 즉시 넘어가지 않고 다친/죽는 연출을 보여준 뒤 후퇴.
    _defeated = true;
    _defeatT = _defeatDuration;
    _retreatFlash = _defeatDuration;
  }

  void _resumeAfterDefeat() {
    _defeated = false;
    _retreatFlash = 0;
    _stage = math.max(1, _stage - 1); // 한 스테이지 뒤로
    _habitatIndex = 0;
    _playerHp = _playerHpMax;
    _spawn();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final save = ref.watch(saveControllerProvider).requireValue;
    return Column(
      children: [
        SafeArea(bottom: false, child: _TopBar(save: save)),
        _StageBanner(
          regionName: _config
              .regionForStage(_stage)
              .name
              .resolve(Localizations.localeOf(context).languageCode),
          chapter: (_stage - 1) ~/ _config.stagesPerRegion + 1,
          stageInRegion: (_stage - 1) % _config.stagesPerRegion + 1,
          habitatIndex: _habitatIndex,
          habitatsPerStage: _config.habitatsPerStage,
          isBoss: _isBoss,
        ),
        Expanded(flex: 50, child: _combatViewport(l)),
        Expanded(flex: 50, child: _upgradePanel(l, save)),
      ],
    );
  }

  Widget _combatViewport(AppLocalizations l) {
    final hpFrac = (_hp / _hpMax).clamp(0.0, 1.0);
    final pHpFrac = (_playerHp / _playerHpMax).clamp(0.0, 1.0);
    final shake = _hitFlash * math.sin(_hitFlash * 40) * 3;
    // 걷는 동안 새 적이 오른쪽에서 슬라이드해 들어옴.
    final walkSlide = _walking
        ? (1 - (_walkT / _walkDuration).clamp(0.0, 1.0)) * 320
        : 0.0;
    final shakeOffset = Offset(
      math.sin(_screenShake * 90) * _screenShake * 4,
      math.cos(_screenShake * 70) * _screenShake * 3.5,
    );

    final regionId = _config.regionForStage(_stage).id;
    final deathP = _dying
        ? (1 - _dyingT / _deathDuration).clamp(0.0, 1.0)
        : 0.0;

    // 캐릭터 상태/프레임
    String cState;
    int cFrame;
    if (_defeated) {
      cState = 'death';
      cFrame = _defeatT > _defeatDuration * 0.5 ? 1 : 2;
    } else if (_attackPulse > 0.12) {
      cState = 'attack';
      cFrame = _attackPulse > 0.6 ? 1 : 2;
    } else {
      cState = 'idle';
      cFrame = 1;
    }
    final charOpacity = _defeated
        ? (0.12 + 0.88 * (_defeatT / _defeatDuration)).clamp(0.12, 1.0)
        : 1.0;
    final cPaths = [
      'assets/images/character/${cState}_$cFrame.webp',
      'assets/images/character/$cState.webp',
      'assets/images/character/idle.webp',
    ];

    // 적 상태/프레임 (보스는 공격/죽음 애니, 서식지는 idle/죽음)
    String eState;
    int eFrame;
    if (_dying) {
      eState = 'death';
      eFrame = deathP < 0.5 ? 1 : 2;
    } else if (_isBoss && _bossLunge > 0) {
      eState = 'attack';
      eFrame = _bossLunge > 0.5 ? 1 : 2;
    } else {
      eState = 'idle';
      eFrame = 1;
    }
    final ePaths = _isBoss
        ? [
            'assets/images/bosses/${regionId}_${eState}_$eFrame.webp',
            'assets/images/bosses/$regionId.webp',
          ]
        : [
            'assets/images/habitats/${_kind.key}_${eState}_$eFrame.webp',
            'assets/images/habitats/${_kind.key}.webp',
          ];
    final enemyBase = gameImageChain(
      ePaths,
      size: _isBoss ? 172 : 84,
      byHeight: true,
      fallback: _isBoss
          ? const Text('🪲', style: TextStyle(fontSize: 72))
          : Text(habitatGlyph(_kind), style: const TextStyle(fontSize: 52)),
    );
    final Widget enemyWidget = _dying
        ? Opacity(
            opacity: (1 - deathP).clamp(0.0, 1.0),
            child: Transform.rotate(
              angle: deathP * 1.3,
              alignment: Alignment.bottomCenter,
              child: Transform.translate(
                offset: Offset(0, deathP * 18),
                child: enemyBase,
              ),
            ),
          )
        : _EnemyArt(art: enemyBase, hitFlash: _hitFlash);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _boost = _boostDuration),
      child: ClipRect(
        child: Transform.translate(
          offset: shakeOffset,
          child: Stack(
            children: [
              // 화면 흔들림 시 가장자리 틈이 보이지 않게 배경을 크게(오버스캔) 깐다.
              Positioned(
                left: -24,
                top: -24,
                right: -24,
                bottom: -24,
                child: SceneBackground(
                  assetPath:
                      'assets/images/regions/${_config.regionForStage(_stage).id}.webp',
                ),
              ),
              // 적/서식지 (하단=발 기준 정렬)
              Align(
                alignment: const Alignment(0.45, 1.0),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Transform.translate(
                    offset: Offset(shake - _bossLunge * 24 + walkSlide, 0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isBoss)
                          Container(
                            margin: const EdgeInsets.only(bottom: 2),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xCCE8503A),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              l.bossLabel,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        _Bar(
                          fraction: hpFrac,
                          wide: _isBoss,
                          colors: const [Color(0xFFFF7043), Color(0xFFE53935)],
                          label:
                              '${formatCompact(_hp.clamp(0, _hpMax))} / ${formatCompact(_hpMax)}',
                        ),
                        const SizedBox(height: 4),
                        enemyWidget,
                      ],
                    ),
                  ),
                ),
              ),

              // 캐릭터 + 플레이어 HP바 (하단=발 기준 정렬)
              Align(
                alignment: const Alignment(-0.55, 1.0),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _Bar(
                        fraction: pHpFrac,
                        wide: false,
                        colors: const [Color(0xFF81C784), Color(0xFF43A047)],
                        label:
                            '${formatCompact(_playerHp.clamp(0, _playerHpMax))} / ${formatCompact(_playerHpMax)}',
                      ),
                      const SizedBox(height: 4),
                      Transform.translate(
                        offset: Offset(
                          _attackPulse * 24 +
                              _playerHitFlash *
                                  math.sin(_playerHitFlash * 40) *
                                  4,
                          _walking ? math.sin(_bgOffset * 0.4) * 2 : 0,
                        ),
                        child: Transform.rotate(
                          angle: _attackPulse * 0.22,
                          alignment: Alignment.bottomCenter,
                          child: Opacity(
                            opacity: charOpacity,
                            child: gameImageChain(
                              cPaths,
                              size: 92,
                              fallback: const Text(
                                '🧑‍🌾',
                                style: TextStyle(fontSize: 50),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 팝업(데미지/골드)
              for (final p in _pops)
                Align(
                  alignment: Alignment(p.baseX + p.dx, 0.0 - p.age * 0.5),
                  child: Opacity(
                    opacity: (1 - p.age).clamp(0.0, 1.0),
                    child: Text(
                      p.text,
                      style: TextStyle(
                        color: p.color,
                        fontWeight: FontWeight.w900,
                        fontSize: p.size,
                        shadows: const [
                          Shadow(color: Colors.black87, blurRadius: 4),
                        ],
                      ),
                    ),
                  ),
                ),

              // 임팩트 스파크 + 파편
              Positioned.fill(
                child: IgnorePointer(
                  child: LayoutBuilder(
                    builder: (context, c) {
                      final ex = c.maxWidth * 0.72;
                      final ey = c.maxHeight * 0.6;
                      return Stack(
                        children: [
                          for (final pt in _particles)
                            Positioned(
                              left: ex + pt.x,
                              top: ey + pt.y,
                              child: Opacity(
                                opacity: (1 - pt.age / 0.5).clamp(0.0, 1.0),
                                child: Container(
                                  width: 5,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: pt.color,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                            ),
                          for (final im in _impacts)
                            Positioned(
                              left: ex - (im.crit ? 45 : 35),
                              top: ey - (im.crit ? 45 : 35),
                              child: SizedBox(
                                width: im.crit ? 90 : 70,
                                height: im.crit ? 90 : 70,
                                child: CustomPaint(
                                  painter: _ImpactPainter(
                                    im.age / 0.28,
                                    im.crit,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),

              // 타격감: 때릴 때 하얀 유리 균열, 맞을 때 빨간 유리 균열
              if (_attackPulse > 0.01)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _CrackPainter(
                        _cracks,
                        _attackPulse,
                        Colors.white,
                      ),
                    ),
                  ),
                ),
              if (_playerHitFlash > 0.01)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _CrackPainter(
                        _cracks,
                        _playerHitFlash,
                        const Color(0xFFFF5252),
                      ),
                    ),
                  ),
                ),

              if (_retreatFlash > 0)
                Center(
                  child: Opacity(
                    opacity: (_retreatFlash / 1.5).clamp(0.0, 1.0),
                    child: Text(
                      l.retreat,
                      style: const TextStyle(
                        color: Color(0xFFFF5252),
                        fontWeight: FontWeight.w900,
                        fontSize: 34,
                        shadows: [Shadow(color: Colors.black, blurRadius: 6)],
                      ),
                    ),
                  ),
                ),

              if (_boost > 0)
                Positioned(
                  top: 8,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: _glass(),
                    child: const Text(
                      '⚡ BOOST',
                      style: TextStyle(
                        color: _honey,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              Positioned(
                bottom: 6,
                left: 0,
                right: 0,
                child: Center(
                  child: Text(
                    l.tapBoostHint,
                    style: const TextStyle(
                      color: Color(0x99FFFFFF),
                      fontSize: 10.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _upgradePanel(AppLocalizations l, SaveGame save) {
    final kinds = _config.upgrades.keys.toList();
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xF21C2A12), Color(0xF20B1206)],
        ),
        border: Border(top: BorderSide(color: Color(0x33FFFFFF))),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
            child: Row(
              children: [
                for (final amount in [1, 10, 100])
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: _AmountButton(
                        amount: amount,
                        selected: _buyAmount == amount,
                        onTap: () => setState(() => _buyAmount = amount),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              itemCount: kinds.length,
              itemBuilder: (context, i) {
                final kind = kinds[i];
                return _UpgradeRow(
                  kind: kind,
                  config: _config,
                  level: save.upgradeLevel(kind),
                  gold: save.gold,
                  buyAmount: _buyAmount,
                  onBuy: () => ref
                      .read(saveControllerProvider.notifier)
                      .buyUpgrade(kind, count: _buyAmount),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.save});
  final SaveGame save;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final xpNeed = xpForNextLevel(save.level);
    final totalMats = MaterialKind.values.fold<int>(
      0,
      (a, k) => a + save.materialCount(k),
    );
    return Container(
      color: const Color(0xF20B1206),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: _glass(10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                goldIcon(size: 18),
                const SizedBox(width: 5),
                Text(
                  formatCompact(save.gold),
                  key: const Key('goldHud'),
                  style: const TextStyle(
                    color: _onScene,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _pill('🧪', formatCompact(totalMats)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  l.levelBadge(save.level),
                  style: const TextStyle(
                    color: _onScene,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 3),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (save.xp / xpNeed).clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: const Color(0x33FFFFFF),
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF66BB6A)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(String icon, String value) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: _glass(10),
    child: Text(
      '$icon $value',
      style: const TextStyle(
        color: _onScene,
        fontWeight: FontWeight.w800,
        fontSize: 13,
      ),
    ),
  );
}

class _StageBanner extends StatelessWidget {
  const _StageBanner({
    required this.regionName,
    required this.chapter,
    required this.stageInRegion,
    required this.habitatIndex,
    required this.habitatsPerStage,
    required this.isBoss,
  });

  final String regionName;
  final int chapter;
  final int stageInRegion;
  final int habitatIndex;
  final int habitatsPerStage;
  final bool isBoss;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xF2101A0A),
        border: Border(bottom: BorderSide(color: Color(0x66EBA52F), width: 2)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(
        children: [
          Text(
            '🌳 $regionName',
            style: const TextStyle(
              color: _onScene,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            isBoss
                ? '$chapter-$stageInRegion · ${l.bossLabel}'
                : '$chapter-$stageInRegion · $habitatIndex/$habitatsPerStage',
            style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _AmountButton extends StatelessWidget {
  const _AmountButton({
    required this.amount,
    required this.selected,
    required this.onTap,
  });
  final int amount;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: selected
              ? const LinearGradient(
                  colors: [Color(0xFFFFD977), Color(0xFFEBA52F)],
                )
              : null,
          color: selected ? null : const Color(0x33FFFFFF),
          border: Border.all(
            color: selected ? Colors.transparent : const Color(0x33FFFFFF),
          ),
        ),
        child: Text(
          '+$amount',
          style: TextStyle(
            color: selected ? const Color(0xFF3A2600) : _onScene,
            fontWeight: FontWeight.w900,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class _UpgradeRow extends StatelessWidget {
  const _UpgradeRow({
    required this.kind,
    required this.config,
    required this.level,
    required this.gold,
    required this.buyAmount,
    required this.onBuy,
  });

  final UpgradeKind kind;
  final RunConfig config;
  final int level;
  final int gold;
  final int buyAmount;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final spec = config.upgrade(kind);
    final singleCost = upgradeCost(spec, level);
    final batchCost = bulkUpgradeCost(spec, level, buyAmount);
    final cur = spec.valueAt(level);
    final next = spec.valueAt(level + 1);
    final affordable = gold >= singleCost;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      decoration: BoxDecoration(
        color: const Color(0x22FFFFFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x1AFFFFFF)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 46,
            height: 46,
            child: upgradeImage(
              kind,
              size: 46,
              fallback: Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _statColor(kind),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_statIcon(kind), color: Colors.white, size: 21),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_statLabel(l, kind)}  Lv.$level',
                  style: const TextStyle(
                    color: _onScene,
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _valuePair(kind, cur, next),
                  style: const TextStyle(
                    color: Color(0xB3FFFFFF),
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: affordable ? onBuy : null,
            child: Container(
              width: 96,
              padding: const EdgeInsets.symmetric(vertical: 8),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: affordable
                    ? const Color(0xFF2E7D32)
                    : const Color(0x33000000),
                border: Border.all(
                  color: affordable
                      ? const Color(0xFF66BB6A)
                      : const Color(0x22FFFFFF),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '+$buyAmount Lv',
                    style: TextStyle(
                      color: affordable
                          ? Colors.white
                          : const Color(0x66FFFFFF),
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    '💰 ${formatCompact(batchCost)}',
                    style: TextStyle(
                      color: affordable
                          ? const Color(0xFFFFE082)
                          : const Color(0x66FFFFFF),
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.fraction,
    required this.wide,
    required this.colors,
    this.label,
  });
  final double fraction;
  final bool wide;
  final List<Color> colors;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: wide ? 152 : 106,
      height: 15,
      decoration: BoxDecoration(
        color: const Color(0x99000000),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: const Color(0x33FFFFFF)),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: fraction.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: colors),
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
            ),
          ),
          if (label != null)
            Center(
              child: Text(
                label!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  height: 1.0,
                  fontWeight: FontWeight.w800,
                  shadows: [Shadow(color: Colors.black, blurRadius: 2)],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

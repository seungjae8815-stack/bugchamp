import 'dart:math' as math;

import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../app_version.dart';
import '../../data/game_data.dart';
import '../../domain/cloud_save_service.dart';
import '../../domain/providers.dart';
import '../../domain/pvp_backend.dart';
import '../../domain/save_controller.dart';
import '../../domain/gift_mail.dart';
import '../../domain/save_game.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/art.dart';
import '../../ui/concept_card.dart';
import '../../ui/format.dart';
import '../../ui/game_dialog.dart';
import '../../ui/labels.dart';
import '../leaderboard/leaderboard_screen.dart';
import '../roadmap/roadmap_screen.dart';

const _uuid = Uuid();
const _honey = Color(0xFFEBA52F);
const _onScene = Color(0xFFFFFFFF);

/// 일반 강화 재료(처치/채집 드롭 대상). 젤리는 프리미엄이라 제외(§E).
const _regularMaterials = [
  MaterialKind.chitin,
  MaterialKind.mineral,
  MaterialKind.sap,
];
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

String _statDesc(AppLocalizations l, UpgradeKind k) => switch (k) {
  UpgradeKind.attack => l.upAttackDesc,
  UpgradeKind.attackSpeed => l.upAttackSpeedDesc,
  UpgradeKind.crit => l.upCritDesc,
  UpgradeKind.critDamage => l.upCritDamageDesc,
  UpgradeKind.bossDamage => l.upBossDamageDesc,
  UpgradeKind.maxHp => l.upMaxHpDesc,
  UpgradeKind.defense => l.upDefenseDesc,
  UpgradeKind.regen => l.upRegenDesc,
  UpgradeKind.reward => l.upRewardDesc,
  UpgradeKind.xp => l.upXpDesc,
  UpgradeKind.bugFind => l.upBugFindDesc,
  UpgradeKind.materialFind => l.upMaterialFindDesc,
  UpgradeKind.moveSpeed => l.upMoveSpeedDesc,
  UpgradeKind.boost => l.upBoostDesc,
  UpgradeKind.bugBuff => l.upBugBuffDesc,
};

/// 업그레이드 아이콘 탭 시 뜨는 상세 설명 카드.
void _showUpgradeInfo(
  BuildContext context,
  AppLocalizations l,
  UpgradeKind kind,
  double cur,
) {
  showConceptCard(
    context,
    // 업그레이드 목록과 동일한 아이콘(이미지 없으면 동일 색상칩 폴백).
    iconBox: SizedBox(
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
          child: Icon(_statIcon(kind), color: Colors.white, size: 24),
        ),
      ),
    ),
    title: _statLabel(l, kind),
    body: _statDesc(l, kind),
    closeLabel: l.actionClose,
  );
}

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
  _Pop(
    this.text,
    this.dx,
    this.color,
    this.size, {
    this.baseX = 0.4,
    this.baseY = 0.0,
    this.delay = 0,
  });
  final String text;
  final double dx;
  final Color color;
  final double size;
  final double baseX;
  final double baseY; // 시작 세로 위치(−1 상단 ~ 1 하단).
  double delay; // 이 시간(초)이 지난 뒤부터 떠오르기 시작.
  double age = 0;
}

class _Impact {
  _Impact(this.crit);
  final bool crit;
  double age = 0;
}

/// 처치 시 몬스터 근처에서 튀어나와 캐릭터로 빨려 들어가는 재화 알갱이.
class _Pickup {
  _Pickup(this.glyph, this.color, this.scatterX, this.scatterY, this.life);
  final String glyph;
  final Color color;
  final double scatterX; // 초기 흩뿌림(적 기준 픽셀)
  final double scatterY;
  final double life; // 총 수명(초). 도착까지 시간.
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

  /// 설정의 빌드 상세(빌드일·기능) 펼침 여부.
  bool _showBuildDetail = false;

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
  double _giftCheckAcc = 0; // 깜짝 선물 스폰 체크 누적(초)
  double _attackPulse = 0;
  double _hitFlash = 0;
  double _boost = 0;
  double _tapHint = 0; // 손가락 탭 힌트 애니 주기
  double _bgOffset = 0;
  double _dmgCooldown = 0;
  double _enemyAtkAcc = 0;
  double _enemyLunge = 0; // 적(보스·서식지) 공격 달려듦 모션 값
  double _playerHitFlash = 0;
  double _screenShake = 0;

  int _buyAmount = 1;
  final List<_Pop> _pops = [];
  final List<_Impact> _impacts = [];
  final List<_Particle> _particles = [];
  final List<_Pickup> _pickups = [];

  late final Clock _clock;
  late final List<List<Offset>> _cracks;
  bool _dying = false;
  double _dyingT = 0;
  bool _defeated = false;
  double _defeatT = 0;

  @override
  void initState() {
    super.initState();
    _cracks = _makeCracks();
    _clock = ref.read(clockProvider);
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
        _showOfflineReward(offline);
      });
    }
    // 선물 예약 초기화 + 만료 정리(첫 진입 시).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) controller.maybeSpawnGift();
    });
  }

  /// 복귀 보상 팝업(방치 정산).
  void _showOfflineReward(OfflineReport r) {
    final l = AppLocalizations.of(context);
    final d = r.accrued;
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final timeStr = h > 0 ? l.durationHm(h, m) : l.durationM(m);
    showGameDialog<void>(
      context,
      title: l.offlineTitle,
      subtitle: l.offlineElapsed(timeStr),
      icon: Icons.wb_sunny_rounded,
      content: gameRewardList(context, gold: r.gold, xp: r.xp),
      actions: [gameDialogButton(l.actionClose, () => Navigator.pop(context))],
    );
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
    _enemyLunge = 0;
    _dying = false;
  }

  /// 업그레이드/레벨 기반 순수 능력치(버프 미포함) — 전투력 표시에 사용.
  /// 업그레이드/레벨만의 순수 능력치(펫·버프 미포함).
  CharacterStats _baseStats(SaveGame save) => deriveStats(
    _config,
    upgradeLevels: save.upgradeLevels,
    characterLevel: save.level,
    bugsCollected: save.bugs.length,
  );

  /// 장착 애완펫 보너스까지 반영한 능력치 — 전투력 표시 기준.
  CharacterStats _petStats(SaveGame save) {
    final base = _baseStats(save);
    final cfg = _data.petConfig;
    if (cfg == null || save.equippedBugIds.isEmpty) return base;
    final now = _clock.now().toUtc();
    final pets = <PetStat>[];
    for (final id in save.equippedBugIds) {
      IndividualBug? bug;
      for (final b in save.bugs) {
        if (b.id == id) {
          bug = b;
          break;
        }
      }
      if (bug == null) continue;
      final sp = _data.speciesById[bug.speciesId];
      if (sp == null) continue;
      pets.add((
        grade: sp.grade,
        sizeMult: bug.statMultiplier(sp),
        potential: bug.potential,
        enhanceTotal: bug.enhancement.total,
        stage: effectiveStage(bug.stage, bug.stageSince, now, cfg),
        level: bug.level,
      ));
    }
    return _applyPetBonus(base, computePetBonus(pets, cfg));
  }

  CharacterStats _applyPetBonus(CharacterStats s, PetBonus pb) =>
      CharacterStats(
        attack: s.attack * pb.attackMult,
        attackSpeed: s.attackSpeed,
        rewardMultiplier: s.rewardMultiplier,
        critChance: s.critChance,
        critDamage: s.critDamage,
        bossDamage: s.bossDamage,
        maxHp: s.maxHp * pb.hpMult,
        defense: s.defense,
        hpRegen: s.hpRegen,
        xpMultiplier: s.xpMultiplier,
        bugFind: s.bugFind,
        materialFind: s.materialFind,
        moveSpeed: s.moveSpeed,
        boostBonus: s.boostBonus,
      );

  /// 펫 + 활성 버프까지 반영한 유효 능력치 — 전투/보상 계산에 사용.
  CharacterStats _stats(SaveGame save) => applyBuffs(
    _petStats(save),
    save.activeBuffs(_clock.now().toUtc()),
    _data.buffConfig,
  );

  void _tick(Duration elapsed) {
    final raw = (elapsed - _lastElapsed).inMicroseconds / 1000000.0;
    _lastElapsed = elapsed;
    final dt = raw.clamp(0.0, 0.05);
    if (dt <= 0) return;
    setState(() => _step(dt));
    // 온라인 중 주기적으로 깜짝 선물 스폰 체크(20초마다).
    _giftCheckAcc += dt;
    if (_giftCheckAcc >= 20) {
      _giftCheckAcc = 0;
      ref.read(saveControllerProvider.notifier).maybeSpawnGift();
    }
  }

  void _step(double dt) {
    _tapHint += dt;
    if (_tapHint > 60) _tapHint -= 60; // 시작 시 1회 + 60초마다
    if (_boost > 0) _boost = math.max(0, _boost - dt);
    if (_attackPulse > 0) _attackPulse = math.max(0, _attackPulse - dt * 2.6);
    if (_hitFlash > 0) _hitFlash = math.max(0, _hitFlash - dt * 7);
    if (_retreatFlash > 0) _retreatFlash = math.max(0, _retreatFlash - dt);
    if (_enemyLunge > 0) _enemyLunge = math.max(0, _enemyLunge - dt * 3);
    if (_playerHitFlash > 0) {
      _playerHitFlash = math.max(0, _playerHitFlash - dt * 4);
    }
    if (_dmgCooldown > 0) _dmgCooldown -= dt;
    for (final p in _pops) {
      if (p.delay > 0) {
        p.delay -= dt;
        continue;
      }
      p.age += dt;
    }
    _pops.removeWhere((p) => p.age > 1.0);
    for (final pk in _pickups) {
      pk.age += dt;
    }
    _pickups.removeWhere((pk) => pk.age > pk.life);
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

    // 적 반격 — 보스·일반 서식지 모두 주기적으로 달려들어(공격 모션) 그 순간 피해.
    final depth = _stage - 1;
    final threat = habitatThreat(_config, depth, boss: _isBoss);
    final incoming = threat * 100 / (100 + stats.defense);
    // 회복은 상시 적용.
    _playerHp = math.min(_playerHpMax, _playerHp + stats.hpRegen * dt);
    _enemyAtkAcc += dt;
    final atkInterval = _isBoss ? 1.3 : 1.5;
    if (_enemyAtkAcc >= atkInterval) {
      _enemyAtkAcc -= atkInterval;
      // 서식지는 이전 상시 피해와 평균 DPS가 같도록 interval 만큼 묶어서 준다.
      final burst = incoming * atkInterval * (_isBoss ? 1.4 : 1.0);
      if (burst > 0) {
        _playerHp -= burst;
        _enemyLunge = 1; // 공격 모션(캐릭터 쪽으로 달려듦)
        _playerHitFlash = _isBoss ? 1.0 : 0.6;
        _pops.add(
          _Pop(
            '-${formatCompact(burst)}',
            (_rng.nextDouble() - 0.5) * 0.2,
            const Color(0xFFFF5252),
            _isBoss ? 18 : 15,
            baseX: -0.55,
            baseY: 0.3,
          ),
        );
      }
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
      ).copyWith(stage: LifeStage.egg, stageSince: _clock.now().toUtc());
    }

    Map<MaterialKind, int>? mats;
    if (_rng.nextDouble() < _config.materialDropChance * stats.materialFind) {
      final kind = _regularMaterials[_rng.nextInt(_regularMaterials.length)];
      mats = {kind: 1 + _rng.nextInt(2)};
    }

    ref
        .read(saveControllerProvider.notifier)
        .applyReward(
          gold: gold,
          xp: xp,
          bug: bug,
          materials: mats,
          mission: _isBoss ? MissionType.killBosses : MissionType.killMonsters,
        );

    // 재화 드롭 연출: 처치 지점에서 코인/재료가 튀어나와 캐릭터로 빨려 들어간다.
    _spawnPickups(hasMaterial: mats != null, hasBug: bug != null);

    // 코인이 캐릭터에 도착할 즈음(≈0.42s 뒤) +골드 / +경험치 숫자가 캐릭터 쪽에서 떠오름.
    _pops.add(
      _Pop(
        '+${formatCompact(gold)} Gold',
        (_rng.nextDouble() - 0.5) * 0.2,
        _honey,
        17,
        baseX: -0.55,
        baseY: 0.35,
        delay: 0.42,
      ),
    );
    if (xp > 0) {
      _pops.add(
        _Pop(
          '+${formatCompact(xp)} xp',
          (_rng.nextDouble() - 0.5) * 0.2,
          const Color(0xFF66D9FF),
          15,
          baseX: -0.35,
          baseY: 0.5,
          delay: 0.52,
        ),
      );
    }
    // 곤충 포획 시 캐릭터에 획득 표시.
    if (bug != null) {
      _pops.add(
        _Pop(
          '🐛 +1',
          (_rng.nextDouble() - 0.5) * 0.15,
          const Color(0xFFB9F6CA),
          17,
          baseX: -0.45,
          baseY: 0.2,
          delay: 0.62,
        ),
      );
    }

    // 적이 쓰러지는 연출(죽음 애니) 후 다음으로.
    _dying = true;
    _dyingT = _deathDuration;
  }

  /// 처치 지점(몬스터 발밑)에서 아래로 떨어졌다가 캐릭터 발밑으로 끌려가는 재화 생성.
  void _spawnPickups({required bool hasMaterial, required bool hasBug}) {
    for (var i = 0; i < 5; i++) {
      _pickups.add(
        _Pickup(
          '🪙',
          _honey,
          (_rng.nextDouble() - 0.5) * 46,
          8 + _rng.nextDouble() * 26, // 몬스터 아래로 흩어짐
          0.42 + _rng.nextDouble() * 0.18,
        ),
      );
    }
    if (hasMaterial) {
      _pickups.add(
        _Pickup(
          '💠',
          const Color(0xFF4FC3F7),
          (_rng.nextDouble() - 0.5) * 30,
          14,
          0.55,
        ),
      );
    }
    if (hasBug) {
      _pickups.add(_Pickup('🐛', Colors.white, 0, 6, 0.62));
    }
    if (_pickups.length > 60) {
      _pickups.removeRange(0, _pickups.length - 60);
    }
  }

  void _advanceAfterDeath() {
    _dying = false;
    _playerHp = math.min(_playerHpMax, _playerHp + _playerHpMax * 0.3);
    if (_isBoss) {
      _stage++;
      _habitatIndex = 0;
      _afterBossAdvance(_stage); // 최고기록 갱신 + 챕터 클리어 보상
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
        SafeArea(bottom: false, child: _topSection(l, save)),
        // 스테이지 배너는 이제 사냥 화면 위 오버레이로 → 사냥 화면이 더 넓어짐.
        Expanded(flex: 54, child: _combatViewport(l)),
        Expanded(flex: 46, child: _upgradePanel(l, save)),
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
    } else if (_enemyLunge > 0) {
      eState = 'attack';
      eFrame = _enemyLunge > 0.5 ? 1 : 2;
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
    final rawEnemy = gameImageChain(
      ePaths,
      size: _isBoss ? 172 : 84,
      byHeight: true,
      fallback: _isBoss
          ? const Text('🪲', style: TextStyle(fontSize: 72))
          : Text(habitatGlyph(_kind), style: const TextStyle(fontSize: 52)),
    );
    // 보스는 캐릭터(좌측)를 바라보도록 좌우 반전(지역별 bossFlip).
    final enemyBase = _isBoss && _config.regionForStage(_stage).bossFlip
        ? Transform.scale(
            scaleX: -1,
            alignment: Alignment.center,
            child: rawEnemy,
          )
        : rawEnemy;
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
              // 좌측 오버레이: 퀘스트 진행 + 재화 목록 (레퍼런스 차용)
              Positioned(
                left: 8,
                top: 8,
                child: _questAndResources(
                  l,
                  ref.watch(saveControllerProvider).requireValue,
                ),
              ),
              // 상단 중앙 오버레이: 스테이지 배너
              Positioned(top: 8, left: 0, right: 0, child: _stageOverlay(l)),
              // 적/서식지 (하단=발 기준 정렬)
              Align(
                alignment: const Alignment(0.45, 1.0),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Transform.translate(
                    offset: Offset(shake - _enemyLunge * 24 + walkSlide, 0),
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

              // 장착 펫: 캐릭터 뒤를 따라다니는 작은 동행
              _petFollowers(),

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
                  alignment: Alignment(p.baseX + p.dx, p.baseY - p.age * 0.5),
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
                      // 픽업: 몬스터 발밑 → 캐릭터 발밑(화면 하단)으로.
                      final pex = c.maxWidth * 0.7;
                      final pey = c.maxHeight * 0.82;
                      final pcx = c.maxWidth * 0.22;
                      final pcy = c.maxHeight * 0.9;
                      return Stack(
                        children: [
                          for (final pk in _pickups)
                            _buildPickup(pk, pex, pey, pcx, pcy),
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
              // 부스트 유도: 주기적으로 나타났다 사라지는 손가락 탭 아이콘
              if (_boost <= 0) _buildTapHint(),
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
                  materials: save.materials,
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
  // ─────────────────────────────────────────────────────────────
  // 상단 상태창 + 버프 스트립 (레퍼런스 레이아웃 차용)
  // ─────────────────────────────────────────────────────────────

  Widget _topSection(AppLocalizations l, SaveGame save) => Container(
    color: const Color(0xF20B1206),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [_topBar(l, save), _chatBar(l)],
    ),
  );

  Widget _topBar(AppLocalizations l, SaveGame save) {
    final xpNeed = xpForNextLevel(save.level);
    final cp = combatPower(_petStats(save));
    final now = _clock.now().toUtc();
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 8, 6),
      child: Row(
        children: [
          // 캐릭터 초상화 → 탭하면 능력치/닉네임 카드
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => _showCharacterCard(l, save),
            child: _portrait(save),
          ),
          const SizedBox(width: 8),
          // 닉네임 · 전투력 · 경험치
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  save.nickname,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _onScene,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.local_fire_department,
                      color: _honey,
                      size: 13,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${l.combatPowerLabel} ${formatCompact(cp)}',
                      style: const TextStyle(
                        color: _honey,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (save.xp / xpNeed).clamp(0.0, 1.0),
                    minHeight: 5,
                    backgroundColor: const Color(0x33FFFFFF),
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF66BB6A)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          // 재화: 골드 + 다이아(젤리)만 — 두 칸 폭을 동일하게(IntrinsicWidth).
          IntrinsicWidth(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _resourcePill(
                  goldIcon(size: 15),
                  formatCompact(save.gold),
                  valueKey: const Key('goldHud'),
                ),
                const SizedBox(height: 4),
                _resourcePill(
                  const Icon(Icons.diamond, size: 13, color: Color(0xFF4FC3F7)),
                  formatCompact(save.materialCount(MaterialKind.jelly)),
                  tint: const Color(0x3355C7F2),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          // 랭킹·편지함·설정 + 그 아래 버프 5개
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _iconBtn(
                    Icons.leaderboard_rounded,
                    () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const LeaderboardScreen(),
                      ),
                    ),
                  ),
                  _iconBtn(
                    Icons.mail_rounded,
                    () => _showMail(l),
                    badge: _hasClaimableDaily(save),
                  ),
                  _iconBtn(Icons.settings_rounded, () => _showSettings(l)),
                ],
              ),
              const SizedBox(height: 3),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _showBuffSheet(l),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final k in BuffKind.values)
                      Padding(
                        padding: const EdgeInsets.only(left: 3),
                        child: _buffMini(k, save.buffRemaining(k, now)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 상단 우측 미니 버프 아이콘 + 아래 남은시간. 탭 시 버프 시트.
  Widget _buffMini(BuffKind k, Duration? remaining) {
    final active = remaining != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Opacity(
          opacity: active ? 1.0 : 0.4,
          child: SizedBox(width: 20, height: 20, child: _buffIconCircle(k, 20)),
        ),
        SizedBox(
          height: 10,
          child: active
              ? Text(
                  _mmss(remaining),
                  style: const TextStyle(
                    color: _honey,
                    fontSize: 7.5,
                    fontWeight: FontWeight.w800,
                  ),
                )
              : null,
        ),
      ],
    );
  }

  /// 버프 스트립이 있던 자리 → 실시간 채팅 바(플레이스홀더). 탭 시 채팅 창(추후).
  Widget _chatBar(AppLocalizations l) => Padding(
    padding: const EdgeInsets.fromLTRB(10, 0, 10, 7),
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _showComingSoon(l, l.chatTitle),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0x33000000),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0x22FFFFFF)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.chat_bubble_outline_rounded,
              color: Color(0x99FFFFFF),
              size: 14,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                l.chatPlaceholder,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0x99FFFFFF),
                  fontSize: 11.5,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _portrait(SaveGame save) => SizedBox(
    width: 44,
    height: 48,
    child: Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Container(
          width: 44,
          height: 44,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: const Color(0x33000000),
            border: Border.all(
              color: _honey.withValues(alpha: 0.7),
              width: 1.5,
            ),
          ),
          child: gameImageChain(
            const [
              'assets/images/character/portrait.webp',
              'assets/images/character/idle.webp',
            ],
            size: 44,
            fallback: const Center(
              child: Text('🧑‍🌾', style: TextStyle(fontSize: 24)),
            ),
          ),
        ),
        Positioned(
          bottom: -3,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: _honey,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'Lv ${save.level}',
              style: const TextStyle(
                color: Color(0xFF3A2600),
                fontWeight: FontWeight.w900,
                fontSize: 9,
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _resourcePill(
    Widget icon,
    String value, {
    Key? valueKey,
    Color? tint,
  }) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: tint == null
        ? _glass(9)
        : BoxDecoration(
            color: tint,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: const Color(0x5555C7F2)),
          ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(width: 15, height: 15, child: Center(child: icon)),
        const SizedBox(width: 4),
        Text(
          value,
          key: valueKey,
          style: const TextStyle(
            color: _onScene,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ],
    ),
  );

  Widget _iconBtn(IconData icon, VoidCallback onTap, {bool badge = false}) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(icon, color: const Color(0xE6FFFFFF), size: 20),
              if (badge)
                Positioned(
                  right: -1,
                  top: -1,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF5252),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF0B1206),
                        width: 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );

  /// 지금 수령 가능한 일일보상/깜짝선물이 하나라도 있는지(편지 아이콘 알림 점).
  bool _hasClaimableDaily(SaveGame save) {
    final now = _clock.now();
    // 만료 전 깜짝 선물이 있으면 알림.
    final nowUtc = now.toUtc();
    if (save.gifts.any((g) => !g.isExpired(nowUtc))) return true;
    final daily = _data.dailyConfig;
    if (daily == null) return false;
    final today = dailyDateKey(now);
    for (final rw in daily.rewards) {
      if (now.hour >= rw.hour && save.dailyClaimedDate(rw.id) != today) {
        return true;
      }
    }
    return false;
  }

  /// 버프 아이콘. 아트가 이미 원형 배지라 그대로 표시(추가 프레임 없음).
  /// 아트가 없을 때만 테마색 원형 + 이모지로 폴백.
  Widget _buffIconCircle(BuffKind k, double size) => buffImage(
    k,
    size: size,
    fallback: Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF141E0C),
        border: Border.all(
          color: buffColor(k).withValues(alpha: 0.7),
          width: 1.4,
        ),
      ),
      child: Text(buffGlyph(k), style: TextStyle(fontSize: size * 0.5)),
    ),
  );

  /// 상단 중앙 스테이지 배너(사냥 화면 위 오버레이).
  Widget _stageOverlay(AppLocalizations l) {
    final region = _config.regionForStage(_stage);
    final name = region.name.resolve(
      Localizations.localeOf(context).languageCode,
    );
    final chapter = (_stage - 1) ~/ _config.stagesPerRegion + 1;
    final stageInRegion = (_stage - 1) % _config.stagesPerRegion + 1;
    final rmChapter = _data.roadmapConfig?.chapterForStage(_stage);
    final diff = rmChapter?.difficulty.resolve(
      Localizations.localeOf(context).languageCode,
    );
    return Center(
      child: GestureDetector(
        onTap: _data.roadmapConfig == null ? null : _openRoadmap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xB3101A0A),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0x66EBA52F)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    diff == null ? '🌳 $name' : '🗺 $name · $diff',
                    style: const TextStyle(
                      color: _onScene,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  if (_data.roadmapConfig != null) ...[
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.expand_more_rounded,
                      color: Color(0xAAEBA52F),
                      size: 15,
                    ),
                  ],
                ],
              ),
              Text(
                _isBoss
                    ? '$chapter-$stageInRegion · ${l.bossLabel}'
                    : '$chapter-$stageInRegion · $_habitatIndex/${_config.habitatsPerStage}',
                style: const TextStyle(
                  color: Color(0xCCFFFFFF),
                  fontSize: 10.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 보스 격파로 스테이지 상승 시: 최고기록 반영 후 새로 클리어한 챕터 축하.
  Future<void> _afterBossAdvance(int stage) async {
    final ctrl = ref.read(saveControllerProvider.notifier);
    await ctrl.reachStage(stage);
    final cleared = await ctrl.grantChapterClears();
    if (!mounted) return;
    for (final ch in cleared) {
      await _showChapterClearDialog(ch);
      if (!mounted) return;
    }
  }

  Future<void> _showChapterClearDialog(RoadmapChapter ch) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final color = Color(ch.color);
    return showGameDialog<void>(
      context,
      title: l.chapterClearTitle,
      subtitle:
          '${ch.difficulty.resolve(locale)} · 👑 ${ch.boss.resolve(locale)}',
      icon: Icons.emoji_events_rounded,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withValues(alpha: 0.35),
                  color.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color),
            ),
            child: Text(
              l.chapterClearMsg(
                ch.difficulty.resolve(locale),
                ch.boss.resolve(locale),
              ),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l.chapterClearReward,
            style: const TextStyle(
              color: Color(0xFFEBA52F),
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          gameRewardList(
            context,
            gold: ch.rewardGold,
            materials: ch.rewardMaterials,
          ),
        ],
      ),
      actions: [gameDialogButton(l.actionClose, () => Navigator.pop(context))],
    );
  }

  /// 스테이지 배너 탭 → 로드맵. 챕터 선택 시 해당 스테이지로 이동.
  Future<void> _openRoadmap() async {
    final cfg = _data.roadmapConfig;
    if (cfg == null) return;
    final save = ref.read(saveControllerProvider).requireValue;
    final target = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (_) => RoadmapScreen(
          config: cfg,
          highestStage: save.stageNumber,
          liveStage: _stage,
        ),
      ),
    );
    if (target != null && mounted) {
      _applyStageJump(target);
      ref.read(saveControllerProvider.notifier).reachStage(target);
    }
  }

  Widget _questAndResources(AppLocalizations l, SaveGame save) {
    final missions = _data.missionConfig?.missions ?? const <MissionDef>[];
    return Container(
      width: 120,
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: const Color(0x88121A10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x33FFFFFF)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.assignment_rounded, color: _honey, size: 13),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  l.missionsTitle,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _onScene,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          // 한 번에 하나의 미션만 노출. 수집하면 다음 미션으로 순환.
          if (missions.isNotEmpty)
            _missionRow(l, save, missions[_activeMissionIndex(save, missions)]),
          const Divider(height: 10, color: Color(0x22FFFFFF)),
          _resRow(goldIcon(size: 14), formatCompact(save.gold)),
          for (final m in _regularMaterials)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: _resRow(
                materialImage(
                  m,
                  size: 14,
                  fallback: Icon(
                    materialIcon(m),
                    size: 13,
                    color: Colors.white70,
                  ),
                ),
                formatCompact(save.materialCount(m)),
              ),
            ),
          // 프리미엄 재화(젤리) — 다른 재화와 동일 간격.
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: _resRow(
              const Icon(Icons.diamond, size: 13, color: Color(0xFF4FC3F7)),
              formatCompact(save.materialCount(MaterialKind.jelly)),
              valueColor: const Color(0xFF81D4FA),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resRow(Widget icon, String value, {Color valueColor = _onScene}) =>
      Row(
        children: [
          SizedBox(width: 16, height: 16, child: Center(child: icon)),
          const SizedBox(width: 5),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontWeight: FontWeight.w700,
              fontSize: 10.5,
            ),
          ),
        ],
      );

  /// 현재 노출할 미션 인덱스. 총 수집 횟수만큼 다음 미션으로 순환.
  int _activeMissionIndex(SaveGame save, List<MissionDef> missions) {
    var totalClaims = 0;
    for (final v in save.missionClaims.values) {
      totalClaims += v;
    }
    return totalClaims % missions.length;
  }

  Widget _missionRow(AppLocalizations l, SaveGame save, MissionDef def) {
    final claims = save.missionClaimCount(def.id);
    final goal = def.goalAt(claims);
    final progress = save.missionProgressCount(def.id);
    final claimable = progress >= goal;
    // 완료 시 칸을 은은하게 깜빡이는 하이라이트로.
    final pulse = 0.5 + 0.5 * math.sin(_tapHint * 4);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: claimable ? () => _claimMission(l, def.id) : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          decoration: claimable
              ? BoxDecoration(
                  color: _honey.withValues(alpha: 0.16 + 0.12 * pulse),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _honey.withValues(alpha: 0.55 + 0.45 * pulse),
                    width: 1.3,
                  ),
                )
              : null,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(missionIcon(def.type), color: _honey, size: 11),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      missionLabel(l, def.type),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _onScene,
                        fontWeight: FontWeight.w700,
                        fontSize: 10.5,
                      ),
                    ),
                  ),
                  if (claimable)
                    const Icon(Icons.card_giftcard, size: 12, color: _honey),
                ],
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: (progress / goal).clamp(0.0, 1.0),
                        minHeight: 4,
                        backgroundColor: const Color(0x33FFFFFF),
                        valueColor: const AlwaysStoppedAnimation(_honey),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$progress/$goal',
                    style: const TextStyle(
                      color: Color(0xCCFFFFFF),
                      fontSize: 8.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _claimMission(AppLocalizations l, String id) async {
    final ok = await ref.read(saveControllerProvider.notifier).claimMission(id);
    if (ok && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l.missionClaimedSnack)));
    }
  }

  /// 흩어졌다가 캐릭터로 흡수되는 재화 알갱이 1개를 배치한다.
  Widget _buildPickup(_Pickup pk, double ex, double ey, double cx, double cy) {
    final t = (pk.age / pk.life).clamp(0.0, 1.0);
    final ease = t * t; // 후반 가속(흡수)
    final sx = ex + pk.scatterX;
    final sy = ey + pk.scatterY;
    // 초반엔 살짝 더 떨어졌다가(중력) 캐릭터 발밑으로 끌려간다.
    final drop = math.sin(t * math.pi) * 10;
    final x = sx + (cx - sx) * ease;
    final y = sy + (cy - sy) * ease + drop;
    final opacity = t < 0.85 ? 1.0 : (1 - (t - 0.85) / 0.15);
    return Positioned(
      left: x - 9,
      top: y - 9,
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: Transform.scale(
          scale: 1.0 - t * 0.35,
          child: Text(
            pk.glyph,
            style: TextStyle(
              fontSize: 17,
              shadows: [
                Shadow(color: pk.color.withValues(alpha: 0.9), blurRadius: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 화면 중앙에서 크게, 시작 시 1회 + 60초마다 나타나는 손가락 탭 아이콘.
  Widget _buildTapHint() {
    const showDur = 1.9; // 노출 지속(초)
    final ph = _tapHint % 60.0;
    if (ph > showDur) return const SizedBox.shrink();
    final local = ph / showDur; // 0..1
    // 노출 구간 동안 두 번 누르는 동작.
    final press = 0.5 - 0.5 * math.cos(local * 4 * math.pi);
    final opacity = local < 0.12
        ? local / 0.12
        : (local > 0.85 ? (1 - local) / 0.15 : 1.0);
    return IgnorePointer(
      child: Center(
        child: Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 84 + press * 34,
                height: 84 + press * 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.55 * (1 - press)),
                    width: 3.5,
                  ),
                ),
              ),
              Transform.translate(
                offset: Offset(0, press * 8),
                child: Transform.scale(
                  scale: 1.0 - press * 0.2,
                  child: const Icon(
                    Icons.touch_app_rounded,
                    color: Colors.white,
                    size: 76,
                    shadows: [Shadow(color: Colors.black87, blurRadius: 10)],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 장착한 애완펫들을 캐릭터 뒤에서 살짝 떠서 따라다니게 렌더.
  Widget _petFollowers() {
    final save = ref.read(saveControllerProvider).requireValue;
    if (save.equippedBugIds.isEmpty) return const SizedBox.shrink();
    final cfg = _data.petConfig;
    final now = _clock.now().toUtc();
    // 캐릭터(x≈-0.55) 뒤(더 왼쪽) 3자리.
    const spots = <(Alignment, double)>[
      (Alignment(-0.82, 0.98), 30),
      (Alignment(-0.94, 0.90), 26),
      (Alignment(-0.72, 0.86), 24),
    ];
    final followers = <Widget>[];
    for (var i = 0; i < save.equippedBugIds.length && i < 3; i++) {
      IndividualBug? bug;
      for (final b in save.bugs) {
        if (b.id == save.equippedBugIds[i]) {
          bug = b;
          break;
        }
      }
      if (bug == null) continue;
      final sp = _data.speciesById[bug.speciesId];
      if (sp == null) continue;
      final stage = cfg == null
          ? bug.stage
          : effectiveStage(bug.stage, bug.stageSince, now, cfg);
      final (align, size) = spots[i];
      final bob = math.sin(_tapHint * 3 + i * 2.1) * 4;
      followers.add(
        Align(
          alignment: align,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            // 캐릭터 공격 시 살짝 같이 앞으로 튀며 동행감.
            child: Transform.translate(
              offset: Offset(_attackPulse * 8, bob),
              child: Opacity(
                opacity: 0.92,
                child: bugStageImage(
                  bug.speciesId,
                  stage,
                  size: size,
                  fallback: bugAvatar(sp, size: size),
                ),
              ),
            ),
          ),
        ),
      );
    }
    return Stack(children: followers);
  }

  String _mmss(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  // ── 다이얼로그/시트 ──────────────────────────────────────────

  void _showComingSoon(AppLocalizations l, String title) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$title · ${l.comingSoon}')));
  }

  /// 편지함 = 일일보상(점심/저녁). 현재 로컬 시각·수령 이력으로 상태 표시.
  void _showMail(AppLocalizations l) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xF2141F0E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Consumer(
          builder: (ctx, r, _) {
            final save = r.watch(saveControllerProvider).requireValue;
            final daily = _data.dailyConfig;
            final now = _clock.now();
            final today = dailyDateKey(now);
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.mail_rounded, color: _honey, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        l.mailTitle,
                        style: const TextStyle(
                          color: _onScene,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l.mailDailyTitle,
                    style: const TextStyle(
                      color: Color(0xFFEBA52F),
                      fontWeight: FontWeight.w700,
                      fontSize: 11.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (daily == null || daily.rewards.isEmpty)
                    Text(
                      l.mailEmpty,
                      style: const TextStyle(color: Color(0xB3FFFFFF)),
                    )
                  else
                    for (final rw in daily.rewards)
                      _dailyMailRow(ctx, r, l, save, rw, now, today),
                  const SizedBox(height: 6),
                  Text(
                    l.giftSectionTitle,
                    style: const TextStyle(
                      color: Color(0xFFEBA52F),
                      fontWeight: FontWeight.w700,
                      fontSize: 11.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ..._giftSection(ctx, r, l, save),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _giftSection(
    BuildContext ctx,
    WidgetRef r,
    AppLocalizations l,
    SaveGame save,
  ) {
    final now = _clock.now().toUtc();
    final gifts = save.gifts.where((g) => !g.isExpired(now)).toList()
      ..sort((a, b) => a.expiry.compareTo(b.expiry));
    if (gifts.isEmpty) {
      return [
        Text(
          l.giftNone,
          style: const TextStyle(color: Color(0x99FFFFFF), fontSize: 12),
        ),
      ];
    }
    return [for (final g in gifts) _giftMailRow(ctx, r, l, g, now)];
  }

  Widget _giftMailRow(
    BuildContext ctx,
    WidgetRef r,
    AppLocalizations l,
    GiftMail g,
    DateTime now,
  ) {
    final rem = g.expiry.difference(now);
    final h = rem.inHours;
    final m = rem.inMinutes % 60;
    final timeStr = h > 0 ? l.durationHm(h, m) : l.durationM(m);
    final parts = <String>[
      if (g.gold > 0) '💰${formatCompact(g.gold)}',
      if (g.jelly > 0) '💎${g.jelly}',
      if (g.chitin + g.mineral + g.sap > 0)
        '🧪${formatCompact(g.chitin + g.mineral + g.sap)}',
    ];
    // 그냥 받기(1배) → 수령 후 "광고 보고 한 번 더 받기" 제안 → 수락 시 +1배.
    Future<void> claimThenOffer() async {
      final notifier = r.read(saveControllerProvider.notifier);
      final ok = await notifier.claimGift(g.id, doubled: false);
      if (!ok || !ctx.mounted) return;
      await showRewardPopup(
        ctx,
        title: l.giftClaimedSnack,
        subtitle: l.rewardGained,
        icon: Icons.card_giftcard_rounded,
        gold: g.gold,
        materials: g.materials,
      );
      if (!ctx.mounted) return;
      final more = await showGameDialog<bool>(
        ctx,
        title: l.giftAdMoreTitle,
        icon: Icons.play_circle_fill_rounded,
        content: Text(
          l.giftAdMoreBody,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xD9FFFFFF),
            fontSize: 13.5,
            height: 1.4,
          ),
        ),
        actions: [
          gameDialogButton(
            l.giftAdMoreLater,
            () => Navigator.pop(ctx, false),
            primary: false,
          ),
          gameDialogButton(l.giftAdMoreYes, () => Navigator.pop(ctx, true)),
        ],
      );
      if (more == true && ctx.mounted) {
        await notifier.grantGiftBonus(g);
        if (!ctx.mounted) return;
        await showRewardPopup(
          ctx,
          title: l.giftDoubledSnack,
          subtitle: l.rewardGained,
          icon: Icons.play_circle_fill_rounded,
          gold: g.gold,
          materials: g.materials,
        );
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0x33EBA52F),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _honey),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.card_giftcard_rounded,
              color: Color(0xFFFFD977),
              size: 24,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    parts.join('  ·  '),
                    style: const TextStyle(
                      color: _onScene,
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                    ),
                  ),
                  Text(
                    l.giftExpiresIn(timeStr),
                    style: const TextStyle(
                      color: Color(0xCCFFFFFF),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 104,
              height: 40,
              child: FilledButton(
                onPressed: claimThenOffer,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFEBA52F),
                  foregroundColor: const Color(0xFF3A2600),
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 40),
                ),
                child: Text(
                  l.giftClaim,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _dailySlotLabel(AppLocalizations l, String id) => switch (id) {
    'lunch' => l.dailyLunch,
    'dinner' => l.dailyDinner,
    _ => id,
  };

  Widget _dailyMailRow(
    BuildContext ctx,
    WidgetRef r,
    AppLocalizations l,
    SaveGame save,
    DailyReward rw,
    DateTime now,
    String today,
  ) {
    final claimedToday = save.dailyClaimedDate(rw.id) == today;
    final unlocked = now.hour >= rw.hour;
    final claimable = unlocked && !claimedToday;
    // 보상 요약
    final parts = <String>[
      if (rw.gold > 0) '💰${formatCompact(rw.gold)}',
      if (rw.jelly > 0) '💎${rw.jelly}',
      if (rw.chitin + rw.mineral + rw.sap > 0)
        '🧪${formatCompact(rw.chitin + rw.mineral + rw.sap)}',
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: claimable ? const Color(0x33EBA52F) : const Color(0x22000000),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: claimable ? _honey : const Color(0x22FFFFFF),
          ),
        ),
        child: Row(
          children: [
            Icon(
              rw.id == 'lunch'
                  ? Icons.wb_sunny_rounded
                  : Icons.nightlight_round,
              color: const Color(0xFFFFD977),
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _dailySlotLabel(l, rw.id),
                    style: const TextStyle(
                      color: _onScene,
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                    ),
                  ),
                  Text(
                    parts.join('  ·  '),
                    style: const TextStyle(
                      color: Color(0xCCFFFFFF),
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (claimedToday)
              Text(
                l.dailyClaimedToday,
                style: const TextStyle(
                  color: Color(0x88FFFFFF),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              )
            else if (!unlocked)
              Text(
                l.dailyLockedUntil(rw.hour),
                style: const TextStyle(
                  color: Color(0x99FFFFFF),
                  fontSize: 11.5,
                ),
              )
            else
              FilledButton(
                onPressed: () async {
                  final ok = await r
                      .read(saveControllerProvider.notifier)
                      .claimDaily(rw);
                  if (ok && ctx.mounted) {
                    ScaffoldMessenger.of(ctx)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        SnackBar(content: Text(l.dailyRewardSnack)),
                      );
                  }
                },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFEBA52F),
                  foregroundColor: const Color(0xFF3A2600),
                  minimumSize: const Size(0, 36),
                ),
                child: Text(l.dailyClaim),
              ),
          ],
        ),
      ),
    );
  }

  void _showSettings(AppLocalizations l) {
    // 실기에서 어떤 빌드로 켰는지(온라인 Supabase / 로컬) 바로 확인.
    final online = ref.read(pvpBackendProvider).isRemote;
    showGameDialog<void>(
      context,
      title: l.settingsTitle,
      icon: Icons.settings_rounded,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 개발자 모드는 디버그 빌드 전용(릴리즈 노출 방지).
          if (kDebugMode) ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _showDevTools(l);
                },
                icon: const Icon(Icons.build, size: 18),
                label: const Text('개발자 모드'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2E6DA4),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _confirmReset(l);
              },
              icon: const Icon(Icons.delete_forever, size: 18),
              label: Text(l.settingsReset),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFEF9A9A),
                side: const BorderSide(color: Color(0x55EF9A9A)),
              ),
            ),
          ),
          // ── 클라우드 백업/복원 ──
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _showCloudSave(l);
              },
              icon: const Icon(Icons.cloud_sync_rounded, size: 18),
              label: Text(l.cloudTitle),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF7FD3F5),
                side: const BorderSide(color: Color(0x557FD3F5)),
              ),
            ),
          ),
          // ── 빌드 식별자 — 설치본이 어떤 업데이트인지 확인용 ──
          // ⓘ 아이콘을 누르면 빌드일·기능 상세가 펼쳐진다(기본 접힘).
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0x22FFFFFF)),
          const SizedBox(height: 8),
          StatefulBuilder(
            builder: (context, setLocal) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      InkResponse(
                        onTap: () => setLocal(
                          () => _showBuildDetail = !_showBuildDetail,
                        ),
                        radius: 16,
                        child: Icon(
                          _showBuildDetail
                              ? Icons.info_rounded
                              : Icons.info_outline_rounded,
                          size: 16,
                          color: _showBuildDetail
                              ? const Color(0xFFEBA52F)
                              : const Color(0x99FFFFFF),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        l.settingsBuildLabel(kBuildLabel),
                        style: const TextStyle(
                          color: Color(0xCCFFFFFF),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color:
                              (online ? const Color(0xFF5FD3C8) : Colors.white)
                                  .withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          online
                              ? '🌐 ${l.backendOnline}'
                              : '📴 ${l.backendLocal}',
                          style: TextStyle(
                            color: online
                                ? const Color(0xFF7FE3D8)
                                : const Color(0xCCFFFFFF),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_showBuildDetail) ...[
                    const SizedBox(height: 6),
                    Text(
                      '$kBuildDate · $kBuildHighlights',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0x99FFFFFF),
                        fontSize: 10.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
      actions: [
        gameDialogButton(
          l.actionClose,
          () => Navigator.pop(context),
          primary: false,
        ),
      ],
    );
  }

  /// 클라우드 백업/복원 시트. 백엔드 미연결이면 안내만 표시.
  Future<void> _showCloudSave(AppLocalizations l) async {
    final cloud = ref.read(cloudSaveProvider);
    final lastAt = cloud.available ? await cloud.lastBackupAt() : null;
    if (!mounted) return;
    await showGameDialog<void>(
      context,
      title: l.cloudTitle,
      icon: Icons.cloud_sync_rounded,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            cloud.available
                ? (lastAt == null
                      ? l.cloudNoBackup
                      : l.cloudLastBackup(
                          '${lastAt.toLocal()}'.split('.').first,
                        ))
                : l.cloudUnavailable,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xD9FFFFFF),
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            l.cloudAnonWarning,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0x99FFFFFF),
              fontSize: 11,
              height: 1.35,
            ),
          ),
        ],
      ),
      actions: [
        gameDialogButton(
          l.actionClose,
          () => Navigator.pop(context),
          primary: false,
        ),
        if (cloud.available)
          gameDialogButton(l.cloudRestore, () async {
            Navigator.pop(context);
            await _cloudRestore(l);
          }, color: const Color(0xFF2E6DA4)),
        if (cloud.available)
          gameDialogButton(l.cloudBackup, () async {
            Navigator.pop(context);
            await _cloudBackup(l);
          }),
      ],
    );
  }

  Future<void> _cloudBackup(AppLocalizations l) async {
    final save = ref.read(saveControllerProvider).requireValue;
    final ok = await ref.read(cloudSaveProvider).upload(save.toJson());
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(ok ? l.cloudBackupDone : l.cloudFailed)),
      );
  }

  /// 서버 세이브로 덮어쓴다(되돌릴 수 없어 확인 후 실행).
  Future<void> _cloudRestore(AppLocalizations l) async {
    final data = await ref.read(cloudSaveProvider).download();
    if (!mounted) return;
    if (data == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l.cloudNoBackup)));
      return;
    }
    final yes = await showGameDialog<bool>(
      context,
      title: l.cloudRestore,
      icon: Icons.warning_amber_rounded,
      content: Text(
        l.cloudRestoreConfirm,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xD9FFFFFF),
          fontSize: 13,
          height: 1.4,
        ),
      ),
      actions: [
        gameDialogButton(
          l.actionCancel,
          () => Navigator.pop(context, false),
          primary: false,
        ),
        gameDialogButton(
          l.cloudRestore,
          () => Navigator.pop(context, true),
          color: const Color(0xFFC85454),
        ),
      ],
    );
    if (yes != true || !mounted) return;
    final ok = await ref
        .read(saveControllerProvider.notifier)
        .restoreFromJson(data);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(ok ? l.cloudRestoreDone : l.cloudFailed)),
      );
  }

  void _confirmReset(AppLocalizations l) {
    showGameDialog<void>(
      context,
      title: l.settingsReset,
      icon: Icons.warning_amber_rounded,
      content: Text(
        l.settingsResetConfirm,
        style: const TextStyle(
          color: Color(0xD9FFFFFF),
          fontSize: 13.5,
          height: 1.4,
        ),
      ),
      actions: [
        gameDialogButton(
          l.actionCancel,
          () => Navigator.pop(context),
          primary: false,
        ),
        gameDialogButton(l.exitAction, () async {
          Navigator.pop(context);
          await ref.read(saveControllerProvider.notifier).resetGame();
          if (!mounted) return;
          _devJumpStage(1); // 라이브 화면도 처음으로 동기화
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(l.settingsResetDone)));
        }, color: const Color(0xFFC85454)),
      ],
    );
  }

  /// 개발자(테스트) 도구 시트 — 채집함/스테이지/재화 조작. (개발 전용, 하드코딩 허용)
  void _showDevTools(AppLocalizations l) {
    final stageCtrl = TextEditingController();
    void toast(String m) => ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xF2141F0E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Consumer(
          builder: (ctx, r, _) {
            final ctrl = r.read(saveControllerProvider.notifier);
            return Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                14,
                16,
                16 + MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '🛠 개발자 모드',
                    style: TextStyle(
                      color: _onScene,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _devSection('채집함', [
                    _devBtn('채우기(종별 3)', () async {
                      await ctrl.devFillBugs();
                      toast('채집함 채움');
                    }),
                    _devBtn('초기화', () async {
                      await ctrl.devClearBugs();
                      toast('채집함 초기화');
                    }, danger: true),
                  ]),
                  _devSection('스테이지 (현재 $_stage)', [
                    _devBtn('초기화(1)', () {
                      _devJumpStage(1);
                      toast('스테이지 1');
                    }, danger: true),
                    SizedBox(
                      width: 90,
                      child: TextField(
                        controller: stageCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          isDense: true,
                          hintText: '스테이지',
                          hintStyle: TextStyle(color: Color(0x66FFFFFF)),
                        ),
                      ),
                    ),
                    _devBtn('이동', () {
                      final n = int.tryParse(stageCtrl.text.trim());
                      if (n != null && n >= 1) {
                        _devJumpStage(n);
                        toast('스테이지 $n 이동');
                      }
                    }),
                  ]),
                  _devSection('재화 추가', [
                    _devBtn('골드 +100K', () {
                      ctrl.devAddResources(gold: 100000);
                      toast('골드 +100K');
                    }),
                    _devBtn('재료 +500', () {
                      ctrl.devAddResources(chitin: 500, mineral: 500, sap: 500);
                      toast('재료 +500');
                    }),
                    _devBtn('젤리 +100', () {
                      ctrl.devAddResources(jelly: 100);
                      toast('젤리 +100');
                    }),
                    _devBtn('경험치 +10K', () {
                      ctrl.devAddResources(xp: 10000);
                      toast('경험치 +10K');
                    }),
                  ]),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _devSection(String title, List<Widget> children) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFFEBA52F),
            fontWeight: FontWeight.w800,
            fontSize: 12.5,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: children,
        ),
      ],
    ),
  );

  Widget _devBtn(String label, VoidCallback onTap, {bool danger = false}) =>
      FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: danger
              ? const Color(0xFF7A2E2E)
              : const Color(0xFF2E6DA4),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          minimumSize: const Size(0, 36),
          textStyle: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        child: Text(label),
      );

  /// (개발) 라이브 스테이지 즉시 이동 + 세이브 기록.
  /// 라이브 화면을 스테이지 [n]으로 이동(세이브 기록 없음).
  void _applyStageJump(int n) {
    setState(() {
      _stage = n;
      _habitatIndex = 0;
      _isBoss = false;
      _defeated = false;
      _dying = false;
      _walking = false;
      _spawn();
      _playerHp = _playerHpMax;
    });
  }

  void _devJumpStage(int n) {
    _applyStageJump(n);
    ref.read(saveControllerProvider.notifier).devSetStage(n);
  }

  /// 초상화 탭 → 현재 능력치 카드 + 닉네임 설정.
  /// 닉네임은 전투력 표기보다 길어지지 않도록 8자로 제한.
  void _showCharacterCard(AppLocalizations l, SaveGame save) {
    final controller = TextEditingController(text: save.nickname);
    final base = _petStats(save);
    final rows = <(String, String)>[
      (l.statCombatPower, formatCompact(combatPower(base))),
      (l.statAttack, base.attack.toStringAsFixed(0)),
      (l.statAttackSpeed, '${base.attackSpeed.toStringAsFixed(2)}/s'),
      (l.statCrit, '${(base.critChance * 100).toStringAsFixed(0)}%'),
      (l.statMaxHp, formatCompact(base.maxHp)),
      (l.statDefense, base.defense.toStringAsFixed(0)),
    ];
    showDialog<void>(
      context: context,
      barrierColor: const Color(0xAA000000),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 36),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xF21F2E13), Color(0xF20E1608)],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0x88EBA52F), width: 1.5),
            boxShadow: const [
              BoxShadow(color: Color(0x99000000), blurRadius: 18),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _portrait(save),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      maxLength: 8,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        counterText: '',
                        labelText: l.settingsNickname,
                        labelStyle: const TextStyle(color: Color(0xFFEBA52F)),
                        hintText: l.settingsNicknameHint,
                        enabledBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: Color(0x55EBA52F)),
                        ),
                        focusedBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFFEBA52F)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Divider(height: 1, color: Color(0x33EBA52F)),
              ),
              for (final r in rows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Text(
                        r.$1,
                        style: const TextStyle(
                          color: Color(0xB3FFFFFF),
                          fontSize: 13,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        r.$2,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xB3FFFFFF),
                    ),
                    child: Text(l.actionCancel),
                  ),
                  FilledButton(
                    onPressed: () {
                      ref
                          .read(saveControllerProvider.notifier)
                          .renamePlayer(controller.text);
                      Navigator.pop(ctx);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFEBA52F),
                      foregroundColor: const Color(0xFF3A2600),
                    ),
                    child: Text(l.actionSave),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBuffSheet(AppLocalizations l) {
    final buffs = _data.buffConfig;
    if (buffs == null) return;
    final minutes = (buffs.durationSeconds / 60).round();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xF2141F0E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Consumer(
          builder: (ctx, r, _) {
            final save = r.watch(saveControllerProvider).requireValue;
            final now = _clock.now().toUtc();
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.buffSheetTitle,
                    style: const TextStyle(
                      color: _onScene,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final k in BuffKind.values)
                    _buffSheetRow(l, r, k, save.buffRemaining(k, now), minutes),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buffSheetRow(
    AppLocalizations l,
    WidgetRef r,
    BuffKind k,
    Duration? remaining,
    int minutes,
  ) {
    final active = remaining != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          _buffIconCircle(k, 44),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        buffLabel(l, k),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _onScene,
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                    // 활성 시 남은 시간을 이름 옆에 표시(설명은 그대로 유지).
                    if (active) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: _honey.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _mmss(remaining),
                          style: const TextStyle(
                            color: _honey,
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  buffDesc(l, k),
                  style: const TextStyle(
                    color: Color(0xB3FFFFFF),
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: () async {
              final ctrl = r.read(saveControllerProvider.notifier);
              await ctrl.activateBuff(k);
              // 광고 보상(테스트): 프리미엄 재화 젤리 1개 지급.
              await ctrl.applyReward(
                gold: 0,
                xp: 0,
                materials: const {MaterialKind.jelly: 1},
              );
              if (!mounted) return;
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(
                    content: Text(
                      l.buffActivatedSnack(buffLabel(l, k), minutes),
                    ),
                  ),
                );
            },
            icon: const Icon(Icons.play_arrow_rounded, size: 18),
            label: Text(l.buffWatchAd),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
            ),
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
    required this.materials,
    required this.buyAmount,
    required this.onBuy,
  });

  final UpgradeKind kind;
  final RunConfig config;
  final int level;
  final int gold;
  final Map<MaterialKind, int> materials;
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

    // 재료 추가비용(있으면). 1레벨분 비용으로 구매 가능 여부 판정.
    final matKind = spec.materialKind;
    final singleMatCost = upgradeMaterialCost(spec, level);
    final batchMatCost = bulkUpgradeMaterialCost(spec, level, buyAmount);
    final haveMat = matKind == null ? 0 : (materials[matKind] ?? 0);
    final matOk = matKind == null || haveMat >= singleMatCost;
    final affordable = gold >= singleCost && matOk;

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
          InkWell(
            onTap: () => _showUpgradeInfo(context, l, kind, cur),
            borderRadius: BorderRadius.circular(10),
            child: Stack(
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
                      child: Icon(
                        _statIcon(kind),
                        color: Colors.white,
                        size: 21,
                      ),
                    ),
                  ),
                ),
                // 설명 힌트(ⓘ)
                const Positioned(
                  right: -1,
                  top: -1,
                  child: Icon(Icons.info, size: 13, color: Color(0xCCFFD977)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: () => _showUpgradeInfo(context, l, kind, cur),
              behavior: HitTestBehavior.opaque,
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
                  const SizedBox(height: 2),
                  // 골드 + 재료 비용을 한 줄로 → 재료 유무와 무관하게 행 높이 통일.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '💰${formatCompact(batchCost)}',
                          style: TextStyle(
                            color: affordable
                                ? const Color(0xFFFFE082)
                                : const Color(0x66FFFFFF),
                            fontWeight: FontWeight.w800,
                            fontSize: 12.5,
                          ),
                        ),
                        if (matKind != null && batchMatCost > 0) ...[
                          const SizedBox(width: 6),
                          materialImage(
                            matKind,
                            size: 12,
                            fallback: Icon(
                              materialIcon(matKind),
                              size: 11,
                              color: matOk
                                  ? const Color(0xFF9CCC65)
                                  : const Color(0xFFEF9A9A),
                            ),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            formatCompact(batchMatCost),
                            style: TextStyle(
                              color: matOk
                                  ? const Color(0xFFC5E1A5)
                                  : const Color(0xFFEF9A9A),
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
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

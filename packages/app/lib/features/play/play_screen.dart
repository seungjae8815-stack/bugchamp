import 'dart:async';
import 'dart:math' as math;

import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../ui/toast.dart';
import '../../app_version.dart';
import '../../data/game_data.dart';
import '../../domain/iap_service.dart';
import '../../domain/admob_ad_service.dart';
import '../../domain/audio_service.dart';
import '../../domain/chat_service.dart';
import '../../domain/notify_prefs.dart';
import '../../domain/auth_service.dart';
import '../../domain/cloud_save_service.dart';
import '../../domain/game_server.dart';
import '../../domain/providers.dart';
import '../../domain/pvp_backend.dart';
import '../../domain/save_controller.dart';
import '../../domain/server_sync.dart';
import 'package:core_save/core_save.dart';
import '../../l10n/app_localizations.dart';
import '../chat/chat_screen.dart';
import '../../ui/ad_gate.dart';
import '../../ui/art.dart';
import '../../ui/concept_card.dart';
import '../../ui/format.dart';
import '../../ui/game_dialog.dart';
import '../../ui/guest_warning.dart';
import '../../ui/nickname_gate.dart';
import '../../ui/labels.dart';
import '../../ui/skins.dart';
import '../leaderboard/leaderboard_screen.dart';
import '../character/item_gallery.dart';
import '../storage/skin_gallery.dart';
import '../event/event_screen.dart';
import '../roadmap/roadmap_screen.dart';
import '../notice/notice_screen.dart';
import '../../domain/review_service.dart';
import '../../domain/notice_service.dart';

const _uuid = Uuid();
const _honey = Color(0xFFEBA52F);
const _onScene = Color(0xFFFFFFFF);

/// 일반 강화 재료(처치/채집 드롭 대상). 젤리는 프리미엄이라 제외(§E).
/// 일반 재료 3종은 `game_rules.dart` 한 곳에 있다(앱·서버 공용).
const _regularMaterials = kRegularMaterials;
const _walkDuration = 0.6;
// 부스트 지속시간·속도계수는 밸런스라 run_config.json 에 있다(§6).
const _deathDuration = 0.4;
const _defeatDuration = 2.5;

BoxDecoration _glass([double r = 999]) => BoxDecoration(
  color: const Color(0x66121A10),
  borderRadius: BorderRadius.circular(r),
  border: Border.all(color: const Color(0x28FFFFFF)),
);

/// 공용 라벨(`ui/labels.dart`)로 위임 — 도감의 종 패시브와 **같은 이름**이어야
/// "이 패시브가 무슨 능력치인지"가 연결된다.
String _statLabel(AppLocalizations l, UpgradeKind k) => upgradeLabel(l, k);

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
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final GameData _data;
  late final RunConfig _config;
  late final Ticker _ticker;
  final _rng = math.Random();

  Duration _lastElapsed = Duration.zero;

  /// 설정의 빌드 상세(빌드일·기능) 펼침 여부.
  bool _showBuildDetail = false;

  int _stage = 1;

  /// 스크롤러가 로컬에서 도달한 **최고** 스테이지. 실패 후퇴(_stage↓)와 무관하게
  /// 유지된다 — 시작 시 서버 세이브 채택(다른 기기 진행)을 따라잡을지 판단하는
  /// 기준으로만 쓴다. 이게 없으면 후퇴할 때마다 최고기록으로 튕겨 올라간다.
  int _stageMax = 1;
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

  /// 탭 연타로 쌓이는 공격 배율(1.0 = 부스트 없음). 안 누르면 초당 감소한다.
  double _boostMult = 1.0;

  /// 이번 몬스터를 잡는 데 걸린 시간(초). 화석 조각을 시간에 비례해 주기 위함.
  double _killSeconds = 0;

  /// 화석 조각의 소수점 이월분 — 반올림으로 새거나 덜 주지 않게 누적한다.
  double _fossilPending = 0;

  /// 탭 순간의 화면 파동(1 → 0). 눌렀다는 시각 피드백.
  double _tapFlash = 0;

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
    // 백그라운드에 있던 시간도 방치 보상으로 쳐야 한다 — 복귀를 직접 듣는다.
    WidgetsBinding.instance.addObserver(this);
    _cracks = _makeCracks();
    _clock = ref.read(clockProvider);
    _data = ref.read(gameDataProvider).requireValue;
    _config = _data.runConfig!;
    final save = ref.read(saveControllerProvider).requireValue;
    _stage = save.stageNumber;
    _stageMax = save.stageNumber;
    final stats = _stats(save);
    _playerHpMax = stats.maxHp;
    _playerHp = stats.maxHp;
    _spawn(announce: false);
    _ticker = createTicker(_tick)..start();
    // 끊기면 **게임을 멈춘다.** 이 게임은 오프라인 플레이를 허용하지 않는다 —
    // 계속 돌게 두면 저장되지 않는 진행이 쌓이고, 앱을 껐다 켜는 순간 서버의
    // 낡은 세이브에 덮여 통째로 사라진다.
    serverDisconnected.addListener(_onConnectionChanged);

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
    WidgetsBinding.instance.removeObserver(this);
    serverDisconnected.removeListener(_onConnectionChanged);
    _ticker.dispose();
    // 챕터 보스전 도중에 화면을 떠나도 보스 배경음이 남지 않게 되돌린다.
    unawaited(AudioService.instance.restoreBgm());
    super.dispose();
  }

  /// 백그라운드 → 복귀. 그동안의 방치 보상을 정산하고 팝업으로 알린다.
  ///
  /// 예전엔 **앱 시작 때만** 정산해서, 앱을 내려놨다가 다시 열면 그 시간이
  /// 통째로 사라졌다. 방치형 게임에서 가장 손해가 큰 구간이다.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) return;
    unawaited(_settleOnResume());
  }

  void _onConnectionChanged() {
    if (!mounted) return;
    if (serverDisconnected.value) {
      _ticker.stop();
    } else if (!_ticker.isActive) {
      // `_tick` 이 dt 를 0.05초로 클램프하므로 재시작해도 튀지 않는다.
      _ticker.start();
    }
  }

  Future<void> _settleOnResume() async {
    final ctrl = ref.read(saveControllerProvider.notifier);
    // 패스 보유자는 쌓인 선물을 **자동으로** 받는다(2배). 선물은 접속 1시간에
    // 5.5개씩 나와서 탭 노동이 만만치 않다 — 그 노동을 없애는 게 패스의 값이다.
    unawaited(ctrl.autoClaimGifts());
    if (!await ctrl.settleOffline()) return;
    final report = ctrl.pendingOffline;
    if (report == null || !mounted) return;
    ctrl.consumeOffline();
    // 복귀 직후 진행 상태(스테이지·체력)도 세이브에 맞춰 다시 잡는다.
    final save = ref.read(saveControllerProvider).requireValue;
    final stats = _stats(save);
    setState(() {
      _playerHpMax = stats.maxHp;
      if (_playerHp > _playerHpMax) _playerHp = _playerHpMax;
    });
    _showOfflineReward(report);
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

  /// [announce] 는 보스 등장 스팅어 재생 여부. 앱 시작·개발도구처럼 **플레이 흐름이
  /// 아닌** 스폰에서는 꺼서, 켜자마자 보스음이 튀어나오지 않게 한다.
  void _spawn({bool announce = true}) {
    _isBoss = _habitatIndex >= _config.habitatsPerStage;
    if (_isBoss && announce) AudioService.instance.sfxBoss();
    // 챕터 최종보스에서만 전용 배경음. 스테이지 보스마다 바꾸면 1분에 한 번씩
    // 곡이 갈려서 오히려 산만하다. 매 스폰마다 호출되지만 같은 트랙이면 무시된다.
    final ch = _data.roadmapConfig?.chapterForStage(_stage);
    unawaited(
      _isBoss && ch != null && _stage == ch.endStage
          ? AudioService.instance.switchBgm('bgm_boss')
          : AudioService.instance.restoreBgm(),
    );
    final depth = _stage - 1;
    // 적응형 체력(§7) — 내 공격력을 넘겨야 "한 방에 죽는" 오버킬이 막힌다.
    // 방치 정산(simulateIdleProgress)도 같은 보정을 쓰므로 화면과 어긋나지 않는다.
    //
    // ⚠️ 기준은 **영구 전력(업그레이드+펫)** 이다. `_stats` 는 버프가 실린
    // 값이라 그걸 쓰면 광폭화를 켤 때마다 몬스터 체력도 같이 올라
    // **버프 효과가 상쇄된다**(버프가 끝나면 반대로 쉬워진다).
    // 탭 부스트도 같은 이유로 여기 들어오면 안 된다 — 데미지 계산에만 실린다.
    //
    // 기준값은 생 `attack` 이 아니라 `baselineHitPower` — 치명타까지 센 1타
    // 데미지다. 치명타를 빼고 잡으면 설정이 "6대"여도 화면은 2~3대가 된다.
    final perm = _petStats(ref.read(saveControllerProvider).requireValue);
    _hpMax =
        (_isBoss
                ? bossMaxHp(
                    _config,
                    depth,
                    playerAttack: baselineHitPower(perm, boss: true),
                  )
                : habitatMaxHp(
                    _config,
                    depth,
                    playerAttack: baselineHitPower(perm),
                  ))
            .toDouble();
    _hp = _hpMax;
    _kind = habitatKindAt(_config, _stage, _isBoss ? 0 : _habitatIndex);
    _walking = false;
    _walkT = 0;
    _attackAcc = 0;
    // ⚠️ `_enemyAtkAcc` 는 **일부러 리셋하지 않는다.** 리셋하면 몬스터가 공격
    // 주기(1.5초)를 채우기 전에 죽는 구간에서 **평생 한 대도 못 때린다** —
    // 위협도를 아무리 올려도 체력이 안 닳던 진짜 원인이었다. 이월시키면
    // 처치가 빨라도 "몇 마리에 한 번"으로 결국 같은 DPS 가 들어온다.
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
      pets.add(petStatOf(bug, sp, cfg, now));
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

  /// 장착 펫들의 **종 고유 패시브** 합산(§2.1).
  ///
  /// `_petStats` 안이 아니라 밖에서 쓰는 이유는 `_stats` 주석 참조.
  Map<UpgradeKind, double> _speciesPassives(SaveGame save) {
    final cfg = _data.petConfig;
    if (cfg == null || save.equippedBugIds.isEmpty) return const {};
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
      pets.add(petStatOf(bug, sp, cfg, now));
    }
    return computePetBonus(pets, cfg).passives;
  }

  /// 펫 + **종 패시브 + 도감 + 장비** + 활성 버프까지 반영한 유효 능력치
  /// — 전투/보상 계산에 사용.
  ///
  /// ⚠️ 이 값은 **적응형 몬스터 체력의 기준으로 쓰지 않는다**(기준은 `_petStats`).
  /// 장비를 기준에 넣으면 좋은 걸 껴도 몬스터가 같이 세져 **모으는 맛이
  /// 사라진다** — 전설 장비를 껴도 체감이 1.7배밖에 안 됐다(실측).
  /// 장비는 순수 이득이어야 관문을 뚫는 수단이 된다.
  ///
  /// **종 패시브·도감도 같은 이유로 여기(기준 밖)에 있다**:
  ///  - 종 패시브를 기준에 넣으면 어떤 종을 껴도 결과가 같아져서, 종을 고르는
  ///    의미가 통째로 사라진다(= 종 패시브를 만든 이유가 무너진다).
  ///  - 도감을 기준에 넣으면 채울수록 몬스터도 세져서 모을 이유가 없어진다.
  CharacterStats _stats(SaveGame save) {
    var s = applyEquipment(
      _petStats(save),
      equipmentBonus(save.equippedItems.values, _data.itemConfig),
    );
    s = applySpeciesPassives(s, _speciesPassives(save));
    final dex = _data.dexConfig;
    if (dex != null) {
      s = dex.apply(s, save.dexDiscovered, save.dexConquered);
    }
    return applyBuffs(
      s,
      save.activeBuffs(_clock.now().toUtc()),
      _data.buffConfig,
    );
  }

  void _tick(Duration elapsed) {
    final raw = (elapsed - _lastElapsed).inMicroseconds / 1000000.0;
    _lastElapsed = elapsed;
    final dt = raw.clamp(0.0, 0.05);
    if (dt <= 0) return;
    _killSeconds += dt;
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
    if (_tapFlash > 0) _tapFlash = math.max(0, _tapFlash - dt * 3.2);
    // 탭을 멈추면 배율이 서서히 1.0 으로 돌아간다 — 계속 두드리게 만드는 축.
    if (_boostMult > 1.0) {
      _boostMult = math.max(1.0, _boostMult - _config.boostDecayPerSec * dt);
    }
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
      // 부스트는 이동에도 실린다 — 때리는 속도만 빨라지고 다음 몬스터를 만나는
      // 데 그대로 걸리면, 연타해도 진행이 안 빨라져 손맛이 죽는다.
      final boostMove = 1 + (_boostMult - 1) * _config.boostSpeedFactor;
      _walkT += dt * boostMove;
      _bgOffset += dt * 130 * boostMove;
      _playerHp = math.min(_playerHpMax, _playerHp + stats.hpRegen * 2 * dt);
      if (_walkT >= _walkDuration / stats.moveSpeed) _spawn();
      return;
    }

    // 적 반격 — 보스·일반 서식지 모두 주기적으로 달려들어(공격 모션) 그 순간 피해.
    final depth = _stage - 1;
    // ⚠️ 기준은 **영구 전력(업그레이드+펫)** 이다. 장비·버프를 넣으면 좋은 옷을
    // 입을수록 몬스터가 세져 **입은 보람이 사라진다** — 체력에서 겪은 그대로다.
    // 회복은 이 식에 없으므로 올린 만큼 그대로 버틴다.
    final threat = habitatThreat(
      _config,
      depth,
      boss: _isBoss,
      playerToughness: toughnessOf(
        _petStats(ref.read(saveControllerProvider).requireValue),
      ),
    );
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
        AudioService.instance.sfxHurt(); // 플레이어 피격음

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
    // ⚠️ 부스트는 **플레이어 공격에만** 실린다(몬스터 공격은 아래에서 따로).
    final dmgMul = _boostMult;
    final speedMul = 1 + (_boostMult - 1) * _config.boostSpeedFactor;
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
        // 타격음 — 연출 쿨다운과 같은 주기라 연타에도 시끄럽지 않다.
        AudioService.instance.sfxHit();
      }
      guard++;
    }
    if (_hp <= 0) _beginDeath(stats);
  }

  void _beginDeath(CharacterStats stats) {
    AudioService.instance.sfxDie(); // 몬스터 처치음
    final depth = _stage - 1;
    // 접속 보너스 — **직접 잡았을 때만** 붙는다(방치 정산에는 안 붙는다).
    // 켜두는 쪽이 이득이어야 자주 들어오고, 그래야 업그레이드·채팅도 돈다.
    final gold =
        (rewardGold(_config, depth, stats.rewardMultiplier, boss: _isBoss) *
                (1 + _config.onlineGoldBonus))
            .round();
    final xp = (rewardXp(_config, depth, boss: _isBoss) * stats.xpMultiplier)
        .round();

    final save = ref.read(saveControllerProvider).requireValue;
    IndividualBug? bug;
    // 등급 필터에 걸린 곤충은 **칸을 쓰지 않는다**(자동 방생) — 그래서 종을
    // 뽑기 전에는 가득 찼는지로 롤을 막을 수 없다. 종을 먼저 정하고,
    // 필터 → 칸 순으로 판정한다.
    Grade? released;
    String? releasedSpeciesId;
    final bugChance = _isBoss ? 1.0 : _config.bugDropChance * stats.bugFind;
    if (_rng.nextDouble() < bugChance) {
      final sp = _data.allSpecies[_rng.nextInt(_data.allSpecies.length)];
      if (!save.acceptsGrade(sp.grade)) {
        released = sp.grade; // 재료로 환산(아래 mats 에서 합산)
        releasedSpeciesId = sp.id; // 스킨 계열 보너스 판정용
      } else if (!save.storageFull) {
        // 채집함이 가득 차면 개체 롤 자체를 건너뛴다 — 굴려서 버리면
        // 연출만 뜨고 실제로는 안 들어와 버그로 보인다.
        final potential =
            1 + (_rng.nextDouble() * _rng.nextDouble() * 4).floor();
        bug = IndividualBug.roll(
          id: _uuid.v4(),
          species: sp,
          rng: _rng,
          potential: potential.clamp(1, 5),
        ).copyWith(stage: LifeStage.egg, stageSince: _clock.now().toUtc());
        // 희귀 이상은 전용 팡파레 — "이번 건 다르다"가 즉시 귀로 구분돼야 한다.
        if (sp.grade.index >= Grade.rare.index) {
          AudioService.instance.sfxRare();
        } else {
          AudioService.instance.sfxCatch();
        }
      }
    }

    // 화석 조각(제련용) — **잡는 데 걸린 시간에 비례**해 쌓는다.
    // 스테이지를 보지 않으므로 낮은 난이도로 내려가도 시간당 획득이 같고,
    // 관문에서 느려질 때도 시간당은 그대로다(막혔는데 장비도 못 만드는 일 방지).
    Map<MaterialKind, int>? mats;
    final forgeCfg = _data.forgeConfig;
    if (forgeCfg != null) {
      _fossilPending += _killSeconds * forgeCfg.fossilPerSecond;
      if (_fossilPending >= 1) {
        final give = _fossilPending.floor();
        _fossilPending -= give;
        mats = {MaterialKind.fossil: give};
      }
    }
    _killSeconds = 0;
    if (_rng.nextDouble() < _config.materialDropChance * stats.materialFind) {
      final kind = _regularMaterials[_rng.nextInt(_regularMaterials.length)];
      mats ??= {};
      // 수량도 깊이에 따라 자란다 — 골드만 지수로 커지면 재료는 중반에
      // 쌓이기만 하고(골드 병목) 후반엔 반대로 재료가 병목이 된다.
      final amount = (1 + _rng.nextInt(2)) * materialAmountMult(_config, depth);
      mats[kind] = math.max(1, amount.round());
    }
    // 등급 필터에 걸린 곤충 → 재료 환산(§2.1). 젤리가 아니라 일반 재료다 —
    // 자동으로 굴러가는 통로에 프리미엄 재화를 흘리면 IAP 가 무의미해진다.
    final petCfg = _data.petConfig;
    if (released != null && petCfg != null) {
      // 스킨 계열 편의 보너스(§2.6 — 재료만).
      final give =
          _data.iapConfig?.skinnedReleaseMaterial(
            petCfg.releaseMaterial(released),
            save.ownedSkins,
            releasedSpeciesId ?? '',
          ) ??
          petCfg.releaseMaterial(released);
      if (give > 0) {
        final kind = _regularMaterials[_rng.nextInt(_regularMaterials.length)];
        mats ??= {};
        mats[kind] = (mats[kind] ?? 0) + give;
      }
    }

    ref
        .read(saveControllerProvider.notifier)
        .applyReward(
          gold: gold,
          xp: xp,
          bug: bug,
          materials: mats,
          mission: _isBoss ? MissionType.killBosses : MissionType.killMonsters,
          idle: true, // 표시용 힌트(현재 로직에서 분기 없음)
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
    // 처치 회복은 데이터에서 온다(§6). 서식지 20마리 × 30% 였던 시절엔
    // 스테이지마다 최대체력의 600% 를 회복해 **피가 절대 안 닳았다**.
    _playerHp = math.min(
      _playerHpMax,
      _playerHp +
          _playerHpMax *
              (_isBoss ? _config.bossKillHealPct : _config.killHealPct),
    );
    if (_isBoss) {
      _stage++;
      _stageMax = math.max(_stageMax, _stage);
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
    // 이월되는 공격 게이지(§_spawn)를 여기서만 비운다 — 부활하자마자 맞고
    // 시작하면 후퇴 패널티가 두 번 붙는다.
    _enemyAtkAcc = 0;
    _spawn();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final save = ref.watch(saveControllerProvider).requireValue;
    // 다른 기기에서 더 진행한 세이브를 채택했을 때만 따라잡는다.
    // **로컬 최고치(_stageMax) 기준** — 실패 후퇴(_stage↓)는 방해하지 않는다.
    if (save.stageNumber > _stageMax) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && save.stageNumber > _stageMax) {
          _applyStageJump(save.stageNumber);
        }
      });
    }
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
      onTap: () {
        // 손맛: 짧은 진동 + 화면 파동. 눌린 게 몸으로 느껴져야 계속 두드린다.
        HapticFeedback.lightImpact();
        setState(() {
          // 한 번에 오르는 폭은 부스트 업그레이드(boostBonus)에 비례한다.
          final stats = _stats(ref.read(saveControllerProvider).requireValue);
          _boostMult = math.min(
            _config.boostMultMax,
            _boostMult + _config.boostStepPerTap * stats.boostBonus,
          );
          _tapFlash = 1.0;
        });
      },
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
                          // 숫자는 **보스에만** 남긴다.
                          //
                          // 적응형 체력(§7)이 들어가 같은 스테이지라도 사람마다
                          // 체력이 다르다 — 숫자를 보여주면 "쟤 몬스터는 왜 약해"가
                          // 되고 설명할 방법이 없다. 게다가 방치형에서 절대값은
                          // 정보 가치가 거의 없다(남은 비율만 알면 된다).
                          // 보스는 "얼마나 남았나"가 실제로 궁금한 유일한 지점이라
                          // 남긴다.
                          label: _isBoss
                              ? '${formatCompact(_hp.clamp(0, _hpMax))} / ${formatCompact(_hpMax)}'
                              : null,
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
                        // 내 체력도 숫자를 뺀다 — 위험한지 아닌지는 게이지가
                        // 더 빨리 읽힌다(전투 중에 자릿수를 읽지 않는다).
                        label: null,
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

              // 탭 파동 — 눌린 순간 화면 전체가 살짝 밝아졌다 사라진다.
              if (_tapFlash > 0)
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          colors: [
                            _honey.withValues(alpha: 0.18 * _tapFlash),
                            const Color(0x00000000),
                          ],
                          radius: 0.9 - 0.25 * _tapFlash,
                        ),
                      ),
                    ),
                  ),
                ),
              if (_boostMult > 1.0)
                Positioned(
                  top: 8,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: _glass(),
                    child: Text(
                      '⚡ x${_boostMult.toStringAsFixed(1)}',
                      style: const TextStyle(
                        color: _honey,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              // 부스트 유도: 주기적으로 나타났다 사라지는 손가락 탭 아이콘
              if (_boostMult <= 1.0) _buildTapHint(),
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
          // 채집함 만석 알림 — 구매 버튼 바로 위(씬을 가리지 않는 자리).
          _storageFullBar(l, save),
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
      children: [
        _topBar(l, save),
        _eventBanner(l),
        _loginNudge(l),
        _chatBar(l),
      ],
    ),
  );

  /// 개막 전 예고 배너 — 눌러서 전단지를 볼 수 있다.
  ///
  /// 서버가 닫혀 있는 동안에도 떠야 하므로 **로컬 설정만** 본다.
  Widget _eventSoonBanner(AppLocalizations l, Duration left) {
    final when = left.inDays >= 1
        ? l.eventOpensInDays(left.inDays + 1)
        : (left.inHours >= 1
              ? l.eventOpensInHours(left.inHours)
              : l.eventOpensInMinutes(left.inMinutes + 1));
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 7),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const EventScreen())),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0x22EBA52F),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0x55EBA52F)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.hourglass_top_rounded,
                size: 15,
                color: Color(0xFFEBA52F),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  l.eventSoonBanner(when),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFEBA52F),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: Color(0x99EBA52F),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 이벤트(왕충 선발대회) 배너.
  ///
  /// 한시적 이벤트라 하단 탭을 늘리지 않고 홈 상단에 둔다. 탭은 이미 5개이고,
  /// 회차가 끝나면 배너만 사라지면 된다.
  ///
  /// **개막 전에도 띄운다.** 서버는 기간 밖이면 `event_closed` 로 아무것도 안 주는데,
  /// 그 상태를 "없음"으로 처리하니 시작 전날까지 대회의 존재 자체가 화면에 없었다.
  /// 시작 전 예고는 **로컬 설정(`event.json`)만 보고** 그린다.
  Widget _eventBanner(AppLocalizations l) {
    final st = ref.watch(eventStateProvider).asData?.value;
    final cfg = ref.watch(gameDataProvider).asData?.value.eventConfig;
    final now = ref.read(clockProvider).now().toUtc();
    if (st == null) {
      final left = cfg?.untilOpen(now);
      if (left == null) return const SizedBox.shrink();
      return _eventSoonBanner(l, left);
    }
    final tickets = (st['tickets'] as num?)?.toInt() ?? 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 7),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () async {
          await Navigator.of(
            context,
          ).push(MaterialPageRoute<void>(builder: (_) => const EventScreen()));
          // 돌아오면 참가권·기록이 바뀌었을 수 있다.
          ref.invalidate(eventStateProvider);
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0x267E57C2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xAA7E57C2)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.emoji_events_rounded,
                color: Color(0xFFD7BCFF),
                size: 14,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  l.eventBanner(tickets),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFD7BCFF),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFFD7BCFF),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 게스트(익명) 상태에서만 뜨는 로그인 유도 배너 — 눌러서 계정 시트를 연다.
  /// 로그인하지 않은 유저는 기기 변경·앱 삭제 시 진행도를 복구할 수 없으므로,
  /// 계정 창을 열지 않아도 홈에서 바로 보이도록 상단에 상시 노출한다.
  /// `_signIn` 성공 시 setState 로 리빌드되어 자동으로 사라진다.
  Widget _loginNudge(AppLocalizations l) {
    final auth = ref.read(authServiceProvider);
    if (!auth.available || auth.isSignedIn) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 7),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _showAccount(l),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _honey.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _honey.withValues(alpha: 0.55)),
          ),
          child: Row(
            children: [
              const Icon(Icons.shield_rounded, color: _honey, size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  l.loginNudge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _honey,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: _honey, size: 16),
            ],
          ),
        ),
      ),
    );
  }

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
                    // (2026-08) 랭킹은 여기서 빼고 **앱 시작 팝업**으로 옮겼다
                    // — 상시 표기는 갱신 시점이 모호해 실제 순위와 어긋나 보였다.
                    // see ui/rank_popup.dart
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
                  // 공지 — 안 읽은 글이 있으면 빨간 점.
                  _iconBtn(
                    Icons.campaign_rounded,
                    () {
                      // 열 때마다 최신 공지를 다시 받는다(플레이 중 올라온 글 반영).
                      ref.invalidate(noticesProvider);
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const NoticeScreen(),
                        ),
                      );
                    },
                    badge: ref.watch(hasUnreadNoticeProvider),
                  ),
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
                    // 운영 우편(점검 보상 등)도 편지함 알림에 포함한다.
                    badge:
                        _hasClaimableDaily(save) ||
                        (ref.watch(serverMailProvider).value?.isNotEmpty ??
                            false),
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
    // 비활성 버프는 부드럽게 맥동하는 글로우 + "!" 로 활성화를 유도한다.
    final pulse = 0.5 + 0.5 * math.sin(_tapHint * 3.2);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              if (!active)
                // 맥동 글로우(활성화 유도)
                Container(
                  width: 20 + pulse * 6,
                  height: 20 + pulse * 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _honey.withValues(alpha: 0.35 + pulse * 0.4),
                        blurRadius: 6 + pulse * 6,
                        spreadRadius: 0.5 + pulse * 1.5,
                      ),
                    ],
                  ),
                ),
              Opacity(
                opacity: active ? 1.0 : 0.55 + pulse * 0.3,
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: _buffIconCircle(k, 20),
                ),
              ),
              if (!active)
                // 우상단 "!" 배지
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    width: 10,
                    height: 10,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: _honey,
                      shape: BoxShape.circle,
                    ),
                    child: const Text(
                      '!',
                      style: TextStyle(
                        color: Color(0xFF3A2600),
                        fontSize: 7.5,
                        fontWeight: FontWeight.w900,
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
            ],
          ),
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

  /// 홈 상단 채팅 바. 탭하면 전체 채팅 화면으로 들어간다.
  Widget _chatBar(AppLocalizations l) => Padding(
    padding: const EdgeInsets.fromLTRB(10, 0, 10, 7),
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const ChatScreen())),
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
            // 마지막 채팅을 보여준다 — "탭하면 열려요"만 있으면 들어갈 이유가
            // 없다. 대화가 오가는 게 보여야 눌러본다.
            Expanded(
              child: Consumer(
                builder: (context, r, _) {
                  final last = r.watch(chatLatestProvider).value;
                  if (last == null) {
                    return Text(
                      l.chatPlaceholder,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0x99FFFFFF),
                        fontSize: 11.5,
                      ),
                    );
                  }
                  return Text.rich(
                    TextSpan(
                      children: [
                        // 운영자 메시지는 홈 채팅바에서도 구분된다 — 여기가
                        // 대부분의 유저가 채팅을 접하는 유일한 자리다.
                        TextSpan(
                          text: '${last.nickname} ',
                          style: TextStyle(
                            color: last.isAdmin
                                ? const Color(0xFF9FD3F5)
                                : const Color(0xFFEBA52F),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        TextSpan(
                          text: last.body,
                          style: const TextStyle(color: Color(0xE6FFFFFF)),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11.5),
                  );
                },
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

  /// "채집함이 가득 찼어요" 알림 바 — 곤충 드롭이 멈춘 이유 안내.
  ///
  /// 강화 패널의 [1/10/100] 버튼 **바로 위**에 얇게 깐다. 씬 위에 띄우면
  /// 캐릭터·연출과 겹쳐 가리기 때문이다. 가득 찼을 때만 아래에서 슬라이드로
  /// 올라오고, 자리가 생기면 높이 0 으로 접혀 레이아웃을 밀지 않는다.
  Widget _storageFullBar(AppLocalizations l, SaveGame save) => AnimatedSize(
    duration: const Duration(milliseconds: 240),
    curve: Curves.easeOutCubic,
    alignment: Alignment.bottomCenter,
    child: !save.storageFull
        ? const SizedBox(width: double.infinity)
        : ClipRect(
            child: TweenAnimationBuilder<double>(
              key: const ValueKey('storage-full-bar'),
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              builder: (context, t, child) => Opacity(
                opacity: t,
                // 아래에서 위로 밀려 올라오는 슬라이드.
                child: Transform.translate(
                  offset: Offset(0, (1 - t) * 14),
                  child: child,
                ),
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                color: const Color(0xCC4A1A0A),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.inventory_2_outlined,
                      size: 12,
                      color: Color(0xFFFF8A65),
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        l.storageFullBanner,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFFFCCBC),
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
  );

  /// 상단 중앙 스테이지 배너(사냥 화면 위 오버레이).
  Widget _stageOverlay(AppLocalizations l) {
    final region = _config.regionForStage(_stage);
    final name = region.name.resolve(
      Localizations.localeOf(context).languageCode,
    );
    // "1-37" = 월드-스테이지. 월드 미설정(worldSize=0)이면 지역 기준(구버전).
    final chapter = _config.worldSize > 0
        ? _config.worldOf(_stage)
        : (_stage - 1) ~/ _config.stagesPerRegion + 1;
    final stageInRegion = _config.worldSize > 0
        ? _config.stageInWorld(_stage)
        : (_stage - 1) % _config.stagesPerRegion + 1;
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
      AudioService.instance.sfxLevelUp(); // 챕터 돌파 — 스테이지 클리어보다 큰 마디
      await _showChapterClearDialog(ch);
      if (!mounted) return;
    }
    // 챕터를 깬 직후 = 기분 좋은 순간. 리뷰는 **여기서 계정당 한 번만** 묻는다
    // (보상 없음 — 평점에 보상을 걸 수 없다. review_service.dart 주석 참조).
    if (cleared.isNotEmpty) await requestStoreReview(ref);
    if (!mounted) return;
    // 게스트면 진척 지점에서 데이터 유실을 상기시킨다(하루 1회 상한은 내부에서).
    await maybeWarnGuest(context, ref, stage);
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
          runConfig: _config,
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: claimable ? () => _claimMission(l, def.id) : null,
        child: _PulseBox(
          // ⚠️ 깜빡임은 **스스로** 돌아야 한다. 예전엔 부모(_tapHint)의 값을 읽어
          //    계산했는데, 미션 목록은 바텀시트라 부모가 갱신돼도 다시 그려지지
          //    않아 한 프레임 값에 멈춰 있었다(=깜빡이지 않았다).
          active: claimable,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
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
    if (!ok) return;
    AudioService.instance.sfxMission();
    if (mounted) {
      showCenterToast(context, l.missionClaimedSnack);
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
                  skin: ref.watch(skinOfProvider)(bug.speciesId),
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

  /// 편지함 = 일일보상(점심/저녁) + 깜짝선물. 현재 로컬 시각·수령 이력으로 상태 표시.
  void _showMail(AppLocalizations l) {
    // 편지함을 열 때 운영 우편을 다시 받는다 — 플레이 중 발송된 보상이
    // 앱을 껐다 켜야 보이면 "안 왔다"는 문의가 된다.
    ref.invalidate(serverMailProvider);
    showModalBottomSheet<void>(
      context: context,
      // 일일보상 + 선물이 쌓이면 기본 시트 높이를 넘는다 — 스크롤 없이는
      // 맨 아래(깜짝선물 섹션)가 하단 바 뒤로 잘려 안 보였다.
      isScrollControlled: true,
      backgroundColor: const Color(0xF2141F0E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.72,
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: Consumer(
          builder: (ctx, r, _) {
            final save = r.watch(saveControllerProvider).requireValue;
            final daily = _data.dailyConfig;
            final now = _clock.now();
            final today = dailyDateKey(now);
            return SingleChildScrollView(
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
                  ..._serverMailSection(ctx, r, l),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// 운영 우편(점검 보상·이벤트 지급). 서버가 보낸 것만 뜨고, 없으면 통째로 숨긴다.
  ///
  /// 수령은 **서버가 확정**한다 — 앱이 재화를 직접 더하면 다음 업로드에서
  /// 골드 급증 상한에 걸려 정당한 보상이 잘린다.
  List<Widget> _serverMailSection(
    BuildContext ctx,
    WidgetRef r,
    AppLocalizations l,
  ) {
    final mails = r.watch(serverMailProvider).value ?? const <ServerMail>[];
    if (mails.isEmpty) return const [];
    return [
      const SizedBox(height: 14),
      Text(
        l.mailNoticeSection,
        style: const TextStyle(
          color: Color(0xFFEBA52F),
          fontWeight: FontWeight.w700,
          fontSize: 11.5,
        ),
      ),
      const SizedBox(height: 10),
      for (final m in mails) _serverMailRow(ctx, r, l, m),
    ];
  }

  Widget _serverMailRow(
    BuildContext ctx,
    WidgetRef r,
    AppLocalizations l,
    ServerMail m,
  ) {
    final parts = <String>[
      if (m.gold > 0) '💰${formatCompact(m.gold)}',
      if (m.jelly > 0) '${l.curJelly} ${m.jelly}',
      if (m.chitin + m.mineral + m.sap > 0)
        '🧪${formatCompact(m.chitin + m.mineral + m.sap)}',
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0x2255AACC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xAA5FA8D3)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.campaign_rounded,
              color: Color(0xFFBFE3F5),
              size: 24,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    m.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _onScene,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  if (m.body.isNotEmpty)
                    Text(
                      m.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xB3FFFFFF),
                        fontSize: 11,
                      ),
                    ),
                  if (parts.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        parts.join('  '),
                        style: const TextStyle(
                          color: Color(0xFFFFE9A8),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () async {
                final res = await r.read(rewardClaimerProvider).claimMail(m.id);
                if (!ctx.mounted) return;
                if (res == RedeemResult.ok) {
                  AudioService.instance.sfxReward();
                  await showRewardPopup(
                    ctx,
                    title: m.title,
                    subtitle: l.rewardGained,
                    icon: Icons.campaign_rounded,
                    gold: m.gold,
                    materials: m.materials,
                  );
                } else {
                  showCenterToast(ctx, _redeemMessage(l, res));
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF3E7D4F),
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              child: Text(l.mailClaim),
            ),
          ],
        ),
      ),
    );
  }

  /// 수령·코드 실패 사유 → 안내 문구. 실패를 뭉뚱그리지 않는다.
  String _redeemMessage(AppLocalizations l, RedeemResult r) => switch (r) {
    RedeemResult.ok => l.giftCodeOk,
    RedeemResult.badCode => l.giftCodeBad,
    RedeemResult.expired => l.giftCodeExpired,
    RedeemResult.exhausted => l.giftCodeExhausted,
    RedeemResult.alreadyUsed => l.giftCodeUsed,
    RedeemResult.failed => l.giftCodeFailed,
  };

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
      if (g.jelly > 0) '${l.curJelly} ${g.jelly}',
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
      // 무료 2배를 다 썼으면 **패스를 안내한다**(2배 제안 대신).
      // 이미 뜬 보상은 1배로 받았으므로 손해는 없다 — 여기서 막는 건 덤뿐이다.
      if (!notifier.canDoubleGift()) {
        final capAction = await showGameDialog<_CapAction>(
          ctx,
          title: l.giftDoubleCapTitle,
          icon: Icons.workspace_premium_rounded,
          content: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0x33EBA52F),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              l.giftDoubleCapBody,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFFFD54F),
                fontSize: 14.5,
                fontWeight: FontWeight.w900,
                height: 1.4,
              ),
            ),
          ),
          // [패스 구입하기] = 결제창 바로 / [닫기] = 상점 탭으로
          // (2026-08-20 사장님 재확인 — 어느 쪽을 눌러도 패스 앞에 서게 한다.
          //  그냥 빠져나가는 길은 바깥 탭·뒤로가기로 남아 있다.)
          actions: [
            gameDialogButton(
              l.actionClose,
              () => Navigator.pop(ctx, _CapAction.shop),
              primary: false,
            ),
            gameDialogButton(
              l.giftBuyPassBtn,
              () => Navigator.pop(ctx, _CapAction.buy),
            ),
          ],
        );
        if (!ctx.mounted || capAction == null) return;
        // ⚠️ 편지함 시트도 같이 닫는다 — 탭만 바꾸면 상점 **위에** 시트가
        // 그대로 떠 있어 이동한 게 안 보인다(실기 지적 2026-08-20).
        Navigator.of(ctx).pop();
        r.read(tabIndexProvider.notifier).set(4);
        if (capAction == _CapAction.buy) {
          // 곤충학자 패스 결제창을 바로 연다(간판 패스 — 자동수령+2배가 이 값어치다).
          final data = r.read(gameDataProvider).value;
          final pass = data?.iapConfig?.products
              .where((p) => p.id == 'idle_pass')
              .firstOrNull;
          if (pass != null) {
            final outcome = await r.read(iapServiceProvider).buy(pass);
            if (!mounted) return;
            if (outcome == PurchaseOutcome.success) {
              showCenterToast(
                context,
                l.storeBought(
                  pass.name?.resolve(
                        Localizations.localeOf(context).languageCode,
                      ) ??
                      pass.id,
                ),
              );
            }
          }
        }
        return;
      }
      final more = await showGameDialog<bool>(
        ctx,
        title: l.giftAdMoreTitle,
        icon: Icons.play_circle_fill_rounded,
        // 이 다이얼로그가 곧 패스 광고판이다 — "1회뿐"과 "패스면 무제한"을
        // 받는 순간에 같이 보여준다(2026-08-20 문구·강조 사장님 지시).
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l.giftAdMoreBody,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xD9FFFFFF),
                fontSize: 13.5,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              l.giftAdMoreFreeLine,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14.5,
                fontWeight: FontWeight.w900,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0x33EBA52F),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                l.giftAdMorePassLine,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFFFD54F),
                  fontSize: 14.5,
                  fontWeight: FontWeight.w900,
                  height: 1.35,
                ),
              ),
            ),
          ],
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
        if (!await watchAdForReward(ctx, r, l)) return;
        if (!ctx.mounted) return;
        if (!await notifier.grantGiftBonus(g)) return;
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
      if (rw.jelly > 0) '${l.curJelly} ${rw.jelly}',
      if (rw.chitin + rw.mineral + rw.sap > 0)
        '🧪${formatCompact(rw.chitin + rw.mineral + rw.sap)}',
    ];
    // 그냥 받기(1배) → 수령 후 "광고 보고 한 번 더 받기" 제안 → 수락 시 +1배.
    Future<void> claimDailyThenOffer() async {
      final notifier = r.read(saveControllerProvider.notifier);
      final ok = await notifier.claimDaily(rw);
      if (!ok || !ctx.mounted) return;
      await showRewardPopup(
        ctx,
        title: l.dailyRewardSnack,
        subtitle: l.rewardGained,
        icon: rw.id == 'lunch'
            ? Icons.wb_sunny_rounded
            : Icons.nightlight_round,
        gold: rw.gold,
        materials: rw.materials,
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
        if (!await watchAdForReward(ctx, r, l)) return;
        if (!ctx.mounted) return;
        await notifier.grantDailyBonus(rw);
        if (!ctx.mounted) return;
        await showRewardPopup(
          ctx,
          title: l.giftDoubledSnack,
          subtitle: l.rewardGained,
          icon: Icons.play_circle_fill_rounded,
          gold: rw.gold,
          materials: rw.materials,
        );
      }
    }

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
                onPressed: claimDailyThenOffer,
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

  /// 설정창 사운드 섹션 — 배경음/효과음 on-off + 볼륨(설정은 로컬 저장).
  Widget _audioSettings(AppLocalizations l) =>
      ValueListenableBuilder<AudioSettings>(
        valueListenable: AudioService.instance.settings,
        builder: (context, s, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                l.settingsSound,
                style: const TextStyle(
                  color: Color(0xFFEBA52F),
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
            _audioRow(
              Icons.music_note_rounded,
              l.settingsBgm,
              s.bgmOn,
              (v) => AudioService.instance.setBgmOn(v),
              s.bgmVol,
              (v) => AudioService.instance.setBgmVol(v),
            ),
            _audioRow(
              Icons.graphic_eq_rounded,
              l.settingsSfx,
              s.sfxOn,
              (v) => AudioService.instance.setSfxOn(v),
              s.sfxVol,
              (v) => AudioService.instance.setSfxVol(v),
            ),
          ],
        ),
      );

  Widget _audioRow(
    IconData icon,
    String label,
    bool on,
    ValueChanged<bool> onToggle,
    double vol,
    ValueChanged<double> onVol,
  ) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Row(
        children: [
          Icon(icon, color: const Color(0xFFEBA52F), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
              ),
            ),
          ),
          Switch(value: on, onChanged: onToggle),
        ],
      ),
      Slider(
        value: vol.clamp(0.0, 1.0),
        activeColor: const Color(0xFFEBA52F),
        onChanged: on ? onVol : null,
      ),
    ],
  );

  /// 선물코드 입력. 지급은 서버가 확정하고 앱은 결과 세이브를 채택한다.
  void _showGiftCode(AppLocalizations l) {
    final ctrl = TextEditingController();
    var busy = false;
    showGameDialog<void>(
      context,
      title: l.giftCodeTitle,
      icon: Icons.confirmation_number_rounded,
      content: StatefulBuilder(
        builder: (ctx, setLocal) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l.giftCodeHint,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xB3FFFFFF),
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              maxLength: 32,
              enabled: !busy,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
              decoration: InputDecoration(
                counterText: '',
                hintText: l.giftCodeField,
                hintStyle: const TextStyle(color: Color(0x66FFFFFF)),
                filled: true,
                fillColor: const Color(0x22000000),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0x33FFFFFF)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: busy
                    ? null
                    : () async {
                        final code = ctrl.text.trim();
                        if (code.isEmpty) return;
                        setLocal(() => busy = true);
                        final res = await ref
                            .read(rewardClaimerProvider)
                            .redeemCode(code);
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        if (res == RedeemResult.ok) {
                          AudioService.instance.sfxReward();
                        }
                        if (mounted) {
                          showCenterToast(context, _redeemMessage(l, res));
                        }
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF3E7D4F),
                ),
                child: Text(busy ? l.giftCodeChecking : l.giftCodeSubmit),
              ),
            ),
          ],
        ),
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

  void _showSettings(AppLocalizations l) {
    // 실기에서 어떤 빌드로 켰는지(온라인 Supabase / 로컬) 바로 확인.
    final online = ref.read(pvpBackendProvider).isRemote;
    // 권위 서버 연결 여부는 Supabase 연결과 별개다 — GAME_SERVER_URL 이
    // 주입돼야 붙는다. 실기 검증 때 "지금 서버 경로로 도는가"를 눈으로 본다.
    final serverAuthority = ref.read(gameServerProvider).available;
    showGameDialog<void>(
      context,
      title: l.settingsTitle,
      icon: Icons.settings_rounded,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 개발자 모드는 **릴리즈만** 숨긴다. 예전엔 kDebugMode 전용이라
          // 폰에 넣는 profile 빌드(.dev)에서 열리지 않아 확인을 못 했다.
          if (!kReleaseMode) ...[
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
          _audioSettings(l),
          const SizedBox(height: 10),
          const _NotifySection(),
          // ⚠️ "게임 데이터 초기화" 버튼을 여기 두지 말 것.
          //    확인 다이얼로그가 있어도 **되돌릴 수 없고**, 초기화된 세이브가
          //    60초 안에 서버로 올라가 서버 백업까지 덮는다(무료 플랜은 백업이
          //    없어 복구 수단이 전무하다). 실제로 잘못 눌러 진행도를 통째로 잃는
          //    사고가 났다. 초기화는 개발자 도구(_devTools)에만 둔다.
          // ── 계정(구글 로그인) ──
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _showAccount(l);
              },
              icon: const Icon(Icons.account_circle_rounded, size: 18),
              label: Text(
                ref.read(authServiceProvider).accountLabel ?? l.accountTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF9BE38B),
                side: const BorderSide(color: Color(0x559BE38B)),
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
          // ── 선물코드 ──
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _showGiftCode(l);
              },
              icon: const Icon(Icons.confirmation_number_rounded, size: 18),
              label: Text(l.giftCodeTitle),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFEBC24A),
                side: const BorderSide(color: Color(0x55EBC24A)),
              ),
            ),
          ),
          // ── 리뷰 남기기 ──
          //
          // **보상을 걸지 않는다.** 스토어 API 는 리뷰 작성 여부·별점을 앱에
          // 알려주지 않아 검증이 불가능하고, 플레이·앱스토어 정책도 평점을
          // 대가로 보상 주는 것을 금지한다(적발 시 앱 내림 사유).
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                await requestStoreReview(ref, force: true);
              },
              icon: const Icon(Icons.star_rounded, size: 18),
              label: Text(l.reviewAction),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFFFD977),
                side: const BorderSide(color: Color(0x55FFD977)),
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
                  // 빌드 라벨 + 상태 칩(온라인/서버권위)은 **줄바꿈**한다.
                  // 한 줄 고정이면 서버권위 칩이 붙는 순간 넘친다(실측 7.3px).
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 5,
                    runSpacing: 4,
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
                      // 권위 서버에 붙었을 때만 뜬다. 이 칩이 없으면 전투·재화는
                      // 아직 로컬 계산이다 — 검증 빌드에서 반드시 확인할 신호.
                      if (serverAuthority) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0x333B7A2A),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '🔐 ${l.backendServer}',
                            style: const TextStyle(
                              color: Color(0xFF9FE38B),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                      // 릴리즈인데 구글 테스트 광고 단위로 도는 경우 경고.
                      // 이대로 업로드하면 실사용자가 테스트 광고를 보고 수익도 0이라,
                      // 업로드 전에 눈으로 잡을 수 있게 빌드 표시 옆에 띄운다.
                      if (kReleaseMode && AdMobAdService.usingTestUnits) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0x33E05A5A),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            '⚠️ 테스트광고',
                            style: TextStyle(
                              color: Color(0xFFF3A5A5),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
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

  /// 계정 시트 — 로그인 상태 표시 + 구글 로그인/로그아웃.
  Future<void> _showAccount(AppLocalizations l) async {
    final auth = ref.read(authServiceProvider);
    await showGameDialog<void>(
      context,
      title: l.accountTitle,
      icon: Icons.account_circle_rounded,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            auth.isSignedIn
                ? l.accountSignedIn(auth.accountLabel ?? '')
                : l.accountAnonymous,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xD9FFFFFF),
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          if (auth.available && !auth.isSignedIn) ...[
            // 데이터 유실 경고 — 게스트는 기기 변경·앱 삭제 시 복구 불가.
            // 회색 소극적 안내 대신 눈에 띄는 경고 박스로 로그인을 유도한다.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: _honey.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _honey.withValues(alpha: 0.5)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: _honey,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l.accountAnonRisk,
                      style: const TextStyle(
                        color: Color(0xF2FFE7B0),
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l.accountWhy,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0x99FFFFFF),
                fontSize: 11,
                height: 1.35,
              ),
            ),
          ] else
            Text(
              auth.available ? l.accountWhy : l.accountUnavailable,
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
        // 구글 로그인은 iOS 를 제외하고 노출(iOS 에선 Apple 로그인만 — Apple 4.8).
        // appleAvailable 는 iOS 에서만 true 이므로, !appleAvailable = Android 등.
        if (auth.available && !auth.isSignedIn && !auth.appleAvailable)
          gameDialogButton(l.accountSignIn, () async {
            Navigator.pop(context);
            await _signIn(l, ref.read(authServiceProvider).signInWithGoogle);
          }),
        // Apple 로그인은 iOS 에서만 노출(Apple 4.8 대응).
        // 흰 배경 + 진한 글씨(gameDialogButton 기본 전경색)로 가독성 확보 —
        // 기존 검정 배경은 진한 글씨와 겹쳐 버튼이 안 보였다.
        if (auth.appleAvailable && !auth.isSignedIn)
          gameDialogButton(l.accountSignInApple, () async {
            Navigator.pop(context);
            await _signIn(l, ref.read(authServiceProvider).signInWithApple);
          }, color: const Color(0xFFFFFFFF)),
        if (auth.isSignedIn)
          gameDialogButton(l.accountSignOut, () async {
            Navigator.pop(context);
            await ref.read(authServiceProvider).signOut();
            if (!mounted) return;
            setState(() {});
            ref.invalidate(myRankProvider); // 로그아웃 → 랭킹 표시 제거
            showCenterToast(context, l.accountSignedOut);
          }, color: const Color(0xFF556070)),
        // 계정 삭제는 로그인 여부와 무관하게 제공한다 — 익명 계정도 서버에
        // 랭킹·방어팀 데이터가 쌓이므로 지울 경로가 있어야 한다(Play 요구사항).
        gameDialogButton(l.accountDelete, () async {
          Navigator.pop(context);
          await _deleteAccount(l);
        }, color: const Color(0xFF7A2E2E)),
        // 이용약관·개인정보처리방침 — 스토어 심사(특히 채팅 UGC) 요건.
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _policyLink(l.termsOfUse, _termsUrl),
            const Text('·', style: TextStyle(color: Color(0x66FFFFFF))),
            _policyLink(l.privacyPolicy, _privacyUrl),
          ],
        ),
      ],
    );
  }

  static const _termsUrl =
      'https://dkc260701.github.io/bugchamp-policy/terms.html';
  static const _privacyUrl = 'https://dkc260701.github.io/bugchamp-policy/';

  Widget _policyLink(String label, String url) => TextButton(
    onPressed: () =>
        launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
    child: Text(
      label,
      style: const TextStyle(
        color: Color(0x99FFFFFF),
        fontSize: 11.5,
        decoration: TextDecoration.underline,
      ),
    ),
  );

  /// 계정·서버 데이터 영구 삭제. 되돌릴 수 없으므로 **확인 단어 입력**을 요구한다.
  ///
  /// 순서가 중요하다: **서버 삭제가 성공한 뒤에만 로컬을 초기화**한다.
  /// 반대로 하면 서버 삭제가 실패했을 때 진행도만 날아간다.
  Future<void> _deleteAccount(AppLocalizations l) async {
    final auth = ref.read(authServiceProvider);
    final controller = TextEditingController();
    final word = l.accountDeleteWord;

    final confirmed = await showGameDialog<bool>(
      context,
      title: l.accountDeleteTitle,
      icon: Icons.delete_forever_rounded,
      content: StatefulBuilder(
        builder: (ctx, setLocal) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l.accountDeleteBody(word),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xD9FFFFFF),
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l.accountDeleteWarnPurchase,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFE79A9A),
                fontSize: 11.5,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              onChanged: (_) => setLocal(() {}),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: InputDecoration(
                hintText: word,
                hintStyle: const TextStyle(color: Color(0x55FFFFFF)),
                filled: true,
                fillColor: const Color(0x22000000),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                gameDialogButton(
                  l.actionClose,
                  () => Navigator.pop(ctx, false),
                  primary: false,
                ),
                const SizedBox(width: 8),
                // 확인 단어가 정확히 입력됐을 때만 삭제 버튼이 살아난다.
                if (controller.text.trim() == word)
                  gameDialogButton(
                    l.accountDeleteConfirm,
                    () => Navigator.pop(ctx, true),
                    color: const Color(0xFF9A3434),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: const [],
    );

    if (confirmed != true || !mounted) return;

    final ok = await auth.deleteAccount();
    if (!mounted) return;
    if (!ok) {
      // 서버 삭제 실패 → 로컬은 절대 건드리지 않는다.
      showCenterToast(context, l.accountDeleteFailed);
      return;
    }

    await ref.read(saveControllerProvider.notifier).resetGame();
    if (!mounted) return;
    setState(() {});
    showCenterToast(context, l.accountDeleteDone);
  }

  /// 로그인(구글/Apple) → 성공 시 클라우드 백업 유무에 따라 동기화 방향을 묻는다.
  /// [doSignIn] 만 갈아끼우면 어느 제공자든 같은 후처리를 공유한다.
  Future<void> _signIn(
    AppLocalizations l,
    Future<bool> Function() doSignIn,
  ) async {
    final ok = await doSignIn();
    if (!mounted) return;
    if (!ok) {
      showCenterToast(context, l.accountSignInFailed);
      return;
    }
    setState(() {});
    ref.invalidate(myRankProvider); // 로그인 후 랭킹 재조회
    // 이 계정에 이미 백업이 있으면 어느 쪽을 쓸지 선택하게 한다(덮어쓰기 사고 방지).
    final cloud = ref.read(cloudSaveProvider);
    final existing = cloud.available ? await cloud.download() : null;
    if (!mounted) return;
    if (existing == null) {
      await _cloudBackup(l); // 백업이 없으면 현재 진행도를 그대로 올림
      await _promptNicknameMandatory(l);
      return;
    }
    final useCloud = await showGameDialog<bool>(
      context,
      title: l.accountSyncTitle,
      icon: Icons.cloud_sync_rounded,
      content: Text(
        l.accountSyncBody,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xD9FFFFFF),
          fontSize: 13,
          height: 1.4,
        ),
      ),
      actions: [
        gameDialogButton(
          l.accountKeepDevice,
          () => Navigator.pop(context, false),
          primary: false,
        ),
        gameDialogButton(l.accountUseCloud, () => Navigator.pop(context, true)),
      ],
    );
    if (!mounted || useCloud == null) return;
    if (useCloud) {
      final done = await ref
          .read(saveControllerProvider.notifier)
          .restoreFromJson(existing);
      if (!mounted) return;
      showCenterToast(context, done ? l.cloudRestoreDone : l.cloudFailed);
    } else {
      await _cloudBackup(l);
    }
    await _promptNicknameMandatory(l);
  }

  /// 첫 로그인 시 닉네임 강제 설정 — 공용 게이트(ui/nickname_gate.dart)에 위임.
  /// 빈 값·금칙어·**중복(온라인)** 검증까지 한 곳에서 처리한다.
  Future<void> _promptNicknameMandatory(AppLocalizations l) async {
    if (!mounted) return;
    await ensureNicknameSet(context, ref);
    if (mounted) setState(() {});
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
    showCenterToast(context, ok ? l.cloudBackupDone : l.cloudFailed);
  }

  /// 서버 세이브로 덮어쓴다(되돌릴 수 없어 확인 후 실행).
  Future<void> _cloudRestore(AppLocalizations l) async {
    final data = await ref.read(cloudSaveProvider).download();
    if (!mounted) return;
    if (data == null) {
      showCenterToast(context, l.cloudNoBackup);
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
    showCenterToast(context, ok ? l.cloudRestoreDone : l.cloudFailed);
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
          showCenterToast(context, l.settingsResetDone);
        }, color: const Color(0xFFC85454)),
      ],
    );
  }

  /// 개발자(테스트) 도구 시트 — 채집함/스테이지/재화 조작. (개발 전용, 하드코딩 허용)
  /// 개발자 모드: 이벤트 참가권 지급을 **서버에 요청**한다.
  ///
  /// 참가권은 서버 소유 필드라 로컬로 못 늘린다(`_serverOwnedKeys`) — 세이브를
  /// 고쳐 봐야 다음 업로드에 서버 값으로 덮인다. 그래서 운영 라우트
  /// (`/admin/event-ticket`)를 쓰며, 키는 기기에 저장해 두고 없을 때만 한 번
  /// 묻는다(손으로 옮기는 값이라 매번 입력하면 오타가 난다).
  Future<String> _devGrantEventTickets(int amount) async {
    final server = ref.read(gameServerProvider);
    if (!server.available) return '서버 연결이 없어요 (GAME_SERVER_URL 필요)';
    final uid = ref.read(authServiceProvider).userId;
    if (uid == null) return '로그인 정보가 없어요';

    final prefs = await SharedPreferences.getInstance();
    var key = prefs.getString('dev_admin_key') ?? '';
    if (key.isEmpty) {
      if (!mounted) return '';
      final ctrl = TextEditingController();
      final ok = await showGameDialog<bool>(
        context,
        title: '운영 키 입력',
        icon: Icons.key_rounded,
        content: TextField(
          controller: ctrl,
          autofocus: true,
          obscureText: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'ADMIN_KEY',
            hintStyle: TextStyle(color: Color(0x66FFFFFF)),
          ),
        ),
        actions: [
          gameDialogButton(
            '취소',
            () => Navigator.pop(context, false),
            primary: false,
          ),
          gameDialogButton('저장', () => Navigator.pop(context, true)),
        ],
      );
      if (ok != true) return '';
      key = ctrl.text.trim();
      if (key.isEmpty) return '키가 비어 있어요';
      await prefs.setString('dev_admin_key', key);
    }

    final r = await server.adminEventTicket(
      adminKey: key,
      userId: uid,
      amount: amount,
    );
    if (!r.isOk) {
      // 키가 틀리면 저장분을 지워 다시 물어볼 수 있게 한다.
      if (r.status == 401 || r.status == 403) {
        await prefs.remove('dev_admin_key');
        return '운영 키가 틀렸어요 (다시 입력해 주세요)';
      }
      return '실패: ${r.error ?? r.status}';
    }
    ref.invalidate(eventStateProvider);
    return '참가권 ${r.data?['tickets']}/${r.data?['max']}';
  }

  void _showDevTools(AppLocalizations l) {
    final stageCtrl = TextEditingController();
    void toast(String m) => showCenterToast(context, m);

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
            // 스킨 버튼 라벨(켜기/끄기)이 바로 바뀌도록 watch 한다.
            final skins = r.watch(
              saveControllerProvider.select(
                (v) => v.value?.ownedSkins ?? const <String>{},
              ),
            );
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
                  // 설정 화면에서 옮겨온 것 — 유저가 잘못 눌러 진행도를 통째로
                  // 잃는 사고가 나서, 개발자 모드 안으로만 남긴다.
                  _devSection('세이브', [
                    _devBtn('게임 데이터 초기화', () {
                      Navigator.pop(context);
                      _confirmReset(AppLocalizations.of(context));
                    }),
                  ]),
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
                  // 이벤트 참가권은 **서버 소유 필드**라 로컬로 늘려도 다음
                  // 업로드에 서버 값으로 덮인다. 그래서 서버에 요청해야 하고,
                  // 아무나 부르면 순위가 무너지므로 **운영 키**로 보호한다.
                  _devSection('이벤트', [
                    _devBtn('참가권 +5', () async {
                      final msg = await _devGrantEventTickets(5);
                      if (msg.isNotEmpty) toast(msg);
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
                    _devBtn('화석 조각 +1000', () {
                      ctrl.devAddResources(fossil: 1000);
                      toast('화석 조각 +1000 (제련 50분치)');
                    }),
                  ]),
                  // 스킨은 IAP 전용이라 사이드로드 빌드에선 살 수가 없다.
                  // 색 필터가 종마다 어떻게 나오는지는 실기로 봐야 한다.
                  _devSection('스킨(코스메틱)', [
                    _devBtn('스킨 그림 확인(확대)', () {
                      Navigator.pop(context);
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const SkinGalleryScreen(),
                        ),
                      );
                    }),
                    for (final (id, name) in const [
                      ('gold_rhino', '황금 장수풍뎅이'),
                      ('albino_stag', '알비노 사슴벌레'),
                      ('arena_theme', '아레나 테마'),
                    ])
                      _devBtn(
                        '$name ${skins.contains(id) ? '끄기' : '켜기'}',
                        () async {
                          final on = await ctrl.devToggleSkin(id);
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);
                          toast('$name ${on ? '적용' : '해제'}');
                        },
                      ),
                  ]),
                  // 아트 확인용 — 제련은 부위가 랜덤이라 특정 그림을 보려면
                  // 수십 번 돌려야 한다. 격자로 한 번에 본다.
                  _devSection('장비', [
                    _devBtn('장비 그림 80종 보기', () {
                      Navigator.pop(context);
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const ItemGalleryScreen(),
                        ),
                      );
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
      _stageMax = math.max(_stageMax, n);
      _habitatIndex = 0;
      _isBoss = false;
      _defeated = false;
      _dying = false;
      _walking = false;
      _spawn(announce: false);
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
    // 닉네임 편집 모드. 처음엔 잠겨 있고, 옆 버튼을 눌러야 열린다.
    var editing = false;
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
          // 닉네임은 **잠겨 있다가** 옆 버튼을 눌러야 고칠 수 있다. 바로 입력
          // 가능하면 실수로 건드린 뒤 저장 단계에서야 젤리가 든다는 걸 알게 된다.
          child: StatefulBuilder(
            builder: (ctx, setD) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _portrait(save),
                    const SizedBox(width: 12),
                    Expanded(
                      child: editing
                          ? TextField(
                              controller: controller,
                              maxLength: 8,
                              autofocus: true,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                              decoration: InputDecoration(
                                isDense: true,
                                counterText: '',
                                labelText: l.settingsNickname,
                                labelStyle: const TextStyle(
                                  color: Color(0xFFEBA52F),
                                ),
                                hintText: l.settingsNicknameHint,
                                enabledBorder: const UnderlineInputBorder(
                                  borderSide: BorderSide(
                                    color: Color(0x55EBA52F),
                                  ),
                                ),
                                focusedBorder: const UnderlineInputBorder(
                                  borderSide: BorderSide(
                                    color: Color(0xFFEBA52F),
                                  ),
                                ),
                              ),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  l.settingsNickname,
                                  style: const TextStyle(
                                    color: Color(0xFFEBA52F),
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  save.nickname,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 17,
                                  ),
                                ),
                              ],
                            ),
                    ),
                    if (!editing) ...[
                      const SizedBox(width: 8),
                      // 비용을 버튼에 박아둔다 — 누르기 전에 보여야 한다.
                      OutlinedButton(
                        onPressed: () {
                          // 젤리가 모자라면 **편집을 열지 않는다**. 열어두면 다
                          // 고치고 나서야 못 바꾼다는 걸 알게 된다.
                          if (save.nicknameSet &&
                              save.materialCount(MaterialKind.jelly) <
                                  SaveController.kNicknameChangeCost) {
                            showCenterToast(ctx, l.notEnoughJelly);
                            return;
                          }
                          if (save.nicknameSet) {
                            showCenterToast(
                              ctx,
                              l.nicknameChangeCostHint(
                                SaveController.kNicknameChangeCost,
                              ),
                            );
                          }
                          controller.text = save.nickname;
                          setD(() => editing = true);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFEBA52F),
                          side: const BorderSide(color: Color(0x66EBA52F)),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          minimumSize: const Size(0, 34),
                          visualDensity: VisualDensity.compact,
                        ),
                        child: Text(
                          save.nicknameSet
                              ? l.nicknameEditAction
                              : l.nicknameEditAction,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
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
                      onPressed: () => editing
                          ? setD(() => editing = false)
                          : Navigator.pop(ctx),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xB3FFFFFF),
                      ),
                      child: Text(editing ? l.actionCancel : l.actionClose),
                    ),
                    if (editing)
                      FilledButton(
                        onPressed: () async {
                          final rules = _data.chatRules ?? const ChatRules();
                          final name = controller.text.trim();
                          if (name.isEmpty || name == save.nickname) {
                            setD(() => editing = false);
                            return;
                          }
                          if (!rules.nicknameAllowed(name)) {
                            showCenterToast(ctx, l.nicknameBlockedWord);
                            return;
                          }
                          final taken = await ref
                              .read(pvpBackendProvider)
                              .isNicknameTaken(name);
                          if (!ctx.mounted) return;
                          if (taken) {
                            showCenterToast(ctx, l.nicknameTaken);
                            return;
                          }
                          // 이미 확정된 닉네임 변경 → 젤리 소비, 먼저 확인.
                          if (save.nicknameSet) {
                            final confirm = await showGameDialog<bool>(
                              ctx,
                              title: l.nicknameChangeTitle,
                              icon: Icons.badge_rounded,
                              content: Text(
                                l.nicknameChangeBody,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Color(0xD9FFFFFF),
                                  fontSize: 13.5,
                                  height: 1.4,
                                ),
                              ),
                              actions: [
                                gameDialogButton(
                                  l.actionCancel,
                                  () => Navigator.pop(ctx, false),
                                  primary: false,
                                ),
                                gameDialogButton(
                                  l.nicknameChangeConfirm,
                                  () => Navigator.pop(ctx, true),
                                ),
                              ],
                            );
                            if (confirm != true || !ctx.mounted) return;
                          }
                          final res = await ref
                              .read(saveControllerProvider.notifier)
                              .renamePlayer(name);
                          if (!ctx.mounted) return;
                          if (res == RenameResult.notEnoughJelly) {
                            showCenterToast(ctx, l.notEnoughJelly);
                            return;
                          }
                          // 다음 실행에 서버 세이브가 덮지 않도록 즉시 올린다.
                          await pushSaveNow(ref);
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFEBA52F),
                          foregroundColor: const Color(0xFF3A2600),
                        ),
                        child: Text(l.nicknameEditAction),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 기기 단위 무료 발동 기록. `buff_free_cd_v1` = `kind=iso8601;...`.
  /// 서버 소유까지는 과하다 — 버프는 PvE 편의고 적응 체력 기준에서도 빠져 있다(§7).
  static Future<Map<BuffKind, DateTime>> _loadBuffFreeAt() async {
    final prefs = await SharedPreferences.getInstance();
    final out = <BuffKind, DateTime>{};
    for (final part in (prefs.getString('buff_free_cd_v1') ?? '').split(';')) {
      final i = part.indexOf('=');
      if (i <= 0) continue;
      final kind = BuffKind.fromKey(part.substring(0, i));
      final at = DateTime.tryParse(part.substring(i + 1));
      if (kind != null && at != null) out[kind] = at.toUtc();
    }
    return out;
  }

  static Future<void> _saveBuffFreeAt(Map<BuffKind, DateTime> m) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'buff_free_cd_v1',
      [
        for (final e in m.entries) '${e.key.key}=${e.value.toIso8601String()}',
      ].join(';'),
    );
  }

  /// 'h:mm' — 쿨다운 표시용(초 단위까지는 필요 없다).
  static String _hmm(Duration d) {
    final m = d.inMinutes.clamp(0, 24 * 60);
    return '${m ~/ 60}:${(m % 60).toString().padLeft(2, '0')}';
  }

  Future<void> _showBuffSheet(AppLocalizations l) async {
    final buffs = _data.buffConfig;
    if (buffs == null) return;
    final minutes = (buffs.durationSeconds / 60).round();
    // 시트를 열기 **전에** 읽는다 — 행마다 async 로 읽으면 첫 프레임에
    // 쿨다운 칩이 늦게 떠서 깜빡인다. 맵은 발동 시 제자리 갱신된다.
    final freeAt = await _loadBuffFreeAt();
    if (!mounted) return;
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
                    _buffSheetRow(
                      l,
                      r,
                      k,
                      save.buffRemaining(k, now),
                      minutes,
                      freeAt,
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// 버프 발동권 — 무료(buffs.json `freeDaily`회/일) 소진 후엔 젤리.
  ///
  /// 기기 단위 카운트다. 버프는 PvE 편의라 서버 소유까지는 과하다 —
  /// 몬스터 적응 체력 기준에서도 버프는 빠져 있다(§7).
  Future<bool> _takeBuffActivation(
    AppLocalizations l,
    BuffKind kind,
    Map<BuffKind, DateTime> freeAt,
  ) async {
    // 무한 버프 패스 보유 중이면 발동 자체가 필요 없다(항상 켜져 있다).
    final save = ref.read(saveControllerProvider).requireValue;
    if (save.buffPassActive(ref.read(clockProvider).now().toUtc())) return true;
    final cfg = _data.buffConfig;
    final free = cfg?.freeDaily ?? 12;
    final cost = cfg?.jellyActivate ?? 2;
    final cd = Duration(seconds: cfg?.freeCooldownSeconds ?? 0);
    final prefs = await SharedPreferences.getInstance();
    final now = ref.read(clockProvider).now().toUtc();
    final today = dailyDateKey(now);
    final parts = (prefs.getString('buff_free_v1') ?? '|').split('|');
    final used = parts[0] == today ? (int.tryParse(parts[1]) ?? 0) : 0;
    // 같은 버프의 무료 발동은 [cd] 텀을 둔다(2026-08-27) — 예전엔 하루치
    // 12회를 한자리에서 연달아 눌러 6시간을 공짜로 쌓을 수 있었다.
    final last = freeAt[kind];
    final coolLeft = (last == null || cd == Duration.zero)
        ? Duration.zero
        : cd - now.difference(last);
    if (used < free && coolLeft <= Duration.zero) {
      await prefs.setString('buff_free_v1', '$today|${used + 1}');
      freeAt[kind] = now; // 시트가 이 맵을 그대로 보므로 제자리 갱신
      await _saveBuffFreeAt(freeAt);
      return true;
    }
    // 무료 불가(쿨다운 또는 소진) — **먼저 묻는다**(말없이 젤리를 깎지 않는다).
    // 젤리 발동은 쿨다운을 소모하지도, 걸지도 않는다 — 결제는 시간만 절약(§2.6).
    if (!mounted) return false;
    final ok = await showGameDialog<bool>(
      context,
      title: l.jellyContinueTitle,
      icon: Icons.water_drop_rounded,
      content: Text(
        coolLeft > Duration.zero
            ? l.buffCooldownAsk(_hmm(coolLeft), cost)
            : l.jellyContinueAsk(cost),
        style: const TextStyle(color: Color(0xDDFFFFFF), height: 1.4),
      ),
      actions: [
        gameDialogButton(
          l.actionCancel,
          () => Navigator.pop(context, false),
          primary: false,
        ),
        gameDialogButton(
          l.jellyContinueYes,
          () => Navigator.pop(context, true),
        ),
      ],
    );
    if (ok != true) return false;
    if (!await ref.read(saveControllerProvider.notifier).trySpendJelly(cost)) {
      if (mounted) showCenterToast(context, l.notEnoughJelly);
      return false;
    }
    // 젤리 발동은 무료 카운트를 늘리지 않는다.
    return true;
  }

  Widget _buffSheetRow(
    AppLocalizations l,
    WidgetRef r,
    BuffKind k,
    Duration? remaining,
    int minutes,
    Map<BuffKind, DateTime> freeAt,
  ) {
    final active = remaining != null;
    final now = _clock.now().toUtc();
    // 패스 보유 중엔 쿨다운 표시가 무의미하다(항상 켜져 있고 무료 발동을 안 쓴다).
    final hasPass = r
        .read(saveControllerProvider)
        .requireValue
        .buffPassActive(now);
    final cd = Duration(seconds: _data.buffConfig?.freeCooldownSeconds ?? 0);
    final last = freeAt[k];
    var coolLeft = Duration.zero;
    if (!hasPass && last != null && cd > Duration.zero) {
      final left = cd - now.difference(last);
      if (left > Duration.zero) coolLeft = left;
    }
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
          // 두 상태(무료 / 젤리)의 **크기를 고정**한다. 라벨 길이에 맡기면
          // 무료→쿨다운으로 바뀔 때 버튼이 커졌다 작아졌다 해서 줄이 흔들린다.
          SizedBox(
            width: 132,
            height: 48,
            child: FilledButton.icon(
              onPressed: () async {
                // 무료 발동 소진 후엔 젤리(사장님 결정 2026-08-18). 광고가
                // 비용이던 자리라, 무료 무제한이면 버프가 사실상 상시화된다.
                if (!await _takeBuffActivation(l, k, freeAt)) return;
                if (!mounted) return;
                final ctrl = r.read(saveControllerProvider.notifier);
                await ctrl.activateBuff(k);
                // 광고 덤 젤리는 **데이터에서 온다**(§6). 예전엔 여기 1이 박혀
                // 있었고, 누적 상한 6시간 = 하루 12회라 덤만으로 12젤리/일이 샜다.
                // 광고의 보상은 버프 자체 — 프리미엄 재화를 얹으면 이중 지급이다.
                final bonus = _data.buffConfig?.adJelly ?? 0;
                if (bonus > 0) {
                  await ctrl.applyReward(
                    gold: 0,
                    xp: 0,
                    materials: {MaterialKind.jelly: bonus},
                  );
                }
                if (!mounted) return;
                showCenterToast(
                  context,
                  l.buffActivatedSnack(buffLabel(l, k), minutes),
                );
              },
              // 쿨다운 중엔 버튼이 스스로 설명한다 — "무료 h:mm 남음" 위에,
              // "n개로 켜기"를 아래에(2026-08-27 지적). 칩으로 옆에 두면
              // 버튼은 여전히 "무료로 켜기"라고 거짓말하는 셈이다.
              //
              // ⚠️ 젤리는 **실제 젤리 그림**을 쓴다(`jellyIcon`). 물방울 글리프는
              // 다른 재화처럼 보여서, 무엇을 쓰는지가 버튼에서 안 읽힌다.
              icon: coolLeft > Duration.zero
                  ? jellyIcon(size: 17)
                  : const Icon(Icons.play_arrow_rounded, size: 18),
              label: coolLeft > Duration.zero
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.buffBtnFreeLeft(_hmm(coolLeft)),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xCCFFFFFF),
                          ),
                        ),
                        Text(
                          l.buffBtnJelly(_data.buffConfig?.jellyActivate ?? 2),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    )
                  : Text(l.buffWatchAd),
              style: FilledButton.styleFrom(
                backgroundColor: coolLeft > Duration.zero
                    ? const Color(0xFF1E6091)
                    : const Color(0xFF2E7D32),
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
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

/// 구매 버튼 — 한 번 탭하면 1회, **꾹 누르고 있으면 연속**으로 레벨업한다.
/// 홀드 중 재화가 부족해지면(enabled=false) 자동으로 멈춘다.
class _HoldBuyButton extends StatefulWidget {
  const _HoldBuyButton({
    required this.enabled,
    required this.onFire,
    required this.child,
  });

  final bool enabled;
  final VoidCallback onFire;
  final Widget child;

  @override
  State<_HoldBuyButton> createState() => _HoldBuyButtonState();
}

class _HoldBuyButtonState extends State<_HoldBuyButton> {
  Timer? _timer;
  // 홀드가 이어지면 점점 빨라진다(초반 천천히 → 빠르게).
  int _ticks = 0;

  void _startHold() {
    if (!widget.enabled) return;
    widget.onFire(); // 홀드 인식 즉시 1회
    _ticks = 0;
    _schedule(const Duration(milliseconds: 180));
  }

  void _schedule(Duration d) {
    _timer?.cancel();
    _timer = Timer(d, () {
      if (!mounted || !widget.enabled) {
        _stopHold();
        return;
      }
      widget.onFire();
      _ticks++;
      // 가속: 180ms → 최소 45ms 까지 단계적으로 단축.
      final ms = (180 - _ticks * 12).clamp(45, 180);
      _schedule(Duration(milliseconds: ms));
    });
  }

  void _stopHold() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _stopHold();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // 짧게 탭 = 1회 구매. 꾹 누르면 = 연속.
      // 진동은 **여기 한 곳**에만 — 연속 구매(_schedule)마다 울리면 손이 아프다.
      onTap: widget.enabled
          ? () {
              // selectionClick 은 기기·설정에 따라 아예 안 느껴진다 —
              // 구매는 확실한 피드백이 필요하므로 lightImpact 로 쓴다.
              HapticFeedback.lightImpact();
              widget.onFire();
            }
          : null,
      onLongPressStart: (_) {
        HapticFeedback.lightImpact();
        _startHold();
      },
      onLongPressEnd: (_) => _stopHold(),
      onLongPressCancel: _stopHold,
      child: widget.child,
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
          _HoldBuyButton(
            enabled: affordable,
            onFire: onBuy,
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

/// 달성한 미션처럼 "지금 눌러야 할" 칸을 은은하게 깜빡이는 상자.
///
/// 스스로 애니메이션을 돈다 — 부모의 틱 값을 읽어 계산하면, 바텀시트처럼
/// 부모와 함께 다시 그려지지 않는 자리에서 값이 멈춰 깜빡이지 않는다.
class _PulseBox extends StatefulWidget {
  const _PulseBox({
    required this.active,
    required this.child,
    this.padding = EdgeInsets.zero,
  });

  final bool active;
  final Widget child;
  final EdgeInsets padding;

  @override
  State<_PulseBox> createState() => _PulseBoxState();
}

class _PulseBoxState extends State<_PulseBox>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) {
      return Padding(padding: widget.padding, child: widget.child);
    }
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_c.value);
        return Container(
          padding: widget.padding,
          decoration: BoxDecoration(
            color: _honey.withValues(alpha: 0.14 + 0.16 * t),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _honey.withValues(alpha: 0.5 + 0.5 * t),
              width: 1.3,
            ),
            boxShadow: [
              BoxShadow(
                color: _honey.withValues(alpha: 0.25 * t),
                blurRadius: 10 * t,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// 설정 시트의 알림 섹션.
///
/// ⚠️ **자체 State 를 가져야 한다.** 설정은 바텀시트라 화면(_PlayScreenState)의
/// setState 로는 다시 그려지지 않는다 — 펼치기가 먹지 않던 원인.
class _NotifySection extends StatefulWidget {
  const _NotifySection();

  @override
  State<_NotifySection> createState() => _NotifySectionState();
}

class _NotifySectionState extends State<_NotifySection> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ValueListenableBuilder<NotifySettings>(
      valueListenable: NotifyPrefs.instance.settings,
      builder: (context, s, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            child: Row(
              children: [
                Text(
                  l.settingsNotify,
                  style: const TextStyle(
                    color: Color(0xFFEBA52F),
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                Icon(
                  _open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                  color: const Color(0xCCFFFFFF),
                  size: 20,
                ),
              ],
            ),
          ),
          // 제목뿐 아니라 "알림 받기" 줄을 눌러도 펼쳐진다 — 스위치만 피해서
          // 탭하면 되도록 InkWell 을 행 전체에 건다.
          InkWell(
            onTap: () => setState(() => _open = !_open),
            child: _row(
              Icons.notifications_active_rounded,
              l.notifyAll,
              s.enabled,
              NotifyPrefs.instance.setEnabled,
            ),
          ),
          if (_open)
            Padding(
              padding: const EdgeInsets.only(left: 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _row(
                    Icons.hourglass_full_rounded,
                    l.notifyOfflineFull,
                    s.offlineFull,
                    NotifyPrefs.instance.setOfflineFull,
                    enabled: s.enabled,
                  ),
                  _row(
                    Icons.egg_alt_rounded,
                    l.notifyHatchDone,
                    s.hatchDone,
                    NotifyPrefs.instance.setHatchDone,
                    enabled: s.enabled,
                  ),
                  _row(
                    Icons.card_giftcard_rounded,
                    l.notifyDaily,
                    s.daily,
                    NotifyPrefs.instance.setDaily,
                    enabled: s.enabled,
                  ),
                  _row(
                    Icons.redeem_rounded,
                    l.notifyGift,
                    s.gift,
                    NotifyPrefs.instance.setGift,
                    enabled: s.enabled,
                  ),
                  _row(
                    Icons.bedtime_rounded,
                    l.notifyQuietHours,
                    s.quietHours,
                    NotifyPrefs.instance.setQuietHours,
                    enabled: s.enabled,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _row(
    IconData icon,
    String label,
    bool on,
    Future<void> Function(bool) onChanged, {
    bool enabled = true,
  }) => Opacity(
    opacity: enabled ? 1 : 0.4,
    child: Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xCCFFFFFF)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Color(0xE6FFFFFF), fontSize: 13),
          ),
        ),
        Switch(
          value: on,
          onChanged: enabled ? (v) => onChanged(v) : null,
          activeThumbColor: _honey,
        ),
      ],
    ),
  );
}

/// 무료 2배 소진 다이얼로그의 선택지.
enum _CapAction { shop, buy }

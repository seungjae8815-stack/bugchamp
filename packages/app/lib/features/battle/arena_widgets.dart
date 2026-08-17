import 'dart:math' as math;

import 'package:core_battle/core_battle.dart';
import 'package:core_models/core_models.dart';
import 'package:flutter/material.dart' hide Element;

import '../../data/game_data.dart';
import '../../domain/audio_service.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/art.dart';
import '../../ui/format.dart';
import '../../ui/game_dialog.dart';
import '../../ui/labels.dart';

/// 오토 아레나(`battle_arena.dart`)와 수동 배틀(`manual_battle_screen.dart`)이
/// 공유하는 순수 표시 위젯. 파이터/데미지 플로트/결과 다이얼로그를 한 곳에 둔다.

const arenaHoney = Color(0xFFEBA52F);
const kRoundDur = 0.85; // 라운드 1회 재생 시간(초, 1x)

String stanceGlyph(Stance s) => switch (s) {
  Stance.attack => '⚔️',
  Stance.defend => '🛡️',
  Stance.heal => '💚',
};

String stanceLabel(AppLocalizations l, Stance s) => switch (s) {
  Stance.attack => l.stanceAttack,
  Stance.defend => l.stanceDefend,
  Stance.heal => l.stanceHeal,
};

Color stanceColor(Stance s) => switch (s) {
  Stance.attack => const Color(0xFFC1502E),
  Stance.defend => const Color(0xFF2E6DA4),
  Stance.heal => const Color(0xFF3E7D4F),
};

IconData stanceIcon(Stance s) => switch (s) {
  Stance.attack => Icons.sports_mma_rounded,
  Stance.defend => Icons.shield_rounded,
  Stance.heal => Icons.favorite_rounded,
};

/// 스탠스 그림. 애셋(`assets/images/ui/stance/<name>.png`)이 있으면 그림을,
/// 없으면 머티리얼 아이콘으로 폴백한다 — 오행과 같은 규칙(§6).
///
/// 스탠스는 **심리전의 핵심 정보**다(공>회>방>공). 매 라운드 눈으로 훑는 자리라
/// 한눈에 구분돼야 한다.
///
/// 이름이 `stanceIcon` 이 아닌 이유: 위의 `IconData` 판이 이미 그 이름을 쓴다.
Widget stanceArt(Stance s, {double size = 20}) => Image.asset(
  'assets/images/ui/stance/${s.name}.png',
  width: size,
  height: size,
  filterQuality: FilterQuality.medium,
  errorBuilder: (_, _, _) =>
      Icon(stanceIcon(s), size: size * 0.9, color: Colors.white),
);

/// 떠오르는 데미지/회복 숫자(가변 age 를 가진 애니메이션 상태).
class FloatText {
  FloatText(this.text, this.color, this.left, {this.element});
  final String text;
  final Color color;
  final bool left;

  /// 있으면 글자 앞에 오행 아이콘을 붙인다(상극 표시). 숫자 데미지는 null.
  final Element? element;
  double age = 0;
  static const life = 0.9;
}

/// 오행 상극(克) 히트 시 터지는 링 버스트(가변 age).
class BurstFx {
  BurstFx({required this.left, required this.color});
  final bool left;
  final Color color;
  double age = 0;
  static const life = 0.45;
}

/// 파이터 **몸만** — 캐릭터 그림 + 타격 모션 + 스탠스 표시.
///
/// 이름·HP 바와 분리한 이유: 대각 구도([ArenaStage])에서는 몸과 이름표가
/// **화면의 반대쪽 구석**에 놓인다(포켓몬식). 한 덩어리로 묶여 있으면 그 배치가
/// 불가능하고, 몸 크기를 좌우 다르게 주는 것도 안 된다.
class ArenaBody extends StatelessWidget {
  const ArenaBody({
    super.key,
    required this.data,
    required this.bug,
    required this.speciesId,
    required this.flip,
    required this.stance,
    required this.flash,
    required this.dx,
    this.size = 96,
    this.stanceHidden = false,
    this.skin,
    this.down = false,
  });

  final GameData data;
  final BattleBug bug;
  final String? speciesId;
  final bool flip;
  final Stance? stance;
  final double flash;
  final double dx;
  final double size;
  final bool stanceHidden;
  final ColorFilter? skin;

  /// 쓰러지는 중. 넘어가며 사라진다 — KO 가 그냥 "다음 곤충으로 바뀜"이면
  /// 무엇이 끝났는지 안 읽힌다.
  final bool down;

  @override
  Widget build(BuildContext context) {
    final sp = data.speciesById[speciesId ?? ''];
    // 자세는 이미 들고 있는 상태에서 나온다 — 맞는 중이면 피격, 돌진 중이면 공격.
    // **돌진이 피격을 이긴다**(한 라운드에 보통 양쪽이 다 맞으므로).
    final pose = dx.abs() > 1.5
        ? BugPose.attack
        : (flash > 0.4 ? BugPose.hurt : BugPose.idle);
    Widget img = sp == null
        ? Icon(Icons.bug_report, color: Colors.white, size: size * 0.6)
        : bugPoseImage(
            sp.id,
            down ? BugPose.hurt : pose,
            size: size,
            fallback: bugAvatar(sp, size: size * 0.85),
            skin: skin,
          );
    if (flip) img = Transform.flip(flipX: true, child: img);

    return SizedBox(
      height: size * 1.25,
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          // 정지 그림 하나로도 **때리고 맞는 것처럼** 보이게 한다.
          //   · 돌진하는 쪽: 앞으로 밀리며 그 방향으로 기운다
          //   · 맞는 쪽: 살짝 납작해졌다 돌아온다(스쿼시)
          AnimatedOpacity(
            duration: const Duration(milliseconds: 260),
            opacity: down ? 0 : 1,
            child: Transform(
              alignment: Alignment.bottomCenter,
              transform: Matrix4.identity()
                ..translateByDouble(dx, flash * 3.0, 0, 1)
                // 쓰러질 땐 뒤로 넘어간다(방향은 바라보는 쪽 반대).
                ..rotateZ(
                  dx * 0.0045 * (flip ? -1 : 1) +
                      (down ? (flip ? 1.1 : -1.1) : 0),
                )
                ..scaleByDouble(1 + flash * 0.10, 1 - flash * 0.14, 1, 1),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                switchInCurve: Curves.easeOutBack,
                switchOutCurve: Curves.easeIn,
                // ⚠️ `FadeTransition(opacity: anim)` 을 쓰면 안 된다 —
                // `easeOutBack` 이 1.0 을 넘겨 단언에 걸린다(위와 같은 함정).
                // 곤충이 교대될 때마다 오류 화면이 스쳤다.
                transitionBuilder: (child, anim) => AnimatedBuilder(
                  animation: anim,
                  child: child,
                  builder: (_, c) => Opacity(
                    opacity: anim.value.clamp(0.0, 1.0),
                    child: Transform.translate(
                      // 튕김은 **위치에만** 남긴다.
                      offset: Offset(
                        (flip ? 0.7 : -0.7) * (1 - anim.value) * 70,
                        0,
                      ),
                      child: c,
                    ),
                  ),
                ),
                child: KeyedSubtree(
                  key: ValueKey(bug.id),
                  // 맞는 순간 **곤충 실루엣 자체를 하얗게 태운다**(빨간 판을
                  // 덮으면 타격이 아니라 오류 표시처럼 읽힌다).
                  child: flash <= 0
                      ? img
                      : ColorFiltered(
                          colorFilter: ColorFilter.mode(
                            Colors.white.withValues(
                              alpha: (flash * 0.9).clamp(0.0, 1.0),
                            ),
                            BlendMode.srcATop,
                          ),
                          child: img,
                        ),
                ),
              ),
            ),
          ),
          if ((stance != null || stanceHidden) && !down)
            Positioned(
              top: 0,
              child: stanceHidden
                  ? Text('❓', style: TextStyle(fontSize: size * 0.21))
                  : stanceArt(stance!, size: size * 0.21),
            ),
        ],
      ),
    );
  }
}

/// 이름표 — 이름·오행·HP 바. 대각 구도에서 **몸의 반대쪽 구석**에 놓인다.
class ArenaPlate extends StatelessWidget {
  const ArenaPlate({
    super.key,
    required this.bug,
    required this.hpFrac,
    this.nameOverride,
    this.compact = false,
    this.mine,
  });

  final BattleBug bug;
  final double hpFrac;
  final String? nameOverride;

  /// 상대 쪽(작게). 화면 위쪽은 정보가 적을수록 무대가 넓어 보인다.
  final bool compact;

  /// true=내 곤충 / false=상대 / null=표시 안 함.
  ///
  /// 둘을 같은 크기로 세우면서 **이게 유일한 구분**이 됐다 — 색만으로는
  /// 오행색과 헷갈린다.
  final bool? mine;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      padding: const EdgeInsets.fromLTRB(8, 5, 8, 6),
      decoration: BoxDecoration(
        // 무대 그림 위에 얹히므로 **자기 바닥**이 있어야 글자가 읽힌다.
        color: const Color(0xB30E1408),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x33FFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (mine != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: mine!
                        ? const Color(0xFF3E7D4F)
                        : const Color(0xFFA8442B),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    // 표시할 때만 찾는다 — 이름표는 다국어 없이도 그려져야
                    // 테스트에서 무대만 따로 펌프할 수 있다.
                    mine!
                        ? AppLocalizations.of(context).sideMine
                        : AppLocalizations.of(context).sideFoe,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
              ],
              elementIcon(bug.element, size: compact ? 11 : 13),
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  nameOverride ?? bug.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  // 이름은 **흰색**이다. 오행색으로 칠했더니 통나무 배경 위에서
                  // 초록·황토가 묻혀 안 읽혔다 — 색은 옆 아이콘이 이미 말한다.
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: compact ? 10.5 : 12,
                    shadows: const [
                      Shadow(color: Colors.black87, blurRadius: 3),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Stack(
              children: [
                Container(
                  height: compact ? 9 : 11,
                  color: const Color(0x66000000),
                ),
                FractionallySizedBox(
                  widthFactor: hpFrac.clamp(0.0, 1.0),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: compact ? 9 : 11,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: hpFrac > 0.3
                            ? const [Color(0xFF7CE38B), Color(0xFF3FA84E)]
                            : const [Color(0xFFFF8A6B), Color(0xFFD84A2E)],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 아레나 한쪽 파이터: 이름·오행·HP바·캐릭터·스탠스 글리프.
/// [dx] 는 이미 방향이 반영된 최종 돌진 오프셋. [stanceHidden] 이면 스탠스를 ❓로 가림(심리전).
class ArenaFighter extends StatelessWidget {
  const ArenaFighter({
    super.key,
    required this.data,
    required this.bug,
    required this.speciesId,
    required this.hpFrac,
    required this.flip,
    required this.stance,
    required this.flash,
    required this.dx,
    this.stanceHidden = false,
    this.skin,
    this.nameOverride,
  });

  final GameData data;
  final BattleBug bug;
  final String? speciesId;
  final double hpFrac;
  final bool flip;
  final Stance? stance;
  final double flash;
  final double dx;
  final bool stanceHidden;

  /// 구매한 스킨의 색 필터. **내 쪽 파이터에만** 준다(상대 곤충은 상대의 외형).
  final ColorFilter? skin;

  /// 화면에 쓸 이름. 이벤트 적처럼 **전투 엔진이 지은 내부 이름**(`W3-1`)을
  /// 그대로 보여주면 안 되는 경우에 준다 — 엔진은 순수 패키지라 다국어를 모른다.
  final String? nameOverride;

  @override
  Widget build(BuildContext context) {
    final u = bug;
    final sp = data.speciesById[speciesId ?? ''];
    // 자세는 이미 들고 있는 상태에서 나온다 — 맞는 중이면 피격, 돌진 중이면 공격.
    // 자세 프레임이 없는 종은 로더가 대기 그림으로 내려가므로 그냥 안 바뀔 뿐이다.
    // **돌진이 피격을 이긴다.** 예전엔 피격을 먼저 봤는데, 이 전투는 한 라운드에
    // 보통 **양쪽이 다 맞으므로** 둘 다 피격 자세가 되고 공격 자세는 아예 안
    // 나왔다(실기: "공격 모션이 안 보인다"). 달려드는 쪽 = 때리는 쪽이다.
    //
    // 피격은 **번쩍임이 셀 때만** — 끝까지 물고 있으면 다음 라운드까지 맞는
    // 자세로 서 있어서, 돌아오는 순간이 없으니 맞은 것으로 안 읽힌다.
    final pose = dx.abs() > 1.5
        ? BugPose.attack
        : (flash > 0.4 ? BugPose.hurt : BugPose.idle);
    Widget img = sp == null
        ? const Icon(Icons.bug_report, color: Colors.white, size: 60)
        : bugPoseImage(
            sp.id,
            pose,
            size: 96,
            fallback: bugAvatar(sp, size: 84),
            skin: skin,
          );
    if (flip) img = Transform.flip(flipX: true, child: img);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      // 아레나 높이가 좁아도(작은 화면·큰 하단 UI) 넘치지 않게 축소.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                elementIcon(u.element, size: 13),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    nameOverride ?? u.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    // 이름은 **흰색**이다. 오행색으로 칠했더니 나무(#855A31)·
                    // 통나무 배경 위에서 초록·황토가 묻혀 안 읽혔다(실기 지적).
                    // 색은 바로 옆 오행 아이콘이 이미 말해 준다 — 글자까지
                    // 색을 지면 정보가 늘지 않고 가독성만 잃는다.
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      shadows: [Shadow(color: Colors.black87, blurRadius: 3)],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: 120,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Stack(
                  children: [
                    Container(height: 12, color: const Color(0x55000000)),
                    FractionallySizedBox(
                      widthFactor: hpFrac,
                      child: Container(
                        height: 12,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: hpFrac > 0.3
                                ? const [Color(0xFF7CE38B), Color(0xFF3FA84E)]
                                : const [Color(0xFFFF8A6B), Color(0xFFD84A2E)],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 120,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // 정지 그림 하나로도 **때리고 맞는 것처럼** 보이게 한다.
                  //   · 돌진하는 쪽: 앞으로 밀리며 그 방향으로 기운다
                  //   · 맞는 쪽: 살짝 납작해졌다 돌아온다(스쿼시)
                  // 프레임 아트가 없어도 이 둘만으로 타격감이 생긴다 —
                  // 오프셋만 있으면 그냥 미끄러지는 것처럼 보였다(실기 지적).
                  Transform(
                    alignment: Alignment.bottomCenter,
                    transform: Matrix4.identity()
                      ..translateByDouble(dx, flash * 3.0, 0, 1)
                      ..rotateZ(dx * 0.0045 * (flip ? -1 : 1))
                      ..scaleByDouble(1 + flash * 0.10, 1 - flash * 0.14, 1, 1),
                    // 교대 시 슬라이드-인/아웃(KO 퇴장 + 다음 파이터 등장).
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      switchInCurve: Curves.easeOutBack,
                      switchOutCurve: Curves.easeIn,
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: SlideTransition(
                          position: Tween(
                            begin: Offset(flip ? 0.7 : -0.7, 0),
                            end: Offset.zero,
                          ).animate(anim),
                          child: child,
                        ),
                      ),
                      child: KeyedSubtree(
                        key: ValueKey(bug.id),
                        // 맞는 순간 **곤충 실루엣 자체를 하얗게 태운다**.
                        // 빨간 사각형을 덮으면 곤충 위에 판을 얹은 것처럼 보여
                        // 타격이 아니라 오류 표시처럼 읽힌다(실기 지적).
                        child: flash <= 0
                            ? img
                            : ColorFiltered(
                                colorFilter: ColorFilter.mode(
                                  Colors.white.withValues(
                                    alpha: (flash * 0.9).clamp(0.0, 1.0),
                                  ),
                                  BlendMode.srcATop,
                                ),
                                child: img,
                              ),
                      ),
                    ),
                  ),
                  if (stance != null || stanceHidden)
                    Positioned(
                      top: -14,
                      child: stanceHidden
                          ? const Text('❓', style: TextStyle(fontSize: 20))
                          : stanceArt(stance!),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 공/방/회 상성(공>회>방>공)을 원형으로 보여주는 휠.
/// 공격 12시 · 회복 4시 · 방어 8시 → 시계방향 화살표가 "이김" 방향.
///
/// - 수동 전투: [onPick] 을 주면 노드를 탭해 스탠스를 고른다.
/// - 자동 전투: [onPick] 을 비우고 [centerLabel] 로 진행 상태만 보여준다
///   ([highlight] 로 현재 내 수를 강조).
class StanceWheel extends StatelessWidget {
  const StanceWheel({
    super.key,
    required this.energy,
    this.onPick,
    this.enabled = true,
    this.centerLabel,
    this.highlight,
  });

  /// 현재 기력(방어·회복 선택 가능 판정).
  final int energy;

  /// 스탠스 선택 콜백. null 이면 **표시 전용**.
  final void Function(Stance)? onPick;

  /// 입력 단계인지(표시 전용이면 무시).
  final bool enabled;

  /// 링 가운데 문구. 기본은 상성 순서 안내.
  final String? centerLabel;

  /// 강조 표시할 스탠스(자동 전투의 현재 수).
  final Stance? highlight;

  bool get _interactive => onPick != null;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return LayoutBuilder(
      builder: (ctx, cons) {
        // 폭을 최대한 쓰되 화면 높이 비율로도 상한(짧은 화면 오버플로우 방지).
        final maxByHeight = MediaQuery.sizeOf(context).height * 0.42;
        final s = math.min(math.min(cons.maxWidth, 460.0), maxByHeight);
        final node = s * 0.34;
        final r = s / 2 - node / 2 - 2;
        final center = Offset(s / 2, s / 2);
        Widget at(double deg, Widget child) {
          final a = deg * math.pi / 180;
          final p = center + Offset(math.cos(a), math.sin(a)) * r;
          return Positioned(
            left: p.dx - node / 2,
            top: p.dy - node / 2,
            width: node,
            child: child,
          );
        }

        return SizedBox(
          width: s,
          height: s + 26,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                top: 0,
                width: s,
                height: s,
                child: CustomPaint(painter: _StanceRingPainter(r)),
              ),
              Positioned(
                left: 0,
                top: s / 2 - 9,
                width: s,
                child: Text(
                  centerLabel ?? '공 › 회 › 방 › 공',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: centerLabel == null
                        ? const Color(0x66FFFFFF)
                        : arenaHoney,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              at(-90, _node(l, Stance.attack, true, node)),
              at(30, _node(l, Stance.heal, energy >= 1, node)),
              at(150, _node(l, Stance.defend, energy >= 1, node)),
            ],
          ),
        );
      },
    );
  }

  Widget _node(AppLocalizations l, Stance s, bool affordable, double size) {
    // 표시 전용이면 강조된 수만 또렷하게, 나머지는 흐리게.
    final active = _interactive
        ? (enabled && affordable)
        : (highlight == null || highlight == s);
    final base = stanceColor(s);
    final cost = s == Stance.attack ? '+1' : '−1';
    return Opacity(
      opacity: active ? 1 : 0.4,
      child: GestureDetector(
        onTap: (_interactive && enabled && affordable)
            ? () => onPick!(s)
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                // 원을 **어둡게** 채우고 테두리로만 스탠스 색을 말한다.
                // 예전엔 원을 스탠스 색으로 꽉 채웠는데, 그림을 얹으니 공격
                // (빨간 원 + 빨간 큰턱)이 통째로 묻혔다 — 그림 자체가 이미
                // 색을 들고 있으므로 배경까지 같은 색이면 형태가 사라진다.
                color: Color.lerp(base, const Color(0xFF14181E), 0.72),
                shape: BoxShape.circle,
                border: Border.all(
                  color: highlight == s ? Colors.white : base,
                  width: highlight == s ? 3.5 : 2.5,
                ),
                boxShadow: active
                    ? [
                        BoxShadow(
                          color: base.withValues(alpha: 0.55),
                          blurRadius: 16,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              // 같은 화면에서 그림과 머티리얼 아이콘이 섞이면 같은 개념이
              // 둘로 보인다 — 선택 버튼도 아레나와 같은 그림을 쓴다.
              child: stanceArt(s, size: size * 0.44),
            ),
            const SizedBox(height: 4),
            Text(
              stanceLabel(l, s),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              '⚡$cost',
              style: const TextStyle(
                color: Color(0xCCFFFFFF),
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 스탠스 휠 링 + 시계방향 화살표(공>회>방>공 상성 흐름).
class _StanceRingPainter extends CustomPainter {
  const _StanceRingPainter(this.radius);

  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = radius;
    if (r <= 0) return;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..color = const Color(0x3AFFFFFF);
    canvas.drawCircle(c, r, ring);
    final arrow = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0x66FFFFFF);
    for (final deg in const [-30.0, 90.0, 210.0]) {
      final a = deg * math.pi / 180;
      final p = c + Offset(math.cos(a), math.sin(a)) * r;
      final t = a + math.pi / 2;
      _head(canvas, p, Offset(math.cos(t), math.sin(t)), arrow);
    }
  }

  void _head(Canvas canvas, Offset p, Offset dir, Paint paint) {
    const s = 14.0;
    final perp = Offset(-dir.dy, dir.dx);
    final tip = p + dir * s;
    final b1 = p - dir * s + perp * (s * 0.7);
    final b2 = p - dir * s - perp * (s * 0.7);
    canvas.drawPath(
      Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(b1.dx, b1.dy)
        ..lineTo(b2.dx, b2.dy)
        ..close(),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _StanceRingPainter old) => old.radius != radius;
}

/// 라운드 안에서 **타격이 꽂히는 시점**(0~1 진행도).
const double arenaImpactAt = 0.16;

/// 라운드 진행도(0..1) → 돌진 정도(0..1).
///
/// **빠르게 뻗었다 천천히 돌아온다.** 예전엔 `sin(t*pi)` 였는데 정점이 라운드
/// 한가운데라, 때리는 게 아니라 **몸을 천천히 흔드는 것**처럼 보였다
/// (실기: "공격 모션이 제대로 안 보인다"). 타격은 빨라야 타격으로 읽힌다.
double arenaLungeCurve(double t) {
  if (t <= 0) return 0;
  if (t < arenaImpactAt) return t / arenaImpactAt;
  final back = (t - arenaImpactAt) / 0.42;
  return back >= 1 ? 0 : 1 - back * back;
}

/// 떠오르는 데미지/회복 숫자 위젯.
class ArenaFloat extends StatelessWidget {
  const ArenaFloat({super.key, required this.f});
  final FloatText f;

  @override
  Widget build(BuildContext context) {
    final t = (f.age / FloatText.life).clamp(0.0, 1.0);
    final w = MediaQuery.of(context).size.width;
    final x = f.left ? w * 0.25 : w * 0.72;
    return Positioned(
      left: x - 24,
      top: 150 - t * 60,
      child: Opacity(
        opacity: (1 - t).clamp(0.0, 1.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (f.element != null) ...[
              elementIcon(f.element!, size: 20),
              const SizedBox(width: 3),
            ],
            Text(
              f.text,
              style: TextStyle(
                color: f.color,
                fontWeight: FontWeight.w900,
                fontSize: 22,
                shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 오행 상극(克) 링 버스트 이펙트.
class ArenaBurst extends StatelessWidget {
  const ArenaBurst({super.key, required this.fx});
  final BurstFx fx;

  @override
  Widget build(BuildContext context) {
    final t = (fx.age / BurstFx.life).clamp(0.0, 1.0);
    final size = 28 + t * 92;
    final w = MediaQuery.of(context).size.width;
    final cx = fx.left ? w * 0.25 : w * 0.72;
    return Positioned(
      left: cx - size / 2,
      top: 178 - size / 2,
      child: IgnorePointer(
        child: Opacity(
          opacity: (1 - t).clamp(0.0, 1.0),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: fx.color, width: 3 * (1 - t) + 1),
              boxShadow: [
                BoxShadow(
                  color: fx.color.withValues(alpha: 0.5 * (1 - t)),
                  blurRadius: 14,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 결과 다이얼로그의 팀 HP% 막대.
Widget arenaTeamHpBar(String label, double pct, Color color) => Row(
  children: [
    SizedBox(
      width: 64,
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 11.5),
      ),
    ),
    Expanded(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: LinearProgressIndicator(
          value: pct.clamp(0.0, 1.0),
          minHeight: 10,
          backgroundColor: const Color(0x33000000),
          valueColor: AlwaysStoppedAnimation(color),
        ),
      ),
    ),
    const SizedBox(width: 6),
    SizedBox(
      width: 38,
      child: Text(
        '${(pct * 100).round()}%',
        textAlign: TextAlign.right,
        style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 11),
      ),
    ),
  ],
);

/// 전투 종료 결과 다이얼로그(오토/수동 공용). [onClose] 로 닫힘 동작 주입.
Future<void> showBattleResultDialog(
  BuildContext context, {
  required BattleResult result,
  required int gold,
  required int trophyDelta,
  required VoidCallback onClose,
}) {
  final l = AppLocalizations.of(context);
  final win = result.outcome == BattleOutcome.teamA;
  final draw = result.outcome == BattleOutcome.draw;
  final title = win ? l.battleWin : (draw ? l.battleDraw : l.battleLose);
  // 무승부는 패배음까지 붙이면 과하다 — 승/패만 울린다.
  if (win) {
    AudioService.instance.sfxWin();
  } else if (!draw) {
    AudioService.instance.sfxLose();
  }
  final color = win
      ? const Color(0xFF6FCF6F)
      : (draw ? const Color(0xFFBFC4CC) : const Color(0xFFEF9A9A));
  return showGameDialog<void>(
    context,
    title: title,
    icon: win ? Icons.emoji_events_rounded : Icons.sports_mma_rounded,
    barrierDismissible: false,
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        arenaTeamHpBar(
          l.battleMyTeam,
          result.teamAHpPct,
          const Color(0xFF6FC96F),
        ),
        const SizedBox(height: 6),
        arenaTeamHpBar(l.battleFoe, result.teamBHpPct, const Color(0xFFC85454)),
        const SizedBox(height: 12),
        Text(
          l.battleReward,
          style: const TextStyle(
            color: arenaHoney,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '💰 ${formatCompact(gold)}    '
          '🏆 ${trophyDelta >= 0 ? '+' : ''}$trophyDelta',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
      ],
    ),
    actions: [gameDialogButton(l.actionClose, onClose)],
  );
}

/// 전투 무대 — **둘을 같은 선 위에, 같은 크기로** 세운다.
///
/// 한때 원근(내 곤충 크게·상대 작게)을 줬다가 되돌렸다(실기 지적). 크기가 다르면
/// 전력 차이로 오해되고, 상대가 작아서 무슨 일이 벌어지는지 보기 어려웠다.
/// **누가 내 편인지**는 크기가 아니라 이름표의 "나/상대" 표시로 말한다 — 그게
/// 오해의 여지가 없다.
///
/// 이름표는 **자기 몸 바로 위**다. 반대쪽 구석에 뒀더니 "어느 HP 바가 내 것인지"
/// 헷갈렸다.
class ArenaStage extends StatelessWidget {
  const ArenaStage({
    super.key,
    required this.background,
    required this.mineBody,
    required this.foeBody,
    required this.minePlate,
    required this.foePlate,
    this.shake = 0,
    this.overlays = const [],
  });

  final Widget background;
  final Widget mineBody;
  final Widget foeBody;
  final Widget minePlate;
  final Widget foePlate;
  final double shake;

  /// 데미지 숫자·버스트·인트로 등 무대 위에 뜨는 것들.
  final List<Widget> overlays;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      // 상극이 터질 때만 흔든다 — 매 라운드 흔들면 멀미가 나고 "이번 한 방이
      // 컸다"는 신호도 죽는다.
      offset: Offset(shake * 6 * (shake > 0.5 ? 1 : -1), 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: [
            Positioned.fill(child: background),
            // 같은 선 위에 나란히. 발이 같은 높이라 "마주 섰다"가 읽힌다.
            Align(
              alignment: const Alignment(0, 0.92),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        minePlate,
                        const SizedBox(height: 4),
                        mineBody,
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [foePlate, const SizedBox(height: 4), foeBody],
                    ),
                  ),
                ],
              ),
            ),
            ...overlays,
          ],
        ),
      ),
    );
  }
}

/// 전투 시작 인트로 — 양 팀이 좌우에서 밀려 들어오고 가운데 VS 가 찍힌다.
///
/// 시작이 없으면 화면이 뜨자마자 이미 싸우고 있어서 **"시작했다"는 마디**가 없다.
/// [t] 는 0→1 진행도. 1 에 도달하면 사라진다.
class ArenaIntro extends StatelessWidget {
  const ArenaIntro({
    super.key,
    required this.t,
    required this.mineName,
    required this.foeName,
  });

  final double t;
  final String mineName;
  final String foeName;

  @override
  Widget build(BuildContext context) {
    if (t >= 1) return const SizedBox.shrink();
    // 마지막 20% 는 사라지는 구간 — 글자가 남아 있으면 첫 라운드를 가린다.
    final fade = t > 0.8 ? (1 - (t - 0.8) / 0.2) : 1.0;
    final slide = Curves.easeOutCubic.transform((t / 0.45).clamp(0.0, 1.0));
    final stamp = Curves.easeOutBack.transform(
      ((t - 0.25) / 0.35).clamp(0.0, 1.0),
    );
    return Positioned.fill(
      child: IgnorePointer(
        child: Opacity(
          opacity: fade.clamp(0.0, 1.0),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(color: Colors.black.withValues(alpha: 0.34 * fade)),
              Align(
                alignment: const Alignment(-0.9, -0.18),
                child: Transform.translate(
                  offset: Offset(-260 * (1 - slide), 0),
                  child: _tag(mineName, const Color(0xFF7CE38B)),
                ),
              ),
              Align(
                alignment: const Alignment(0.9, 0.18),
                child: Transform.translate(
                  offset: Offset(260 * (1 - slide), 0),
                  child: _tag(foeName, const Color(0xFFFF8A6B)),
                ),
              ),
              Transform.scale(
                scale: 0.4 + stamp * 0.6,
                child: Opacity(
                  // ⚠️ `easeOutBack` 은 **1.0 을 넘겼다 돌아온다**(그게 "톡" 하고
                  // 찍히는 맛이다). 그 값을 그대로 Opacity 에 주면 단언에 걸려
                  // **빨간 오류 화면**이 잠깐 떴다 사라진다(실기 지적).
                  // 튕김은 scale 에만 남기고 투명도는 자른다.
                  opacity: stamp.clamp(0.0, 1.0),
                  child: const Text(
                    'VS',
                    style: TextStyle(
                      color: arenaHoney,
                      fontSize: 54,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      shadows: [
                        Shadow(color: Colors.black, blurRadius: 10),
                        Shadow(color: Color(0xAAEBA52F), blurRadius: 22),
                      ],
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

  Widget _tag(String name, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xCC0E1408),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: c.withValues(alpha: 0.8), width: 1.5),
    ),
    child: Text(
      name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(color: c, fontWeight: FontWeight.w900, fontSize: 15),
    ),
  );
}

/// 승패 배너 — 다이얼로그 대신 화면을 가로지르는 띠.
///
/// 다이얼로그는 "알림"이라 이겼는지 졌는지가 **사건**으로 안 남는다. 띠가
/// 밀려 들어오고 트로피가 올라가는 게 보여야 한 판이 끝난 느낌이 든다.
class ArenaResultBanner extends StatelessWidget {
  const ArenaResultBanner({
    super.key,
    required this.t,
    required this.text,
    required this.win,
    this.sub,
  });

  final double t;
  final String text;
  final bool win;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    final p = Curves.easeOutCubic.transform(t.clamp(0.0, 1.0));
    final c = win ? const Color(0xFFEBC24A) : const Color(0xFF8FA0B5);
    return Positioned.fill(
      child: IgnorePointer(
        child: Center(
          child: Transform.translate(
            offset: Offset((1 - p) * 420, 0),
            child: Opacity(
              opacity: p,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      c.withValues(alpha: 0.30),
                      c.withValues(alpha: 0.30),
                      Colors.transparent,
                    ],
                  ),
                  border: Border(
                    top: BorderSide(color: c.withValues(alpha: 0.8), width: 2),
                    bottom: BorderSide(
                      color: c.withValues(alpha: 0.8),
                      width: 2,
                    ),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      text,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: c,
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3,
                        shadows: const [
                          Shadow(color: Colors.black, blurRadius: 8),
                        ],
                      ),
                    ),
                    if (sub != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        sub!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

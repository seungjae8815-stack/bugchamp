import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/providers.dart';
import '../domain/save_controller.dart';

/// 구매한 스킨(코스메틱)을 실제 외형에 입히는 색 처리.
///
/// 새 아트 없이 **색상 필터**로 구현한다 — 스탯에는 전혀 영향이 없다(§2.6).
/// 스킨 정의(어느 종에 어떤 효과)는 `iap.json` 의 `skins` 에 있다(§6).

/// 곤충 스킨 효과 → 색 필터. 알 수 없는 효과면 null(기본 외형).
///
/// ⚠️ 행렬을 고치면 `tool/make_skin_thumbs.py` 의 GOLD/ALBINO/ARENA 도 같이
/// 고치고 다시 돌린다 — 상점 썸네일을 이 행렬로 만들기 때문에, 갈리면 상점
/// 그림이 조용히 거짓말을 시작한다.
ColorFilter? bugSkinFilter(String? effect) => switch (effect) {
  // 황금: 휘도를 **1.75배로 밀고 그림자를 깎는다**.
  //
  // 예전엔 1.35배 + 오프셋이라 "누렇게 뜬 갈색"이었다 — 원본이 이미 갈색인
  // 장수풍뎅이라 차이가 거의 안 보였다(2026-08-19 지적). 하이라이트를 흰금까지
  // 올리고 그림자를 깊은 청동으로 떨어뜨려야 **금속**으로 읽힌다.
  'gold' => const ColorFilter.matrix(<double>[
    0.5233, 1.0273, 0.1995, 0, -30, //
    0.4037, 0.7925, 0.1539, 0, -28, //
    0.1196, 0.2348, 0.0456, 0, -20, //
    0, 0, 0, 1, 0, //
  ]),
  // 알비노: 탈색해 흰쪽으로 밀되, **원래 색을 15%만 남겨** 진주광을 만든다.
  //
  // 완전 무채색이면 밋밋한 회백색 덩어리가 된다. 채널마다 자기 색을 조금씩
  // 남기면 각도에 따라 분홍·청록이 비치는 알비노 특유의 질감이 산다.
  'albino' => const ColorFilter.matrix(<double>[
    0.2756, 0.2465, 0.0479, 0, 140, //
    0.1256, 0.3465, 0.0479, 0, 138, //
    0.1256, 0.2465, 0.1979, 0, 142, //
    0, 0, 0, 1, 0, //
  ]),
  // 무지개(이색 개체 §2.1): 색상환을 160° 돌리고 채도를 1.55배 —
  // 원본이 무슨 색이든 "본 적 없는 색"이 되는 게 목적이다.
  'rainbow' => const ColorFilter.matrix(<double>[
    -1.0462, 1.3775, 0.6687, 0, 0, //
    0.5990, 0.3742, 0.0267, 0, 0, //
    0.1060, 2.1356, -1.2416, 0, 0, //
    0, 0, 0, 1, 0, //
  ]),
  _ => null,
};

/// 아레나 테마 스킨의 배경 색보정 — **채도 1.45배 + 대비 1.15배 + 따뜻함**.
///
/// 예전엔 대비만 살짝(1.18/1.06/0.92) 올려서 켜고 끈 차이를 못 느꼈다.
/// 배경은 뒤에 깔리는 그림이라 어지간히 밀지 않으면 안 읽힌다.
const ColorFilter arenaThemeFilter = ColorFilter.matrix(<double>[
  1.5127, -0.3038, -0.0590, 0, -8, //
  -0.1548, 1.3638, -0.0590, 0, -18, //
  -0.1548, -0.3038, 1.6085, 0, -28, //
  0, 0, 0, 1, 0, //
]);

/// [child] 에 [filter] 를 입힌다. filter 가 null 이면 원본 그대로.
Widget withSkin(Widget child, ColorFilter? filter) =>
    filter == null ? child : ColorFiltered(colorFilter: filter, child: child);

/// 내 곤충([speciesId])의 스킨 그리기 정보. 미보유/미해당이면 null.
SkinView? myBugSkin(IapConfig? cfg, Set<String> ownedSkins, String speciesId) {
  if (cfg == null || ownedSkins.isEmpty) return null;
  final e = cfg.skinEffectFor(ownedSkins, speciesId);
  return e == null ? null : SkinView(e, hasArt: cfg.skinHasArt(e, speciesId));
}

/// 곤충 하나의 **그리기 정보** — 이색(변이)과 스킨을 합쳐 정한다.
///
/// 이색이 스킨보다 우선한다: 이색은 1/300 복권이고 스킨은 언제든 살 수 있다.
/// 산 것이 뽑은 것을 덮으면 "무지개가 사라졌다"는 문의가 된다.
/// (알비노 이색은 유료 알비노 스킨과 같은 색 처리를 쓴다 — 스킨 쪽은
/// 확률이 아니라 **확정 구매 + 전용 그림**이 값어치다.)
SkinView? bugView(SkinOf skinOf, IndividualBug bug) =>
    bug.variant != BugVariant.none
    ? SkinView(bug.variant.key)
    : skinOf(bug.speciesId);

/// 아레나 테마 스킨을 보유했는지.
bool hasArenaTheme(IapConfig? cfg, Set<String> ownedSkins) =>
    cfg != null &&
    ownedSkins.isNotEmpty &&
    cfg.ownsEffect(ownedSkins, 'arenaTheme');

/// 한 곤충에 걸린 스킨의 **그리기 정보**.
///
/// 색 필터가 아니라 이 값을 들고 다닌다 — 색에서 효과를 되짚을 수 없어서,
/// 필터만 넘기면 후광·반짝임([SkinAura])을 붙일 수가 없다(2026-08-19).
@immutable
class SkinView {
  const SkinView(this.effect, {this.hasArt = false});

  /// 효과 키(`gold`/`albino`). 후광 색과 그림 파일명에 쓰인다.
  final String effect;

  /// 이 종에 **전용 스킨 그림**이 있는가.
  ///
  /// 있으면 `{종}_adult_{n}_{effect}.webp` 를 쓰고 **색 필터를 입히지 않는다**
  /// — 그림이 이미 그 색이라 두 번 물들면 뭉갠다. 없으면 예전처럼 색 필터.
  final bool hasArt;

  @override
  bool operator ==(Object other) =>
      other is SkinView && other.effect == effect && other.hasArt == hasArt;

  @override
  int get hashCode => Object.hash(effect, hasArt);
}

/// 종 id → 그 곤충의 스킨 그리기 정보. 미보유/미해당이면 null.
typedef SkinOf = SkinView? Function(String speciesId);

/// 스킨 없음(기본 외형). 위젯 파라미터 기본값용.
SkinView? noSkin(String speciesId) => null;

/// 현재 세이브의 보유 스킨 기준 해석기. 세이브/데이터 로딩 전이면 항상 null.
final skinOfProvider = Provider<SkinOf>((ref) {
  final cfg = ref.watch(gameDataProvider).value?.iapConfig;
  final owned = ref.watch(
    saveControllerProvider.select(
      (s) => s.value?.ownedSkins ?? const <String>{},
    ),
  );
  if (cfg == null || owned.isEmpty) return (_) => null;
  return (speciesId) => myBugSkin(cfg, owned, speciesId);
});

/// 아레나 테마 스킨 보유 여부.
final arenaThemeOwnedProvider = Provider<bool>((ref) {
  final cfg = ref.watch(gameDataProvider).value?.iapConfig;
  final owned = ref.watch(
    saveControllerProvider.select(
      (s) => s.value?.ownedSkins ?? const <String>{},
    ),
  );
  return hasArenaTheme(cfg, owned);
});

/// 스킨 이펙트 오버레이 — **색 필터만으로는 "화려함"이 안 나온다.**
///
/// 색 행렬은 픽셀 색만 바꾼다. 보석·갑옷처럼 **없던 것을 그릴 수는 없다**.
/// 종마다 손으로 그리면 24장(성충 8종 × 3자세)이 필요하고 종이 늘 때마다
/// 또 늘어난다. 그래서 그림 대신 **빛**을 얹는다 — 뒤에 후광, 앞에 반짝임.
/// 어느 종에 걸어도 같은 값어치가 나오고 새 아트가 0장이다(2026-08-19).
///
/// 작게 그릴 땐(목록 썸네일) 반짝임을 끈다 — 46px 에서는 점으로 뭉개지고
/// 목록 수십 칸이 동시에 애니메이션하면 프레임을 깎아먹는다.
class SkinAura extends StatefulWidget {
  const SkinAura({
    super.key,
    required this.effect,
    required this.size,
    required this.child,
  });

  /// 스킨 효과 키(`gold`/`albino`). null 이면 아무것도 안 얹는다.
  final String? effect;
  final double size;
  final Widget child;

  /// 반짝임을 켜는 최소 크기. 이보다 작으면 후광만.
  ///
  /// 스카우트 보드·채집함 썸네일이 46px 이라 예전 문턱(60)에서는 **후광만
  /// 남아 "스킨인지 모르겠다"가 됐다**(실기 지적 2026-08-19). 40 이면 그
  /// 칸들이 들어온다. 더 낮추지는 말 것 — 목록 수십 칸이 동시에 애니메이션하면
  /// 프레임을 깎아먹는다.
  static const sparkleMinSize = 40.0;

  @override
  State<SkinAura> createState() => _SkinAuraState();
}

class _SkinAuraState extends State<SkinAura>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );

  @override
  void initState() {
    super.initState();
    if (widget.effect != null && widget.size >= SkinAura.sparkleMinSize) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pal = _auraPalette(widget.effect);
    if (pal == null) return widget.child;
    final s = widget.size;
    // 안쪽 밝은 빛 → 바깥 진한 테 → 투명. 진한 테가 있어야 **밝은 배경에서도**
    // 곤충 둘레가 읽힌다(밝은 빛만 있으면 낮에는 흰 바탕에 묻힌다).
    final glow = IgnorePointer(
      child: Container(
        width: s * 1.16,
        height: s * 1.16,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              pal.inner.withValues(alpha: 0.45),
              pal.outer.withValues(alpha: 0.34),
              pal.outer.withValues(alpha: 0),
            ],
            stops: const [0.20, 0.62, 1],
          ),
        ),
      ),
    );
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        glow,
        widget.child,
        if (s >= SkinAura.sparkleMinSize)
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _c,
              builder: (_, _) => CustomPaint(
                size: Size(s, s),
                painter: _SparklePainter(t: _c.value, sparks: pal.sparks),
              ),
            ),
          ),
      ],
    );
  }
}

/// 효과별 빛 색. 알 수 없는 효과면 null(오버레이 없음).
///
/// **세 겹으로 나눈다.** 예전엔 색 하나로 안쪽부터 투명까지 번지게 했는데,
/// 그 색이 밝은색이라 **낮(밝은 배경)에는 통째로 안 보였다**(실기 지적
/// 2026-08-19). 밝은 배경에서 보이려면 배경보다 **진한** 테가 있어야 한다.
///   · inner — 안쪽 밝은 빛(어두운 배경에서 산다)
///   · outer — 바깥 진한 테(밝은 배경에서 산다)
///   · sparks — 반짝임 색 **여러 개**. 한 색이면 배경과 겹칠 때 사라지지만,
///     색이 흩어져 있으면 어떤 배경에서도 몇 개는 살아남는다.
({Color inner, Color outer, List<Color> sparks})? _auraPalette(String? e) =>
    switch (e) {
      'gold' => (
        inner: const Color(0xFFFFF3C4),
        outer: const Color(0xFFCE7A12),
        sparks: const [
          Color(0xFFFFD24A), // 호박
          Color(0xFFFFFFFF), // 흰빛
          Color(0xFFFF8A2B), // 주황
          Color(0xFFFFB88C), // 장미금
          Color(0xFFFFF3A0), // 연노랑
          Color(0xFFE0552B), // 구릿빛
          Color(0xFFFFE07A), // 금
        ],
      ),
      'rainbow' => (
        inner: const Color(0xFFE0FFE8),
        outer: const Color(0xFF9C27B0),
        sparks: const [
          Color(0xFFFF5C8A), // 진분홍
          Color(0xFFFFC24A), // 호박
          Color(0xFF7CF07C), // 초록
          Color(0xFF5FD8FF), // 시안
          Color(0xFFB388FF), // 보라
          Color(0xFFFFFFFF), // 흰빛
          Color(0xFFFFF07A), // 노랑
        ],
      ),
      'albino' => (
        inner: const Color(0xFFFFFFFF),
        outer: const Color(0xFF6E56C8),
        sparks: const [
          Color(0xFF5FD8FF), // 시안
          Color(0xFFC9A7FF), // 라일락
          Color(0xFFFF9ECF), // 분홍
          Color(0xFF7CF0C4), // 민트
          Color(0xFFFFFFFF), // 흰빛
          Color(0xFF8FA8FF), // 연청
          Color(0xFFFFD98A), // 연노랑(보색 한 점)
        ],
      ),
      _ => null,
    };

/// 반짝임 — 4각 별 여러 개가 **서로 다른 색·위상**으로 명멸한다.
///
/// 색을 흩는 이유: 한 색이면 그 색과 비슷한 배경에서 통째로 사라진다.
/// 여러 색이면 어떤 배경에서도 몇 개는 살아남아 "반짝인다"가 읽힌다.
///
/// 위치는 고정이다. 무작위로 뿌리면 프레임마다 자리가 바뀌어 지저분해지고,
/// 결정론 원칙(§5)과도 어긋난다.
class _SparklePainter extends CustomPainter {
  _SparklePainter({required this.t, required this.sparks});

  final double t;
  final List<Color> sparks;

  /// (x비율, y비율, 크기비율, 위상)
  static const _spots = <(double, double, double, double)>[
    (0.16, 0.22, 0.095, 0.00),
    (0.80, 0.28, 0.075, 0.35),
    (0.60, 0.10, 0.060, 0.62),
    (0.28, 0.70, 0.080, 0.18),
    (0.88, 0.62, 0.065, 0.80),
    (0.46, 0.86, 0.070, 0.50),
    (0.08, 0.52, 0.060, 0.26),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < _spots.length; i++) {
      final (fx, fy, fr, phase) = _spots[i];
      final tone = sparks[i % sparks.length];
      // 삼각파 — 0에서 커졌다 다시 0으로. 사인보다 반짝임이 또렷하다.
      final u = (t + phase) % 1.0;
      final a = u < 0.5 ? u * 2 : (1 - u) * 2;
      if (a <= 0.02) continue;
      final c = Offset(fx * size.width, fy * size.height);
      final r = fr * size.width * a;
      // 4각 별: 세로·가로로 뾰족한 마름모 둘.
      Path star(double rr) => Path()
        ..moveTo(c.dx, c.dy - rr)
        ..quadraticBezierTo(c.dx, c.dy, c.dx + rr, c.dy)
        ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + rr)
        ..quadraticBezierTo(c.dx, c.dy, c.dx - rr, c.dy)
        ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - rr)
        ..close();
      // **진한 심지 위에 밝은 속심.** 밝은 배경에서 밝은 별만 그리면 흰 바탕에
      // 묻힌다 — 진한 테를 한 겹 깔아야 낮에도 별 모양이 읽힌다.
      final deep = HSLColor.fromColor(tone);
      p.color = deep
          .withLightness((deep.lightness * 0.45).clamp(0.0, 1.0))
          .withSaturation((deep.saturation * 0.9 + 0.1).clamp(0.0, 1.0))
          .toColor()
          .withValues(alpha: a * 0.85);
      canvas.drawPath(star(r * 1.35), p);
      p.color = tone.withValues(alpha: a * 0.98);
      canvas.drawPath(star(r), p);
    }
  }

  @override
  bool shouldRepaint(_SparklePainter old) => old.t != t;
}

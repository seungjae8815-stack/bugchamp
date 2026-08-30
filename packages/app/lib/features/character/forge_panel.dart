import 'dart:async';
import 'dart:math' as math;

import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:core_save/core_save.dart' show kMaxForgeStack;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/audio_service.dart';
import '../../domain/providers.dart';
import '../../domain/save_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/art.dart';
import '../../ui/format.dart';
import '../../ui/game_dialog.dart';
import '../../ui/labels.dart';
import '../../ui/toast.dart';
import 'equip_widgets.dart';

const _honey = Color(0xFFFFD54F);

/// 장비 칸 **바로 밑**에 붙는 공방 조작부.
///
/// 가운데 [제련], 그 옆에 자동 제련 아이콘, 아래에 [공방 등급].
/// 화면을 옮기지 않는다 — 장비를 보면서 바로 돌리는 게 이 시스템의 리듬이다.
class ForgeBar extends ConsumerStatefulWidget {
  const ForgeBar({super.key});

  @override
  ConsumerState<ForgeBar> createState() => _ForgeBarState();
}

class _ForgeBarState extends ConsumerState<ForgeBar> {
  /// 자동이 돌고 있나. **타이머가 아니라 망치질 애니메이션이 박자를 잡는다** —
  /// 타이머로 돌렸더니 망치가 한 번 툭 치고 2초 넘게 쉬어서 "돌고 있나?" 싶었다.
  bool _autoOn = false;
  bool _busy = false;

  /// 한 번 뽑는 데 걸리는 시간 = 망치질 한 바퀴(§6 — `forge.json → hammerSeconds`).
  ///
  /// 손으로 눌러도 **같은 시간**이 걸린다. 즉시 뽑히면 손가락만 빠르면 화석을
  /// 몇 초 만에 다 태울 수 있어서, 뽑는 재미도 머무는 시간도 사라진다.
  Duration _cycle(ForgeConfig f) =>
      Duration(milliseconds: (f.hammerSeconds * 1000).round());

  /// 망치가 마지막으로 내리친 순간 — 여기서 한 개가 나온다.
  Future<void> _onStrikeDone() async {
    if (_busy) return;
    _busy = true;
    final full =
        ref.read(saveControllerProvider).requireValue.forgeStack.length >=
        kMaxForgeStack;
    final r = await ref.read(saveControllerProvider.notifier).forgeOnce();
    if (!mounted) return;
    _busy = false;
    final l = AppLocalizations.of(context);
    if (r.item == null) {
      // 화석이 떨어졌거나 모루가 가득 찼다 — 자동이면 여기서 멈춘다.
      setState(() => _autoOn = false);
      showCenterToast(context, full ? l.forgeStackFull : l.forgeNoFossil);
      return;
    }
    // 걸러진 것도 화석은 줄었으니 다시 그린다.
    setState(() {});
    if (!r.kept && !_autoOn) {
      // 손으로 두드렸는데 아무것도 안 쌓이면 고장으로 보인다 — 이유를 말한다.
      showCenterToast(context, l.forgeFiltered);
    }
  }

  /// 자동 제련 — 망치가 **쉬지 않고** 돌면서 한 바퀴마다 하나씩 쌓는다.
  ///
  /// 예전엔 자동으로 갈아 끼웠지만, 그러면 뭘 뽑았는지 못 보고 지나간다.
  /// 지금은 쌓아 두고 **본인이 하나씩 열어 본다**.
  ///
  /// 좋은 게 나왔다고 **중간에 멈추지 않는다.** 어차피 쌓아 두고 나중에 보는
  /// 구조라 멈출 이유가 없다. 화석이 떨어지거나 10칸이 다 차면 멈춘다.
  void _toggleAuto() => setState(() => _autoOn = !_autoOn);

  /// 쌓인 것 중 **맨 위 하나**를 열어 본다.
  ///
  /// ⚠️ **먼저 빼내면 안 된다.** 예전엔 빼고 나서 창을 띄웠는데, 바깥을 눌러
  /// 창을 닫으면 교체도 버리기도 안 했는데 아이템이 사라졌다.
  /// 교체/버리기를 **누른 뒤에만** 모루에서 없앤다.
  Future<void> _openTop() async {
    final stack = ref.read(saveControllerProvider).requireValue.forgeStack;
    if (stack.isEmpty) return;
    final done = await showForgeResult(context, ref, stack.last);
    if (done) await ref.read(saveControllerProvider.notifier).takeForgeItem();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final save = ref.watch(saveControllerProvider).requireValue;
    final data = ref.watch(gameDataProvider).value;
    final forge = data?.forgeConfig;
    final items = data?.itemConfig;
    if (forge == null || items == null) return const SizedBox.shrink();
    final fossil = save.materialCount(MaterialKind.fossil);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 왼쪽 = 공방 등급. **좌우 폭을 같게** 두어야 모루가 진짜 가운데에
        // 온다(가장 자주 누르는 버튼이 엄지 정중앙이어야 한다).
        _SquareButton(
          icon: Icons.workspace_premium_rounded,
          label: l.forgeGradeButton,
          sub: '${save.forgeLevel + 1}',
          busy: save.forgeUpAt != null,
          onTap: () => showForgeGrade(context, ref),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 뽑은 것들이 **모루 위에 쌓인다**. 자리를 늘 비워 두어야
                // 쌓일 때 아래가 밀리지 않는다.
                _ForgePile(
                  stack: save.forgeStack,
                  config: items,
                  onTap: _openTop,
                ),
                // **모루 자체가 버튼**이다. 칸 전체를 누르게 하면 모루를
                // 겨냥해 누른 게 아니라 "칸을 눌렀다"는 느낌이 든다.
                _AnvilButton(
                  cycle: _cycle(forge),
                  auto: _autoOn,
                  onStrike: _onStrikeDone,
                ),
                const SizedBox(height: 3),
                Text(
                  l.forgeHammer,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 화석 조각은 제련의 **유일한 소모품**이다 — 여기가 그걸
                    // 확인하는 자리이므로 실제 재료 아이콘을 쓴다(범용 망치
                    // 아이콘은 모루 버튼과 헷갈렸다).
                    materialImage(
                      MaterialKind.fossil,
                      size: 14,
                      fallback: const Icon(
                        Icons.hardware_outlined,
                        size: 12,
                        color: _honey,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      formatCompact(fossil),
                      style: const TextStyle(
                        color: _honey,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        // 오른쪽 = 필터 위, 자동 아래. 필터로 걸러 놓고 자동을 켜는 순서라
        // 위아래도 그 순서로 둔다.
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SquareButton(
              icon: Icons.tune_rounded,
              label: l.forgeFilter,
              sub: save.autoForgeOptions.isEmpty
                  ? null
                  : '${save.autoForgeOptions.length}',
              on: save.autoForgeOptions.isNotEmpty,
              onTap: () async {
                await showForgeFilter(context, ref);
                if (mounted) setState(() {});
              },
            ),
            const SizedBox(height: 6),
            _SquareButton(
              icon: _autoOn ? Icons.stop_rounded : Icons.autorenew_rounded,
              label: l.forgeAutoShort,
              on: _autoOn,
              onTap: _toggleAuto,
            ),
          ],
        ),
      ],
    );
  }
}

/// 공방 조작부의 네모 버튼(공방 등급 · 필터 · 자동).
///
/// 셋의 **크기를 똑같이** 맞춘다 — 좌우 폭이 어긋나면 가운데 모루가 한쪽으로
/// 밀린다.
class _SquareButton extends StatelessWidget {
  const _SquareButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.sub,
    this.on = false,
    this.busy = false,
  });

  final IconData icon;
  final String label;
  final String? sub;
  final VoidCallback onTap;

  /// 켜져 있나 — 꿀색으로 채운다.
  final bool on;

  /// 타이머가 도는 중인가 — 모래시계를 덧붙인다.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final fg = on ? const Color(0xFF2A1B08) : _honey;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: on
                ? const [Color(0xFFFFD54F), Color(0xFFC08A1E)]
                : const [Color(0xFF6B4A28), Color(0xFF3A2716)],
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: on ? Colors.white : _honey, width: 1.3),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              busy ? Icons.hourglass_bottom_rounded : icon,
              color: fg,
              size: 18,
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: fg,
                fontSize: 9,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (sub != null)
              Text(
                sub!,
                style: TextStyle(
                  color: fg,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 모루 위에 쌓인 제련 결과. 누르면 맨 위 하나를 열어 본다.
///
/// 자리(높이)는 **비었을 때도 그대로 둔다** — 쌓일 때마다 아래 버튼이
/// 밀려 올라가면 두드리던 손가락이 헛나간다.
class _ForgePile extends StatelessWidget {
  const _ForgePile({
    required this.stack,
    required this.config,
    required this.onTap,
  });

  final List<EquipItem> stack;
  final ItemConfig config;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const h = 38.0;
    if (stack.isEmpty) return const SizedBox(height: h);
    final l = AppLocalizations.of(context);
    // **쌓인 걸 다 보여 준다.** 5개까지만 그렸더니 10칸이 찼는데도 5개로
    // 보여서 "안 쌓인다"로 읽혔다. 대신 간격을 좁혀 다 들어가게 한다.
    // 오른쪽에서 왼쪽으로 — 방금 뽑힌 게 맨 왼쪽이자 **맨 위**다.
    const step = -11.0;

    return SizedBox(
      // 폭을 고정한다 — 안 그러면 개수 배지가 아이템 한 칸 옆(=가운데)에
      // 붙어 버린다. 10개가 ±50px 로 퍼지므로 그만큼 잡아 둔다.
      width: 170,
      height: h,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            for (var i = 0; i < stack.length; i++)
              Transform.translate(
                // 세로로는 **어긋내지 않는다.** 한 칸씩 올려 쌓았더니 계단이
                // 져서 위쪽이 잘리고 줄이 비뚤어 보였다.
                offset: Offset((i - (stack.length - 1) / 2) * step, 0),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: const Color(0xCC101A0C),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: tierColor(config, stack[i].tier),
                      width: 1.4,
                    ),
                  ),
                  child: itemImage(stack[i], size: 26),
                ),
              ),
            // 몇 개 남았는지 — 겹쳐 있으면 숫자가 없으면 못 센다.
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xE6FFD54F),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  '${stack.length}',
                  style: const TextStyle(
                    color: Color(0xFF2A1B08),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -2,
              child: Text(
                l.forgeStackHint,
                style: const TextStyle(
                  color: _honey,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 모루 그림 버튼 — 누르면 **망치가 두 번 내리친다**(땅, 땅).
///
/// 그냥 눌리기만 하면 뭘 했는지 안 보인다. 실제로 두드리는 그림과 소리가
/// 있어야 "제련했다"가 손에 남는다.
class _AnvilButton extends StatefulWidget {
  const _AnvilButton({
    required this.cycle,
    required this.auto,
    required this.onStrike,
  });

  /// 망치질 한 바퀴 = **한 개 뽑는 데 걸리는 시간**.
  final Duration cycle;

  /// 자동이 도는 중인가 — 도는 동안은 쉬지 않고 두드린다.
  final bool auto;

  /// 마지막(세 번째) 타격 순간. 여기서 한 개가 나온다.
  final VoidCallback onStrike;

  @override
  State<_AnvilButton> createState() => _AnvilButtonState();
}

/// 단독 망치 그림. 없으면 망치를 안 그린다(모루 그림에 이미 얹혀 있다).
const _kHammer = 'assets/images/ui/hammer.webp';

class _AnvilButtonState extends State<_AnvilButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  /// 단독 망치 그림이 실제로 있나 — 애셋은 **한 번만** 물어본다.
  bool _hasHammerArt = false;

  /// 이번 망치질에서 소리를 낸 타격 수 — 같은 타격에 두 번 울리지 않게.
  int _rung = 0;

  /// 직전 프레임의 진행도 — 한 바퀴를 돌았는지(자동 반복) 알아내는 데 쓴다.
  double _prev = 0;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.cycle)
      ..addListener(_onFrame);
    _checkHammer();
    if (widget.auto) _c.repeat();
  }

  Future<void> _checkHammer() async {
    try {
      await rootBundle.load(_kHammer);
      if (mounted) setState(() => _hasHammerArt = true);
    } catch (_) {
      // 없으면 그냥 안 그린다 — §6 폴백 원칙.
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// **세 번** 내리친다(땅·땅·땅). 각 값이 망치가 닿는 순간이다.
  /// 아래 [_angle] 의 코사인이 -1 이 되는 지점과 **정확히 같아야** 소리와
  /// 그림이 어긋나지 않는다 — `1/6, 3/6, 5/6`.
  static const _hits = [1 / 6, 0.5, 5 / 6];

  void _onFrame() {
    final t = _c.value;
    if (t < _prev) _rung = 0; // 자동 반복 — 한 바퀴를 돌았다
    _prev = t;
    while (_rung < _hits.length && t >= _hits[_rung]) {
      _rung++;
      AudioService.instance.sfxForge();
      // **마지막 타격에서** 결과가 나온다. 애니메이션이 끝난 뒤로 미루면
      // 소리·불꽃이 지나가고 나서 뒤늦게 쌓여 인과가 안 보인다.
      if (_rung == _hits.length) widget.onStrike();
    }
    setState(() {});
  }

  @override
  void didUpdateWidget(_AnvilButton old) {
    super.didUpdateWidget(old);
    if (widget.cycle != old.cycle) _c.duration = widget.cycle;
    if (widget.auto == old.auto) return;
    if (widget.auto) {
      _rung = 0;
      _prev = 0;
      _c.repeat();
    } else {
      // 돌던 바퀴는 **끝까지 마친다** — 중간에 멈추면 망치가 허공에 뜬다.
      _c.forward();
    }
  }

  /// 손으로 두드린다. **한 바퀴가 끝나기 전엔 안 받는다** — 연타로 화석을
  /// 몇 초 만에 태워버리면 뽑는 재미도, 머무는 시간도 사라진다.
  void _strike() {
    if (widget.auto || _c.isAnimating) return;
    _rung = 0;
    _prev = 0;
    _c.forward(from: 0);
  }

  /// 든 자세(42°)와 내리친 자세(6°). 실제 그림을 겹쳐 보고 고른 값이다 —
  /// 6°에서 망치 머리가 모루 상판에 닿는다.
  static const _up = 0.733;
  static const _down = 0.105;

  /// 망치 각도(rad). 위로 들었다가 모루로 떨어진다.
  double get _angle {
    if (!_c.isAnimating && _c.value == 0) return _up;
    // **세 번** 왕복 — 코사인이 -1 인 지점이 타격이다.
    const mid = (_up + _down) / 2;
    const amp = (_up - _down) / 2;
    return mid + amp * math.cos(2 * math.pi * _hits.length * _c.value);
  }

  /// 타격 직후의 불꽃 세기(0~1).
  double get _spark {
    var best = 0.0;
    for (final h in _hits) {
      final d = (_c.value - h).abs();
      if (d < 0.09) best = math.max(best, 1 - d / 0.09);
    }
    return _c.isAnimating ? best : 0;
  }

  @override
  Widget build(BuildContext context) {
    final spark = _spark;
    return GestureDetector(
      onTap: _strike,
      // 그림 바깥의 투명한 부분도 눌리게 — 누끼를 뜬 그림이라 실제 픽셀은
      // 모루 모양뿐이다. 안 그러면 "안 눌리는 데"가 생긴다.
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 78,
        height: 70,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // 모루 — 맞을 때 살짝 눌린다.
            Transform.translate(
              offset: Offset(0, spark * 2),
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color.lerp(
                    const Color(0x22000000),
                    const Color(0x55FFD54F),
                    spark,
                  ),
                  border: Border.all(
                    color: Color.lerp(const Color(0x55FFD54F), _honey, spark)!,
                    width: 1.2,
                  ),
                ),
                child: gameImageChain(
                  const [
                    // 망치가 **안 얹힌** 모루가 있으면 그걸 쓴다. 얹힌 그림
                    // 위에서 망치를 휘두르면 망치가 두 개로 보인다.
                    'assets/images/ui/anvil_base.webp',
                    'assets/images/ui/anvil.webp',
                  ],
                  size: 54,
                  fallback: const Icon(
                    Icons.hardware_rounded,
                    color: _honey,
                    size: 52,
                  ),
                ),
              ),
            ),
            // 불꽃 — 맞은 자리에서 튄다.
            if (spark > 0)
              Positioned(
                top: 12,
                child: Opacity(
                  opacity: spark,
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    size: 14 + spark * 10,
                    color: const Color(0xFFFFF59D),
                  ),
                ),
              ),
            // 망치 — 오른쪽 위에서 내리친다. 회전축을 자루 끝에 둬야
            // 휘두르는 것처럼 보인다(가운데로 두면 빙글 돈다).
            //
            // ⚠️ 폴백 그림(`anvil.webp`)에는 망치가 이미 얹혀 있다. 그때는
            // 이 망치를 **안 그린다** — 두 개로 보이는 게 더 나쁘다.
            if (_hasHammerArt)
              Positioned(
                right: 12,
                top: 8,
                child: Transform.rotate(
                  angle: _angle,
                  // 축은 **자루 끝**(그림의 오른쪽 아래). 가운데로 두면
                  // 휘두르는 게 아니라 빙글 돈다.
                  alignment: Alignment.bottomRight,
                  child: Image.asset(
                    _kHammer,
                    width: 30,
                    height: 30,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 비교 창의 한쪽 — 그림 · 이름 · 능력치를 세로로 쌓는다.
class _CompareSide extends StatelessWidget {
  const _CompareSide({
    required this.label,
    required this.item,
    required this.config,
    required this.locale,
    this.compare,
    this.highlight = false,
  });

  final String label;
  final EquipItem? item;
  final ItemConfig config;
  final String locale;
  final EquipItem? compare;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final color = item == null
        ? const Color(0x33FFFFFF)
        : tierColor(config, item!.tier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: highlight ? _honey : const Color(0x99FFFFFF),
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              // 등급색을 여기서도 깔아 준다 — 칸에서 보던 색과 같아야 한다.
              gradient: item == null
                  ? null
                  : LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        color.withValues(alpha: 0.34),
                        color.withValues(alpha: 0.10),
                      ],
                    ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color, width: item == null ? 1 : 1.6),
            ),
            child: item == null
                ? const SizedBox(width: 56, height: 56)
                : itemImage(item!, size: 56),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          item == null ? l.charEmptySlot : itemName(config, l, locale, item!),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: item == null ? const Color(0x66FFFFFF) : color,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        if (item != null)
          ItemOptionList(
            item: item!,
            config: config,
            compare: compare,
            dense: true,
          ),
      ],
    );
  }
}

/// 제련 결과 — **지금 낀 것과 나란히**. 가방이 없으니 여기서 정한다.
///
/// 교체나 버리기를 **눌렀을 때만** true. 바깥을 눌러 닫으면 false 라서
/// 호출부가 모루에 그대로 남겨 둘 수 있다.
Future<bool> showForgeResult(
  BuildContext context,
  WidgetRef ref,
  EquipItem item,
) async {
  final l = AppLocalizations.of(context);
  final locale = Localizations.localeOf(context).languageCode;
  final items = ref.read(gameDataProvider).value?.itemConfig;
  if (items == null) return false;
  final cur = ref
      .read(saveControllerProvider)
      .requireValue
      .equippedItems[item.slot];

  final done = await showGameDialog<bool>(
    context,
    title: itemName(items, l, locale, item),
    iconWidget: itemImage(item, size: 40),
    // **왼쪽 = 지금 낀 것, 오른쪽 = 새로 뽑은 것.** 위아래로 쌓으면 두 값을
    // 번갈아 보느라 눈이 왕복한다 — 나란히 두어야 한 줄씩 바로 비교된다.
    content: SizedBox(
      width: double.maxFinite,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _CompareSide(
              label: l.forgeCurrent,
              item: cur,
              config: items,
              locale: locale,
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.arrow_forward_rounded,
            size: 18,
            color: Color(0x66FFFFFF),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _CompareSide(
              label: l.forgeResultNew,
              item: item,
              config: items,
              locale: locale,
              compare: cur,
              highlight: true,
            ),
          ),
        ],
      ),
    ),
    actions: [
      gameDialogButton(
        l.forgeResultDrop,
        () => Navigator.pop(context, true),
        primary: false,
      ),
      gameDialogButton(l.forgeResultKeep, () {
        ref.read(saveControllerProvider.notifier).equipItem(item);
        Navigator.pop(context, true);
      }),
    ],
  );
  return done ?? false;
}

/// 제련 필터 — **원하는 능력치**. 하나라도 붙은 것만 모루에 쌓는다.
///
/// 필터가 비어 있으면 전부 쌓는다. 10칸이 금방 차서 자동이 멈추기 때문에,
/// 오래 돌리려면 걸러 내야 한다.
Future<void> showForgeFilter(BuildContext context, WidgetRef ref) async {
  final l = AppLocalizations.of(context);
  final ctrl = ref.read(saveControllerProvider.notifier);
  final save = ref.read(saveControllerProvider).requireValue;
  final want = {...save.autoForgeOptions};

  await showGameDialog<void>(
    context,
    title: l.forgeFilter,
    icon: Icons.tune_rounded,
    content: StatefulBuilder(
      builder: (context, setLocal) => SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l.forgeFilterHint,
              style: const TextStyle(color: Color(0x99FFFFFF), fontSize: 11.5),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 260,
              child: ListView(
                shrinkWrap: true,
                children: [
                  // ⚠️ `CheckboxListTile` 을 쓰면 `dense` 여도 최소 높이가
                  // 48px 이라(터치 타깃 규격) 15줄이 세로로 훌쩍 벌어진다
                  // (2026-08-30 지적). 목록이 길어 한눈에 훑어야 하는
                  // 화면이라, 직접 그려 줄 간격을 좁힌다.
                  for (final k in ItemOptionKind.values)
                    InkWell(
                      onTap: () => setLocal(() {
                        want.contains(k) ? want.remove(k) : want.add(k);
                      }),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 22,
                              height: 22,
                              child: Checkbox(
                                value: want.contains(k),
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                onChanged: (v) => setLocal(() {
                                  v == true ? want.add(k) : want.remove(k);
                                }),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                optionLabel(l, k),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    actions: [
      gameDialogButton(l.actionClose, () {
        ctrl.setAutoForge(options: want, stopOnHit: save.autoForgeStopOnHit);
        Navigator.pop(context);
      }),
    ],
  );
}

/// 공방 등급 — 현재/다음 확률과 **골드 10칸** 업그레이드.
Future<void> showForgeGrade(BuildContext context, WidgetRef ref) async {
  final data = ref.read(gameDataProvider).value;
  final forge = data?.forgeConfig;
  final items = data?.itemConfig;
  if (forge == null || items == null) return;

  await showGameDialog<void>(
    context,
    title: AppLocalizations.of(context).forgeGradeButton,
    icon: Icons.workspace_premium_rounded,
    content: _GradeBody(forge: forge, items: items),
    actions: [
      gameDialogButton(
        AppLocalizations.of(context).actionClose,
        () => Navigator.pop(context),
      ),
    ],
  );
}

class _GradeBody extends ConsumerStatefulWidget {
  const _GradeBody({required this.forge, required this.items});
  final ForgeConfig forge;
  final ItemConfig items;

  @override
  ConsumerState<_GradeBody> createState() => _GradeBodyState();
}

class _GradeBodyState extends ConsumerState<_GradeBody> {
  /// 업그레이드 남은 시간을 **초 단위로 갱신**하기 위한 티커.
  ///
  /// 예전엔 남은 시간이 아예 없었다 — "업그레이드 중"만 떠서 얼마나 더
  /// 기다려야 하는지 알 수 없었고, 즉시완료 젤리값만 보였다. 시간을 넣으려면
  /// 다시 그려야 하므로 상태 위젯이 필요하다(세이브가 안 바뀌면 리빌드가 없다).
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  ForgeConfig get forge => widget.forge;
  ItemConfig get items => widget.items;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final save = ref.watch(saveControllerProvider).requireValue;
    final ctrl = ref.read(saveControllerProvider.notifier);
    final now = ref.read(clockProvider).now().toUtc();
    final maxed = save.forgeLevel >= forge.maxLevel;
    final upAt = save.forgeUpAt;

    final cur = forge.tierWeights(save.forgeLevel, items.tierCount);
    final next = forge.tierWeights(save.forgeLevel + 1, items.tierCount);

    return SizedBox(
      width: double.maxFinite,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.forgeLevel(save.forgeLevel + 1),
            style: const TextStyle(
              color: _honey,
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          // **전체 등급을 다 보여준다.** 지금 나오는 것만 추리면 "위에 뭐가
          // 남았는지"가 안 보여서 올릴 이유가 흐려진다. 0% 도 0.0% 로 적는다.
          for (var i = 0; i < items.tierCount; i++)
            _oddsRow(locale, i, cur[i], next[i], maxed),
          const SizedBox(height: 12),
          if (maxed)
            Text(
              l.forgeMaxLevel,
              style: const TextStyle(color: Color(0x99FFFFFF)),
            )
          else if (upAt != null) ...[
            Row(
              children: [
                const Icon(
                  Icons.timer_outlined,
                  size: 14,
                  color: Color(0x99FFFFFF),
                ),
                const SizedBox(width: 4),
                Text(
                  l.forgeUpgrading,
                  style: const TextStyle(
                    color: Color(0x99FFFFFF),
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                // 남은 시간 — 1초마다 갱신된다(위 `_tick`).
                Text(
                  now.isAfter(upAt)
                      ? l.forgeReady
                      : remainLabel(l, upAt.difference(now)),
                  style: TextStyle(
                    color: now.isAfter(upAt) ? _honey : Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (now.isAfter(upAt))
              _wide(l.forgeClaim, () => ctrl.claimForgeUpgrade())
            else
              _wide(
                '${l.forgeRush} · ${forge.levelUpJelly(upAt.difference(now))}',
                () async {
                  if (!await ctrl.rushForgeUpgrade() && context.mounted) {
                    showCenterToast(context, l.notEnoughJelly);
                  }
                },
              ),
          ] else ...[
            Row(
              children: [
                for (var i = 0; i < forge.levelUpSteps; i++)
                  Expanded(
                    child: Container(
                      height: 9,
                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                      decoration: BoxDecoration(
                        color: i < save.forgeSteps
                            ? _honey
                            : const Color(0x22FFFFFF),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            _wide(
              '${l.forgeStep(save.forgeSteps, forge.levelUpSteps)} · '
              '${formatCompact(forge.levelUpStepGold(save.forgeLevel))}',
              () async {
                if (!await ctrl.payForgeStep() && context.mounted) {
                  showCenterToast(context, l.notEnoughGold);
                }
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _oddsRow(String locale, int i, double now, double next, bool maxed) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Row(
          children: [
            SizedBox(
              width: 54,
              child: Text(
                items.tier(i).name.resolve(locale),
                style: TextStyle(
                  color: tierColor(items, i),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            SizedBox(
              width: 48,
              child: Text(
                '${(now * 100).toStringAsFixed(1)}%',
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: now < 0.0005 ? const Color(0x55FFFFFF) : Colors.white,
                  fontSize: 11.5,
                ),
              ),
            ),
            if (!maxed) ...[
              const Icon(
                Icons.arrow_right_rounded,
                size: 16,
                color: Color(0x66FFFFFF),
              ),
              SizedBox(
                width: 48,
                child: Text(
                  '${(next * 100).toStringAsFixed(1)}%',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: next > now
                        ? const Color(0xFF9CCC65)
                        : const Color(0x66FFFFFF),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      );

  Widget _wide(String text, VoidCallback onTap) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0x33FFD54F),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _honey),
      ),
      child: Text(
        text,
        style: const TextStyle(color: _honey, fontWeight: FontWeight.w900),
      ),
    ),
  );
}

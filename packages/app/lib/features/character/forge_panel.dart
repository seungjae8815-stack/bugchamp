import 'dart:async';
import 'dart:math' as math;

import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:core_save/core_save.dart' show kMaxForgeStack, SaveGame;
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

  /// 가속 남은 시간을 **1초마다** 다시 그리는 티커.
  ///
  /// 망치질 애니메이션은 자기 박자로만 setState 하므로, 가속이 끝나가도
  /// 숫자가 멈춰 있었다(2026-09-09 지적). 남은 시간은 시간이 지나면 줄어야
  /// 하는 값이라 **자기 티커**가 필요하다.
  Timer? _rushTick;

  /// 한 번 뽑는 데 걸리는 시간 = 망치질 한 바퀴(§6 — `forge.json → hammerSeconds`).
  ///
  /// 손으로 눌러도 **같은 시간**이 걸린다. 즉시 뽑히면 손가락만 빠르면 화석을
  /// 몇 초 만에 다 태울 수 있어서, 뽑는 재미도 머무는 시간도 사라진다.
  Duration _cycle(ForgeConfig f) {
    final save = ref.read(saveControllerProvider).requireValue;
    final until = save.forgeRushUntil;
    final now = ref.read(clockProvider).now().toUtc();
    // 가속 중이면 간격이 절반이다. 애니메이션이 박자를 잡으므로 여기만 바꾸면
    // 뽑는 속도까지 같이 빨라진다.
    final rushing = until != null && until.isAfter(now);
    final sec = rushing ? f.hammerSeconds / 2 : f.hammerSeconds;
    return Duration(milliseconds: (sec * 1000).round());
  }

  /// 가속을 사기 전에 **무엇을 사는지** 보여준다.
  ///
  /// 값과 지속시간이 버튼에 안 적혀 있으면 눌러 보기 전엔 알 수 없다.
  Future<void> _confirmRush(
    AppLocalizations l,
    ForgeConfig forge,
    int left,
  ) async {
    final go = await showGameDialog<bool>(
      context,
      title: l.forgeRushTitle,
      icon: Icons.fast_forward_rounded,
      subtitle: left > 0 ? l.forgeRushLeft(left) : null,
      content: Text(
        l.forgeRushBody(forge.rushJelly, forge.rushSeconds),
        style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 12.5),
      ),
      actions: [
        gameDialogButton(
          l.actionClose,
          () => Navigator.pop(context, false),
          primary: false,
        ),
        gameDialogButton(l.forgeRush, () => Navigator.pop(context, true)),
      ],
    );
    if (go != true || !mounted) return;
    await _spendJelly(
      () => ref.read(saveControllerProvider.notifier).rushForgeHammer(),
    );
  }

  /// 젤리 액션 공통 — 실패하면 이유를 말한다.
  ///
  /// ⚠️ 콜백을 위젯 트리 안에 인라인으로 두면 `context` 를 async 경계 너머로
  /// 들고 가게 되어 분석기가 막는다. State 메서드로 빼야 `mounted` 가 이
  /// State 의 것으로 읽힌다.
  Future<void> _spendJelly(Future<bool> Function() run) async {
    final ok = await run();
    if (!mounted) return;
    if (!ok) {
      showCenterToast(context, AppLocalizations.of(context).forgeNoJelly);
    }
    setState(() {});
  }

  /// 가속 남은 초(없으면 0). 버튼 라벨과 재빌드 판단에 쓴다.
  int _rushLeft(SaveGame save) {
    final until = save.forgeRushUntil;
    if (until == null) return 0;
    final left = until.difference(ref.read(clockProvider).now().toUtc());
    return left.isNegative ? 0 : left.inSeconds;
  }

  /// 지금 모루 칸 수(기본 + 젤리 확장, 설정 상한까지).
  int _stackCap(SaveGame save, ForgeConfig f) {
    final cap = kMaxForgeStack + save.forgeStackBought * f.stackExpandStep;
    return cap > f.stackExpandMax ? f.stackExpandMax : cap;
  }

  /// 망치질 한 번에 뽑는 개수 — **진행한 만큼 빨라진다**(§6, `forge.json`).
  ///
  /// 챕터가 곧 개수이고, 회차를 한 번이라도 넘겼으면 처음부터 상한이다.
  /// 회차 전환은 스테이지를 1로 되돌리므로, 챕터만 보면 2회차 시작이 1회차
  /// 끝보다 느려진다 — 넘어갈 이유를 없애면 안 된다.
  /// 고른 값이 있으면 그걸 쓰되 **해금 상한으로 잘린다**(0 = 상한 그대로).
  int _strikes(ForgeConfig f, SaveGame save, RoadmapConfig? roadmap) =>
      f.effectiveStrikes(
        difficultyTier: save.difficultyTier,
        chapter: _chapter(save, roadmap),
        chosen: save.autoForgeStrikes,
      );

  /// 지금 해금된 **최대** 개수 — 선택 시트의 잠금 경계.
  int _strikeMax(ForgeConfig f, SaveGame save, RoadmapConfig? roadmap) =>
      f.autoStrikes(
        difficultyTier: save.difficultyTier,
        chapter: _chapter(save, roadmap),
      );

  int _chapter(SaveGame save, RoadmapConfig? roadmap) =>
      roadmap?.stageLabel(save.stageNumber)?.world ?? 1;

  /// 망치가 마지막으로 내리친 순간 — 여기서 [_strikes] 개가 나온다.
  Future<void> _onStrikeDone() async {
    if (_busy) return;
    _busy = true;
    final data = ref.read(gameDataProvider).value;
    final forge = data?.forgeConfig;
    final save = ref.read(saveControllerProvider).requireValue;
    if (forge == null) {
      _busy = false;
      return;
    }
    final full = save.forgeStack.length >= _stackCap(save, forge);
    final n = _strikes(forge, save, data?.roadmapConfig);
    final r = await ref.read(saveControllerProvider.notifier).forgeMany(n);
    if (!mounted) return;
    _busy = false;
    final l = AppLocalizations.of(context);
    if (r.forged == 0) {
      // 화석이 떨어졌거나 모루가 가득 찼다 — 자동이면 여기서 멈춘다.
      setState(() => _autoOn = false);
      showCenterToast(context, full ? l.forgeStackFull : l.forgeNoFossil);
      return;
    }
    // 걸러진 것도 화석은 줄었으니 다시 그린다.
    setState(() {});
    if (r.kept == 0 && !_autoOn) {
      // 손으로 두드렸는데 아무것도 안 쌓이면 고장으로 보인다 — 이유를 말한다.
      showCenterToast(context, l.forgeFiltered);
    }
    // 배수로 뽑다 보면 도중에 모루가 찬다. 자동이면 여기서 멈춰야 한다 —
    // 안 그러면 다음 망치질이 0개를 뽑고 그제서야 멈춰 한 박자가 비어 보인다.
    if (r.full && _autoOn) {
      setState(() => _autoOn = false);
      showCenterToast(context, l.forgeStackFull);
      return;
    }
    // 원하는 걸 찾았다 — 자동을 세운다. 안 세우면 다음 망치질이 곧바로
    // 돌아 화석을 계속 태우고, 찾았다는 사실도 흘러가 버린다.
    if (r.hit && _autoOn) {
      setState(() => _autoOn = false);
      showCenterToast(context, l.forgeStoppedOnHit);
    }
  }

  /// 자동 제련 — 망치가 **쉬지 않고** 돌면서 한 바퀴마다 하나씩 쌓는다.
  ///
  /// 예전엔 자동으로 갈아 끼웠지만, 그러면 뭘 뽑았는지 못 보고 지나간다.
  /// 지금은 쌓아 두고 **본인이 하나씩 열어 본다**.
  ///
  /// 좋은 게 나왔다고 **중간에 멈추지 않는다.** 어차피 쌓아 두고 나중에 보는
  /// 구조라 멈출 이유가 없다. 화석이 떨어지거나 10칸이 다 차면 멈춘다.
  /// 켜기 전에 **몇 개씩 뽑을지** 먼저 고른다. 끌 때는 곧바로 멈춘다 —
  /// 멈추려고 눌렀는데 창이 뜨면 그 사이에도 망치가 계속 돈다.
  Future<void> _toggleAuto() async {
    if (_autoOn) {
      setState(() => _autoOn = false);
      return;
    }
    final data = ref.read(gameDataProvider).value;
    final forge = data?.forgeConfig;
    if (forge == null) return;
    final save = ref.read(saveControllerProvider).requireValue;
    final ok = await showForgeStrikePick(
      context,
      ref,
      max: _strikeMax(forge, save, data?.roadmapConfig),
      cap: forge.autoStrikeMax,
    );
    if (!mounted || !ok) return;
    setState(() => _autoOn = true);
  }

  /// 쌓인 것 중 **맨 위 하나**를 열어 본다.
  ///
  /// ⚠️ **먼저 빼내면 안 된다.** 예전엔 빼고 나서 창을 띄웠는데, 바깥을 눌러
  /// 창을 닫으면 교체도 버리기도 안 했는데 아이템이 사라졌다.
  /// 교체/버리기를 **누른 뒤에만** 모루에서 없앤다.
  Future<void> _openTop() async {
    final stack = ref.read(saveControllerProvider).requireValue.forgeStack;
    if (stack.isEmpty) return;
    // 하나를 처리하면 **다음 것이 바로 뜬다.** 예전엔 매번 모루를 다시
    // 눌러야 했다 — 10칸을 비우려면 10번을 더 눌러야 하는 셈이었다
    // (2026-09-09 지적).
    while (mounted && await _openOne()) {
      if (!mounted) return;
      setState(() {});
    }
  }

  /// 맨 위 하나를 열어 처리한다. 다음 것을 이어서 열어도 되면 true.
  ///
  /// 루프에서 분리한 이유: `context` 를 **await 전에** 써야 분석기가 통과한다.
  /// 루프 안에 두면 두 번째 회차의 context 는 async 경계를 넘은 것이 된다.
  Future<bool> _openOne() async {
    final top = ref.read(saveControllerProvider).requireValue.forgeStack;
    if (top.isEmpty) return false;
    final done = await showForgeResult(context, ref, top.last);
    if (!done) return false; // 바깥을 눌러 닫았다 — 여기서 멈춘다.
    await ref.read(saveControllerProvider.notifier).takeForgeItem();
    return true;
  }

  @override
  void initState() {
    super.initState();
    _rushTick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      // 가속 중일 때만 다시 그린다 — 평소엔 공짜 리빌드를 만들지 않는다.
      final save = ref.read(saveControllerProvider).value;
      if (save != null && _rushLeft(save) > 0) setState(() {});
    });
  }

  @override
  void dispose() {
    _rushTick?.cancel();
    super.dispose();
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
    final rushLeft = _rushLeft(save);
    final cap = _stackCap(save, forge);
    final strikes = _strikes(forge, save, data?.roadmapConfig);

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
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      l.forgeHammer,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                    // 배수가 화면에 없으면 "왜 갑자기 여러 개가 나오지?"가
                    // 된다. 한 번에 몇 개인지는 눌러 보기 전에 보여야 한다.
                    if (strikes > 1) ...[
                      const SizedBox(width: 4),
                      Text(
                        l.forgeStrikes(strikes),
                        style: const TextStyle(
                          color: _honey,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
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
                    const SizedBox(width: 8),
                    // 모루가 몇 칸 남았는지 — 확장을 살지 판단하는 근거다.
                    Text(
                      l.forgeStackCount(save.forgeStack.length, cap),
                      style: const TextStyle(
                        color: Color(0x99FFFFFF),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                // 젤리 소비처 두 개. 제련은 유저가 가장 오래 붙잡는 무한
                // 루프인데 젤리 통로가 하나도 없었다(2026-09-09).
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _JellyChip(
                      icon: Icons.add_box_rounded,
                      // 다 늘렸으면 **값을 지우고 "확장 최대"** 라고 쓴다.
                      // 살 수 없는 값(450)이 떠 있으면 못 사는 게 아니라
                      // 젤리가 모자란 것으로 읽힌다(2026-09-09 지적).
                      label: cap >= forge.stackExpandMax
                          ? l.forgeExpandMax
                          : l.forgeExpand,
                      cost: cap >= forge.stackExpandMax
                          ? null
                          : forge.stackExpandCost(save.forgeStackBought),
                      enabled: cap < forge.stackExpandMax,
                      onTap: () => _spendJelly(
                        () => ref
                            .read(saveControllerProvider.notifier)
                            .expandForgeStack(),
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
              // 등급 필터만 걸어 둔 경우에도 켜진 것으로 보여야 한다 —
              // 능력치 개수만 세면 "필터를 걸었는데 꺼져 보인다"가 된다.
              sub: save.autoForgeOptions.isEmpty
                  ? (save.autoForgeMinTier > 0
                        ? items
                              .tier(save.autoForgeMinTier)
                              .name
                              .resolve(l.localeName)
                        : null)
                  : '${save.autoForgeOptions.length}',
              on: save.autoForgeOptions.isNotEmpty || save.autoForgeMinTier > 0,
              onTap: () async {
                await showForgeFilter(context, ref);
                if (mounted) setState(() {});
              },
            ),
            const SizedBox(height: 6),
            // 망치질 가속 — **젤리 소비처**. 순수 시간 절약이라 P2W 위험이 없다.
            // 남은 시간을 라벨에 띄워, 켜져 있는 동안 다시 안 사게 한다.
            _SquareButton(
              icon: Icons.fast_forward_rounded,
              label: l.forgeRush,
              sub: rushLeft > 0 ? '$rushLeft' : '${forge.rushJelly}',
              on: rushLeft > 0,
              onTap: () => _confirmRush(l, forge, rushLeft),
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

/// 젤리를 쓰는 작은 칩(재굴림·칸 확장).
///
/// 값을 **항상 보여준다** — 눌러 봐야 값을 아는 버튼은 안 눌린다.
class _JellyChip extends StatelessWidget {
  const _JellyChip({
    required this.icon,
    required this.label,
    required this.enabled,
    this.cost,
    required this.onTap,
  });

  final IconData icon;
  final String label;

  /// 값. **null 이면 값을 안 그린다** — 다 사서 살 수 없는 상태에서 값이
  /// 떠 있으면 "못 사는 것"이 아니라 "젤리가 모자란 것"으로 읽힌다.
  final int? cost;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = enabled ? const Color(0xFFCE93D8) : const Color(0x55FFFFFF);
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: enabled ? const Color(0x337E57C2) : const Color(0x22000000),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: enabled ? const Color(0x887E57C2) : const Color(0x22FFFFFF),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(
                color: fg,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (cost != null) ...[
              const SizedBox(width: 4),
              materialImage(
                MaterialKind.jelly,
                size: 11,
                fallback: Icon(Icons.bubble_chart, size: 10, color: fg),
              ),
              const SizedBox(width: 2),
              Text(
                '$cost',
                style: TextStyle(
                  color: fg,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ],
        ),
      ),
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
    if (widget.cycle != old.cycle) {
      _c.duration = widget.cycle;
      // ⚠️ `duration` 만 바꾸면 **이미 돌고 있는 repeat 에는 안 먹는다** —
      // 자동을 켠 채 가속을 사면 아무 일도 안 일어났다(2026-09-09 지적).
      // 돌고 있으면 새 주기로 다시 시작한다.
      if (widget.auto && _c.isAnimating) {
        _rung = 0;
        _prev = 0;
        _c.repeat();
      }
    }
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
/// 비교 카드 하나 — **가로로 눕힌다**(그림 왼쪽, 이름·옵션 오른쪽).
///
/// 예전 `_CompareSide` 는 세로 카드를 좌우 2열로 놓았는데, 한 열이 113px 뿐이라
/// 옵션 이름이 잘리고 재굴림 버튼도 못 들어갔다(2026-09-10 지적).
/// 위아래로 쌓고 각 카드를 눕히면 **폭을 다 쓴다**.
class _StackSide extends StatelessWidget {
  const _StackSide({
    required this.label,
    required this.item,
    required this.config,
    required this.locale,
    this.compare,
    this.highlight = false,
    this.rerollCost,
    this.onReroll,
  });

  final String label;
  final EquipItem? item;
  final ItemConfig config;
  final String locale;
  final EquipItem? compare;

  /// 새로 뽑은 쪽인가 — 테두리·이름표를 꿀색으로 세워 **낀 것과 확실히 가른다**.
  final bool highlight;
  final int? rerollCost;
  final void Function(int index)? onReroll;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final color = item == null
        ? const Color(0x33FFFFFF)
        : tierColor(config, item!.tier);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        // 새로 뽑은 쪽만 바탕을 옅게 깔고 테두리를 굵게 — 두 칸이 같은 모양이면
        // 이름표를 읽기 전에는 어느 쪽이 어느 쪽인지 모른다.
        color: highlight ? const Color(0x22EBA52F) : const Color(0x14FFFFFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: highlight ? _honey : const Color(0x33FFFFFF),
          width: highlight ? 1.6 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: highlight ? _honey : const Color(0x33FFFFFF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: highlight ? const Color(0xFF2A1B08) : Colors.white,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
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
                  border: Border.all(
                    color: color,
                    width: item == null ? 1 : 1.6,
                  ),
                ),
                child: item == null
                    ? const SizedBox(width: 44, height: 44)
                    : itemImage(item!, size: 44),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item == null
                          ? l.charEmptySlot
                          : itemName(config, l, locale, item!),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: item == null ? const Color(0x66FFFFFF) : color,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    if (item != null)
                      ItemOptionList(
                        item: item!,
                        config: config,
                        compare: compare,
                        rerollCost: rerollCost,
                        onReroll: onReroll,
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
  final data = ref.read(gameDataProvider).value;
  final items = data?.itemConfig;
  final forge = data?.forgeConfig;
  if (items == null) return false;
  // 낀 것도 이 창에서 굴릴 수 있다 — 그래서 **var** 다.
  var cur = ref
      .read(saveControllerProvider)
      .requireValue
      .equippedItems[item.slot];
  // 재굴림하면 이 창의 오른쪽이 바뀐다 — 창을 닫았다 열지 않고 여기서 갱신한다.
  var shown = item;

  final done = await showGameDialog<bool>(
    context,
    title: itemName(items, l, locale, item),
    iconWidget: itemImage(item, size: 40),
    // **위 = 지금 낀 것, 아래 = 새로 뽑은 것.** 예전엔 좌우 2열이었는데,
    // 한 쪽이 113px 뿐이라 옵션 이름이 잘리고 재굴림 버튼도 못 넣었다
    // (2026-09-10 지적). 세로로 쌓으면 폭을 다 쓰므로 둘 다 해결된다.
    content: StatefulBuilder(
      builder: (ctx, setLocal) => SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StackSide(
              label: l.forgeCurrent,
              item: cur,
              config: items,
              locale: locale,
              // 낀 쪽에도 재굴림 버튼을 둔다. 기능이기도 하지만, 한쪽에만
              // 버튼이 있으면 **두 칸의 옵션 줄이 서로 어긋나** 비교가
              // 안 된다(2026-09-10 지적).
              rerollCost: cur == null ? null : forge?.rerollJelly,
              onReroll: (forge == null || cur == null)
                  ? null
                  : (i) async {
                      final slot = cur!.slot;
                      final ok = await ref
                          .read(saveControllerProvider.notifier)
                          .rerollOption(index: i, equipped: true, slot: slot);
                      if (!ctx.mounted) return;
                      if (!ok) {
                        showCenterToast(ctx, l.forgeNoJelly);
                        return;
                      }
                      final now = ref
                          .read(saveControllerProvider)
                          .requireValue
                          .equippedItems[slot];
                      setLocal(() => cur = now);
                    },
            ),
            // 두 칸 사이에 **아래 화살표**. 무엇이 무엇으로 바뀌는지가
            // 이름표만으로는 덜 읽힌다.
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Icon(
                Icons.arrow_downward_rounded,
                size: 16,
                color: Color(0x66FFFFFF),
              ),
            ),
            _StackSide(
              label: l.forgeResultNew,
              item: shown,
              config: items,
              locale: locale,
              compare: cur,
              highlight: true,
              rerollCost: forge?.rerollJelly,
              onReroll: forge == null
                  ? null
                  : (i) async {
                      final ok = await ref
                          .read(saveControllerProvider.notifier)
                          .rerollOption(index: i);
                      if (!ctx.mounted) return;
                      if (!ok) {
                        showCenterToast(ctx, l.forgeNoJelly);
                        return;
                      }
                      final stack = ref
                          .read(saveControllerProvider)
                          .requireValue
                          .forgeStack;
                      if (stack.isNotEmpty) setLocal(() => shown = stack.last);
                    },
            ),
            const SizedBox(height: 4),
            Text(
              l.forgeRerollHint,
              style: const TextStyle(color: Color(0x88FFFFFF), fontSize: 10.5),
            ),
          ],
        ),
      ),
    ),
    actions: [
      gameDialogButton(
        l.forgeResultDrop,
        () => Navigator.pop(context, true),
        primary: false,
      ),
      gameDialogButton(l.forgeResultKeep, () {
        // ⚠️ 굴린 뒤라면 **굴린 것**을 껴야 한다.
        ref.read(saveControllerProvider.notifier).equipItem(shown);
        Navigator.pop(context, true);
      }),
    ],
  );
  return done ?? false;
}

/// 망치질 개수 고르기 — 자동을 켜기 전에 뜬다.
///
/// 예전엔 개수가 **챕터에서 자동으로 정해져** 유저가 손댈 수 없었다. 그래서
/// 두 가지가 안 보였다: 지금 몇 개씩 나오는지 고를 수 없다는 것과, **더 열려면
/// 무엇을 해야 하는지**. 잠긴 항목을 목록에서 지우지 않고 `챕터 N 필요`로
/// 남겨 두는 이유다 — 안 보이면 열린 게 전부인 줄 안다.
///
/// [max] = 지금 해금된 최대, [cap] = 영원한 상한(`forge.json → autoStrikeMax`).
Future<bool> showForgeStrikePick(
  BuildContext context,
  WidgetRef ref, {
  required int max,
  required int cap,
}) async {
  final l = AppLocalizations.of(context);
  final ctrl = ref.read(saveControllerProvider.notifier);
  final save = ref.read(saveControllerProvider).requireValue;
  var chosen = save.autoForgeStrikes;
  var stopOnHit = save.autoForgeStopOnHit;
  // 멈출 기준이 없으면 체크해도 아무 일이 없다 — 켤 수 있게 두면 "켰는데
  // 안 멈춘다"가 된다. 필터를 먼저 걸라고 말해 준다.
  final hasFilter =
      save.autoForgeOptions.isNotEmpty || save.autoForgeMinTier > 0;

  final done = await showGameDialog<bool>(
    context,
    title: l.forgeStrikePick,
    icon: Icons.hardware_outlined,
    content: StatefulBuilder(
      builder: (context, setLocal) => SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.forgeStrikePickHint,
              style: const TextStyle(color: Color(0x99FFFFFF), fontSize: 11.5),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: const Color(0x22000000),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0x33FFFFFF)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: chosen > max ? 0 : chosen,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF2A1B08),
                  iconEnabledColor: _honey,
                  // ⚠️ 안 자르면 항목 11개를 **한 번에 다 펼쳐서** 다이얼로그
                  // 위로 화면 밖까지 넘어간다(2026-09-08 제보). 네 줄쯤만
                  // 보이게 잘라 나머지는 스크롤로 넘긴다.
                  menuMaxHeight: 220,
                  itemHeight: 48,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  items: [
                    // `최대` 는 숫자를 고정하지 않는다 — 챕터를 깨면 따라
                    // 오른다. 이걸 안 두면 한 번 고른 뒤로는 상한이 올라도
                    // 그대로라 "챕터를 깼는데 안 빨라진다"가 된다.
                    DropdownMenuItem(
                      value: 0,
                      child: _strikeRow(
                        '${l.forgeStrikeAuto} (x$max)',
                        l.forgeStrikeAutoHint,
                        false,
                      ),
                    ),
                    for (var n = 1; n <= cap; n++)
                      DropdownMenuItem(
                        value: n,
                        // 잠긴 건 고를 수 없게 두되 **목록에는 남긴다** —
                        // 지우면 무엇을 깨야 열리는지 알 방법이 없다.
                        enabled: n <= max,
                        child: _strikeRow(
                          'x$n',
                          n > max ? l.forgeStrikeLocked(n) : null,
                          n > max,
                        ),
                      ),
                  ],
                  onChanged: (v) => setLocal(() => chosen = v ?? 0),
                ),
              ),
            ),
            const SizedBox(height: 6),
            // 원하는 걸 뽑고도 남은 횟수만큼 화석을 더 태우면, 배수를 올릴수록
            // 손해가 커진다. 멈춤이 배수와 **한 세트**인 이유다.
            InkWell(
              onTap: hasFilter
                  ? () => setLocal(() => stopOnHit = !stopOnHit)
                  : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: Checkbox(
                        value: stopOnHit && hasFilter,
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        onChanged: hasFilter
                            ? (v) => setLocal(() => stopOnHit = v == true)
                            : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.forgeStopOnHit,
                            style: TextStyle(
                              color: hasFilter
                                  ? Colors.white
                                  : const Color(0x66FFFFFF),
                              fontSize: 12.5,
                            ),
                          ),
                          Text(
                            hasFilter
                                ? l.forgeStopOnHitHint
                                : l.forgeStopOnHitNoFilter,
                            style: const TextStyle(
                              color: Color(0x99FFFFFF),
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    actions: [
      gameDialogButton(l.actionClose, () => Navigator.pop(context, false)),
      // 시작이 곧 저장이다. 닫기로 나가면 아무것도 안 바뀐다 — 고르다 말고
      // 나갔는데 설정이 바뀌어 있으면 그게 더 놀랍다.
      gameDialogButton(l.forgeStrikeStart, () {
        ctrl.setAutoForge(
          strikes: chosen > max ? 0 : chosen,
          stopOnHit: stopOnHit,
        );
        Navigator.pop(context, true);
      }),
    ],
  );
  return done ?? false;
}

/// 드롭다운 한 줄 — `x3` 옆에 조건/설명을 흐리게 붙인다.
Widget _strikeRow(String label, String? sub, bool locked) => Row(
  children: [
    if (locked) ...[
      const Icon(
        Icons.lock_outline_rounded,
        size: 12,
        color: Color(0x66FFFFFF),
      ),
      const SizedBox(width: 3),
    ],
    Text(
      label,
      style: TextStyle(
        color: locked ? const Color(0x66FFFFFF) : Colors.white,
        fontSize: 13,
        fontWeight: FontWeight.w800,
      ),
    ),
    if (sub != null) ...[
      const SizedBox(width: 6),
      Flexible(
        child: Text(
          sub,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Color(0x77FFFFFF), fontSize: 10),
        ),
      ),
    ],
  ],
);

/// 제련 필터 — **원하는 능력치**. 하나라도 붙은 것만 모루에 쌓는다.
///
/// 필터가 비어 있으면 전부 쌓는다. 10칸이 금방 차서 자동이 멈추기 때문에,
/// 오래 돌리려면 걸러 내야 한다.
Future<void> showForgeFilter(BuildContext context, WidgetRef ref) async {
  final l = AppLocalizations.of(context);
  final ctrl = ref.read(saveControllerProvider.notifier);
  final save = ref.read(saveControllerProvider).requireValue;
  final items = ref.read(gameDataProvider).value?.itemConfig;
  final want = {...save.autoForgeOptions};
  var minTier = save.autoForgeMinTier;

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
            // ── 등급 축 ──
            //
            // 능력치만 있던 시절엔 원하는 옵션이 붙은 **풀잎**이 10칸을
            // 채웠다(2026-09-07 지적). 옵션은 맞는데 수치가 등급 배율(x1.0)에
            // 눌려 쓸모가 없다 — 거를 축이 없었던 것이다.
            //
            // 가로 스크롤 칩으로 둔다. 10등급을 세로로 늘어놓으면 능력치
            // 목록을 밀어내고, 어차피 **하나만 고르는** 축이다.
            if (items != null) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${l.forgeFilterGrade} · ${l.forgeFilterGradeHint}',
                  style: const TextStyle(
                    color: Color(0x99FFFFFF),
                    fontSize: 11.5,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              SizedBox(
                height: 30,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (var t = 0; t < items.tierCount; t++)
                      Padding(
                        padding: const EdgeInsets.only(right: 5),
                        child: _TierChip(
                          // 0 은 등급 이름이 아니라 **"전부"** 다. 풀잎을
                          // 골라도 결과가 같지만, 필터를 안 걸었다는 뜻이
                          // 이름으로 보여야 한다.
                          label: t == 0
                              ? l.forgeFilterGradeAll
                              : items.tier(t).name.resolve(l.localeName),
                          color: _tierColor(items.tier(t).color),
                          on: minTier == t,
                          onTap: () => setLocal(() => minTier = t),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
            // ── 능력치 축 ──
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${l.forgeFilterOption} · ${l.forgeFilterHint}',
                style: const TextStyle(
                  color: Color(0x99FFFFFF),
                  fontSize: 11.5,
                ),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 210,
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
        ctrl.setAutoForge(
          options: want,
          minTier: minTier,
          stopOnHit: save.autoForgeStopOnHit,
        );
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

/// 등급 색 문자열(ARGB 16진) → Color. 못 읽으면 회색.
Color _tierColor(String hex) =>
    Color(int.tryParse(hex, radix: 16) ?? 0xFF9E9E9E);

/// 최소 등급 칩 — 한 번에 **하나만** 켜진다(라디오).
class _TierChip extends StatelessWidget {
  const _TierChip({
    required this.label,
    required this.color,
    required this.on,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: on ? color.withValues(alpha: 0.28) : const Color(0x22000000),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: on ? color : const Color(0x33FFFFFF),
          width: on ? 1.6 : 1,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: on ? Colors.white : const Color(0xBBFFFFFF),
          fontWeight: on ? FontWeight.w900 : FontWeight.w700,
          fontSize: 12,
        ),
      ),
    ),
  );
}

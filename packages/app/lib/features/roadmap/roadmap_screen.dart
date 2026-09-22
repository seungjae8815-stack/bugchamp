// ⚠️ `as cm` 접두사가 필요하다 — core_models 의 오행 `Element` 와 Flutter
// 위젯 트리의 `Element` 가 이름이 겹쳐, 그냥 import 하면 모호해진다.
import 'package:core_models/core_models.dart' as cm;
import 'package:core_run/core_run.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../ui/labels.dart';
import '../../ui/tier_label.dart';

/// 로드맵에서 난이도를 골랐다(pop 값). 스테이지 번호(int)와 구분한다.
class RoadmapTierPick {
  const RoadmapTierPick(this.tier);
  final int tier;
}

/// 스테이지 로드맵 — **아래(하위) → 위(상위)** 로 올라가는 징검다리.
///
/// 칸 하나 = `nodeStep`(기본 10) 스테이지. 한 월드(100)는 **2줄 × 5칸**이고,
/// 줄마다 방향이 바뀌어(← →) 뱀처럼 이어진다. `x-100` 은 월드 보스(뿔 테두리),
/// 마지막 `10-100` 은 맨 위 중앙에 크게 = 최종 보스.
///
/// 탭하면 그 스테이지로 이동(pop 으로 스테이지 번호 반환). 아직 도달하지 못한
/// 칸은 잠겨 있다.
class RoadmapScreen extends StatefulWidget {
  const RoadmapScreen({
    super.key,
    required this.config,
    required this.runConfig,
    required this.highestStage,
    required this.liveStage,
    this.tier = 0,
    this.topTier = 0,
  });

  /// 가 본 가장 높은 난이도 — 여기까지 난이도 칩을 누를 수 있다.
  final int topTier;

  final RoadmapConfig config;

  /// 현재 회차(난이도) — 사냥터 구조에서 보스 아트 id 를 정한다.
  final int tier;

  /// 월드 크기(x-100 판정)·"1-30" 라벨 계산에 필요.
  final RunConfig runConfig;

  final int highestStage;
  final int liveStage;

  @override
  State<RoadmapScreen> createState() => _RoadmapScreenState();
}

/// 로드맵 칸 하나.
class _Node {
  const _Node({
    required this.stage,
    required this.chapter,
    required this.isWorldBoss,
  });

  /// 이 칸이 대표하는 **절대 스테이지**(= 구간의 마지막). 예: 1-30 → 30.
  final int stage;
  final RoadmapChapter chapter;

  /// 월드 마지막 칸(x-100) — 다음 월드로 가는 관문 보스.
  final bool isWorldBoss;
}

class _RoadmapScreenState extends State<RoadmapScreen> {
  final _scroll = ScrollController();
  bool _jumped = false;

  /// 한 줄에 놓는 칸 수(월드 10칸 = 2줄).
  static const _cols = 5;
  // 줄 간격. 보스 칸(68) + 라벨 알약(26) 이 아래 칸을 침범하지 않는 최소치.
  static const _cellH = 100.0;
  static const _cellSize = 56.0;
  // 뿔·가시 여백(_bossInsetFrac)을 빼고도 본체가 일반 칸(56)보다 커야 한다.
  // 가장 좁은 폰(360dp → 칸너비 72)에서도 이웃 칸을 침범하지 않는 상한.
  static const _bossCellSize = 68.0;
  static const _finalRowH = 168.0;
  static const _finalSize = 116.0;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// 전 월드의 칸을 스테이지 오름차순으로 편다.
  List<_Node> _buildNodes() {
    final step = widget.config.nodeStep;
    final worldSize = widget.runConfig.worldSize;
    final out = <_Node>[];
    for (final c in widget.config.chapters) {
      for (var s = c.startStage + step - 1; s <= c.endStage; s += step) {
        out.add(
          _Node(
            stage: s,
            chapter: c,
            isWorldBoss: worldSize > 0 && s % worldSize == 0,
          ),
        );
      }
    }
    return out;
  }

  /// "1-30" 표기. 월드 미설정이면 절대 스테이지 그대로.
  String _label(int stage) {
    final rc = widget.runConfig;
    if (rc.worldSize <= 0) return '$stage';
    return '${rc.worldOf(stage)}-${rc.stageInWorld(stage)}';
  }

  /// 칸의 중심 좌표(격자 원점 = 좌상단). [row] 는 **아래에서 0**.
  Offset _center(int row, int col, double width, double gridH) {
    final cellW = width / _cols;
    // 짝수 줄은 왼→오, 홀수 줄은 오→왼(뱀 모양) — 줄이 바뀔 때 세로로 이어진다.
    final c = row.isEven ? col : (_cols - 1 - col);
    return Offset(
      cellW * (c + 0.5),
      gridH - _cellH * (row + 0.5), // 아래가 하위 스테이지
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    // 사냥터 구조(2026-09-14 지시): **아래에서 위로 한 칸씩 점령**하는 세로
    // 목록. 예전 징검다리 격자는 칸이 56px 이라 보스 이름이 잘렸고, 11칸을
    // 뱀처럼 접어 놓으니 "어디까지 왔나"가 오히려 안 보였다.
    if (widget.runConfig.zoneMode) return _zoneList(context, l, locale);
    final all = _buildNodes();
    if (all.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(l.roadmapTitle)),
        body: Center(child: Text(l.comingSoon)),
      );
    }

    // 최종 보스는 격자에서 빼고 맨 위 중앙에 따로 그린다.
    final finalNode = all.last;
    final grid = all.sublist(0, all.length - 1);
    final rows = (grid.length / _cols).ceil();
    final gridH = rows * _cellH;

    return Scaffold(
      appBar: AppBar(title: Text(l.roadmapTitle)),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final totalH = gridH + _finalRowH;

          // 첫 프레임: 현재 위치가 화면 중앙에 오도록 스크롤.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_jumped || !_scroll.hasClients) return;
            _jumped = true;
            final idx = _currentIndex(all);
            final y = idx >= grid.length
                ? 0.0
                : _finalRowH +
                      _center(idx ~/ _cols, idx % _cols, width, gridH).dy;
            final target = y - constraints.maxHeight / 2;
            _scroll.jumpTo(target.clamp(0.0, _scroll.position.maxScrollExtent));
          });

          return SingleChildScrollView(
            controller: _scroll,
            // 시스템 내비게이션 바에 맨 아래 칸이 가리지 않게.
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewPaddingOf(context).bottom + 16,
            ),
            child: SizedBox(
              width: width,
              height: totalH,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.asset(
                      'assets/images/ui/roadmap_bg.webp',
                      fit: BoxFit.cover,
                      repeat: ImageRepeat.repeatY,
                      alignment: Alignment.bottomCenter,
                    ),
                  ),
                  const Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: Color(0x59000000)),
                    ),
                  ),
                  // 칸을 잇는 길(점선).
                  Positioned(
                    top: _finalRowH,
                    left: 0,
                    right: 0,
                    height: gridH,
                    child: CustomPaint(
                      painter: _PathPainter(
                        points: [
                          for (var i = 0; i < grid.length; i++)
                            _center(i ~/ _cols, i % _cols, width, gridH),
                        ],
                        clearedUpTo: _clearedCount(grid),
                      ),
                      size: Size(width, gridH),
                    ),
                  ),
                  // 최종 보스로 올라가는 마지막 한 칸.
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: _finalRowH + _cellH,
                    child: CustomPaint(
                      painter: _PathPainter(
                        points: [
                          Offset(width / 2, _finalRowH * 0.52),
                          _center(
                                (grid.length - 1) ~/ _cols,
                                (grid.length - 1) % _cols,
                                width,
                                gridH,
                              ) +
                              Offset(0, _finalRowH),
                        ],
                        clearedUpTo: widget.highestStage > finalNode.stage
                            ? 2
                            : 0,
                      ),
                      size: Size(width, _finalRowH + _cellH),
                    ),
                  ),
                  // 격자 칸들.
                  for (var i = 0; i < grid.length; i++)
                    _positioned(
                      grid[i],
                      _center(i ~/ _cols, i % _cols, width, gridH) +
                          const Offset(0, _finalRowH),
                      locale,
                      l,
                    ),
                  // 최종 보스.
                  _positioned(
                    finalNode,
                    Offset(width / 2, _finalRowH * 0.52),
                    locale,
                    l,
                    isFinal: true,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// 아직 클리어하지 못한 첫 칸의 인덱스(= 지금 도전 중인 칸).
  int _currentIndex(List<_Node> nodes) {
    for (var i = 0; i < nodes.length; i++) {
      if (widget.liveStage <= nodes[i].stage) return i;
    }
    return nodes.length - 1;
  }

  int _clearedCount(List<_Node> nodes) {
    var n = 0;
    for (final node in nodes) {
      if (widget.highestStage > node.stage) n++;
    }
    return n;
  }

  Widget _positioned(
    _Node node,
    Offset center,
    String locale,
    AppLocalizations l, {
    bool isFinal = false,
  }) {
    final size = isFinal
        ? _finalSize
        : (node.isWorldBoss ? _bossCellSize : _cellSize);
    // 라벨(어두운 알약) 높이까지 포함한 박스 — 좌표는 칸의 중심 기준.
    // 키울 땐 _cellH 도 함께 봐야 한다(줄 간격을 넘으면 위아래 칸과 겹친다).
    const labelH = 26.0;
    return Positioned(
      left: center.dx - size / 2,
      top: center.dy - size / 2,
      width: size,
      height: size + labelH,
      child: _NodeTile(
        node: node,
        size: size,
        isFinal: isFinal,
        label: _label(node.stage),
        cleared: widget.highestStage > node.stage,
        unlocked: widget.highestStage >= node.stage,
        isHere: _isHere(node),
        bossName: node.chapter.boss.resolve(locale),
        // 이 칸의 지역 속성 — **다음에 갈 곳의 속성을 미리 보고** 편성을
        // 준비할 수 있어야 한다. 전투 화면에 도착해서야 알면 이미 늦다.
        element: widget.runConfig.regionForStage(node.stage).element,
        // 사냥터 구조: 이 칸의 보스 그림(점령 전엔 실루엣).
        artPath: widget.runConfig.zoneMode
            ? 'assets/images/bosses/'
                  '${widget.runConfig.bossArtId(widget.tier, widget.runConfig.zoneOf(node.stage))}.webp'
            : null,
        onTap: () => Navigator.pop(context, node.stage),
      ),
    );
  }

  /// 지금 캐릭터가 서 있는 칸인지(구간 안에 liveStage 가 있는지).
  bool _isHere(_Node node) {
    final step = widget.config.nodeStep;
    return widget.liveStage > node.stage - step &&
        widget.liveStage <= node.stage;
  }

  /// 사냥터 목록 — **맨 아래가 사냥터 1**, 위로 갈수록 강하다.
  ///
  /// `reverse: true` 라 처음 화면이 바닥(사냥터 1)에서 시작한다. 점령한 칸은
  /// 그림이 드러나고, 아직 못 깬 칸은 검은 실루엣이다 — 다음에 뭐가 나오는지
  /// 궁금하게 두고, 깨면 보여 준다(사장님 확정).
  Widget _zoneList(BuildContext context, AppLocalizations l, String locale) {
    final rc = widget.runConfig;
    final zones = rc.zonesPerTier;
    final hereZone = rc.zoneOf(widget.liveStage);
    final topZone = rc.zoneOf(widget.highestStage);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.roadmapTitle),
        // 난이도 이동(2026-09-15) — 가 본 난이도까지. 어려우면 아래로 내려간다.
        bottom: widget.topTier <= 0
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(52),
                child: _tierChips(context, l),
              ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/ui/roadmap_bg.webp',
              fit: BoxFit.cover,
              repeat: ImageRepeat.repeatY,
              alignment: Alignment.bottomCenter,
            ),
          ),
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(color: Color(0x8C000000)),
            ),
          ),
          ListView.builder(
            reverse: true,
            padding: EdgeInsets.only(
              top: 12,
              bottom: MediaQuery.viewPaddingOf(context).bottom + 12,
            ),
            itemCount: zones,
            itemBuilder: (context, i) {
              final zone = i + 1; // reverse 라 i=0(사냥터 1)이 맨 아래
              final conquered = topZone > zone;
              final here = zone == hereZone;
              final artId = rc.bossArtId(widget.tier, zone);
              final info = widget.config.boss(artId);
              final chapter = widget.config.chapterForStage(
                rc.zoneStartStage(zone),
              );
              return _ZoneRow(
                zone: zone,
                isFinal: rc.isFinalZone(zone),
                conquered: conquered,
                here: here,
                // 점령한 곳과 지금 있는 곳까지만 갈 수 있다.
                unlocked: conquered || here,
                title: rc.isFinalZone(zone)
                    ? l.zoneFinalLabel
                    : l.zoneLabel(zone),
                name:
                    info?.name.resolve(locale) ??
                    chapter?.boss.resolve(locale) ??
                    '',
                desc: info?.desc.resolve(locale) ?? '',
                artPath: 'assets/images/bosses/$artId.webp',
                statusText: conquered
                    ? l.zoneConquered
                    : here
                    ? l.zoneHere
                    : l.zoneLocked,
                onTap: () => Navigator.pop(context, rc.zoneStartStage(zone)),
              );
            },
          ),
        ],
      ),
    );
  }
}

extension on _RoadmapScreenState {
  /// 난이도 네 칸 — 화면 폭을 똑같이 나눠 좌우 대칭으로 채운다. 칸마다 색·아이콘이
  /// 달라서 글자를 읽지 않아도 어느 난이도인지 갈린다(2026-09-22 사장님 요청).
  Widget _tierChips(BuildContext context, AppLocalizations l) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
    child: Row(
      children: [
        for (var t = 0; t < 4; t++) ...[
          if (t > 0) const SizedBox(width: 4),
          Expanded(
            // 높이 40 안에서 판 비율(600:194)을 지킨다 — 넓은 화면에서도 안 커진다.
            child: SizedBox(
              height: 40,
              child: Center(child: _tierButton(context, l, t)),
            ),
          ),
        ],
      ],
    ),
  );

  /// 난이도 버튼 — `ui/tier/tier_{t}.webp` 판 그림 위에 글자를 얹는다.
  /// 그림이 없으면 색 + 아이콘 버튼([_tierButtonPlain])으로 폴백한다.
  /// 지금 난이도는 원색 + 빛 테두리, 갈 수 있는 곳은 흐리게, 못 가는 곳은
  /// 흑백 + 자물쇠(같은 그림을 가공 — 따로 그리지 않는다).
  Widget _tierButton(BuildContext context, AppLocalizations l, int t) {
    final selected = t == widget.tier;
    final locked = t > widget.topTier;
    final plate = Image.asset(
      'assets/images/ui/tier/tier_$t.webp',
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, _, _) => _tierButtonPlain(context, l, t),
    );
    Widget art = locked
        ? ColorFiltered(colorFilter: _kGreyscale, child: plate)
        : plate;
    art = Opacity(opacity: selected ? 1 : (locked ? 0.45 : 0.6), child: art);
    return AnimatedScale(
      scale: selected ? 1.0 : 0.93,
      duration: const Duration(milliseconds: 150),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: locked || selected ? null : () => _confirmTier(context, l, t),
        child: AspectRatio(
          aspectRatio: 600 / 194,
          child: LayoutBuilder(
            builder: (context, box) => Stack(
              fit: StackFit.expand,
              children: [
                if (selected)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(box.maxHeight / 2),
                      boxShadow: [
                        BoxShadow(
                          color: _kTierLook[t.clamp(0, 3)].$1.withValues(
                            alpha: 0.8,
                          ),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                art,
                // 글자 — 문양(왼쪽 약 28%) 오른쪽 빈 판 위.
                Positioned(
                  left: box.maxWidth * 0.29,
                  right: box.maxWidth * 0.06,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        tierName(l, t),
                        maxLines: 1,
                        style: TextStyle(
                          color: locked ? Colors.white54 : Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          shadows: const [
                            Shadow(color: Colors.black87, blurRadius: 3),
                            Shadow(color: Colors.black54, offset: Offset(0, 1)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (locked)
                  Positioned(
                    left: box.maxWidth * 0.06,
                    width: box.maxWidth * 0.2,
                    top: 0,
                    bottom: 0,
                    child: const Center(
                      child: Icon(
                        Icons.lock_rounded,
                        size: 16,
                        color: Colors.white,
                        shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tierButtonPlain(BuildContext context, AppLocalizations l, int t) {
    final (color, icon) = _kTierLook[t.clamp(0, _kTierLook.length - 1)];
    final selected = t == widget.tier;
    final locked = t > widget.topTier;
    final fg = locked
        ? Colors.white38
        : selected
        ? Colors.white
        : color;
    return Material(
      color: selected
          ? color
          : locked
          ? Colors.white.withValues(alpha: 0.04)
          : color.withValues(alpha: 0.14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: locked ? Colors.white12 : color,
          width: selected ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: locked || selected ? null : () => _confirmTier(context, l, t),
        child: SizedBox(
          height: 40,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(locked ? Icons.lock_rounded : icon, size: 16, color: fg),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  tierName(l, t),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: fg,
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmTier(
    BuildContext context,
    AppLocalizations l,
    int tier,
  ) async {
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.tierMoveTitle(tierName(l, tier))),
        content: Text(l.tierMoveBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.actionClose),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.tierMoveGo),
          ),
        ],
      ),
    );
    if (go == true && context.mounted) {
      Navigator.pop(context, RoadmapTierPick(tier));
    }
  }
}

/// 사냥터 한 칸 — 보스 그림(실루엣) + 이름 + 한 줄 설명 + 상태.
class _ZoneRow extends StatelessWidget {
  const _ZoneRow({
    required this.zone,
    required this.isFinal,
    required this.conquered,
    required this.here,
    required this.unlocked,
    required this.title,
    required this.name,
    required this.desc,
    required this.artPath,
    required this.statusText,
    required this.onTap,
  });

  final int zone;
  final bool isFinal;
  final bool conquered;
  final bool here;
  final bool unlocked;
  final String title;
  final String name;
  final String desc;
  final String artPath;
  final String statusText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = here
        ? const Color(0xFF8BC34A)
        : conquered
        ? const Color(0xFFEBA52F)
        : const Color(0x33FFFFFF);
    final art = Image.asset(
      artPath,
      width: 74,
      height: 74,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) =>
          const Icon(Icons.bug_report, size: 44, color: Color(0x66FFFFFF)),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      // ⚠️ IntrinsicHeight 가 필요하다. 목록 칸은 높이가 무한으로 주어지는데
      // 아래 Row 가 `stretch` 로 세로를 채우려 해서 레이아웃이 터졌다 —
      // 릴리즈에서는 오류 위젯이 **빈 상자**라 "배경만 보인다"가 됐다
      // (2026-09-14). 여기서 높이를 카드 높이로 확정해 준다.
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 왼쪽 세로 길 — 점령한 곳까지는 금색으로 이어진다.
            SizedBox(
              width: 14,
              child: Center(
                child: Container(
                  width: 3,
                  decoration: BoxDecoration(
                    color: conquered || here
                        ? const Color(0xFFEBA52F)
                        : const Color(0x22FFFFFF),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: unlocked ? onTap : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: here
                        ? const Color(0xCC1B2A10)
                        : const Color(0xB3101A0A),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: accent, width: here ? 2 : 1),
                  ),
                  child: Row(
                    children: [
                      // 점령 전엔 실루엣 — 무엇이 기다리는지는 숨긴다.
                      // ⚠️ 검은색으로 칠하면 **어두운 카드 위에서 아무것도 안
                      // 보인다**(2026-09-14 지적: "보스들이 안 나와"). 형태가
                      // 읽히도록 밝은 회색으로 찍고 살짝 비친다.
                      SizedBox(
                        width: 74,
                        height: 74,
                        child: conquered || here
                            ? art
                            : Opacity(
                                opacity: 0.55,
                                child: ColorFiltered(
                                  colorFilter: const ColorFilter.mode(
                                    Color(0xFF8A96A0),
                                    BlendMode.srcIn,
                                  ),
                                  child: art,
                                ),
                              ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    name.isEmpty ? title : name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: isFinal
                                          ? const Color(0xFFFFD54F)
                                          : Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                                if (isFinal) ...[
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.workspace_premium_rounded,
                                    size: 15,
                                    color: Color(0xFFFFD54F),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              desc,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xB3FFFFFF),
                                fontSize: 11.5,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: accent.withValues(alpha: 0.22),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(color: accent),
                                  ),
                                  child: Text(
                                    '$title · $statusText',
                                    style: TextStyle(
                                      color: conquered || here
                                          ? Colors.white
                                          : const Color(0x99FFFFFF),
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                if (unlocked) ...[
                                  const Spacer(),
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    size: 18,
                                    color: Color(0x99FFFFFF),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 칸 하나의 그림 — 네모(징검다리) + 상태 표시 + 라벨.
class _NodeTile extends StatelessWidget {
  const _NodeTile({
    required this.node,
    required this.size,
    required this.isFinal,
    required this.label,
    required this.cleared,
    required this.unlocked,
    required this.isHere,
    required this.bossName,
    required this.element,
    required this.onTap,
    this.artPath,
  });

  final _Node node;

  /// 사냥터 구조의 보스 그림 경로. 점령 전엔 검은 실루엣으로만 보인다 —
  /// "다음에 뭐가 나오나"는 실루엣으로 궁금하게, 깨면 드러난다(사장님 확정).
  final String? artPath;
  final double size;
  final bool isFinal;
  final String label;
  final bool cleared;
  final bool unlocked;
  final bool isHere;
  final String bossName;

  /// 이 칸이 속한 지역의 오행. null 이면 무속성(뱃지를 안 그린다).
  final cm.Element? element;

  final VoidCallback onTap;

  static const _gold = Color(0xFFFFD24A);

  /// 보스 칸 전용 핏빛 — 챕터색과 무관하게 "여긴 보스다"를 색으로 먼저 알린다.
  static const _demon = Color(0xFFD1443E);

  @override
  Widget build(BuildContext context) {
    final isBoss = node.isWorldBoss || isFinal;
    final color = Color(node.chapter.color);
    final border = cleared
        ? _gold
        : (isHere
              ? Colors.white
              : isBoss
              ? _demon
              : (unlocked ? color : const Color(0x66FFFFFF)));

    Widget tile = Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        // 네모칸(징검다리). 보스는 살짝 더 둥글게 강조.
        borderRadius: BorderRadius.circular(isFinal ? 22 : 12),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: unlocked
              ? [color.withValues(alpha: 0.95), color.withValues(alpha: 0.55)]
              // 잠긴 보스 칸은 회색으로 덮지 않는다 — 핏빛 테두리와 붙었을 때
              // 챕터색이 옅게 남아 있어야 "잠긴 회색 칸"과 구분된다.
              : isBoss
              ? [color.withValues(alpha: 0.45), color.withValues(alpha: 0.20)]
              : [const Color(0xFF39403A), const Color(0xFF1B211D)],
        ),
        border: Border.all(
          color: border,
          width: isBoss || cleared || isHere ? 3 : 2,
        ),
        boxShadow: [
          if (isHere || isFinal)
            BoxShadow(
              color: (isFinal ? _gold : Colors.white).withValues(alpha: 0.55),
              blurRadius: isFinal ? 22 : 14,
            )
          else if (isBoss)
            BoxShadow(color: _demon.withValues(alpha: 0.45), blurRadius: 12),
        ],
      ),
      child: _inner(),
    );

    if (isBoss) {
      // 뿔·가시는 칸 안쪽 여백에 그린다 — 바깥으로 삐져나가면 상위 Stack 이 잘라낸다.
      tile = Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _BossFrame(border))),
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.all(size * _bossInsetFrac),
              child: tile,
            ),
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: unlocked ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: element == null
                ? tile
                : Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(child: tile),
                      // 오른쪽 위 구석 — 칸 안의 챕터 그림·보스 뿔과 안 겹친다.
                      // 잠긴 칸에서도 보여준다. 어디를 뚫으면 무슨 속성이
                      // 나오는지가 곧 편성을 준비할 이유다.
                      Positioned(
                        right: -3,
                        top: -3,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: const Color(0xCC000000),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: elementColor(
                                element!,
                              ).withValues(alpha: 0.9),
                            ),
                          ),
                          child: elementIcon(element!, size: 11),
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 2),
          // 배경 일러스트 위에 흰 글씨만 얹으면 밝은 부분에서 사라진다 —
          // 어두운 알약을 깔아 배경과 무관하게 읽히게 한다.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: const Color(0xC2000000),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              // 사냥터 구조에서는 칸 하나가 보스 하나다 — 이름이 곧 목표다.
              (isFinal || node.isWorldBoss) && bossName.isNotEmpty
                  ? bossName
                  : label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isFinal
                    ? _gold
                    : (unlocked ? Colors.white : const Color(0xCCFFFFFF)),
                fontWeight: FontWeight.w900,
                fontSize: isFinal ? 16 : 12.5,
                letterSpacing: isFinal ? 0.3 : 0,
                shadows: const [Shadow(color: Colors.black, blurRadius: 2)],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _inner() {
    // ★ 보스 칸·최종 보스 — 사냥터 구조에서는 마리마다 그림이 있다.
    //   점령 전: 검은 실루엣(정체를 감추되 형태로 기대를 만든다).
    //   점령 후: 그림 그대로 + 금색 체크.
    //   그림이 없으면(아트 미도착) 예전 표식으로 떨어진다.
    if ((node.isWorldBoss || isFinal) && artPath != null) {
      final img = Image.asset(
        artPath!,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, _, _) => _legacyBossMark(),
      );
      return Padding(
        padding: EdgeInsets.all(size * 0.06),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (cleared)
              img
            else
              ColorFiltered(
                colorFilter: const ColorFilter.mode(
                  Color(0xFF14110F),
                  BlendMode.srcIn,
                ),
                child: img,
              ),
            if (cleared)
              Align(
                alignment: Alignment.bottomRight,
                child: Icon(
                  Icons.check_circle_rounded,
                  color: _gold,
                  size: size * 0.26,
                ),
              )
            else if (!unlocked)
              Align(
                alignment: Alignment.bottomRight,
                child: Icon(
                  Icons.lock_rounded,
                  color: const Color(0xE6FFFFFF),
                  size: size * 0.24,
                ),
              ),
          ],
        ),
      );
    }
    if (node.isWorldBoss || isFinal) return _legacyBossMark();
    return _plainMark();
  }

  /// 예전 보스 표식(그림 없을 때).
  Widget _legacyBossMark() {
    final Widget mark;
    if (cleared) {
      mark = Icon(Icons.check_circle_rounded, color: _gold, size: size * 0.28);
    } else if (unlocked) {
      mark = Text('👹', style: TextStyle(fontSize: size * 0.30));
    } else {
      // 잠김 — 자물쇠는 일반 칸과 같은 크기로 둔다(작은 배지로 줄이지 않는다).
      mark = Icon(
        Icons.lock_rounded,
        color: const Color(0xE6FFFFFF),
        size: size * 0.28,
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isFinal) Text('👑', style: TextStyle(fontSize: size * 0.16)),
        mark,
        Text(
          'BOSS',
          style: TextStyle(
            color: unlocked ? Colors.white : const Color(0xCCFFFFFF),
            fontWeight: FontWeight.w900,
            fontSize: size * 0.155,
            letterSpacing: 0.6,
            height: 1.1,
            shadows: const [Shadow(color: Colors.black, blurRadius: 3)],
          ),
        ),
      ],
    );
  }

  Widget _plainMark() {
    if (!unlocked) {
      return Icon(
        Icons.lock_rounded,
        color: const Color(0xCCFFFFFF),
        size: size * 0.36,
      );
    }
    if (cleared) {
      return Icon(Icons.check_rounded, color: _gold, size: size * 0.44);
    }
    // 진행 중/미클리어 일반 칸 — 라벨은 아래에 있으니 여기선 표식만.
    return Text(
      label.split('-').last,
      style: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w900,
        fontSize: size * 0.36,
        shadows: const [
          Shadow(color: Colors.black, blurRadius: 4),
          Shadow(color: Colors.black54, offset: Offset(0, 1), blurRadius: 2),
        ],
      ),
    );
  }
}

/// 보스 칸 본체가 물러나는 여백 비율 — 그 여백에 뿔·가시를 그린다.
/// 본체가 일반 칸(56)보다 작아지지 않게 `_bossCellSize` 와 함께 조정할 것.
const _bossInsetFrac = 0.08;

/// 보스 칸 테두리 장식 — 위쪽 뿔 2개 + 좌우 가시 3쌍.
/// 일반 칸의 밋밋한 네모와 실루엣만으로 구분되게 해서, 스크롤로 훑을 때
/// "저기가 보스"가 글자를 읽기 전에 먼저 보이게 한다.
class _BossFrame extends CustomPainter {
  const _BossFrame(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color;
    final w = size.width;
    final h = size.height;
    final inset = w * _bossInsetFrac;

    // 뿔 — 위 양옆 모서리에서 바깥 위로.
    for (final left in const [true, false]) {
      final x = left ? inset : w - inset;
      final dir = left ? -1.0 : 1.0;
      canvas.drawPath(
        Path()
          ..moveTo(x + dir * w * 0.02, inset * 1.5)
          ..lineTo(x + dir * w * 0.09, 0)
          ..lineTo(x + dir * w * 0.14, inset * 1.9)
          ..close(),
        p,
      );
    }

    // 좌우 가시.
    final spike = w * 0.055;
    for (final t in const [0.40, 0.60, 0.80]) {
      final y = h * t;
      for (final left in const [true, false]) {
        final x = left ? inset : w - inset;
        final dir = left ? -1.0 : 1.0;
        canvas.drawPath(
          Path()
            ..moveTo(x, y - spike)
            ..lineTo(x + dir * inset * 0.95, y)
            ..lineTo(x, y + spike)
            ..close(),
          p,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_BossFrame old) => old.color != color;
}

/// 칸과 칸을 잇는 점선 길. 클리어한 구간은 금색, 나머지는 흐리게.
class _PathPainter extends CustomPainter {
  const _PathPainter({required this.points, required this.clearedUpTo});

  final List<Offset> points;

  /// 앞에서부터 몇 개의 칸이 클리어됐는지(그만큼의 선을 금색으로).
  final int clearedUpTo;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i + 1 < points.length; i++) {
      final done = i + 1 < clearedUpTo;
      final paint = Paint()
        ..color = done ? const Color(0xCCFFD24A) : const Color(0x66FFFFFF)
        ..strokeWidth = done ? 4 : 3
        ..strokeCap = StrokeCap.round;
      _dashed(canvas, points[i], points[i + 1], paint);
    }
  }

  /// 징검다리 느낌의 점선.
  void _dashed(Canvas canvas, Offset a, Offset b, Paint paint) {
    const dash = 7.0;
    const gap = 6.0;
    final total = (b - a).distance;
    if (total <= 0) return;
    final dir = (b - a) / total;
    var t = 0.0;
    while (t < total) {
      final end = (t + dash).clamp(0.0, total);
      canvas.drawLine(a + dir * t, a + dir * end, paint);
      t = end + gap;
    }
  }

  @override
  bool shouldRepaint(_PathPainter old) =>
      old.clearedUpTo != clearedUpTo || old.points.length != points.length;
}

/// 난이도별 색·아이콘(쉬움 → 극한). 뒤로 갈수록 뜨겁고 위험하게.
const _kTierLook = <(Color, IconData)>[
  (Color(0xFF66BB6A), Icons.eco_rounded),
  (Color(0xFF42A5F5), Icons.terrain_rounded),
  (Color(0xFFFFA726), Icons.local_fire_department_rounded),
  (Color(0xFFE53935), Icons.dangerous_rounded),
];

/// 못 가는 난이도 — 같은 판 그림을 흑백으로.
const _kGreyscale = ColorFilter.matrix(<double>[
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0, 0, 0, 1, 0,
]);

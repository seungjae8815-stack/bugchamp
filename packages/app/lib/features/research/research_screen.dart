import 'dart:async';
import 'dart:math' as math;

import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:core_save/core_save.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/game_data.dart';
import '../../domain/combat_power.dart';
import '../../domain/guild_service.dart' show guildBonusProvider;
import '../../domain/providers.dart';
import '../../domain/research_view.dart';
import '../../domain/save_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/art.dart';
import '../../ui/colors.dart';
import '../../ui/format.dart';
import '../../ui/jelly_confirm.dart';
import '../../ui/tier_label.dart';
import '../../ui/toast.dart';

/// 연구소 탭(설계 `docs/superpowers/specs/2026-10-22-research-lab-design.md` §3 · §11 기술 트리).
///
/// 위: 연구 재화 보유량 · 연구 칸 1~3 가로 카드(진행 막대·남은 시간·젤리 즉시 완료 / 빈 칸 / 잠긴 칸 + 젤리 구매)
/// \+ "연구 속도 +N%"(연구 효율). 가운데: 고른 분야의 **트리** — 카드(아이콘·이름·`Lv x/30`)를 research.json 의
/// `tree` 칸에 놓고 `requires` 로 선을 긋는다. 카드를 누르면 아래 시트에 효과·비용·잠김 사유·[연구]/즉시 완료.
/// 아래: 분야 탭 5개(사냥·육성·결투·장비·경제).
/// 규칙(가격·시작 조건)은 core_save `research_progress.dart`, 화면은 그 결과(`ResearchOp` 사유)를 그대로 보여 준다.
class ResearchScreen extends ConsumerStatefulWidget {
  const ResearchScreen({super.key});

  @override
  ConsumerState<ResearchScreen> createState() => _ResearchScreenState();
}

/// 연구 하나의 지금 상태(카드·시트·탭 점이 같은 값을 본다).
typedef _Status = ({
  int lv,
  bool maxed,
  ResearchSlot? slot,
  ResearchPrice? price,
  String? error,
});

class _ResearchScreenState extends ConsumerState<ResearchScreen> {
  Timer? _tick;
  ResearchBranch _branch = ResearchBranch.hunt;

  @override
  void initState() {
    super.initState();
    // 남은 시간을 1초마다 다시 그리고, 끝난 연구는 바로 반영한다 — 사냥이 멈추면 커밋도 멈춘다.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      final s = ref.read(saveControllerProvider).value;
      if (!mounted || s == null || s.researchSlots.isEmpty) return;
      final now = ref.read(clockProvider).now().toUtc();
      if (s.researchSlots.any((r) => !now.isBefore(r.endsAt))) {
        unawaited(ref.read(saveControllerProvider.notifier).claimResearchDue());
      }
      // 다른 탭에 있는 동안(IndexedStack 이 살려 둔다)은 다시 그리지 않는다 — 수령만 한다.
      if (ref.read(tabIndexProvider) == kResearchTabIndex) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  SaveController get _ctrl => ref.read(saveControllerProvider.notifier);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final data = ref.watch(gameDataProvider).value;
    final save = ref.watch(saveControllerProvider).value;
    final cfg = data?.researchConfig;

    // 연구가 끝나 레벨이 오르면(자동 수령·즉시 완료) 연구소를 보고 있을 때만 알린다.
    ref.listen<AsyncValue<SaveGame>>(saveControllerProvider, (prev, next) {
      final a = prev?.value, b = next.value;
      if (a == null || b == null || cfg == null) return;
      if (ref.read(tabIndexProvider) != kResearchTabIndex) return;
      for (final e in b.researchLevels.entries) {
        if (e.value > (a.researchLevels[e.key] ?? 0)) {
          final def = cfg.byId(e.key);
          if (def == null) continue;
          showCenterToast(
            context,
            l.researchDoneToast(_name(def, locale), '${e.value}'),
          );
          break;
        }
      }
    });

    return Scaffold(
      appBar: AppBar(title: Text(l.navResearch)),
      body: SafeArea(
        child: data == null || save == null || cfg == null
            ? const SizedBox.shrink()
            : Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: _body(l, locale, data, save, cfg),
              ),
      ),
    );
  }

  /// 사냥 능력치는 한 번만 — 29개 가격이 모두 같은 값을 쓴다.
  CharacterStats? _stats(GameData data, SaveGame save, DateTime now) =>
      data.runConfig == null
      ? null
      : huntStatsOf(save, data, now, guildBonus: ref.read(guildBonusProvider));

  _Status _statusOf(
    GameData data,
    SaveGame save,
    ResearchConfig cfg,
    ResearchDef def,
    DateTime now,
    CharacterStats? stats,
  ) {
    final lv = save.researchLevels[def.id] ?? 0;
    final maxed = lv >= def.maxLevel;
    ResearchSlot? slot;
    for (final r in save.researchSlots) {
      if (r.id == def.id) slot = r;
    }
    final price = maxed || stats == null
        ? null
        : researchPriceOf(save, data, def.id, now, stats: stats);
    final error = maxed
        ? 'max_level'
        : price == null
        ? 'unknown_research'
        : startResearch(save, cfg, def.id, now, price).error;
    return (lv: lv, maxed: maxed, slot: slot, price: price, error: error);
  }

  Widget _body(
    AppLocalizations l,
    String locale,
    GameData data,
    SaveGame save,
    ResearchConfig cfg,
  ) {
    final now = ref.read(clockProvider).now().toUtc();
    ref.watch(guildBonusProvider);
    final stats = _stats(data, save, now);
    final status = {
      for (final def in cfg.defs)
        def.id: _statusOf(data, save, cfg, def, now, stats),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 재화·칸도 트리와 같이 스크롤한다 — 작은 폰에서 위쪽이 트리 자리를 붙잡지 않게.
        Expanded(
          child: SingleChildScrollView(
            key: Key('researchTree_${_branch.key}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _currencies(l, save, cfg),
                const SizedBox(height: 6),
                _slots(l, locale, save, cfg, now),
                const SizedBox(height: 6),
                _tree(l, locale, save, cfg, status, now),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        _tabs(l, cfg, status),
      ],
    );
  }

  // ── 위: 재화 한 줄 + 연구 시간 ──

  Widget _currencies(AppLocalizations l, SaveGame save, ResearchConfig cfg) {
    final cut = researchEffects(
      cfg,
      save.researchLevels,
    ).of(ResearchEffect.researchTime);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: _box(),
      child: Row(
        children: [
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  _tally(
                    _sampleIcon(16),
                    formatCompact(save.researchSamples),
                    tooltip: l.researchSamples,
                  ),
                  const SizedBox(width: 12),
                  _tally(goldIcon(size: 16), formatCompact(save.gold)),
                  const SizedBox(width: 12),
                  _tally(
                    materialImage(
                      MaterialKind.fossil,
                      size: 16,
                      fallback: const Icon(Icons.diamond_rounded, size: 14),
                    ),
                    formatCompact(save.materialCount(MaterialKind.fossil)),
                  ),
                  const SizedBox(width: 12),
                  _tally(
                    jellyIcon(size: 16),
                    formatCompact(save.materialCount(MaterialKind.jelly)),
                  ),
                ],
              ),
            ),
          ),
          // 연구 효율 — 시트의 "연구 시간 −N%" 와 같은 숫자.
          if (cut > 0) ...[
            const SizedBox(width: 8),
            Text(
              l.researchTimeCut(fmtResearchPct(cut)),
              key: const Key('researchTimeCut'),
              maxLines: 1,
              style: const TextStyle(
                color: Color(0xFF80DEEA),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _tally(Widget icon, String text, {String? tooltip}) {
    final w = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
    return tooltip == null ? w : Tooltip(message: tooltip, child: w);
  }

  // ── 위: 연구 칸(가로 3장) ──

  Widget _slots(
    AppLocalizations l,
    String locale,
    SaveGame save,
    ResearchConfig cfg,
    DateTime now,
  ) {
    final open = cfg.slotsFor(save.topTier, save.researchSlotsBought);
    // 사면 늘 다음 칸 하나(core_save `buyResearchSlot` — 값은 열린 칸 수로 정해진다).
    final buyPrice = researchSlotPrice(save, cfg);
    final cut = researchEffects(
      cfg,
      save.researchLevels,
    ).of(ResearchEffect.researchTime);
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
      decoration: _box(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l.researchSlotsTitle('${save.researchSlots.length}', '$open'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: kHoney,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < ResearchConfig.maxSlots; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(
                    child: i < save.researchSlots.length
                        ? _runningSlot(
                            l,
                            locale,
                            cfg,
                            save.researchSlots[i],
                            now,
                            cut,
                          )
                        : i < open
                        ? _slotFrame(
                            key: Key('researchSlot$i'),
                            child: Center(
                              child: Text(
                                l.researchSlotEmpty,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 11.5,
                                ),
                              ),
                            ),
                          )
                        : _lockedSlot(
                            l,
                            cfg,
                            i,
                            buyPrice: i == open ? buyPrice : null,
                          ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _slotFrame({Key? key, required Widget child, Color? border}) =>
      Container(
        key: key,
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: const Color(0x33000000),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border ?? const Color(0x22FFFFFF)),
        ),
        child: child,
      );

  /// 진행 중 칸 — 이름 · Lv 칩 · 남은 시간 · 막대만(낮게). 즉시 완료는 눌러서 여는 시트에서.
  Widget _runningSlot(
    AppLocalizations l,
    String locale,
    ResearchConfig cfg,
    ResearchSlot r,
    DateTime now,
    double cut,
  ) {
    final def = cfg.byId(r.id);
    final left = r.endsAt.difference(now);
    // 칸에는 시작 시각이 없다 — 이번 레벨의 시간(지금 연구 효율 반영)으로 진행률을 어림한다.
    final total = def == null
        ? Duration.zero
        : cfg.timeAt(def, r.level) * (1 - cut);
    final progress = total.inSeconds <= 0
        ? 1.0
        : (1 - left.inSeconds / total.inSeconds).clamp(0.0, 1.0);
    final name = def == null ? r.id : _name(def, locale);
    return GestureDetector(
      key: Key('researchSlotCard_${r.id}'),
      onTap: def == null ? null : () => _openSheet(def.id),
      child: _slotFrame(
        border: const Color(0xAA4FC3F7),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                _researchIcon(def, 16),
                const SizedBox(width: 3),
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                // 레벨은 따로 — 긴 이름의 말줄임에 묻히지 않게.
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: const Color(0x334FC3F7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Lv${r.level}',
                    style: const TextStyle(
                      color: Color(0xFF80DEEA),
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              formatShortDuration(left),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 10.5),
            ),
            const SizedBox(height: 3),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                key: Key('researchSlotBar_${r.id}'),
                value: progress,
                minHeight: 5,
                backgroundColor: const Color(0x33FFFFFF),
                color: const Color(0xFF4FC3F7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _lockedSlot(
    AppLocalizations l,
    ResearchConfig cfg,
    int index, {
    int? buyPrice,
  }) {
    final tier = researchSlotOpensAtTier(cfg, index);
    return _slotFrame(
      key: Key('researchSlot$index'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              const Icon(Icons.lock_rounded, size: 13, color: Colors.white38),
              const SizedBox(width: 3),
              // 한 줄 — 칸 카드 높이를 낮게 둔다(좁으면 글자를 줄인다).
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    tier == null
                        ? ''
                        : l.researchSlotOpensAt(tierName(l, tier)),
                    maxLines: 1,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 10.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (buyPrice != null) ...[
            const SizedBox(height: 4),
            _smallButton(
              key: const Key('researchBuySlot'),
              onPressed: () => _buySlot(l, buyPrice),
              compact: true,
              child: jellyPrice(cost: buyPrice, label: l.researchSlotBuy),
            ),
          ],
        ],
      ),
    );
  }

  // ── 가운데: 분야 트리 ──

  Widget _tree(
    AppLocalizations l,
    String locale,
    SaveGame save,
    ResearchConfig cfg,
    Map<String, _Status> status,
    DateTime now,
  ) {
    final defs = [
      for (final d in cfg.defs)
        if (d.branch == _branch) d,
    ];
    // 칸이 안 적힌 연구는 가운데 열에 순서대로(데이터가 빠져도 화면은 그린다).
    final cells = <String, ({int col, int row})>{
      for (var i = 0; i < defs.length; i++)
        defs[i].id: defs[i].tree ?? (col: 1, row: i),
    };
    final rows = cells.values.fold(0, (m, c) => math.max(m, c.row + 1));
    return LayoutBuilder(
      builder: (context, box) {
        final cellW = box.maxWidth / 3;
        // 320dp 폰에서도 3열 + 틈이 들어가게 너비에서 카드 크기를 정한다.
        final cardW = math.min(cellW - 12, 100.0);
        // 세로 여유 — 이름 두 줄 + Lv 알약 + 남은 시간이 FittedBox 로 많이 줄지 않게.
        final cardH = cardW * 1.3;
        const gap = 26.0, pad = 6.0;
        Rect rectOf(String id) {
          final c = cells[id]!;
          return Rect.fromLTWH(
            cellW * (c.col.clamp(0, 2) + 0.5) - cardW / 2,
            pad + c.row * (cardH + gap),
            cardW,
            cardH,
          );
        }

        final edges = [
          for (final d in defs)
            if (d.requires case final req? when cells.containsKey(req.id))
              (
                from: rectOf(req.id),
                to: rectOf(d.id),
                lit: (save.researchLevels[req.id] ?? 0) >= req.level,
              ),
        ];
        final height = pad * 2 + rows * cardH + math.max(0, rows - 1) * gap;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: height,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(painter: _TreeLines(edges)),
                  ),
                  for (final d in defs)
                    Positioned.fromRect(
                      rect: rectOf(d.id),
                      child: _card(l, locale, d, status[d.id]!, now, cardW),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                l.researchHowToGet,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ),
          ],
        );
      },
    );
  }

  /// 트리 카드 — 다 찍음 금테 · 연구 중 하늘색 테 + 남은 시간 · 잠김 어둡게 + 자물쇠 · 시작 가능 빨간 점.
  Widget _card(
    AppLocalizations l,
    String locale,
    ResearchDef def,
    _Status st,
    DateTime now,
    double cardW,
  ) {
    final locked = st.error == 'locked';
    final running = st.slot != null;
    final border = st.maxed
        ? kHoney
        : running
        ? const Color(0xFF4FC3F7)
        : const Color(0x33FFFFFF);
    final card = Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('researchCard_${def.id}'),
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openSheet(def.id),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: st.maxed
                  ? const [Color(0xFF4A3A14), Color(0xFF231A08)]
                  : const [Color(0xFF2A3D1C), Color(0xFF142010)],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: border,
              width: st.maxed || running ? 2 : 1,
            ),
            boxShadow: [
              if (st.maxed || running)
                BoxShadow(color: border.withAlpha(0x66), blurRadius: 8),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox(
                width: cardW - 10,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _researchIcon(def, cardW * 0.4, dim: locked),
                    const SizedBox(height: 3),
                    Text(
                      _name(def, locale),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // 알약은 한 줄 — 좁으면 글자를 줄인다.
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: locked ? const Color(0x44FFFFFF) : kHoney,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Text(
                          l.researchLevel('${st.lv}', '${def.maxLevel}'),
                          maxLines: 1,
                          softWrap: false,
                          style: TextStyle(
                            color: locked ? Colors.white70 : kHoneyInk,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    // 남은 시간 줄은 모든 카드가 자리를 잡아 둔다 — 연구 중 카드만 더 줄어들지 않게.
                    const SizedBox(height: 2),
                    Text(
                      switch (st.slot) {
                        final r? => formatShortDuration(
                          r.endsAt.difference(now),
                        ),
                        null => '',
                      },
                      key: Key('researchCardTime_${def.id}'),
                      maxLines: 1,
                      style: const TextStyle(
                        color: Color(0xFF80DEEA),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: locked ? Opacity(opacity: 0.5, child: card) : card,
        ),
        if (locked)
          const Positioned(
            top: 4,
            right: 4,
            child: Icon(Icons.lock_rounded, size: 14, color: Colors.white70),
          ),
        if (st.error == null)
          const Positioned(top: -3, right: -3, child: _Dot()),
      ],
    );
  }

  // ── 아래: 분야 탭 ──

  Widget _tabs(
    AppLocalizations l,
    ResearchConfig cfg,
    Map<String, _Status> status,
  ) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF1B2A12), Color(0xFF0E1608)],
      ),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0x22FFFFFF)),
    ),
    child: Row(
      children: [
        for (final b in ResearchBranch.values)
          Expanded(child: _tab(l, cfg, status, b)),
      ],
    ),
  );

  Widget _tab(
    AppLocalizations l,
    ResearchConfig cfg,
    Map<String, _Status> status,
    ResearchBranch b,
  ) {
    final active = b == _branch;
    ResearchDef? root;
    for (final d in cfg.defs) {
      if (d.branch == b && d.requires == null) {
        root = d;
        break;
      }
    }
    final ready = cfg.defs.any(
      (d) => d.branch == b && status[d.id]?.error == null,
    );
    return InkWell(
      key: Key('researchTab_${b.key}'),
      borderRadius: BorderRadius.circular(8),
      onTap: () => setState(() => _branch = b),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
        decoration: BoxDecoration(
          color: active ? const Color(0x2EEBA52F) : null,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? kHoney : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(child: _researchIcon(root, 22, dim: !active)),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _branchLabel(l, b),
                    maxLines: 1,
                    style: TextStyle(
                      color: active ? kHoney : Colors.white70,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            if (ready) const Positioned(top: -2, right: 2, child: _Dot()),
          ],
        ),
      ),
    );
  }

  // ── 연구 하나의 시트 ──

  void _openSheet(String id) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xF20A1206),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        // 남은 시간·즉시 완료 값이 흐르게 1초마다 다시 그린다(시트가 닫히면 구독도 끝난다).
        child: StreamBuilder<void>(
          stream: Stream<void>.periodic(const Duration(seconds: 1)),
          builder: (ctx, _) => Consumer(
            builder: (ctx, ref, _) {
              if (!mounted) return const SizedBox.shrink();
              final data = ref.watch(gameDataProvider).value;
              final save = ref.watch(saveControllerProvider).value;
              final cfg = data?.researchConfig;
              final def = cfg?.byId(id);
              if (data == null || save == null || cfg == null || def == null) {
                return const SizedBox.shrink();
              }
              return _sheet(
                AppLocalizations.of(ctx),
                Localizations.localeOf(ctx).languageCode,
                sheetContext,
                data,
                save,
                cfg,
                def,
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _sheet(
    AppLocalizations l,
    String locale,
    BuildContext sheetContext,
    GameData data,
    SaveGame save,
    ResearchConfig cfg,
    ResearchDef def,
  ) {
    final now = ref.read(clockProvider).now().toUtc();
    final st = _statusOf(data, save, cfg, def, now, _stats(data, save, now));
    final cur = cfg.effectAt(def, st.lv);
    final next = cfg.effectAt(def, st.lv + 1);
    final fx = _fxLabel(l, def.effect);
    final effectText = st.maxed
        ? '$fx ${_fxValue(l, def.effect, cur)}'
        : '$fx ${_fxValue(l, def.effect, cur)} → ${_fxValue(l, def.effect, next)}';
    final req = def.requires;
    final reqDef = req == null ? null : cfg.byId(req.id);
    final reason = switch (st.error) {
      null => null,
      'max_level' => null,
      'already_running' => null,
      'locked' => l.researchLockedReq(
        reqDef == null ? req!.id : _name(reqDef, locale),
        '${req!.level}',
      ),
      final e => _errText(l, e),
    };
    final slot = st.slot;
    final left = slot?.endsAt.difference(now);
    final jelly = left == null ? 0 : cfg.instantJelly(left);
    return SingleChildScrollView(
      key: Key('researchSheet_${def.id}'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _researchIcon(def, 44, dim: st.error == 'locked'),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _name(def, locale),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                l.researchLevel('${st.lv}', '${def.maxLevel}'),
                style: TextStyle(
                  color: st.maxed ? kHoney : Colors.white70,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            effectText,
            style: const TextStyle(color: Color(0xFFB9F6CA), fontSize: 13),
          ),
          if (st.price case final p?) ...[
            const SizedBox(height: 8),
            _cost(l, save, p),
          ],
          if (reason != null) ...[
            const SizedBox(height: 8),
            Text(
              reason,
              style: const TextStyle(color: Color(0xFFFF8A80), fontSize: 12),
            ),
          ],
          // 표본이 모자라고 연구 패스가 없으면 패스 안내(2026-10-25 사장님 — 복귀 팝업의 "버프 켜러 가기"와 같은 방식).
          // 사실만 적는다: 연구 패스는 방치(오프라인) 중에도 표본을 모은다.
          if (st.price case final p?
              when p.samples > save.researchSamples &&
                  !save.researchPassActive(
                    ref.read(clockProvider).now().toUtc(),
                  )) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
              decoration: BoxDecoration(
                color: const Color(0x228FC3FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0x558FC3FF)),
              ),
              child: Row(
                children: [
                  // 연구 패스 그림(상점 카드와 같은 그림) — 무엇을 사라는 건지 한눈에.
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: gameImage(
                      'assets/images/shop/research_pass.webp',
                      width: 24,
                      height: 24,
                      fit: BoxFit.cover,
                      fallback: _sampleIcon(18),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 한 줄(2026-10-25 사장님 — 두 줄은 읽기 어렵다). 좁으면 글자를 줄인다.
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        l.researchPassHint,
                        maxLines: 1,
                        style: const TextStyle(
                          color: Color(0xFFCFE4FF),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  _smallButton(
                    key: const Key('researchPassHintShop'),
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      ref.read(tabIndexProvider.notifier).set(kShopTabIndex);
                    },
                    child: Text(l.researchPassHintGo),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              if (slot != null && left != null) ...[
                Expanded(
                  child: Text(
                    formatShortDuration(left),
                    style: const TextStyle(
                      color: Color(0xFF80DEEA),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (jelly > 0)
                  _smallButton(
                    key: Key('researchSheetInstant_${def.id}'),
                    onPressed: () =>
                        _instant(l, _name(def, locale), slot.id, slot.level),
                    child: jellyPrice(cost: jelly),
                  ),
              ] else ...[
                const Spacer(),
                _smallButton(
                  key: Key('researchStart_${def.id}'),
                  onPressed: st.error == null
                      ? () => _start(l, def.id, sheetContext)
                      : null,
                  child: Text(st.maxed ? l.researchMaxed : l.researchStart),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// 다음 레벨 비용 — 모자란 것은 빨간 글씨.
  Widget _cost(AppLocalizations l, SaveGame save, ResearchPrice p) {
    const ok = Colors.white70;
    const short = Color(0xFFFF8A80);
    Widget item(Widget icon, String text, bool enough) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        const SizedBox(width: 3),
        Text(
          text,
          style: TextStyle(
            color: enough ? ok : short,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
    final matsOk = kRegularMaterials.every(
      (m) => save.materialCount(m) >= p.materialsEach,
    );
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        item(
          const Icon(Icons.schedule_rounded, size: 14, color: Colors.white54),
          formatShortDuration(p.time),
          true,
        ),
        if (p.samples > 0)
          item(
            _sampleIcon(14),
            formatCompact(p.samples),
            save.researchSamples >= p.samples,
          ),
        if (p.gold > 0)
          item(goldIcon(size: 14), formatCompact(p.gold), save.gold >= p.gold),
        if (p.materialsEach > 0)
          item(
            materialImage(
              MaterialKind.chitin,
              size: 14,
              fallback: const Icon(Icons.category_rounded, size: 13),
            ),
            l.researchCostMaterials(formatCompact(p.materialsEach)),
            matsOk,
          ),
        if (p.fossil > 0)
          item(
            materialImage(
              MaterialKind.fossil,
              size: 14,
              fallback: const Icon(Icons.diamond_rounded, size: 13),
            ),
            formatCompact(p.fossil),
            save.materialCount(MaterialKind.fossil) >= p.fossil,
          ),
      ],
    );
  }

  // ── 동작 ──

  Future<void> _start(
    AppLocalizations l,
    String id,
    BuildContext sheetContext,
  ) async {
    final err = await _ctrl.startResearchNow(id);
    if (!mounted) return;
    if (err != null) {
      showCenterToast(context, _errText(l, err));
    } else if (sheetContext.mounted) {
      Navigator.of(sheetContext).pop();
    }
  }

  /// 즉시 완료 — 젤리 값은 누르는 순간의 남은 시간으로 다시 잰다(칸·시트가 1초 늦게 그려져 있어도 같은 값).
  Future<void> _instant(
    AppLocalizations l,
    String name,
    String id,
    int level,
  ) async {
    final s = ref.read(saveControllerProvider).value;
    final cfg = ref.read(gameDataProvider).value?.researchConfig;
    ResearchSlot? slot;
    for (final r in s?.researchSlots ?? const <ResearchSlot>[]) {
      if (r.id == id) slot = r;
    }
    if (cfg == null || slot == null) return;
    final jelly = cfg.instantJelly(
      slot.endsAt.difference(ref.read(clockProvider).now().toUtc()),
    );
    if (jelly <= 0) return;
    final ok = await confirmJellySpend(
      context,
      title: l.researchInstantTitle,
      body: l.researchInstantBody(name, '$level'),
      jelly: jelly,
    );
    if (!ok || !mounted) return;
    final err = await _ctrl.finishResearchWithJelly(id);
    if (err != null && mounted) showCenterToast(context, _errText(l, err));
  }

  Future<void> _buySlot(AppLocalizations l, int jelly) async {
    final ok = await confirmJellySpend(
      context,
      title: l.researchSlotBuyTitle,
      body: l.researchSlotBuyBody,
      jelly: jelly,
      actionLabel: l.researchSlotBuy,
    );
    if (!ok || !mounted) return;
    final err = await _ctrl.buyResearchSlotNow();
    if (err != null && mounted) showCenterToast(context, _errText(l, err));
  }

  // ── 모양 ──

  /// [compact] 는 칸 카드 안 버튼 — 좁은 칸에서도 글자를 줄여 넣는다.
  Widget _smallButton({
    required Key key,
    required VoidCallback? onPressed,
    required Widget child,
    bool compact = false,
  }) => FilledButton(
    key: key,
    onPressed: onPressed,
    style: FilledButton.styleFrom(
      backgroundColor: kHoney,
      foregroundColor: kHoneyInk,
      disabledBackgroundColor: const Color(0x22FFFFFF),
      disabledForegroundColor: Colors.white38,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 12),
      minimumSize: compact ? const Size(0, 28) : const Size(56, 32),
      tapTargetSize: compact ? MaterialTapTargetSize.shrinkWrap : null,
      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
    ),
    child: compact ? FittedBox(fit: BoxFit.scaleDown, child: child) : child,
  );

  Widget _sampleIcon(double size) =>
      Icon(Icons.science_rounded, size: size, color: const Color(0xFF80DEEA));

  /// 연구 아이콘 — research.json `image`, 없으면 효과별 Material 아이콘(§6 폴백).
  Widget _researchIcon(ResearchDef? def, double size, {bool dim = false}) =>
      gameIcon(
        def == null ? 'research' : 'research_${def.id}',
        size: size,
        fallback: def == null ? Icons.science_rounded : _fxIcon(def.effect),
        color: _branchColor(def?.branch),
        dim: dim,
        assetPath: def?.image,
      );

  BoxDecoration _box({Color border = const Color(0x22FFFFFF)}) => BoxDecoration(
    color: const Color(0x55121A10),
    borderRadius: BorderRadius.circular(10),
    border: Border.all(color: border),
  );
}

/// 시작할 수 있음 표시(빨간 점 — 하단 탭 빨간 점과 같은 뜻).
class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) => Container(
    width: 9,
    height: 9,
    decoration: BoxDecoration(
      color: const Color(0xFFE53935),
      shape: BoxShape.circle,
      border: Border.all(color: const Color(0xFF0E1608), width: 1.5),
    ),
  );
}

/// 트리 선 — 부모 카드 아래 → 두 행 사이 → 자식 카드 위로 꺾어 긋는다. 선행을 채웠으면 밝게.
class _TreeLines extends CustomPainter {
  _TreeLines(this.edges);

  final List<({Rect from, Rect to, bool lit})> edges;

  @override
  void paint(Canvas canvas, Size size) {
    Paint pen(Color c) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final dim = pen(const Color(0x40FFFFFF));
    final lit = pen(const Color(0xFFE8D9A8));
    // 어두운 선을 먼저 — 밝은 선이 겹친 마디 위에 남는다.
    for (final pass in [false, true]) {
      for (final e in edges) {
        if (e.lit != pass) continue;
        final x0 = e.from.center.dx, y0 = e.from.bottom;
        final x1 = e.to.center.dx, y1 = e.to.top;
        if (y1 <= y0) continue; // 부모는 늘 자식보다 위 — 데이터가 틀려도 거꾸로 긋지 않는다.
        final mid = y1 - math.min(13.0, (y1 - y0) / 2);
        canvas.drawPath(
          Path()
            ..moveTo(x0, y0)
            ..lineTo(x0, mid)
            ..lineTo(x1, mid)
            ..lineTo(x1, y1),
          pass ? lit : dim,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_TreeLines old) {
    if (old.edges.length != edges.length) return true;
    for (var i = 0; i < edges.length; i++) {
      if (old.edges[i] != edges[i]) return true;
    }
    return false;
  }
}

String _name(ResearchDef def, String locale) =>
    def.name[locale] ?? def.name['en'] ?? def.name['ko'] ?? def.id;

String _errText(AppLocalizations l, String code) => switch (code) {
  'max_level' => l.researchErrMaxLevel,
  'locked' => l.researchErrLocked,
  'slots_full' => l.researchErrSlotsFull,
  'already_running' => l.researchErrRunning,
  'not_enough' => l.researchErrNotEnough,
  'not_enough_jelly' => l.notEnoughJelly,
  'max_slots' => l.researchErrMaxSlots,
  'stale_price' => l.researchErrStale,
  _ => l.researchErrGeneric,
};

String _branchLabel(AppLocalizations l, ResearchBranch b) => switch (b) {
  ResearchBranch.hunt => l.researchBranchHunt,
  ResearchBranch.nurture => l.researchBranchNurture,
  ResearchBranch.duel => l.researchBranchDuel,
  ResearchBranch.gear => l.researchBranchGear,
  ResearchBranch.economy => l.researchBranchEconomy,
};

Color _branchColor(ResearchBranch? b) => switch (b) {
  ResearchBranch.hunt => const Color(0xFFFFB74D),
  ResearchBranch.nurture => const Color(0xFFAED581),
  ResearchBranch.duel => const Color(0xFFE57373),
  ResearchBranch.gear => const Color(0xFF90CAF9),
  ResearchBranch.economy => kHoney,
  null => kHoney,
};

/// 효과 값 — 단축·낮춤은 −, 확률 덧셈(회피·치명·근성 문턱)은 %p, 나머지는 %.
String _fxValue(AppLocalizations l, ResearchEffect e, double v) {
  final minus =
      e.isTimeCut ||
      e == ResearchEffect.skillCooldown ||
      e == ResearchEffect.duelGrit;
  final pp =
      e == ResearchEffect.huntEvade ||
      e == ResearchEffect.duelCrit ||
      e == ResearchEffect.duelGrit;
  return '${minus ? '−' : '+'}${fmtResearchPct(v)}${pp ? l.researchUnitPp : '%'}';
}

/// 비율 → 퍼센트 숫자(소수 한 자리, 1 미만은 두 자리 — 근성 문턱처럼 작은 값이 0 으로 보이지 않게).
String fmtResearchPct(double v) {
  final p = v * 100;
  final digits = p != 0 && p.abs() < 1 ? 2 : 1;
  var s = p.toStringAsFixed(digits);
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }
  return s;
}

String _fxLabel(AppLocalizations l, ResearchEffect e) => switch (e) {
  ResearchEffect.huntAtk => l.researchFxHuntAtk,
  ResearchEffect.huntHpDef => l.researchFxHuntHpDef,
  ResearchEffect.find => l.researchFxFind,
  ResearchEffect.gold => l.researchFxGold,
  ResearchEffect.bossDmg => l.researchFxBossDmg,
  ResearchEffect.offline => l.researchFxOffline,
  ResearchEffect.hatchTime => l.researchFxHatchTime,
  ResearchEffect.breedTime => l.researchFxBreedTime,
  ResearchEffect.trainTime => l.researchFxTrainTime,
  ResearchEffect.researchTime => l.researchFxResearchTime,
  ResearchEffect.duelAtk => l.researchFxDuelAtk,
  ResearchEffect.duelDef => l.researchFxDuelDef,
  ResearchEffect.duelHp => l.researchFxDuelHp,
  ResearchEffect.injuryTime => l.researchFxInjuryTime,
  ResearchEffect.huntCritDmg => l.researchFxHuntCritDmg,
  ResearchEffect.huntRegen => l.researchFxHuntRegen,
  ResearchEffect.huntEvade => l.researchFxHuntEvade,
  ResearchEffect.huntExp => l.researchFxHuntExp,
  ResearchEffect.skillCooldown => l.researchFxSkillCooldown,
  ResearchEffect.forgeTime => l.researchFxForgeTime,
  ResearchEffect.starTime => l.researchFxStarTime,
  ResearchEffect.polishCost => l.researchFxPolishCost,
  ResearchEffect.traitChance => l.researchFxTraitChance,
  ResearchEffect.potionChance => l.researchFxPotionChance,
  ResearchEffect.salvageMat => l.researchFxSalvageMat,
  ResearchEffect.exchangeGain => l.researchFxExchangeGain,
  ResearchEffect.giftGold => l.researchFxGiftGold,
  ResearchEffect.duelCrit => l.researchFxDuelCrit,
  ResearchEffect.duelGrit => l.researchFxDuelGrit,
};

IconData _fxIcon(ResearchEffect e) => switch (e) {
  ResearchEffect.huntAtk => Icons.flash_on_rounded,
  ResearchEffect.huntHpDef => Icons.shield_rounded,
  ResearchEffect.find => Icons.search_rounded,
  ResearchEffect.gold => Icons.monetization_on_rounded,
  ResearchEffect.bossDmg => Icons.whatshot_rounded,
  ResearchEffect.offline => Icons.bedtime_rounded,
  ResearchEffect.hatchTime => Icons.egg_alt_rounded,
  ResearchEffect.breedTime => Icons.favorite_rounded,
  ResearchEffect.trainTime => Icons.fitness_center_rounded,
  ResearchEffect.researchTime => Icons.science_rounded,
  ResearchEffect.duelAtk => Icons.sports_mma_rounded,
  ResearchEffect.duelDef => Icons.security_rounded,
  ResearchEffect.duelHp => Icons.favorite_border_rounded,
  ResearchEffect.injuryTime => Icons.healing_rounded,
  ResearchEffect.huntCritDmg => Icons.bolt_rounded,
  ResearchEffect.huntRegen => Icons.spa_rounded,
  ResearchEffect.huntEvade => Icons.directions_run_rounded,
  ResearchEffect.huntExp => Icons.trending_up_rounded,
  ResearchEffect.skillCooldown => Icons.timer_rounded,
  ResearchEffect.forgeTime => Icons.construction_rounded,
  ResearchEffect.starTime => Icons.star_rounded,
  ResearchEffect.polishCost => Icons.auto_fix_high_rounded,
  ResearchEffect.traitChance => Icons.account_tree_rounded,
  ResearchEffect.potionChance => Icons.local_drink_rounded,
  ResearchEffect.salvageMat => Icons.recycling_rounded,
  ResearchEffect.exchangeGain => Icons.swap_horiz_rounded,
  ResearchEffect.giftGold => Icons.card_giftcard_rounded,
  ResearchEffect.duelCrit => Icons.gps_fixed_rounded,
  ResearchEffect.duelGrit => Icons.touch_app_rounded,
};

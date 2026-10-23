import 'dart:async';

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

/// 연구소 탭(설계 `docs/superpowers/specs/2026-10-22-research-lab-design.md` §3).
///
/// 위: 연구 재화 보유량 · 연구 칸 1~3(진행 막대·남은 시간·젤리 즉시 완료 / 빈 칸 / 잠긴 칸 + 젤리 구매).
/// 아래: 분야 5묶음(사냥·육성·결투·장비·경제) — 한 줄 = 아이콘·이름·Lv · 지금 → 다음 효과 · 다음 레벨 비용 · [연구].
/// 규칙(가격·시작 조건)은 core_save `research_progress.dart`, 화면은 그 결과(`ResearchOp` 사유)를 그대로 보여 준다.
class ResearchScreen extends ConsumerStatefulWidget {
  const ResearchScreen({super.key});

  @override
  ConsumerState<ResearchScreen> createState() => _ResearchScreenState();
}

class _ResearchScreenState extends ConsumerState<ResearchScreen> {
  Timer? _tick;

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
      setState(() {});
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

  Widget _body(
    AppLocalizations l,
    String locale,
    GameData data,
    SaveGame save,
    ResearchConfig cfg,
  ) {
    final now = ref.read(clockProvider).now().toUtc();
    // 사냥 능력치는 한 번만 — 29줄 가격이 모두 같은 값을 쓴다.
    final stats = data.runConfig == null
        ? null
        : huntStatsOf(
            save,
            data,
            now,
            guildBonus: ref.watch(guildBonusProvider),
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _currencies(l, save),
        const SizedBox(height: 6),
        _slots(l, locale, save, cfg, now),
        const SizedBox(height: 6),
        Expanded(
          // 29줄뿐이라 한 번에 그린다(목록 길이가 고정).
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final branch in ResearchBranch.values) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(2, 8, 2, 4),
                    child: Text(
                      _branchLabel(l, branch),
                      style: const TextStyle(
                        color: kHoney,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  for (final def in cfg.defs)
                    if (def.branch == branch)
                      _row(l, locale, data, save, cfg, def, now, stats),
                ],
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    l.researchHowToGet,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── 위: 재화 ──

  Widget _currencies(AppLocalizations l, SaveGame save) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: _box(),
    child: Wrap(
      spacing: 14,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _tally(
          _sampleIcon(16),
          formatCompact(save.researchSamples),
          tooltip: l.researchSamples,
        ),
        _tally(goldIcon(size: 16), formatCompact(save.gold)),
        _tally(
          materialImage(
            MaterialKind.fossil,
            size: 16,
            fallback: const Icon(Icons.diamond_rounded, size: 14),
          ),
          formatCompact(save.materialCount(MaterialKind.fossil)),
        ),
        _tally(jellyIcon(size: 16), formatCompact(save.materialCount(MaterialKind.jelly))),
      ],
    ),
  );

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

  // ── 위: 연구 칸 ──

  Widget _slots(
    AppLocalizations l,
    String locale,
    SaveGame save,
    ResearchConfig cfg,
    DateTime now,
  ) {
    final open = cfg.slotsFor(save.topTier, save.researchSlotsBought);
    final bought = save.researchSlotsBought;
    // 사면 칸이 실제로 늘어날 때만 판다 — 진행도 칸이 이미 앞서 있으면 산 칸이 늘지 않는다.
    final canBuy =
        bought < cfg.slotJelly.length &&
        cfg.slotsFor(save.topTier, bought + 1) > open;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: _box(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l.researchSlotsTitle('${save.researchSlots.length}', '$open'),
            style: const TextStyle(
              color: kHoney,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          for (var i = 0; i < ResearchConfig.maxSlots; i++) ...[
            const SizedBox(height: 6),
            if (i < save.researchSlots.length)
              _runningSlot(l, locale, save, cfg, save.researchSlots[i], now)
            else if (i < open)
              _slotFrame(
                key: Key('researchSlot$i'),
                child: Text(
                  l.researchSlotEmpty,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              )
            else
              _lockedSlot(
                l,
                cfg,
                i,
                buyPrice: canBuy && i == open ? cfg.slotJelly[bought] : null,
              ),
          ],
        ],
      ),
    );
  }

  Widget _slotFrame({Key? key, required Widget child, Color? border}) =>
      Container(
        key: key,
        constraints: const BoxConstraints(minHeight: 40),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: const Color(0x33000000),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border ?? const Color(0x22FFFFFF)),
        ),
        child: child,
      );

  Widget _runningSlot(
    AppLocalizations l,
    String locale,
    SaveGame save,
    ResearchConfig cfg,
    ResearchSlot r,
    DateTime now,
  ) {
    final def = cfg.byId(r.id);
    final left = r.endsAt.difference(now);
    final done = left <= Duration.zero;
    // 칸에는 시작 시각이 없다 — 이번 레벨의 시간(지금 연구 효율 반영)으로 진행률을 어림한다.
    final cut = researchEffects(
      cfg,
      save.researchLevels,
    ).of(ResearchEffect.researchTime);
    final total = def == null
        ? Duration.zero
        : cfg.timeAt(def, r.level) * (1 - cut);
    final progress = total.inSeconds <= 0
        ? 1.0
        : (1 - left.inSeconds / total.inSeconds).clamp(0.0, 1.0);
    final jelly = cfg.instantJelly(left);
    final name = def == null ? r.id : _name(def, locale);
    return _slotFrame(
      border: const Color(0xAA4FC3F7),
      child: Row(
        children: [
          _researchIcon(def, 26),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l.researchSlotItem(name, '${r.level}'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      done ? '0s' : formatShortDuration(left),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    key: Key('researchSlotBar_${r.id}'),
                    value: progress,
                    minHeight: 6,
                    backgroundColor: const Color(0x33FFFFFF),
                    color: const Color(0xFF4FC3F7),
                  ),
                ),
              ],
            ),
          ),
          if (!done && jelly > 0) ...[
            const SizedBox(width: 8),
            _smallButton(
              key: Key('researchInstant_${r.id}'),
              onPressed: () => _instant(l, name, r, jelly),
              child: jellyPrice(cost: jelly),
            ),
          ],
        ],
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
      child: Row(
        children: [
          const Icon(Icons.lock_rounded, size: 16, color: Colors.white38),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              tier == null ? '' : l.researchSlotOpensAt(tierName(l, tier)),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
          if (buyPrice != null) ...[
            const SizedBox(width: 6),
            _smallButton(
              key: const Key('researchBuySlot'),
              onPressed: () => _buySlot(l, buyPrice),
              child: jellyPrice(cost: buyPrice, label: l.researchSlotBuy),
            ),
          ],
        ],
      ),
    );
  }

  // ── 아래: 연구 한 줄 ──

  Widget _row(
    AppLocalizations l,
    String locale,
    GameData data,
    SaveGame save,
    ResearchConfig cfg,
    ResearchDef def,
    DateTime now,
    CharacterStats? stats,
  ) {
    final lv = save.researchLevels[def.id] ?? 0;
    final maxed = lv >= def.maxLevel;
    final running = save.researchSlots.any((r) => r.id == def.id);
    final price = maxed || stats == null
        ? null
        : researchPriceOf(save, data, def.id, now, stats: stats);
    final error = maxed
        ? 'max_level'
        : price == null
        ? 'unknown_research'
        : startResearch(save, cfg, def.id, now, price).error;
    final cur = cfg.effectAt(def, lv);
    final next = cfg.effectAt(def, lv + 1);
    final fx = _fxLabel(l, def.effect);
    final effectText = maxed
        ? '$fx ${_fxValue(l, def.effect, cur)}'
        : '$fx ${_fxValue(l, def.effect, cur)} → ${_fxValue(l, def.effect, next)}';
    final req = def.requires;
    final reqDef = req == null ? null : cfg.byId(req.id);
    final reason = switch (error) {
      null => null,
      'max_level' => null,
      'already_running' => null,
      'locked' => l.researchLockedReq(
        reqDef == null ? req!.id : _name(reqDef, locale),
        '${req!.level}',
      ),
      _ => _errText(l, error),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
      decoration: _box(
        border: running ? const Color(0xAA4FC3F7) : const Color(0x22FFFFFF),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _researchIcon(def, 30, dim: error == 'locked'),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _name(def, locale),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          l.researchLevel('$lv', '${def.maxLevel}'),
                          style: TextStyle(
                            color: maxed ? kHoney : Colors.white70,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      effectText,
                      style: const TextStyle(
                        color: Color(0xFFB9F6CA),
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (price != null) ...[
            const SizedBox(height: 5),
            _cost(l, save, price),
          ],
          const SizedBox(height: 5),
          Row(
            children: [
              Expanded(
                child: Text(
                  reason ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFFF8A80),
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              _smallButton(
                key: Key('researchStart_${def.id}'),
                onPressed: error == null ? () => _start(l, def.id) : null,
                child: Text(
                  maxed
                      ? l.researchMaxed
                      : running
                      ? l.researchRunning
                      : l.researchStart,
                ),
              ),
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
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
    final matsOk = kRegularMaterials.every(
      (m) => save.materialCount(m) >= p.materialsEach,
    );
    return Wrap(
      spacing: 10,
      runSpacing: 3,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        item(
          const Icon(Icons.schedule_rounded, size: 13, color: Colors.white54),
          formatShortDuration(p.time),
          true,
        ),
        if (p.samples > 0)
          item(
            _sampleIcon(13),
            formatCompact(p.samples),
            save.researchSamples >= p.samples,
          ),
        if (p.gold > 0)
          item(goldIcon(size: 13), formatCompact(p.gold), save.gold >= p.gold),
        if (p.materialsEach > 0)
          item(
            materialImage(
              MaterialKind.chitin,
              size: 13,
              fallback: const Icon(Icons.category_rounded, size: 12),
            ),
            l.researchCostMaterials(formatCompact(p.materialsEach)),
            matsOk,
          ),
        if (p.fossil > 0)
          item(
            materialImage(
              MaterialKind.fossil,
              size: 13,
              fallback: const Icon(Icons.diamond_rounded, size: 12),
            ),
            formatCompact(p.fossil),
            save.materialCount(MaterialKind.fossil) >= p.fossil,
          ),
      ],
    );
  }

  // ── 동작 ──

  Future<void> _start(AppLocalizations l, String id) async {
    final err = await _ctrl.startResearchNow(id);
    if (err != null && mounted) showCenterToast(context, _errText(l, err));
  }

  Future<void> _instant(
    AppLocalizations l,
    String name,
    ResearchSlot r,
    int jelly,
  ) async {
    final ok = await confirmJellySpend(
      context,
      title: l.researchInstantTitle,
      body: l.researchInstantBody(name, '${r.level}'),
      jelly: jelly,
    );
    if (!ok || !mounted) return;
    final err = await _ctrl.finishResearchWithJelly(r.id);
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

  Widget _smallButton({
    required Key key,
    required VoidCallback? onPressed,
    required Widget child,
  }) => FilledButton(
    key: key,
    onPressed: onPressed,
    style: FilledButton.styleFrom(
      backgroundColor: kHoney,
      foregroundColor: kHoneyInk,
      disabledBackgroundColor: const Color(0x22FFFFFF),
      disabledForegroundColor: Colors.white38,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      minimumSize: const Size(56, 32),
      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
    ),
    child: child,
  );

  Widget _sampleIcon(double size) =>
      Icon(Icons.science_rounded, size: size, color: const Color(0xFF80DEEA));

  /// 연구 아이콘 — `assets/images/ui/icon/research_<id>.webp`, 없으면 효과별 Material 아이콘(§6 폴백).
  Widget _researchIcon(ResearchDef? def, double size, {bool dim = false}) =>
      gameIcon(
        def == null ? 'research' : 'research_${def.id}',
        size: size,
        fallback: def == null ? Icons.science_rounded : _fxIcon(def.effect),
        color: _branchColor(def?.branch),
        dim: dim,
      );

  BoxDecoration _box({Color border = const Color(0x22FFFFFF)}) => BoxDecoration(
    color: const Color(0x55121A10),
    borderRadius: BorderRadius.circular(10),
    border: Border.all(color: border),
  );
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

import 'dart:math' as math;

import 'package:core_battle/core_battle.dart';
import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:flutter/material.dart' hide Element;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/game_data.dart';
import '../../domain/providers.dart';
import '../../domain/save_controller.dart';
import '../../domain/save_game.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/art.dart';
import '../../ui/labels.dart';
import 'battle_arena.dart';

const _honey = Color(0xFFEBA52F);

/// 곤충 결투(PvP). 성충 3마리 팀 vs 로컬 생성 상대. 결정론적 simulate 사용.
/// (Supabase 비동기 매칭은 Phase 4 — 지금은 로컬 상대)
class BattleScreen extends ConsumerStatefulWidget {
  const BattleScreen({super.key});

  @override
  ConsumerState<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends ConsumerState<BattleScreen> {
  final _rng = math.Random();
  List<String?> _team = [null, null, null];
  bool _initialized = false;

  double _power(BattleBug b) => b.atk + b.def + b.spd + b.maxHp * 0.15;

  /// 성충 개체 목록.
  List<IndividualBug> _adults(SaveGame save, GameData data, DateTime now) {
    final cfg = data.petConfig;
    return save.bugs.where((b) {
      final st = cfg == null
          ? b.stage
          : effectiveStage(b.stage, b.stageSince, now, cfg);
      return st == LifeStage.adult;
    }).toList();
  }

  Stance _prefStance(Specialty s) => switch (s) {
    Specialty.strike => Stance.attack,
    Specialty.grip => Stance.defend,
    Specialty.toss => Stance.heal,
  };

  BattleBug _toBattleBug(IndividualBug bug, GameData data, String locale) {
    final sp = data.species(bug.speciesId);
    final sm = bug.statMultiplier(sp);
    final enh = data.enhanceConfig;
    double per(BugPart p, double d) => enh?.spec(p).effectPerLevel ?? d;
    final e = bug.enhancement;
    return BattleBug(
      id: bug.id,
      name: sp.name.resolve(locale),
      element: bug.element,
      temperament: bug.temperament,
      preferredStance: _prefStance(sp.specialty),
      maxHp:
          sp.baseStats.hp *
          sm *
          (1 + e.levelOf(BugPart.build) * per(BugPart.build, 0.05)),
      atk:
          sp.baseStats.atk *
          sm *
          (1 + e.levelOf(BugPart.hornJaw) * per(BugPart.hornJaw, 0.04)),
      def:
          sp.baseStats.def *
          sm *
          (1 + e.levelOf(BugPart.cuticle) * per(BugPart.cuticle, 0.04)),
      spd:
          sp.baseStats.spd *
          sm *
          (1 + e.levelOf(BugPart.wing) * per(BugPart.wing, 0.03)),
    );
  }

  /// 내 팀 파워에 맞춘 로컬 상대 3마리 생성(전투용 + 표시용 종 id).
  List<({BattleBug bug, String speciesId})> _genOpponent(
    List<BattleBug> mine,
    GameData data,
    String locale,
  ) {
    final n = mine.length;
    final avgHp = mine.fold(0.0, (s, b) => s + b.maxHp) / n;
    final avgAtk = mine.fold(0.0, (s, b) => s + b.atk) / n;
    final avgDef = mine.fold(0.0, (s, b) => s + b.def) / n;
    final avgSpd = mine.fold(0.0, (s, b) => s + b.spd) / n;
    final species = data.allSpecies;
    return List.generate(3, (i) {
      final sp = species[_rng.nextInt(species.length)];
      final f = 0.85 + _rng.nextDouble() * 0.32; // 0.85~1.17
      return (
        speciesId: sp.id,
        bug: BattleBug(
          id: 'opp$i',
          name: sp.name.resolve(locale),
          element: Element.values[_rng.nextInt(Element.values.length)],
          temperament:
              Temperament.values[_rng.nextInt(Temperament.values.length)],
          preferredStance: _prefStance(sp.specialty),
          maxHp: avgHp * f,
          atk: avgAtk * f,
          def: avgDef * f,
          spd: avgSpd * f,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final data = ref.watch(gameDataProvider).requireValue;
    final save = ref.watch(saveControllerProvider).requireValue;
    final now = ref.read(clockProvider).now().toUtc();
    final locale = Localizations.localeOf(context).languageCode;
    final adults = _adults(save, data, now);

    // 최초 진입: 파워 상위 3마리 자동 편성.
    if (!_initialized) {
      _initialized = true;
      final sorted = [...adults]
        ..sort(
          (a, b) => _power(
            _toBattleBug(b, data, locale),
          ).compareTo(_power(_toBattleBug(a, data, locale))),
        );
      for (var i = 0; i < 3 && i < sorted.length; i++) {
        _team[i] = sorted[i].id;
      }
    }
    // 사라진(진화/분해된) 곤충 정리.
    final adultIds = adults.map((b) => b.id).toSet();
    _team = [for (final id in _team) adultIds.contains(id) ? id : null];

    final teamCount = _team.whereType<String>().length;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.battleTitle),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Center(
              child: Text(
                '🏆 ${save.pvpTrophies}',
                style: const TextStyle(
                  color: _honey,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
      body: adults.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  l.battleNeedBugs,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xB3FFFFFF)),
                ),
              ),
            )
          : Column(
              children: [
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const Icon(Icons.groups_rounded, color: _honey, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        l.battleMyTeam,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      for (var i = 0; i < 3; i++)
                        Expanded(child: _teamSlot(data, save, locale, i)),
                    ],
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                  child: SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton.icon(
                      onPressed: teamCount == 0
                          ? null
                          : () => _battle(data, save, locale),
                      icon: const Icon(Icons.sports_mma_rounded),
                      label: Text(
                        l.battleStart,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFC1502E),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _teamSlot(GameData data, SaveGame save, String locale, int index) {
    final id = _team[index];
    final bug = id == null
        ? null
        : save.bugs.cast<IndividualBug?>().firstWhere(
            (b) => b!.id == id,
            orElse: () => null,
          );
    final sp = bug == null ? null : data.species(bug.speciesId);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: GestureDetector(
        onTap: () => _showPicker(data, save, locale, index),
        child: Container(
          height: 150,
          decoration: BoxDecoration(
            color: const Color(0x22000000),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: bug == null ? const Color(0x33FFFFFF) : _honey,
              width: bug == null ? 1 : 1.6,
            ),
          ),
          child: bug == null
              ? const Center(
                  child: Icon(
                    Icons.add_circle_outline,
                    color: Color(0x66FFFFFF),
                    size: 28,
                  ),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: bugStageImage(
                        bug.speciesId,
                        LifeStage.adult,
                        size: 60,
                        fallback: bugAvatar(sp!, size: 52),
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(bottom: 2),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: elementColor(
                          bug.element,
                        ).withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${elementGlyph(bug.element)} ${elementLabel(AppLocalizations.of(context), bug.element)}',
                        style: TextStyle(
                          color: elementColor(bug.element),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        sp.name.resolve(locale),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                ),
        ),
      ),
    );
  }

  void _showPicker(GameData data, SaveGame save, String locale, int slot) {
    final now = ref.read(clockProvider).now().toUtc();
    final adults = _adults(save, data, now);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xF2141F0E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final l = AppLocalizations.of(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.battlePickTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 340),
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final b in adults)
                          _pickTile(ctx, data, locale, b, slot),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _pickTile(
    BuildContext ctx,
    GameData data,
    String locale,
    IndividualBug bug,
    int slot,
  ) {
    final sp = data.species(bug.speciesId);
    final used = _team.contains(bug.id);
    return GestureDetector(
      onTap: () {
        setState(() {
          // 다른 슬롯에 이미 있으면 제거(중복 방지) 후 배치.
          for (var i = 0; i < 3; i++) {
            if (_team[i] == bug.id) _team[i] = null;
          }
          _team[slot] = bug.id;
        });
        Navigator.pop(ctx);
      },
      child: SizedBox(
        width: 84,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0x22000000),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: used
                  ? _honey
                  : gradeColor(sp.grade).withValues(alpha: 0.7),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              bugStageImage(
                bug.speciesId,
                LifeStage.adult,
                size: 44,
                fallback: bugAvatar(sp, size: 38),
              ),
              const SizedBox(height: 2),
              Text(
                sp.name.resolve(locale),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
              Text(
                'Lv.${bug.level}',
                style: const TextStyle(color: Color(0x99FFFFFF), fontSize: 9),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _battle(GameData data, SaveGame save, String locale) async {
    final speciesOf = <String, String>{};
    final mine = <BattleBug>[];
    for (final id in _team.whereType<String>()) {
      final bug = save.bugs.firstWhere((b) => b.id == id);
      speciesOf[bug.id] = bug.speciesId;
      mine.add(_toBattleBug(bug, data, locale));
    }
    if (mine.isEmpty) return;
    final foeGen = _genOpponent(mine, data, locale);
    final foe = <BattleBug>[];
    for (final e in foeGen) {
      speciesOf[e.bug.id] = e.speciesId;
      foe.add(e.bug);
    }
    final seed = _rng.nextInt(1 << 31);
    final result = simulate(seed, mine, foe);

    final win = result.outcome == BattleOutcome.teamA;
    final draw = result.outcome == BattleOutcome.draw;
    final gold = win ? 4000 + save.pvpTrophies * 30 : 0;
    final trophy = win ? 12 : (draw ? 0 : -8);
    await ref
        .read(saveControllerProvider.notifier)
        .applyBattleResult(gold: gold, trophyDelta: trophy);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BattleArenaScreen(
          data: data,
          myTeam: mine,
          foeTeam: foe,
          speciesOf: speciesOf,
          result: result,
          gold: gold,
          trophyDelta: trophy,
        ),
      ),
    );
  }
}

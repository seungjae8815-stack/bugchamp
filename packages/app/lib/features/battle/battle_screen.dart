import 'dart:async';
import 'dart:math' as math;

import 'package:core_battle/core_battle.dart';
import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:flutter/material.dart' hide Element;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/game_data.dart';
import '../../domain/providers.dart';
import '../../domain/pvp_backend.dart';
import '../../domain/save_controller.dart';
import '../../domain/save_game.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/art.dart';
import '../../ui/format.dart';
import '../../ui/game_dialog.dart';
import '../../ui/labels.dart';
import 'arena_widgets.dart';
import 'battle_arena.dart';
import 'manual_battle_screen.dart';

const _honey = Color(0xFFEBA52F);

/// 스카우트된 상대 후보 1팀(난이도 티어 + 상대 3마리).
/// [ownerName] 이 있으면 **실제 다른 유저**의 방어팀, null 이면 로컬 합성 상대.
class _Scout {
  _Scout({required this.tier, required this.team, this.ownerName});
  final ScoutTier tier;
  final List<({BattleBug bug, String speciesId})> team;
  final String? ownerName;
}

/// 곤충 결투(PvP). 성충 3마리 팀 vs 상대(실제 다른 유저 방어팀 또는 로컬 합성).
/// 결정론적 simulate 사용. Supabase 연동 시 스카우트 보드가 실 유저 방어팀으로 채워진다.
class BattleScreen extends ConsumerStatefulWidget {
  const BattleScreen({super.key});

  @override
  ConsumerState<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends ConsumerState<BattleScreen> {
  final _rng = math.Random();
  List<String?> _team = [null, null, null];
  bool _initialized = false;

  List<_Scout> _scouts = [];
  int _selectedScout = 1; // 기본 '대등' 티어
  bool _scoutsFetched = false; // 실 유저 방어팀 fetch 를 이번 세션에 시도했는지
  String? _registeredSig; // 마지막으로 등록한 방어팀 시그니처(중복 업서트 방지)

  double _power(BattleBug b) => b.atk + b.def + b.spd + b.maxHp * 0.15;

  PvpProfile _me(SaveGame save) =>
      PvpProfile(id: 'me', nickname: save.nickname, trophies: save.pvpTrophies);

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

  /// 로스터 파워 상위 3마리의 평균 스탯(스카우트 상대 스케일 기준). 성충 없으면 null.
  ({double hp, double atk, double def, double spd})? _rosterAvg(
    List<IndividualBug> adults,
    GameData data,
    String locale,
  ) {
    if (adults.isEmpty) return null;
    final bb = adults.map((b) => _toBattleBug(b, data, locale)).toList()
      ..sort((a, b) => _power(b).compareTo(_power(a)));
    final top = bb.take(3).toList();
    final n = top.length;
    return (
      hp: top.fold(0.0, (s, b) => s + b.maxHp) / n,
      atk: top.fold(0.0, (s, b) => s + b.atk) / n,
      def: top.fold(0.0, (s, b) => s + b.def) / n,
      spd: top.fold(0.0, (s, b) => s + b.spd) / n,
    );
  }

  /// 기준 평균 × [powerMult] 로 상대 3마리 생성. [salt] 로 id 충돌 방지.
  List<({BattleBug bug, String speciesId})> _genFoeTeam(
    ({double hp, double atk, double def, double spd}) avg,
    double powerMult,
    GameData data,
    String locale,
    int salt,
  ) {
    final species = data.allSpecies;
    return List.generate(3, (i) {
      final sp = species[_rng.nextInt(species.length)];
      final f = (0.9 + _rng.nextDouble() * 0.2) * powerMult;
      return (
        speciesId: sp.id,
        bug: BattleBug(
          id: 'opp${salt}_$i',
          name: sp.name.resolve(locale),
          element: Element.values[_rng.nextInt(Element.values.length)],
          temperament:
              Temperament.values[_rng.nextInt(Temperament.values.length)],
          preferredStance: _prefStance(sp.specialty),
          maxHp: avg.hp * f,
          atk: avg.atk * f,
          def: avg.def * f,
          spd: avg.spd * f,
        ),
      );
    });
  }

  /// 스카우트 보드 갱신(난이도 티어별 상대 1팀씩).
  void _rollScouts(
    GameData data,
    String locale,
    ({double hp, double atk, double def, double spd}) avg,
  ) {
    final cfg = data.battleConfig ?? const BattleConfig();
    _scouts = [
      for (var i = 0; i < cfg.scoutTiers.length; i++)
        _Scout(
          tier: cfg.scoutTiers[i],
          team: _genFoeTeam(avg, cfg.scoutTiers[i].powerMult, data, locale, i),
        ),
    ];
    if (_selectedScout >= _scouts.length) _selectedScout = _scouts.length ~/ 2;
  }

  Species? _speciesOrNull(GameData data, String id) {
    try {
      return data.species(id);
    } catch (_) {
      return null;
    }
  }

  double _teamPower(Iterable<BattleBug> team) {
    if (team.isEmpty) return 0;
    return team.map(_power).reduce((a, b) => a + b) / team.length;
  }

  /// 방어팀 스냅샷([dt]) → 전투용 팀. 종을 못 찾으면(데이터 변경) null 로 스킵.
  List<({BattleBug bug, String speciesId})>? _defenderTeam(
    DefenderTeam dt,
    GameData data,
    String locale,
    int salt,
  ) {
    final out = <({BattleBug bug, String speciesId})>[];
    for (var i = 0; i < dt.bugs.length; i++) {
      final d = dt.bugs[i];
      final sp = _speciesOrNull(data, d.speciesId);
      if (sp == null) return null;
      out.add((
        speciesId: d.speciesId,
        bug: BattleBug(
          id: 'def${salt}_$i',
          name: sp.name.resolve(locale),
          element: d.element,
          temperament: d.temperament,
          preferredStance: _prefStance(sp.specialty),
          maxHp: d.maxHp,
          atk: d.atk,
          def: d.def,
          spd: d.spd,
        ),
      ));
    }
    return out.isEmpty ? null : out;
  }

  /// 내 편성([_team]) → 방어팀 스냅샷(서버 등록용).
  DefenderBug _defenderBugOf(IndividualBug bug, GameData data, String locale) {
    final bb = _toBattleBug(bug, data, locale);
    return DefenderBug(
      speciesId: bug.speciesId,
      element: bb.element,
      temperament: bb.temperament,
      maxHp: bb.maxHp,
      atk: bb.atk,
      def: bb.def,
      spd: bb.spd,
    );
  }

  /// 현재 편성을 내 방어팀으로 등록(업서트). 시그니처가 같으면 스킵.
  /// 로컬 백엔드는 no-op — fire-and-forget(에러 무시).
  void _maybeRegisterDefender(GameData data, SaveGame save, String locale) {
    final ids = _team.whereType<String>().toList();
    if (ids.isEmpty) return;
    final sig = '${ids.join(',')}|${save.pvpTrophies}';
    if (sig == _registeredSig) return;
    _registeredSig = sig;
    final team = [
      for (final id in ids)
        _defenderBugOf(save.bugs.firstWhere((b) => b.id == id), data, locale),
    ];
    ref.read(pvpBackendProvider).registerDefender(me: _me(save), team: team);
  }

  /// [ratio] 에 powerMult 가 가장 가까운 **빈** 티어 슬롯 index. 없으면 -1.
  int _closestFreeTier(
    double ratio,
    List<_Scout?> slots,
    List<ScoutTier> tiers,
  ) {
    var best = -1;
    var bestD = double.infinity;
    for (var i = 0; i < tiers.length; i++) {
      if (slots[i] != null) continue;
      final d = (tiers[i].powerMult - ratio).abs();
      if (d < bestD) {
        bestD = d;
        best = i;
      }
    }
    return best;
  }

  /// 실 유저 방어팀을 fetch 해 스카우트 보드에 병합.
  /// 각 방어팀을 내 로스터 대비 파워 비율로 난이도 티어에 배치하고,
  /// 남는 티어는 로컬 합성 상대로 채운다(실데이터가 없으면 전부 합성 유지).
  Future<void> _fetchRealScouts(
    GameData data,
    String locale,
    ({double hp, double atk, double def, double spd}) avg,
    SaveGame save,
  ) async {
    final backend = ref.read(pvpBackendProvider);
    final cfg = data.battleConfig ?? const BattleConfig();
    final tiers = cfg.scoutTiers;
    final reals = await backend.fetchOpponents(
      me: _me(save),
      count: tiers.length,
    );
    if (!mounted || reals.isEmpty) return;

    final myPower = avg.atk + avg.def + avg.spd + avg.hp * 0.15;
    // 실 방어팀 → (전투팀, 파워비율). 종을 못 찾으면 스킵.
    final built =
        <
          ({
            List<({BattleBug bug, String speciesId})> team,
            double ratio,
            String owner,
          })
        >[];
    for (var r = 0; r < reals.length; r++) {
      final team = _defenderTeam(reals[r], data, locale, r);
      if (team == null) continue;
      final ratio =
          _teamPower(team.map((e) => e.bug)) / (myPower <= 0 ? 1 : myPower);
      built.add((team: team, ratio: ratio, owner: reals[r].ownerName));
    }
    if (built.isEmpty) return;

    // 파워 낮은 순으로 가장 가까운 빈 티어에 배치(약→easy, 강→hard 경향).
    built.sort((a, b) => a.ratio.compareTo(b.ratio));
    final slots = List<_Scout?>.filled(tiers.length, null);
    for (final b in built) {
      final idx = _closestFreeTier(b.ratio, slots, tiers);
      if (idx < 0) break;
      slots[idx] = _Scout(tier: tiers[idx], team: b.team, ownerName: b.owner);
    }
    // 빈 티어는 로컬 합성 상대로 채움.
    for (var i = 0; i < tiers.length; i++) {
      slots[i] ??= _Scout(
        tier: tiers[i],
        team: _genFoeTeam(avg, tiers[i].powerMult, data, locale, 100 + i),
      );
    }
    setState(() {
      _scouts = [for (final s in slots) s!];
      if (_selectedScout >= _scouts.length) {
        _selectedScout = _scouts.length ~/ 2;
      }
    });
  }

  /// 티어 id → 현지화 라벨/색.
  (String, Color) _tierStyle(AppLocalizations l, String id) => switch (id) {
    'easy' => (l.scoutEasy, const Color(0xFF6FCF6F)),
    'even' => (l.scoutEven, const Color(0xFFE9D9A6)),
    'hard' => (l.scoutHard, const Color(0xFFEF6B4A)),
    _ => (id, const Color(0xFFBFC4CC)),
  };

  /// 리그 id → 현지화 라벨·색·엠블럼.
  (String, Color, String) _leagueStyle(AppLocalizations l, String id) =>
      switch (id) {
        'bronze' => (l.leagueBronze, const Color(0xFFB87333), '🥉'),
        'silver' => (l.leagueSilver, const Color(0xFFB8C4CE), '🥈'),
        'gold' => (l.leagueGold, const Color(0xFFEBC24A), '🥇'),
        'platinum' => (l.leaguePlatinum, const Color(0xFF5FD3C8), '💠'),
        'diamond' => (l.leagueDiamond, const Color(0xFF6FA8FF), '💎'),
        _ => (id, const Color(0xFFBFC4CC), '🏅'),
      };

  /// 시즌 종료까지 남은 시간 표기(일 포함). "13d 04:22" / "04:22".
  String _seasonLeft(Duration d) {
    if (d.isNegative) d = Duration.zero;
    final days = d.inDays;
    final h = d.inHours % 24;
    final m = d.inMinutes % 60;
    final hm =
        '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
    return days > 0 ? '${days}d $hm' : hm;
  }

  /// 리그 패널 — 현재 등급 엠블럼·트로피·다음 티어 진행바·시즌 카운트다운·승급 보상 수령.
  Widget _leaguePanel(
    AppLocalizations l,
    BattleConfig cfg,
    SaveGame save,
    DateTime now,
  ) {
    final trophies = save.pvpTrophies;
    final cur = cfg.leagueFor(trophies);
    final next = cfg.nextLeagueAfter(cur);
    final progress = cfg.leagueProgress(trophies);
    final claimable = cfg.claimableLeagues(trophies, save.claimedLeagues);
    final (label, color, emoji) = _leagueStyle(l, cur.id);
    // 시즌 종료 = 시작 + seasonDays. 시작 미기록이면 지금을 시작으로 간주.
    final seasonStart = save.seasonStartedAt ?? now;
    final seasonRemaining = seasonStart
        .add(Duration(days: cfg.seasonDays))
        .difference(now);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0x22000000),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              Text(
                '🏆 $trophies',
                style: const TextStyle(
                  color: _honey,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: const Color(0x33000000),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(
                Icons.hourglass_bottom_rounded,
                size: 12,
                color: Color(0x99FFFFFF),
              ),
              const SizedBox(width: 3),
              Text(
                l.seasonEndsIn(_seasonLeft(seasonRemaining)),
                style: const TextStyle(color: Color(0x99FFFFFF), fontSize: 11),
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  next == null
                      ? l.leagueMaxRank
                      : l.leagueToNext(
                          next.minTrophy - trophies,
                          _leagueStyle(l, next.id).$1,
                        ),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0x99FFFFFF),
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          if (claimable.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 40,
              child: FilledButton.icon(
                onPressed: () => _claimLeague(l),
                icon: const Icon(Icons.military_tech_rounded, size: 18),
                label: Text(
                  l.leagueClaimReward,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF3E7D4F),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _claimLeague(AppLocalizations l) async {
    final r = await ref
        .read(saveControllerProvider.notifier)
        .claimLeagueRewards();
    if (r == null || !mounted) return;
    await showGameDialog<void>(
      context,
      title: l.leaguePromoTitle,
      icon: Icons.military_tech_rounded,
      content: Text(
        '💰 ${formatCompact(r.gold)}    💎 ${r.jelly}',
        style: const TextStyle(
          color: Color(0xFFEBD24A),
          fontWeight: FontWeight.w900,
          fontSize: 18,
        ),
      ),
      actions: [gameDialogButton(l.actionClose, () => Navigator.pop(context))],
    );
  }

  Future<void> _showSeasonEnd(SeasonReport r) async {
    if (!mounted) return;
    final l = AppLocalizations.of(context);
    final cfg =
        ref.read(gameDataProvider).requireValue.battleConfig ??
        const BattleConfig();
    final peakLabel = _leagueStyle(l, cfg.leagueFor(r.peakTrophies).id).$1;
    final hasReward = r.rewardGold > 0 || r.rewardJelly > 0;
    await showGameDialog<void>(
      context,
      title: l.seasonEndTitle,
      icon: Icons.workspace_premium_rounded,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            l.seasonPeak(peakLabel),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l.seasonTrophyReset(r.fromTrophies, r.toTrophies),
            style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 13),
          ),
          if (hasReward) ...[
            const SizedBox(height: 12),
            Text(
              '💰 ${formatCompact(r.rewardGold)}    💎 ${r.rewardJelly}',
              style: const TextStyle(
                color: Color(0xFFEBD24A),
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
          ],
        ],
      ),
      actions: [gameDialogButton(l.actionClose, () => Navigator.pop(context))],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final data = ref.watch(gameDataProvider).requireValue;
    final save = ref.watch(saveControllerProvider).requireValue;
    final now = ref.read(clockProvider).now().toUtc();
    final locale = Localizations.localeOf(context).languageCode;
    final adults = _adults(save, data, now);

    // 최초 진입: 파워 상위 3마리 자동 편성(부상 곤충 제외).
    if (!_initialized) {
      _initialized = true;
      final sorted =
          [
            for (final b in adults)
              if (!save.isInjured(b.id, now)) b,
          ]..sort(
            (a, b) => _power(
              _toBattleBug(b, data, locale),
            ).compareTo(_power(_toBattleBug(a, data, locale))),
          );
      for (var i = 0; i < 3 && i < sorted.length; i++) {
        _team[i] = sorted[i].id;
      }
    }
    // 사라진(진화/분해) · 부상당한 곤충은 편성에서 자동 제외.
    final adultIds = adults.map((b) => b.id).toSet();
    _team = [
      for (final id in _team)
        (id != null && adultIds.contains(id) && !save.isInjured(id, now))
            ? id
            : null,
    ];

    final teamCount = _team.whereType<String>().length;

    // 스카우트 보드: 로스터가 있으면 합성 상대로 즉시 채우고(빈 보드 방지),
    // 실 유저 방어팀은 비동기로 fetch 해 병합(있으면 교체).
    final battleCfg = data.battleConfig ?? const BattleConfig();
    final avg = _rosterAvg(adults, data, locale);
    if (avg != null && _scouts.isEmpty) _rollScouts(data, locale, avg);
    if (avg != null && !_scoutsFetched) {
      _scoutsFetched = true;
      _fetchRealScouts(data, locale, avg, save);
    }
    // 현재 편성을 내 방어팀으로 등록(다른 유저가 나를 상대하게).
    _maybeRegisterDefender(data, save, locale);
    final canBattle = teamCount > 0 && _scouts.isNotEmpty;

    // 시즌 종료 정산(로드 시 계산됨) → 1회 다이얼로그.
    final notifier = ref.read(saveControllerProvider.notifier);
    final season = notifier.pendingSeason;
    if (season != null) {
      notifier.consumeSeason();
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _showSeasonEnd(season),
      );
    }

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
          : SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  _leaguePanel(l, battleCfg, save, now),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.groups_rounded,
                          color: _honey,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          l.battleMyTeam,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                        const Spacer(),
                        const Icon(
                          Icons.drag_indicator_rounded,
                          color: Color(0x88FFFFFF),
                          size: 15,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          l.teamReorderHint,
                          style: const TextStyle(
                            color: Color(0x88FFFFFF),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
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
                  const SizedBox(height: 8),
                  _synergyBar(l, data, save, locale),
                  const SizedBox(height: 14),
                  // ── 스카우트 보드 ──
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.travel_explore_rounded,
                          color: _honey,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          l.scoutBoard,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: avg == null
                              ? null
                              : () {
                                  setState(
                                    () => _rollScouts(data, locale, avg),
                                  );
                                  _fetchRealScouts(data, locale, avg, save);
                                },
                          icon: const Icon(
                            Icons.smart_display_rounded,
                            size: 16,
                          ),
                          label: Text(l.scoutRefresh),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFFE9D9A6),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i < _scouts.length; i++)
                          Expanded(
                            child: _scoutCard(l, data, battleCfg, save, i),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: Column(
                      children: [
                        // 수동 전투(심리전) — 헤드라인
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: FilledButton.icon(
                            onPressed: canBattle
                                ? () => _battleManual(
                                    data,
                                    save,
                                    locale,
                                    _scouts[_selectedScout],
                                  )
                                : null,
                            icon: const Icon(Icons.psychology_rounded),
                            label: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  l.battleManual,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Text(
                                  l.battleManualDesc,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xCCFFFFFF),
                                  ),
                                ),
                              ],
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFC1502E),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        // 자동 전투 — 빠른 진행
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: OutlinedButton.icon(
                            onPressed: canBattle
                                ? () => _battle(
                                    data,
                                    save,
                                    locale,
                                    _scouts[_selectedScout],
                                  )
                                : null,
                            icon: const Icon(
                              Icons.fast_forward_rounded,
                              size: 20,
                            ),
                            label: Text(
                              l.battleAuto,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFE9D9A6),
                              side: const BorderSide(color: Color(0x55EBA52F)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  /// 슬롯 [from] 의 곤충을 [to] 위치로 이동(삽입 재배치, 나머지는 밀림).
  /// 오행 상생(生)이 앞→뒤 인접으로 작동하므로 순서가 곧 전략.
  void _reorderSlots(int from, int to) {
    if (from == to) return;
    final item = _team.removeAt(from);
    _team.insert(to, item);
  }

  /// 드래그 중 손가락을 따라오는 축소 피드백(종 초상).
  Widget _dragFeedback(IndividualBug bug, Species sp) => Material(
    type: MaterialType.transparency,
    child: Transform.translate(
      offset: const Offset(-30, -30),
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: const Color(0xE6141F0E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _honey, width: 1.6),
        ),
        child: bugStageImage(
          bug.speciesId,
          LifeStage.adult,
          size: 48,
          fallback: bugAvatar(sp, size: 42),
        ),
      ),
    ),
  );

  Widget _teamSlot(GameData data, SaveGame save, String locale, int index) {
    final id = _team[index];
    final bug = id == null
        ? null
        : save.bugs.cast<IndividualBug?>().firstWhere(
            (b) => b!.id == id,
            orElse: () => null,
          );
    final sp = bug == null ? null : data.species(bug.speciesId);
    final card = GestureDetector(
      onTap: () => _showPicker(data, save, locale, index),
      child: Container(
        width: double.infinity, // 셀(1/3)을 꽉 채워 3슬롯 균등 정렬
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
                      color: elementColor(bug.element).withValues(alpha: 0.25),
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
    );
    // 채워진 슬롯은 드래그 가능(탭=선택 유지). 빈 슬롯은 드롭 대상만.
    final Widget content = (bug == null)
        ? card
        : Draggable<int>(
            data: index,
            dragAnchorStrategy: pointerDragAnchorStrategy,
            feedback: _dragFeedback(bug, sp!),
            childWhenDragging: Opacity(opacity: 0.35, child: card),
            child: card,
          );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: DragTarget<int>(
        onWillAcceptWithDetails: (d) => d.data != index,
        onAcceptWithDetails: (d) =>
            setState(() => _reorderSlots(d.data, index)),
        builder: (ctx, candidate, rejected) => Stack(
          clipBehavior: Clip.none,
          children: [
            content,
            // 드롭 대상 하이라이트.
            if (candidate.isNotEmpty)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      color: _honey.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _honey, width: 2),
                    ),
                  ),
                ),
              ),
            // 전투 순서 배지 ①②③
            Positioned(top: -6, left: -2, child: _orderBadge(index)),
          ],
        ),
      ),
    );
  }

  Widget _orderBadge(int index) => Container(
    width: 19,
    height: 19,
    decoration: const BoxDecoration(color: _honey, shape: BoxShape.circle),
    alignment: Alignment.center,
    child: Text(
      '${index + 1}',
      style: const TextStyle(
        color: Color(0xFF3A2600),
        fontSize: 11,
        fontWeight: FontWeight.w900,
      ),
    ),
  );

  /// 편성 순서대로 오행 상생(生) 연결·팀 시너지% 미리보기.
  Widget _synergyBar(
    AppLocalizations l,
    GameData data,
    SaveGame save,
    String locale,
  ) {
    final mine = [
      for (final id in _team.whereType<String>())
        _toBattleBug(save.bugs.firstWhere((b) => b.id == id), data, locale),
    ];
    if (mine.length < 2) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Text(
          l.synergyHint,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0x77FFFFFF), fontSize: 10.5),
        ),
      );
    }
    final pct = ((teamSynergy(mine) - 1) * 100).round();
    final active = pct > 0;
    final color = active ? const Color(0xFF6FCF6F) : const Color(0xFFBFC4CC);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < mine.length; i++) ...[
          if (i > 0) _linkGlyph(mine[i - 1].element.generates(mine[i].element)),
          Text(
            elementGlyph(mine[i].element),
            style: const TextStyle(fontSize: 15),
          ),
        ],
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '${l.synergyLabel} ${active ? '+' : ''}$pct%',
            style: TextStyle(
              color: active ? const Color(0xFF6FCF6F) : const Color(0xCCFFFFFF),
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }

  Widget _linkGlyph(bool gen) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Text(
      gen ? '→' : '·',
      style: TextStyle(
        color: gen ? const Color(0xFF6FCF6F) : const Color(0x55FFFFFF),
        fontSize: gen ? 16 : 15,
        fontWeight: FontWeight.w900,
      ),
    ),
  );

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
                          _pickTile(ctx, data, save, locale, now, b, slot),
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
    SaveGame save,
    String locale,
    DateTime now,
    IndividualBug bug,
    int slot,
  ) {
    final sp = data.species(bug.speciesId);
    final used = _team.contains(bug.id);
    final until = save.injuredUntil(bug.id);
    final injured = until != null && now.isBefore(until);
    return Opacity(
      opacity: injured ? 0.45 : 1,
      child: GestureDetector(
        onTap: injured
            ? null
            : () {
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
                color: injured
                    ? const Color(0x66EF9A9A)
                    : (used
                          ? _honey
                          : gradeColor(sp.grade).withValues(alpha: 0.7)),
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
                injured
                    ? Text(
                        '🩹 ${formatClock(until.difference(now))}',
                        style: const TextStyle(
                          color: Color(0xFFEF9A9A),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    : Text(
                        'Lv.${bug.level}',
                        style: const TextStyle(
                          color: Color(0x99FFFFFF),
                          fontSize: 9,
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 편성된 팀 + 선택한 스카우트 상대 → 전투용 팀·표시용 종 맵·시드.
  ({
    List<BattleBug> mine,
    List<BattleBug> foe,
    Map<String, String> speciesOf,
    int seed,
  })
  _buildMatch(GameData data, SaveGame save, String locale, _Scout scout) {
    final speciesOf = <String, String>{};
    final mine = <BattleBug>[];
    for (final id in _team.whereType<String>()) {
      final bug = save.bugs.firstWhere((b) => b.id == id);
      speciesOf[bug.id] = bug.speciesId;
      mine.add(_toBattleBug(bug, data, locale));
    }
    final foe = <BattleBug>[];
    for (final e in scout.team) {
      speciesOf[e.bug.id] = e.speciesId;
      foe.add(e.bug);
    }
    return (
      mine: mine,
      foe: foe,
      speciesOf: speciesOf,
      seed: _rng.nextInt(1 << 31),
    );
  }

  Future<void> _applyReward(
    int gold,
    int trophyDelta,
    List<String> koedBugIds,
  ) async {
    await ref
        .read(saveControllerProvider.notifier)
        .applyBattleResult(
          gold: gold,
          trophyDelta: trophyDelta,
          koedBugIds: koedBugIds,
        );
    // 승패 반영 후 트로피를 백엔드에 즉시 push(비동기 대전 라이브).
    // 네트워크가 UI(아레나 전환)를 막지 않도록 fire-and-forget.
    final save = ref.read(saveControllerProvider).requireValue;
    unawaited(ref.read(pvpBackendProvider).pushTrophies(me: _me(save)));
  }

  /// 자동 전투 — 결정론 simulate 후 아레나 재생.
  Future<void> _battle(
    GameData data,
    SaveGame save,
    String locale,
    _Scout scout,
  ) async {
    final m = _buildMatch(data, save, locale, scout);
    if (m.mine.isEmpty) return;
    final cfg = data.battleConfig ?? const BattleConfig();
    final result = simulate(m.seed, m.mine, m.foe);
    final rw = pvpReward(
      result.outcome,
      save.pvpTrophies,
      cfg,
      rewardMult: scout.tier.rewardMult,
    );
    await _applyReward(
      rw.gold,
      rw.trophyDelta,
      koedTeamAIds(m.mine, result.events),
    );
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BattleArenaScreen(
          data: data,
          myTeam: m.mine,
          foeTeam: m.foe,
          speciesOf: m.speciesOf,
          result: result,
          gold: rw.gold,
          trophyDelta: rw.trophyDelta,
        ),
      ),
    );
  }

  /// 수동 전투 — 심리전. 보상은 결착 후 적용(승패가 그때 결정).
  Future<void> _battleManual(
    GameData data,
    SaveGame save,
    String locale,
    _Scout scout,
  ) async {
    final m = _buildMatch(data, save, locale, scout);
    if (m.mine.isEmpty) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ManualBattleScreen(
          data: data,
          myTeam: m.mine,
          foeTeam: m.foe,
          speciesOf: m.speciesOf,
          seed: m.seed,
          trophiesAtStart: save.pvpTrophies,
          config: data.battleConfig ?? const BattleConfig(),
          rewardMult: scout.tier.rewardMult,
          onApply: _applyReward,
        ),
      ),
    );
  }

  /// 스카우트 카드 — 난이도 배지·상대 3마리 미리보기·승리 보상, 탭하면 선택.
  Widget _scoutCard(
    AppLocalizations l,
    GameData data,
    BattleConfig cfg,
    SaveGame save,
    int index,
  ) {
    final scout = _scouts[index];
    final selected = index == _selectedScout;
    final (label, color) = _tierStyle(l, scout.tier.id);
    final gold = cfg.winGold(save.pvpTrophies, scout.tier.rewardMult);
    final trophy = cfg.trophyOnWin(scout.tier.rewardMult);
    return GestureDetector(
      onTap: () => setState(() => _selectedScout = index),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.14)
              : const Color(0x22000000),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : const Color(0x33FFFFFF),
            width: selected ? 1.8 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            // 실제 다른 유저 방어팀이면 닉네임 표시(합성 상대는 미표시).
            if (scout.ownerName != null) ...[
              const SizedBox(height: 3),
              Text(
                '👤 ${scout.ownerName}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xCCE9D9A6),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final e in scout.team)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: bugStageImage(
                      e.speciesId,
                      LifeStage.adult,
                      size: 26,
                      fallback: Text(
                        elementGlyph(e.bug.element),
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '💰${formatCompact(gold)}',
              style: const TextStyle(
                color: Color(0xFFEBD24A),
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              '🏆+$trophy',
              style: const TextStyle(
                color: Color(0xFFE9D9A6),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

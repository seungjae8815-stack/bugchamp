import 'dart:async';

import 'package:core_battle/core_battle.dart';
import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/game_data.dart';
import '../../domain/game_server.dart';
import '../../domain/save_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/art.dart';
import '../../ui/format.dart';
import '../../ui/labels.dart';
import '../../ui/toast.dart';

const _honey = Color(0xFFEBA52F);

/// 이벤트 도전 — **서버와 대화하며 한 웨이브씩** 진행한다.
///
/// 흐름: `/event/start`(1웨이브) → 재생 → **카드 3장 중 1장 선택** →
/// `/event/pick`(다음 웨이브) → 재생 → … → 판 종료.
///
/// 점수는 서버가 확정한다. 앱이 하는 계산은 **연출뿐**이며, 서버가 준 seed·체력·
/// 버프로 같은 판을 다시 그린다(`core_battle` 결정론 §2.3).
class EventBattleScreen extends ConsumerStatefulWidget {
  const EventBattleScreen({
    super.key,
    required this.data,
    required this.team,
    required this.first,
  });

  final GameData data;

  /// 출전한 곤충(순서 그대로).
  final List<IndividualBug> team;

  /// `/event/start` 응답.
  final Map<String, dynamic> first;

  @override
  ConsumerState<EventBattleScreen> createState() => _EventBattleScreenState();
}

class _EventBattleScreenState extends ConsumerState<EventBattleScreen> {
  late Map<String, dynamic> _res;
  BattleState? _battle;
  List<BattleBug> _units = const [];
  List<BattleBug> _enemies = const [];
  List<double> _hpShown = const [];
  int _enemyIdx = 0;
  bool _replaying = false;
  bool _busy = false;
  bool _fast = false;
  Timer? _timer;

  EventConfig get _cfg => widget.data.eventConfig ?? const EventConfig();
  int get _seed => (_res['seed'] as num?)?.toInt() ?? 0;
  int get _wave => (_res['wave'] as num?)?.toInt() ?? 1;
  bool get _done => _res['done'] == true;
  List<Map<String, dynamic>> get _cards =>
      ((_res['cards'] as List?) ?? const []).cast<Map<String, dynamic>>();

  @override
  void initState() {
    super.initState();
    _res = widget.first;
    _replayCurrentWave();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// 서버가 확정한 이번 웨이브를 **처음부터** 다시 그린다.
  ///
  /// 시작 체력은 직전 웨이브 종료 상태여야 하는데, 서버 응답의 `hp` 는 이미
  /// **끝난 뒤**의 값이다. 그래서 재생은 "만피 → 결과"가 아니라
  /// **직전 상태 → 결과**로 맞춰야 한다. 첫 웨이브만 만피로 시작한다.
  void _replayCurrentWave({List<double>? from}) {
    final buffs = EventBuffs.fromJson(
      (_res['buffs'] as Map?)?.cast<String, dynamic>(),
    );
    _units = [
      for (final bug in widget.team)
        if (widget.data.speciesById[bug.speciesId] != null)
          () {
            final sp = widget.data.speciesById[bug.speciesId]!;
            final n = _cfg.normalized(sp.grade);
            return buildEventBug(
              bug: bug,
              species: sp,
              locale: 'ko',
              hp: n.hp * (1 + buffs.maxHp),
              atk: n.atk * (1 + buffs.atk),
              def: n.def * (1 + buffs.def),
              spd: n.spd,
            );
          }(),
    ];
    if (_units.length != widget.team.length) {
      // 종을 못 찾으면 재생만 건너뛴다 — 점수는 서버 것이 이미 확정돼 있다.
      setState(() => _replaying = false);
      return;
    }

    _enemies = eventWaveEnemies(
      _seed,
      _wave,
      WaveEnemySpec(
        baseHp: _cfg.enemyBaseHp,
        baseAtk: _cfg.enemyBaseAtk,
        baseDef: _cfg.enemyBaseDef,
        baseSpd: _cfg.enemyBaseSpd,
        growth: _cfg.enemyGrowth,
        count: _cfg.enemyCount,
      ),
    );
    // 건너뛴 웨이브(우회로 카드)는 싸우지 않았으므로 재생할 게 없다.
    if (_res['skipped'] == true) {
      setState(() {
        _replaying = false;
        _hpShown = _serverHp();
      });
      return;
    }
    _battle = initBattle(
      _seed + _wave * 7919,
      _units,
      _enemies,
      initialHpA: from,
    );
    _hpShown = [for (final u in _units) from == null ? u.maxHp : 0];
    if (from != null) {
      for (var i = 0; i < _hpShown.length && i < from.length; i++) {
        _hpShown[i] = from[i];
      }
    }
    setState(() {
      _replaying = true;
      _enemyIdx = 0;
    });
    _loop();
  }

  List<double> _serverHp() => [
    for (final v in ((_res['hp'] as List?) ?? const [])) (v as num).toDouble(),
  ];

  void _loop() {
    _timer?.cancel();
    _timer = Timer.periodic(
      Duration(milliseconds: _fast ? 70 : 300),
      (_) => _tick(),
    );
  }

  void _tick() {
    final st = _battle;
    if (st == null) return;
    if (st.done) {
      _timer?.cancel();
      setState(() {
        _replaying = false;
        // 재생이 끝나면 **서버가 준 체력**으로 맞춘다(클리어 회복까지 반영된 값).
        _hpShown = _serverHp();
      });
      return;
    }
    st.step();
    setState(() {
      for (var i = 0; i < _hpShown.length && i < st.hpA.length; i++) {
        _hpShown[i] = st.hpA[i];
      }
      _enemyIdx = st.b;
    });
  }

  Future<void> _pick(String cardId) async {
    if (_busy) return;
    setState(() => _busy = true);
    final sid = '${_res['sessionId']}';
    final r = await ref.read(gameServerProvider).eventPick(sid, cardId);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!r.isOk) {
      showCenterToast(context, AppLocalizations.of(context).cloudFailed);
      return;
    }
    final save = r.save;
    if (save != null) {
      await ref.read(saveControllerProvider.notifier).adoptServerSave(save);
    }
    if (!mounted) return;
    final before = _hpShown;
    setState(() => _res = {..._res, ...?r.data});
    _replayCurrentWave(from: before);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFF10190A),
      body: SafeArea(
        child: Column(
          children: [
            _header(l),
            Expanded(child: _arena(l)),
            if (_replaying)
              _speedButton(l)
            else if (_done)
              _result(l)
            else
              _cardPicker(l),
          ],
        ),
      ),
    );
  }

  Widget _header(AppLocalizations l) {
    final buffs = EventBuffs.fromJson(
      (_res['buffs'] as Map?)?.cast<String, dynamic>(),
    );
    final parts = <String>[
      if (buffs.atk > 0) '⚔ +${(buffs.atk * 100).round()}%',
      if (buffs.def > 0) '🛡 +${(buffs.def * 100).round()}%',
      if (buffs.maxHp > 0) '❤ +${(buffs.maxHp * 100).round()}%',
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Row(
        children: [
          Text(
            l.eventWaveRecord(_wave),
            style: const TextStyle(
              color: _honey,
              fontWeight: FontWeight.w900,
              fontSize: 20,
            ),
          ),
          const Spacer(),
          if (parts.isNotEmpty)
            Text(
              parts.join('  '),
              style: const TextStyle(
                color: Color(0xFF9CE37D),
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
        ],
      ),
    );
  }

  Widget _arena(AppLocalizations l) {
    final st = _battle;
    final foe = (_replaying && _enemyIdx < _enemies.length)
        ? _enemies[_enemyIdx]
        : null;
    return Column(
      children: [
        SizedBox(
          height: 96,
          child: foe == null
              ? const SizedBox.shrink()
              : Column(
                  children: [
                    Text(
                      elementGlyph(foe.element),
                      style: const TextStyle(fontSize: 38),
                    ),
                    Text(
                      '${l.battleFoe} ${_enemyIdx + 1}/${_enemies.length}',
                      style: const TextStyle(
                        color: Color(0x99FFFFFF),
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 3),
                    SizedBox(
                      width: 150,
                      child: _bar(
                        st != null && _enemyIdx < st.hpB.length
                            ? st.hpB[_enemyIdx] / foe.maxHp
                            : 1,
                        const Color(0xFFFF8A65),
                      ),
                    ),
                  ],
                ),
        ),
        const Divider(color: Color(0x22FFFFFF)),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            itemCount: _units.length,
            itemBuilder: (c, i) {
              final u = _units[i];
              final bug = i < widget.team.length ? widget.team[i] : null;
              final sp = bug == null
                  ? null
                  : widget.data.speciesById[bug.speciesId];
              final hp = i < _hpShown.length ? _hpShown[i] : 0.0;
              final down = hp <= 0;
              final fighting = _replaying && _battle?.a == i && !down;
              return Opacity(
                opacity: down ? 0.35 : 1,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 3),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: fighting
                        ? _honey.withValues(alpha: 0.14)
                        : const Color(0x18000000),
                    borderRadius: BorderRadius.circular(10),
                    border: fighting
                        ? Border.all(color: _honey.withValues(alpha: 0.7))
                        : null,
                  ),
                  child: Row(
                    children: [
                      if (bug != null && sp != null)
                        bugStageImage(
                          bug.speciesId,
                          LifeStage.adult,
                          size: 32,
                          fallback: bugAvatar(sp, size: 28),
                        ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${i + 1}. ${u.name} ${elementGlyph(u.element)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 12.5,
                              ),
                            ),
                            const SizedBox(height: 3),
                            _bar(
                              u.maxHp <= 0 ? 0 : hp / u.maxHp,
                              const Color(0xFF7BC96F),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _bar(double r, Color c) => ClipRRect(
    borderRadius: BorderRadius.circular(999),
    child: LinearProgressIndicator(
      value: r.clamp(0.0, 1.0),
      minHeight: 6,
      backgroundColor: const Color(0x33FFFFFF),
      valueColor: AlwaysStoppedAnimation(c),
    ),
  );

  Widget _speedButton(AppLocalizations l) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
    child: SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          setState(() => _fast = !_fast);
          _loop();
        },
        icon: const Icon(Icons.fast_forward_rounded),
        label: Text(l.eventFastForward),
        style: OutlinedButton.styleFrom(
          foregroundColor: _honey,
          side: const BorderSide(color: Color(0x66EBA52F)),
        ),
      ),
    ),
  );

  /// 카드 선택 — **이 판의 유일한 개입 지점**이다.
  Widget _cardPicker(AppLocalizations l) {
    final cards = _cards;
    if (cards.isEmpty) return _result(l);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
      decoration: const BoxDecoration(
        color: Color(0xFF17240F),
        border: Border(top: BorderSide(color: Color(0x33EBA52F))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l.eventCardTitle(_wave),
            style: const TextStyle(
              color: _honey,
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            l.eventCardHint,
            style: const TextStyle(color: Color(0x99FFFFFF), fontSize: 11),
          ),
          const SizedBox(height: 10),
          // 설명 줄 수가 카드마다 달라(예: "우회로"는 2줄) 높이가 어긋난다.
          // IntrinsicHeight 로 **가장 높은 카드에 맞춰** 셋을 같은 높이로 만든다.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final c in cards)
                  Expanded(child: _card(l, '${c['id']}', '${c['kind']}')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(AppLocalizations l, String id, String kind) {
    final (name, desc) = cardText(l, id);
    return GestureDetector(
      onTap: _busy ? null : () => _pick(id),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0x22000000),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _honey.withValues(alpha: 0.6), width: 1.4),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            // 애셋(ui/cards/{id}.webp)이 들어오면 자동으로 그림이 된다.
            gameImage(
              'assets/images/ui/cards/$id.webp',
              width: 40,
              height: 40,
              fallback: Text(
                cardGlyph(kind),
                style: const TextStyle(fontSize: 30),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              desc,
              textAlign: TextAlign.center,
              maxLines: 3,
              style: const TextStyle(
                color: Color(0xBBFFFFFF),
                fontSize: 10.5,
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _result(AppLocalizations l) {
    final cleared = (_res['cleared'] as num?)?.toInt() ?? 0;
    final score = (_res['score'] as num?)?.toInt() ?? 0;
    final isBest = _res['isBest'] == true;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0x22000000),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _honey.withValues(alpha: 0.6)),
      ),
      child: Column(
        children: [
          Text(
            l.eventResultTitle(cleared),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l.eventScore(formatCompact(score)),
            style: const TextStyle(color: _honey, fontWeight: FontWeight.w800),
          ),
          if (isBest) ...[
            const SizedBox(height: 6),
            Text(
              l.eventNewBest,
              style: const TextStyle(
                color: Color(0xFF9CE37D),
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(
                backgroundColor: _honey,
                foregroundColor: const Color(0xFF3A2600),
                minimumSize: const Size(0, 44),
              ),
              child: Text(
                l.actionClose,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

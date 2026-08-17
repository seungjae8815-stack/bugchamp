import 'dart:async';

import 'package:core_battle/core_battle.dart';
import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:flutter/material.dart';

import '../../data/game_data.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/art.dart';
import '../../ui/format.dart';
import '../../ui/labels.dart';

const _honey = Color(0xFFEBA52F);

/// 이벤트 도전 재생 — **서버가 확정한 판을 다시 그린다.**
///
/// 점수는 이미 서버가 정했다. 여기서 계산하는 값은 오직 **연출**을 위한 것이며,
/// `core_battle` 이 완전 결정론이라(§2.3) 같은 seed·같은 팀이면 서버와 같은 판이
/// 나온다. 그래도 화면에 쓰는 최종 웨이브·점수는 **서버 값**을 그대로 쓴다 —
/// 앱 데이터가 서버보다 낡았을 때 숫자가 갈리면 안 되기 때문이다.
class EventReplayScreen extends StatefulWidget {
  const EventReplayScreen({
    super.key,
    required this.data,
    required this.seed,
    required this.team,
    required this.serverWave,
    required this.serverScore,
    required this.isBest,
  });

  final GameData data;
  final int seed;

  /// 출전한 곤충(순서 그대로).
  final List<IndividualBug> team;

  /// 서버가 확정한 결과 — 화면 숫자는 이 값이 기준이다.
  final int serverWave;
  final int serverScore;
  final bool isBest;

  @override
  State<EventReplayScreen> createState() => _EventReplayScreenState();
}

class _EventReplayScreenState extends State<EventReplayScreen> {
  final List<BattleBug> _units = [];
  final List<double> _maxHp = [];
  List<double> _hp = [];

  BattleState? _battle;
  List<BattleBug> _enemies = const [];
  int _wave = 1;
  int _enemyIdx = 0;
  bool _finished = false;
  bool _fast = false;
  Timer? _timer;
  String? _flash; // 웨이브 클리어 등 한 줄 연출

  EventConfig get _cfg => widget.data.eventConfig ?? const EventConfig();

  @override
  void initState() {
    super.initState();
    for (final bug in widget.team) {
      final sp = widget.data.speciesById[bug.speciesId];
      if (sp == null) continue;
      final n = _cfg.normalized(sp.grade);
      _units.add(
        buildEventBug(
          bug: bug,
          species: sp,
          locale: 'ko',
          hp: n.hp,
          atk: n.atk,
          def: n.def,
          spd: n.spd,
        ),
      );
      _maxHp.add(n.hp);
    }
    _hp = [..._maxHp];
    _startWave();
    _tickLoop();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  WaveEnemySpec get _spec => WaveEnemySpec(
    baseHp: _cfg.enemyBaseHp,
    baseAtk: _cfg.enemyBaseAtk,
    baseDef: _cfg.enemyBaseDef,
    baseSpd: _cfg.enemyBaseSpd,
    growth: _cfg.enemyGrowth,
    count: _cfg.enemyCount,
  );

  void _startWave() {
    _enemies = eventWaveEnemies(widget.seed, _wave, _spec);
    _battle = initBattle(
      widget.seed + _wave * 7919,
      _units,
      _enemies,
      initialHpA: _hp,
    );
    _enemyIdx = 0;
  }

  void _tickLoop() {
    _timer?.cancel();
    _timer = Timer.periodic(
      Duration(milliseconds: _fast ? 90 : 340),
      (_) => _step(),
    );
  }

  void _step() {
    final st = _battle;
    if (st == null || _finished) return;
    if (!st.done) {
      st.step();
      setState(() {
        for (var i = 0; i < _hp.length && i < st.hpA.length; i++) {
          _hp[i] = st.hpA[i];
        }
        _enemyIdx = st.b;
      });
      return;
    }

    // 이 웨이브가 끝났다.
    final won = st.toResult().outcome == BattleOutcome.teamA;
    if (!won || _wave >= _cfg.maxWave) {
      _timer?.cancel();
      setState(() => _finished = true);
      return;
    }
    setState(() {
      // 클리어 회복 — **살아 있는 곤충만**(엔진과 같은 규칙).
      for (var i = 0; i < _hp.length; i++) {
        if (_hp[i] > 0) {
          _hp[i] = (_hp[i] + _maxHp[i] * _cfg.waveHealPct).clamp(
            0.0,
            _maxHp[i],
          );
        }
      }
      _flash = '$_wave';
      _wave++;
      _startWave();
    });
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _flash = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    return Scaffold(
      backgroundColor: const Color(0xFF10190A),
      body: SafeArea(
        child: Column(
          children: [
            _waveHeader(l),
            const SizedBox(height: 4),
            Expanded(child: _arena(l, locale)),
            if (_finished) _resultCard(l) else _controls(l),
          ],
        ),
      ),
    );
  }

  Widget _waveHeader(AppLocalizations l) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
    child: Row(
      children: [
        Text(
          l.eventWaveRecord(_finished ? widget.serverWave : _wave),
          style: const TextStyle(
            color: _honey,
            fontWeight: FontWeight.w900,
            fontSize: 20,
          ),
        ),
        const Spacer(),
        if (_flash != null)
          Text(
            l.eventWaveCleared(_flash!),
            style: const TextStyle(
              color: Color(0xFF9CE37D),
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
      ],
    ),
  );

  Widget _arena(AppLocalizations l, String locale) {
    final st = _battle;
    final foe = (st != null && _enemyIdx < _enemies.length)
        ? _enemies[_enemyIdx]
        : null;
    return Column(
      children: [
        // 적 — 웨이브마다 오행이 회전하므로 속성 표시가 핵심 정보다.
        if (foe != null && !_finished)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              children: [
                Text(
                  elementGlyph(foe.element),
                  style: const TextStyle(fontSize: 40),
                ),
                Text(
                  '${l.battleFoe} ${_enemyIdx + 1}/${_enemies.length}',
                  style: const TextStyle(
                    color: Color(0x99FFFFFF),
                    fontSize: 11.5,
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: 160,
                  child: _hpBar(
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
        // 내 팀 — 누가 언제 쓰러졌는지가 다음 편성의 근거가 된다.
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: _units.length,
            itemBuilder: (c, i) {
              final u = _units[i];
              final bug = i < widget.team.length ? widget.team[i] : null;
              final sp = bug == null
                  ? null
                  : widget.data.speciesById[bug.speciesId];
              final down = _hp[i] <= 0;
              final fighting = _battle?.a == i && !down && !_finished;
              return Opacity(
                opacity: down ? 0.35 : 1,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
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
                          size: 34,
                          fallback: bugAvatar(sp, size: 30),
                        ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  '${i + 1}. ${u.name}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12.5,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  elementGlyph(u.element),
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            _hpBar(
                              _maxHp[i] <= 0 ? 0 : _hp[i] / _maxHp[i],
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

  Widget _hpBar(double ratio, Color color) => ClipRRect(
    borderRadius: BorderRadius.circular(999),
    child: LinearProgressIndicator(
      value: ratio.clamp(0.0, 1.0),
      minHeight: 6,
      backgroundColor: const Color(0x33FFFFFF),
      valueColor: AlwaysStoppedAnimation(color),
    ),
  );

  Widget _controls(AppLocalizations l) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
    child: Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              setState(() => _fast = !_fast);
              _tickLoop();
            },
            icon: Icon(_fast ? Icons.speed : Icons.fast_forward_rounded),
            label: Text(_fast ? l.battleSkip : l.eventFastForward),
            style: OutlinedButton.styleFrom(
              foregroundColor: _honey,
              side: const BorderSide(color: Color(0x66EBA52F)),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _resultCard(AppLocalizations l) => Container(
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
          l.eventResultTitle(widget.serverWave),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l.eventScore(formatCompact(widget.serverScore)),
          style: const TextStyle(color: _honey, fontWeight: FontWeight.w800),
        ),
        if (widget.isBest) ...[
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

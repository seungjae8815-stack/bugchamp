import 'dart:async';

import 'package:core_battle/core_battle.dart';
import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:flutter/material.dart' hide Element;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/game_data.dart';
import '../../domain/audio_service.dart';
import '../../domain/game_server.dart';
import '../../domain/save_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/art.dart';
import '../../ui/format.dart';
import '../../ui/labels.dart';
import '../../ui/game_dialog.dart';
import '../../ui/toast.dart';
import '../battle/arena_widgets.dart';
import 'event_arena.dart';

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

  /// 화면에 그릴 팀 — **서버가 정한 순서**를 따른다. 선봉을 바꾸면 서버가 순서를
  /// 재배치하므로, 앱이 처음 편성 순서를 계속 쓰면 "바꿨는데 안 나온다"가 된다.
  late List<IndividualBug> _team;
  BattleState? _battle;
  List<BattleBug> _units = const [];
  List<BattleBug> _enemies = const [];
  List<double> _hpShown = const [];
  int _enemyIdx = 0;
  // 연출 상태 — PvP 아레나와 같은 이펙트 위젯을 쓴다.
  final List<FloatText> _floats = [];
  final List<BurstFx> _bursts = [];
  double _flashL = 0, _flashR = 0, _lunge = 0, _shake = 0;

  /// 이번 라운드에 **누가 돌진하는가**(-1 왼쪽 / 1 오른쪽 / 0 없음).
  /// 둘 다 움직이면 서로 스쳐 지나가는 것처럼 보여 때린 느낌이 안 난다.
  int _lungeSide = 0;

  /// 카드를 고를 때 함께 정하는 **다음 웨이브 선봉**. null 이면 순서 유지.
  String? _lead;
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
    _team = [...widget.team];
    _syncTeamOrder();
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
      for (final bug in _team)
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
    if (_units.length != _team.length) {
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

  /// 서버가 준 순서로 팀을 재배치한다(선봉 교체 반영).
  void _syncTeamOrder() {
    final ids = (_res['teamIds'] as List?)?.map((e) => '$e').toList();
    if (ids == null || ids.length != _team.length) return;
    final byId = {for (final b in _team) b.id: b};
    final next = <IndividualBug>[];
    for (final id in ids) {
      final b = byId[id];
      if (b == null) return; // 모르는 id 면 건드리지 않는다
      next.add(b);
    }
    _team = next;
  }

  List<double> _serverHp() => [
    for (final v in ((_res['hp'] as List?) ?? const [])) (v as num).toDouble(),
  ];

  void _loop() {
    _timer?.cancel();
    _timer = Timer.periodic(
      Duration(milliseconds: _fast ? 160 : 620),
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
        // ⚠️ 이펙트를 반드시 비운다 — 타이머가 멈추면 age 가 늘지 않아
        // 데미지 숫자가 화면에 **영원히 붙어 있는다**(실기에서 발견).
        _floats.clear();
        _bursts.clear();
        _flashL = _flashR = _lunge = _shake = 0;
        _lungeSide = 0;
      });
      return;
    }
    final before = st.events.length;
    st.step();
    setState(() {
      for (var i = 0; i < _hpShown.length && i < st.hpA.length; i++) {
        _hpShown[i] = st.hpA[i];
      }
      _enemyIdx = st.b;
      if (st.events.length > before) _playEffects(st, st.events.last);
      // 이펙트는 시간이 지나면 사라진다(수명은 위젯이 안다).
      // 수명은 초 단위다 — 재생 간격만큼 늘려야 제때 사라진다.
      final dt = (_fast ? 160 : 620) / 1000.0;
      for (final f in _floats) {
        f.age += dt;
      }
      for (final b in _bursts) {
        b.age += dt;
      }
      _floats.removeWhere((f) => f.age >= FloatText.life);
      _bursts.removeWhere((b) => b.age >= BurstFx.life);
      _flashL = (_flashL - 0.5).clamp(0.0, 1.0);
      _flashR = (_flashR - 0.5).clamp(0.0, 1.0);
      _lunge = (_lunge - 8).clamp(0.0, 40.0);
      _shake = (_shake - 0.5).clamp(0.0, 1.0);
    });
  }

  /// 한 라운드의 결과를 **화면 신호**로 바꾼다. 숫자만 바뀌면 오행을 맞춘 보람이
  /// 화면에 남지 않는다 — 상극이 터질 때만 흔들고 링을 터뜨린다.
  void _playEffects(BattleState st, BattleEvent ev) {
    final mine = st.a < _units.length ? _units[st.a] : null;
    final foe = _enemyIdx < _enemies.length ? _enemies[_enemyIdx] : null;
    if (ev.dmgToA >= 1) {
      _floats.add(
        FloatText('-${ev.dmgToA.round()}', const Color(0xFFFF6B6B), true),
      );
      _flashL = 1;
      AudioService.instance.sfxHurt(); // 내가 맞았다
    }
    if (ev.healToA >= 1) {
      _floats.add(
        FloatText('+${ev.healToA.round()}', const Color(0xFF7CE38B), true),
      );
    }
    if (ev.dmgToB >= 1) {
      _floats.add(
        FloatText('-${ev.dmgToB.round()}', const Color(0xFFFF6B6B), false),
      );
      _flashR = 1;
      AudioService.instance.sfxHit(); // 내가 때렸다
    }
    if (ev.healToB >= 1) {
      _floats.add(
        FloatText('+${ev.healToB.round()}', const Color(0xFF7CE38B), false),
      );
    }
    // **더 크게 때린 쪽만** 달려든다.
    _lungeSide = ev.dmgToB > ev.dmgToA + 0.5
        ? -1
        : (ev.dmgToA > ev.dmgToB + 0.5 ? 1 : 0);
    _lunge = _lungeSide == 0 ? 0 : 16;
    if (mine != null && foe != null) {
      final foeHit = ev.dmgToB >= 1 && mine.element.restrains(foe.element);
      final selfHit = ev.dmgToA >= 1 && foe.element.restrains(mine.element);
      if (foeHit) {
        _bursts.add(BurstFx(left: false, color: elementColor(mine.element)));
      }
      if (selfHit) {
        _bursts.add(BurstFx(left: true, color: elementColor(foe.element)));
      }
      if (foeHit || selfHit) _shake = 1;
    }
  }

  Future<void> _pick(String cardId) async {
    if (_busy) return;
    setState(() => _busy = true);
    final sid = '${_res['sessionId']}';
    final r = await ref
        .read(gameServerProvider)
        .eventPick(sid, cardId, leadBugId: _lead);
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
    setState(() {
      _res = {..._res, ...?r.data};
      _lead = null;
      _syncTeamOrder();
    });
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
            Expanded(child: _stage(l)),
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
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WaveProgress(
            wave: _wave,
            maxWave: _cfg.maxWave,
            // 다음 웨이브의 오행을 미리 알려준다 — 카드 선택에 계획이 생긴다.
            nextElement: _replaying || _done ? null : _nextWaveElement(),
          ),
          if (parts.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              parts.join('  '),
              style: const TextStyle(
                color: Color(0xFF9CE37D),
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 적의 모습으로 쓸 종. 새 아트를 그리지 않고 **이미 있는 20종을 돌려쓴다**.
  String? _foeSpeciesId(int index) => eventWaveSpeciesId(
    _seed,
    _wave,
    index,
    widget.data.speciesById.keys.toList()..sort(),
  );

  /// 다음 웨이브의 **대표 오행**(첫 적 기준). 카드를 고르는 시점에만 쓴다.
  Element? _nextWaveElement() {
    final next = eventWaveEnemies(
      _seed,
      _wave + 1,
      WaveEnemySpec(
        baseHp: _cfg.enemyBaseHp,
        baseAtk: _cfg.enemyBaseAtk,
        baseDef: _cfg.enemyBaseDef,
        baseSpd: _cfg.enemyBaseSpd,
        growth: _cfg.enemyGrowth,
        count: _cfg.enemyCount,
      ),
    );
    return next.isEmpty ? null : next.first.element;
  }

  /// 무대(위) + 내 팀 미니 체력(아래).
  ///
  /// 전에는 세로 리스트만 있어서 "전투가 벌어지고 있다"가 안 보였다. 대치 구도로
  /// 바꾸고 팀 상태는 아래로 내린다 — 지금 누가 싸우는지가 먼저 읽혀야 한다.
  Widget _stage(AppLocalizations l) {
    final st = _battle;
    final ev = (st != null && st.events.isNotEmpty) ? st.events.last : null;
    final mineIdx = st?.a ?? 0;
    final mine = mineIdx < _units.length ? _units[mineIdx] : null;
    final foe = _enemyIdx < _enemies.length ? _enemies[_enemyIdx] : null;
    final mineHp = mineIdx < _hpShown.length ? _hpShown[mineIdx] : 0.0;
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: EventArena(
              data: widget.data,
              mine: _replaying ? mine : null,
              foe: _replaying ? foe : null,
              mineSpeciesId: mineIdx < _team.length
                  ? _team[mineIdx].speciesId
                  : null,
              foeSpeciesId: _foeSpeciesId(_enemyIdx),
              mineHpFrac: (mine == null || mine.maxHp <= 0)
                  ? 0
                  : mineHp / mine.maxHp,
              foeHpFrac: (st == null || foe == null || foe.maxHp <= 0)
                  ? 1
                  : (_enemyIdx < st.hpB.length ? st.hpB[_enemyIdx] : 0) /
                        foe.maxHp,
              stanceMine: ev?.aStance,
              stanceFoe: ev?.bStance,
              flashL: _flashL,
              flashR: _flashR,
              lungeDx:
                  _lunge * (_lungeSide == 0 ? 0 : (_lungeSide < 0 ? 1 : -1)),
              shake: _shake,
              floats: _floats,
              bursts: _bursts,
            ),
          ),
        ),
        const SizedBox(height: 8),
        // 내 팀 3마리 — 누가 쓰러졌는지가 다음 편성의 근거가 된다.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              for (var i = 0; i < _units.length; i++)
                Expanded(child: _teamChip(i)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _teamChip(int i) {
    final u = _units[i];
    final bug = i < _team.length ? _team[i] : null;
    final sp = bug == null ? null : widget.data.speciesById[bug.speciesId];
    final hp = i < _hpShown.length ? _hpShown[i] : 0.0;
    final down = hp <= 0;
    final fighting = _replaying && _battle?.a == i && !down;
    // 카드를 고르는 동안에는 탭이 **선봉 지정**이 된다(전투 중엔 상세 보기).
    final picking = !_replaying && !_done && _cards.isNotEmpty;
    final isLead = _lead == bug?.id || (_lead == null && i == 0);
    return GestureDetector(
      onTap: bug == null || sp == null
          ? null
          : () {
              if (picking && !down) {
                setState(() => _lead = bug.id);
              } else {
                _showBugInfo(bug, sp, u, hp);
              }
            },
      child: Opacity(
        opacity: down ? 0.35 : 1,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          decoration: BoxDecoration(
            color: (fighting || (picking && isLead && !down))
                ? _honey.withValues(alpha: 0.16)
                : const Color(0x33000000),
            borderRadius: BorderRadius.circular(10),
            border: (fighting || (picking && isLead && !down))
                ? Border.all(color: _honey.withValues(alpha: 0.8))
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (bug != null && sp != null)
                    bugStageImage(
                      bug.speciesId,
                      LifeStage.adult,
                      size: 22,
                      fallback: bugAvatar(sp, size: 20),
                    ),
                  const SizedBox(width: 3),
                  Text(
                    elementGlyph(u.element),
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              _bar(u.maxHp <= 0 ? 0 : hp / u.maxHp, const Color(0xFF7BC96F)),
              if (picking && !down) ...[
                const SizedBox(height: 3),
                Text(
                  isLead
                      ? AppLocalizations.of(context).eventLead
                      : AppLocalizations.of(context).eventSetLead,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isLead ? _honey : const Color(0x99FFFFFF),
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 대기 중인 곤충을 눌렀을 때 — **왜 이 곤충을 넣었는지** 다시 확인하는 창.
  /// 이벤트는 스탯이 평준화되므로 종·오행·기질·주특기만 보여준다.
  void _showBugInfo(IndividualBug bug, Species sp, BattleBug unit, double hp) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    showGameDialog<void>(
      context,
      title: sp.name.resolve(locale),
      iconWidget: bugStageImage(
        sp.id,
        LifeStage.adult,
        size: 40,
        fallback: bugAvatar(sp, size: 36),
      ),
      subtitle: gradeLabel(l, sp.grade),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoRow(l.battleHpPct(((hp / unit.maxHp) * 100).round().toString())),
          _infoRow(
            '${elementGlyph(bug.element)} ${elementLabel(l, bug.element)}',
          ),
          _infoRow(temperamentLabel(l, bug.temperament)),
          _infoRow(
            '${stanceGlyph(unit.preferredStance)} '
            '${stanceLabel(l, unit.preferredStance)}',
          ),
          const SizedBox(height: 8),
          Text(
            l.eventNormalizeBody,
            style: const TextStyle(
              color: Color(0x99FFFFFF),
              fontSize: 11,
              height: 1.35,
            ),
          ),
        ],
      ),
      actions: [gameDialogButton(l.actionClose, () => Navigator.pop(context))],
    );
  }

  Widget _infoRow(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(
      text,
      style: const TextStyle(color: Color(0xDDFFFFFF), fontSize: 13),
    ),
  );

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
            '${l.eventCardHint} · ${l.eventLeadHint}',
            textAlign: TextAlign.center,
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

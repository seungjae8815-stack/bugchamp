import 'dart:async';
import 'dart:math' as math;

import 'package:core_battle/core_battle.dart';
import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:flutter/material.dart' hide Element;
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/game_data.dart';
import '../../domain/audio_service.dart';
import '../../domain/game_server.dart';
import '../../domain/save_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/art.dart';
import '../../ui/element_wheel.dart';
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

class _EventBattleScreenState extends ConsumerState<EventBattleScreen>
    with SingleTickerProviderStateMixin {
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
  double _flashL = 0, _flashR = 0, _shake = 0;

  /// 이번 라운드에 **누가 때렸는가**. 때린 쪽이 달려든다(둘 다면 서로 부딪친다).
  bool _strikeL = false, _strikeR = false;

  /// 라운드 안에서의 경과(초). 0 에서 시작해 [_roundDur] 에 다음 라운드로 넘어간다.
  double _roundT = 0;

  /// 아직 꽂히지 않은 이번 라운드 결과. 타격 시점([arenaImpactAt])에 터뜨린다.
  BattleEvent? _pending;

  /// [_pending] 이 벌어진 시점의 적 번호. 라운드가 끝나며 적이 교체될 수 있어,
  /// 이펙트(오행 상극 판정)는 **그때 싸우던 적**을 봐야 한다.
  int _pendingFoe = 0;

  /// 체력 바가 따라갈 목표(타격이 꽂히는 순간 갱신).
  List<double> _hpTarget = const [];

  /// 카드를 고를 때 함께 정하는 **다음 웨이브 선봉**. null 이면 순서 유지.
  String? _lead;
  bool _replaying = false;
  bool _busy = false;
  bool _fast = false;
  late final Ticker _ticker;
  Duration _last = Duration.zero;

  /// 한 라운드의 길이(초).
  double get _roundDur => _fast ? 0.16 : 0.62;

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
    // 60fps 로 돈다. 예전엔 `Timer.periodic(620ms)` 한 번에 **라운드 하나**를
    // 통째로 처리해서, 애니메이션이 초당 1.6 프레임이었다 — 자세가 라운드당 한 번
    // 바뀌고 그대로 멈춰 있으니 때리는 것도 맞는 것도 보일 수가 없었다
    // (실기: "전투하는 느낌이 안 든다"). 전투 진행과 그림 갱신을 분리한다.
    _ticker = createTicker(_onFrame)..start();
    _replayCurrentWave();
  }

  @override
  void dispose() {
    _ticker.dispose();
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
      // 웨이브전은 결투와 라운드 상한이 다르다 — 서버와 **같은 값**을 써야
      // 재생이 서버 결과와 어긋나지 않는다.
      maxRounds: kMaxEventRounds,
    );
    _hpShown = [for (final u in _units) from == null ? u.maxHp : 0];
    if (from != null) {
      for (var i = 0; i < _hpShown.length && i < from.length; i++) {
        _hpShown[i] = from[i];
      }
    }
    _hpTarget = [..._hpShown];
    setState(() {
      _replaying = true;
      _enemyIdx = 0;
      _roundT = 0;
      _pending = null;
      _strikeL = _strikeR = false;
    });
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

  /// 매 프레임. **그림만** 굴리고, 전투는 라운드 경계에서만 한 칸 나간다.
  void _onFrame(Duration elapsed) {
    final raw = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    if (!_replaying) return;
    final st = _battle;
    if (st == null) return;
    // 프레임이 튀어도(앱 복귀 등) 한 번에 몰아서 진행하지 않는다.
    final dt = raw.clamp(0.0, 0.05);
    if (dt <= 0) return;

    setState(() {
      // 감쇠·수명은 **실제 시간**으로 — 프레임 수로 깎으면 배속에 따라 달라진다.
      _flashL = math.max(0, _flashL - dt * 3);
      _flashR = math.max(0, _flashR - dt * 3);
      _shake = math.max(0, _shake - dt * 2.5);
      for (final f in _floats) {
        f.age += dt;
      }
      for (final b in _bursts) {
        b.age += dt;
      }
      _floats.removeWhere((f) => f.age >= FloatText.life);
      _bursts.removeWhere((b) => b.age >= BurstFx.life);

      // 체력 바는 목표를 향해 따라간다 — 뚝 떨어지면 얼마나 깎였는지 안 보인다.
      for (var i = 0; i < _hpShown.length && i < _hpTarget.length; i++) {
        _hpShown[i] += (_hpTarget[i] - _hpShown[i]) * (dt * 9).clamp(0.0, 1.0);
      }

      _roundT += dt;
      // 돌진이 꽂히는 순간에 맞춰 데미지·번쩍임·소리를 함께 터뜨린다.
      // 예전엔 라운드가 시작하자마자 다 나와서, 숫자가 뜬 뒤에 몸이 움직였다.
      if (_pending != null && _roundT >= _roundDur * arenaImpactAt) {
        _applyImpact(st, _pending!);
        _pending = null;
      }
      if (_roundT >= _roundDur) {
        _roundT -= _roundDur;
        _advance(st);
      }
    });
  }

  /// 라운드를 한 칸 진행하고, 이번 라운드에 **누가 때리는지**만 먼저 정한다.
  /// (데미지 표시는 [_applyImpact] 가 타격 시점에 한다.)
  void _advance(BattleState st) {
    if (st.done) {
      _replaying = false;
      // 재생이 끝나면 **서버가 준 체력**으로 맞춘다(클리어 회복까지 반영된 값).
      _hpShown = _serverHp();
      _hpTarget = [..._hpShown];
      // ⚠️ 이펙트를 반드시 비운다 — 재생이 멈추면 age 가 늘지 않아
      // 데미지 숫자가 화면에 **영원히 붙어 있는다**(실기에서 발견).
      _floats.clear();
      _bursts.clear();
      _flashL = _flashR = _shake = 0;
      _strikeL = _strikeR = false;
      return;
    }
    final before = st.events.length;
    // 적 교체는 라운드가 끝난 **뒤**에 반영한다 — 쓰러지는 라운드는 쓰러지는
    // 놈이 화면에 있어야 한다.
    _enemyIdx = st.b;
    st.step();
    if (st.events.length <= before) return;
    final ev = st.events.last;
    _pending = ev;
    _pendingFoe = _enemyIdx;
    _strikeL = ev.dmgToB >= 1;
    _strikeR = ev.dmgToA >= 1;
  }

  /// 한 라운드의 결과를 **화면 신호**로 바꾼다. 숫자만 바뀌면 오행을 맞춘 보람이
  /// 화면에 남지 않는다 — 상극이 터질 때만 흔들고 링을 터뜨린다.
  void _applyImpact(BattleState st, BattleEvent ev) {
    for (var i = 0; i < _hpTarget.length && i < st.hpA.length; i++) {
      _hpTarget[i] = st.hpA[i];
    }
    final mine = st.a < _units.length ? _units[st.a] : null;
    final foe = _pendingFoe < _enemies.length ? _enemies[_pendingFoe] : null;
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
    if (mine != null && foe != null) {
      final foeHit = ev.dmgToB >= 1 && mine.element.restrains(foe.element);
      final selfHit = ev.dmgToA >= 1 && foe.element.restrains(mine.element);
      // 상극은 데미지 1.5배다. 링만 터뜨리면 **왜 컸는지**가 안 읽히므로
      // 어느 오행이 어느 오행을 눌렀는지 글자로 남긴다.
      if (foeHit) {
        _bursts.add(BurstFx(left: false, color: elementColor(mine.element)));
        _floats.add(
          FloatText(
            AppLocalizations.of(context).battleRestrain,
            elementColor(mine.element),
            false,
            element: mine.element,
          ),
        );
      }
      if (selfHit) {
        _bursts.add(BurstFx(left: true, color: elementColor(foe.element)));
        _floats.add(
          FloatText(
            AppLocalizations.of(context).battleRestrain,
            elementColor(foe.element),
            true,
            element: foe.element,
          ),
        );
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
    // 카드(회복·부활·최대체력)가 반영된 **진입 체력**을 서버가 준다. 없으면
    // (구버전 서버) 예전처럼 화면 체력에서 시작한다.
    final entry = (_res['hpEntry'] as List?)
        ?.map((e) => (e as num).toDouble())
        .toList();
    _replayCurrentWave(from: entry ?? before);
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
            // 속성 이름만 알려줘 봐야 **뭘로 받아야 하는지** 모르면 예고가
            // 무용지물이다. 눌러서 관계도를 보게 한다.
            onTapElement: () =>
                showElementWheel(context, highlight: _nextWaveElement()),
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

  /// 다음 웨이브 색과의 상성: 1=내가 克한다 · -1=내가 당한다 · 0=중립.
  int _matchup(Element mine) {
    final next = _nextWaveElement();
    if (next == null) return 0;
    if (mine.restrains(next)) return 1;
    if (next.restrains(mine)) return -1;
    return 0;
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
              // 전투 엔진이 지은 이름은 `W3-1` 이다(순수 패키지라 다국어를
              // 모른다). 화면에는 그 모습으로 쓰는 **종의 이름**을 보여준다.
              foeName: widget
                  .data
                  .speciesById[_foeSpeciesId(_enemyIdx) ?? '']
                  ?.name
                  .resolve(Localizations.localeOf(context).languageCode),
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
              lungeL: _strikeL ? arenaLungeCurve(_roundT / _roundDur) * 22 : 0,
              lungeR: _strikeR ? arenaLungeCurve(_roundT / _roundDur) * 22 : 0,
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
    // 다음 웨이브 색과의 상성. 실측상 **매 웨이브 상극을 앞세우면 도달
    // 웨이브가 +28~35%** 인데, 화면이 그걸 말해 주지 않아 유저에겐 "오행이
    // 아무 의미 없다"로 보였다(2026-09-02 제보). 웨이브 색은 다섯 색을 한
    // 바퀴 돌아 **어떤 색을 데려오느냐**는 상쇄된다 — 오행이 실제로 갈리는
    // 지점은 여기 하나뿐이다.
    //
    // ⚠️ 글자를 **줄로 추가하면 안 된다**. 유리/불리가 붙은 칩만 키가 커져
    // 옆 칩과 행이 어긋난다(첫 시도에서 실기 지적). 색으로 칩 전체를 물들이고,
    // 글자는 **이미 있는 아이콘 줄**에 얹어 높이를 그대로 둔다.
    final mu = picking && !down ? _matchup(u.element) : 0;
    final muColor = mu > 0
        ? const Color(0xFF9CE37D)
        : (mu < 0 ? const Color(0xFFE38080) : null);
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
                : (muColor?.withValues(alpha: 0.12) ?? const Color(0x33000000)),
            borderRadius: BorderRadius.circular(10),
            border: (fighting || (picking && isLead && !down))
                ? Border.all(color: _honey.withValues(alpha: 0.8))
                : (muColor == null
                      ? null
                      : Border.all(color: muColor.withValues(alpha: 0.7))),
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
                  elementIcon(u.element, size: 13),
                  if (muColor != null) ...[
                    const SizedBox(width: 2),
                    Text(
                      mu > 0
                          ? AppLocalizations.of(context).eventLeadStrong
                          : AppLocalizations.of(context).eventLeadWeak,
                      style: TextStyle(
                        color: muColor,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
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
            elementLabel(l, bug.element),
            icon: elementIcon(bug.element, size: 14),
          ),
          _infoRow(
            temperamentLabel(l, bug.temperament),
            icon: temperamentIcon(bug.temperament),
          ),
          _infoRow(
            stanceLabel(l, unit.preferredStance),
            icon: stanceArt(unit.preferredStance, size: 14),
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

  Widget _infoRow(String text, {Widget? icon}) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[icon, const SizedBox(width: 4)],
        Text(
          text,
          style: const TextStyle(color: Color(0xDDFFFFFF), fontSize: 13),
        ),
      ],
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
    // 왜 끝났는지 한 줄. 20라운드 판정패(§2.3)로 지면 **곤충이 살아 있는 채로**
    // 결과가 뜬다 — 이유가 없으면 화면이 고장 난 것처럼 보인다(실기 제보).
    final won = _res['won'] == true;
    final wiped = _hpShown.every((v) => v <= 0.5);
    final reason = won
        ? l.eventStopMax
        : (wiped ? l.eventStopWipe : l.eventStopJudge);
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
          const SizedBox(height: 6),
          Text(
            reason,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFCBD8BE),
              fontSize: 12,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
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

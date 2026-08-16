import 'dart:math' as math;

import 'package:core_models/core_models.dart';
import 'package:core_save/core_save.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../domain/providers.dart';
import '../../domain/save_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../domain/audio_service.dart';
import '../../ui/art.dart';
import '../../ui/labels.dart';

/// 걷기 스프라이트를 초당 몇 장 넘기나. 2장뿐이라 너무 빠르면 떨려 보인다.
const double _kWalkFps = 5;

/// 한 걸음의 각속도(rad/s). 프레임 2장이 한 주기이므로 `fps/2` 회전이다.
const double _kStepHz = math.pi * _kWalkFps;

/// 무대에 동시에 세우는 야생 곤충 수.
const int _kWildCount = 3;

/// 캐릭터 탭 상단의 **살아 있는 씬** — 그리고 작은 채집 미니게임.
///
/// 캐릭터가 그냥 왔다 갔다 하면 금세 지루하다. 그래서 **야생 곤충을 쫓아가
/// 채집망을 휘두르고**, 기회가 열리면 제한 시간 안에 탭해서 잡는다.
///
/// 여기 나오는 곤충은 **보유 곤충이 아니라 야생**이다. 보유한 걸 보여 주면
/// 구경거리로 끝나지만, 야생이면 화면을 켜 둘 이유가 생긴다(§2.4 접속 보너스
/// 계열 — 켜 둔 사람에게만 얹는다).
class CharacterScene extends ConsumerStatefulWidget {
  const CharacterScene({super.key, required this.save});

  final SaveGame save;

  @override
  ConsumerState<CharacterScene> createState() => _CharacterSceneState();
}

/// 캐릭터가 지금 뭘 하고 있나.
enum _Act {
  /// 노린 곤충 쪽으로 걸어간다.
  chase,

  /// 채집망을 휘두른다.
  swing,

  /// 한숨 돌린다 — 계속 휘두르면 정신없다.
  rest,
}

class _CharacterSceneState extends ConsumerState<CharacterScene>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _last = Duration.zero;

  final _rng = math.Random();
  final _uuid = const Uuid();

  /// 무대의 야생 곤충들.
  final List<_Wild> _wild = [];

  /// 캐릭터.
  final _hero = _Wanderer(seed: 3);
  double _t = 0;

  _Act _act = _Act.chase;
  double _actT = 0;

  /// 지금 노리는 곤충. 없으면 그냥 거닌다.
  int _target = -1;
  bool _swung = false;

  /// 잡을 기회가 열린 곤충. -1 이면 안 열려 있다.
  int _chance = -1;

  /// 기회가 닫히기까지 남은 시간(초).
  double _chanceLeft = 0;

  /// 다음 기회까지 쉬는 시간(초).
  double _cooldown = 0;

  /// 방금 잡은 것 — 짧게 이름을 띄운다.
  String? _caught;
  double _caughtT = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _tick(Duration elapsed) {
    final raw = (elapsed - _last).inMicroseconds / 1000000.0;
    _last = elapsed;
    // 프레임이 튀어도 한 번에 크게 움직이지 않게 묶는다(홈 화면과 같은 규칙).
    final dt = raw.clamp(0.0, 0.05);
    if (dt <= 0) return;
    setState(() {
      _t += dt;
      _actT += dt;
      if (_cooldown > 0) _cooldown -= dt;
      if (_caught != null && (_caughtT -= dt) <= 0) _caught = null;
      if (_chance >= 0) {
        _chanceLeft -= dt;
        if (_chanceLeft <= 0) _missChance();
      }
      for (final w in _wild) {
        w.bug.step(dt);
      }
      _stepHero(dt);
    });
  }

  /// 캐릭터의 사냥 한 박자.
  void _stepHero(double dt) {
    switch (_act) {
      case _Act.chase:
        if (_target < 0 || _target >= _wild.length) {
          _pickTarget();
          if (_target < 0) {
            _hero.step(dt); // 곤충이 없으면 그냥 거닌다
            return;
          }
        }
        final dx = _wild[_target].bug.x - _hero.x;
        _hero.facingRight = dx >= 0;
        // 곤충보다 조금 빨라야 따라잡는다 — 같으면 영영 못 잡는다.
        _hero.x += dx.sign * 0.22 * dt;
        _hero.bob(dt);
        if (dx.abs() < 0.07) {
          _act = _Act.swing;
          _actT = 0;
          _swung = false;
        }
      case _Act.swing:
        // 휘두르는 중간에 결판이 난다 — 끝나고 반응하면 인과가 안 보인다.
        if (!_swung && _actT > 0.28) {
          _swung = true;
          _resolveSwing();
        }
        if (_actT > 0.66) {
          _act = _Act.rest;
          _actT = 0;
        }
      case _Act.rest:
        if (_actT > 0.7) {
          _act = _Act.chase;
          _actT = 0;
          _pickTarget();
        }
    }
  }

  /// 휘두른 결과 — **기회가 열리거나**, 곤충이 그냥 달아난다.
  void _resolveSwing() {
    if (_target < 0 || _target >= _wild.length) return;
    final cfg = ref.read(gameDataProvider).value?.runConfig;
    final open =
        cfg != null &&
        _chance < 0 &&
        _cooldown <= 0 &&
        !widget.save.storageFull &&
        _rng.nextDouble() < cfg.sceneCatchChance;
    if (open) {
      _chance = _target;
      _chanceLeft = cfg.sceneCatchWindow;
      AudioService.instance.sfxTap();
      return;
    }
    _wild[_target].bug.startle(_hero.facingRight ? 1 : -1);
  }

  /// 시간 안에 못 눌렀다 — 놓친다.
  void _missChance() {
    if (_chance >= 0 && _chance < _wild.length) {
      _wild[_chance].bug.startle(_hero.facingRight ? 1 : -1);
    }
    _chance = -1;
    _chanceLeft = 0;
  }

  /// 시간 안에 눌렀다 — **잡는다**.
  Future<void> _tapCatch() async {
    if (_chance < 0 || _chance >= _wild.length) return;
    final data = ref.read(gameDataProvider).value;
    final cfg = data?.runConfig;
    final species = data?.speciesById[_wild[_chance].speciesId];
    final idx = _chance;
    _chance = -1;
    _chanceLeft = 0;
    if (species == null || cfg == null) return;

    _cooldown = cfg.sceneCatchCooldown;
    final locale = Localizations.localeOf(context).languageCode;
    setState(() {
      _caught = species.name.resolve(locale);
      _caughtT = 1.6;
      // 잡힌 자리에 **다른 종**을 새로 세운다 — 같은 놈이 계속 나오면
      // "잡았는데 그대로"로 보인다.
      _wild[idx] = _rollWild(idx);
    });

    if (species.grade.index >= Grade.rare.index) {
      AudioService.instance.sfxRare();
    } else {
      AudioService.instance.sfxCatch();
    }
    // 획득 경로는 방치 드롭과 **같다** — 알로 들어가 부화기를 거친다.
    // 여기만 성충으로 주면 부화기 루프를 통째로 건너뛰게 된다.
    await ref
        .read(saveControllerProvider.notifier)
        .applyReward(
          gold: 0,
          xp: 0,
          bug:
              IndividualBug.roll(
                id: _uuid.v4(),
                species: species,
                rng: _rng,
                potential:
                    (1 + (_rng.nextDouble() * _rng.nextDouble() * 4).floor())
                        .clamp(1, 5),
              ).copyWith(
                stage: LifeStage.egg,
                stageSince: ref.read(clockProvider).now().toUtc(),
              ),
        );
  }

  /// 가장 가까운 곤충을 노린다 — 굳이 먼 놈을 쫓으면 어슬렁대는 걸로 보인다.
  void _pickTarget() {
    _target = -1;
    var best = 2.0;
    for (var i = 0; i < _wild.length; i++) {
      final d = (_wild[i].bug.x - _hero.x).abs();
      if (d < best) {
        best = d;
        _target = i;
      }
    }
    // 가끔은 엉뚱한 놈을 노린다 — 늘 최단거리면 기계처럼 보인다.
    if (_wild.length > 1 && _rng.nextDouble() < 0.3) {
      _target = _rng.nextInt(_wild.length);
    }
  }

  _Wild _rollWild(int seed) {
    final all = ref.read(gameDataProvider).value?.allSpecies ?? const [];
    // 등급 필터(§2.1)는 **여기서** 건다 — 채집망은 눈에 보이는 놈을 직접
    // 골라 휘두르는 조작이라, 잡고 나서 방생하면 "잡았는데 없어졌다"가 된다.
    // 아예 나타나지 않게 하면 헛스윙 자체가 없다.
    final save = ref.read(saveControllerProvider).value;
    final pool = save == null
        ? all
        : all.where((s) => save.acceptsGrade(s.grade)).toList();
    // 필터가 너무 세서 아무것도 안 남으면 씬이 텅 빈다 — 그때는 필터를 무시하고
    // 전체에서 세운다(잡히면 방생되지만, 빈 화면보다는 낫다).
    final src = pool.isEmpty ? all : pool;
    final sp = src.isEmpty ? null : src[_rng.nextInt(src.length)];
    return _Wild(
      speciesId: sp?.id ?? '',
      bug: _Wanderer(seed: seed * 37 + _rng.nextInt(9999)),
    );
  }

  void _fillStage() {
    if (ref.read(gameDataProvider).value == null) return;
    while (_wild.length < _kWildCount) {
      _wild.add(_rollWild(_wild.length));
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(gameDataProvider).value;
    _fillStage();

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: GestureDetector(
        // 기회가 열렸을 때 **씬 아무 데나** 누르면 된다 — 움직이는 곤충을
        // 정확히 겨냥하게 하면 손가락이 화면을 가려 오히려 못 잡는다.
        onTap: _chance >= 0 ? _tapCatch : null,
        child: Container(
          // 높이는 **부모가 정한다** — 화면 크기에 따라 달라지므로 여기서
          // 고정하면 작은 폰에서 다른 요소를 밀어낸다.
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF2A3D1C), Color(0xFF15200E)],
            ),
          ),
          child: Stack(
            children: [
              // 배경 — 홈 화면과 같은 지역 그림을 쓴다. 없으면 그라데이션만.
              Positioned.fill(
                child: gameImageChain(
                  const [
                    'assets/images/regions/oak_forest.webp',
                    'assets/images/biomes/oak_forest.webp',
                  ],
                  size: 999,
                  fit: BoxFit.cover,
                  fallback: const SizedBox.shrink(),
                ),
              ),
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x00000000), Color(0x66000000)],
                    ),
                  ),
                ),
              ),
              LayoutBuilder(
                builder: (context, c) {
                  // 캐릭터와 곤충이 **같은 무대**를 쓴다. 예전엔 캐릭터가 왼쪽
                  // 26px 안에 갇혀 있어서 곤충 쪽으로 갈 수가 없었다.
                  final span = (c.maxWidth - 76).clamp(60.0, 900.0);
                  return Stack(
                    children: [
                      for (var i = 0; i < _wild.length; i++)
                        _bugSprite(data, i, span),
                      _heroSprite(span),
                    ],
                  );
                },
              ),
              if (_chance >= 0) _catchBar(),
              if (_caught != null) _caughtBanner(),
            ],
          ),
        ),
      ),
    );
  }

  /// 제한 시간 게이지 + "탭!" — 이게 없으면 언제 눌러야 하는지 알 수 없다.
  Widget _catchBar() {
    final cfg = ref.read(gameDataProvider).value?.runConfig;
    final total = cfg?.sceneCatchWindow ?? 1.4;
    final left = (_chanceLeft / total).clamp(0.0, 1.0);
    final l = AppLocalizations.of(context);
    return Positioned(
      left: 24,
      right: 24,
      top: 10,
      child: Column(
        children: [
          Text(
            l.sceneCatchTap,
            style: const TextStyle(
              color: Color(0xFFFFD54F),
              fontSize: 15,
              fontWeight: FontWeight.w900,
              shadows: [Shadow(color: Colors.black, blurRadius: 4)],
            ),
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: left,
              minHeight: 8,
              backgroundColor: const Color(0x66000000),
              // 시간이 얼마 안 남으면 붉어진다 — 숫자 없이 급한 게 읽힌다.
              valueColor: AlwaysStoppedAnimation(
                left > 0.35 ? const Color(0xFF9CCC65) : const Color(0xFFE57373),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _caughtBanner() => Positioned(
    left: 0,
    right: 0,
    top: 14,
    child: Text(
      '✔ $_caught',
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: Color(0xFFFFF176),
        fontSize: 15,
        fontWeight: FontWeight.w900,
        shadows: [Shadow(color: Colors.black, blurRadius: 4)],
      ),
    ),
  );

  Widget _heroSprite(double span) {
    final swinging = _act == _Act.swing;
    final walking = _act == _Act.chase;
    // 휘두르는 동안은 두 장을 **한 번씩** 넘긴다(들어올림 → 내려침).
    final swingFrame = _actT < 0.3 ? 1 : 2;
    return Positioned(
      left: 8 + _hero.x * span,
      bottom: 22 + (walking ? _hero.hop * 0.7 : 0),
      child: Transform.rotate(
        // 내려칠 때 상체가 앞으로 쏠린다 — 휘두르는 힘이 여기서 읽힌다.
        angle: swinging
            ? (_actT < 0.3 ? -0.12 : 0.14) * (_hero.facingRight ? 1 : -1)
            : walking
            ? math.sin(_t * _kStepHz) * 0.03
            : 0,
        child: Transform.scale(
          scaleX: _hero.facingRight ? 1 : -1,
          // 발이 땅에 닿을 때 살짝 눌린다. 흔드는 주기를 **프레임 교체 주기에
          // 맞춘다** — 따로 놀면 그림과 어긋나 떨린다.
          scaleY: walking ? 1 + math.sin(_t * _kStepHz * 2) * 0.02 : 1,
          child: gameImageChain(
            [
              if (swinging)
                'assets/images/character/attack_$swingFrame.webp'
              else if (walking)
                'assets/images/character/walk_${(_t * _kWalkFps).floor() % 2 + 1}.webp'
              else
                'assets/images/character/idle.webp',
              'assets/images/character/idle.webp',
              'assets/images/character/idle_1.webp',
            ],
            size: 62,
            byHeight: true,
            fallback: const Text('🧍', style: TextStyle(fontSize: 44)),
          ),
        ),
      ),
    );
  }

  Widget _bugSprite(dynamic data, int i, double span) {
    final w = _wild[i];
    final species = data?.speciesById[w.speciesId];
    final marked = _chance == i;

    return Positioned(
      left: 30 + w.bug.x * span,
      bottom: 20 + w.bug.hop,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 놀란 표시 / 노려진 표시 — 어느 놈이 걸렸는지 읽혀야 한다.
          SizedBox(
            height: 14,
            child: marked
                ? const Text(
                    '★',
                    style: TextStyle(
                      color: Color(0xFFFFD54F),
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  )
                : w.bug.startled
                ? const Text(
                    '!',
                    style: TextStyle(
                      color: Color(0xFFFFD54F),
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  )
                : null,
          ),
          Transform.scale(
            scaleX: w.bug.facingRight ? 1 : -1,
            // ⚠️ 경로 규약은 `bugs/{id}_adult.webp` 다(`species/` 가 아니다).
            // 틀린 경로는 에러 없이 조용히 폴백해서 **곤충이 영영 안 보였다**.
            child: bugStageImage(
              w.speciesId,
              LifeStage.adult,
              size: 34,
              fallback: Text(
                '🐛',
                style: TextStyle(
                  fontSize: 24,
                  color: species == null ? null : gradeColor(species.grade),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 무대에 서 있는 야생 곤충 한 마리 — 어떤 종인지 + 어떻게 움직이는지.
class _Wild {
  const _Wild({required this.speciesId, required this.bug});

  final String speciesId;
  final _Wanderer bug;
}

/// 곤충 한 마리의 배회 — 좌우로 오가며 가끔 통통 뛴다.
class _Wanderer {
  _Wanderer({required int seed}) : _rng = math.Random(seed) {
    x = _rng.nextDouble();
    _speed = 0.06 + _rng.nextDouble() * 0.07;
    facingRight = _rng.nextBool();
    _hopPhase = _rng.nextDouble() * math.pi * 2;
  }

  final math.Random _rng;

  /// 0~1 (무대 안 상대 위치).
  double x = 0;
  double hop = 0;
  bool facingRight = true;

  double _speed = 0.1;
  double _hopPhase = 0;
  double _pause = 0;

  /// 놀라서 달아나는 중이면 > 0.
  double _flee = 0;

  /// 방금 놀랐나 — 느낌표를 띄우는 동안.
  bool get startled => _flee > 0.55;

  /// 채집망에 놀란다 — `dir` 쪽(휘두른 방향)으로 튄다.
  void startle(int dir) {
    _flee = 0.9;
    _pause = 0;
    facingRight = dir > 0;
  }

  void step(double dt) {
    if (_flee > 0) _flee = math.max(0, _flee - dt);
    // 가끔 멈춰 선다 — 계속 왕복만 하면 기계처럼 보인다.
    if (_pause > 0) {
      _pause -= dt;
    } else {
      // 놀랐을 땐 훨씬 빠르게 튄다.
      final v = _speed * (_flee > 0 ? 4.5 : 1);
      x += (facingRight ? 1 : -1) * v * dt;
      if (x <= 0) {
        x = 0;
        facingRight = true;
        _pause = _flee > 0 ? 0 : _rng.nextDouble() * 1.2;
      } else if (x >= 1) {
        x = 1;
        facingRight = false;
        _pause = _flee > 0 ? 0 : _rng.nextDouble() * 1.2;
      }
    }
    _hopPhase += dt * (_flee > 0 ? 14 : 6);
    hop = (math.sin(_hopPhase).abs()) * (_flee > 0 ? 6 : 3);
  }

  /// 캐릭터가 걸을 때의 위아래 흔들림만 갱신한다(위치는 사냥 로직이 정한다).
  void bob(double dt) {
    _hopPhase += dt * 6;
    hop = (math.sin(_hopPhase).abs()) * 3;
    x = x.clamp(0.0, 1.0);
  }
}

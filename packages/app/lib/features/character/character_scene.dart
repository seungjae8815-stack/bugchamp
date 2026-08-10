import 'dart:math' as math;

import 'package:core_models/core_models.dart';
import 'package:core_save/core_save.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/providers.dart';
import '../../ui/art.dart';
import '../../ui/labels.dart';

/// 캐릭터 탭 상단의 **살아 있는 씬**.
///
/// 홈 화면처럼 캐릭터가 서 있고 장착한 곤충들이 곁에서 자유롭게 걸어다닌다.
/// 정지된 초상 하나보다 이쪽이 "내 캐릭터"라는 느낌을 준다.
///
/// 스프라이트는 **홈과 같은 파일을 그대로 쓴다**(`character/idle_1.webp` …).
/// 없으면 이모지로 폴백하므로 아트가 없어도 동작한다(§6).
class CharacterScene extends ConsumerStatefulWidget {
  const CharacterScene({super.key, required this.save});

  final SaveGame save;

  @override
  ConsumerState<CharacterScene> createState() => _CharacterSceneState();
}

class _CharacterSceneState extends ConsumerState<CharacterScene>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _last = Duration.zero;

  /// 곤충 한 마리의 배회 상태. 화면 밖으로 안 나가게 좌우 끝에서 되돌아온다.
  final List<_Wanderer> _bugs = [];

  /// 캐릭터도 제자리에 서 있지 않고 조금씩 거닌다.
  final _hero = _Wanderer(seed: 3);
  double _t = 0;

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
      _hero.step(dt);
      for (final b in _bugs) {
        b.step(dt);
      }
    });
  }

  /// 장착 곤충이 바뀌면 배회자 목록을 맞춘다.
  void _sync(int count) {
    if (_bugs.length == count) return;
    while (_bugs.length < count) {
      // 시작 위치·속도를 조금씩 다르게 — 똑같이 움직이면 복제로 보인다.
      final i = _bugs.length;
      _bugs.add(_Wanderer(seed: i * 37 + 11));
    }
    while (_bugs.length > count) {
      _bugs.removeLast();
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(gameDataProvider).value;
    final ids = widget.save.equippedBugIds;
    _sync(ids.length);

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 132,
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
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [const Color(0x00000000), const Color(0x66000000)],
                  ),
                ),
              ),
            ),
            LayoutBuilder(
              builder: (context, c) => Stack(
                children: [
                  // 바닥선 — 캐릭터와 곤충이 같은 지면에 선 것처럼 보이게.
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 26,
                    child: Container(height: 1, color: const Color(0x22FFFFFF)),
                  ),
                  // 캐릭터도 곤충들처럼 **거닌다**. 걷기 스프라이트가 없어서
                  // (idle/attack/death 뿐) 위치와 기울기로 움직임을 만든다.
                  Positioned(
                    left: 16 + _hero.x * 26,
                    bottom: 22 + (_hero.moving ? _hero.hop * 0.7 : 0),
                    // 걷기 스프라이트(`walk_1`·`walk_2`)가 있으면 **번갈아** 쓰고,
                    // 없으면 idle 한 장을 **코드로 걷는 것처럼** 흔든다.
                    // 그림이 없다고 화면이 죽어 있으면 안 된다(§6 폴백 원칙).
                    child: Transform.rotate(
                      angle: _hero.moving ? math.sin(_t * 6.0) * 0.045 : 0,
                      child: Transform.scale(
                        scaleX: _hero.facingRight ? 1 : -1,
                        // 발이 땅에 닿을 때 살짝 눌린다 — 이것만으로 걸음이 읽힌다.
                        scaleY: _hero.moving
                            ? 1 + math.sin(_t * 12.0) * 0.03
                            : 1,
                        child: gameImageChain(
                          [
                            'assets/images/character/walk_${(_t * 5).floor() % 2 + 1}.webp',
                            'assets/images/character/idle_1.webp',
                            'assets/images/character/idle.webp',
                          ],
                          size: 62,
                          byHeight: true,
                          fallback: const Text(
                            '🧍',
                            style: TextStyle(fontSize: 44),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // 곤충들 — 캐릭터 오른쪽 공간을 자유롭게 배회한다.
                  for (var i = 0; i < ids.length && i < _bugs.length; i++)
                    _bugSprite(context, data, ids[i], _bugs[i], c.maxWidth),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bugSprite(
    BuildContext context,
    dynamic data,
    String bugId,
    _Wanderer w,
    double width,
  ) {
    IndividualBug? bug;
    for (final b in widget.save.bugs) {
      if (b.id == bugId) {
        bug = b;
        break;
      }
    }
    final species = bug == null ? null : data?.speciesById[bug.speciesId];
    // 캐릭터(왼쪽 18~80) 를 피해 오른쪽 영역에서만 돈다.
    const left = 96.0;
    final span = (width - left - 44).clamp(40.0, 400.0);
    final x = left + w.x * span;

    return Positioned(
      left: x,
      bottom: 20 + w.hop,
      child: Transform.scale(
        scaleX: w.facingRight ? 1 : -1,
        // ⚠️ 경로 규약은 `bugs/{id}_adult.webp` 다(`species/` 가 아니다).
        // 틀린 경로는 에러 없이 조용히 폴백해서 **곤충이 영영 안 보였다**.
        child: bug == null
            ? const Text('🐛', style: TextStyle(fontSize: 24))
            : bugStageImage(
                bug.speciesId,
                bug.stage,
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
    );
  }
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

  /// 0~1 (구간 내 상대 위치).
  double x = 0;
  double hop = 0;
  bool facingRight = true;

  double _speed = 0.1;
  double _hopPhase = 0;
  double _pause = 0;

  /// 지금 걷는 중인가 — 멈춰 섰을 땐 흔들지 않아야 자연스럽다.
  bool get moving => _pause <= 0;

  void step(double dt) {
    // 가끔 멈춰 선다 — 계속 왕복만 하면 기계처럼 보인다.
    if (_pause > 0) {
      _pause -= dt;
    } else {
      x += (facingRight ? 1 : -1) * _speed * dt;
      if (x <= 0) {
        x = 0;
        facingRight = true;
        _pause = _rng.nextDouble() * 1.2;
      } else if (x >= 1) {
        x = 1;
        facingRight = false;
        _pause = _rng.nextDouble() * 1.2;
      }
    }
    _hopPhase += dt * 6;
    hop = (math.sin(_hopPhase).abs()) * 3;
  }
}

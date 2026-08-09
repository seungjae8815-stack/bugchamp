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
        child: LayoutBuilder(
          builder: (context, c) => Stack(
            children: [
              // 바닥선 — 캐릭터와 곤충이 같은 지면에 선 것처럼 보이게.
              Positioned(
                left: 0,
                right: 0,
                bottom: 26,
                child: Container(height: 1, color: const Color(0x22FFFFFF)),
              ),
              // 캐릭터는 왼쪽에 고정. 숨쉬듯 위아래로만 흔들린다.
              Positioned(
                left: 18,
                bottom: 22,
                child: Transform.translate(
                  offset: Offset(0, math.sin(_t * 2.2) * 2),
                  child: gameImageChain(
                    const [
                      'assets/images/character/idle_1.webp',
                      'assets/images/character/idle.webp',
                    ],
                    size: 62,
                    byHeight: true,
                    fallback: const Text('🧍', style: TextStyle(fontSize: 44)),
                  ),
                ),
              ),
              // 곤충들 — 캐릭터 오른쪽 공간을 자유롭게 배회한다.
              for (var i = 0; i < ids.length && i < _bugs.length; i++)
                _bugSprite(context, data, ids[i], _bugs[i], c.maxWidth),
            ],
          ),
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
        child: gameImageChain(
          [if (species != null) 'assets/images/species/${species.id}.webp'],
          size: 34,
          byHeight: true,
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

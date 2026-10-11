import 'package:core_battle/core_battle.dart';
import 'package:core_models/core_models.dart';
import 'package:core_save/core_save.dart';
import 'package:flutter/material.dart' hide Element;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/game_data.dart';
import '../../domain/audio_service.dart';
import '../../domain/providers.dart';
import '../../ui/colors.dart';
import '../../ui/skins.dart';
import '../../ui/toast.dart';
import 'duel_arena_screen.dart';
import 'duel_bug_build.dart';
import 'duel_driver.dart';

/// 홍보 영상 촬영 모드(개발 빌드 전용 — 개발자 모드 시트에서만 연다).
///
/// 아무 종·크기·이색이나 골라 1:1 결투를 **앱에서** 계산하고 결투 화면으로 재생한다.
/// 엔진이 결정론이라 seed 를 훑어 원하는 결말(장외·뒤집기·탭 반격 역전)이 나는 판을 고른다.
/// 서버·세이브·보상과 무관하다(빈 세이브로 만든 곤충 — 훈련 보너스 없음).
class DuelCaptureScreen extends ConsumerStatefulWidget {
  const DuelCaptureScreen({super.key});

  @override
  ConsumerState<DuelCaptureScreen> createState() => _DuelCaptureScreenState();
}

/// 촬영할 한 곤충.
class _Shot {
  const _Shot(
    this.speciesId,
    this.sizeMm,
    this.element,
    this.temperament, {
    this.variant = BugVariant.none,
  });

  final String speciesId;
  final double sizeMm;
  final Element element;
  final Temperament temperament;
  final BugVariant variant;
}

/// 한 장면 — 두 곤충과 원하는 결말. 조건이 비면 아무 판이나.
class _Scene {
  const _Scene(
    this.title,
    this.a,
    this.b, {
    required this.arena,
    this.finishes = const {
      DuelFinish.ringOut,
      DuelFinish.flip,
      DuelFinish.knockout,
    },
    this.winner,
    this.needSave = false,
    this.maxSeconds = 15,
  });

  final String title;
  final _Shot a;
  final _Shot b;
  final Element arena;
  final Set<DuelFinish> finishes;

  /// 0 = 왼쪽(A)이 이긴다, 1 = 오른쪽(B), null = 상관없음.
  final int? winner;

  /// A 가 탭 반격으로 살아나는 판만.
  final bool needSave;
  static const minSeconds = 5.0;
  final double maxSeconds;
}

const _scenes = <_Scene>[
  _Scene(
    '장수풍뎅이 vs 왕사슴벌레',
    _Shot('rhino_japanese', 84, Element.fire, Temperament.aggressive),
    _Shot('stag_giant', 90, Element.metal, Temperament.steadfast),
    arena: Element.wood,
    winner: 0,
  ),
  _Scene(
    '말벌 28mm가 하늘소 118mm를 이긴다',
    _Shot('hornet_giant', 28, Element.fire, Temperament.cunning),
    _Shot('longhorn_relict', 118, Element.metal, Temperament.steadfast),
    arena: Element.earth,
    winner: 0,
  ),
  _Scene(
    '탭 반격으로 버티고 역전',
    _Shot('stag_twospot', 66, Element.water, Temperament.steadfast),
    _Shot('mantis_giant', 92, Element.fire, Temperament.aggressive),
    arena: Element.water,
    winner: 0,
    needSave: true,
    maxSeconds: 22,
  ),
  _Scene(
    '무지개 이색 왕사마귀',
    _Shot(
      'mantis_giant',
      93,
      Element.wood,
      Temperament.aggressive,
      variant: BugVariant.rainbow,
    ),
    _Shot('stag_miyama', 76, Element.earth, Temperament.cautious),
    arena: Element.wood,
    winner: 0,
  ),
  _Scene(
    '장외로 밀어내기',
    _Shot('water_bug_giant', 70, Element.water, Temperament.steadfast),
    _Shot('rhino_japanese', 80, Element.fire, Temperament.fickle),
    arena: Element.water,
    finishes: {DuelFinish.ringOut},
    winner: 0,
  ),
  _Scene(
    '뒤집어서 끝내기',
    _Shot('rhino_japanese', 85, Element.metal, Temperament.aggressive),
    _Shot('longhorn_relict', 100, Element.wood, Temperament.cautious),
    arena: Element.metal,
    finishes: {DuelFinish.flip},
    winner: 0,
  ),
  _Scene(
    '알비노 사슴벌레',
    _Shot(
      'stag_giant',
      91,
      Element.metal,
      Temperament.steadfast,
      variant: BugVariant.albino,
    ),
    _Shot('stag_flat', 85, Element.wood, Temperament.aggressive),
    arena: Element.metal,
    winner: 0,
  ),
];

class _DuelCaptureScreenState extends ConsumerState<DuelCaptureScreen> {
  double _speed = 1;
  bool _slowMo = true;
  bool _playing = false;

  DuelBug _bugOf(_Shot s, String id, GameData data, String locale) {
    final bug = IndividualBug(
      id: id,
      speciesId: s.speciesId,
      sizeMm: s.sizeMm,
      potential: 5,
      temperament: s.temperament,
      sex: Sex.male,
      variant: s.variant,
      element: s.element,
    );
    return duelBugFor(bug, data, SaveGame.initial(), locale);
  }

  /// 조건에 맞는 첫 seed 의 판. 없으면 null.
  DuelBout? _find(_Scene sc, DuelBug a, DuelBug b, DuelParams p) {
    for (var seed = 1; seed <= 4000; seed++) {
      final bout = simulateBout(seed: seed, a: a, b: b, params: p);
      final secs = bout.ticks / p.tickHz;
      if (!sc.finishes.contains(bout.finish)) continue;
      if (sc.winner != null && bout.winner != sc.winner) continue;
      if (secs < _Scene.minSeconds || secs > sc.maxSeconds) continue;
      if (sc.needSave &&
          !bout.events.any(
            (e) => e.kind == DuelEventKind.clutchSave && e.who == 0,
          )) {
        continue;
      }
      debugPrint(
        '[capture] "${sc.title}" seed=$seed finish=${bout.finish.key} '
        'winner=${bout.winner} secs=${secs.toStringAsFixed(1)} events='
        '${bout.events.map((e) => '${e.kind.name}@${(e.tick / p.tickHz).toStringAsFixed(2)}/${e.who}').join(',')}',
      );
      return bout;
    }
    return null;
  }

  Future<void> _play(List<_Scene> scenes) async {
    if (_playing) return;
    final data = ref.read(gameDataProvider).requireValue;
    final locale = Localizations.localeOf(context).languageCode;
    final params = duelParamsOf(data);
    setState(() => _playing = true);
    AudioService.captureLog = true;
    for (final sc in scenes) {
      if (!mounted) break;
      final a = _bugOf(sc.a, 'capA', data, locale);
      final b = _bugOf(sc.b, 'capB', data, locale);
      final bout = _find(sc, a, b, params);
      if (bout == null) {
        showCenterToast(context, '조건에 맞는 판 없음: ${sc.title}');
        continue;
      }
      debugPrint(
        '[capture-scene] ${DateTime.now().millisecondsSinceEpoch} ${sc.title}',
      );
      // 전환 애니메이션 없이 — 녹화본에서 장면이 바뀌는 순간이 효과음 로그와 맞물리게.
      await Navigator.of(context).push(
        PageRouteBuilder<void>(
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
          pageBuilder: (_, _, _) => DuelArenaScreen(
            mine: [a],
            foe: [b],
            driver: PrebakedDuelDriver(bouts: [bout]),
            params: params,
            arena: sc.arena,
            showDuelResult: false,
            playbackSpeed: _speed,
            cinematic: _slowMo,
            mySkins: {
              if (sc.a.variant != BugVariant.none)
                a.id: SkinView(sc.a.variant.key),
            },
            foeSkins: {
              if (sc.b.variant != BugVariant.none)
                b.id: SkinView(sc.b.variant.key),
            },
            onFinished: (_) async {},
          ),
        ),
      );
      // 장면 사이 — 편집할 때 자르기 쉽게 잠깐 비운다.
      await Future<void>.delayed(const Duration(milliseconds: 1200));
    }
    AudioService.captureLog = false;
    if (mounted) setState(() => _playing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B1A14),
      appBar: AppBar(
        title: const Text('🎬 결투 촬영 모드'),
        backgroundColor: const Color(0xFF1B1A14),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              const Text('속도', style: TextStyle(color: Colors.white)),
              const SizedBox(width: 8),
              for (final s in const [1.0, 0.7, 0.5])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text('×$s'),
                    selected: _speed == s,
                    onSelected: (_) => setState(() => _speed = s),
                  ),
                ),
            ],
          ),
          SwitchListTile(
            value: _slowMo,
            onChanged: (v) => setState(() => _slowMo = v),
            title: const Text(
              '결판·탭 반격 순간 슬로모션 + 건너뛰기 버튼 숨김',
              style: TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            key: const ValueKey('capture-all'),
            onPressed: _playing ? null : () => _play(_scenes),
            style: FilledButton.styleFrom(
              backgroundColor: kHoney,
              foregroundColor: const Color(0xFF3A2410),
              minimumSize: const Size.fromHeight(52),
            ),
            child: const Text(
              '전부 연속 재생',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(height: 12),
          for (final sc in _scenes)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: OutlinedButton(
                onPressed: _playing ? null : () => _play([sc]),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(44),
                ),
                child: Text(sc.title),
              ),
            ),
        ],
      ),
    );
  }
}

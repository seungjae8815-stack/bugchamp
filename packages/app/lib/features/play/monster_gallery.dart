import 'dart:async';

import 'package:core_run/core_run.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/providers.dart';
import '../../ui/art.dart';
import '../../ui/labels.dart';

/// 개발자용 — **몬스터·보스 그림과 모션을 한 화면에서** 본다.
///
/// 몬스터는 스테이지를 실제로 밟아야 나오고, 타격·피격 자세는 몬스터가 나를
/// 때리거나 내가 때리는 **찰나**에만 스친다. 아트를 넣고 확인하는 데 그건
/// 못 쓴다(장비 갤러리를 만든 이유와 같다).
///
/// 두 가지를 본다:
/// - **모션**: 종마다 네 자세를 자동으로 돌린다 → 반전 방향·프레임 누락이 보인다.
/// - **스테이지**: 특정 스테이지에서 실제로 어떤 순서로 나오는지 늘어놓는다.
class MonsterGalleryScreen extends ConsumerStatefulWidget {
  const MonsterGalleryScreen({super.key});

  @override
  ConsumerState<MonsterGalleryScreen> createState() =>
      _MonsterGalleryScreenState();
}

/// 코드가 찾는 네 상태. 파일 접미사와 화면 라벨을 **한 곳**에 둔다 —
/// 갈라 두면 "갤러리에는 나오는데 게임에는 안 나온다"가 생긴다.
const _poses = <({String suffix, String label})>[
  (suffix: '', label: '대기'),
  (suffix: '_attack_1', label: '덤벼듦'),
  (suffix: '_attack_2', label: '복귀'),
  (suffix: '_hurt_1', label: '움찔'),
];

class _MonsterGalleryScreenState extends ConsumerState<MonsterGalleryScreen> {
  Timer? _tick;

  /// 지금 보여줄 자세 인덱스. 모든 종이 **같은 박자**로 넘어간다 —
  /// 제각각 돌면 어느 자세를 보고 있는지 알 수 없다.
  int _pose = 0;

  /// 자동 재생 중인가. 끄면 한 자세를 붙잡고 볼 수 있다.
  bool _playing = true;

  /// 스테이지 미리보기에서 볼 스테이지.
  int _stage = 1;
  final _stageCtrl = TextEditingController(text: '1');

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(milliseconds: 700), (_) {
      if (!_playing || !mounted) return;
      setState(() => _pose = (_pose + 1) % _poses.length);
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _stageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(gameDataProvider).value;
    final run = data?.runConfig;
    if (run == null) return const Scaffold();
    final locale = Localizations.localeOf(context).languageCode;
    final monsters = run.monsters.values.toList();

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('🛠 몬스터 그림 확인'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '몬스터'),
              Tab(text: '스테이지'),
              Tab(text: '보스'),
            ],
          ),
          actions: [
            IconButton(
              tooltip: _playing ? '멈춤' : '재생',
              icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
              onPressed: () => setState(() => _playing = !_playing),
            ),
          ],
        ),
        body: TabBarView(
          children: [
            _monsterTab(monsters, locale),
            _stageTab(run, locale),
            _bossTab(run, locale),
          ],
        ),
      ),
    );
  }

  // ── 1. 몬스터: 종별 네 자세 ───────────────────────────────────

  Widget _monsterTab(List<MonsterDef> monsters, String locale) => ListView(
    padding: const EdgeInsets.all(10),
    children: [
      _hint(
        '지금 자세: ${_poses[_pose].label} · 700ms 마다 넘어갑니다. '
        '오른쪽 위 버튼으로 멈출 수 있어요.\n'
        '⚠️ 모두 **왼쪽(플레이어 쪽)** 을 봐야 합니다. 오른쪽을 보면 좌우반전이 '
        '안 된 것이고, 자세가 안 바뀌면 그 프레임 파일이 없는 것입니다.',
      ),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 0.78,
        ),
        itemCount: monsters.length,
        itemBuilder: (_, i) => _card(monsters[i], locale),
      ),
    ],
  );

  Widget _card(MonsterDef m, String locale) => Container(
    padding: const EdgeInsets.all(6),
    decoration: BoxDecoration(
      color: const Color(0x22000000),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0x33FFFFFF)),
    ),
    child: Column(
      children: [
        Expanded(
          child: Center(child: _sprite(m, _poses[_pose].suffix, size: 76)),
        ),
        Text(
          m.name.resolve(locale),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
        // 어떤 자세 파일이 실제로 있는지 — 없으면 대기 그림으로 조용히
        // 내려가므로, 화면만 봐서는 "안 만든 것"과 "안 나오는 것"이 같아 보인다.
        Text(
          'x${m.scale}',
          style: const TextStyle(color: Color(0x77FFFFFF), fontSize: 9),
        ),
      ],
    ),
  );

  /// 게임과 **같은 경로 규칙**으로 그린다(`play_screen` 의 ePaths).
  Widget _sprite(MonsterDef m, String suffix, {required double size}) =>
      gameImageChain(
        [
          'assets/images/habitats/${m.id}$suffix.webp',
          'assets/images/habitats/${m.id}.webp',
        ],
        size: size,
        byHeight: true,
        fallback: Text(m.glyph, style: TextStyle(fontSize: size * 0.62)),
      );

  // ── 2. 스테이지: 실제 등장 순서 ───────────────────────────────

  Widget _stageTab(RunConfig run, String locale) {
    final region = run.regionForStage(_stage);
    final count = run.habitatsPerStage;
    // 게임과 **같은 함수**를 쓴다 — 갤러리가 따로 계산하면 "여기선 이런데
    // 게임에선 다르다"가 되어 확인하는 의미가 없다.
    final ids = [for (var i = 0; i < count; i++) monsterIdAt(run, _stage, i)];
    return ListView(
      padding: const EdgeInsets.all(10),
      children: [
        Row(
          children: [
            SizedBox(
              width: 90,
              child: TextField(
                controller: _stageCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: '스테이지',
                  labelStyle: TextStyle(color: Color(0x99FFFFFF)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () {
                final n = int.tryParse(_stageCtrl.text.trim());
                if (n != null && n >= 1) setState(() => _stage = n);
              },
              child: const Text('보기'),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () => setState(() {
                _stage = _stage > 1 ? _stage - 1 : 1;
                _stageCtrl.text = '$_stage';
              }),
              icon: const Icon(Icons.chevron_left),
            ),
            IconButton(
              onPressed: () => setState(() {
                _stage++;
                _stageCtrl.text = '$_stage';
              }),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        _hint(
          '${region.name.resolve(locale)}'
          '${region.element == null ? '' : ' · ${region.element!.key}'}'
          ' · $count마리\n'
          '⚠️ 같은 몬스터가 **연달아** 있으면 순서 섞기가 깨진 것입니다.',
        ),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var i = 0; i < ids.length; i++)
              _stageCell(run, ids[i], i, locale),
          ],
        ),
        const SizedBox(height: 14),
        _hint(
          '이 지역에 배정된 종: '
          '${region.monsterKeys.map((k) => run.monsters[k]?.name.resolve(locale) ?? k).join(' · ')}',
        ),
      ],
    );
  }

  Widget _stageCell(RunConfig run, String id, int index, String locale) {
    final m = run.monsters[id];
    final elite = isEliteAt(
      stageNumber: _stage,
      habitatIndex: index,
      chance: run.eliteChance,
      boss: false,
    );
    return SizedBox(
      width: 78,
      child: Column(
        children: [
          SizedBox(
            height: 64,
            child: Center(
              child: m == null
                  ? const Text('?')
                  : _sprite(
                      m,
                      _poses[_pose].suffix,
                      size: 56 * (elite ? run.eliteScale : 1.0) * m.scale,
                    ),
            ),
          ),
          Text(
            '${index + 1}. ${m?.name.resolve(locale) ?? id}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: elite ? const Color(0xFFB39DDB) : Colors.white,
              fontSize: 9,
              fontWeight: elite ? FontWeight.w900 : FontWeight.w600,
            ),
          ),
          if (elite)
            const Text(
              '정예',
              style: TextStyle(
                color: Color(0xFFB39DDB),
                fontSize: 8,
                fontWeight: FontWeight.w900,
              ),
            ),
        ],
      ),
    );
  }

  // ── 3. 보스 ──────────────────────────────────────────────────

  Widget _bossTab(RunConfig run, String locale) => ListView(
    padding: const EdgeInsets.all(10),
    children: [
      _hint(
        '보스는 지역마다 하나입니다. 자세는 몬스터와 **다른 순서**예요 — '
        '보스 시트는 1=내리치기 / 2=곧추서기 입니다.\n'
        '⚠️ 보스는 `bossFlip` 이 true 면 코드가 좌우를 뒤집습니다. '
        '여기서는 그 뒤집기까지 적용해 **게임과 같은 방향**으로 보여줍니다.',
      ),
      for (final r in run.regions) _bossRow(r, locale),
    ],
  );

  Widget _bossRow(RegionConfig r, String locale) {
    const states = <({String suffix, String label})>[
      (suffix: '', label: '대기'),
      (suffix: '_attack_1', label: '공격1'),
      (suffix: '_attack_2', label: '공격2'),
      (suffix: '_death_1', label: '사망1'),
      (suffix: '_death_2', label: '사망2'),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${r.bossName.resolve(locale)}  (${r.id})',
                style: const TextStyle(
                  color: Color(0xFFFFD54F),
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 6),
              if (r.element != null) elementIcon(r.element!, size: 14),
              const SizedBox(width: 6),
              Text(
                r.bossFlip ? 'flip' : '',
                style: const TextStyle(color: Color(0x99FFFFFF), fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final s in states)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Column(
                      children: [
                        SizedBox(height: 96, child: _boss(r, s.suffix)),
                        Text(
                          s.label,
                          style: const TextStyle(
                            color: Color(0x99FFFFFF),
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _boss(RegionConfig r, String suffix) {
    final art = gameImageChain(
      [
        'assets/images/bosses/${r.id}$suffix.webp',
        'assets/images/bosses/${r.id}.webp',
      ],
      size: 92,
      byHeight: true,
      fallback: const Text('🪲', style: TextStyle(fontSize: 56)),
    );
    // 게임과 같은 규칙으로 뒤집는다.
    return r.bossFlip
        ? Transform.scale(scaleX: -1, alignment: Alignment.center, child: art)
        : art;
  }

  // ── 공통 ─────────────────────────────────────────────────────

  Widget _hint(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      text,
      style: const TextStyle(color: Color(0xAAFFFFFF), fontSize: 11.5),
    ),
  );
}

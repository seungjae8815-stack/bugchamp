import 'package:app/data/game_data.dart';
import 'package:app/features/battle/arena_widgets.dart';
import 'package:app/ui/art.dart';
import 'package:core_battle/core_battle.dart';
import 'package:core_models/core_models.dart';
import 'package:flutter/material.dart' hide Element;
import 'package:flutter_test/flutter_test.dart';

import 'package:app/l10n/app_localizations.dart';

/// 아레나 배치가 **좁은 화면에서 넘치지 않는지** 검증.
///
/// 대각 구도로 바꾸면서 한 무대 안에 곤충(116)·이름표(138)·스탠스 그림이 겹쳐
/// 들어간다. 넘치면 앱이 죽지는 않고 **줄무늬 오버플로 띠**를 그렸다 지우는데,
/// 실기에서는 "오류 같은 화면이 잠깐 떴다 사라진다"로 보인다(2026-08-17 지적).
/// 눈으로는 놓치기 쉬우므로 제일 좁은 화면으로 여기서 잡는다.
BattleBug _bug(String id, Element e) => BattleBug(
  id: id,
  name: '아주긴곤충이름테스트',
  element: e,
  temperament: Temperament.aggressive,
  preferredStance: Stance.attack,
  maxHp: 100,
  atk: 20,
  def: 10,
  spd: 10,
);

const _data = GameData(
  speciesById: {},
  trapById: {},
  fields: [],
  spawnTable: SpawnTable([]),
);

Widget _stage(
  Size size, {
  double flash = 0,
  double dx = 0,
  bool intro = false,
}) {
  final mine = _bug('a', Element.wood);
  final foe = _bug('b', Element.fire);
  // 이름표의 "나/상대" 칩이 다국어를 쓰므로 델리게이트가 필요하다.
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('ko'),
    home: MediaQuery(
      data: MediaQueryData(size: size),
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: size.width,
          // 실제 화면에서 무대가 차지하는 비율(나머지는 상단바·하단 조작).
          height: size.height * 0.52,
          child: ArenaStage(
            background: const ColoredBox(color: Color(0xFF1E3B28)),
            mineBody: ArenaBody(
              data: _data,
              bug: mine,
              speciesId: 'stag_giant',
              flip: false,
              stance: Stance.attack,
              flash: flash,
              dx: dx,
              size: 104,
            ),
            foeBody: ArenaBody(
              data: _data,
              bug: foe,
              speciesId: 'stag_giant',
              flip: true,
              stance: Stance.defend,
              flash: flash,
              dx: -dx,
              size: 104,
            ),
            minePlate: ArenaPlate(bug: mine, hpFrac: 0.6, mine: true),
            foePlate: ArenaPlate(bug: foe, hpFrac: 0.3, mine: false),
            overlays: [if (intro) const ArenaIntro(t: 0.5)],
          ),
        ),
      ),
    ),
  );
}

void main() {
  // 320×568 = 아이폰 SE. 여기서 통과하면 더 넓은 화면은 안전하다.
  for (final size in const [Size(320, 568), Size(360, 640), Size(412, 915)]) {
    testWidgets('무대가 ${size.width.toInt()}px 화면에서 안 넘친다', (t) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(_stage(size));
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('인트로·타격 중에도 안 넘친다', (t) async {
    const size = Size(320, 568);
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(_stage(size, flash: 1, dx: 24, intro: true));
    await t.pump(const Duration(milliseconds: 16));
    expect(t.takeException(), isNull);
  });

  group('라운드 3박자 자세', () {
    // 스탠스 특성상 대부분의 라운드는 **양쪽이 다 때린다**. 예전 규칙
    // ("돌진 중이면 공격")에서는 그때 피격 자세가 아예 안 나왔다.
    test('때리고 맞은 곤충도 공격 → 피격 → 대기를 다 보여준다', () {
      BugPose at(double t) => arenaPose(clash: t, struck: true, damaged: true);
      expect(at(0.05), BugPose.attack, reason: '뻗는 중');
      expect(at(0.25), BugPose.hurt, reason: '맞는 중 — 뻗기를 이긴다');
      expect(at(0.60), BugPose.idle, reason: '되돌아오는 중');
    });

    test('때리기만 한 곤충은 피격이 안 나온다', () {
      expect(
        arenaPose(clash: 0.25, struck: true, damaged: false),
        BugPose.attack,
      );
    });

    test('맞기만 한 곤충은 공격이 안 나온다', () {
      expect(
        arenaPose(clash: 0.05, struck: false, damaged: true),
        BugPose.idle,
      );
      expect(
        arenaPose(clash: 0.25, struck: false, damaged: true),
        BugPose.hurt,
      );
    });

    test('방어·회복만 한 라운드는 계속 대기', () {
      for (final t in const [0.0, 0.2, 0.5, 0.9]) {
        expect(
          arenaPose(clash: t, struck: false, damaged: false),
          BugPose.idle,
        );
      }
    });

    test('쓰러지는 중이면 무조건 피격', () {
      expect(
        arenaPose(clash: 0.9, struck: true, damaged: false, down: true),
        BugPose.hurt,
      );
    });
  });
}

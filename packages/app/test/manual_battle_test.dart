import 'package:app/data/game_data.dart';
import 'package:app/features/battle/manual_battle_screen.dart';
import 'package:app/l10n/app_localizations.dart';
import 'package:core_battle/core_battle.dart';
import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:flutter/material.dart' hide Element;
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _name(String s) => {'ko': s, 'en': s, 'ja': s};

/// 최소 GameData — 수동 배틀은 `speciesById` 만 참조(파이터 이미지 폴백).
GameData _data() => GameData.fromDecoded(
  species: {
    'species': [
      {
        'id': 'a',
        'name': _name('Test Bug'),
        'grade': 'common',
        'specialty': 'grip',
        'baseStats': {'hp': 100, 'atk': 40, 'def': 30, 'spd': 20},
        'sizeMinMm': 20,
        'sizeMaxMm': 60,
      },
    ],
  },
  traps: {
    'traps': [
      {'id': 'sap_trap', 'name': _name('Sap Trap')},
    ],
  },
  fields: {
    'fields': [
      {'id': 'oak_forest', 'name': _name('Oak Forest'), 'unlockOrder': 0},
    ],
  },
  spawns: {
    'schemaVersion': 1,
    'defaultPotentialWeights': [
      {'potential': 1, 'weight': 1},
    ],
    'spawns': <dynamic>[],
  },
);

BattleBug _bug({required String id, required double hp, required double atk}) =>
    BattleBug(
      id: id,
      name: id,
      element: Element.fire,
      temperament: Temperament.steadfast,
      preferredStance: Stance.attack,
      maxHp: hp,
      atk: atk,
      def: 0,
      spd: 10,
    );

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('en'),
  home: child,
);

void main() {
  testWidgets('수동 배틀: 공격 선택 반복 → 압승 시 보상 콜백(골드·트로피) 적용', (tester) async {
    int? gold;
    int? trophy;

    // 내 곤충은 압도적으로 강함 → 몇 라운드 안에 결착.
    final me = _bug(id: 'me', hp: 500, atk: 300);
    final foe = _bug(id: 'foe', hp: 100, atk: 1);

    await tester.pumpWidget(
      _wrap(
        ManualBattleScreen(
          data: _data(),
          myTeam: [me],
          foeTeam: [foe],
          speciesOf: const {'me': 'a', 'foe': 'a'},
          seed: 7,
          trophiesAtStart: 0,
          config: const BattleConfig(),
          onApply: (g, t, koed) async {
            gold = g;
            trophy = t;
          },
        ),
      ),
    );
    await tester.pump();

    // 입력 단계마다 '공격' 버튼이 활성일 때만 눌러 결착까지 진행.
    final attackBtn = find.widgetWithText(FilledButton, 'Attack');
    for (var i = 0; i < 60 && gold == null; i++) {
      final btn = tester.widget<FilledButton>(attackBtn);
      if (btn.onPressed != null) {
        await tester.tap(attackBtn);
      }
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(gold, isNotNull, reason: '결착 후 onApply 가 호출돼야 한다');
    expect(gold, 4000); // 승리: 4000 + 트로피(0)×30
    expect(trophy, 12); // 승리 트로피 +12

    // 결과 다이얼로그가 뜰 프레임 확보(Ticker 상시 구동이라 pumpAndSettle 금지).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Victory!'), findsOneWidget); // 결과 다이얼로그
  });
}

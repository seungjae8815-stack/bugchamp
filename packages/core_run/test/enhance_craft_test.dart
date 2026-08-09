import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:test/test.dart';

void main() {
  group('부위강화 등급 배수', () {
    final cfg = EnhanceConfig.fromJson({
      'parts': [
        {
          'part': 'hornJaw',
          'material': 'chitin',
          'baseCost': 2,
          'costGrowth': 1.12,
          'effectPerLevel': 0.04,
        },
      ],
      'gradeMult': {'common': 1, 'rare': 4, 'legendary': 16},
    });

    test('등급이 높을수록 비싸다 — 강화 총량이 유한해서 배수가 없으면 후반에 공짜가 된다', () {
      expect(cfg.costFor(BugPart.hornJaw, 0, Grade.common), 2);
      expect(cfg.costFor(BugPart.hornJaw, 0, Grade.rare), 8);
      expect(cfg.costFor(BugPart.hornJaw, 0, Grade.legendary), 32);
    });

    test('레벨 곡선은 그대로 곱해진다', () {
      // 2 x 1.12^10 = 6.2 -> 6, x4 = 24
      expect(cfg.costFor(BugPart.hornJaw, 10, Grade.rare), 24);
    });

    test('배수가 없는 등급·구버전 JSON 은 1배(기존 동작)', () {
      expect(cfg.costFor(BugPart.hornJaw, 0, Grade.epic), 2);
      final old = EnhanceConfig.fromJson({
        'parts': [
          {
            'part': 'hornJaw',
            'material': 'chitin',
            'baseCost': 2,
            'costGrowth': 1.12,
            'effectPerLevel': 0.04,
          },
        ],
      });
      expect(old.costFor(BugPart.hornJaw, 0, Grade.legendary), 2);
    });
  });

  group('제작 재료비 성장', () {
    CraftConfig cfg(double growth) => CraftConfig.fromJson({
      'inputGrowth': growth,
      'recipes': [
        {
          'id': 'potion_gold',
          'buff': 'goldRush',
          'inputs': {'chitin': 20, 'jelly': 5},
        },
      ],
    });

    test('성장률 1.0 이면 고정(기존 동작)', () {
      final c = cfg(1.0);
      expect(c.inputsAt(c.recipes.first, 500)[MaterialKind.chitin], 20);
    });

    test('스테이지에 따라 오른다 — 후반에 물약이 공짜가 되지 않게', () {
      final c = cfg(1.01);
      expect(c.inputsAt(c.recipes.first, 1)[MaterialKind.chitin], 20);
      // 20 x 1.01^99 = 53.6 -> 54
      expect(c.inputsAt(c.recipes.first, 100)[MaterialKind.chitin], 54);
    });

    test('젤리는 성장에서 뺀다 — 프리미엄 재화는 결제 가치가 흔들리면 안 된다', () {
      final c = cfg(1.01);
      expect(c.inputsAt(c.recipes.first, 500)[MaterialKind.jelly], 5);
    });
  });
}

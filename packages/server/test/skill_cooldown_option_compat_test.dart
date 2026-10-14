import 'package:core_models/core_models.dart';
import 'package:core_save/core_save.dart';
import 'package:server/src/actions.dart';
import 'package:server/src/game_config.dart';
import 'package:test/test.dart';

/// 스킬 쿨타임 감소 옵션(2026-10-14 · feat 26) — 1.0.20 이하 앱은 자기 풀에 없는 옵션이라 지우고 올린다.
/// 같은 장비면 서버가 저장본으로 되돌린다(`_restoreDroppedOptions`).
final t0 = DateTime.utc(2026, 10, 14, 12);

void main() {
  late GameActions actions;
  setUpAll(() async {
    final cfg = await GameConfig.load(dir: '../app/assets/data');
    actions = GameActions(config: cfg, now: () => t0);
  });

  const hat = EquipItem(
    slot: EquipSlot.hat,
    tier: 9,
    options: [
      ItemOption(kind: ItemOptionKind.attack, value: 20),
      ItemOption(kind: ItemOptionKind.skillCooldown, value: 5.5),
    ],
  );
  SaveGame stored() => SaveGame.initial(createdAt: t0).copyWith(
    lastSeen: t0.subtract(const Duration(seconds: 60)),
    equippedItems: {EquipSlot.hat: hat},
  );

  Map<String, dynamic> oldUpload(int feat) {
    final j = stored().toJson()..['feat'] = feat;
    final eq = Map<String, dynamic>.from(j['equippedItems'] as Map);
    final item = Map<String, dynamic>.from(eq['hat'] as Map);
    item['o'] = [
      for (final o in item['o'] as List)
        if ((o as Map)['k'] != 'skillCooldown') o,
    ];
    eq['hat'] = item;
    j['equippedItems'] = eq;
    return j;
  }

  for (final feat in [25, 19]) {
    test('feat $feat 앱이 지운 스킬 쿨감 옵션을 되돌린다', () {
      final got = actions
          .mergeSave(stored(), oldUpload(feat))
          .save!
          .equippedItems[EquipSlot.hat]!;
      expect(
        got.options.map((o) => o.kind),
        containsAll([ItemOptionKind.attack, ItemOptionKind.skillCooldown]),
      );
    });
  }

  test('새 앱이 옵션을 바꿔 올리면(다른 장비) 그대로', () {
    final j = stored().toJson()..['feat'] = kSaveFeatureLevel;
    final r = actions.mergeSave(stored(), j);
    expect(r.save!.equippedItems[EquipSlot.hat]!.options.length, 2);
  });
}

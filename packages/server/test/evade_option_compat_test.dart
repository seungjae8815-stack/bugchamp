import 'package:core_models/core_models.dart';
import 'package:core_save/core_save.dart';
import 'package:server/src/actions.dart';
import 'package:server/src/game_config.dart';
import 'package:test/test.dart';

/// 장비 옵션 `evade`(회피, 2026-10-09 · feat 20)와 구버전 앱(1.0.17 = feat 19 이하).
///
/// 1.0.17 의 세이브 파서는 모르는 옵션을 **빼고** 읽는다(ItemOption.tryFromJson — 크래시 없음).
/// 그 앱이 다시 올린 세이브에는 회피 옵션이 빠져 있으므로, 같은 장비면 서버가 저장본을 되돌린다.
final t0 = DateTime.utc(2026, 10, 9, 12);

void main() {
  late GameConfig cfg;
  late GameActions actions;

  setUpAll(() async {
    cfg = await GameConfig.load(dir: '../app/assets/data');
    actions = GameActions(config: cfg, now: () => t0);
  });

  const ringWithEvade = EquipItem(
    slot: EquipSlot.ring,
    tier: 9,
    options: [
      ItemOption(kind: ItemOptionKind.attack, value: 12.5),
      ItemOption(kind: ItemOptionKind.evade, value: 3.1),
    ],
  );

  SaveGame stored() => SaveGame.initial(createdAt: t0).copyWith(
    lastSeen: t0.subtract(const Duration(seconds: 60)),
    equippedItems: {EquipSlot.ring: ringWithEvade},
    forgeStack: const [ringWithEvade],
  );

  /// 1.0.17 앱이 이 세이브를 읽고(회피 옵션을 모르고 뺌) 그대로 다시 올리는 모양.
  Map<String, dynamic> oldAppReupload(SaveGame s) {
    final j = s.toJson()..['feat'] = 19;
    Map<String, dynamic> strip(Map<String, dynamic> item) => {
      ...item,
      'o': [
        for (final o in item['o'] as List)
          if ((o as Map)['k'] != 'evade') o,
      ],
    };
    j['equippedItems'] = <String, dynamic>{
      for (final e in (j['equippedItems'] as Map<String, dynamic>).entries)
        e.key: strip(Map<String, dynamic>.from(e.value as Map)),
    };
    j['forgeStack'] = [
      for (final i in j['forgeStack'] as List)
        strip(Map<String, dynamic>.from(i as Map)),
    ];
    return j;
  }

  test('구버전 파서는 모르는 옵션 키를 만나도 죽지 않고 그 옵션만 뺀다', () {
    final j = stored().toJson();
    // 1.0.17 이 모르는 키를 흉내 낸다(지금 앱 기준으로도 모르는 키).
    ((j['equippedItems'] as Map)['ring'] as Map)['o'] = [
      {'k': 'attack', 'v': 12.5},
      {'k': 'zzz_future', 'v': 3.1},
    ];
    final s = SaveGame.fromJson(j);
    expect(s.equippedItems[EquipSlot.ring]!.options, const [
      ItemOption(kind: ItemOptionKind.attack, value: 12.5),
    ]);
  });

  test('1.0.17 앱이 다시 올려도 같은 장비의 회피 옵션은 저장본에서 되돌아온다', () {
    final s = stored();
    final r = actions.mergeSave(s, oldAppReupload(s));
    expect(r.isOk, isTrue, reason: r.error);
    expect(r.save!.equippedItems[EquipSlot.ring].toString(), '$ringWithEvade');
    expect(r.save!.forgeStack.map((e) => '$e'), ['$ringWithEvade']);
  });

  test('1.0.17 기기에서 장비를 바꿨으면(나머지 옵션이 다르면) 새 장비를 둔다', () {
    final s = stored();
    final j = oldAppReupload(s);
    j['equippedItems'] = <String, dynamic>{
      'ring': <String, dynamic>{
        's': 'ring',
        't': 9,
        'o': [
          {'k': 'attack', 'v': 20.0},
          {'k': 'defense', 'v': 50.0},
        ],
      },
    };
    final r = actions.mergeSave(s, j);
    expect(r.save!.equippedItems[EquipSlot.ring]!.options, const [
      ItemOption(kind: ItemOptionKind.attack, value: 20.0),
      ItemOption(kind: ItemOptionKind.defense, value: 50.0),
    ]);
  });

  test('회피를 아는 앱(feat 20)이 회피를 지운 건 그대로 받는다(재굴림)', () {
    final s = stored();
    final j = oldAppReupload(s)..['feat'] = kSaveFeatureLevel;
    final r = actions.mergeSave(s, j);
    expect(r.save!.equippedItems[EquipSlot.ring]!.options, const [
      ItemOption(kind: ItemOptionKind.attack, value: 12.5),
    ]);
  });

  test('지금 앱은 회피 옵션을 그대로 왕복한다', () {
    final s = SaveGame.fromJson(stored().toJson());
    expect(s.equippedItems[EquipSlot.ring].toString(), '$ringWithEvade');
    expect(kSaveFeatureLevel, greaterThanOrEqualTo(20));
  });
}

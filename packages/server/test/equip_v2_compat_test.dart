import 'package:core_models/core_models.dart';
import 'package:core_save/core_save.dart';
import 'package:server/src/actions.dart';
import 'package:server/src/game_config.dart';
import 'package:test/test.dart';

/// 장비 v2(2026-10-10 · feat 21) 키 — 별 `st` · 환생 재료 `sx` · 옵션 정성 `p` — 와 구버전 앱(1.0.18 = feat 20).
///
/// 1.0.18 의 `EquipItem.tryFromJson` 은 s/t/o 만 읽어 새 키를 **버리고** 다시 올린다. 같은 장비면
/// 서버가 저장본의 값을 얹어 되돌린다(`GameActions._restoreEquipV2`).
final t0 = DateTime.utc(2026, 10, 10, 12);

void main() {
  late GameActions actions;

  setUpAll(() async {
    final cfg = await GameConfig.load(dir: '../app/assets/data');
    actions = GameActions(config: cfg, now: () => t0);
  });

  const ring = EquipItem(
    slot: EquipSlot.ring,
    tier: 9,
    stars: 3,
    starExp: 2,
    options: [
      ItemOption(kind: ItemOptionKind.attack, value: 12.5, polish: 4),
      ItemOption(kind: ItemOptionKind.critDamage, value: 40),
    ],
  );

  SaveGame stored() => SaveGame.initial(createdAt: t0).copyWith(
    lastSeen: t0.subtract(const Duration(seconds: 60)),
    equippedItems: {EquipSlot.ring: ring},
    forgeStack: const [ring],
  );

  /// 1.0.18 앱이 읽고(새 키를 버림) 다시 올리는 모양.
  Map<String, dynamic> oldAppReupload(SaveGame s, {double? attack}) {
    final j = s.toJson()..['feat'] = 20;
    Map<String, dynamic> strip(Map<String, dynamic> item) => {
      's': item['s'],
      't': item['t'],
      'o': [
        for (final o in item['o'] as List)
          {
            'k': (o as Map)['k'],
            'v': attack != null && o['k'] == 'attack' ? attack : o['v'],
          },
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

  test('1.0.18 앱이 다시 올려도 같은 장비의 별·환생 재료·정성은 저장본에서 되돌아온다', () {
    final s = stored();
    final r = actions.mergeSave(s, oldAppReupload(s));
    expect(r.isOk, isTrue, reason: r.error);
    final got = r.save!.equippedItems[EquipSlot.ring]!;
    expect(got.stars, 3);
    expect(got.starExp, 2);
    expect(got.options[0].polish, 4);
    expect(r.save!.forgeStack.single.stars, 3);
    expect(r.save!.forgeStack.single.options[0].polish, 4);
  });

  test('1.0.18 기기에서 장비가 바뀌었으면(옵션 값이 다르면) 올라온 장비를 그대로 둔다', () {
    final s = stored();
    final r = actions.mergeSave(s, oldAppReupload(s, attack: 3.3));
    final got = r.save!.equippedItems[EquipSlot.ring]!;
    expect(got.stars, 0);
    expect(got.options[0].value, 3.3);
  });

  test('새 앱(feat 21)이 별을 비웠으면 그 값을 받는다(되돌리지 않는다)', () {
    final s = stored();
    final j = s.toJson();
    (j['equippedItems'] as Map)['ring'] = const EquipItem(
      slot: EquipSlot.ring,
      tier: 9,
      options: [
        ItemOption(kind: ItemOptionKind.attack, value: 12.5),
        ItemOption(kind: ItemOptionKind.critDamage, value: 40),
      ],
    ).toJson();
    final r = actions.mergeSave(s, j);
    expect(r.save!.equippedItems[EquipSlot.ring]!.stars, 0);
  });
}

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

  test('1.0.18 앱이 다시 올려도 진행 중인 별 강화 끝 시각(su)이 되돌아온다', () {
    final until = t0.add(const Duration(hours: 3));
    final s = stored().copyWith(
      equippedItems: {
        EquipSlot.ring: ring.copyWith(starExp: 150, starUntil: until),
      },
    );
    final r = actions.mergeSave(s, oldAppReupload(s));
    expect(r.isOk, isTrue, reason: r.error);
    expect(r.save!.equippedItems[EquipSlot.ring]!.starUntil, until);
    // 서버 세이브 왕복(결투 뒤 채택 경로)에서도 남는다.
    final back = SaveGame.fromJson(r.save!.toJson());
    expect(back.equippedItems[EquipSlot.ring]!.starUntil, until);
  });

  test('공방 초월 단계는 1.0.18(feat 20)·장비 v2 개발 빌드(feat 21) 업로드에서 저장본 값으로 지킨다', () {
    final s = stored().copyWith(forgeTranscend: 2);
    final old = oldAppReupload(s)..remove('forgeTranscend');
    expect(actions.mergeSave(s, old).save!.forgeTranscend, 2);
    final dev = s.toJson()
      ..['feat'] = 21
      ..remove('forgeTranscend');
    expect(actions.mergeSave(s, dev).save!.forgeTranscend, 2);
  });

  test('초월 직후(feat 22) 장비·모루가 빈 업로드를 막거나 되돌리지 않는다', () {
    final s = stored().copyWith(
      forgeLevel: 19,
      materials: {MaterialKind.fossil: 20000},
    );
    final up = s.copyWith(
      forgeTranscend: 1,
      forgeLevel: 0,
      equippedItems: const {},
      forgeStack: const [],
      materials: {MaterialKind.fossil: 10000},
    );
    final r = actions.mergeSave(s, up.toJson());
    expect(r.isOk, isTrue, reason: r.error);
    expect(r.save!.forgeTranscend, 1);
    expect(r.save!.forgeLevel, 0);
    expect(r.save!.equippedItems, isEmpty);
    expect(r.save!.forgeStack, isEmpty);
  });

  test('훈련 보너스 폐지 — 넘친 기록은 첫 업로드에서 한 번만 자르고, 다음 업로드는 되돌리지 않는다', () {
    const bug = IndividualBug(
      id: 'b1',
      speciesId: 'stag_dorcus',
      sizeMm: 40,
      potential: 3, // 예산 18
      temperament: Temperament.aggressive,
      sex: Sex.male,
      element: Element.wood,
    );
    final s = stored().copyWith(
      bugs: const [bug],
      trainPoints: const {
        'b1': BugTrain(
          alloc: {TrainSlot.attack: 15, TrainSlot.defense: 10},
          paid: 25,
          bonus: 7,
        ),
      },
    );
    final r1 = actions.mergeSave(s, s.toJson());
    expect(r1.isOk, isTrue, reason: r1.error);
    expect(r1.extra['clampReasons'], contains('train'));
    final rec = r1.save!.trainPoints['b1']!;
    expect(rec.alloc.values.fold<int>(0, (a, b) => a + b), 18);
    expect(rec.freeRespec, isTrue);
    final r2 = actions.mergeSave(r1.save!, r1.save!.toJson());
    expect(r2.extra['clamped'], isFalse, reason: '${r2.extra}');
  });

  test(
    '프로필 그림(feat 23) — 1.0.18(feat 20)·장비 v2 개발 빌드(feat 22) 업로드는 저장본 그림을 지킨다',
    () {
      final s = stored().copyWith(avatar: 'avatar_05');
      final old = oldAppReupload(s)..remove('avatar');
      expect(actions.mergeSave(s, old).save!.avatar, 'avatar_05');
      final dev = s.toJson()
        ..['feat'] = 22
        ..remove('avatar');
      expect(actions.mergeSave(s, dev).save!.avatar, 'avatar_05');
      // 새 앱이 바꾸면 그 값을 받는다.
      final now = s.copyWith(avatar: 'avatar_12').toJson();
      expect(actions.mergeSave(s, now).save!.avatar, 'avatar_12');
    },
  );

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

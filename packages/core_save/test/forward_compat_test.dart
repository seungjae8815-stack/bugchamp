import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:core_save/core_save.dart';
import 'package:test/test.dart';

/// **앞 버전 호환**(forward compatibility) 계약.
///
/// 세이브는 서버를 거쳐 여러 버전의 앱을 오간다. 신버전이 재료·업그레이드·장비
/// 옵션을 하나만 추가해도, 그 세이브를 받은 **구버전 앱이 통째로 죽으면 안 된다**.
/// 2026-08-26 이전에는 `MaterialKind.fromKey` 가 `ArgumentError` 를 던져 그랬다.
///
/// 그리고 살아남는 것만으로는 부족하다 — 60초 주기 전체 업로드가 있으므로
/// **모르는 값을 그대로 되돌려주지 않으면 재화가 영구 소실된다**.
void main() {
  final t0 = DateTime.utc(2026, 8, 26, 12);

  /// 미래 버전이 만든 세이브를 흉내 낸다.
  Map<String, dynamic> futureSave() {
    final json = SaveGame.initial(createdAt: t0).toJson();
    (json['materials'] as Map<String, dynamic>)['chitin'] = 10;
    (json['materials'] as Map<String, dynamic>)['amber_v2'] = 777;
    (json['upgradeLevels'] as Map<String, dynamic>)['attack'] = 5;
    (json['upgradeLevels'] as Map<String, dynamic>)['telepathy_v2'] = 3;
    return json;
  }

  test('모르는 재료·업그레이드 키가 있어도 파싱이 죽지 않는다', () {
    final s = SaveGame.fromJson(futureSave());
    expect(s.materialCount(MaterialKind.chitin), 10);
    expect(s.upgradeLevel(UpgradeKind.attack), 5);
  });

  test('모르는 키의 수량이 왕복에서 보존된다 (구버전이 덮어써도 안 사라진다)', () {
    final out = SaveGame.fromJson(futureSave()).toJson();
    expect((out['materials'] as Map)['amber_v2'], 777);
    expect((out['materials'] as Map)['chitin'], 10);
    expect((out['upgradeLevels'] as Map)['telepathy_v2'], 3);
  });

  test('보존한 값이 게임 로직으로는 새지 않는다 (기본 세이브엔 비어 있다)', () {
    final s = SaveGame.initial(createdAt: t0);
    expect(s.unknownMaterials, isEmpty);
    expect(s.unknownUpgrades, isEmpty);
  });

  test('모르는 장비 부위·옵션은 그것만 빠지고 나머지는 살아남는다', () {
    final json = SaveGame.initial(createdAt: t0).toJson();
    json['equippedItems'] = {
      'ring': {
        's': 'ring',
        't': 3,
        'o': [
          {'k': 'attack', 'v': 12.0},
          {'k': 'timeWarp_v2', 'v': 99.0},
        ],
      },
      'halo_v2': {
        's': 'halo_v2',
        't': 9,
        'o': const [],
      },
    };
    json['autoForgeOptions'] = ['attack', 'timeWarp_v2'];

    final s = SaveGame.fromJson(json);
    final ring = s.equippedItems[EquipSlot.ring];
    expect(ring, isNotNull, reason: '아는 부위는 살아야 한다');
    expect(ring!.options.map((o) => o.kind), [ItemOptionKind.attack]);
    expect(s.equippedItems.keys.map((k) => k.key), ['ring']);
    expect(s.autoForgeOptions, {ItemOptionKind.attack});
  });

  test('모르는 기질·성별·오행 키를 가진 곤충도 읽힌다', () {
    final bug = IndividualBug.fromJson({
      'id': 'b1',
      'speciesId': 'stag',
      'sizeMm': 50.0,
      'potential': 3,
      'temperament': 'zealous_v2',
      'sex': 'neuter_v2',
      'element': 'aether_v2',
      'trait': 'radiant_v2',
      'stage': 'imago_v2',
    });
    // 오행은 미지정이면 id 기반 안정 배정으로 떨어진다(던지지 않는다).
    expect(Element.values, contains(bug.element));
    expect(bug.trait, BugTrait.none);
    expect(bug.stage, LifeStage.adult);
  });

  test('애셋 JSON 파서는 여전히 던진다 (오타를 로딩에서 잡아야 한다)', () {
    expect(() => MaterialKind.fromKey('amber_v2'), throwsArgumentError);
    expect(() => Grade.fromKey('mythic_v2'), throwsArgumentError);
    expect(MaterialKind.fromKeyOrNull('amber_v2'), isNull);
  });
}

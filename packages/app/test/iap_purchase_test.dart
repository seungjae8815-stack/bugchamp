import 'package:app/data/game_data.dart';
import 'package:app/data/save_repository.dart';
import 'package:app/domain/providers.dart';
import 'package:app/domain/save_controller.dart';
import 'package:app/domain/save_game.dart';
import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeRepo implements SaveRepository {
  _FakeRepo(this._game);
  SaveGame _game;
  @override
  Future<SaveGame> load() async => _game;
  @override
  Future<void> save(SaveGame g) async => _game = g;
  @override
  Future<void> clear() async =>
      _game = SaveGame.initial(createdAt: DateTime.utc(2026, 1, 1));
}

Map<String, dynamic> _name(String s) => {'ko': s, 'en': s, 'ja': s};

GameData _data() => GameData.fromDecoded(
  species: {
    'species': [
      {
        'id': 'a',
        'name': _name('A'),
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
      {'id': 'sap_trap', 'name': _name('S')},
    ],
  },
  fields: {
    'fields': [
      {'id': 'oak_forest', 'name': _name('O'), 'unlockOrder': 0},
    ],
  },
  spawns: {
    'schemaVersion': 1,
    'defaultPotentialWeights': [
      {'potential': 1, 'weight': 1},
    ],
    'spawns': <dynamic>[],
  },
  iapConfig: {
    'passDurationDays': 30,
    'passDailyJelly': 30,
    'removeAdsDailyJelly': 10,
    'passOfflineCapHours': 12,
    'passIdleGoldMult': 1.2,
    'products': <dynamic>[],
  },
);

void main() {
  final t0 = DateTime.utc(2026, 1, 1);

  ProviderContainer container() {
    final seed = SaveGame.initial(createdAt: t0).copyWith(lastSeen: t0);
    final c = ProviderContainer(
      overrides: [
        gameDataProvider.overrideWith((ref) => _data()),
        saveRepositoryProvider.overrideWithValue(_FakeRepo(seed)),
        clockProvider.overrideWithValue(FixedClock(t0)),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<SaveController> ctrl(ProviderContainer c) async {
    await c.read(saveControllerProvider.future);
    return c.read(saveControllerProvider.notifier);
  }

  test('젤리 팩: 재화만 지급(스탯 없음)', () async {
    final c = container();
    final s = await ctrl(c);
    final before = c.read(saveControllerProvider).requireValue;
    final ok = await s.applyPurchase(
      const IapProduct(
        id: 'jelly_m',
        kind: IapKind.consumable,
        type: IapType.jelly,
        priceKrw: 5500,
        grant: IapGrant(jelly: 330),
      ),
    );
    final after = c.read(saveControllerProvider).requireValue;
    expect(ok, isTrue);
    expect(
      after.materialCount(MaterialKind.jelly),
      before.materialCount(MaterialKind.jelly) + 330,
    );
    expect(after.adsRemoved, isFalse); // 다른 상태는 안 건드림
  });

  test('스타터 패키지: 재화+슬롯 지급, 두 번째 구매는 거부', () async {
    final c = container();
    final s = await ctrl(c);
    final cap0 = c.read(saveControllerProvider).requireValue.incubatorCapacity;
    const starter = IapProduct(
      id: 'starter_pack',
      kind: IapKind.nonConsumable,
      type: IapType.starter,
      priceKrw: 5500,
      grant: IapGrant(jelly: 300, gold: 200000, chitin: 500, incubatorSlots: 1),
    );

    expect(await s.applyPurchase(starter), isTrue);
    final after = c.read(saveControllerProvider).requireValue;
    expect(after.starterBought, isTrue);
    expect(after.gold, 200000);
    expect(after.materialCount(MaterialKind.jelly), 300);
    expect(after.materialCount(MaterialKind.chitin), 500);
    expect(after.incubatorCapacity, cap0 + 1);

    // 1회 한정 — 재구매 거부(중복 지급 방지).
    expect(await s.applyPurchase(starter), isFalse);
    expect(c.read(saveControllerProvider).requireValue.gold, 200000);
  });

  test('광고 제거: 영구 적용 → adsHidden true', () async {
    final c = container();
    final s = await ctrl(c);
    await s.applyPurchase(
      const IapProduct(
        id: 'remove_ads',
        kind: IapKind.nonConsumable,
        type: IapType.removeAds,
        priceKrw: 7700,
      ),
    );
    final after = c.read(saveControllerProvider).requireValue;
    expect(after.adsRemoved, isTrue);
    expect(after.adsHidden(t0), isTrue);
    expect(after.passActive(t0), isFalse); // 패스와는 별개
  });

  test('패스: 30일 부여 + 재구매 시 남은 기간에 이어서 연장', () async {
    final c = container();
    final s = await ctrl(c);
    const pass = IapProduct(
      id: 'idle_pass',
      kind: IapKind.timed,
      type: IapType.pass,
      priceKrw: 9900,
    );

    await s.applyPurchase(pass);
    final first = c.read(saveControllerProvider).requireValue;
    expect(first.passExpiresAt, t0.add(const Duration(days: 30)));
    expect(first.passActive(t0), isTrue);
    expect(first.adsHidden(t0), isTrue); // 패스도 광고 숨김

    // 아직 유효한 상태에서 재구매 → 만료일이 60일로 누적(손해 없음).
    await s.applyPurchase(pass);
    final second = c.read(saveControllerProvider).requireValue;
    expect(second.passExpiresAt, t0.add(const Duration(days: 60)));
  });

  test('일일 젤리: 패스 보유 시 로드마다 하루 1회만 지급', () async {
    // 패스 보유 상태로 시작 → 로드 시 30 지급, 같은 날 재로드는 추가 지급 없음.
    final seed = SaveGame.initial(
      createdAt: t0,
    ).copyWith(lastSeen: t0, passExpiresAt: t0.add(const Duration(days: 10)));
    final repo = _FakeRepo(seed);
    final c = ProviderContainer(
      overrides: [
        gameDataProvider.overrideWith((ref) => _data()),
        saveRepositoryProvider.overrideWithValue(repo),
        clockProvider.overrideWithValue(FixedClock(t0)),
      ],
    );
    addTearDown(c.dispose);

    final first = await c.read(saveControllerProvider.future);
    expect(first.materialCount(MaterialKind.jelly), 30);

    // 같은 날 다시 로드해도 중복 지급 없음.
    final c2 = ProviderContainer(
      overrides: [
        gameDataProvider.overrideWith((ref) => _data()),
        saveRepositoryProvider.overrideWithValue(repo),
        clockProvider.overrideWithValue(FixedClock(t0)),
      ],
    );
    addTearDown(c2.dispose);
    final second = await c2.read(saveControllerProvider.future);
    expect(second.materialCount(MaterialKind.jelly), 30);
  });

  test('일일 젤리: 광고제거만 있으면 10 (패스보다 적음)', () async {
    final seed = SaveGame.initial(
      createdAt: t0,
    ).copyWith(lastSeen: t0, adsRemoved: true);
    final c = ProviderContainer(
      overrides: [
        gameDataProvider.overrideWith((ref) => _data()),
        saveRepositoryProvider.overrideWithValue(_FakeRepo(seed)),
        clockProvider.overrideWithValue(FixedClock(t0)),
      ],
    );
    addTearDown(c.dispose);
    final s = await c.read(saveControllerProvider.future);
    expect(s.materialCount(MaterialKind.jelly), 10);
  });

  test('미구매는 일일 젤리 없음', () async {
    final c = container();
    final s = await c.read(saveControllerProvider.future);
    expect(s.materialCount(MaterialKind.jelly), 0);
  });

  test('스킨: 보유 목록에 추가(스탯 영향 없음)', () async {
    final c = container();
    final s = await ctrl(c);
    await s.applyPurchase(
      const IapProduct(
        id: 'skin_gold_rhino',
        kind: IapKind.nonConsumable,
        type: IapType.skin,
        priceKrw: 3300,
        skinId: 'gold_rhino',
      ),
    );
    final after = c.read(saveControllerProvider).requireValue;
    expect(after.ownedSkins, contains('gold_rhino'));
    expect(after.gold, 0); // 재화 변화 없음
  });
}

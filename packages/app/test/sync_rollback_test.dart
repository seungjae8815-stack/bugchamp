import 'package:app/data/game_data.dart';
import 'package:app/data/save_repository.dart';
import 'package:app/domain/game_server.dart';
import 'package:app/domain/providers.dart';
import 'package:app/domain/save_controller.dart';
import 'package:app/domain/server_sync.dart';
import 'package:core_models/core_models.dart';
import 'package:core_save/core_save.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 아직 세이브가 없는 **완전 신규 설치**를 흉내낸다.
class _FreshRepo implements SaveRepository {
  _FreshRepo([this._seed]);
  final SaveGame? _seed;
  @override
  SaveLoadFailure? get lastFailure => null;

  SaveGame? _game;
  @override
  Future<SaveGame> load() async {
    // 실제 저장소도 즉시 반환하지 않는다 — 로딩 구간을 만든다.
    await Future<void>.delayed(const Duration(milliseconds: 20));
    return _game ??=
        _seed ?? SaveGame.initial(createdAt: DateTime.utc(2026, 8, 8));
  }

  @override
  Future<void> save(SaveGame g) async => _game = g;
  @override
  Future<void> clear() async => _game = null;
}

/// 서버에 **오래된** 저장본이 있는 계정(마지막 업로드가 실패한 상황).
class _StaleServer implements GameServer {
  _StaleServer(this.remote);
  final SaveGame remote;
  bool adopted = false;

  @override
  bool get available => true;

  @override
  Future<ServerResult> fetchState() async {
    adopted = true;
    return ServerResult.ok({'save': remote.toJson()});
  }

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
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
);

void main() {
  final t0 = DateTime.utc(2026, 8, 31);

  /// ⚠️ **이 테스트가 지키는 것: 앱을 켤 때 진행이 사라지지 않는다.**
  ///
  /// 예전에는 서버 저장본이 있으면 **조건 없이** 채택했다. 마지막 업로드가
  /// 실패했거나(크래시·네트워크) 서버 것이 더 오래됐으면, 켤 때마다 그 사이
  /// 진행이 통째로 날아갔다 — "돈이 줄어든다 · 스테이지가 되돌아간다 ·
  /// 부화한 곤충이 없어진다"가 전부 이 한 경로였다(2026-08-30 유저 제보).
  test('로컬이 더 진행됐으면 서버의 옛 세이브를 채택하지 않는다', () async {
    final local = SaveGame.initial(createdAt: t0).copyWith(
      zoneEpoch: kZoneEpoch,
      stageNumber: 500,
      level: 40,
      gold: 1000000,
    );
    final stale = SaveGame.initial(
      createdAt: t0,
    ).copyWith(zoneEpoch: kZoneEpoch, stageNumber: 320, level: 31, gold: 5000);
    final server = _StaleServer(stale);
    final c = ProviderContainer(
      overrides: [
        gameDataProvider.overrideWith((ref) => _data()),
        saveRepositoryProvider.overrideWithValue(_FreshRepo(local)),
        gameServerProvider.overrideWithValue(server),
        clockProvider.overrideWithValue(FixedClock(t0)),
      ],
    );
    addTearDown(c.dispose);

    await syncSaveWith(
      server: server,
      ctrl: c.read(saveControllerProvider.notifier),
      localSave: () => c.read(saveControllerProvider.future),
    );

    final after = c.read(saveControllerProvider).requireValue;
    expect(after.stageNumber, 500, reason: '스테이지가 되돌아가면 안 된다');
    // 서버 횟수를 이어 센다(stale 은 0 이라 그냥 1 이상).
    expect(after.saveRev, greaterThan(stale.saveRev));
    expect(after.gold, greaterThanOrEqualTo(1000000), reason: '골드가 줄면 안 된다');
  });

  /// 반대 방향 — 다른 기기에서 더 진행했으면 그걸 따라야 한다.
  /// 되돌림만 막는 것이지 "서버가 진실"이라는 원칙을 버리는 게 아니다.
  test('서버가 더 진행됐으면 그대로 채택한다', () async {
    final local = SaveGame.initial(
      createdAt: t0,
    ).copyWith(zoneEpoch: kZoneEpoch, stageNumber: 100);
    final ahead = SaveGame.initial(
      createdAt: t0,
    ).copyWith(zoneEpoch: kZoneEpoch, stageNumber: 700, level: 55);
    final server = _StaleServer(ahead);
    final c = ProviderContainer(
      overrides: [
        gameDataProvider.overrideWith((ref) => _data()),
        saveRepositoryProvider.overrideWithValue(_FreshRepo(local)),
        gameServerProvider.overrideWithValue(server),
        clockProvider.overrideWithValue(FixedClock(t0)),
      ],
    );
    addTearDown(c.dispose);

    await syncSaveWith(
      server: server,
      ctrl: c.read(saveControllerProvider.notifier),
      localSave: () => c.read(saveControllerProvider.future),
    );
    expect(c.read(saveControllerProvider).requireValue.stageNumber, 700);
  });

  /// 회차 전환은 스테이지 1·레벨 1·업그레이드 0 으로 **일부러** 되돌리는
  /// 동작이라, 진행도 축으로만 재면 전환 직후 로컬이 "뒤처짐"으로 보인다.
  /// 전환 후 60초(업로드 주기) 안에 앱을 끄면 전환 전 서버 세이브가 채택돼
  /// **회차가 조용히 취소**된다 — 회차가 다르면 회차만으로 판정한다.
  test('회차를 전환한 로컬은 전환 전 서버 세이브에 덮이지 않는다', () async {
    final local = SaveGame.initial(createdAt: t0).copyWith(
      zoneEpoch: kZoneEpoch,
      difficultyTier: 1,
      stageNumber: 1,
      level: 1,
      upgradeLevels: const {},
    );
    final preTier = SaveGame.initial(
      createdAt: t0,
    ).copyWith(zoneEpoch: kZoneEpoch, stageNumber: 1000, level: 80);
    final server = _StaleServer(preTier);
    final c = ProviderContainer(
      overrides: [
        gameDataProvider.overrideWith((ref) => _data()),
        saveRepositoryProvider.overrideWithValue(_FreshRepo(local)),
        gameServerProvider.overrideWithValue(server),
        clockProvider.overrideWithValue(FixedClock(t0)),
      ],
    );
    addTearDown(c.dispose);

    await syncSaveWith(
      server: server,
      ctrl: c.read(saveControllerProvider.notifier),
      localSave: () => c.read(saveControllerProvider.future),
    );
    final after = c.read(saveControllerProvider).requireValue;
    expect(after.difficultyTier, 1, reason: '회차 전환이 취소되면 안 된다');
  });

  test('요정만 키운 로컬은 요정이 없는 서버 세이브에 덮이지 않는다(1.0.15)', () async {
    SaveGame base() =>
        SaveGame.initial(createdAt: t0).copyWith(zoneEpoch: kZoneEpoch);
    final local = base().copyWith(
      fairy: const FairyState(
        fairies: [
          Fairy(id: 'f1', kind: 'ignis', grade: FairyGrade.epic, sub: 'hp'),
        ],
        companionId: 'f1',
        dex: {'ignis:epic'},
        seq: 1,
      ),
    );
    final server = _StaleServer(base());
    final c = ProviderContainer(
      overrides: [
        gameDataProvider.overrideWith((ref) => _data()),
        saveRepositoryProvider.overrideWithValue(_FreshRepo(local)),
        gameServerProvider.overrideWithValue(server),
        clockProvider.overrideWithValue(FixedClock(t0)),
      ],
    );
    addTearDown(c.dispose);

    await syncSaveWith(
      server: server,
      ctrl: c.read(saveControllerProvider.notifier),
      localSave: () => c.read(saveControllerProvider.future),
    );
    final after = c.read(saveControllerProvider).requireValue;
    expect(after.fairy.companion?.id, 'f1', reason: '요정이 사라지면 안 된다');
  });

  /// 반대 방향 — 다른 기기가 회차를 전환했으면 이쪽 로컬(쉬움 1000)이
  /// 스테이지 숫자로는 앞서 보여도 서버를 따라야 한다.
  test('다른 기기가 회차를 전환했으면 그걸 따른다', () async {
    final local = SaveGame.initial(
      createdAt: t0,
    ).copyWith(zoneEpoch: kZoneEpoch, stageNumber: 1000, level: 80);
    final tiered = SaveGame.initial(createdAt: t0).copyWith(
      zoneEpoch: kZoneEpoch,
      difficultyTier: 1,
      stageNumber: 3,
      level: 2,
    );
    final server = _StaleServer(tiered);
    final c = ProviderContainer(
      overrides: [
        gameDataProvider.overrideWith((ref) => _data()),
        saveRepositoryProvider.overrideWithValue(_FreshRepo(local)),
        gameServerProvider.overrideWithValue(server),
        clockProvider.overrideWithValue(FixedClock(t0)),
      ],
    );
    addTearDown(c.dispose);

    await syncSaveWith(
      server: server,
      ctrl: c.read(saveControllerProvider.notifier),
      localSave: () => c.read(saveControllerProvider.future),
    );
    expect(c.read(saveControllerProvider).requireValue.difficultyTier, 1);
  });

  /// 가 본 난이도로 **내려가는** 것도 합법이다(2026-09-15). 지금 난이도로
  /// 비교하면 내려간 직후의 로컬이 "뒤처짐"이 되어 서버 옛 세이브(윗 난이도)에
  /// 덮인다 — 최고 난이도(`topTier`)로 비교해야 한다.
  test('아래 난이도로 내려간 로컬은 내려가기 전 서버 세이브에 덮이지 않는다', () async {
    final before = SaveGame.initial(createdAt: t0).copyWith(
      zoneEpoch: kZoneEpoch,
      difficultyTier: 2,
      maxTierReached: 2,
      stageNumber: 301,
      bestStage: 301,
      level: 30,
    );
    final local = before.copyWith(difficultyTier: 1, stageNumber: 1001);
    final server = _StaleServer(before);
    final c = ProviderContainer(
      overrides: [
        gameDataProvider.overrideWith((ref) => _data()),
        saveRepositoryProvider.overrideWithValue(_FreshRepo(local)),
        gameServerProvider.overrideWithValue(server),
        clockProvider.overrideWithValue(FixedClock(t0)),
      ],
    );
    addTearDown(c.dispose);

    await syncSaveWith(
      server: server,
      ctrl: c.read(saveControllerProvider.notifier),
      localSave: () => c.read(saveControllerProvider.future),
    );
    final after = c.read(saveControllerProvider).requireValue;
    expect(after.difficultyTier, 1, reason: '내려간 선택이 취소되면 안 된다');
    expect(after.maxTierReached, 2);
  });

  /// 반대로 — 다른 기기가 그 사이 최고 난이도에서 더 나아갔으면(최고 기록이
  /// 더 높음) 이 기기에서 난이도를 옮긴 것만으로 그 진행을 덮으면 안 된다.
  test('난이도를 옮겨도 다른 기기가 더 나아간 최고 기록은 덮지 않는다', () async {
    final base = SaveGame.initial(createdAt: t0).copyWith(
      zoneEpoch: kZoneEpoch,
      difficultyTier: 2,
      maxTierReached: 2,
      level: 30,
    );
    // 이 기기: 사냥터 3 까지만 간 상태에서 보통으로 내려갔다.
    final local = base.copyWith(
      difficultyTier: 1,
      stageNumber: 1001,
      bestStage: 201,
    );
    // 다른 기기: 어려움 사냥터 6 까지 나아갔다.
    final other = base.copyWith(stageNumber: 501, bestStage: 501);
    final server = _StaleServer(other);
    final c = ProviderContainer(
      overrides: [
        gameDataProvider.overrideWith((ref) => _data()),
        saveRepositoryProvider.overrideWithValue(_FreshRepo(local)),
        gameServerProvider.overrideWithValue(server),
        clockProvider.overrideWithValue(FixedClock(t0)),
      ],
    );
    addTearDown(c.dispose);

    await syncSaveWith(
      server: server,
      ctrl: c.read(saveControllerProvider.notifier),
      localSave: () => c.read(saveControllerProvider.future),
    );
    final after = c.read(saveControllerProvider).requireValue;
    expect(after.bestStage, 501, reason: '다른 기기의 진행이 사라지면 안 된다');
  });

  /// 진행도가 **같으면** 저장 횟수가 많은 쪽이 나중 것이다(2026-10-05 제보: "훈련을 눌러도
  /// 나갔다 오면 취소돼 있다"). 훈련 시작처럼 진행도를 안 바꾸는 변경이 업로드 전에 앱이 꺼지면,
  /// 동점이라 서버의 옛 세이브가 채택돼 그 변경이 사라졌다. 표식으로 골드를 쓴다(진행도 축이 아니다).
  Future<SaveGame> syncTie({
    required int localRev,
    required int remoteRev,
  }) async {
    final base = SaveGame.initial(
      createdAt: t0,
    ).copyWith(zoneEpoch: kZoneEpoch, stageNumber: 201, level: 20);
    final local = base.copyWith(gold: 777, saveRev: localRev);
    final remote = base.copyWith(gold: 5, saveRev: remoteRev);
    final server = _StaleServer(remote);
    final c = ProviderContainer(
      overrides: [
        gameDataProvider.overrideWith((ref) => _data()),
        saveRepositoryProvider.overrideWithValue(_FreshRepo(local)),
        gameServerProvider.overrideWithValue(server),
        clockProvider.overrideWithValue(FixedClock(t0)),
      ],
    );
    addTearDown(c.dispose);
    await syncSaveWith(
      server: server,
      ctrl: c.read(saveControllerProvider.notifier),
      localSave: () => c.read(saveControllerProvider.future),
    );
    return c.read(saveControllerProvider).requireValue;
  }

  test('진행도가 같으면 저장 횟수가 많은 기기 세이브를 지킨다', () async {
    final after = await syncTie(localRev: 10, remoteRev: 3);
    expect(after.gold, 777, reason: '업로드 전에 꺼진 변경이 서버 옛 세이브에 덮이면 안 된다');
  });

  test('진행도가 같아도 서버의 저장 횟수가 많으면 서버를 따른다', () async {
    final after = await syncTie(localRev: 3, remoteRev: 50);
    expect(after.gold, 5);
    // 채택한 뒤에도 횟수를 이어 센다 — 줄면 다음 동점 판정이 거꾸로 간다.
    expect(after.saveRev, greaterThan(50));
  });

  test('채택할 때 기기의 저장 횟수가 더 크면 그 값을 이어 센다', () async {
    final local = SaveGame.initial(
      createdAt: t0,
    ).copyWith(zoneEpoch: kZoneEpoch, stageNumber: 100, saveRev: 90);
    // 서버가 더 진행됐다(다른 기기) — 채택은 하되 횟수는 줄지 않는다.
    final ahead = SaveGame.initial(
      createdAt: t0,
    ).copyWith(zoneEpoch: kZoneEpoch, stageNumber: 700, saveRev: 4);
    final server = _StaleServer(ahead);
    final c = ProviderContainer(
      overrides: [
        gameDataProvider.overrideWith((ref) => _data()),
        saveRepositoryProvider.overrideWithValue(_FreshRepo(local)),
        gameServerProvider.overrideWithValue(server),
        clockProvider.overrideWithValue(FixedClock(t0)),
      ],
    );
    addTearDown(c.dispose);
    await syncSaveWith(
      server: server,
      ctrl: c.read(saveControllerProvider.notifier),
      localSave: () => c.read(saveControllerProvider.future),
    );
    final after = c.read(saveControllerProvider).requireValue;
    expect(after.stageNumber, 700);
    expect(after.saveRev, greaterThan(90));
  });

  /// 진행도로 앞서 서버를 채택하지 않을 때도 횟수는 서버 것까지 이어 센다 — 안 그러면 이 기기 내용이
  /// 다른 기기가 남긴 큰 횟수로 저장돼, 다음 동점에서 이 기기의 새 변경(훈련 시작 등)이 진다.
  test('로컬이 앞서 채택을 건너뛰어도 서버 횟수를 이어 센다', () async {
    final local = SaveGame.initial(
      createdAt: t0,
    ).copyWith(zoneEpoch: kZoneEpoch, stageNumber: 500, saveRev: 21);
    final remote = SaveGame.initial(
      createdAt: t0,
    ).copyWith(zoneEpoch: kZoneEpoch, stageNumber: 300, saveRev: 100);
    final server = _StaleServer(remote);
    final c = ProviderContainer(
      overrides: [
        gameDataProvider.overrideWith((ref) => _data()),
        saveRepositoryProvider.overrideWithValue(_FreshRepo(local)),
        gameServerProvider.overrideWithValue(server),
        clockProvider.overrideWithValue(FixedClock(t0)),
      ],
    );
    addTearDown(c.dispose);
    await syncSaveWith(
      server: server,
      ctrl: c.read(saveControllerProvider.notifier),
      localSave: () => c.read(saveControllerProvider.future),
    );
    final after = c.read(saveControllerProvider).requireValue;
    expect(after.stageNumber, 500);
    expect(after.saveRev, greaterThan(100));
  });
}

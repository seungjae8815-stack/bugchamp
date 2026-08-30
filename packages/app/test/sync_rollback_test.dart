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
    final local = SaveGame.initial(
      createdAt: t0,
    ).copyWith(stageNumber: 500, level: 40, gold: 1000000);
    final stale = SaveGame.initial(
      createdAt: t0,
    ).copyWith(stageNumber: 320, level: 31, gold: 5000);
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
    expect(after.gold, greaterThanOrEqualTo(1000000), reason: '골드가 줄면 안 된다');
  });

  /// 반대 방향 — 다른 기기에서 더 진행했으면 그걸 따라야 한다.
  /// 되돌림만 막는 것이지 "서버가 진실"이라는 원칙을 버리는 게 아니다.
  test('서버가 더 진행됐으면 그대로 채택한다', () async {
    final local = SaveGame.initial(createdAt: t0).copyWith(stageNumber: 100);
    final ahead = SaveGame.initial(
      createdAt: t0,
    ).copyWith(stageNumber: 700, level: 55);
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
}

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
  @override
  SaveLoadFailure? get lastFailure => null;

  SaveGame? _game;
  @override
  Future<SaveGame> load() async {
    // 실제 저장소도 즉시 반환하지 않는다 — 로딩 구간을 만든다.
    await Future<void>.delayed(const Duration(milliseconds: 20));
    return _game ??= SaveGame.initial(createdAt: DateTime.utc(2026, 8, 8));
  }

  @override
  Future<void> save(SaveGame g) async => _game = g;
  @override
  Future<void> clear() async => _game = null;
}

/// 서버에 저장본이 **없는** 신규 계정.
class _EmptyServer implements GameServer {
  Map<String, dynamic>? bootstrapped;

  @override
  bool get available => true;

  @override
  Future<ServerResult> fetchState() async =>
      const ServerResult.ok({'save': null});

  @override
  Future<ServerResult> bootstrap(Map<String, dynamic> save) async {
    bootstrapped = save;
    return ServerResult.ok({'save': save});
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
  test('첫 실행(세이브 로딩 중)에도 서버 동기화가 멈추지 않는다', () async {
    // 회귀: `requireValue` 를 쓰던 시절엔 여기서
    // AsyncValueIsLoadingException 이 나고 타이틀이 "불러오는 중"에서 멈췄다.
    // 기존 유저는 세이브가 이미 있어 이 경로를 안 밟아 못 잡던 버그다.
    final server = _EmptyServer();
    final c = ProviderContainer(
      overrides: [
        gameDataProvider.overrideWith((ref) => _data()),
        saveRepositoryProvider.overrideWithValue(_FreshRepo()),
        gameServerProvider.overrideWithValue(server),
        clockProvider.overrideWithValue(FixedClock(DateTime.utc(2026, 8, 8))),
      ],
    );
    addTearDown(c.dispose);

    // 세이브를 **미리 읽지 않고**(= 로딩 중인 상태로) 동기화를 부른다.
    await expectLater(
      syncSaveWith(
        server: server,
        ctrl: c.read(saveControllerProvider.notifier),
        localSave: () => c.read(saveControllerProvider.future),
      ),
      completes,
    );
    expect(server.bootstrapped, isNotNull, reason: '로컬 세이브가 서버로 이관돼야 한다');
  });
}

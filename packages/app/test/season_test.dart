import 'package:app/data/game_data.dart';
import 'package:app/data/save_repository.dart';
import 'package:app/domain/providers.dart';
import 'package:app/domain/save_controller.dart';
import 'package:core_save/core_save.dart';
import 'package:core_models/core_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeRepo implements SaveRepository {
  @override
  SaveLoadFailure? get lastFailure => null;

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

/// battleConfig: {} → 기본(season days14/reset0.5/mult3, 리그 브론즈~다이아).
/// runConfig 없음 → 오프라인 정산이 시즌 판정에 끼어들지 않음.
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
  battleConfig: const {},
);

void main() {
  final t0 = DateTime.utc(2026, 2, 1);

  ProviderContainer container(SaveGame seed) {
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

  // 시즌 경계는 **요일·시각 앵커**(KST 월요일 09:00 = UTC 월요일 00:00)다.
  // t0 = 2026-02-01(일) → 이번 시즌 시작은 1/26(월) 00:00 UTC.
  final curSeasonStart = DateTime.utc(2026, 1, 26);

  test('시즌 만료: 종료 시 등급 보상 + 트로피 소프트리셋', () async {
    // 지난 시즌에 멈춰 있던 세이브 → 경계를 넘겼으므로 정산된다.
    // 종료 시 800(platinum) → 보상 120000골드·60젤리, 리셋 400.
    final seed = SaveGame.initial(createdAt: DateTime.utc(2026, 1, 1)).copyWith(
      lastSeen: t0,
      pvpTrophies: 800,
      seasonPeakTrophies: 800,
      seasonStartedAt: DateTime.utc(2026, 1, 19), // 지난 주 시즌
    );
    final c = container(seed);
    await c.read(saveControllerProvider.future);

    final s = c.read(saveControllerProvider).requireValue;
    expect(s.pvpTrophies, 400); // 800 × 0.5
    expect(s.gold, 120000); // platinum 40000 × 3
    expect(s.materialCount(MaterialKind.jelly), 60); // 20 × 3
    expect(s.seasonPeakTrophies, 400);
    // 새 시즌은 '지금'이 아니라 **이번 주 경계**에서 시작한다 — 유저마다
    // 시작 시각이 달라지면 같은 시즌을 겨루는 게 아니게 된다.
    expect(s.seasonStartedAt, curSeasonStart);

    final report = c.read(saveControllerProvider.notifier).pendingSeason;
    expect(report, isNotNull);
    expect(report!.endTrophies, 800);
    expect(report.fromTrophies, 800);
    expect(report.toTrophies, 400);
  });

  test('시즌 보상은 최고 기록이 아니라 **종료 시 등급**으로 준다', () async {
    // 주중에 플래티넘(800)까지 갔다가 실버(150)로 떨어진 채 시즌이 끝난 경우.
    //
    // 예전에는 최고 기록으로 줬다(플래티넘 보상). 지금은 끝나는 순간의 등급이다
    // — 화면에 뜨는 "지금 등급"과 실제 보상이 달라 설명할 수가 없었다.
    final seed = SaveGame.initial(createdAt: DateTime.utc(2026, 1, 1)).copyWith(
      lastSeen: t0,
      pvpTrophies: 150, // 실버
      seasonPeakTrophies: 800, // 한때 플래티넘
      seasonStartedAt: DateTime.utc(2026, 1, 19),
    );
    final c = container(seed);
    await c.read(saveControllerProvider.future);

    final s = c.read(saveControllerProvider).requireValue;
    expect(s.gold, 15000); // silver 5000 × 3 (platinum 120000 이 아니다)
    // 테스트는 코드 기본값(`_defaultLeagues`)을 쓴다 — 실버 젤리 5.
    // 실제 수치는 battle.json 이 정한다(§6).
    expect(s.materialCount(MaterialKind.jelly), 15); // silver 5 × 3
    expect(s.pvpTrophies, 75); // 150 × 0.5

    final report = c.read(saveControllerProvider.notifier).pendingSeason;
    expect(report!.endTrophies, 150);
  });

  test('시즌 미만료: 변화 없음', () async {
    final seed = SaveGame.initial(createdAt: DateTime.utc(2026, 1, 1)).copyWith(
      lastSeen: t0,
      pvpTrophies: 800,
      seasonPeakTrophies: 800,
      seasonStartedAt: curSeasonStart, // 이번 시즌 → 미만료
    );
    final c = container(seed);
    await c.read(saveControllerProvider.future);

    final s = c.read(saveControllerProvider).requireValue;
    expect(s.pvpTrophies, 800); // 유지
    expect(c.read(saveControllerProvider.notifier).pendingSeason, isNull);
  });

  test('여러 주를 비워도 정산은 한 번만', () async {
    // 3주 전 시즌에서 멈춘 세이브 — 주마다 보상을 소급해 주지 않는다.
    final seed = SaveGame.initial(createdAt: DateTime.utc(2026, 1, 1)).copyWith(
      lastSeen: t0,
      pvpTrophies: 800,
      seasonPeakTrophies: 800,
      seasonStartedAt: DateTime.utc(2026, 1, 5),
    );
    final c = container(seed);
    await c.read(saveControllerProvider.future);

    final s = c.read(saveControllerProvider).requireValue;
    expect(s.gold, 120000); // 3주치가 아니라 1회분
    expect(s.pvpTrophies, 400);
    expect(s.seasonStartedAt, curSeasonStart);
  });

  test('시즌 시작이 없던 세이브는 이번 주 경계로 맞춰지고 보상은 없다', () async {
    // `seasonStartedAt` 이 아예 없던 옛 세이브. copyWith 로는 null 을 못 넣어
    // JSON 에서 필드를 빼서 만든다(실제 마이그레이션 상황과 같다).
    final json =
        SaveGame.initial(createdAt: DateTime.utc(2026, 1, 1))
            .copyWith(lastSeen: t0, pvpTrophies: 800, seasonPeakTrophies: 800)
            .toJson()
          ..remove('seasonStartedAt');
    final seed = SaveGame.fromJson(json);
    final c = container(seed);
    await c.read(saveControllerProvider.future);

    final s = c.read(saveControllerProvider).requireValue;
    expect(s.seasonStartedAt, curSeasonStart);
    expect(s.pvpTrophies, 800); // 리셋되지 않는다
    expect(c.read(saveControllerProvider.notifier).pendingSeason, isNull);
  });

  test('서버 세이브를 채택해도 정산되지 않은 시즌은 다시 정산한다', () async {
    // 시작할 때 서버 세이브를 통째로 채택하는데, 서버는 다음 업로드에서야
    // 시즌을 확정한다. 채택 뒤 다시 돌리지 않으면 방금 깎은 트로피가
    // 되돌아가고 "시즌 종료" 팝업이 두 번 뜬다.
    final seed = SaveGame.initial(
      createdAt: DateTime.utc(2026, 1, 1),
    ).copyWith(lastSeen: t0, seasonStartedAt: curSeasonStart);
    final c = container(seed);
    await c.read(saveControllerProvider.future);
    final ctrl = c.read(saveControllerProvider.notifier);
    ctrl.consumeSeason();

    // 서버가 아직 정산하지 않은(지난 시즌 그대로인) 세이브를 내려준다.
    final stale = seed
        .copyWith(
          pvpTrophies: 800,
          seasonPeakTrophies: 800,
          seasonStartedAt: DateTime.utc(2026, 1, 19),
        )
        .toJson();
    await ctrl.adoptServerSave(stale);

    final s = c.read(saveControllerProvider).requireValue;
    expect(s.pvpTrophies, 400); // 채택 직후 바로 소프트리셋
    expect(s.seasonStartedAt, curSeasonStart);
    expect(ctrl.pendingSeason, isNotNull);
  });
}

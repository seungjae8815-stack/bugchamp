import 'package:app/data/game_data.dart';
import 'package:app/data/save_repository.dart';
import 'package:app/domain/providers.dart';
import 'package:app/domain/save_controller.dart';
import 'package:core_run/core_run.dart';
import 'package:core_models/core_models.dart';
import 'package:core_save/core_save.dart';
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

/// 앱이 실제로 읽는 것과 같은 모양의 battle.json 조각(§6 — 수치는 JSON에서).
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
  battleConfig: {
    'tickets': {
      'max': 10,
      'regenSeconds': 1800,
      'adGrant': 3,
      'adDailyLimit': 30,
      'refillJelly': 10,
    },
  },
);

void main() {
  final t0 = DateTime.utc(2026, 8, 6, 12);

  ProviderContainer container(SaveGame seed, {DateTime? now}) {
    final c = ProviderContainer(
      overrides: [
        gameDataProvider.overrideWith((ref) => _data()),
        saveRepositoryProvider.overrideWithValue(_FakeRepo(seed)),
        clockProvider.overrideWithValue(FixedClock(now ?? t0)),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  SaveGame seeded({int tickets = 10, int jelly = 0, DateTime? at}) =>
      SaveGame.initial(createdAt: t0).copyWith(
        lastSeen: t0,
        pvpTickets: tickets,
        ticketsAt: at ?? t0,
        materials: {MaterialKind.jelly: jelly},
      );

  test('결투 1판 = 티켓 1장, 없으면 시작할 수 없다', () async {
    final c = container(seeded(tickets: 1));
    await c.read(saveControllerProvider.future);
    final ctrl = c.read(saveControllerProvider.notifier);

    expect(await ctrl.consumePvpTicket(), isTrue);
    expect(ctrl.ticketsNow, 0);
    // 0장에서는 거부 — 이게 하루 판수를 묶는 지점이다.
    expect(await ctrl.consumePvpTicket(), isFalse);
    expect(ctrl.ticketsNow, 0);
  });

  test('30분당 1장씩 자연 충전되고 상한에서 멈춘다', () async {
    // 2시간 전이 기준시각 → 4장 충전
    final c = container(
      seeded(tickets: 2, at: t0.subtract(const Duration(hours: 2))),
    );
    await c.read(saveControllerProvider.future);
    expect(c.read(saveControllerProvider.notifier).ticketsNow, 6);

    final full = container(
      seeded(tickets: 9, at: t0.subtract(const Duration(days: 1))),
    );
    await full.read(saveControllerProvider.future);
    expect(full.read(saveControllerProvider.notifier).ticketsNow, 10);
  });

  test('전투 시작 실패 시 낙관 차감분을 되돌린다', () async {
    final c = container(seeded(tickets: 5));
    await c.read(saveControllerProvider.future);
    final ctrl = c.read(saveControllerProvider.notifier);
    await ctrl.consumePvpTicket();
    expect(ctrl.ticketsNow, 4);
    await ctrl.restorePvpTicket();
    expect(ctrl.ticketsNow, 5);
  });

  test('광고 보상 +3장, 하루 상한까지만(광고제거 구매자도 동일)', () async {
    final c = container(seeded(tickets: 2));
    await c.read(saveControllerProvider.future);
    final ctrl = c.read(saveControllerProvider.notifier);

    expect(await ctrl.grantAdTickets(), TicketCharge.ok);
    expect(ctrl.ticketsNow, 5);

    // 상한(30회)을 채운 상태 — 광고제거를 샀어도 더 받을 수 없다.
    final maxed = container(
      seeded(tickets: 2).copyWith(
        adUseCounts: {kAdFeaturePvpTicket: 30},
        adUseDate: dailyDateKey(t0),
        adsRemoved: true,
      ),
    );
    await maxed.read(saveControllerProvider.future);
    expect(
      await maxed.read(saveControllerProvider.notifier).grantAdTickets(),
      TicketCharge.adLimit,
    );
  });

  test('광고 보상은 상한을 넘겨 쌓일 수 있다(9장에서 봐도 낭비 없음)', () async {
    final c = container(seeded(tickets: 9));
    await c.read(saveControllerProvider.future);
    final ctrl = c.read(saveControllerProvider.notifier);
    expect(await ctrl.grantAdTickets(), TicketCharge.ok);
    expect(ctrl.ticketsNow, 12);
  });

  test('젤리 충전: 값을 치르고 만땅, 부족하면 아무것도 소비하지 않는다', () async {
    final rich = container(seeded(tickets: 3, jelly: 25));
    await rich.read(saveControllerProvider.future);
    final ctrl = rich.read(saveControllerProvider.notifier);
    expect(await ctrl.refillTicketsWithJelly(), TicketCharge.ok);
    expect(ctrl.ticketsNow, 10);
    expect(
      rich
          .read(saveControllerProvider)
          .requireValue
          .materialCount(MaterialKind.jelly),
      15,
    );
    // 이미 가득이면 젤리를 받지 않는다.
    expect(await ctrl.refillTicketsWithJelly(), TicketCharge.alreadyFull);

    final poor = container(seeded(tickets: 3, jelly: 1));
    await poor.read(saveControllerProvider.future);
    expect(
      await poor.read(saveControllerProvider.notifier).refillTicketsWithJelly(),
      TicketCharge.notEnoughJelly,
    );
    expect(
      poor
          .read(saveControllerProvider)
          .requireValue
          .materialCount(MaterialKind.jelly),
      1,
    );
  });

  test('서버가 준 티켓 상태를 로컬이 그대로 채택한다(서버가 진실)', () async {
    final c = container(seeded(tickets: 9));
    await c.read(saveControllerProvider.future);
    final ctrl = c.read(saveControllerProvider.notifier);
    await ctrl.adoptTicketState({
      'tickets': 2,
      'ticketsAt': t0.toIso8601String(),
      'adUsed': 7,
    });
    expect(ctrl.ticketsNow, 2);
    final s = c.read(saveControllerProvider).requireValue;
    expect(s.adUseCount(kAdFeaturePvpTicket, dailyDateKey(t0)), 7);
  });
}

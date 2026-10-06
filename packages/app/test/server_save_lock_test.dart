import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:app/data/game_data.dart';
import 'package:app/data/save_repository.dart';
import 'package:app/domain/game_server.dart';
import 'package:app/domain/notice_service.dart';
import 'package:app/domain/providers.dart';
import 'package:app/domain/save_controller.dart';
import 'package:app/domain/server_sync.dart';
import 'package:app/domain/store_iap_service.dart';
import 'package:core_models/core_models.dart';
import 'package:core_save/core_save.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

class _Repo implements SaveRepository {
  _Repo(this._g);
  SaveGame _g;
  @override
  SaveLoadFailure? get lastFailure => null;
  @override
  Future<SaveGame> load() async => _g;
  @override
  Future<void> save(SaveGame g) async => _g = g;
  @override
  Future<void> clear() async =>
      _g = SaveGame.initial(createdAt: DateTime.utc(2026));
}

Map<String, dynamic> _read(String f) =>
    jsonDecode(File('assets/data/$f').readAsStringSync())
        as Map<String, dynamic>;

GameData _data() => GameData.fromDecoded(
  species: _read('species.json'),
  traps: _read('traps.json'),
  fields: _read('fields.json'),
  spawns: _read('spawns.json'),
  runConfig: _read('run_config.json'),
  petConfig: _read('pets.json'),
);

final _t0 = DateTime.utc(2026, 10, 5, 12, 8);

/// 운영 서버를 흉내낸다 — 업로드는 **골드 감소도 소비로 받아들이고**(실제 서버가 그렇다),
/// 우편 받기는 저장본에 골드를 더해 돌려주고, 결제는 저장본을 그대로 돌려준다.
/// 응답마다 짧게 기다려 흐름이 서로 끼어들 틈을 만든다(실제 왕복처럼).
class _RaceServer extends NoGameServer {
  _RaceServer(SaveGame initial) : stored = initial.toJson();

  Map<String, dynamic> stored;

  /// 업로드가 실어 온 골드(도착 순서대로).
  final uploadedGold = <int>[];

  /// 들어온 요청 순서(경쟁이 직렬화됐는지 본다).
  final log = <String>[];

  @override
  bool get available => true;

  Future<void> _rtt() => Future<void>.delayed(const Duration(milliseconds: 5));

  int _gold(Map<String, dynamic> j) => SaveGame.fromJson(j).gold.toInt();

  @override
  Future<ServerResult> uploadSave(Map<String, dynamic> save) async {
    log.add('save');
    await _rtt();
    uploadedGold.add(_gold(save));
    stored = save;
    return const ServerResult.ok({});
  }

  @override
  Future<ServerResult> claimMail(String id) async {
    log.add('claim');
    await _rtt();
    final s = SaveGame.fromJson(stored);
    stored = s.copyWith(gold: s.gold + 1000).toJson();
    return ServerResult.ok({'save': stored});
  }

  @override
  Future<ServerResult> purchase({
    required String productId,
    required String purchaseToken,
  }) async {
    log.add('purchase');
    await _rtt();
    return ServerResult.ok({'save': stored});
  }
}

/// `StoreIapService._grantViaServer` 와 같은 흐름 — 올리기 → `/purchase` → 채택을 잠금 안에서.
Future<void> _grantLike(GameServer server, SaveController ctrl) =>
    withServerSaveLock(() async {
      await flushSaveBeforeServerAction(server, () => ctrl.latestSave);
      final res = await server.purchase(productId: 'pass', purchaseToken: 't');
      if (res.isOk && res.save != null) await ctrl.adoptServerSave(res.save!);
    });

void main() {
  group('서버 세이브 잠금(2026-10-05 우편 되돌림 사고)', () {
    test('복원 두 건 사이에 우편을 받아도 받은 골드가 되돌아가지 않는다', () async {
      final seed = SaveGame.initial(createdAt: _t0).copyWith(gold: 500);
      final server = _RaceServer(seed);
      final c = ProviderContainer(
        overrides: [
          gameDataProvider.overrideWith((ref) => _data()),
          saveRepositoryProvider.overrideWithValue(_Repo(seed)),
          clockProvider.overrideWithValue(FixedClock(_t0)),
          gameServerProvider.overrideWithValue(server),
        ],
      );
      addTearDown(c.dispose);
      await c.read(saveControllerProvider.future);
      final ctrl = c.read(saveControllerProvider.notifier);

      // 운영 로그의 순서 그대로 한꺼번에 시작한다: 복원 1 → 우편 받기 → 복원 2.
      // 예전 코드는 복원 2 가 **시작할 때** 세이브를 읽어 두었다가 우편 채택 뒤에 올렸다.
      final first = _grantLike(server, ctrl);
      final claim = c.read(rewardClaimerProvider).claimMail('7');
      final second = _grantLike(server, ctrl);
      await Future.wait([first, claim.then((_) {}), second]);

      expect(await claim, RedeemResult.ok);
      // 흐름이 섞이지 않고 한 줄로 돌았다.
      expect(server.log, [
        'save',
        'purchase',
        'save',
        'claim',
        'save',
        'purchase',
      ]);
      // 복원 2 의 업로드는 우편 채택 **뒤의** 세이브(골드 +1000)를 실었다.
      expect(server.uploadedGold.last, 1500);
      expect(SaveGame.fromJson(server.stored).gold.toInt(), 1500);
      expect(c.read(saveControllerProvider).requireValue.gold.toInt(), 1500);
    });

    test('잠금 안에서 다시 잡아도 교착하지 않는다(재진입)', () async {
      final order = <int>[];
      await withServerSaveLock(() async {
        order.add(1);
        await withServerSaveLock(() async => order.add(2));
        order.add(3);
      }).timeout(const Duration(seconds: 2));
      expect(order, [1, 2, 3]);
    });

    test('잠금 안에서 예약한 작업은 풀린 뒤 깨어나면 줄을 다시 선다', () async {
      final order = <String>[];
      final later = Completer<void>();
      await withServerSaveLock(() async {
        // 업로드 재시도 타이머처럼 — 잠금 안에서 만들어 Zone 을 물려받는다.
        Timer(const Duration(milliseconds: 10), () {
          later.complete(withServerSaveLock(() async => order.add('retry')));
        });
      });
      // 다른 흐름이 잠금을 쥐고 있는 동안 재시도가 깨어난다 — 끼어들면 안 된다.
      final holder = withServerSaveLock(() async {
        order.add('holder-start');
        await Future<void>.delayed(const Duration(milliseconds: 30));
        order.add('holder-end');
      });
      await holder;
      await later.future;
      expect(order, ['holder-start', 'holder-end', 'retry']);
    });

    test('본문이 실패해도 잠금은 풀린다', () async {
      await expectLater(
        withServerSaveLock<void>(() async => throw StateError('x')),
        throwsStateError,
      );
      expect(
        await withServerSaveLock(
          () async => 1,
        ).timeout(const Duration(seconds: 2)),
        1,
      );
    });
  });

  group('결제 복원 — 이미 지급된 구매는 서버에 다시 묻지 않는다', () {
    final base = SaveGame.initial(createdAt: _t0);

    test('지급 기록에 토큰이 있으면 이미 지급됨', () {
      final s = base.copyWith(redeemedPurchases: {'tok-1'});
      expect(purchaseAlreadyGranted(s, 'tok-1'), isTrue);
      expect(purchaseAlreadyGranted(s, 'tok-2'), isFalse);
    });

    test('빈 토큰·세이브 없음은 판단하지 않는다(서버에 묻는다)', () {
      final s = base.copyWith(redeemedPurchases: {''});
      expect(purchaseAlreadyGranted(s, ''), isFalse);
      expect(purchaseAlreadyGranted(null, 'tok-1'), isFalse);
    });

    test('iOS 복원의 already_owned 만 완료로 닫는다(안드로이드는 환불 경로 유지)', () {
      expect(
        isIosRestoreOfOwned(
          platform: TargetPlatform.iOS,
          error: 'already_owned',
        ),
        isTrue,
      );
      expect(
        isIosRestoreOfOwned(
          platform: TargetPlatform.android,
          error: 'already_owned',
        ),
        isFalse,
      );
      expect(
        isIosRestoreOfOwned(
          platform: TargetPlatform.iOS,
          error: 'store_unavailable',
        ),
        isFalse,
      );
    });
  });
}

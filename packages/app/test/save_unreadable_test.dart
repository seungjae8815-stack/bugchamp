import 'dart:convert';
import 'dart:io';

import 'package:app/data/save_repository.dart';
import 'package:core_save/core_save.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

/// **읽지 못한 세이브를 조용히 덮지 않는다**는 계약.
///
/// 2026-08-26 이전에는 로드 실패를 통째로 삼키고 `SaveGame.initial()` 을
/// 돌려줬다. 유저에게는 진행이 사라진 것으로 보이고, 60초 뒤 업로더가 그 빈
/// 세이브를 서버에 올려 **복구 불가능하게** 만들었다. 크래시보다 나쁘다.
void main() {
  late Directory dir;
  late Box box;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('bugchamp_save_test');
    Hive.init(dir.path);
    box = await Hive.openBox('t${dir.path.hashCode}');
  });

  tearDown(() async {
    await box.deleteFromDisk();
    await Hive.close();
    await dir.delete(recursive: true);
  });

  final t0 = DateTime.utc(2026, 8, 26, 12);

  test('정상 세이브는 실패로 표시되지 않고, 저장도 그대로 된다', () async {
    final repo = HiveSaveRepository(box);
    await repo.save(SaveGame.initial(createdAt: t0).copyWith(gold: 1234));
    final loaded = await repo.load();
    expect(repo.lastFailure, isNull);
    expect(loaded.gold, 1234);
    expect(box.get(HiveSaveRepository.backupKey), isNull);
  });

  test('앱보다 높은 스키마 = 업데이트 필요 (다운그레이드)', () async {
    final json = SaveGame.initial(createdAt: t0).toJson();
    json['schemaVersion'] = kSaveSchemaVersion + 1;
    await box.put('game', jsonEncode(json));

    final repo = HiveSaveRepository(box);
    await repo.load();
    expect(repo.lastFailure, SaveLoadFailure.needsUpdate);
  });

  test('깨진 JSON = 손상', () async {
    await box.put('game', '{이건 JSON 이 아니다');
    final repo = HiveSaveRepository(box);
    await repo.load();
    expect(repo.lastFailure, SaveLoadFailure.corrupt);
  });

  test('읽지 못하면 원본을 격리해 두고, save() 가 그 위를 덮지 않는다', () async {
    const original = '{"schemaVersion": 999, "gold": 77}';
    await box.put('game', original);

    final repo = HiveSaveRepository(box);
    await repo.load();
    // 원본은 손대지 않고 따로 보관한다.
    expect(box.get(HiveSaveRepository.backupKey), original);

    // ⚠️ 여기가 핵심 — 실패 상태에서 저장하면 원본이 초기 세이브로 덮인다.
    await repo.save(SaveGame.initial(createdAt: t0));
    expect(box.get('game'), original);
  });

  test('두 번째 실패가 첫 격리본을 덮지 않는다 (첫 원본이 가장 온전하다)', () async {
    const first = '{"schemaVersion": 999, "gold": 77}';
    await box.put('game', first);
    await HiveSaveRepository(box).load();

    await box.put('game', '{"schemaVersion": 999, "gold": 0}');
    await HiveSaveRepository(box).load();

    expect(box.get(HiveSaveRepository.backupKey), first);
  });

  test('clear() 는 격리 상태를 풀되 격리본은 남긴다', () async {
    await box.put('game', '{망가진 것');
    final repo = HiveSaveRepository(box);
    await repo.load();
    expect(repo.lastFailure, isNotNull);

    await repo.clear();
    expect(repo.lastFailure, isNull);
    expect(box.get(HiveSaveRepository.backupKey), isNotNull);
    // 초기화 뒤에는 다시 저장이 된다.
    await repo.save(SaveGame.initial(createdAt: t0).copyWith(gold: 5));
    expect((await repo.load()).gold, 5);
  });
}

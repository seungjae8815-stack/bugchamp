import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import 'package:core_save/core_save.dart';

/// 세이브를 **읽지 못했다**는 사실. 읽기에 실패했을 때만 값이 있다.
enum SaveLoadFailure {
  /// 세이브가 이 앱이 아는 스키마보다 **높다** — 다운그레이드(또는 다른 기기가
  /// 더 새 버전). 유저가 할 일은 앱 업데이트다.
  needsUpdate,

  /// JSON 이 깨졌거나 이 버전이 해석할 수 없다.
  corrupt,
}

/// 세이브를 **읽지 못했다**. 화면(앱 셸)이 듣고 게임을 통째로 덮는다.
///
/// 읽지 못한 채로 놀게 두면 초기 세이브 위에 진행이 쌓이고, 업로더가 그걸
/// 서버에 올려 **원래 계정을 덮어쓴다**. 멈추는 게 유일하게 안전한 선택이다.
final saveUnreadable = ValueNotifier<SaveLoadFailure?>(null);

/// 세이브 로드/저장 추상화. (Phase 4 에서 클라우드 동기화로 확장 여지)
abstract interface class SaveRepository {
  /// 저장된 세이브를 로드. 없으면 초기 세이브.
  ///
  /// ⚠️ **읽기에 실패해도 초기 세이브를 돌려준다** — 앱이 부팅은 해야 하기
  /// 때문이다. 대신 [lastFailure] 가 채워지고, 그 상태에서는 [save] 가
  /// 아무것도 쓰지 않으며 업로더도 멈춘다. 이 값을 무시하고 진행시키면
  /// **빈 세이브가 서버를 덮어써 계정이 초기화된다**.
  Future<SaveGame> load();

  /// 마지막 [load] 가 실패했으면 그 사유, 성공했으면 null.
  SaveLoadFailure? get lastFailure;

  Future<void> save(SaveGame game);

  Future<void> clear();
}

/// Hive 박스에 **버전드 JSON 문자열**로 저장하는 구현.
/// Hive 는 단순 key-value 저장소로만 쓰고, 스키마 진화는 JSON 마이그레이션이 담당한다
/// (TypeAdapter 미사용 → 마이그레이션 단순·안전).
class HiveSaveRepository implements SaveRepository {
  HiveSaveRepository(this._box);

  final Box _box;
  static const String _key = 'game';

  /// 읽기에 실패한 원본을 **손대지 않고** 옮겨 두는 자리.
  /// 덮어쓰지 않는다 — 첫 실패본이 가장 온전하다.
  @visibleForTesting
  static const String backupKey = 'game_unreadable';

  SaveLoadFailure? _failure;

  @override
  SaveLoadFailure? get lastFailure => _failure;

  @override
  Future<SaveGame> load() async {
    _failure = null;
    final raw = _box.get(_key);
    // 저장된 게 없다 = 신규 유저. 실패가 아니다.
    if (raw is! String) return SaveGame.initial();
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final version = (decoded['schemaVersion'] as num?)?.toInt() ?? 0;
      // 앞선 버전이 만든 세이브인지 **먼저** 가른다. 사유가 다르면 유저가 할
      // 일도 다르다(업데이트 vs 문의).
      if (version > kSaveSchemaVersion) {
        await _quarantine(raw, SaveLoadFailure.needsUpdate);
        return SaveGame.initial();
      }
      return SaveGame.fromJson(migrateToCurrent(decoded));
    } catch (e) {
      // ⚠️ 예전에는 여기서 조용히 초기 세이브를 돌려줬다(2026-08-26 수정).
      // 유저 화면에서는 진행이 통째로 사라진 것으로 보이고, 60초 뒤 업로더가
      // **그 빈 세이브를 서버에 덮어써** 복구할 수도 없게 만든다. 조용해서
      // 더 나빴다. 이제는 원본을 격리하고 게임을 멈춘다.
      debugPrint('[save] 로드 실패: $e');
      await _quarantine(raw, SaveLoadFailure.corrupt);
      return SaveGame.initial();
    }
  }

  Future<void> _quarantine(String raw, SaveLoadFailure why) async {
    _failure = why;
    // 이미 격리본이 있으면 남겨 둔다 — 두 번째 실패본으로 덮으면 첫 원본을 잃는다.
    if (_box.get(backupKey) is! String) {
      await _box.put(backupKey, raw);
    }
  }

  @override
  Future<void> save(SaveGame game) async {
    // 읽지 못한 상태에서 쓰면 원본을 **초기 세이브로 덮어쓴다**. 쓰지 않는다.
    if (_failure != null) return;
    await _box.put(_key, jsonEncode(game.toJson()));
  }

  @override
  Future<void> clear() async {
    // 유저가 스스로 초기화를 택한 경우다 — 격리 상태도 함께 푼다.
    // (격리본 자체는 남긴다. 지우는 건 되돌릴 수 없다.)
    _failure = null;
    await _box.delete(_key);
  }
}

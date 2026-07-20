import 'dart:convert';

import 'package:hive/hive.dart';

import 'package:core_save/core_save.dart';

/// 세이브 로드/저장 추상화. (Phase 4 에서 클라우드 동기화로 확장 여지)
abstract interface class SaveRepository {
  /// 저장된 세이브를 로드. 없으면 초기 세이브, 손상 시 초기 세이브로 폴백.
  Future<SaveGame> load();

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

  @override
  Future<SaveGame> load() async {
    final raw = _box.get(_key);
    if (raw is! String) return SaveGame.initial();
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final migrated = migrateToCurrent(decoded);
      return SaveGame.fromJson(migrated);
    } catch (_) {
      // 손상/미지원 데이터 → 진행 보호를 위해 초기 세이브로 폴백.
      // (실서비스에선 손상본 백업/로깅 권장 — TODO Phase 4 서버 백업)
      return SaveGame.initial();
    }
  }

  @override
  Future<void> save(SaveGame game) async {
    await _box.put(_key, jsonEncode(game.toJson()));
  }

  @override
  Future<void> clear() async {
    await _box.delete(_key);
  }
}

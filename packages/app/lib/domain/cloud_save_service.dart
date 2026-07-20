import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 클라우드 세이브(백업/복원) 계약.
///
/// `PvpBackend` 와 같은 "인터페이스 + 구현 교체" 패턴. Supabase 키가 없으면
/// [NoCloudSave] 가 쓰여 UI 가 "사용 불가"로 표시된다.
///
/// ⚠️ 익명 인증만 쓰는 동안엔 **앱 삭제 시 계정(uid)도 사라져** 복원이 불가능하다.
/// 기기 변경까지 커버하려면 구글 로그인(계정 연동)이 선행돼야 한다.
abstract interface class CloudSaveService {
  /// 서버에 연결돼 백업/복원이 가능한지.
  bool get available;

  /// 마지막 백업 시각(UTC). 백업이 없으면 null.
  Future<DateTime?> lastBackupAt();

  /// 현재 세이브 JSON 을 서버에 업로드(업서트).
  Future<bool> upload(Map<String, dynamic> saveJson);

  /// 서버 세이브 JSON 을 내려받는다. 없으면 null.
  Future<Map<String, dynamic>?> download();
}

/// 백엔드 미연결(키 없음) — 항상 사용 불가.
class NoCloudSave implements CloudSaveService {
  const NoCloudSave();

  @override
  bool get available => false;

  @override
  Future<DateTime?> lastBackupAt() async => null;

  @override
  Future<bool> upload(Map<String, dynamic> saveJson) async => false;

  @override
  Future<Map<String, dynamic>?> download() async => null;
}

/// Supabase `saves` 테이블 기반 구현(행 1개 = 유저 1명, RLS 본인만).
/// 스키마는 docs/backend_supabase.md 참조.
class SupabaseCloudSave implements CloudSaveService {
  const SupabaseCloudSave(this._client);

  final SupabaseClient _client;

  String? get _uid => _client.auth.currentUser?.id;

  @override
  bool get available => _uid != null;

  @override
  Future<DateTime?> lastBackupAt() async {
    final uid = _uid;
    if (uid == null) return null;
    try {
      final row = await _client
          .from('saves')
          .select('updated_at')
          .eq('id', uid)
          .maybeSingle();
      final ts = row?['updated_at'] as String?;
      return ts == null ? null : DateTime.parse(ts).toUtc();
    } catch (e) {
      debugPrint('lastBackupAt failed: $e');
      return null;
    }
  }

  @override
  Future<bool> upload(Map<String, dynamic> saveJson) async {
    final uid = _uid;
    if (uid == null) return false;
    try {
      await _client.from('saves').upsert({
        'id': uid,
        'data': saveJson,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      return true;
    } catch (e) {
      debugPrint('cloud upload failed: $e');
      return false;
    }
  }

  @override
  Future<Map<String, dynamic>?> download() async {
    final uid = _uid;
    if (uid == null) return null;
    try {
      final row = await _client
          .from('saves')
          .select('data')
          .eq('id', uid)
          .maybeSingle();
      final data = row?['data'];
      return data == null ? null : Map<String, dynamic>.from(data as Map);
    } catch (e) {
      debugPrint('cloud download failed: $e');
      return null;
    }
  }
}

/// 교체 가능한 클라우드 세이브 제공자. 기본은 미연결.
final cloudSaveProvider = Provider<CloudSaveService>(
  (ref) => const NoCloudSave(),
);

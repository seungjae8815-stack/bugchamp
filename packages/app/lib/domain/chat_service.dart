import 'dart:async';

import 'package:core_models/core_models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 전체 채팅 서비스 계약. 다른 서비스들과 같은 "인터페이스 + 구현 교체" 패턴.
///
/// ⚠️ 채팅은 **사용자 제작 콘텐츠(UGC)** 다. 구글 플레이 정책상
/// 신고·차단 수단이 반드시 있어야 하므로 [report] 를 계약에 포함한다.
/// (차단은 기기 로컬 목록으로 처리 — `SaveGame.blockedUserIds`)
abstract interface class ChatService {
  /// 서버에 연결돼 채팅을 쓸 수 있는지.
  bool get available;

  /// 최근 메시지를 시간순(오래된 것 → 최신)으로 가져온다.
  Future<List<ChatMessage>> recent({int limit = 50});

  /// 새 메시지 실시간 스트림.
  Stream<ChatMessage> subscribe();

  /// 메시지 전송. 성공 시 true.
  /// **금칙어·길이·도배 검사는 호출 전에 [ChatRules.check] 로 끝내야 한다.**
  Future<bool> send({required String nickname, required String body});

  /// 메시지 신고(UGC 정책 필수). 같은 메시지를 두 번 신고해도 오류가 아니다.
  Future<bool> report({required String messageId, required String reason});

  void dispose();
}

/// 백엔드 미연결 — 채팅 사용 불가.
class NoChatService implements ChatService {
  const NoChatService();

  @override
  bool get available => false;
  @override
  Future<List<ChatMessage>> recent({int limit = 50}) async => const [];
  @override
  Stream<ChatMessage> subscribe() => const Stream.empty();
  @override
  Future<bool> send({required String nickname, required String body}) async =>
      false;
  @override
  Future<bool> report({
    required String messageId,
    required String reason,
  }) async => false;
  @override
  void dispose() {}
}

/// Supabase `chat_messages` 기반 구현.
///
/// 스키마·RLS·도배 방지 트리거는 `docs/backend_supabase.md` §8 참조.
/// 서버에도 전송 간격 제한을 두는 이유: 클라이언트 검사만으로는
/// 앱을 조작한 사용자를 막지 못한다.
class SupabaseChatService implements ChatService {
  SupabaseChatService(this._client);

  final SupabaseClient _client;
  RealtimeChannel? _channel;

  String? get _uid => _client.auth.currentUser?.id;

  /// 내 계정 id(표시용).
  String? get myUserId => _uid;

  @override
  bool get available => _uid != null;

  @override
  Future<List<ChatMessage>> recent({int limit = 50}) async {
    try {
      final rows = await _client
          .from('chat_messages')
          .select()
          .order('created_at', ascending: false)
          .limit(limit);
      // 최신순으로 받아 화면 표시용(오래된 것 → 최신)으로 뒤집는다.
      return [
        for (final r in (rows as List).reversed)
          ChatMessage.fromJson(r as Map<String, dynamic>),
      ];
    } catch (e) {
      debugPrint('[chat] recent 실패: $e');
      return const [];
    }
  }

  @override
  Stream<ChatMessage> subscribe() {
    final controller = StreamController<ChatMessage>.broadcast();
    _channel = _client
        .channel('public:chat_messages')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'chat_messages',
          callback: (payload) {
            try {
              controller.add(ChatMessage.fromJson(payload.newRecord));
            } catch (e) {
              debugPrint('[chat] payload 파싱 실패: $e');
            }
          },
        )
        .subscribe();
    controller.onCancel = () {
      final ch = _channel;
      _channel = null;
      if (ch != null) _client.removeChannel(ch);
    };
    return controller.stream;
  }

  @override
  Future<bool> send({required String nickname, required String body}) async {
    final uid = _uid;
    if (uid == null) return false;
    try {
      await _client.from('chat_messages').insert({
        'user_id': uid,
        'nickname': nickname,
        'body': body,
      });
      return true;
    } catch (e) {
      // 서버 도배 제한(트리거)에 걸리면 여기로 온다.
      debugPrint('[chat] send 실패: $e');
      return false;
    }
  }

  @override
  Future<bool> report({
    required String messageId,
    required String reason,
  }) async {
    final uid = _uid;
    if (uid == null) return false;
    try {
      await _client.from('chat_reports').upsert({
        'message_id': int.tryParse(messageId) ?? 0,
        'reporter_id': uid,
        'reason': reason,
      }, onConflict: 'message_id,reporter_id');
      return true;
    } catch (e) {
      debugPrint('[chat] report 실패: $e');
      return false;
    }
  }

  @override
  void dispose() {
    final ch = _channel;
    _channel = null;
    if (ch != null) _client.removeChannel(ch);
  }
}

/// 내 계정 id — 내 말풍선을 오른쪽에 붙이는 용도.
/// 미연결이면 null(모든 메시지가 남의 것으로 보인다).
final chatMyUserIdProvider = Provider<String?>((ref) {
  final svc = ref.watch(chatServiceProvider);
  return svc is SupabaseChatService ? svc.myUserId : null;
});

/// 교체 가능한 채팅 서비스. 기본은 미연결.
final chatServiceProvider = Provider<ChatService>((ref) {
  const s = NoChatService();
  ref.onDispose(s.dispose);
  return s;
});

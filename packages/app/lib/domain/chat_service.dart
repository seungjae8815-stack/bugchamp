import 'dart:async';

import 'package:core_models/core_models.dart';
import 'package:flutter/widgets.dart';
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
  /// [guildId] 가 있으면 그 길드 채팅, 없으면 전체 채팅. [mixed] 면 전체 + 그 길드 글을 함께
  /// (채팅 화면 "전체" 탭 — 길드 글은 [길드] 표시로 가른다, 2026-10-05).
  Future<List<ChatMessage>> recent({
    int limit = 50,
    String? guildId,
    bool mixed = false,
  });

  /// 새 메시지 실시간 스트림 — 거르는 규칙은 [chatMessageVisible].
  Stream<ChatMessage> subscribe({String? guildId, bool mixed = false});

  /// 메시지 전송. 성공 시 true.
  /// **금칙어·길이·도배 검사는 호출 전에 [ChatRules.check] 로 끝내야 한다.**
  ///
  /// [badge]·[avatar] 는 **먼저 띄우는 내 화면용**일 뿐이다 — 서버에는 보내지 않는다.
  /// 저장되는 뱃지·그림은 DB 트리거가 `profiles.badge`·`profiles.avatar` 에서 찍는다.
  Future<bool> send({
    required String nickname,
    required String body,
    String badge = '',
    String? guildId,
    String? avatar,
  });

  /// 메시지 신고(UGC 정책 필수). 같은 메시지를 두 번 신고해도 오류가 아니다.
  Future<bool> report({required String messageId, required String reason});

  /// **본인이 쓴 메시지 삭제**(UGC 정책 — Apple 1.2). 성공 시 true.
  /// 서버 RLS 로 본인 메시지만 지워진다(남의 것은 지워지지 않음).
  Future<bool> deleteOwn({required String messageId});

  void dispose();
}

/// 채팅 탭에 이 글이 보이나(2026-10-05 전체/길드 탭).
/// - 길드 탭(`mixed` 아님 + [guildId]): 그 길드 글만.
/// - 전체 탭(`mixed` + [guildId]): 전체 글 + 내 길드 글(화면이 [길드] 표시를 붙인다).
/// - 길드가 없으면([guildId] null): 전체 글만.
/// DB 정책(`chat_read`)이 원래 전체 + 내 길드 글만 보내 주지만, 길드를 막 옮긴 순간 등을 위해 앱도 거른다.
bool chatMessageVisible(ChatMessage m, {String? guildId, bool mixed = false}) {
  if (guildId == null) return m.guildId == null;
  if (mixed) return m.guildId == null || m.guildId == guildId;
  return m.guildId == guildId;
}

/// 백엔드 미연결 — 채팅 사용 불가.
class NoChatService implements ChatService {
  const NoChatService();

  @override
  bool get available => false;
  @override
  Future<List<ChatMessage>> recent({
    int limit = 50,
    String? guildId,
    bool mixed = false,
  }) async => const [];
  @override
  Stream<ChatMessage> subscribe({String? guildId, bool mixed = false}) =>
      const Stream.empty();
  @override
  Future<bool> send({
    required String nickname,
    required String body,
    String badge = '',
    String? guildId,
    String? avatar,
  }) async => false;
  @override
  Future<bool> report({
    required String messageId,
    required String reason,
  }) async => false;
  @override
  Future<bool> deleteOwn({required String messageId}) async => false;
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
  Future<List<ChatMessage>> recent({
    int limit = 50,
    String? guildId,
    bool mixed = false,
  }) async {
    try {
      // 전체 채팅만이면 `guild_id is null` 로 거른다 — 정책이 내 길드 글도 읽게 해 주므로
      // 안 거르면 길드 대화가 섞인다. "전체" 탭([mixed])은 전체 + 내 길드 글을 함께 받는다.
      final q = _client.from('chat_messages').select();
      final rows =
          await (guildId == null
                  ? q.isFilter('guild_id', null)
                  : mixed
                  ? q.or('guild_id.is.null,guild_id.eq.$guildId')
                  : q.eq('guild_id', guildId))
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

  /// 구독자 전체가 나눠 쓰는 브로드캐스트 스트림.
  StreamController<ChatMessage>? _events;

  /// ⚠️ **구독자가 둘 이상이다** — 홈 상단 채팅 바와 전체 채팅 화면.
  ///
  /// 예전엔 호출마다 같은 토픽(`public:chat_messages`)으로 채널을 새로 만들고
  /// `_channel` 을 덮어썼다. 그러면 나중에 붙은 쪽이 먼저 붙은 쪽을 밀어내
  /// **홈 채팅 바가 조용히 갱신을 멈췄고**, 채팅 화면을 나갈 때 채널을 지워
  /// 남은 구독자까지 끊겼다. 채널은 하나만 두고 스트림을 공유한다.
  ///
  /// 길드 채팅도 **같은 채널**로 온다 — DB 정책이 전체 + 내 길드 글만 보내 주므로 채널을 더 열
  /// 필요가 없다(연결 수 = 요금). 받는 쪽에서 [chatMessageVisible] 로 가른다.
  @override
  Stream<ChatMessage> subscribe({String? guildId, bool mixed = false}) {
    final controller = _events ??= StreamController<ChatMessage>.broadcast();
    _ensureChannel();
    // 개별 구독자가 떠나도 채널은 유지한다 — 정리는 [dispose] 한 곳에서만.
    return controller.stream.where(
      (m) => chatMessageVisible(m, guildId: guildId, mixed: mixed),
    );
  }

  /// 지금 채널의 구독 상태(null = 아직 응답 없음).
  RealtimeSubscribeStatus? _status;
  Timer? _retry;
  int _retryCount = 0;
  bool _disposed = false;

  /// 다시 붙는 간격(초) — 계속 실패하면 마지막 값으로 반복한다.
  static const _retrySeconds = [2, 5, 10, 30];

  /// 채널이 없으면 연다. ⚠️ 구독 상태를 **지켜본다**(2026-10-10 실기 지적 — 채팅이 실시간으로 안 바뀜).
  /// 예전엔 한 번 열면 끝이라, 폰이 잠겼다 돌아오며 토큰이 만료된 채 다시 붙다 실패하는 식으로 채널이 조용히
  /// 죽으면 앱을 다시 켤 때까지 새 글이 오지 않았다. 오류·닫힘·시간 초과면 간격을 두고 새 채널로 다시 붙는다.
  void _ensureChannel() {
    final controller = _events;
    if (_channel != null || controller == null || _disposed) return;
    _lifecycle ??= AppLifecycleListener(
      onPause: () => _pausedAt = DateTime.now(),
      onResume: _onResumed,
    );
    late final RealtimeChannel ch;
    ch = _client
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
        .subscribe((status, error) {
          // 지운 옛 채널이 닫히며 부르는 콜백은 무시한다(안 그러면 다시 붙기가 꼬리를 문다).
          if (!identical(_channel, ch)) return;
          _status = status;
          if (status == RealtimeSubscribeStatus.subscribed) {
            // 클라이언트가 스스로 다시 붙었으면 걸어 둔 재연결은 취소한다 — 안 그러면 멀쩡한 채널을 버리고 새로 연다.
            _retry?.cancel();
            _retryCount = 0;
            return;
          }
          debugPrint('[chat] 실시간 $status ${error ?? ''}');
          _scheduleReconnect();
        });
    _channel = ch;
  }

  void _scheduleReconnect() {
    if (_disposed || _events == null) return;
    _retry?.cancel();
    final sec = _retrySeconds[_retryCount.clamp(0, _retrySeconds.length - 1)];
    _retryCount++;
    _retry = Timer(Duration(seconds: sec), _reconnectNow);
  }

  /// 지금 채널을 버리고 새로 연다.
  void _reconnectNow() {
    _retry?.cancel();
    final old = _channel;
    _channel = null;
    _status = null;
    if (old != null) unawaited(_client.removeChannel(old));
    _ensureChannel();
  }

  AppLifecycleListener? _lifecycle;
  DateTime? _pausedAt;

  /// 앱이 다시 앞으로 왔을 때 — 구독이 살아 있지 않거나 30초 넘게 나가 있었으면 새로 붙는다.
  /// (상태가 subscribed 로 남은 채 소켓만 죽어 있는 경우까지 덮는다. 다시 붙기는 채널 하나라 싸다.)
  void _onResumed() {
    if (_disposed || _events == null) return;
    final away = _pausedAt == null
        ? Duration.zero
        : DateTime.now().difference(_pausedAt!);
    _pausedAt = null;
    if (_status == RealtimeSubscribeStatus.subscribed &&
        away < const Duration(seconds: 30)) {
      return;
    }
    _retryCount = 0;
    _reconnectNow();
  }

  @override
  Future<bool> send({
    required String nickname,
    required String body,
    String badge = '',
    String? guildId,
    String? avatar,
  }) async {
    final uid = _uid;
    if (uid == null) return false;
    try {
      await _client.from('chat_messages').insert({
        'user_id': uid,
        'nickname': nickname,
        'body': body,
        'guild_id': ?guildId,
      });
      // ⚠️ **넣자마자 스스로 방송한다.** 예전에는 Postgres → realtime →
      // 앱 왕복이 돌아올 때까지 기다렸고, 그 시간이 그대로 "내가 쓴 글이 늦게
      // 뜬다"로 보였다(2026-08-30 지적). 홈 상단 채팅 바도 같은 스트림을
      // 보므로 여기서 한 번 방송하면 두 화면이 함께 즉시 갱신된다.
      //
      // 실제 브로드캐스트가 뒤따라 오면 같은 내용이 한 번 더 들어온다 —
      // 받는 쪽이 **내가 먼저 띄운 것과 같은 글이면 대체**한다(chat_screen).
      _events?.add(
        ChatMessage(
          id: 'echo:${DateTime.now().microsecondsSinceEpoch}',
          userId: uid,
          nickname: nickname,
          body: body,
          createdAt: DateTime.now().toUtc(),
          badge: badge,
          guildId: guildId,
          avatar: avatar,
        ),
      );
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
  Future<bool> deleteOwn({required String messageId}) async {
    final uid = _uid;
    if (uid == null) return false;
    try {
      // RLS(chat_delete)로 본인 메시지만 삭제된다. user_id 조건도 명시(방어).
      await _client
          .from('chat_messages')
          .delete()
          .eq('id', int.tryParse(messageId) ?? 0)
          .eq('user_id', uid);
      return true;
    } catch (e) {
      debugPrint('[chat] delete 실패: $e');
      return false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _retry?.cancel();
    _lifecycle?.dispose();
    _lifecycle = null;
    final ch = _channel;
    _channel = null;
    if (ch != null) _client.removeChannel(ch);
    unawaited(_events?.close());
    _events = null;
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

/// 홈 상단 채팅 바에 보여줄 **가장 최근 메시지 1건**.
///
/// 처음엔 최근 목록에서 마지막 하나를 집고, 그 뒤로는 실시간 구독으로 갱신한다.
/// 실시간이 조용히 끊길 수 있어(2026-10-10 실기 지적 — 서버 구독 목록에서 빠진 채 켜져 있었다)
/// [_latestPoll] 마다 최근 1건을 직접 확인하는 안전망을 둔다(작은 조회 1번).
/// 채팅이 미연결이거나 아직 아무 말도 없으면 null → 바는 안내 문구를 보여준다.
final chatLatestProvider = StreamProvider<ChatMessage?>((ref) {
  final svc = ref.watch(chatServiceProvider);
  if (!svc.available) return Stream.value(null);
  final out = StreamController<ChatMessage?>();
  ChatMessage? latest;
  var first = true;
  Future<void> poll() async {
    var list = const <ChatMessage>[];
    try {
      list = await svc.recent(limit: 1);
    } catch (_) {
      // 조회 실패는 조용히 넘긴다 — 홈 화면이 채팅 때문에 깨지면 안 된다.
    }
    if (out.isClosed) return;
    final m = list.isEmpty ? null : list.last;
    final newer =
        m != null &&
        m.id != latest?.id &&
        (latest == null || m.createdAt.isAfter(latest!.createdAt));
    if (newer) {
      latest = m;
      out.add(m);
    } else if (first && latest == null) {
      out.add(null);
    }
    first = false;
  }

  unawaited(poll());
  final sub = svc.subscribe().listen((m) {
    latest = m;
    if (!out.isClosed) out.add(m);
  });
  // 앱이 앞에 있을 때만 — 백그라운드에서도 돌면 시간당 80번 헛조회다(복귀하면 다음 주기에 채운다).
  final timer = Timer.periodic(_latestPoll, (_) {
    final st = WidgetsBinding.instance.lifecycleState;
    if (st != null && st != AppLifecycleState.resumed) return;
    poll();
  });
  ref.onDispose(() {
    timer.cancel();
    unawaited(sub.cancel());
    unawaited(out.close());
  });
  return out.stream;
});

/// 홈 채팅 바 안전망 간격.
const _latestPoll = Duration(seconds: 45);

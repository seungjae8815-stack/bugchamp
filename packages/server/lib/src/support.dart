import 'dart:convert';
import 'dart:io' show Platform, stderr;

import 'package:http/http.dart' as http;

/// 유저 문의를 **텔레그램으로 밀어 준다**.
///
/// 왜 서버가 하나: 봇 토큰은 비밀이라 앱에 넣을 수 없다. 앱에 넣으면 누구나
/// 꺼내 아무 메시지나 보낼 수 있다(스팸·사칭). 서버는 이미 토큰을 안전하게
/// 쥐고 있고, **누가 보냈는지도 인증으로 안다**.
///
/// 게임 내 채팅으로 버그를 알리는 유저가 많은데(2026-08-30), 채팅은 흘러가고
/// 운영자가 놓친다. 문의는 놓치면 안 되는 신호라 따로 받는다.
class SupportNotifier {
  SupportNotifier({http.Client? client, String? botToken, String? chatId})
    : _http = client ?? http.Client(),
      _token = botToken ?? Platform.environment['TELEGRAM_BOT_TOKEN'] ?? '',
      _chat =
          chatId ?? Platform.environment['TELEGRAM_CHAT_ID'] ?? _defaultChat;

  /// 일일 리포트(Edge Function)와 **같은 방**. 기본값을 두는 이유는 사장님이
  /// 배포 때 넣을 것을 **토큰 하나로 줄이기** 위해서다 — 채팅방 ID 는 비밀이
  /// 아니고, 빠뜨리면 기능이 통째로 꺼진다.
  static const _defaultChat = '1025640548';

  final http.Client _http;
  final String _token;
  final String _chat;

  /// 유저별 마지막 전송 시각 — 도배 방지.
  final Map<String, DateTime> _lastSent = {};

  /// 같은 유저가 다시 보낼 수 있게 되기까지.
  static const cooldown = Duration(minutes: 1);

  /// 본문 길이 상한. 길면 텔레그램이 잘라 버려 뒷부분이 사라진다.
  static const maxLength = 500;

  bool get available => _token.isNotEmpty && _chat.isNotEmpty;

  /// 남은 대기 시간(0 이면 지금 보낼 수 있다).
  Duration remainingCooldown(String userId, DateTime now) {
    final last = _lastSent[userId];
    if (last == null) return Duration.zero;
    final left = cooldown - now.difference(last);
    return left.isNegative ? Duration.zero : left;
  }

  /// 문의를 보낸다. 성공하면 true.
  ///
  /// [context] 는 상황 파악에 필요한 값들(닉네임·스테이지·버전 등) —
  /// 이게 없으면 "버그예요"라는 메시지만 받고 아무것도 못 한다.
  Future<bool> send({
    required String userId,
    required String message,
    required Map<String, Object?> context,
    required DateTime now,
  }) async {
    if (!available) return false;
    _lastSent[userId] = now;

    final ctx = [
      for (final e in context.entries)
        if (e.value != null && '${e.value}'.isNotEmpty) '${e.key}: ${e.value}',
    ].join('\n');

    // ⚠️ 유저가 쓴 글을 **그대로** 넣는다(마크다운 파싱 안 함). 서식 문자를
    // 해석하면 남이 쓴 글로 메시지 모양을 바꿀 수 있다.
    final text = '🐛 문의\n\n$message\n\n──────\n$ctx\nuid: $userId';

    try {
      final res = await _http.post(
        Uri.parse('https://api.telegram.org/bot$_token/sendMessage'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'chat_id': _chat, 'text': text}),
      );
      if (res.statusCode >= 300) {
        stderr.writeln('[support] 텔레그램 실패: ${res.statusCode}');
        return false;
      }
      return true;
    } catch (e) {
      stderr.writeln('[support] 텔레그램 예외: $e');
      return false;
    }
  }
}

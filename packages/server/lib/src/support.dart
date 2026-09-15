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
  SupportNotifier({
    http.Client? client,
    String? botToken,
    String? chatId,
    String? webhookSecret,
  }) : _http = client ?? http.Client(),
       _token = botToken ?? Platform.environment['TELEGRAM_BOT_TOKEN'] ?? '',
       _chat =
           chatId ?? Platform.environment['TELEGRAM_CHAT_ID'] ?? _defaultChat,
       _secret =
           (webhookSecret ??
                   Platform.environment['TELEGRAM_WEBHOOK_SECRET'] ??
                   '')
               .trim();

  /// 일일 리포트(Edge Function)와 **같은 방**. 기본값을 두는 이유는 사장님이
  /// 배포 때 넣을 것을 **토큰 하나로 줄이기** 위해서다 — 채팅방 ID 는 비밀이
  /// 아니고, 빠뜨리면 기능이 통째로 꺼진다.
  static const _defaultChat = '1025640548';

  final http.Client _http;
  final String _token;
  final String _chat;

  /// 텔레그램 웹훅 비밀값(`setWebhook` 의 `secret_token`).
  /// 비어 있으면 답장 기능이 잠긴다 — 아무나 우편을 보내는 문을 열어두지 않는다.
  final String _secret;

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

  static const _header = '🐛 문의';
  static const _divider = '──────';

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
    // ⚠️ `uid:` 줄은 답장 기능이 유저를 찾는 근거다([parseReply]) — 형식을 바꾸지 않는다.
    final text =
        '$_header\n\n$message\n\n$_divider\n$ctx\nuid: $userId'
        '${replyAvailable ? '\n\n↩️ 이 메시지에 답장하면 우편으로 전달돼요' : ''}';
    return _post({'chat_id': _chat, 'text': text});
  }

  // ───────────────────────── 답장 → 우편 ─────────────────────────
  //
  // 운영자가 텔레그램에서 문의 알림에 **답장**하면 그 글을 유저 우편으로 보낸다.
  // 예전엔 알림만 오고 답할 길이 없어, 운영 패널에서 uid 를 옮겨 우편을 따로 썼다.
  //
  // ⚠️ 봇 하나에 웹훅은 하나다. 봇을 다른 서비스와 같이 쓰면 그쪽 수신이 끊긴다.

  /// 우편 본문 상한 — 운영 패널 우편(`/admin/mail`)과 같다.
  static const replyMaxLength = 1000;

  /// 우편 본문에 붙이는 원래 문의의 최대 길이.
  static const quoteMaxLength = 200;

  bool get replyAvailable => available && _secret.isNotEmpty;

  /// 최근 처리한 update_id — 텔레그램이 재전송해도 우편이 두 통 가지 않게.
  final List<int> _seenUpdates = [];

  /// 웹훅 요청이 정말 텔레그램에서 왔는지(비밀 헤더 비교, 상수 시간).
  bool webhookAuthorized(String? header) {
    if (!replyAvailable) return false;
    final given = (header ?? '').trim();
    if (given.length != _secret.length) return false;
    var diff = 0;
    for (var i = 0; i < given.length; i++) {
      diff |= given.codeUnitAt(i) ^ _secret.codeUnitAt(i);
    }
    return diff == 0;
  }

  /// 텔레그램 update 에서 "문의 알림에 단 답장"을 찾는다. 해당 없으면 null.
  ///
  /// 받는 조건: 우리 채팅방 · 글이 있음 · 답장 대상이 `uid:` 줄을 가진 문의 알림.
  /// 같은 update_id 는 한 번만 돌려준다.
  SupportReply? parseReply(Map<String, dynamic> update) {
    final msg = update['message'];
    if (msg is! Map) return null;
    final chat = msg['chat'];
    if (chat is! Map || '${chat['id']}' != _chat) return null;
    final text = (msg['text'] as String?)?.trim() ?? '';
    if (text.isEmpty) return null;
    final origin = msg['reply_to_message'];
    if (origin is! Map) return null;
    final originText = origin['text'] as String? ?? '';
    if (!originText.startsWith(_header)) return null;
    final uid = RegExp(
      r'^uid: ([0-9a-fA-F-]{36})$',
      multiLine: true,
    ).firstMatch(originText)?.group(1);
    if (uid == null) return null;

    final updateId = update['update_id'];
    if (updateId is int) {
      if (_seenUpdates.contains(updateId)) return null;
      _seenUpdates.add(updateId);
      if (_seenUpdates.length > 200) _seenUpdates.removeAt(0);
    }

    // 원래 문의 본문 = 머리말과 구분선 사이.
    final start = originText.indexOf('\n\n');
    final end = originText.lastIndexOf('\n\n$_divider');
    var quote = (start >= 0 && end > start)
        ? originText.substring(start + 2, end).trim()
        : '';
    if (quote.length > quoteMaxLength) {
      quote = '${quote.substring(0, quoteMaxLength)}…';
    }

    final messageId = msg['message_id'];
    return SupportReply(
      userId: uid.toLowerCase(),
      text: text,
      quote: quote,
      messageId: messageId is int ? messageId : null,
    );
  }

  /// 방에 짧은 결과 알림(발송됨/실패). [replyTo] 가 있으면 그 메시지에 답장으로.
  Future<bool> notify(String text, {int? replyTo}) async {
    if (!available) return false;
    return _post({
      'chat_id': _chat,
      'text': text,
      if (replyTo != null) 'reply_to_message_id': replyTo,
    });
  }

  // ───────────────────────── 운영 명령(텔레그램) ─────────────────────────

  /// 우리 방에서 온 `/명령` 메시지. 아니면 null. 같은 update 는 한 번만.
  ({String text, int? messageId, Map<String, dynamic>? replyTo})? parseCommand(
    Map<String, dynamic> update,
  ) {
    final msg = update['message'];
    if (msg is! Map) return null;
    final chat = msg['chat'];
    if (chat is! Map || '${chat['id']}' != _chat) return null;
    final text = (msg['text'] as String?)?.trim() ?? '';
    if (!text.startsWith('/')) return null;
    if (!_firstSeen(update)) return null;
    final id = msg['message_id'];
    final reply = msg['reply_to_message'];
    return (
      text: text,
      messageId: id is int ? id : null,
      replyTo: reply is Map ? Map<String, dynamic>.from(reply) : null,
    );
  }

  /// 우리 방에서 누른 인라인 버튼. 아니면 null.
  ({String data, String callbackId, int? messageId})? parseCallback(
    Map<String, dynamic> update,
  ) {
    final cb = update['callback_query'];
    if (cb is! Map) return null;
    final msg = cb['message'];
    final chat = msg is Map ? msg['chat'] : null;
    if (chat is! Map || '${chat['id']}' != _chat) return null;
    if (!_firstSeen(update)) return null;
    final id = msg is Map ? msg['message_id'] : null;
    return (
      data: '${cb['data'] ?? ''}',
      callbackId: '${cb['id'] ?? ''}',
      messageId: id is int ? id : null,
    );
  }

  bool _firstSeen(Map<String, dynamic> update) {
    final updateId = update['update_id'];
    if (updateId is! int) return true;
    if (_seenUpdates.contains(updateId)) return false;
    _seenUpdates.add(updateId);
    if (_seenUpdates.length > 200) _seenUpdates.removeAt(0);
    return true;
  }

  /// 긴 글은 텔레그램 한도(4096자) 안으로 줄 단위로 나눠 보낸다.
  Future<bool> sendLong(String text, {int? replyTo}) async {
    var ok = true;
    for (final part in chunkTelegram(text)) {
      ok = await notify(part, replyTo: replyTo) && ok;
      replyTo = null;
    }
    return ok;
  }

  /// [확인] [취소] 같은 버튼을 단 메시지. [buttons] = (글자, callback_data).
  Future<bool> sendButtons(String text, List<(String, String)> buttons) async {
    if (!available) return false;
    return _post({
      'chat_id': _chat,
      'text': text,
      'reply_markup': {
        'inline_keyboard': [
          [
            for (final b in buttons) {'text': b.$1, 'callback_data': b.$2},
          ],
        ],
      },
    });
  }

  /// 버튼 누름에 응답(텔레그램 로딩 표시를 끈다) + 원래 메시지의 버튼을 결과 글로 바꾼다.
  Future<void> resolveButtons(
    String callbackId,
    int? messageId,
    String resultText,
  ) async {
    if (!available) return;
    await _call('answerCallbackQuery', {'callback_query_id': callbackId});
    if (messageId != null) {
      await _call('editMessageText', {
        'chat_id': _chat,
        'message_id': messageId,
        'text': resultText,
      });
    }
  }

  Future<bool> _call(String method, Map<String, Object?> body) async {
    try {
      final res = await _http.post(
        Uri.parse('https://api.telegram.org/bot$_token/$method'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      return res.statusCode < 300;
    } catch (e) {
      stderr.writeln('[support] $method 예외: $e');
      return false;
    }
  }

  Future<bool> _post(Map<String, Object?> body) async {
    try {
      final res = await _http.post(
        Uri.parse('https://api.telegram.org/bot$_token/sendMessage'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
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

/// 문의 알림에 단 운영자 답장 1건.
class SupportReply {
  const SupportReply({
    required this.userId,
    required this.text,
    required this.quote,
    this.messageId,
  });

  final String userId;

  /// 운영자가 쓴 답장.
  final String text;

  /// 원래 문의(잘라낸 것). 비어 있을 수 있다.
  final String quote;

  /// 운영자 답장 메시지 id — 결과 알림을 그 메시지에 붙인다.
  final int? messageId;

  /// 우편 본문. 답장이 먼저(편지함 미리보기 두 줄에 보이게), 문의 원문은 뒤에.
  /// 합쳐서 상한을 넘으면 원문을 뺀다. 답장 자체가 넘으면 자르고 알린다.
  ({String body, bool truncated}) mailBody() {
    const max = SupportNotifier.replyMaxLength;
    if (text.length > max) {
      return (body: text.substring(0, max), truncated: true);
    }
    final withQuote = quote.isEmpty ? text : '$text\n\n── 문의 내용 ──\n$quote';
    return (body: withQuote.length <= max ? withQuote : text, truncated: false);
  }
}

/// 텔레그램 한 메시지 한도(4096자) 안으로 **줄 단위로** 나눈다. 한 줄이 너무 길면 그 줄만 자른다.
List<String> chunkTelegram(String text, {int max = 3900}) {
  final out = <String>[];
  final buf = StringBuffer();
  for (var line in text.split('\n')) {
    if (line.length > max) line = '${line.substring(0, max - 1)}…';
    if (buf.length + line.length + 1 > max) {
      out.add(buf.toString().trimRight());
      buf.clear();
    }
    buf.writeln(line);
  }
  if (buf.isNotEmpty) out.add(buf.toString().trimRight());
  return out;
}

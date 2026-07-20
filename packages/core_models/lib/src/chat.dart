import 'package:meta/meta.dart';

/// 전체 채팅 메시지 1건.
///
/// 순수 모델 — 저장소/네트워크를 모른다(직렬화만 제공).
@immutable
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.userId,
    required this.nickname,
    required this.body,
    required this.createdAt,
  });

  /// 서버가 부여한 메시지 id(신고·차단 대상 식별용).
  final String id;

  /// 보낸 사람의 계정 id. **차단은 이 값 기준**(닉네임은 바뀔 수 있다).
  final String userId;

  final String nickname;
  final String body;
  final DateTime createdAt;

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'].toString(),
    userId: json['user_id'] as String,
    nickname: json['nickname'] as String? ?? '',
    body: json['body'] as String? ?? '',
    createdAt: DateTime.parse(json['created_at'] as String).toUtc(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'nickname': nickname,
    'body': body,
    'created_at': createdAt.toUtc().toIso8601String(),
  };
}

/// 메시지 검사 결과.
enum ChatCheckResult {
  ok,

  /// 빈 문자열이거나 공백뿐.
  empty,

  /// 길이 초과.
  tooLong,

  /// 금칙어 포함 → 전송 거부.
  blocked,

  /// 너무 빨리 연속 전송(도배).
  tooFast,
}

/// 채팅 규칙 + 금칙어 필터.
///
/// **단어 목록과 수치는 전부 JSON(`chat.json`)에서 주입**한다(§6).
/// 코드에 금칙어를 박지 않는 이유: 운영 중 목록만 갈아끼울 수 있어야 한다.
///
/// 검사는 **보낼 때와 보여줄 때 양쪽에서** 한다. 목록이 갱신되기 전에
/// 서버에 들어간 과거 메시지도 가려지게 하기 위함이다.
@immutable
class ChatRules {
  const ChatRules({
    this.bannedWords = const [],
    this.maxLength = 100,
    this.minIntervalSeconds = 3,
    this.historyLimit = 50,
    this.maskChar = '*',
  });

  /// 금칙어(소문자·공백제거 기준으로 비교).
  final List<String> bannedWords;

  final int maxLength;

  /// 연속 전송 최소 간격(초) — 도배 방지.
  final int minIntervalSeconds;

  /// 화면에 유지할 최근 메시지 수.
  final int historyLimit;

  final String maskChar;

  factory ChatRules.fromJson(Map<String, dynamic> json) => ChatRules(
    bannedWords: [
      for (final w in (json['bannedWords'] as List? ?? const []))
        (w as String).toLowerCase(),
    ],
    maxLength: (json['maxLength'] as num?)?.toInt() ?? 100,
    minIntervalSeconds: (json['minIntervalSeconds'] as num?)?.toInt() ?? 3,
    historyLimit: (json['historyLimit'] as num?)?.toInt() ?? 50,
    maskChar: json['maskChar'] as String? ?? '*',
  );

  /// 비교용 정규화 — 소문자화 + 공백/구두점 제거.
  /// `씨 발` 처럼 사이를 띄워 필터를 피하는 것을 막는다.
  static String normalize(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[\s\.\,\-_~!@#$%^&*()+=|/\\]'), '');

  /// 금칙어를 포함하는지.
  bool hasBannedWord(String text) {
    if (bannedWords.isEmpty) return false;
    final n = normalize(text);
    for (final w in bannedWords) {
      if (w.isEmpty) continue;
      if (n.contains(normalize(w))) return true;
    }
    return false;
  }

  /// 표시용 마스킹 — 원문에서 금칙어 부분을 [maskChar] 로 가린다.
  /// 정규화 때문에 위치가 어긋날 수 있어, **단순 포함 시 통째로 가린다**.
  String mask(String text) {
    if (!hasBannedWord(text)) return text;
    return maskChar * text.length.clamp(1, maxLength);
  }

  /// 전송 전 검사. [lastSentAt] 이 null 이면 첫 전송.
  ChatCheckResult check(String body, {DateTime? lastSentAt, DateTime? now}) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return ChatCheckResult.empty;
    if (trimmed.length > maxLength) return ChatCheckResult.tooLong;
    if (hasBannedWord(trimmed)) return ChatCheckResult.blocked;
    if (lastSentAt != null && now != null) {
      final gap = now.difference(lastSentAt).inSeconds;
      if (gap < minIntervalSeconds) return ChatCheckResult.tooFast;
    }
    return ChatCheckResult.ok;
  }
}

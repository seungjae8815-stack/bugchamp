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
    this.isAdmin = false,
  });

  /// 서버가 부여한 메시지 id(신고·차단 대상 식별용).
  final String id;

  /// 보낸 사람의 계정 id. **차단은 이 값 기준**(닉네임은 바뀔 수 있다).
  final String userId;

  final String nickname;
  final String body;
  final DateTime createdAt;

  /// 운영자가 보낸 메시지.
  ///
  /// **서버(service_role)만 true 로 넣을 수 있다** — RLS 가 클라이언트의 true
  /// 삽입을 막는다. 닉네임은 누구나 '운영자'로 바꿀 수 있으므로 이 값만이
  /// 진짜 운영자라는 근거다. 화면은 반드시 이 값으로 배지를 판단한다.
  final bool isAdmin;

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'].toString(),
    userId: json['user_id'] as String,
    nickname: json['nickname'] as String? ?? '',
    body: json['body'] as String? ?? '',
    createdAt: DateTime.parse(json['created_at'] as String).toUtc(),
    // 컬럼이 없는 서버(구버전 스키마)에서도 안전하게 false 로 읽는다.
    isAdmin: json['is_admin'] == true,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'nickname': nickname,
    'body': body,
    'created_at': createdAt.toUtc().toIso8601String(),
    'is_admin': isAdmin,
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
    this.reservedNames = const [],
  });

  /// 금칙어(소문자·공백제거 기준으로 비교).
  final List<String> bannedWords;

  final int maxLength;

  /// 연속 전송 최소 간격(초) — 도배 방지.
  final int minIntervalSeconds;

  /// 화면에 유지할 최근 메시지 수.
  final int historyLimit;

  final String maskChar;

  /// 운영자 사칭 금지 이름(부분 일치). 수치가 아니라 정책이라 JSON(chat.json)에 둔다.
  final List<String> reservedNames;

  factory ChatRules.fromJson(Map<String, dynamic> json) => ChatRules(
    bannedWords: [
      for (final w in (json['bannedWords'] as List? ?? const []))
        (w as String).toLowerCase(),
    ],
    maxLength: (json['maxLength'] as num?)?.toInt() ?? 100,
    minIntervalSeconds: (json['minIntervalSeconds'] as num?)?.toInt() ?? 3,
    historyLimit: (json['historyLimit'] as num?)?.toInt() ?? 50,
    maskChar: json['maskChar'] as String? ?? '*',
    reservedNames: [
      for (final w in (json['reservedNames'] as List? ?? const []))
        (w as String).toLowerCase(),
    ],
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

  /// 운영자를 사칭하는 이름인지.
  ///
  /// 채팅의 운영자 표시는 DB 의 `is_admin` 이 근거지만, **닉네임 자체가
  /// '운영자'면 유저는 배지를 보지 않고 이름만 보고 믿는다.** 그래서 이름
  /// 단계에서 막는다. 부분 일치로 본다 — '운영자입니다' 같은 우회를 막기 위해.
  bool isReservedName(String name) {
    if (reservedNames.isEmpty) return false;
    final n = normalize(name);
    for (final w in reservedNames) {
      if (w.isEmpty) continue;
      if (n.contains(normalize(w))) return true;
    }
    return false;
  }

  /// 닉네임으로 쓸 수 있는지. 채팅과 **같은 금칙어 목록**을 공유한다
  /// (닉네임은 랭킹·스카우트·채팅에 그대로 노출되므로 기준이 같아야 한다).
  bool nicknameAllowed(String name) =>
      name.trim().isNotEmpty && !hasBannedWord(name) && !isReservedName(name);

  /// 표시용 닉네임. 금칙어가 든 이름은 [fallback] 으로 대체한다.
  ///
  /// 이미 서버에 등록된 이름은 되돌릴 수 없으므로 **보여줄 때 가린다**.
  /// 별표 대신 중립적인 이름을 쓰는 이유: 별표는 오히려 눈에 띄어
  /// "무슨 말이었을까" 하는 관심을 끈다.
  ///
  /// [isAdmin] 이 true 면 **그대로 둔다** — 진짜 운영자 메시지까지 가리면
  /// 안 되기 때문이다. 이 값은 서버만 세울 수 있으므로 우회할 수 없다.
  String maskNickname(
    String name, {
    String fallback = '이용자',
    bool isAdmin = false,
  }) {
    if (isAdmin) return name;
    return (hasBannedWord(name) || isReservedName(name)) ? fallback : name;
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

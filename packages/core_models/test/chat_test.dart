import 'package:core_models/core_models.dart';
import 'package:test/test.dart';

void main() {
  // 실제 금칙어 대신 검사용 더미 단어로 로직만 확인한다.
  final rules = ChatRules.fromJson({
    'bannedWords': ['금칙', 'badword'],
    'maxLength': 20,
    'minIntervalSeconds': 3,
  });

  group('금칙어 필터', () {
    test('금칙어가 없으면 통과', () {
      expect(rules.hasBannedWord('안녕하세요 반갑습니다'), isFalse);
      expect(rules.check('안녕하세요'), ChatCheckResult.ok);
    });

    test('금칙어가 있으면 차단', () {
      expect(rules.hasBannedWord('이건 금칙 이야'), isTrue);
      expect(rules.check('이건 금칙 이야'), ChatCheckResult.blocked);
    });

    test('사이를 띄워 피하려는 시도도 잡는다', () {
      // 정규화(공백·구두점 제거) 덕분에 걸러져야 한다.
      expect(rules.hasBannedWord('금 칙'), isTrue);
      expect(rules.hasBannedWord('금.칙'), isTrue);
      expect(rules.hasBannedWord('금-칙'), isTrue);
      expect(rules.hasBannedWord('b a d w o r d'), isTrue);
    });

    test('대소문자를 가리지 않는다', () {
      expect(rules.hasBannedWord('BadWord'), isTrue);
      expect(rules.hasBannedWord('BADWORD'), isTrue);
    });

    test('목록이 비면 아무것도 막지 않는다', () {
      const empty = ChatRules();
      expect(empty.hasBannedWord('무슨 말이든'), isFalse);
    });
  });

  group('전송 검사', () {
    test('빈 문자열·공백만은 거부', () {
      expect(rules.check(''), ChatCheckResult.empty);
      expect(rules.check('   '), ChatCheckResult.empty);
    });

    test('길이 초과는 거부', () {
      expect(rules.check('가' * 21), ChatCheckResult.tooLong);
      expect(rules.check('가' * 20), ChatCheckResult.ok);
    });

    test('도배(최소 간격 미만)는 거부', () {
      final t0 = DateTime.utc(2026, 1, 1, 12, 0, 0);
      expect(
        rules.check(
          '안녕',
          lastSentAt: t0,
          now: t0.add(const Duration(seconds: 1)),
        ),
        ChatCheckResult.tooFast,
      );
      expect(
        rules.check(
          '안녕',
          lastSentAt: t0,
          now: t0.add(const Duration(seconds: 3)),
        ),
        ChatCheckResult.ok,
      );
    });

    test('첫 전송(lastSentAt 없음)은 간격 검사를 하지 않는다', () {
      expect(rules.check('안녕'), ChatCheckResult.ok);
    });

    test('금칙어 검사가 도배 검사보다 먼저다', () {
      // 둘 다 위반이면 더 무거운 사유(차단)를 돌려줘야 한다.
      final t0 = DateTime.utc(2026, 1, 1);
      expect(
        rules.check('금칙', lastSentAt: t0, now: t0),
        ChatCheckResult.blocked,
      );
    });
  });

  group('표시용 마스킹', () {
    test('금칙어가 있으면 가린다', () {
      expect(rules.mask('금칙'), '**');
      expect(rules.mask('깨끗한 문장'), '깨끗한 문장');
    });

    test('마스킹 길이는 상한을 넘지 않는다', () {
      expect(rules.mask('금칙' * 50).length, lessThanOrEqualTo(20));
    });
  });

  group('닉네임 필터', () {
    test('깨끗한 닉네임은 허용', () {
      expect(rules.nicknameAllowed('채집가'), isTrue);
      expect(rules.maskNickname('채집가'), '채집가');
    });

    test('금칙어가 든 닉네임은 거부', () {
      expect(rules.nicknameAllowed('금칙왕'), isFalse);
      expect(rules.nicknameAllowed('badword123'), isFalse);
    });

    test('빈 닉네임은 거부', () {
      expect(rules.nicknameAllowed(''), isFalse);
      expect(rules.nicknameAllowed('   '), isFalse);
    });

    test('이미 등록된 부적절한 닉네임은 표시할 때 대체된다', () {
      expect(rules.maskNickname('금칙왕'), '이용자');
      expect(rules.maskNickname('금칙왕', fallback: 'Player'), 'Player');
    });

    test('닉네임도 띄어쓰기 우회를 잡는다', () {
      expect(rules.nicknameAllowed('금 칙'), isFalse);
    });
  });

  group('메시지 직렬화', () {
    test('왕복해도 값이 보존된다', () {
      final m = ChatMessage(
        id: '42',
        userId: 'u-1',
        nickname: '채집가',
        body: '안녕하세요',
        createdAt: DateTime.utc(2026, 7, 20, 12, 30),
      );
      final back = ChatMessage.fromJson(m.toJson());
      expect(back.id, '42');
      expect(back.userId, 'u-1');
      expect(back.nickname, '채집가');
      expect(back.body, '안녕하세요');
      expect(back.createdAt, m.createdAt);
    });

    test('서버가 id 를 숫자로 줘도 문자열로 받는다', () {
      final m = ChatMessage.fromJson({
        'id': 7,
        'user_id': 'u-2',
        'nickname': 'a',
        'body': 'b',
        'created_at': '2026-07-20T00:00:00Z',
      });
      expect(m.id, '7');
    });

    test('is_admin 이 없는 서버 응답은 false 로 읽는다(구버전 스키마 호환)', () {
      final m = ChatMessage.fromJson({
        'id': 7,
        'user_id': 'u-2',
        'nickname': 'a',
        'body': 'b',
        'created_at': '2026-07-20T00:00:00Z',
      });
      expect(m.isAdmin, isFalse);
      final admin = ChatMessage.fromJson({
        'id': 8,
        'user_id': 'u-3',
        'nickname': '운영자',
        'body': '점검 안내',
        'created_at': '2026-07-20T00:00:00Z',
        'is_admin': true,
      });
      expect(admin.isAdmin, isTrue);
    });
  });

  group('운영자 사칭 방지', () {
    const rules = ChatRules(
      reservedNames: ['운영자', 'gm', 'admin'],
      bannedWords: ['욕설'],
    );

    test('예약된 이름은 닉네임으로 쓸 수 없다', () {
      expect(rules.nicknameAllowed('운영자'), isFalse);
      expect(rules.nicknameAllowed('GM김씨'), isFalse);
      // 부분 일치·띄어쓰기 우회도 막는다.
      expect(rules.nicknameAllowed('운 영 자 입니다'), isFalse);
      expect(rules.nicknameAllowed('ADMIN_2'), isFalse);
      // 평범한 이름은 통과.
      expect(rules.nicknameAllowed('풍뎅이왕'), isTrue);
    });

    test('이미 등록된 사칭 이름은 표시 단계에서 가린다', () {
      expect(rules.maskNickname('운영자', fallback: '이용자'), '이용자');
      expect(rules.maskNickname('욕설맨', fallback: '이용자'), '이용자');
      expect(rules.maskNickname('풍뎅이왕', fallback: '이용자'), '풍뎅이왕');
    });

    test('진짜 운영자 메시지는 가리지 않는다', () {
      // is_admin 은 서버(service_role)만 세울 수 있으므로 우회 불가.
      expect(rules.maskNickname('운영자', fallback: '이용자', isAdmin: true), '운영자');
    });

    test('예약어 목록이 비면 아무것도 막지 않는다(설정 누락 시 기존 동작)', () {
      const empty = ChatRules();
      expect(empty.isReservedName('운영자'), isFalse);
      expect(empty.nicknameAllowed('운영자'), isTrue);
    });
  });
}

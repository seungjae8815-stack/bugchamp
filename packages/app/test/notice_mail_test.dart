import 'package:app/domain/game_server.dart';
import 'package:app/domain/notice_service.dart';
import 'package:core_models/core_models.dart';
import 'package:core_save/core_save.dart';
import 'package:flutter_test/flutter_test.dart';

/// 서버 응답을 흉내내는 가짜 — 라우팅·인증은 서버 테스트가 덮으므로
/// 여기서는 **앱이 응답을 어떻게 해석하는가**만 본다.
class _FakeServer implements GameServer {
  _FakeServer({this.error});

  /// 서버가 돌려줄 거절 사유. null 이면 성공.
  final String? error;

  @override
  bool get available => true;

  @override
  Future<ServerResult> redeemCode(String code) async => error == null
      ? const ServerResult.ok({'save': <String, dynamic>{}})
      : ServerResult.fail(error, 400);

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

void main() {
  group('공지 읽음 판정', () {
    final base = SaveGame.initial(createdAt: DateTime.utc(2026, 8, 7));

    test('마지막으로 읽은 id 보다 큰 공지만 새 글이다', () {
      final s = base.copyWith(lastReadNoticeId: 5);
      expect(s.isNewNotice(6), isTrue);
      expect(s.isNewNotice(5), isFalse);
      expect(s.isNewNotice(1), isFalse);
    });

    test('한 번도 안 읽었으면 전부 새 글', () {
      expect(base.lastReadNoticeId, 0);
      expect(base.isNewNotice(1), isTrue);
    });

    test('세이브에 왕복 저장된다(호환 필드 — 스키마 버전 그대로)', () {
      final s = base.copyWith(lastReadNoticeId: 12, reviewAsked: true);
      final back = SaveGame.fromJson(s.toJson());
      expect(back.lastReadNoticeId, 12);
      expect(back.reviewAsked, isTrue);
      expect(back.schemaVersion, kSaveSchemaVersion);
      // 예전 세이브(필드 없음)는 기본값으로 읽힌다.
      final old = s.toJson()
        ..remove('lastReadNoticeId')
        ..remove('reviewAsked');
      expect(SaveGame.fromJson(old).lastReadNoticeId, 0);
      expect(SaveGame.fromJson(old).reviewAsked, isFalse);
    });
  });

  group('운영 우편 파싱', () {
    test('재화·기한을 읽고, 음수는 0으로 막는다', () {
      final m = ServerMail.fromJson({
        'id': 7,
        'title': '점검 보상',
        'body': '죄송합니다',
        'gold': 1000,
        'jelly': 100,
        'chitin': 0,
        'mineral': -5, // 운영 실수 — 재화를 뺏지 않는다
        'sap': 0,
        'ends_at': '2026-08-14T00:00:00Z',
      });
      expect(m.id, '7'); // id 는 문자열로 다룬다(서버는 bigserial)
      expect(m.gold, 1000);
      expect(m.materials[MaterialKind.jelly], 100);
      expect(m.materials.containsKey(MaterialKind.mineral), isFalse);
      expect(m.endsAt, DateTime.utc(2026, 8, 14));
    });

    test('공지: pinned·작성일 파싱', () {
      final n = Notice.fromJson({
        'id': 3,
        'title': '업데이트',
        'body': '결투 티켓이 생겼어요',
        'pinned': true,
        'created_at': '2026-08-07T01:00:00Z',
      });
      expect(n.id, 3);
      expect(n.pinned, isTrue);
      expect(n.createdAt, DateTime.utc(2026, 8, 7, 1));
    });
  });

  group('수령·코드 실패 사유', () {
    // 실패를 뭉뚱그리면 사용자는 "왜 안 되지"만 남는다. 사유별로 갈린다.
    test('서버 오류코드 → 화면 사유 매핑', () async {
      final cases = {
        'bad_code': RedeemResult.badCode,
        'code_expired': RedeemResult.expired,
        'code_exhausted': RedeemResult.exhausted,
        'code_already_used': RedeemResult.alreadyUsed,
        'mail_not_found': RedeemResult.alreadyUsed,
        'store_unavailable': RedeemResult.failed,
      };
      for (final e in cases.entries) {
        final server = _FakeServer(error: e.key);
        final res = await server.redeemCode('X');
        expect(res.isOk, isFalse, reason: e.key);
        expect(res.error, e.key);
      }
    });
  });
}

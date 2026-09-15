import 'package:server/src/support.dart';
import 'package:server/src/telegram_admin.dart';
import 'package:test/test.dart';

void main() {
  test('명령 분리 — 봇 이름 붙은 명령도', () {
    expect(splitCommand('/Mail@bugchamp_bot a | b').name, 'mail');
    expect(splitCommand('/mail a | b').rest, 'a | b');
    expect(splitCommand('/help').rest, '');
    expect(splitPipe('a | | c '), ['a', '', 'c']);
  });

  test('보상 해석 — 단위·쉼표·영문', () {
    final r = parseReward('젤리 100 골드 5만 키틴 1.5천 mineral 2k 수액 1,000');
    expect(r.unknown, isEmpty);
    expect(r.reward, {
      'jelly': 100,
      'gold': 50000,
      'chitin': 1500,
      'mineral': 2000,
      'sap': 1000,
    });
    expect(parseReward('골드 1억').reward['gold'], 100000000);
  });

  test('보상 해석 — 모르는 단어는 조용히 넘기지 않는다', () {
    final r = parseReward('젤리리 100 골드 5만');
    expect(r.unknown, isNotEmpty);
    expect(r.reward['gold'], 50000);
  });

  test('보상 요약·채팅 서식', () {
    expect(rewardLabel({'jelly': 100, 'gold': 50000}), '골드 5만 · 젤리 100');
    expect(rewardLabel({}), '보상 없음');
    expect(rewardLabel({'gold': 15000}), '골드 1.5만');
    final text = formatChat([
      {
        'id': 2,
        'nickname': '나중',
        'body': '둘',
        'created_at': '2026-09-15T01:05:00Z',
      },
      {
        'id': 1,
        'nickname': '먼저',
        'body': '하나',
        'created_at': '2026-09-15T01:00:00Z',
        'is_admin': true,
      },
    ]);
    expect(
      text.indexOf('#1'),
      lessThan(text.indexOf('#2')),
      reason: '오래된 글이 위',
    );
    expect(text, contains('#1 10:00 📢먼저: 하나'));
  });

  test('긴 글은 텔레그램 한도 안으로 줄 단위로 나눈다', () {
    final long = List.generate(400, (i) => '줄 $i ${'가' * 20}').join('\n');
    final parts = chunkTelegram(long);
    expect(parts.length, greaterThan(1));
    for (final p in parts) {
      expect(p.length, lessThanOrEqualTo(3900));
    }
    expect(parts.join('\n'), long);
  });
}

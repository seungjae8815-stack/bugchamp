import 'package:app/domain/notice_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// 언어별 공지(2026-10-03): 기기 언어 글 → (일본어면) 영어 → 한국어 순으로 대체.
void main() {
  final row = <String, dynamic>{
    'id': 7,
    'title': '요정이 왔어요',
    'body': '한국어 본문',
    'title_en': 'Fairies are here',
    'body_en': 'English body',
    'title_ja': '',
    'body_ja': null,
    'pinned': true,
  };

  test('한국어 기기는 한국어', () {
    final n = Notice.fromJson(row, lang: 'ko');
    expect(n.title, '요정이 왔어요');
    expect(n.body, '한국어 본문');
  });

  test('영어 기기는 영어', () {
    final n = Notice.fromJson(row, lang: 'en');
    expect(n.title, 'Fairies are here');
    expect(n.body, 'English body');
  });

  test('일본어가 비어 있으면 영어로', () {
    final n = Notice.fromJson(row, lang: 'ja');
    expect(n.title, 'Fairies are here');
    expect(n.body, 'English body');
  });

  test('일본어가 있으면 일본어', () {
    final n = Notice.fromJson({
      ...row,
      'title_ja': '妖精がやってきた',
      'body_ja': '日本語',
    }, lang: 'ja');
    expect(n.title, '妖精がやってきた');
    expect(n.body, '日本語');
  });

  test('언어 칸이 없는 옛 서버 응답은 한국어', () {
    final n = Notice.fromJson({
      'id': 1,
      'title': '옛 공지',
      'body': '본문',
    }, lang: 'ja');
    expect(n.title, '옛 공지');
    expect(n.body, '본문');
    expect(n.pinned, isFalse);
  });

  test('그 밖의 언어(독일어 등)는 영어 → 한국어', () {
    expect(Notice.fromJson(row, lang: 'de').title, 'Fairies are here');
    expect(
      Notice.fromJson({'id': 2, 'title': '한국어만'}, lang: 'de').title,
      '한국어만',
    );
  });
}

import 'package:app/ui/format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('한글이 낀 글자 사이에만 단어 결합자 · 띄어쓰기·영어는 그대로 · 두 번 써도 같다', () {
    expect(keepWords('전투력 상위'), '전\u2060투\u2060력 상\u2060위');
    expect(keepWords('11월'), '11\u2060월');
    expect(keepWords('Lv.10 hp'), 'Lv.10 hp');
    expect(keepWords(keepWords('소모돼요(채집함')), keepWords('소모돼요(채집함'));
    expect(keepWords(''), '');
    expect(noBreak('젤리 50'), '젤리\u00A050');
  });
}

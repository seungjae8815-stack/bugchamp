import 'package:app/ui/art.dart';
import 'package:core_models/core_models.dart';
import 'package:flutter_test/flutter_test.dart';

const _b = 'assets/images/bugs/';

void main() {
  test('암컷 pose 2: 암컷 경로 셋이 맨 앞, 그 뒤가 수컷 사슬', () {
    final f = adultImagePaths('stag_giant', pose: 2, sex: Sex.female);
    final m = adultImagePaths('stag_giant', pose: 2);
    expect(f.take(3), [
      '${_b}stag_giant_female_adult_2.webp',
      '${_b}stag_giant_female_adult_1.webp',
      '${_b}stag_giant_female_adult.webp',
    ]);
    expect(f.skip(3), m);
  });

  test('수컷 pose 2: 기존 사슬 그대로', () {
    final m = adultImagePaths('stag_giant', pose: 2);
    expect(m, [
      '${_b}stag_giant_adult_2.webp',
      '${_b}stag_giant_adult_2.png',
      '${_b}stag_giant_adult_1.webp',
      '${_b}stag_giant_adult_1.png',
      '${_b}stag_giant_adult.webp',
      '${_b}stag_giant_adult.png',
      '${_b}stag_giant.webp',
      '${_b}stag_giant.png',
    ]);
  });

  test('수컷 + 스킨: 스킨 경로가 맨 앞', () {
    final m = adultImagePaths('stag_giant', pose: 2, skin: 'albino');
    expect(m.first, '${_b}stag_giant_adult_2_albino.webp');
    expect(m[1], '${_b}stag_giant_adult_1_albino.webp');
    expect(m.skip(2), adultImagePaths('stag_giant', pose: 2));
  });

  test('암컷 + 스킨: 암컷 경로가 스킨 경로보다 앞', () {
    final f = adultImagePaths(
      'stag_giant',
      pose: 2,
      sex: Sex.female,
      skin: 'albino',
    );
    final iFemale = f.indexOf('${_b}stag_giant_female_adult.webp');
    final iSkin = f.indexOf('${_b}stag_giant_adult_2_albino.webp');
    expect(iFemale, 2);
    expect(iSkin, greaterThan(iFemale));
  });

  test('pose 없음(대기·생애주기) 암컷: _1, 기본 다음에 수컷 사슬', () {
    final f = adultImagePaths('stag_giant', sex: Sex.female);
    expect(f.take(2), [
      '${_b}stag_giant_female_adult_1.webp',
      '${_b}stag_giant_female_adult.webp',
    ]);
    expect(f.skip(2), adultImagePaths('stag_giant'));
    expect(adultImagePaths('stag_giant').first, '${_b}stag_giant_adult.webp');
  });
}

import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:test/test.dart';

void main() {
  group('지역 오행 속성', () {
    test('JSON 에 적힌 속성을 읽는다', () {
      final r = RegionConfig.fromJson({
        'id': 'oak_forest',
        'name': {'ko': '참나무 숲', 'en': 'Oak Forest', 'ja': 'ナラの森'},
        'bossName': {'ko': '숲지기', 'en': 'Forest Warden', 'ja': '森の主'},
        'habitatKinds': ['tree'],
        'element': 'wood',
      });
      expect(r.element, Element.wood);
    });

    test('속성이 없으면 null — 무속성 지역이 되고 상극이 안 걸린다', () {
      // 여기서 던지면 구버전 JSON 을 얹은 앱이 로딩에서 죽는다.
      final r = RegionConfig.fromJson({
        'id': 'grass_field',
        'name': {'ko': '풀밭', 'en': 'Grassland', 'ja': '草原'},
        'bossName': {'ko': '들풀왕', 'en': 'Meadow King', 'ja': '草原の王'},
        'habitatKinds': ['flower'],
      });
      expect(r.element, isNull);
    });
  });
}

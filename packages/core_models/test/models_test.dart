import 'package:core_models/core_models.dart';
import 'package:test/test.dart';

void main() {
  group('Species.fromJson', () {
    final json = {
      'id': 'hercules_beetle',
      'name': {'ko': '헤라클레스장수풍뎅이', 'en': 'Hercules Beetle', 'ja': 'ヘラクレスオオカブト'},
      'grade': 'legendary',
      'specialty': 'toss',
      'baseStats': {'hp': 150, 'atk': 60, 'def': 45, 'spd': 25},
      'sizeMinMm': 50.0,
      'sizeMaxMm': 180.0,
    };

    test('필드 파싱', () {
      final s = Species.fromJson(json);
      expect(s.id, 'hercules_beetle');
      expect(s.grade, Grade.legendary);
      expect(s.specialty, Specialty.toss);
      expect(s.baseStats.hp, 150);
      expect(s.sizeMaxMm, 180.0);
      expect(s.name.resolve('ja'), 'ヘラクレスオオカブト');
      expect(s.name.resolve('en'), 'Hercules Beetle');
      expect(s.name.resolve('fr'), 'Hercules Beetle'); // 미지원 → en 폴백
    });

    test('toJson 왕복', () {
      final s = Species.fromJson(json);
      expect(Species.fromJson(s.toJson()).toJson(), s.toJson());
    });

    test('알 수 없는 enum 키는 예외', () {
      final bad = Map<String, dynamic>.from(json)..['grade'] = 'mythic';
      expect(() => Species.fromJson(bad), throwsArgumentError);
    });
  });

  group('Specialty 상성 (치기>집기>던지기>치기)', () {
    test('strike > grip > toss > strike', () {
      expect(Specialty.strike.beats(Specialty.grip), isTrue);
      expect(Specialty.grip.beats(Specialty.toss), isTrue);
      expect(Specialty.toss.beats(Specialty.strike), isTrue);
    });

    test('역방향/동일은 이기지 못함', () {
      expect(Specialty.grip.beats(Specialty.strike), isFalse);
      expect(Specialty.strike.beats(Specialty.strike), isFalse);
      expect(Specialty.strike.beats(Specialty.toss), isFalse);
    });
  });

  group('Stats', () {
    test('scaled 반올림', () {
      const s = Stats(hp: 100, atk: 41, def: 30, spd: 20);
      final x = s.scaled(1.20);
      expect(x.hp, 120);
      expect(x.atk, 49); // 41*1.2=49.2 → 49
    });

    test('덧셈', () {
      const a = Stats(hp: 1, atk: 2, def: 3, spd: 4);
      const b = Stats(hp: 10, atk: 20, def: 30, spd: 40);
      expect(a + b, const Stats(hp: 11, atk: 22, def: 33, spd: 44));
    });
  });

  group('PartLevels', () {
    test('total 합산 및 copyWith', () {
      const p = PartLevels(hornJaw: 2, cuticle: 3, wing: 1, build: 4);
      expect(p.total, 10);
      expect(p.copyWith(wing: 5).total, 14);
    });

    test('JSON 왕복 + 누락 필드 기본 0', () {
      expect(PartLevels.fromJson({'hornJaw': 3}), const PartLevels(hornJaw: 3));
      const p = PartLevels(hornJaw: 1, cuticle: 2, wing: 3, build: 4);
      expect(PartLevels.fromJson(p.toJson()), p);
    });
  });

  group('MaterialStack', () {
    test('같은 종류 합산', () {
      const a = MaterialStack(kind: MaterialKind.jelly, amount: 3);
      const b = MaterialStack(kind: MaterialKind.jelly, amount: 5);
      expect((a + b).amount, 8);
    });

    test('JSON 왕복', () {
      const m = MaterialStack(kind: MaterialKind.chitin, amount: 12);
      expect(MaterialStack.fromJson(m.toJson()), m);
    });
  });

  group('Trap / Field', () {
    test('Trap 기본 yieldMultiplier=1.0 및 왕복', () {
      final t = Trap.fromJson({
        'id': 'sap_trap',
        'name': {'ko': '수액 트랩', 'en': 'Sap Trap', 'ja': '樹液トラップ'},
      });
      expect(t.yieldMultiplier, 1.0);
      expect(Trap.fromJson(t.toJson()).id, 'sap_trap');
    });

    test('Field unlockOrder 파싱', () {
      final f = Field.fromJson({
        'id': 'oak_forest',
        'name': {'ko': '참나무 숲', 'en': 'Oak Forest', 'ja': 'ナラの森'},
        'unlockOrder': 0,
      });
      expect(f.unlockOrder, 0);
      expect(f.name.resolve('ko'), '참나무 숲');
    });
  });
}

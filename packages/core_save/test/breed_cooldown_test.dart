import 'package:core_save/core_save.dart';
import 'package:test/test.dart';

/// 짝짓기 텀(§2.5)의 **세이브 쪽 계약**.
///
/// 부모는 짝짓기 중에도 잠기지 않으므로(스냅샷 저장), 텀이 없으면 잘 뽑힌 한 쌍으로
/// 같은 급 자식을 슬롯이 도는 속도만큼 계속 찍어낼 수 있다. 그 텀을 저장하는 필드다.
///
/// 스키마 버전을 올리지 않는 **호환 필드**라, 비어 있을 때는 JSON 에 아예 실리지
/// 않아야 한다 — 구버전 앱이 읽어도 아무 일이 없어야 하고, 세이브 크기도 늘지 않는다.
void main() {
  final t0 = DateTime.utc(2026, 8, 16, 12);

  test('기본값은 비어 있고, JSON 에도 실리지 않는다', () {
    final s = SaveGame.initial(createdAt: t0);
    expect(s.breedCooldowns, isEmpty);
    expect(s.toJson().containsKey('breedCooldowns'), isFalse);
  });

  test('왕복(toJson → fromJson)에서 시각이 유지된다', () {
    final until = t0.add(const Duration(hours: 5, minutes: 20));
    final s = SaveGame.initial(
      createdAt: t0,
    ).copyWith(breedCooldowns: {'mom': until, 'dad': until});
    final back = SaveGame.fromJson(s.toJson());
    expect(back.breedCooldowns.length, 2);
    expect(back.breedCooldowns['mom'], until);
  });

  test('breedOnCooldown — 지난 시각은 더 이상 막지 않는다', () {
    final s = SaveGame.initial(createdAt: t0).copyWith(
      breedCooldowns: {
        'waiting': t0.add(const Duration(hours: 1)),
        'done': t0.subtract(const Duration(minutes: 1)),
      },
    );
    expect(s.breedOnCooldown('waiting', t0), isTrue);
    expect(s.breedOnCooldown('done', t0), isFalse);
    expect(s.breedOnCooldown('never-bred', t0), isFalse);
  });

  test('prunedBreedCooldowns — 만료된 것만 걷어낸다(세이브 크기 방어)', () {
    final alive = t0.add(const Duration(hours: 2));
    final s = SaveGame.initial(createdAt: t0).copyWith(
      breedCooldowns: {
        'a': alive,
        'b': t0.subtract(const Duration(days: 3)),
        'c': t0, // 딱 지금 = 이미 끝난 것으로 본다
      },
    );
    final pruned = s.prunedBreedCooldowns(t0);
    expect(pruned.keys, ['a']);
    expect(pruned['a'], alive);
    // 원본은 그대로 — 새 맵을 돌려준다.
    expect(s.breedCooldowns.length, 3);
  });
}

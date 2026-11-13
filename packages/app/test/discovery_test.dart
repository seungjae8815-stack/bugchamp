import 'package:app/domain/discovery.dart';
import 'package:core_save/core_save.dart';
import 'package:flutter_test/flutter_test.dart';

/// 새 곤충 발견 연출(2026-11-09) — 도감 직전·직후 비교로 새 종·첫 이색을 찾는다.
void main() {
  test('새 종은 발견 · 이미 있던 종의 크기 기록 갱신은 발견이 아니다', () {
    final before = {'a': const DexEntry(maxSizeMm: 30)};
    final after = {
      'a': const DexEntry(maxSizeMm: 50),
      'b': const DexEntry(maxSizeMm: 20),
    };
    expect(dexDiscoveries(before, after), [
      (speciesId: 'b', newSpecies: true, variant: false),
    ]);
  });

  test('이미 있던 종의 첫 이색은 따로 · 새 종이 이색으로 오면 한 건', () {
    final before = {'a': const DexEntry()};
    final after = {
      'a': const DexEntry(variantFound: true),
      'c': const DexEntry(variantFound: true),
    };
    expect(dexDiscoveries(before, after), [
      (speciesId: 'a', newSpecies: false, variant: true),
      (speciesId: 'c', newSpecies: true, variant: true),
    ]);
  });

  test('대기열은 하나씩 꺼낸다', () {
    final feed = DiscoveryFeed.instance;
    while (feed.take() != null) {}
    feed.addAll([
      (speciesId: 'x', newSpecies: true, variant: false),
      (speciesId: 'y', newSpecies: true, variant: false),
    ]);
    expect(feed.take()?.speciesId, 'x');
    expect(feed.take()?.speciesId, 'y');
    expect(feed.take(), isNull);
  });
}

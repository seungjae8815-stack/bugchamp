import 'package:core_run/core_run.dart';
import 'package:test/test.dart';

void main() {
  test('문장 번호는 1~10 만 유효하다', () {
    expect(guildEmblemValid(0), isFalse);
    expect(guildEmblemValid(1), isTrue);
    expect(guildEmblemValid(kGuildEmblemCount), isTrue);
    expect(guildEmblemValid(kGuildEmblemCount + 1), isFalse);
  });

  test('기본 문장 — 같은 id 는 늘 같은 값 · 범위 안 · 고정값(플랫폼 독립)', () {
    const id = '3f2b8c1e-0000-4000-8000-000000000001';
    final e = guildDefaultEmblem(id);
    expect(e, guildDefaultEmblem(id));
    expect(guildEmblemValid(e), isTrue);
    // 해시 공식이 바뀌면 옛 길드 문장이 바뀐다 — 값을 못 박아 둔다.
    expect(guildDefaultEmblem(''), 1);
    expect(guildDefaultEmblem('g1'), (103 * 31 + 49) % 10 + 1);
    final seen = {for (var i = 0; i < 200; i++) guildDefaultEmblem('guild-$i')};
    expect(seen.length, kGuildEmblemCount, reason: '10장이 고르게 나와야 한다');
  });

  test('고른 문장이 있으면 그것, 없거나 범위 밖이면 기본', () {
    expect(guildEmblemOf('g1', 7), 7);
    expect(guildEmblemOf('g1', null), guildDefaultEmblem('g1'));
    expect(guildEmblemOf('g1', 11), guildDefaultEmblem('g1'));
  });
}

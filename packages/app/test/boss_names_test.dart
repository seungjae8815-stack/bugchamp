import 'dart:convert';
import 'dart:io';

import 'package:core_run/core_run.dart';
import 'package:flutter_test/flutter_test.dart';

/// 보스 이름표(roadmap.json → bosses)가 **그림 id 와 정확히 짝**인지 본다.
///
/// 키가 하나라도 어긋나면 화면은 조용히 옛 챕터 이름으로 폴백한다 — 빌드도
/// 테스트도 통과하고 사람 눈에만 보인다. 그래서 여기서 막는다.
void main() {
  Map<String, dynamic> read(String name) =>
      jsonDecode(File('assets/data/$name').readAsStringSync())
          as Map<String, dynamic>;

  test('보스 44마리 이름·설명이 그림 id 와 1:1 로 맞는다', () {
    final run = RunConfig.fromJson(read('run_config.json'));
    final roadmap = RoadmapConfig.fromJson(read('roadmap.json'));
    expect(run.zoneMode, isTrue, reason: '사냥터 구조가 꺼지면 이 검사의 전제가 깨진다');

    final wanted = <String>{
      for (var tier = 0; tier < 4; tier++)
        for (var zone = 1; zone <= run.zonesPerTier; zone++)
          run.bossArtId(tier, zone),
    };
    expect(wanted.length, 44);
    expect(
      roadmap.bosses.keys.toSet(),
      wanted,
      reason: '이름표 키 = 그림 id. 남거나 모자라면 그 보스만 이름이 사라진다',
    );

    for (final id in wanted) {
      final info = roadmap.boss(id)!;
      expect(info.name.resolve('ko'), isNotEmpty, reason: '$id 이름');
      expect(info.desc.resolve('ko'), isNotEmpty, reason: '$id 설명');
      // 그림 파일도 여섯 장이 다 있어야 한다(대기·공격2·피격·죽음2).
      for (final suffix in [
        '',
        '_attack_1',
        '_attack_2',
        '_hurt_1',
        '_death_1',
        '_death_2',
      ]) {
        expect(
          File('assets/images/bosses/$id$suffix.webp').existsSync(),
          isTrue,
          reason: '$id$suffix.webp 없음',
        );
      }
    }
  });

  test('이름이 서로 겹치지 않는다 — 44마리가 다 다른 보스다', () {
    final roadmap = RoadmapConfig.fromJson(read('roadmap.json'));
    final names = roadmap.bosses.values
        .map((b) => b.name.resolve('ko'))
        .toList();
    expect(names.toSet().length, names.length);
  });
}

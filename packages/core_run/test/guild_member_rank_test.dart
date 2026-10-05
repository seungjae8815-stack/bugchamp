import 'dart:convert';
import 'dart:io';

import 'package:core_run/core_run.dart';
import 'package:test/test.dart';

void main() {
  final cfg = GuildConfig.fromJson(
    jsonDecode(File('../app/assets/data/guild.json').readAsStringSync())
        as Map<String, dynamic>,
  );

  test('실데이터 — 등급 4단계 새내기 0 · 일꾼 500 · 정예 3000 · 원로 10000', () {
    expect(
      [for (final r in cfg.memberRanks) '${r.id}:${r.min}'],
      ['rookie:0', 'worker:500', 'elite:3000', 'elder:10000'],
    );
  });

  test('기여도 → 지금 등급과 다음 등급(경계 포함)', () {
    String at(int c) {
      final r = guildMemberRank(cfg.memberRanks, c);
      return '${r.rank.id}>${r.next?.id}';
    }

    expect(at(0), 'rookie>worker');
    expect(at(499), 'rookie>worker');
    expect(at(500), 'worker>elite');
    expect(at(2999), 'worker>elite');
    expect(at(3000), 'elite>elder');
    expect(at(10000), 'elder>null');
    expect(at(999999), 'elder>null');
    expect(at(-5), 'rookie>worker'); // 음수는 첫 등급
  });

  test('순서가 섞여 있어도 · 비어 있으면 기본표', () {
    const shuffled = [
      GuildMemberRankDef('c', 300),
      GuildMemberRankDef('a', 0),
      GuildMemberRankDef('b', 100),
    ];
    expect(guildMemberRank(shuffled, 150).rank.id, 'b');
    expect(guildMemberRank(shuffled, 150).next?.id, 'c');
    expect(guildMemberRank(const [], 600).rank.id, 'worker');
    expect(GuildConfig.fromJson(const {}).memberRanks, hasLength(4));
  });

  test('직책 권한 — 길드장만 추방·설정·스킬·임명 · 부길드장 수락은 스위치', () {
    for (final r in GuildRole.values) {
      final leader = r == GuildRole.leader;
      expect(r.canKick, leader);
      expect(r.canEditSettings, leader);
      expect(r.canEditSkills, leader);
      expect(r.canAssignRoles, leader);
    }
    expect(GuildRole.leader.canAnswerRequests(deputyCanAccept: false), isTrue);
    expect(GuildRole.deputy.canAnswerRequests(deputyCanAccept: true), isTrue);
    expect(GuildRole.deputy.canAnswerRequests(deputyCanAccept: false), isFalse);
    expect(GuildRole.member.canAnswerRequests(deputyCanAccept: true), isFalse);
  });
}

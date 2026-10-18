import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:core_save/core_save.dart';
import 'package:test/test.dart';

// 놓친 능력치 굴리기(2026-10-16 사장님 확정, 1.0.22) — 업데이트 전 곤충은 등급마다 받지 못한 굴리기를 무료로.
void main() {
  final g = PetConfig.fromJson(
    jsonDecode(File('../app/assets/data/pets.json').readAsStringSync())
        as Map<String, dynamic>,
  ).individualGrade;
  final t0 = DateTime.utc(2026, 10, 16);

  IndividualBug bug({
    int pot = 5,
    bool ng = false,
    int su = 4,
    int? ls,
    int lru = 0,
  }) => IndividualBug(
    id: 'old',
    speciesId: 'stag_saw',
    sizeMm: 40,
    potential: pot,
    temperament: Temperament.cunning,
    sex: Sex.male,
    newGen: ng,
    synthUps: su,
    legacySynthUps: ls,
    legacyRollUps: lru,
  );

  test('놓친 횟수 = 등급 − 1 − 새 규칙으로 올린 단계 · 새 곤충은 0', () {
    expect(legacyMissedRolls(bug()), 4); // 옛 합성 5★
    expect(legacyMissedRolls(bug(pot: 5, su: 0)), 4); // 태생 5★
    expect(legacyMissedRolls(bug(pot: 5, su: 4, ls: 2)), 2); // 옛 2단계 + 새로 2번 올림
    expect(legacyMissedRolls(bug(ng: true)), 0);
    expect(legacyRollsLeft(bug(lru: 3)), 1);
  });

  test('굴리면 칸마다 내려가지 않고 · 횟수가 줄고 · 물약을 쓴다 · 다 쓰면 거절', () {
    var s = SaveGame.initial(
      createdAt: t0,
    ).copyWith(bugs: [bug()], growthPotions: 6);
    final rng = Random(1);
    for (var i = 0; i < 4; i++) {
      final before = s.bugs.single.statRolls;
      final r = legacyRollUp(s, 'old', g, rng, potions: i < 2 ? 3 : 0);
      expect(r.isOk, isTrue);
      s = r.save!;
      final after = s.bugs.single.statRolls;
      for (var k = 0; k < before.length; k++) {
        expect(after[k], greaterThanOrEqualTo(before[k]));
      }
    }
    expect(s.growthPotions, 0);
    expect(s.bugs.single.legacyRollUps, 4);
    expect(legacyRollUp(s, 'old', g, rng).error, 'none_left');
    // 롤이 저장되고, 서버 정리(sanitize)가 지우지 않는다(합성 단계 0 인 태생 5★ 도).
    final born5 = SaveGame.initial(createdAt: t0).copyWith(bugs: [bug(su: 0)]);
    final rolled = legacyRollUp(born5, 'old', g, rng).save!;
    expect(rolled.bugs.single.rolls, isNotNull);
    expect(sanitizeGradeRolls(rolled).bugs.single.rolls, isNotNull);
    // 저장 키 lru.
    expect(rolled.bugs.single.toJson()['lru'], 1);
  });

  test('롤 정리 — 놓친 굴리기가 없는 곤충에 lru 를 붙여도 롤은 지운다(새 곤충 만점 롤 구멍)', () {
    const full = [100, 100, 100, 100, 100, 100, 100, 100];
    final forged = SaveGame.initial(createdAt: t0).copyWith(
      bugs: [
        bug(ng: true, su: 0, pot: 1, lru: 1).copyWith(rolls: full),
        // 옛 곤충이라도 1성(놓친 굴리기 0)이면 같다.
        bug(pot: 1, su: 0, lru: 1).copyWith(rolls: full),
      ],
    );
    for (final b in sanitizeGradeRolls(forged).bugs) {
      expect(b.rolls, isNull);
    }
    // 놓친 굴리기가 있는 옛 곤충은 남긴다.
    final ok = SaveGame.initial(
      createdAt: t0,
    ).copyWith(bugs: [bug(pot: 3, su: 0, lru: 1).copyWith(rolls: full)]);
    expect(sanitizeGradeRolls(ok).bugs.single.rolls, full);
  });
}

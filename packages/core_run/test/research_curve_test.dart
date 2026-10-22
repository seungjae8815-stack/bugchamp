// 연구소 곡선 회귀 테스트(실데이터) — 사장님 요구 "터무니없는 값이 나오지 않게".
// 숫자는 tool/research_table.dart --fit 이 뽑는다(손으로 한 칸씩 고치지 않는다).
import 'dart:convert';
import 'dart:io';

import 'package:core_run/core_run.dart';
import 'package:test/test.dart';

import '../tool/research_table.dart';

Map<String, dynamic> _raw() =>
    jsonDecode(File('../app/assets/data/research.json').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  final raw = _raw();
  final c = ResearchConfig.fromJson(raw);

  test('한 레벨의 골드·재료는 하루 3시간(180분) 수입의 3배(540분)를 넘지 않는다', () {
    for (final d in c.defs) {
      for (var l = 1; l <= d.maxLevel; l++) {
        final cost = c.costAt(d, l);
        expect(cost.goldMinutes, lessThanOrEqualTo(540), reason: '${d.id} $l');
        expect(
          cost.materialMinutes,
          lessThanOrEqualTo(540),
          reason: '${d.id} $l',
        );
      }
    }
  });

  test('즉시 완료 젤리는 5 단위 · 한 레벨 최대 3,000', () {
    var top = 0;
    for (final d in c.defs) {
      for (var l = 1; l <= d.maxLevel; l++) {
        final j = c.instantJelly(c.timeAt(d, l));
        expect(j % 5, 0, reason: '${d.id} $l');
        if (j > top) top = j;
      }
    }
    expect(top, lessThanOrEqualTo(3000));
  });

  test('시간·비용은 레벨마다 줄지 않고 Lv1 은 10분 이하', () {
    for (final d in c.defs) {
      expect(
        c.timeAt(d, 1),
        lessThanOrEqualTo(const Duration(minutes: 10)),
        reason: d.id,
      );
      for (var l = 2; l <= d.maxLevel; l++) {
        final a = c.costAt(d, l - 1), b = c.costAt(d, l);
        expect(c.timeAt(d, l), greaterThan(c.timeAt(d, l - 1)), reason: d.id);
        expect(b.goldMinutes, greaterThan(a.goldMinutes), reason: d.id);
        expect(b.materialMinutes, greaterThan(a.materialMinutes));
        expect(b.samples, greaterThanOrEqualTo(a.samples), reason: d.id);
        expect(b.fossil, greaterThanOrEqualTo(a.fossil), reason: d.id);
      }
    }
  });

  test('무과금이 칸을 쉬지 않고 돌리면 175~185일에 다 끝나고, 표본은 병목이 아니다', () {
    final basis = FitBasis.fromJson(
      (raw['fitBasis'] as Map).cast<String, dynamic>(),
    );
    final r = scheduleResearch(c, basis);
    expect(r.completionDay, inInclusiveRange(175, 185));
    // 표본 합계가 그 기간 표본 수입의 95% 이하 — 시간이 병목이어야 한다.
    expect(r.samplesSpent / r.samplesEarned, lessThanOrEqualTo(0.95));
    // 표본이 모자라 칸이 논 시간은 전체 칸 시간의 3% 미만.
    expect(r.sampleWaitSlotDays / r.slotDays, lessThan(0.03));
  });
}

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

  // 한 레벨 상한 = 사냥 1,210분치 ≈ 하루 3시간 켜 둔 날 실제 수입의 1/3(사장님 A안, 설계 §10).
  test('한 레벨의 골드·재료는 사냥 1,210분치를 넘지 않는다', () {
    for (final d in c.defs) {
      for (var l = 1; l <= d.maxLevel; l++) {
        final cost = c.costAt(d, l);
        expect(cost.goldMinutes, lessThanOrEqualTo(1210), reason: '${d.id} $l');
        expect(
          cost.materialMinutes,
          lessThanOrEqualTo(1210),
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

  // 2026-10-25 사장님 — 연구 패스면 표본이 아슬아슬하게 딱 맞고, 없으면 표본이 모자라 칸이 논다
  // (더 오래 켜 두거나 패스). 패스 유저 = 하루 3시간 켜 둠 + research.json pass.fitIdleHours 방치(효율 run_config).
  final basis = FitBasis.fromJson(
    (raw['fitBasis'] as Map).cast<String, dynamic>(),
  );
  final pass = (raw['pass'] as Map).cast<String, dynamic>();
  final run =
      jsonDecode(File('../app/assets/data/run_config.json').readAsStringSync())
          as Map<String, dynamic>;
  final idleFactor =
      (pass['fitIdleHours'] as num) *
      (run['offlineEfficiency'] as num) /
      basis.activeHours;

  test('연구 패스 유저는 185~200일에 다 끝나고 표본은 아슬아슬하게 맞는다', () {
    final r = scheduleResearch(
      c,
      basis,
      idleFactor: idleFactor.toDouble(),
      passCut: c.passTimeCut,
    );
    // 2026-10-25 극한 2칸 · 심연 3칸으로 180 → 약 194일(사장님 — 일수 괜찮음).
    expect(r.completionDay, inInclusiveRange(185, 200));
    // 번 표본의 90~100% 를 쓴다(남아돌지 않는다).
    expect(r.samplesSpent / r.samplesEarned, inInclusiveRange(0.9, 1.0));
    // 표본이 모자라 칸이 논 시간은 5% 미만.
    expect(r.sampleWaitSlotDays / r.slotDays, lessThan(0.05));
  });

  test('패스가 없으면 표본이 병목 — 칸이 10% 넘게 놀고 완료가 늦다(그러나 터무니없지 않게 300일 이하)', () {
    final r = scheduleResearch(c, basis);
    expect(r.sampleWaitSlotDays / r.slotDays, greaterThan(0.10));
    expect(r.completionDay, inInclusiveRange(220, 300));
  });
}

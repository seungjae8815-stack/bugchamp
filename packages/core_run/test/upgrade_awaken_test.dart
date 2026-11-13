import 'dart:convert';
import 'dart:io';

import 'package:core_run/core_run.dart';
import 'package:test/test.dart';

/// 강화 각성·대성공(2026-11-10 사장님 확정).
void main() {
  final json =
      jsonDecode(File('../app/assets/data/run_config.json').readAsStringSync())
          as Map<String, dynamic>;
  final run = RunConfig.fromJson(json);
  final plain = RunConfig.fromJson({...json}..remove('upgradeAwaken'));

  group('각성', () {
    test('최대 레벨 값은 각성이 없을 때와 같다 — 덤은 레벨당 몫에서 옮겨 온 것', () {
      for (final kind in run.upgrades.keys) {
        final spec = run.upgrade(kind);
        final max = spec.maxLevel!;
        expect(
          spec.valueAt(max),
          closeTo(plain.upgrade(kind).valueAt(max), 1e-9),
          reason: kind.key,
        );
      }
    });

    test('각성 레벨에 닿으면 값이 한 레벨보다 크게 뛴다', () {
      final spec = run.upgrade(UpgradeKind.attack);
      final a = spec.awakenAt.first;
      final step = spec.valueAt(a - 1) - spec.valueAt(a - 2);
      expect(spec.valueAt(a) - spec.valueAt(a - 1), greaterThan(step * 1.5));
      expect(spec.nextAwakenAt(a - 1), a);
    });

    test('강화 예산에 맞춘 치명·회피는 각성이 없다', () {
      expect(run.upgrade(UpgradeKind.crit).awakenAt, isEmpty);
      expect(run.upgrade(UpgradeKind.evade).awakenAt, isEmpty);
    });

    test('어느 레벨도 각성이 없을 때보다 약하지 않다 — 업데이트 직후 "약해졌다" 방지', () {
      for (final kind in run.upgrades.keys) {
        final spec = run.upgrade(kind);
        for (var lv = 0; lv <= spec.maxLevel!; lv++) {
          expect(
            spec.valueAt(lv),
            greaterThanOrEqualTo(plain.upgrade(kind).valueAt(lv)),
            reason: '${kind.key} $lv',
          );
        }
      }
    });

    test('값은 레벨이 오를수록 줄지 않는다', () {
      for (final kind in run.upgrades.keys) {
        final spec = run.upgrade(kind);
        for (var lv = 0; lv < spec.maxLevel!; lv++) {
          expect(
            spec.valueAt(lv + 1),
            greaterThanOrEqualTo(spec.valueAt(lv)),
            reason: '${kind.key} $lv',
          );
        }
      }
    });
  });

  group('대성공', () {
    test('같은 계정·레벨이면 늘 같은 결과(다시 굴릴 수 없다)', () {
      for (var lv = 0; lv < 50; lv++) {
        final a = upgradeLuckyAt(
          run,
          seed: 42,
          kind: UpgradeKind.attack,
          level: lv,
        );
        final b = upgradeLuckyAt(
          run,
          seed: 42,
          kind: UpgradeKind.attack,
          level: lv,
        );
        expect(a, b);
      }
    });

    test('나오는 비율이 설정 확률 근처', () {
      var n = 0;
      const total = 20000;
      for (var i = 0; i < total; i++) {
        if (upgradeLuckyAt(
          run,
          seed: i ~/ 200,
          kind: UpgradeKind.values[i % UpgradeKind.values.length],
          level: i % 200,
        )) {
          n++;
        }
      }
      expect(n / total, closeTo(run.upgradeLuckyChance, 0.01));
    });

    test('덤 레벨은 상한을 넘지 않는다', () {
      final spec = run.upgrade(UpgradeKind.attack);
      final max = spec.maxLevel!;
      for (var seed = 0; seed < 500; seed++) {
        expect(
          upgradeLevelAfterBuy(run, spec, seed: seed, level: max - 1),
          max,
        );
      }
    });
  });
}

import 'dart:convert';
import 'dart:io';

import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:flutter_test/flutter_test.dart';

/// assets/data/*.json 이 core_models 로 무결하게 파싱되고 기획 제약을 지키는지 검증.
/// flutter test 의 작업 디렉토리는 패키지 루트(packages/app)이므로 상대경로로 읽는다.
Map<String, dynamic> _readJson(String rel) =>
    jsonDecode(File(rel).readAsStringSync()) as Map<String, dynamic>;

void main() {
  group('species.json', () {
    final root = _readJson('assets/data/species.json');
    final list = (root['species'] as List).cast<Map<String, dynamic>>();
    final species = list.map(Species.fromJson).toList();

    test('schemaVersion == 1', () {
      expect(root['schemaVersion'], 1);
    });

    test('정확히 20종', () {
      expect(species.length, 20);
    });

    test('id 중복 없음', () {
      final ids = species.map((s) => s.id).toSet();
      expect(ids.length, species.length);
    });

    test('모든 항목이 Species.fromJson 파싱 성공 (enum 키 유효)', () {
      // map(Species.fromJson) 가 이미 실행됐으므로 통과. 명시적 재확인.
      expect(() => list.map(Species.fromJson).toList(), returnsNormally);
    });

    test('사이즈 범위 유효 (0 < min < max)', () {
      for (final s in species) {
        expect(s.sizeMinMm, greaterThan(0), reason: s.id);
        expect(s.sizeMaxMm, greaterThan(s.sizeMinMm), reason: s.id);
      }
    });

    test('모든 baseStat > 0', () {
      for (final s in species) {
        final st = s.baseStats;
        expect(
          st.hp > 0 && st.atk > 0 && st.def > 0 && st.spd > 0,
          isTrue,
          reason: s.id,
        );
      }
    });

    test('다국어 이름 3개 언어 모두 비어있지 않음', () {
      for (final s in species) {
        for (final loc in ['ko', 'en', 'ja']) {
          expect(
            s.name.resolve(loc).trim(),
            isNotEmpty,
            reason: '${s.id}/$loc',
          );
        }
      }
    });

    test('등급 분포 = 일반6·고급5·희귀4·영웅3·전설2', () {
      final byGrade = <Grade, int>{};
      for (final s in species) {
        byGrade[s.grade] = (byGrade[s.grade] ?? 0) + 1;
      }
      expect(byGrade[Grade.common], 6);
      expect(byGrade[Grade.uncommon], 5);
      expect(byGrade[Grade.rare], 4);
      expect(byGrade[Grade.epic], 3);
      expect(byGrade[Grade.legendary], 2);
    });

    test('세 주특기 모두 등장', () {
      final specialties = species.map((s) => s.specialty).toSet();
      expect(specialties, containsAll(Specialty.values));
    });

    test('스탯 총합이 등급에 따라 단조 증가 (평균 기준)', () {
      double avgBst(Grade g) {
        final xs = species.where((s) => s.grade == g).map((s) {
          final b = s.baseStats;
          return (b.hp + b.atk + b.def + b.spd).toDouble();
        }).toList();
        return xs.reduce((a, b) => a + b) / xs.length;
      }

      final order = [
        Grade.common,
        Grade.uncommon,
        Grade.rare,
        Grade.epic,
        Grade.legendary,
      ];
      for (var i = 1; i < order.length; i++) {
        expect(
          avgBst(order[i]),
          greaterThan(avgBst(order[i - 1])),
          reason: '${order[i].key} > ${order[i - 1].key}',
        );
      }
    });
  });

  group('traps.json', () {
    final root = _readJson('assets/data/traps.json');
    final list = (root['traps'] as List).cast<Map<String, dynamic>>();
    final traps = list.map(Trap.fromJson).toList();

    test('파싱 성공 & id 중복 없음', () {
      expect(traps, isNotEmpty);
      expect(traps.map((t) => t.id).toSet().length, traps.length);
    });

    test('기본 트랩 sap_trap 존재', () {
      expect(traps.any((t) => t.id == 'sap_trap'), isTrue);
    });

    test('yieldMultiplier 양수', () {
      for (final t in traps) {
        expect(t.yieldMultiplier, greaterThan(0), reason: t.id);
      }
    });
  });

  group('fields.json', () {
    final root = _readJson('assets/data/fields.json');
    final list = (root['fields'] as List).cast<Map<String, dynamic>>();
    final fields = list.map(Field.fromJson).toList();

    test('파싱 성공 & id 중복 없음', () {
      expect(fields, isNotEmpty);
      expect(fields.map((f) => f.id).toSet().length, fields.length);
    });

    test('시작 필드(unlockOrder 0) 존재 & unlockOrder 중복 없음', () {
      expect(fields.any((f) => f.unlockOrder == 0), isTrue);
      final orders = fields.map((f) => f.unlockOrder).toList();
      expect(orders.toSet().length, orders.length);
    });
  });

  group('spawns.json (교차 참조 무결성)', () {
    final speciesRoot = _readJson('assets/data/species.json');
    final speciesIds = (speciesRoot['species'] as List)
        .cast<Map<String, dynamic>>()
        .map((s) => s['id'] as String)
        .toSet();
    final trapIds = (_readJson('assets/data/traps.json')['traps'] as List)
        .cast<Map<String, dynamic>>()
        .map((t) => t['id'] as String)
        .toSet();
    final fieldIds = (_readJson('assets/data/fields.json')['fields'] as List)
        .cast<Map<String, dynamic>>()
        .map((f) => f['id'] as String)
        .toSet();

    final root = _readJson('assets/data/spawns.json');
    final table = SpawnTable.fromJson(root);

    test('SpawnTable.fromJson 파싱 성공 & 비어있지 않음', () {
      expect(table.entries, isNotEmpty);
    });

    test('모든 fieldId / trapId 가 실제 필드·트랩에 존재', () {
      for (final e in table.entries) {
        expect(
          fieldIds.contains(e.fieldId),
          isTrue,
          reason: 'field ${e.fieldId}',
        );
        expect(trapIds.contains(e.trapId), isTrue, reason: 'trap ${e.trapId}');
      }
    });

    test('(fieldId,trapId) 조합 중복 없음', () {
      final keys = table.entries
          .map((e) => '${e.fieldId}|${e.trapId}')
          .toList();
      expect(keys.toSet().length, keys.length);
    });

    test('모든 speciesId 가 실제 종에 존재하고 weight > 0', () {
      for (final e in table.entries) {
        expect(
          e.speciesWeights,
          isNotEmpty,
          reason: '${e.fieldId}/${e.trapId}',
        );
        for (final sw in e.speciesWeights) {
          expect(
            speciesIds.contains(sw.speciesId),
            isTrue,
            reason: '${e.fieldId}/${e.trapId}: ${sw.speciesId}',
          );
          expect(sw.weight, greaterThan(0));
        }
      }
    });

    test('encountersPerHour / materialsPerHour 양수', () {
      for (final e in table.entries) {
        expect(e.encountersPerHour, greaterThan(0));
        expect(e.materialsPerHour, isNotEmpty);
        for (final r in e.materialsPerHour) {
          expect(r.perHour, greaterThan(0));
        }
      }
    });

    test('potentialWeights 는 1~5 범위 (기본값 상속 포함)', () {
      for (final e in table.entries) {
        expect(e.potentialWeights, isNotEmpty);
        for (final pw in e.potentialWeights) {
          expect(pw.potential, inInclusiveRange(kPotentialMin, kPotentialMax));
          expect(pw.weight, greaterThan(0));
        }
      }
    });

    test('시작 조합(oak_forest × sap_trap) 조회 가능', () {
      expect(table.lookup('oak_forest', 'sap_trap'), isNotNull);
      expect(table.lookup('no_such', 'sap_trap'), isNull);
    });
  });

  group('run_config.json', () {
    final config = RunConfig.fromJson(_readJson('assets/data/run_config.json'));

    test('파싱 성공 & 스케일링 계수 > 1 또는 유효', () {
      expect(config.hpGrowth, greaterThan(1.0));
      expect(config.goldGrowth, greaterThan(1.0));
      expect(config.habitatsPerStage, greaterThan(0));
      expect(config.bossHpMult, greaterThan(1.0));
    });

    test('업그레이드 3종(attack/attackSpeed/reward) 모두 존재', () {
      for (final kind in UpgradeKind.values) {
        expect(config.upgrades.containsKey(kind), isTrue, reason: kind.key);
      }
    });

    test('지역 서식지 종류가 비어있지 않음', () {
      expect(config.region.habitatKinds, isNotEmpty);
    });
  });

  group('battle.json', () {
    final cfg = BattleConfig.fromJson(_readJson('assets/data/battle.json'));

    test('보상 계수 파싱 & 양수', () {
      expect(cfg.winGoldBase, greaterThan(0));
      expect(cfg.trophyWin, greaterThan(0));
      expect(cfg.trophyLose, lessThan(0)); // 패배는 트로피 감소
    });

    test('스카우트 티어 3종 & 파워↑ 상대일수록 보상↑', () {
      expect(cfg.scoutTiers.length, 3);
      final sorted = [...cfg.scoutTiers]
        ..sort((a, b) => a.powerMult.compareTo(b.powerMult));
      // 파워 오름차순이면 보상배율도 오름차순(하이리스크-하이리턴)
      for (var i = 1; i < sorted.length; i++) {
        expect(
          sorted[i].rewardMult,
          greaterThanOrEqualTo(sorted[i - 1].rewardMult),
        );
      }
    });

    test('리그: minTrophy 오름차순 & 첫 리그 0에서 시작', () {
      expect(cfg.leagues, isNotEmpty);
      expect(cfg.leagues.first.minTrophy, 0);
      for (var i = 1; i < cfg.leagues.length; i++) {
        expect(
          cfg.leagues[i].minTrophy,
          greaterThan(cfg.leagues[i - 1].minTrophy),
          reason: cfg.leagues[i].id,
        );
      }
    });
  });
}

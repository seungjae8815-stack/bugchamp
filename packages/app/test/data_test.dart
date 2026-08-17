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

    // ── 종 고유 패시브(§2.1) ───────────────────────────────────
    //
    // `stat` 은 문자열이라(core_models 가 UpgradeKind 를 모른다) 오타가 나면
    // 로딩은 통과하고 **패시브만 조용히 사라진다**. 그걸 여기서 잡는다.
    group('종 고유 패시브', () {
      test('모든 종이 패시브를 가진다 — 하나라도 없으면 그 종만 매력이 없다', () {
        for (final s in species) {
          expect(s.passive, isNotNull, reason: s.id);
        }
      });

      test('stat 키가 전부 실재하는 UpgradeKind 다 (오타 = 조용한 무효화)', () {
        for (final s in species) {
          expect(
            UpgradeKind.fromKeyOrNull(s.passive!.statKey),
            isNotNull,
            reason: '${s.id}: 알 수 없는 stat "${s.passive!.statKey}"',
          );
        }
      });

      test('값이 0보다 크다 — 0 이면 패시브가 있는 척만 하는 셈', () {
        for (final s in species) {
          expect(s.passive!.value, greaterThan(0), reason: s.id);
        }
      });

      test('등급이 높을수록 패시브도 세다(평균 기준)', () {
        // crit 은 확률(%p)이라 단위가 달라 평균에서 뺀다.
        double avg(Grade g) {
          final vs = species
              .where((s) => s.grade == g && s.passive!.statKey != 'crit')
              .map((s) => s.passive!.value)
              .toList();
          return vs.isEmpty ? 0 : vs.reduce((a, b) => a + b) / vs.length;
        }

        const order = [
          Grade.common,
          Grade.uncommon,
          Grade.rare,
          Grade.epic,
          Grade.legendary,
        ];
        for (var i = 1; i < order.length; i++) {
          expect(
            avg(order[i]),
            greaterThan(avg(order[i - 1])),
            reason: '${order[i].key} > ${order[i - 1].key}',
          );
        }
      });

      test('패시브 축이 한쪽에 쏠리지 않는다 — 쏠리면 종 선택이 사라진다', () {
        final kinds = species.map((s) => s.passive!.statKey).toSet();
        expect(kinds.length, greaterThanOrEqualTo(8), reason: '서로 다른 축 수');
      });
    });
  });

  group('dex.json', () {
    final cfg = DexConfig.fromJson(_readJson('assets/data/dex.json'));
    final speciesCount =
        (_readJson('assets/data/species.json')['species'] as List).length;

    test('마일스톤이 종 수를 넘지 않는다 — 못 받는 보상이 있으면 안 된다', () {
      for (final m in [...cfg.discoverMilestones, ...cfg.conquerMilestones]) {
        expect(m.count, lessThanOrEqualTo(speciesCount), reason: m.id);
      }
    });

    test('마지막 마일스톤은 도감 완성(전 종)이다', () {
      expect(cfg.discoverMilestones.last.count, speciesCount);
      expect(cfg.conquerMilestones.last.count, speciesCount);
    });

    test('마일스톤 보상이 뒤로 갈수록 커진다', () {
      for (final list in [cfg.discoverMilestones, cfg.conquerMilestones]) {
        for (var i = 1; i < list.length; i++) {
          expect(list[i].gold, greaterThan(list[i - 1].gold));
        }
      }
    });

    test('전 종 정복 보너스가 과하지 않다 — 도감이 진행의 지름길이 되면 안 된다', () {
      // 업그레이드가 레벨당 x1.15 곱연산이라, 도감 전체가 두어 레벨 수준을
      // 넘으면 방치 루프를 밀어낸다.
      expect(cfg.attackPerConquer * speciesCount, lessThanOrEqualTo(0.5));
      expect(cfg.hpPerConquer * speciesCount, lessThanOrEqualTo(0.6));
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

  group('장비·공방·스킬 (신규)', () {
    final items = ItemConfig.fromJson(_readJson('assets/data/items.json'));
    final forge = ForgeConfig.fromJson(_readJson('assets/data/forge.json'));
    final skills = SkillConfig.fromJson(_readJson('assets/data/skills.json'));

    test('부위 8 × 등급 10 = 80종, 스킬 16종', () {
      expect(items.slots.length, 8);
      expect(items.tierCount, 10);
      expect(skills.skills.length, 16);
    });

    test('pubspec 이 자동 로드하는 assets/data 안에 있다', () {
      for (final f in ['items.json', 'forge.json', 'skills.json']) {
        expect(File('assets/data/$f').existsSync(), isTrue, reason: f);
      }
    });

    test('공방 최고 레벨에서 최상위 등급에 닿는다(창이 헛돌지 않게)', () {
      final w = forge.tierWeights(forge.maxLevel, items.tierCount);
      expect(w.last, greaterThan(0.5));
    });
  });

  // pubspec 애셋 등록 — **Flutter 는 하위 디렉토리를 자동 포함하지 않는다.**
  //
  // `assets/images/ui/` 만 적혀 있으면 `ui/cards/` 는 번들에 안 들어가고,
  // 앱은 에러 없이 **조용히 폴백 아이콘**을 그린다. 눈으로 보기 전엔 모르고,
  // 실기에서 "이미지가 적용이 안 됐다"로 돌아온다(2026-08-17 실제 발생).
  test('이미지 폴더가 전부 pubspec 에 등록돼 있다', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final missing = <String>[];
    for (final d in Directory(
      'assets/images',
    ).listSync(recursive: true).whereType<Directory>()) {
      // `_` 로 시작하는 폴더는 **일부러 번들에서 뺀 것**이다(원본 백업 등).
      // 넣으면 앱 용량만 커진다.
      if (d.path.split(RegExp(r'[\\/]')).any((p) => p.startsWith('_'))) {
        continue;
      }
      final hasImage = d.listSync().whereType<File>().any(
        (f) =>
            f.path.endsWith('.webp') ||
            f.path.endsWith('.png') ||
            f.path.endsWith('.jpg'),
      );
      if (!hasImage) continue;
      // 윈도우 경로 구분자를 pubspec 표기(`/`)에 맞춘다.
      final rel = '${d.path.replaceAll(r'\', '/')}/';
      if (!pubspec.contains('- $rel')) missing.add(rel);
    }
    expect(
      missing,
      isEmpty,
      reason:
          'pubspec.yaml 의 assets 목록에 없는 폴더: $missing — '
          'Flutter 는 하위 폴더를 자동 포함하지 않으므로 한 줄씩 적어야 한다.',
    );
  });

  // 오행 표시는 **한 군데(`elementIcon`)로만** 나가야 한다.
  //
  // 이모지(🔥💧🌿⚙️⛰️)는 기기 폰트마다 모양·색이 달라 작게 쓰면 안 읽힌다.
  // 그림으로 바꿨는데 화면이 여덟 군데라, 처음에 세 군데만 바꾸고 나머지는
  // 그대로 뒀다 — 실기에서 "결투랑 대회에는 예전 게 그대로 나온다"로 돌아왔다
  // (2026-08-17). 새 화면을 만들 때 또 `elementGlyph` 를 부르면 여기서 걸린다.
  test('오행은 elementIcon 으로만 그린다 (이모지 직접 호출 금지)', () {
    final offenders = <String>[];
    for (final f
        in Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))) {
      // 정의와 폴백이 있는 곳은 예외 — elementIcon 이 여기 산다.
      if (f.path.replaceAll(r'\', '/').endsWith('lib/ui/labels.dart')) continue;
      if (f.readAsStringSync().contains('elementGlyph(')) {
        offenders.add(f.path.replaceAll(r'\', '/'));
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'elementGlyph 를 직접 부르는 곳: $offenders — '
          'elementIcon(element, size: ...) 을 쓸 것. '
          '애셋이 없으면 elementIcon 이 알아서 이모지로 내려간다.',
    );
  });

  // ARB 플레이스홀더 순서 — **문자열에 나타난 순서 = 파라미터 순서**.
  //
  // `gen-l10n` 은 메타데이터가 없으면 파라미터를 **알파벳 순**으로 만든다.
  // 그래서 "{start} ~ {end}" 가 `(end, start)` 시그니처가 되고, 쓰인 대로 넘긴
  // 호출부는 **조용히 뒤바뀐 값**을 출력한다 — 전부 String 이라 컴파일러도 못 잡는다.
  // 실제로 두 건 발생했다: 참가권 "5/2", 전단지 기간 "8월30일 ~ 8월17일".
  test('ARB 플레이스홀더 순서가 문자열 순서와 일치한다', () {
    final arb =
        jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync())
            as Map<String, dynamic>;
    final gen = File('lib/l10n/app_localizations.dart').readAsStringSync();
    final bad = <String>[];
    for (final e in arb.entries) {
      if (e.key.startsWith('@') || e.value is! String) continue;
      final order = RegExp(
        r'\{(\w+)\}',
      ).allMatches(e.value as String).map((m) => m.group(1)!).toSet().toList();
      if (order.length < 2) continue;
      final sig = RegExp(
        r'\b'
        '${e.key}'
        r'\((.*?)\);',
        dotAll: true,
      ).firstMatch(gen)?.group(1);
      if (sig == null) continue;
      final params = sig
          .split(',')
          .map((p) => p.trim())
          .where((p) => p.isNotEmpty)
          .map((p) => p.split(' ').last)
          .toList();
      if (!_sameOrder(params, order)) {
        bad.add('${e.key}: 문자열 $order vs 시그니처 $params');
      }
    }
    expect(
      bad,
      isEmpty,
      reason:
          '순서가 어긋난 문구: $bad — '
          'app_en.arb 에 @키의 placeholders 를 문자열 순서대로 적어 고정한다.',
    );
  });
}

bool _sameOrder(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

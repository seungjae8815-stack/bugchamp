import 'dart:convert';
import 'dart:io';

import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:flutter_test/flutter_test.dart';

/// 젤리(프리미엄 재화 §2.6) **수도꼭지 규칙**을 고정한다.
///
/// 왜 테스트가 필요한가: 젤리가 나오는 곳이 여섯 군데(일일보상·깜짝선물·미션·
/// 리그/시즌·광고버프·분해)로 흩어져 있어, 하나씩 보면 다 적어 보이는데
/// 합치면 하루 193개 = ₩5,500 패키지를 **1.6일마다 공짜로 주는** 상태가 됐다
/// (2026-08-15 감사, `core_run/tool/jelly_sim.dart`).
///
/// 아래는 그때 막은 **구조적 구멍들**이다. 수치 자체가 아니라
/// "무한히 늘어나는 통로에 프리미엄 재화를 붙이지 않는다"는 규칙을 검사한다.
Map<String, dynamic> _readJson(String rel) =>
    jsonDecode(File(rel).readAsStringSync()) as Map<String, dynamic>;

void main() {
  final pets = PetConfig.fromJson(_readJson('assets/data/pets.json'));
  final buffs = BuffConfig.fromJson(_readJson('assets/data/buffs.json'));
  final missions = MissionConfig.fromJson(
    _readJson('assets/data/missions.json'),
  );
  final gifts = GiftConfig.fromJson(_readJson('assets/data/gifts.json'));

  group('분해 — 무한 공급이라 문턱이 필요하다', () {
    test('포텐셜 문턱이 살아 있다 (0 이면 무제한 수도꼭지)', () {
      // 곤충은 시간당 27마리씩 무한히 나온다. 문턱이 없으면 분해만으로
      // 하루 97젤리(전체의 50%)가 들어왔다.
      expect(pets.disassembleJellyMinPotential, greaterThan(0));
    });

    test('문턱 미만 개체는 젤리를 주지 않는다', () {
      for (var p = 1; p < pets.disassembleJellyMinPotential; p++) {
        expect(pets.disassembleJelly(p), 0, reason: '포텐셜 $p');
      }
    });

    test('문턱 이상은 젤리를 준다 — 드문 개체의 가치는 남아야 한다', () {
      expect(
        pets.disassembleJelly(pets.disassembleJellyMinPotential),
        greaterThan(0),
      );
    });

    test('야생 드롭 대다수는 문턱 아래다 — 파밍으로 젤리가 뽑히면 안 된다', () {
      // 드롭 롤은 `1 + floor(r1*r2*4)`. 곱의 분포라 상위 포텐셜이 드물다.
      // 여기서 재는 건 "평균적으로 한 마리당 젤리가 거의 안 나온다"는 사실이다.
      var jelly = 0.0;
      const n = 200000;
      final rng = _Lcg(20260815);
      for (var i = 0; i < n; i++) {
        final p = (1 + (rng.next() * rng.next() * 4).floor()).clamp(1, 5);
        jelly += pets.disassembleJelly(p);
      }
      expect(jelly / n, lessThan(0.2), reason: '마리당 평균 젤리');
    });

    test('일반 개체도 재료는 돌려받는다 — 분해할 이유가 남아야 한다', () {
      for (final g in Grade.values) {
        expect(pets.releaseMaterial(g), greaterThan(0), reason: g.key);
      }
    });
  });

  group('광고 버프 — 보상은 버프 자체다', () {
    test('덤 젤리가 데이터에 있고 0이다 (코드 상수 아님)', () {
      // 누적 상한 6h ÷ 30분 = 하루 12회. 덤이 1이면 그것만으로 12젤리/일이 샌다.
      expect(buffs.adJelly, 0);
    });
  });

  group('미션 — 지수 보상에는 상한이 필요하다', () {
    test('젤리 보상 미션에는 rewardMax 가 있다', () {
      final jellyMissions = missions.missions.where((m) => m.reward == 'jelly');
      expect(jellyMissions, isNotEmpty, reason: '젤리 미션이 있어야 이 검사가 의미 있다');
      for (final m in jellyMissions) {
        expect(m.rewardMax, greaterThan(0), reason: m.id);
      }
    });

    test('티어가 아무리 쌓여도 상한을 넘지 않는다', () {
      for (final m in missions.missions.where((m) => m.reward == 'jelly')) {
        // 100티어(정상 플레이로 도달 불가한 수준)에서도 막혀야 한다.
        expect(m.rewardAt(100), lessThanOrEqualTo(m.rewardMax.round()));
      }
    });
  });

  group('깜짝선물 — 접속 시간에 비례해 무한히 늘어나는 통로', () {
    test('젤리는 최상위 티어에만 붙는다', () {
      final withJelly = gifts.tiers.where((t) => t.jelly > 0).toList();
      expect(withJelly.length, 1, reason: '젤리를 주는 티어 수');
      // 그 티어가 가장 드물어야 한다.
      final minWeight = gifts.tiers
          .map((t) => t.weight)
          .reduce((a, b) => a < b ? a : b);
      expect(withJelly.single.weight, minWeight);
    });

    test('선물 1개당 기대 젤리가 1개 미만이다', () {
      final total = gifts.tiers.fold<double>(0, (a, t) => a + t.weight);
      final avg =
          gifts.tiers.fold<double>(0, (a, t) => a + t.weight * t.jelly) / total;
      // 광고 배수(×2)까지 감안해도 개당 1개를 넘지 않아야 한다.
      expect(avg * gifts.adMultiplier, lessThanOrEqualTo(1.0));
    });
  });

  group('혈통 특성 — PvP 전투 반영', () {
    test('전투 배율이 켜져 있고, 펫 계수와 따로 조절된다', () {
      expect(pets.traitBattleScale, greaterThan(0));
      // 맹렬은 공격만, 강인은 체력만 — 전투에서도 축이 갈려야 한다.
      expect(pets.traitBattleAtk(BugTrait.fierce), greaterThan(0));
      expect(pets.traitBattleHp(BugTrait.fierce), 0);
      expect(pets.traitBattleHp(BugTrait.sturdy), greaterThan(0));
      expect(pets.traitBattleAtk(BugTrait.sturdy), 0);
    });

    test('특성 없는 개체는 전투 보정 0 — 야생 개체가 손해보지 않는다', () {
      expect(pets.traitBattleAtk(BugTrait.none), 0);
      expect(pets.traitBattleHp(BugTrait.none), 0);
    });
  });
}

/// 테스트 안에서 재현 가능한 난수(전역 Random 금지 §5).
class _Lcg {
  _Lcg(this._seed);
  int _seed;
  double next() {
    _seed = (_seed * 1103515245 + 12345) & 0x7FFFFFFF;
    return _seed / 0x7FFFFFFF;
  }
}

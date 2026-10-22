import 'dart:convert';
import 'dart:io';

import 'package:core_run/core_run.dart';
import 'package:test/test.dart';

ResearchConfig _real() => ResearchConfig.fromJson(
  jsonDecode(File('../app/assets/data/research.json').readAsStringSync())
      as Map<String, dynamic>,
);

void main() {
  final c = _real();

  test('효과·시간·비용 곡선', () {
    for (final d in c.defs) {
      expect(c.effectAt(d, 0), 0, reason: d.id);
      for (var l = 1; l <= d.maxLevel; l++) {
        expect(c.effectAt(d, l), greaterThan(c.effectAt(d, l - 1)));
        if (l > 1) {
          expect(c.timeAt(d, l), greaterThan(c.timeAt(d, l - 1)));
          expect(
            c.costAt(d, l).goldMinutes,
            greaterThanOrEqualTo(c.costAt(d, l - 1).goldMinutes),
          );
        }
      }
    }
  });

  test('증가율 감쇠(decay) — 1 이면 등비, 작으면 뒤로 갈수록 덜 커진다', () {
    const geo = ResearchDef(
      id: 'a',
      branch: ResearchBranch.hunt,
      effect: ResearchEffect.gold,
      maxLevel: 10,
      firstSeconds: 100,
      timeGrowth: 2,
      goldMinutesFirst: 10,
      costGrowth: 2,
      fossilFrom: 3,
      fossilFirst: 5,
    );
    const cfg = ResearchConfig();
    expect(cfg.timeAt(geo, 1).inSeconds, 100);
    expect(cfg.timeAt(geo, 4).inSeconds, 800);
    expect(cfg.costAt(geo, 4).goldMinutes, 80);
    expect(cfg.costAt(geo, 4).fossil, 10);
    final dec = ResearchDef.fromJson({
      'id': 'b',
      'branch': 'hunt',
      'kind': 'gold',
      'maxLevel': 10,
      'time': {'firstSeconds': 100, 'growth': 2, 'decay': 0.5},
      'cost': {
        'goldMinutesFirst': 10,
        'growth': 2,
        'decay': 0.5,
        'fossilFrom': 3,
        'fossilFirst': 5,
      },
    });
    // 단계 배율 = 1 + (2-1)×0.5^(i-1): ×2 · ×1.5 · ×1.25
    expect(cfg.timeAt(dec, 2).inSeconds, 200);
    expect(cfg.timeAt(dec, 3).inSeconds, 300);
    expect(cfg.timeAt(dec, 4).inSeconds, 375);
    expect(cfg.costAt(dec, 4).goldMinutes, closeTo(37.5, 1e-9));
    // 화석은 fossilFrom 레벨이 fossilFirst, 그 뒤 같은 배율(3→4 ×1.25).
    expect(cfg.costAt(dec, 3).fossil, 5);
    expect(cfg.costAt(dec, 4).fossil, 6);
  });

  test('칸 수', () {
    expect(c.slotsFor(0, 0), 1);
    expect(c.slotsFor(2, 0), 2);
    expect(c.slotsFor(3, 0), 3);
    expect(c.slotsFor(0, 1), 2);
    expect(c.slotsFor(0, 5), 3);
    expect(c.slotsFor(3, 2), 3);
  });

  test('시간 단축 효과는 0.5 를 넘지 않는다', () {
    final all = {for (final d in c.defs) d.id: d.maxLevel};
    final big = ResearchConfig(
      defs: [
        for (final d in c.defs)
          ResearchDef(
            id: d.id,
            branch: d.branch,
            effect: d.effect,
            maxLevel: d.maxLevel,
            perLevel: 0.5,
          ),
      ],
    );
    expect(researchEffects(big, all).of(ResearchEffect.hatchTime), 0.5);
    expect(
      researchEffects(c, all).of(ResearchEffect.hatchTime),
      lessThanOrEqualTo(0.5),
    );
    expect(researchEffects(c, {}).of(ResearchEffect.gold), 0);
    // 장비 시간·다듬기 비용도 시간 단축과 같은 0.5 · 회피·스킬 쿨타임은 연구 몫 0.2.
    for (final e in [
      ResearchEffect.forgeTime,
      ResearchEffect.starTime,
      ResearchEffect.polishCost,
    ]) {
      expect(researchEffects(big, all).of(e), 0.5, reason: e.key);
    }
    expect(researchEffects(big, all).of(ResearchEffect.huntEvade), 0.2);
    expect(researchEffects(big, all).of(ResearchEffect.skillCooldown), 0.2);
    expect(researchEffects(big, all).of(ResearchEffect.gold), greaterThan(0.5));
  });

  test('즉시 완료 젤리는 5 단위', () {
    for (final s in [1, 60, 1800, 86400, 400000]) {
      expect(c.instantJelly(Duration(seconds: s)) % 5, 0);
    }
    expect(c.instantJelly(Duration.zero), 0);
  });

  test('실데이터: 29개, id 유일, 효과 유일, 선행 유효, 분야별 11·7·6·3·2', () {
    expect(c.defs.length, 29);
    final ids = c.defs.map((d) => d.id).toSet();
    expect(ids.length, 29);
    expect(c.defs.map((d) => d.effect).toSet(), ResearchEffect.values.toSet());
    // 분야마다 첫 연구만 바로 열리고 나머지는 같은 분야 앞 연구 5레벨.
    for (final b in ResearchBranch.values) {
      final list = c.defs.where((d) => d.branch == b).toList();
      expect(list.first.requires, isNull, reason: b.key);
      for (var i = 1; i < list.length; i++) {
        expect(list[i].requires?.id, list[i - 1].id, reason: list[i].id);
        expect(list[i].requires?.level, 5, reason: list[i].id);
      }
    }
    for (final d in c.defs) {
      final r = d.requires;
      if (r != null) {
        expect(ids, contains(r.id));
        expect(c.byId(r.id)!.branch, d.branch);
      }
      expect(d.name.keys, containsAll(['ko', 'en', 'ja']));
    }
    int n(ResearchBranch b) => c.defs.where((d) => d.branch == b).length;
    expect(n(ResearchBranch.hunt), 11);
    expect(n(ResearchBranch.nurture), 7);
    expect(n(ResearchBranch.duel), 6);
    expect(n(ResearchBranch.gear), 3);
    expect(n(ResearchBranch.economy), 2);
  });
}

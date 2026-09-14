// 세이브 하나를 놓고 "지금 전력이 어느 사냥터에서 벽을 만나는가"를 본다.
//
// 사냥터 구조의 몬스터는 **고정 세기**라(적응형 끔), 유저마다 체감이 갈리는
// 이유가 전부 이 표에 드러난다. 시뮬(balance_sim)이 "평균 유저"를 재는 도구라면
// 이 도구는 **실제 계정 하나**를 잰다 — 문의가 들어왔을 때 쓴다.
//
// 사용: dart run tool/zone_check.dart <세이브 json> [--no-gear]
//   세이브 json = Supabase saves 행(배열) 또는 data 객체 그대로.
import 'dart:convert';
import 'dart:io';

import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';

void main(List<String> args) {
  final path = args.firstWhere((a) => !a.startsWith('--'));
  final noGear = args.contains('--no-gear');
  final raw = jsonDecode(File(path).readAsStringSync());
  final data = (raw is List ? raw[0]['data'] : raw) as Map<String, dynamic>;

  final cfg = RunConfig.fromJson(
    jsonDecode(File('../app/assets/data/run_config.json').readAsStringSync())
        as Map<String, dynamic>,
  );
  final items = ItemConfig.fromJson(
    jsonDecode(File('../app/assets/data/items.json').readAsStringSync())
        as Map<String, dynamic>,
  );

  final levels = <UpgradeKind, int>{};
  (data['upgradeLevels'] as Map?)?.forEach((k, v) {
    final kind = UpgradeKind.values.where((u) => u.key == k);
    if (kind.isNotEmpty) levels[kind.first] = (v as num).toInt();
  });
  final tier = (data['difficultyTier'] as num?)?.toInt() ?? 0;

  final bare = deriveStats(
    cfg,
    upgradeLevels: levels,
    characterLevel: (data['level'] as num?)?.toInt() ?? 1,
    bugsCollected: (data['bugs'] as List?)?.length ?? 0,
  );

  // 장비 — **상한을 먼저 적용**한다(trimItemOptions). 안 그러면 옛 세이브의
  // 상한 초과 옵션이 그대로 더해져 앱보다 세게 나온다.
  var st = bare;
  var gearNote = '장비 없음';
  final eq = (data['equippedItems'] as Map?) ?? const {};
  if (!noGear && eq.isNotEmpty) {
    final equipped = <EquipItem>[];
    for (final v in eq.values) {
      final item = EquipItem.fromJson((v as Map).cast<String, dynamic>());
      equipped.add(trimItemOptions(item, items));
    }
    final bonus = equipmentBonus(equipped, items);
    st = applyEquipment(st, bonus, critBudget: cfg.critBudgetGear);
    gearNote =
        '장비 ${equipped.length}부위 · '
        '공격 +${(bonus[ItemOptionKind.attack] ?? 0).toStringAsFixed(0)}% · '
        '공속 +${(bonus[ItemOptionKind.attackSpeed] ?? 0).toStringAsFixed(0)}% · '
        '치명피해 +${(bonus[ItemOptionKind.critDamage] ?? 0).toStringAsFixed(0)}% · '
        '보스 +${(bonus[ItemOptionKind.bossDamage] ?? 0).toStringAsFixed(0)}%';
  }

  final hit = baselineHitPower(st);
  final bossHit = baselineHitPower(st, boss: true);
  stdout.writeln(
    '회차 $tier · 레벨 ${data['level']} · 한 대 ${hit.toStringAsFixed(0)} '
    '· 체력 ${st.maxHp.toStringAsFixed(0)} · 방어 ${st.defense.toStringAsFixed(0)} '
    '· 공속 ${st.attackSpeed.toStringAsFixed(2)}',
  );
  stdout.writeln(gearNote);
  stdout.writeln(
    '업그레이드: ${levels.entries.map((e) => '${e.key.key}=${e.value}').join(' ')}',
  );
  stdout.writeln('');
  stdout.writeln('사냥터 | 타격수 | 보스타격 | 한대(%체력) | 마리당 초');
  for (var z = 1; z <= cfg.zonesPerTier; z++) {
    final stage = cfg.zoneStartStage(z);
    final hp = habitatMaxHp(cfg, stage - 1, tier: tier).toDouble();
    final bhp = bossMaxHp(cfg, stage - 1, tier: tier).toDouble();
    // 앱과 **같은 인자**로 부른다 — 기준 맷집은 장비 뺀 값, 장비 몫은 따로.
    final threat = habitatThreat(
      cfg,
      stage - 1,
      tier: tier,
      playerToughness: toughnessOf(bare),
      gearToughness: toughnessOf(st),
    );
    final bite =
        threat * cfg.enemyAtkInterval * 100 / (100 + st.defense) / st.maxHp;
    final hits = hp / hit;
    stdout.writeln(
      '${z.toString().padLeft(4)}   '
      '${hits.toStringAsFixed(1).padLeft(7)} '
      '${(bhp / bossHit).toStringAsFixed(1).padLeft(9)} '
      '${(bite * 100).toStringAsFixed(1).padLeft(11)}% '
      '${(hits / st.attackSpeed).toStringAsFixed(2).padLeft(9)}',
    );
  }
}

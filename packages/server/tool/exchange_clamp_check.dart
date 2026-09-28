// 젤리 → 골드 교환소가 서버 골드 상한(mergeSave)에 잘리는지 잰다(2026-09-28).
//
// 교환은 기기에서 바로 골드를 준다(교환 1회 = 그 자리 1시간치 골드). 서버는 60초 업로드마다
// "그 사이 벌 수 있는 골드"로 상한을 걸어 넘으면 자른다 — 젤리를 내고 받은 골드가 잘리면 그대로 손해다.
//
// 실행: cd packages\server ; dart run tool/exchange_clamp_check.dart
import 'package:core_run/core_run.dart';
import 'package:core_save/core_save.dart';
import 'package:server/src/actions.dart';
import 'package:server/src/game_config.dart';

Future<void> main() async {
  final cfg = await GameConfig.load(dir: '../app/assets/data');
  final run = cfg.run;
  final t0 = DateTime.utc(2026, 9, 28, 12);
  final actions = GameActions(config: cfg, now: () => t0);

  print('난이도 사냥터 강화Lv | 교환1회 골드 | 60초 상한 | 교환 몇 회까지 통과');
  for (final tier in [0, 1, 2, 3]) {
    for (final zone in [1, 6, 11]) {
      for (final lv in [50, 200, 500]) {
        final stage = run.zoneStartStage(zone);
        final stored = SaveGame.initial(createdAt: t0).copyWith(
          lastSeen: t0.subtract(const Duration(seconds: 60)),
          zoneEpoch: kZoneEpoch,
          difficultyTier: tier,
          maxTierReached: tier,
          stageNumber: stage,
          bestStage: stage,
          upgradeLevels: {for (final k in UpgradeKind.values) k: lv},
          gold: 1000,
        );
        final perTrade =
            (rewardGold(run, stage, 1.0, tier: tier) *
                    run.exchangeKillsPerHour *
                    run.exchangeGoldHours)
                .round();
        var pass = 0;
        for (var n = 1; n <= 10; n++) {
          final client = stored.copyWith(gold: stored.gold + perTrade * n);
          final r = actions.mergeSave(stored, client.toJson());
          if (r.extra['clamped'] == true) break;
          pass = n;
        }
        // 상한 = 통과하는 최대 증가량(이분 탐색 대신 대략값).
        final probe = actions.mergeSave(
          stored,
          stored.copyWith(gold: 1 << 62).toJson(),
        );
        final bound = probe.save!.gold - stored.gold;
        print(
          '${['쉬움', '보통', '어려움', '극한'][tier]} $zone Lv$lv | '
          '${_c(perTrade)} | ${_c(bound)} | $pass${pass == 0 ? '  ← 1회도 잘림' : ''}',
        );
      }
    }
  }
}

String _c(num v) {
  if (v >= 1e12) return '${(v / 1e12).toStringAsFixed(1)}조';
  if (v >= 1e8) return '${(v / 1e8).toStringAsFixed(1)}억';
  if (v >= 1e4) return '${(v / 1e4).toStringAsFixed(1)}만';
  return '$v';
}

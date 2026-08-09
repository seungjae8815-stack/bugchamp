// 제련을 실제로 굴려보는 도구 — 확률·비용을 "숫자를 보면서" 잡는다.
//
//   dart run tool/forge_sim.dart
//   dart run tool/forge_sim.dart --level=20 --rolls=200000
//
// 밸런스를 만질 땐 반드시 이걸 돌린다. 확률 창은 계수 두 개(centerPerLevel,
// spread)로 열 등급을 굴리므로, 손으로 예상하면 거의 틀린다.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';

const _dir = '../app/assets/data';

void main(List<String> args) {
  final opts = _parse(args);
  final items = ItemConfig.fromJson(_read('items.json'));
  final forge = ForgeConfig.fromJson(_read('forge.json'));

  stdout.writeln('══ 공방 제련 시뮬 ══');
  stdout.writeln(
    '망치질 ${forge.hammerSeconds}초 · 온라인 시간당 '
    '${(forge.fossilPerSecond * 3600).round()}개 획득\n',
  );

  _tierTable(forge, items);
  _rollReport(items, forge, opts.level, opts.rolls);
  _timeToTier(items, forge);
  _levelUpTable(forge);
}

Map<String, dynamic> _read(String name) =>
    jsonDecode(File('$_dir/$name').readAsStringSync()) as Map<String, dynamic>;

/// 레벨별 등급 확률 — 창이 위로 미끄러지는지 눈으로 본다.
void _tierTable(ForgeConfig forge, ItemConfig items) {
  stdout.writeln('── 등급 확률(공방 레벨별) ──');
  final head = StringBuffer('  레벨 ');
  for (final t in items.tiers) {
    head.write(t.name.ko.padLeft(7));
  }
  stdout.writeln(head);
  for (var lv = 1; lv <= forge.maxLevel; lv++) {
    final w = forge.tierWeights(lv, items.tierCount);
    final row = StringBuffer('  ${lv.toString().padLeft(4)} ');
    for (final v in w) {
      row.write(
        v >= 0.0005
            ? '${(v * 100).toStringAsFixed(1)}%'.padLeft(7)
            : '-'.padLeft(7),
      );
    }
    stdout.writeln(row);
  }
  stdout.writeln('');
}

/// 실제로 굴려서 나온 분포 — 이론값과 어긋나면 롤 로직이 잘못된 것이다.
void _rollReport(ItemConfig items, ForgeConfig forge, int level, int rolls) {
  final rng = Random(20260809);
  final tierCount = <int, int>{};
  final optCount = <ItemOptionKind, int>{};
  var optTotal = 0;
  for (var i = 0; i < rolls; i++) {
    final it = forgeOnce(
      rng: rng,
      items: items,
      forge: forge,
      forgeLevel: level,
    );
    tierCount[it.tier] = (tierCount[it.tier] ?? 0) + 1;
    for (final o in it.options) {
      optCount[o.kind] = (optCount[o.kind] ?? 0) + 1;
      optTotal++;
    }
  }

  stdout.writeln('── 레벨 $level 에서 ${_num(rolls)}회 굴린 결과 ──');
  for (var t = 0; t < items.tierCount; t++) {
    final c = tierCount[t] ?? 0;
    if (c == 0) continue;
    final pct = c / rolls * 100;
    final oneIn = c == 0 ? 0.0 : rolls / c;
    stdout.writeln(
      '  ${items.tier(t).name.ko.padRight(4)} '
      '${pct.toStringAsFixed(2).padLeft(6)}%  '
      '= ${oneIn.toStringAsFixed(1).padLeft(8)}회에 1개  '
      '(${_mins(oneIn * forge.hammerSeconds)})',
    );
  }
  stdout.writeln('  옵션은 굴림당 평균 ${(optTotal / rolls).toStringAsFixed(2)}개');
  stdout.writeln('');
}

/// "원하는 걸 뽑는 데 얼마나 걸리나" — 하루 획득량 기준.
void _timeToTier(ItemConfig items, ForgeConfig forge) {
  // 하루 = 활동 2시간 + 오프라인 8시간(기존 시뮬과 같은 가정).
  final perDay =
      forge.fossilPerSecond * 3600 * 2 +
      forge.fossilPerSecond * forge.fossilOfflineRatio * 3600 * 8;
  stdout.writeln('── 하루 획득 ${perDay.round()}개 로 무엇을 얻나 ──');
  stdout.writeln(
    '  (활동 2시간 + 오프라인 8시간 · 제련 ${_mins(perDay * forge.hammerSeconds)})',
  );
  for (final lv in const [5, 15, 25, 35]) {
    final w = forge.tierWeights(lv, items.tierCount);
    // 그 레벨에서 나오는 **가장 높은 등급**을 목표로 본다.
    var top = 0;
    for (var i = 0; i < w.length; i++) {
      if (w[i] >= 0.005) top = i;
    }
    final p = w[top];
    final perSlot = p / items.slots.length; // 원하는 부위까지 맞을 확률
    stdout.writeln(
      '  레벨 ${lv.toString().padLeft(2)} → 최고 ${items.tier(top).name.ko.padRight(4)}'
      ' 하루 ${(perDay * p).toStringAsFixed(1).padLeft(6)}개'
      ' · 특정 부위로는 ${(perDay * perSlot).toStringAsFixed(1).padLeft(5)}개',
    );
  }
  stdout.writeln('');
}

/// 공방 등급업 — **골드 10칸을 채우면 업그레이드가 시작된다**.
/// 장비 성장의 총 속도를 결정하는 표라 눈으로 확인하고 만진다.
void _levelUpTable(ForgeConfig forge) {
  stdout.writeln('── 공방 등급업(골드 ${forge.levelUpSteps}칸 + 시간) ──');
  stdout.writeln('  레벨 |    총 골드 |   칸당 골드 |  업그레이드 시간 | 누적 시간');
  var acc = Duration.zero;
  for (var lv = 0; lv < forge.maxLevel; lv++) {
    final d = forge.levelUpDuration(lv);
    acc += d;
    stdout.writeln(
      '  ${(lv + 1).toString().padLeft(4)} |'
      ' ${_gold(forge.levelUpGold(lv)).padLeft(10)} |'
      ' ${_gold(forge.levelUpStepGold(lv)).padLeft(11)} |'
      ' ${_days(d).padLeft(16)} |'
      ' ${_days(acc).padLeft(9)}',
    );
  }
  stdout.writeln('  * 시간만 젤리로 즉시완료된다 — 골드는 젤리로 사지 않는다(P2W 금지).');
  stdout.writeln('');
}

/// 큰 골드를 한국식 단위로 — 억/조 단위가 아니면 규모가 안 읽힌다.
String _gold(int v) {
  final d = v.toDouble();
  if (d >= 1e16) return '${(d / 1e16).toStringAsFixed(1)}경';
  if (d >= 1e12) return '${(d / 1e12).toStringAsFixed(1)}조';
  if (d >= 1e8) return '${(d / 1e8).toStringAsFixed(1)}억';
  if (d >= 1e4) return '${(d / 1e4).toStringAsFixed(1)}만';
  return '$v';
}

String _mins(double seconds) {
  if (seconds < 60) return '${seconds.toStringAsFixed(0)}초';
  if (seconds < 3600) return '${(seconds / 60).toStringAsFixed(1)}분';
  if (seconds < 86400) return '${(seconds / 3600).toStringAsFixed(1)}시간';
  return '${(seconds / 86400).toStringAsFixed(1)}일';
}

String _days(Duration d) => _mins(d.inSeconds.toDouble());

String _num(int v) => v >= 1000 ? '${(v / 1000).toStringAsFixed(0)}K' : '$v';

({int level, int rolls}) _parse(List<String> args) {
  var level = 15;
  var rolls = 100000;
  for (final a in args) {
    final m = RegExp(r'^--([a-z-]+)=(.+)$').firstMatch(a);
    if (m == null) continue;
    switch (m.group(1)) {
      case 'level':
        level = int.parse(m.group(2)!);
      case 'rolls':
        rolls = int.parse(m.group(2)!);
    }
  }
  return (level: level, rolls: rolls);
}

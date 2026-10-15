import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../ui/art.dart';
import '../../ui/format.dart';
import '../../ui/labels.dart';

/// 복귀 팝업의 보상 표(2026-10-15 사장님 확정) — 줄마다 **버프 없이 / 버프 있을 때** 두 칸.
///
/// - 버프를 켜 둔 사람([OfflineReport.buffBonus]): 왼쪽 "버프 없었다면"(받은 값 − 더 받은 몫) · 오른쪽 "버프 있어서 받음"(실제).
/// - 버프가 없던 사람([OfflineReport.buffMissed]만): 왼쪽 "버프 없이 받음"(실제) · 오른쪽 "버프 있었다면"(실제 + 놓친 몫, "약").
/// 실제로 받은 칸을 밝게, 다른 칸을 흐리게 칠한다. 둘 다 없으면 null — 예전 목록을 그대로 쓴다.
///
/// 재료 몫은 합계 기댓값뿐이라 받은 재료 비율로 나눠 보여 준다(화석은 시간 비례라 버프와 무관 — 나누지 않는다).
/// [dayHours] = 이 유저의 방치 보상 상한(기본 8시간, 곤충학자 패스면 16시간) — 희귀 드롭 "하루 약 N개"의 기준.
Widget? offlineRewardTable(
  AppLocalizations l,
  OfflineReport r, {
  int dayHours = kOfflineDayHours,
}) {
  final bonus = r.buffBonus;
  final missed = r.buffMissed;
  if (bonus == null && missed == null) return null;
  // 버프가 켜졌던 사람 — 더 받은 몫이 있거나, 희귀 드롭을 받았다(방치 희귀 드롭은 버프 구간에서만 나온다).
  // 더 받은 몫이 작아 비워진(null) 짧은 버프에서 받은 물약이 "✕"로 사라지던 것을 막는다(2026-10-15 점검).
  final hadBuff = bonus != null || r.fairyStones + r.duelStones + r.potions > 0;
  // 실제 값에 더하거나 뺄 몫 — 켜 둔 사람은 −더 받은 몫, 없던 사람은 +놓친 몫.
  final g = hadBuff ? (bonus ?? const OfflineGain()) : missed!;
  final sign = hadBuff ? -1.0 : 1.0;

  // 희귀 드롭 하루 예상(2026-10-15 사장님) — 채집가의 손길을 켜 둔 기대값(받은 몫 + 놓친 몫)을
  // 이번 방치 시간당으로 나눠 **방치 하루(오프라인 상한 8시간)** 로 늘린다.
  final hours = r.accrued.inSeconds / 3600;
  double perDay(double Function(OfflineGain g) f) {
    if (hours <= 0) return 0;
    final full =
        (bonus == null ? 0.0 : f(bonus)) + (missed == null ? 0.0 : f(missed));
    return full / hours * dayHours;
  }

  final rows = <_Row>[];
  void add(
    Widget icon,
    String name,
    double got,
    double delta, {
    bool exact = false,
    bool always = false,
    double daily = 0,
  }) {
    final other = got + sign * delta;
    // 희귀 드롭(속성석·결투석·성장물약)은 0 이어도 줄을 남긴다(2026-10-15 사장님 — "버프 없으면 0"이 보여야 한다).
    if (!always && got <= 0 && other < 0.5) return;
    rows.add(
      _Row(
        icon,
        name,
        got,
        other < 0 ? 0 : other,
        exact,
        rare: always,
        daily: daily,
      ),
    );
  }

  add(
    goldIcon(size: 22),
    l.curGold,
    r.gold.toDouble(),
    g.gold.toDouble(),
    exact: true,
  );
  add(
    gameImage(
      'assets/images/upgrades/xp.webp',
      width: 22,
      height: 22,
      fallback: const Icon(Icons.auto_awesome, size: 18, color: Colors.white70),
    ),
    l.offlineXpLabel,
    r.xp.toDouble(),
    g.xp.toDouble(),
    exact: true,
  );
  final dropTotal = [
    for (final e in r.materials.entries)
      if (e.key != MaterialKind.fossil) e.value,
  ].fold<int>(0, (a, b) => a + b);
  for (final k in MaterialKind.values) {
    final v = (r.materials[k] ?? 0).toDouble();
    final share = k == MaterialKind.fossil || dropTotal <= 0
        ? 0.0
        : v / dropTotal;
    add(
      materialImage(k, size: 22, fallback: Icon(materialIcon(k), size: 18)),
      materialLabel(l, k),
      v,
      g.materials * share,
    );
  }
  // 받은 재료가 하나도 없는데 놓친 재료만 있으면 한 줄로.
  if (dropTotal <= 0 && g.materials >= 0.5 && !hadBuff) {
    rows.add(
      _Row(
        const Icon(Icons.inventory_2_rounded, size: 18, color: Colors.white70),
        l.offlineRowMaterials,
        0,
        g.materials,
        false,
      ),
    );
  }
  add(
    const Icon(Icons.egg_rounded, size: 20, color: Color(0xFFFFE0B2)),
    l.offlineRowEggs,
    r.bugs.toDouble(),
    g.bugs,
  );
  add(
    gameImage(
      'assets/images/fairies/stone_attack.webp',
      width: 22,
      height: 22,
      fallback: const Icon(Icons.diamond_rounded, size: 18),
    ),
    l.offlineRowFairyStone,
    r.fairyStones.toDouble(),
    g.fairyStones,
    always: true,
    daily: perDay((x) => x.fairyStones),
  );
  add(
    gameIcon('stone_element', size: 22, fallback: Icons.hexagon_rounded),
    l.offlineRowDuelStone,
    r.duelStones.toDouble(),
    g.duelStones,
    always: true,
    daily: perDay((x) => x.duelStones),
  );
  add(
    gameIcon('potion', size: 22, fallback: Icons.science_rounded),
    l.offlineRowPotion,
    r.potions.toDouble(),
    g.potions,
    always: true,
    daily: perDay((x) => x.potions),
  );

  const got = Color(0xFFEBA52F);
  const dim = Color(0x80FFFFFF);
  // 실제로 받은 칸 = 버프를 켰으면 오른쪽, 아니면 왼쪽.
  final leftTitle = hadBuff ? l.offlineColNoBuffWould : l.offlineColNoBuffGot;
  final rightTitle = hadBuff ? l.offlineColBuffGot : l.offlineColBuffWould;

  // 계산한 값(약)이 1 보다 작으면 소수 한 자리 — 짧게 비웠을 때 "약 +0"만 보이면 버프를 켤 이유가 안 보인다(2026-10-15).
  String fmt(double v, {required bool approx, required bool exact}) {
    final small = approx && !exact && v >= 0.005 && v < 0.95;
    // 0.1 아래는 둘째 자리까지("약 +0.0"이 보였다 — 2026-10-15 에뮬).
    final n = small
        ? v.toStringAsFixed(v < 0.095 ? 2 : 1)
        : formatCompact(v.round());
    return approx && !exact ? l.offlineApprox('+$n') : '+$n';
  }

  // 희귀 드롭의 "버프 없이" 칸 = ✕ 버프 켤 때만(방치 희귀 드롭은 채집가의 손길이 켜진 동안만, 2026-10-15 사장님).
  Widget rareOff() => Expanded(
    flex: 3,
    child: FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerRight,
      child: Text(
        '✕ ${l.offlineRareBuffOnly}',
        maxLines: 1,
        style: const TextStyle(
          color: Color(0xFFE57373),
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
  );

  // 머리말은 한 줄 — 칸이 좁으면 글자를 줄인다("버프 있어서 받음"이 두 줄로 꺾였다, 2026-10-15 실기).
  Widget head(String t, bool on) => Expanded(
    flex: 3,
    child: FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerRight,
      child: Text(
        t,
        maxLines: 1,
        style: TextStyle(
          color: on ? got : dim,
          fontSize: 11.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    ),
  );

  // 칸이 좁으면 말줄임 대신 글자를 줄인다("하루 약 4.0개"가 잘렸다, 2026-10-15 실기).
  Widget cell(String t, bool on) => Expanded(
    flex: 3,
    child: FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerRight,
      child: Text(
        t,
        maxLines: 1,
        style: TextStyle(
          color: on ? got : dim,
          fontSize: on ? 14 : 13,
          fontWeight: on ? FontWeight.w900 : FontWeight.w700,
        ),
      ),
    ),
  );

  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          children: [
            const Expanded(flex: 4, child: SizedBox()),
            head(leftTitle, !hadBuff),
            const SizedBox(width: 8),
            head(rightTitle, hadBuff),
          ],
        ),
      ),
      const SizedBox(height: 4),
      for (final row in rows)
        Container(
          margin: const EdgeInsets.only(top: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0x22000000),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0x1AFFFFFF)),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: Row(
                  children: [
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: Center(child: row.icon),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        row.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // 왼쪽 = 버프 없이, 오른쪽 = 버프 있을 때. 계산한 값(받지 않은 칸)은 기댓값이라 "약".
              if (row.rare)
                rareOff()
              else
                cell(
                  fmt(
                    hadBuff ? row.other : row.got,
                    approx: hadBuff,
                    exact: row.exact,
                  ),
                  !hadBuff,
                ),
              const SizedBox(width: 8),
              // 희귀 드롭의 버프 칸 = 하루 예상. 버프를 켠 사람은 실제로 받은 수를 앞에 붙인다.
              if (row.rare)
                cell(
                  hadBuff
                      ? '+${row.got.round()} · ${l.offlineRareDaily(_dayStr(row.daily))}'
                      : l.offlineRareDaily(_dayStr(row.daily)),
                  hadBuff,
                )
              else
                cell(
                  fmt(
                    hadBuff ? row.got : row.other,
                    approx: !hadBuff,
                    exact: false,
                  ),
                  hadBuff,
                ),
            ],
          ),
        ),
      if (rows.any((r) => r.rare)) ...[
        const SizedBox(height: 6),
        Text(
          l.offlineRareNote(dayHours),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xB3FFFFFF),
            fontSize: 11,
            height: 1.35,
          ),
        ),
      ],
    ],
  );
}

/// 희귀 드롭 하루 예상의 기본 기준 시간 = 방치 보상 상한(8시간, 패스 없이).
const kOfflineDayHours = 8;

String _dayStr(double v) =>
    v >= 10 ? '${v.round()}' : v.toStringAsFixed(v >= 1 ? 1 : 2);

class _Row {
  const _Row(
    this.icon,
    this.name,
    this.got,
    this.other,
    this.exact, {
    this.rare = false,
    this.daily = 0,
  });
  final Widget icon;
  final String name;
  final double got;
  final double other;

  /// 버프를 켠 사람의 "버프 없었다면" 골드·경험치는 정확한 값이라 "약"을 붙이지 않는다.
  final bool exact;

  /// 희귀 드롭(속성석·결투석·성장물약) — 버프 없이 칸은 ✕.
  final bool rare;

  /// 희귀 드롭 — 채집가의 손길을 켜 둔 방치 하루(상한 시간) 기대 개수.
  final double daily;
}

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
Widget? offlineRewardTable(AppLocalizations l, OfflineReport r) {
  final bonus = r.buffBonus;
  final missed = r.buffMissed;
  if (bonus == null && missed == null) return null;
  final hadBuff = bonus != null;
  // 실제 값에 더하거나 뺄 몫 — 켜 둔 사람은 −더 받은 몫, 없던 사람은 +놓친 몫.
  final g = hadBuff ? bonus : missed!;
  final sign = hadBuff ? -1.0 : 1.0;

  final rows = <_Row>[];
  void add(
    Widget icon,
    String name,
    double got,
    double delta, {
    bool exact = false,
    bool always = false,
  }) {
    final other = got + sign * delta;
    // 희귀 드롭(속성석·결투석·성장물약)은 0 이어도 줄을 남긴다(2026-10-15 사장님 — "버프 없으면 0"이 보여야 한다).
    if (!always && got <= 0 && other < 0.5) return;
    rows.add(_Row(icon, name, got, other < 0 ? 0 : other, exact));
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
  );
  add(
    gameIcon('stone_element', size: 22, fallback: Icons.hexagon_rounded),
    l.offlineRowDuelStone,
    r.duelStones.toDouble(),
    g.duelStones,
    always: true,
  );
  add(
    gameIcon('potion', size: 22, fallback: Icons.science_rounded),
    l.offlineRowPotion,
    r.potions.toDouble(),
    g.potions,
    always: true,
  );

  const got = Color(0xFFEBA52F);
  const dim = Color(0x80FFFFFF);
  // 실제로 받은 칸 = 버프를 켰으면 오른쪽, 아니면 왼쪽.
  final leftTitle = hadBuff ? l.offlineColNoBuffWould : l.offlineColNoBuffGot;
  final rightTitle = hadBuff ? l.offlineColBuffGot : l.offlineColBuffWould;

  String fmt(double v, {required bool approx, required bool exact}) {
    final n = formatCompact(v.round());
    return approx && !exact ? l.offlineApprox('+$n') : '+$n';
  }

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

  Widget cell(String t, bool on) => Expanded(
    flex: 3,
    child: Text(
      t,
      textAlign: TextAlign.right,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: on ? got : dim,
        fontSize: on ? 14 : 13,
        fontWeight: on ? FontWeight.w900 : FontWeight.w700,
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
              cell(
                fmt(
                  hadBuff ? row.other : row.got,
                  approx: hadBuff,
                  exact: row.exact,
                ),
                !hadBuff,
              ),
              const SizedBox(width: 8),
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
    ],
  );
}

class _Row {
  const _Row(this.icon, this.name, this.got, this.other, this.exact);
  final Widget icon;
  final String name;
  final double got;
  final double other;

  /// 버프를 켠 사람의 "버프 없었다면" 골드·경험치는 정확한 값이라 "약"을 붙이지 않는다.
  final bool exact;
}

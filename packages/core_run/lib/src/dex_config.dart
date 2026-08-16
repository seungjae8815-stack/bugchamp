import 'package:core_models/core_models.dart';
import 'package:meta/meta.dart';

import 'character_stats.dart';

/// 도감(§2.1) 보상 설정 (assets/data/dex.json, §6).
///
/// 도감은 **곤충이 사라져도 남는 기록**이다. 분해·방생으로 개체는 없어지지만
/// "이 종을 잡아봤다 / 성충까지 키웠다"는 남으므로, 수집 자체에 보상을 걸 수 있는
/// 유일한 축이다.
///
/// 보상이 두 겹인 이유:
///  - **마일스톤**(일시금): 눈앞의 목표. "3종만 더 채우면 젤리 20개".
///  - **정복 비례 영구 보너스**: 장기 축. 도감을 채울수록 캐릭터가 세진다.
///
/// ⚠️ 영구 보너스는 **적응형 몬스터 체력 기준(§7) 밖**에 적용해야 한다.
/// 기준에 넣으면 도감을 채워도 몬스터가 같이 세져서 모을 이유가 사라진다.
@immutable
class DexConfig {
  const DexConfig({
    this.discoverMilestones = const [],
    this.conquerMilestones = const [],
    this.attackPerConquer = 0,
    this.hpPerConquer = 0,
    this.rewardPerDiscover = 0,
  });

  /// 발견(한 번이라도 보유) 마일스톤.
  final List<DexMilestone> discoverMilestones;

  /// 정복(성충까지 키움) 마일스톤.
  final List<DexMilestone> conquerMilestones;

  /// 정복 1종당 공격 배율 가산(0.01 = +1%).
  final double attackPerConquer;

  /// 정복 1종당 최대체력 배율 가산.
  final double hpPerConquer;

  /// 발견 1종당 골드 배율 가산 — 도감을 채우는 초반 동기.
  final double rewardPerDiscover;

  /// [discovered]종 발견 · [conquered]종 정복 상태에서 **받을 수 있는** 마일스톤 중
  /// 아직 안 받은 것들([claimed] 에 없는 것).
  List<DexMilestone> claimable(
    int discovered,
    int conquered,
    Set<String> claimed,
  ) => [
    for (final m in discoverMilestones)
      if (discovered >= m.count && !claimed.contains(m.id)) m,
    for (final m in conquerMilestones)
      if (conquered >= m.count && !claimed.contains(m.id)) m,
  ];

  /// 도감 진행도로 얻는 영구 스탯 보너스. 정복 수에 비례한다.
  ///
  /// 발견이 아니라 **정복**에 거는 이유: 발견은 드롭 운이지만 정복은
  /// 부화기를 돌려 키운 결과다. 시간을 쓴 쪽에 보상이 가야 한다.
  CharacterStats apply(CharacterStats s, int discovered, int conquered) {
    if (discovered <= 0 && conquered <= 0) return s;
    return CharacterStats(
      attack: s.attack * (1 + attackPerConquer * conquered),
      maxHp: s.maxHp * (1 + hpPerConquer * conquered),
      rewardMultiplier: s.rewardMultiplier + rewardPerDiscover * discovered,
      attackSpeed: s.attackSpeed,
      critChance: s.critChance,
      critDamage: s.critDamage,
      bossDamage: s.bossDamage,
      defense: s.defense,
      hpRegen: s.hpRegen,
      xpMultiplier: s.xpMultiplier,
      bugFind: s.bugFind,
      materialFind: s.materialFind,
      moveSpeed: s.moveSpeed,
      boostBonus: s.boostBonus,
    );
  }

  factory DexConfig.fromJson(Map<String, dynamic> json) => DexConfig(
    discoverMilestones: _milestones(json['discoverMilestones'], 'dex_d'),
    conquerMilestones: _milestones(json['conquerMilestones'], 'dex_c'),
    attackPerConquer: (json['attackPerConquer'] as num?)?.toDouble() ?? 0,
    hpPerConquer: (json['hpPerConquer'] as num?)?.toDouble() ?? 0,
    rewardPerDiscover: (json['rewardPerDiscover'] as num?)?.toDouble() ?? 0,
  );

  static List<DexMilestone> _milestones(Object? raw, String prefix) {
    if (raw is! List) return const [];
    final out = <DexMilestone>[];
    for (final e in raw) {
      if (e is! Map) continue;
      final m = Map<String, dynamic>.from(e);
      final count = (m['count'] as num?)?.toInt();
      if (count == null) continue;
      out.add(
        DexMilestone(
          // id 는 **저장되는 키**다(중복 수령 방지). count 로 만들면 JSON 에서
          // 마일스톤 개수를 바꿔도 이미 받은 것이 유지된다.
          id: '${prefix}_$count',
          count: count,
          gold: (m['gold'] as num?)?.toInt() ?? 0,
          jelly: (m['jelly'] as num?)?.toInt() ?? 0,
        ),
      );
    }
    out.sort((a, b) => a.count.compareTo(b.count));
    return out;
  }
}

/// 도감 마일스톤 하나(발견/정복 N종 달성 시 일시금).
@immutable
class DexMilestone {
  const DexMilestone({
    required this.id,
    required this.count,
    this.gold = 0,
    this.jelly = 0,
  });

  /// 수령 여부를 저장할 키(`SaveGame.claimedDex`).
  final String id;

  /// 필요한 종 수.
  final int count;
  final int gold;
  final int jelly;

  /// 정복 마일스톤인가(발견이면 false). 화면 문구를 가른다.
  bool get isConquer => id.startsWith('dex_c');
}

/// 종 목록에서 **도감에 실릴 종**만 고른다(현재는 전부).
///
/// 함수로 둔 이유: 나중에 이벤트 한정·미출시 종이 생기면 여기만 바꾸면 된다.
/// 도감 분모가 화면·마일스톤·보너스 세 곳에서 쓰이므로 한 곳에서 정해야 한다.
List<Species> dexSpecies(Iterable<Species> all) => all.toList()
  ..sort((a, b) {
    final g = a.grade.index.compareTo(b.grade.index);
    return g != 0 ? g : a.id.compareTo(b.id);
  });

import 'package:core_models/core_models.dart';

/// 펫 패시브 v2(2026-10-14 사장님 확정, `pets.json → passiveV2`, 설계 `docs/design_growth_1021.md` §1·§2).
///
/// - **종류**: 1.0.21 뒤에 생긴 곤충([IndividualBug.passiveV2])은 개체마다 [kinds] 중 하나(id 로 정해짐) —
///   같은 종을 모아도 패시브가 달라 모으는 재미가 생긴다. 업데이트 전 곤충은 그 종의 패시브 종류 그대로.
/// - **크기** = 종류 최대치 × 등급 계수(개체 등급) × 희귀도 계수(종 희귀도) × 롤 계수(0~100 → [rollMin]~1).
///   등급을 올릴수록 커지고 희귀 종일수록 더 크게 자란다(옛 "종 희귀도로만 고정" 대체).
/// - 펫(방치 사냥)에만 — 결투·대회에는 실리지 않는다(P2W 선 유지). 적응형 기준 밖(종 패시브와 같은 층).
///
/// ⚠️ [kinds] 의 **순서가 곧 종류 배정**이다(id → 자리) — 중간에 넣거나 빼면 이미 생긴 곤충의 패시브 종류가 바뀐다.
/// 새 종류는 **맨 뒤에만** 붙인다.
class PassiveV2Config {
  const PassiveV2Config({
    this.enabled = false,
    this.kinds = const {},
    this.gradeFactor = const [0.30, 0.45, 0.60, 0.80, 1.00],
    this.rarityFactor = const {},
    this.rollMin = 0.8,
    this.rerollEssence = 3,
    this.rerollJelly = 10,
    this.legacyFreeRerolls = 0,
  });

  final bool enabled;

  /// 종류(`UpgradeKind.key`) → 최대치(전설 종 · 전설 등급 · 롤 100). 순서 = 배정 순서(맨 뒤에만 추가).
  final Map<String, double> kinds;

  /// 개체 등급(일반~전설) 계수.
  final List<double> gradeFactor;

  /// 종 희귀도 계수.
  final Map<Grade, double> rarityFactor;

  /// 롤 0 일 때의 배율(롤 100 = 1.0).
  final double rollMin;

  /// 크기 재굴림 비용 — 그 종 정수(무료 경로) 또는 젤리.
  final int rerollEssence;
  final int rerollJelly;

  /// 업데이트 전 곤충(`p2` 없음)이 곤충마다 받는 **무료** 크기 재굴림 횟수(2026-10-14 사장님 확정 5 — 1.0.21 에서 옛 곤충
  /// 패시브가 대부분 낮아진 것을 스스로 메우게). 펫 전용이라 결투 P2W 밖.
  final int legacyFreeRerolls;

  /// [bug] 가 무료 재굴림을 몇 번 더 쓸 수 있나(업데이트 전 곤충만).
  int freeRerollsLeft(IndividualBug bug) => bug.passiveV2
      ? 0
      : (legacyFreeRerolls - bug.passiveFreeUsed).clamp(0, legacyFreeRerolls);

  List<String> get kindKeys => kinds.keys.toList(growable: false);

  /// [bug] 의 패시브 종류 키. 업데이트 전 곤충은 [legacyKey](그 종의 패시브), 없으면 null.
  String? kindOf(IndividualBug bug, String? legacyKey) {
    if (!bug.passiveV2 || kinds.isEmpty) return legacyKey;
    final keys = kindKeys;
    return keys[IndividualBug.passivePickOf(bug.id, keys.length)];
  }

  /// 롤 [roll](0~100)에서의 크기.
  double valueAt(String kind, Grade grade, Grade rarity, int roll) {
    final max = kinds[kind] ?? 0;
    final g = gradeFactor.isEmpty
        ? 1.0
        : gradeFactor[grade.index.clamp(0, gradeFactor.length - 1)];
    final r = rarityFactor[rarity] ?? 1.0;
    final t = roll.clamp(0, 100) / 100;
    return max * g * r * (rollMin + (1 - rollMin) * t);
  }

  factory PassiveV2Config.fromJson(Map<String, dynamic>? j) {
    if (j == null) return const PassiveV2Config();
    const d = PassiveV2Config();
    final kinds = <String, double>{};
    final rawKinds = j['kinds'];
    if (rawKinds is Map) {
      for (final e in rawKinds.entries) {
        if (e.key is String && !(e.key as String).startsWith('_')) {
          final v = e.value;
          if (v is num) kinds[e.key as String] = v.toDouble();
        }
      }
    }
    final rarity = <Grade, double>{};
    final rawRarity = j['rarityFactor'];
    if (rawRarity is Map) {
      for (final e in rawRarity.entries) {
        final g = Grade.values.where((x) => x.key == e.key).firstOrNull;
        if (g != null && e.value is num) {
          rarity[g] = (e.value as num).toDouble();
        }
      }
    }
    final gf = j['gradeFactor'];
    return PassiveV2Config(
      enabled: j['enabled'] == true,
      kinds: kinds,
      gradeFactor: gf is List
          ? [for (final v in gf) (v as num).toDouble()]
          : d.gradeFactor,
      rarityFactor: rarity,
      rollMin: (j['rollMin'] as num?)?.toDouble() ?? d.rollMin,
      rerollEssence: (j['rerollEssence'] as num?)?.toInt() ?? d.rerollEssence,
      rerollJelly: (j['rerollJelly'] as num?)?.toInt() ?? d.rerollJelly,
      legacyFreeRerolls:
          (j['legacyFreeRerolls'] as num?)?.toInt() ?? d.legacyFreeRerolls,
    );
  }
}

import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:core_save/core_save.dart';
import 'package:flutter_test/flutter_test.dart';

/// 회차 전환이 **성장 축만** 처음으로 돌리는지 — 무엇이 남고 무엇이 돌아가는가.
///
/// 여기서 규칙을 고정해 두는 이유: 골드를 남겼더니 쌓아 둔 돈으로 넘어가는
/// 즉시 강화 상한을 다시 사서 새 회차가 통째로 건너뛰어졌다(2026-09-14).
/// 반대로 곤충·장비를 지우면 "이번엔 수월하다"가 사라진다. 둘 다 회귀하기
/// 쉬운 지점이라 테스트가 지킨다.
void main() {
  SaveGame grown() =>
      SaveGame.initial(createdAt: DateTime.utc(2026, 1, 1)).copyWith(
        stageNumber: 1001,
        difficultyTier: 0,
        level: 54,
        xp: 9999,
        gold: 113000000000000,
        zoneKills: 189,
        upgradeLevels: const {UpgradeKind.attack: 200, UpgradeKind.maxHp: 191},
        materials: const {MaterialKind.chitin: 5000, MaterialKind.jelly: 300},
      );

  /// `SaveController.enterNextTier` 가 만드는 것과 **같은 변환**.
  /// (컨트롤러는 Riverpod·Hive 를 물고 있어 여기선 규칙만 본다.)
  SaveGame nextTier(SaveGame s) => s.copyWith(
    stageNumber: 1,
    difficultyTier: s.difficultyTier + 1,
    upgradeLevels: const {},
    level: 1,
    xp: 0,
    gold: 0,
    zoneKills: 0,
    materials: {
      for (final e in s.materials.entries)
        if (!kRegularMaterials.contains(e.key)) e.key: e.value,
    },
  );

  test('성장 축은 처음으로 — 스테이지·레벨·강화·골드·보스 게이지', () {
    final s = nextTier(grown());
    expect(s.difficultyTier, 1);
    expect(s.stageNumber, 1);
    expect(s.level, 1);
    expect(s.xp, 0);
    expect(s.upgradeLevels, isEmpty);
    // 골드가 남으면 넘어간 즉시 상한까지 되사서 회차가 통째로 건너뛰어진다.
    expect(s.gold, 0);
    // 게이지가 남으면 새 난이도 첫 사냥터에서 보스 도전이 이미 열려 있다.
    expect(s.zoneKills, 0);
  });

  test('일반 재료도 성장 축 — 강화 2차 비용이라 골드와 한 세트다', () {
    final s = nextTier(grown());
    // 키틴 300만이면 공격 164레벨을 즉시 되산다(2026-09-14 계산).
    expect(s.materialCount(MaterialKind.chitin), 0);
    expect(s.materialCount(MaterialKind.mineral), 0);
    expect(s.materialCount(MaterialKind.sap), 0);
  });

  test('수집한 것은 그대로 — 곤충·젤리', () {
    final before = grown();
    final s = nextTier(before);
    expect(s.bugs.length, before.bugs.length);
    // 젤리는 프리미엄 재화 — 돈 주고 산 것을 회차 전환으로 지울 수 없다.
    expect(s.materialCount(MaterialKind.jelly), 300);
  });
}

import 'package:core_models/core_models.dart';
import 'package:core_save/core_save.dart';
import 'package:server/src/actions.dart';
import 'package:server/src/game_config.dart';
import 'package:test/test.dart';

/// 별 재료 이월(2026-10-14 · feat 26) — 1.0.20 이하 앱은 불러올 때 별 재료(`sx`)를 이번 별 몫(need)까지 잘라 올린다.
/// 같은 장비 · 같은 별이면 서버가 저장본 재료를 지킨다(`GameActions._keepStarCarry`).
final t0 = DateTime.utc(2026, 10, 14, 12);

void main() {
  late GameActions actions;
  setUpAll(() async {
    final cfg = await GameConfig.load(dir: '../app/assets/data');
    actions = GameActions(config: cfg, now: () => t0);
  });

  const ring = EquipItem(
    slot: EquipSlot.ring,
    tier: 9,
    stars: 1,
    starExp: 400, // 이번 별(150) + 이월 250
    options: [ItemOption(kind: ItemOptionKind.attack, value: 12.5)],
  );

  SaveGame stored() => SaveGame.initial(createdAt: t0).copyWith(
    lastSeen: t0.subtract(const Duration(seconds: 60)),
    equippedItems: {EquipSlot.ring: ring},
  );

  Map<String, dynamic> upload(
    SaveGame s, {
    required int feat,
    int? sx,
    int? st,
  }) {
    final j = s.toJson()..['feat'] = feat;
    final eq = Map<String, dynamic>.from(j['equippedItems'] as Map);
    final item = Map<String, dynamic>.from(eq['ring'] as Map);
    if (sx != null) item['sx'] = sx;
    if (st != null) item['st'] = st;
    eq['ring'] = item;
    j['equippedItems'] = eq;
    return j;
  }

  test('구버전(feat 25)이 이번 별 몫(150)으로 자른 재료는 저장본(400)으로 되돌린다', () {
    final r = actions.mergeSave(stored(), upload(stored(), feat: 25, sx: 150));
    expect(r.save!.equippedItems[EquipSlot.ring]!.starExp, 400);
  });

  test('구버전이라도 별이 올랐으면(강화를 끝냈으면) 올라온 값을 믿는다', () {
    final r = actions.mergeSave(
      stored(),
      upload(stored(), feat: 25, sx: 0, st: 2),
    );
    final got = r.save!.equippedItems[EquipSlot.ring]!;
    expect(got.stars, 2);
    expect(got.starExp, 0);
  });

  test('새 앱(feat 26)은 올라온 값 그대로', () {
    final r = actions.mergeSave(
      stored(),
      upload(stored(), feat: kSaveFeatureLevel, sx: 120),
    );
    expect(r.save!.equippedItems[EquipSlot.ring]!.starExp, 120);
  });
}

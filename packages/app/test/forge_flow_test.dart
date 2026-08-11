import 'dart:convert';
import 'dart:io';

import 'package:app/data/game_data.dart';
import 'package:app/data/save_repository.dart';
import 'package:app/domain/providers.dart';
import 'package:app/domain/save_controller.dart';
import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:core_save/core_save.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Repo implements SaveRepository {
  _Repo(this._g);
  SaveGame _g;
  @override
  Future<SaveGame> load() async => _g;
  @override
  Future<void> save(SaveGame g) async => _g = g;
  @override
  Future<void> clear() async =>
      _g = SaveGame.initial(createdAt: DateTime.utc(2026));
}

Map<String, dynamic> _read(String f) =>
    jsonDecode(File('assets/data/$f').readAsStringSync())
        as Map<String, dynamic>;

/// 실제 게임 데이터로 돈다 — JSON 을 고치면 여기서 먼저 깨진다.
GameData _data() => GameData.fromDecoded(
  species: _read('species.json'),
  traps: _read('traps.json'),
  fields: _read('fields.json'),
  spawns: _read('spawns.json'),
  runConfig: _read('run_config.json'),
  petConfig: _read('pets.json'),
  itemConfig: _read('items.json'),
  forgeConfig: _read('forge.json'),
  skillConfig: _read('skills.json'),
);

void main() {
  final t0 = DateTime.utc(2026, 8, 9, 12);

  ProviderContainer make(SaveGame seed, {DateTime? now}) {
    final c = ProviderContainer(
      overrides: [
        gameDataProvider.overrideWith((ref) => _data()),
        saveRepositoryProvider.overrideWithValue(_Repo(seed)),
        clockProvider.overrideWithValue(FixedClock(now ?? t0)),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  SaveGame seed() =>
      SaveGame.initial(createdAt: t0).copyWith(lastSeen: t0, gold: 0);

  group('제련', () {
    test('화석 조각 1개를 태워 장비 하나가 나온다', () async {
      final c = make(seed().copyWith(materials: {MaterialKind.fossil: 3}));
      await c.read(saveControllerProvider.future);
      final ctrl = c.read(saveControllerProvider.notifier);

      final r = await ctrl.forgeOnce();
      expect(r.item, isNotNull);
      expect(r.kept, isTrue);
      expect(
        c
            .read(saveControllerProvider)
            .requireValue
            .materialCount(MaterialKind.fossil),
        2,
      );
    });

    test('화석 조각이 없으면 못 뽑는다(자동 제련이 여기서 멈춘다)', () async {
      final c = make(seed());
      await c.read(saveControllerProvider.future);
      expect(
        (await c.read(saveControllerProvider.notifier).forgeOnce()).item,
        isNull,
      );
    });

    test('뽑은 것은 **모루 위에 쌓인다** — 10칸이 차면 더 안 나온다', () async {
      final c = make(seed().copyWith(materials: {MaterialKind.fossil: 30}));
      await c.read(saveControllerProvider.future);
      final ctrl = c.read(saveControllerProvider.notifier);

      for (var i = 0; i < kMaxForgeStack; i++) {
        expect((await ctrl.forgeOnce()).item, isNotNull);
      }
      final full = c.read(saveControllerProvider).requireValue;
      expect(full.forgeStack.length, kMaxForgeStack);
      // 가득 찬 뒤엔 화석도 안 태운다 — 태우면 그냥 손해다.
      final left = full.materialCount(MaterialKind.fossil);
      expect((await ctrl.forgeOnce()).item, isNull);
      expect(
        c
            .read(saveControllerProvider)
            .requireValue
            .materialCount(MaterialKind.fossil),
        left,
      );

      // 맨 위(마지막)부터 하나씩 집는다.
      final top = await ctrl.takeForgeItem();
      expect(top, full.forgeStack.last);
      expect(
        c.read(saveControllerProvider).requireValue.forgeStack.length,
        kMaxForgeStack - 1,
      );
    });

    test('필터에 안 맞으면 화석만 쓰고 **안 쌓인다**', () async {
      const want = {ItemOptionKind.critDamage};
      final c = make(
        seed().copyWith(
          materials: {MaterialKind.fossil: 40},
          autoForgeOptions: want,
        ),
      );
      await c.read(saveControllerProvider.future);
      final ctrl = c.read(saveControllerProvider.notifier);

      var filtered = 0;
      for (var i = 0; i < 40; i++) {
        final r = await ctrl.forgeOnce();
        if (r.item == null) break; // 10칸이 찼다
        if (!r.kept) filtered++;
      }
      final after = c.read(saveControllerProvider).requireValue;

      // 규칙 자체를 본다 — 쌓인 것은 **전부** 필터에 걸린 옵션을 갖고 있다.
      for (final item in after.forgeStack) {
        expect(
          item.options.any((o) => want.contains(o.kind)),
          isTrue,
          reason: '필터에 없는 옵션만 가진 게 쌓였다',
        );
      }
      // 걸러진 것도 화석은 태웠다 — 그래야 자동이 무한히 안 돈다.
      expect(filtered, greaterThan(0), reason: '40번 굴려 하나도 안 걸러졌다');
      expect(after.materialCount(MaterialKind.fossil), lessThan(40));
    });

    test('장착은 **교체**다 — 가방이 없어 부위마다 1개만 남는다', () async {
      final c = make(seed().copyWith(materials: {MaterialKind.fossil: 10}));
      await c.read(saveControllerProvider.future);
      final ctrl = c.read(saveControllerProvider.notifier);

      await ctrl.equipItem(
        const EquipItem(slot: EquipSlot.tool, tier: 2, options: []),
      );
      await ctrl.equipItem(
        const EquipItem(slot: EquipSlot.tool, tier: 5, options: []),
      );
      final save = c.read(saveControllerProvider).requireValue;
      expect(save.equippedItems.length, 1);
      expect(save.equippedItems[EquipSlot.tool]!.tier, 5);
    });

    test('교체 판단: 목표 옵션이 있으면 등급보다 그게 우선이다', () async {
      final c = make(
        seed().copyWith(
          equippedItems: {
            EquipSlot.tool: const EquipItem(
              slot: EquipSlot.tool,
              tier: 8,
              options: [],
            ),
          },
          autoForgeOptions: {ItemOptionKind.critDamage},
        ),
      );
      await c.read(saveControllerProvider.future);
      final ctrl = c.read(saveControllerProvider.notifier);

      // 등급은 낮아도 원하는 옵션이 붙었으면 낫다고 본다.
      expect(
        ctrl.isBetterItem(
          const EquipItem(
            slot: EquipSlot.tool,
            tier: 3,
            options: [ItemOption(kind: ItemOptionKind.critDamage, value: 40)],
          ),
        ),
        isTrue,
      );
      // 목표 옵션이 없으면 등급으로 본다.
      expect(
        ctrl.isBetterItem(
          const EquipItem(slot: EquipSlot.tool, tier: 3, options: []),
        ),
        isFalse,
      );
    });
  });

  group('공방 등급업 — 골드 10칸 + 시간', () {
    test('칸을 다 채워야 업그레이드가 시작된다', () async {
      final forge = ForgeConfig.fromJson(_read('forge.json'));
      final c = make(seed().copyWith(gold: 100000000));
      await c.read(saveControllerProvider.future);
      final ctrl = c.read(saveControllerProvider.notifier);

      for (var i = 1; i < forge.levelUpSteps; i++) {
        expect(await ctrl.payForgeStep(), isTrue);
        final s = c.read(saveControllerProvider).requireValue;
        expect(s.forgeSteps, i);
        expect(s.forgeUpAt, isNull, reason: '$i칸에서는 아직 시작하면 안 된다');
      }
      expect(await ctrl.payForgeStep(), isTrue);
      final s = c.read(saveControllerProvider).requireValue;
      expect(s.forgeSteps, forge.levelUpSteps);
      expect(s.forgeUpAt, isNotNull); // 이제 시작
      expect(s.forgeLevel, 0); // 시간이 지나야 오른다
    });

    test('부분적으로 부어둔 칸은 그대로 남는다', () async {
      final c = make(seed().copyWith(gold: 100000));
      await c.read(saveControllerProvider.future);
      final ctrl = c.read(saveControllerProvider.notifier);
      expect(await ctrl.payForgeStep(), isTrue);
      expect(c.read(saveControllerProvider).requireValue.forgeSteps, 1);
      // 골드가 떨어지면 더 못 붓지만 진행은 보존된다.
      final s = c.read(saveControllerProvider).requireValue;
      expect(s.gold, lessThan(100000));
      expect(s.forgeSteps, 1);
    });

    test('골드가 모자라면 칸을 못 채운다', () async {
      final c = make(seed().copyWith(gold: 10));
      await c.read(saveControllerProvider.future);
      expect(
        await c.read(saveControllerProvider.notifier).payForgeStep(),
        isFalse,
      );
    });

    test('시간이 지나면 레벨이 **1씩** 오른다', () async {
      final forge = ForgeConfig.fromJson(_read('forge.json'));
      final done = t0.add(forge.levelUpDuration(0));
      final c = make(
        seed().copyWith(forgeSteps: forge.levelUpSteps, forgeUpAt: done),
        now: done.add(const Duration(minutes: 1)),
      );
      await c.read(saveControllerProvider.future);
      final ctrl = c.read(saveControllerProvider.notifier);
      expect(await ctrl.claimForgeUpgrade(), isTrue);
      final s = c.read(saveControllerProvider).requireValue;
      expect(s.forgeLevel, 1);
      expect(s.forgeSteps, 0);
      expect(s.forgeUpAt, isNull);
    });

    test('아직 시간이 안 됐으면 못 받는다', () async {
      final c = make(
        seed().copyWith(forgeUpAt: t0.add(const Duration(hours: 1))),
      );
      await c.read(saveControllerProvider.future);
      expect(
        await c.read(saveControllerProvider.notifier).claimForgeUpgrade(),
        isFalse,
      );
    });

    test('젤리는 **시간만** 산다 — 골드 칸은 팔지 않는다', () async {
      final forge = ForgeConfig.fromJson(_read('forge.json'));
      final c = make(
        seed().copyWith(
          materials: {MaterialKind.jelly: 999},
          forgeUpAt: t0.add(const Duration(hours: 3)),
          forgeSteps: forge.levelUpSteps,
        ),
      );
      await c.read(saveControllerProvider.future);
      final ctrl = c.read(saveControllerProvider.notifier);
      expect(await ctrl.rushForgeUpgrade(), isTrue);
      expect(c.read(saveControllerProvider).requireValue.forgeLevel, 1);

      // 칸이 안 찬 상태에서는 젤리로 건너뛸 방법이 없다.
      final c2 = make(seed().copyWith(materials: {MaterialKind.jelly: 999}));
      await c2.read(saveControllerProvider.future);
      expect(
        await c2.read(saveControllerProvider.notifier).rushForgeUpgrade(),
        isFalse,
      );
    });
  });

  group('화석 조각 획득', () {
    test('오프라인 정산에서 시간에 비례해 들어온다 — 상한(8h)을 따른다', () async {
      final forge = ForgeConfig.fromJson(_read('forge.json'));
      final c = make(
        SaveGame.initial(
          createdAt: t0.subtract(const Duration(days: 1)),
        ).copyWith(lastSeen: t0.subtract(const Duration(hours: 30))),
      );
      await c.read(saveControllerProvider.future);
      final got = c
          .read(saveControllerProvider)
          .requireValue
          .materialCount(MaterialKind.fossil);
      // 30시간 비워도 8시간분만 — 상한이 걸린다.
      final cap = (8 * 3600 * forge.fossilPerSecond * forge.fossilOfflineRatio)
          .floor();
      expect(got, cap);
    });
  });

  group('스킬', () {
    test('습득 → 장착, 칸을 넘기면 무시된다', () async {
      final cfg = SkillConfig.fromJson(_read('skills.json'));
      final ids = cfg.skills.take(cfg.equipSlots + 1).map((s) => s.id).toList();
      final c = make(
        seed().copyWith(skillLevels: {for (final id in ids) id: 1}),
      );
      await c.read(saveControllerProvider.future);
      final ctrl = c.read(saveControllerProvider.notifier);

      for (final id in ids) {
        await ctrl.toggleSkill(id);
      }
      final s = c.read(saveControllerProvider).requireValue;
      expect(s.equippedSkills.length, cfg.equipSlots);

      // 다시 누르면 해제된다.
      await ctrl.toggleSkill(s.equippedSkills.first);
      expect(
        c.read(saveControllerProvider).requireValue.equippedSkills.length,
        cfg.equipSlots - 1,
      );
    });

    test('미보유 스킬은 장착되지 않는다', () async {
      final c = make(seed());
      await c.read(saveControllerProvider.future);
      await c.read(saveControllerProvider.notifier).toggleSkill('crit_strike');
      expect(
        c.read(saveControllerProvider).requireValue.equippedSkills,
        isEmpty,
      );
    });
  });

  group('장비가 전투에 실린다', () {
    test('장비는 능력치를 올리되 **적응형 체력 기준에는 안 들어간다**', () {
      final run = RunConfig.fromJson(_read('run_config.json'));
      final items = ItemConfig.fromJson(_read('items.json'));
      final base = deriveStats(
        run,
        upgradeLevels: {UpgradeKind.attack: 30},
        characterLevel: 5,
        bugsCollected: 10,
      );
      final geared = applyEquipment(
        base,
        equipmentBonus([
          const EquipItem(slot: EquipSlot.tool, tier: 9, options: []),
        ], items),
      );
      expect(geared.attack, greaterThan(base.attack));

      // 기준(base)으로 계산한 체력은 장비를 껴도 그대로 → 타격 수가 줄어든다.
      final hp = habitatMaxHp(run, 200, playerAttack: base.attack);
      expect((hp / geared.attack).ceil(), lessThan((hp / base.attack).ceil()));
    });
  });
}

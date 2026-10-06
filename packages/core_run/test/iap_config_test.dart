import 'package:core_run/core_run.dart';
import 'package:test/test.dart';

void main() {
  final cfg = IapConfig.fromJson({
    'currency': 'KRW',
    'passDurationDays': 30,
    'passOfflineCapHours': 12,
    'passIdleGoldMult': 1.2,
    'products': [
      {
        'id': 'jelly_m',
        'kind': 'consumable',
        'type': 'jelly',
        'priceKrw': 5500,
        'sort': 110,
        'bonusPct': 10,
        'grant': {'jelly': 330},
      },
      {
        'id': 'remove_ads',
        'kind': 'nonConsumable',
        'type': 'removeAds',
        'priceKrw': 7700,
        'sort': 10,
      },
      {
        'id': 'starter_pack',
        'kind': 'nonConsumable',
        'type': 'starter',
        'priceKrw': 5500,
        'sort': 20,
        'grant': {'jelly': 300, 'gold': 200000, 'incubatorSlots': 1},
      },
    ],
  });

  test('상품 파싱: 종류·타입·가격·지급', () {
    final jelly = cfg.byId('jelly_m')!;
    expect(jelly.kind, IapKind.consumable);
    expect(jelly.type, IapType.jelly);
    expect(jelly.priceKrw, 5500);
    expect(jelly.bonusPct, 10);
    expect(jelly.grant.jelly, 330);

    final starter = cfg.byId('starter_pack')!;
    expect(starter.kind, IapKind.nonConsumable);
    expect(starter.grant.gold, 200000);
    expect(starter.grant.incubatorSlots, 1);
  });

  test('sort 오름차순 정렬 · 타입 필터', () {
    expect(cfg.sorted.first.id, 'remove_ads'); // sort 10
    expect(cfg.sorted.last.id, 'jelly_m'); // sort 110
    expect(cfg.byType(IapType.jelly).map((p) => p.id), ['jelly_m']);
  });

  test('없는 id → null, 빈 지급 판정', () {
    expect(cfg.byId('nope'), isNull);
    expect(cfg.byId('remove_ads')!.grant.isEmpty, isTrue);
  });

  test('패스 수치는 JSON 에서 온다(§6)', () {
    expect(cfg.passDurationDays, 30);
    expect(cfg.passOfflineCapHours, 12);
    expect(cfg.passIdleGoldMult, 1.2);
    expect(cfg.passDailyJelly, 30); // 미지정 → 기본값
  });

  group('스킨 적용 규칙', () {
    final skinCfg = IapConfig.fromJson({
      'products': const [],
      'skins': [
        {'id': 'gold_rhino', 'speciesPrefix': 'rhino_', 'effect': 'gold'},
        {'id': 'albino_stag', 'speciesPrefix': 'stag_', 'effect': 'albino'},
        {'id': 'arena_theme', 'effect': 'arenaTheme'},
      ],
    });

    test('보유한 스킨만, 해당 종 접두사에만 적용된다', () {
      const owned = {'gold_rhino'};
      expect(skinCfg.skinEffectFor(owned, 'rhino_common'), 'gold');
      expect(skinCfg.skinEffectFor(owned, 'stag_giant'), isNull); // 미보유
      expect(skinCfg.skinEffectFor(owned, 'mantis_giant'), isNull); // 대상 아님
    });

    test('미보유면 아무 효과도 없다', () {
      expect(skinCfg.skinEffectFor(const {}, 'rhino_common'), isNull);
    });

    test('종별 스킨은 곤충이 아닌 효과(아레나 테마)와 섞이지 않는다', () {
      const owned = {'arena_theme'};
      expect(skinCfg.skinEffectFor(owned, 'rhino_common'), isNull);
      expect(skinCfg.ownsEffect(owned, 'arenaTheme'), isTrue);
      expect(skinCfg.ownsEffect(const {}, 'arenaTheme'), isFalse);
    });

    test('skins 미정의 JSON 이면 빈 목록', () {
      expect(cfg.skins, isEmpty);
      expect(cfg.skinEffectFor(const {'gold_rhino'}, 'rhino_common'), isNull);
    });
  });

  group('요정·스킬 상품 칸(2026-10)', () {
    final c = IapConfig.fromJson({
      'growthPassDurationDays': 30,
      'growthPassDaily': {
        'fairyDust': 20,
        'skillGradeShards': {'rare': 2},
        'fairyAccelerators': {'acc30m': 1},
      },
      'products': [
        {
          'id': 'fairy_starter',
          'kind': 'nonConsumable',
          'type': 'oncePack',
          'priceKrw': 4400,
          'grant': {
            'fairyEggs': {'epic': 1, 'rare': 3},
            'fairyAccelerators': {'acc8h': 3},
            'fairyStones': {'attack': 1, 'critDamage': 1, 'bossDamage': 1},
            'fairyDust': 300,
            // 모양이 틀린 값·0 은 버린다(던지지 않는다).
            'skillGradeShards': {'rare': 'x', 'epic': 0},
          },
        },
        {'id': 'growth_pass', 'kind': 'timed', 'type': 'growthPass'},
        {'id': 'weekly_bundle', 'kind': 'consumable', 'type': 'weekly'},
      ],
    });

    test('새 타입·지급 칸을 읽는다', () {
      final p = c.byId('fairy_starter')!;
      expect(p.type, IapType.oncePack);
      expect(p.grant.fairyEggs, {'epic': 1, 'rare': 3});
      expect(p.grant.fairyAccelerators, {'acc8h': 3});
      expect(p.grant.fairyStones.length, 3);
      expect(p.grant.fairyDust, 300);
      expect(p.grant.skillGradeShards, isEmpty);
      expect(p.grant.hasFairy, isTrue);
      expect(p.grant.isEmpty, isFalse);
      expect(c.byId('growth_pass')!.type, IapType.growthPass);
      expect(c.byId('weekly_bundle')!.type, IapType.weekly);
    });

    test('성장 패스 기간·매일 몫', () {
      expect(c.growthPassDurationDays, 30);
      expect(c.growthPassDaily.fairyDust, 20);
      expect(c.growthPassDaily.skillGradeShards, {'rare': 2});
      expect(c.growthPassDaily.fairyAccelerators, {'acc30m': 1});
      expect(c.growthPassDaily.jelly, 0);
    });

    test('칸이 없는 옛 JSON 이면 빈 값', () {
      expect(cfg.growthPassDaily.isEmpty, isTrue);
      expect(const IapGrant().hasFairy, isFalse);
    });
  });
}

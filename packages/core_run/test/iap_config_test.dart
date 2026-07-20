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
}

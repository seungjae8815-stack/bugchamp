import 'package:core_run/core_run.dart';
import 'package:core_save/core_save.dart';

/// 보유 중인 패스와 끝나는 시각(2026-10-25 사장님 — 만료 3일 전·당일 안내).
///
/// 상점 카드의 남은 일수와 **같은 판정**(`craft_screen.dart` `passEndsAt`)이다. 올인원 패스는 네 패스를 함께
/// 늘리는 상품이라 따로 세지 않는다 — 네 패스 각각이 이미 들어 있다.
List<({IapProduct product, DateTime until})> activePasses(
  SaveGame s,
  IapConfig cfg,
  DateTime now,
) {
  IapProduct? first(IapType t) => cfg.byType(t).firstOrNull;
  return [
    for (final (type, active, until) in [
      (IapType.pass, s.passActive(now), s.passExpiresAt),
      (IapType.buffPass, s.buffPassActive(now), s.buffPassExpiresAt),
      (IapType.growthPass, s.growthPassActive(now), s.growthPassExpiresAt),
      (
        IapType.researchPass,
        s.researchPassActive(now),
        s.researchPassExpiresAt,
      ),
    ])
      if (active && until != null && first(type) != null)
        (product: first(type)!, until: until),
  ];
}

/// 안내 단계 — 3일 이하 남음(`soon`) · 하루 이하 남음(`today`). 그 밖은 null.
enum PassExpiryStage { soon, today }

PassExpiryStage? passExpiryStage(DateTime until, DateTime now) {
  final left = until.difference(now);
  if (left <= Duration.zero) return null;
  if (left <= const Duration(days: 1)) return PassExpiryStage.today;
  if (left <= const Duration(days: 3)) return PassExpiryStage.soon;
  return null;
}

/// 남은 날(올림) — 상점 카드와 같은 표기.
int passDaysLeft(DateTime until, DateTime now) {
  final h = until.difference(now).inHours;
  return h <= 0 ? 0 : (h + 23) ~/ 24;
}

/// 로컬 알림을 걸 시각 — 패스마다 끝나기 3일 전과 12시간 전(이미 지난 시각은 뺀다).
List<DateTime> passExpiryNotifyTimes(
  List<({IapProduct product, DateTime until})> passes,
  DateTime now,
) => [
  for (final p in passes)
    for (final t in [
      p.until.subtract(const Duration(days: 3)),
      p.until.subtract(const Duration(hours: 12)),
    ])
      if (t.isAfter(now)) t,
]..sort();

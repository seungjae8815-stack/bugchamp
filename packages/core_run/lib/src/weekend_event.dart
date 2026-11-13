import 'package:meta/meta.dart';

import 'character_stats.dart';

/// 주말 이벤트 사냥터(2026-11-10 사장님 확정, `run_config.json → weekendEvents`).
///
/// 토요일 0시부터 [WeekendEventConfig.hours] 시간(결투 시즌과 같은 고정 시간대) 동안 **온라인 사냥**에만
/// 보상 배율이 붙는다 — "이번 주말엔 켜야지"를 만든다. 방치 정산·선물·일일보상에는 붙지 않는다
/// (서버 봉투 밖으로 나가지 않게). 매주 하나씩 돌아간다([WeekendEventConfig.at]). ❌ 젤리 없음.
@immutable
class WeekendEvent {
  const WeekendEvent({
    required this.id,
    this.name = const {},
    this.desc = const {},
    this.mult = const {},
  });

  final String id;
  final Map<String, String> name;
  final Map<String, String> desc;

  /// 키: `gold`·`xp`·`bugFind`·`materialFind`. 없으면 1.
  final Map<String, double> mult;

  static const keys = {'gold', 'xp', 'bugFind', 'materialFind'};

  double of(String k) => mult[k] ?? 1.0;

  factory WeekendEvent.fromJson(Map<String, dynamic> j) {
    Map<String, String> text(Object? v) => {
      for (final e in ((v as Map?) ?? const {}).entries)
        '${e.key}': '${e.value}',
    };
    return WeekendEvent(
      id: j['id'] as String,
      name: text(j['name']),
      desc: text(j['desc']),
      mult: {
        for (final e in ((j['mult'] as Map?) ?? const {}).entries)
          '${e.key}': (e.value as num).toDouble(),
      },
    );
  }
}

@immutable
class WeekendEventConfig {
  const WeekendEventConfig({this.hours = 48, this.events = const []});

  /// 토요일 0시(고정 시간대)부터 열리는 시간.
  final int hours;
  final List<WeekendEvent> events;

  /// [nowUtc] 에 열린 이벤트와 끝나는 시각(UTC). 없으면 null. [tzOffsetMinutes] = 결투 시즌 시간대(KST 540).
  ({WeekendEvent event, DateTime endsAt})? at(
    DateTime nowUtc,
    int tzOffsetMinutes,
  ) {
    if (events.isEmpty || hours <= 0) return null;
    final local = nowUtc.toUtc().add(Duration(minutes: tzOffsetMinutes));
    final day = DateTime.utc(local.year, local.month, local.day);
    // 이번 주(월요일 시작) 토요일 0시.
    final sat = day.subtract(Duration(days: day.weekday - DateTime.saturday));
    final start = local.weekday >= DateTime.saturday
        ? sat
        : sat.subtract(const Duration(days: 7));
    final end = start.add(Duration(hours: hours));
    if (local.isBefore(start) || !local.isBefore(end)) return null;
    final week = start.millisecondsSinceEpoch ~/ (7 * 86400000);
    return (
      event: events[week % events.length],
      endsAt: end.subtract(Duration(minutes: tzOffsetMinutes)),
    );
  }

  factory WeekendEventConfig.fromJson(Map<String, dynamic>? j) => j == null
      ? const WeekendEventConfig()
      : WeekendEventConfig(
          hours: (j['hours'] as num?)?.toInt() ?? 48,
          events: [
            for (final e in (j['events'] as List? ?? const []))
              WeekendEvent.fromJson(e as Map<String, dynamic>),
          ],
        );
}

/// 주말 이벤트 배율을 온라인 사냥 능력치에 입힌다([e] 가 null 이면 그대로).
CharacterStats applyWeekendEvent(CharacterStats s, WeekendEvent? e) {
  if (e == null || e.mult.isEmpty) return s;
  return CharacterStats(
    attack: s.attack,
    attackSpeed: s.attackSpeed,
    rewardMultiplier: s.rewardMultiplier * e.of('gold'),
    critChance: s.critChance,
    critDamage: s.critDamage,
    bossDamage: s.bossDamage,
    maxHp: s.maxHp,
    defense: s.defense,
    hpRegen: s.hpRegen,
    xpMultiplier: s.xpMultiplier * e.of('xp'),
    bugFind: s.bugFind * e.of('bugFind'),
    materialFind: s.materialFind * e.of('materialFind'),
    evade: s.evade,
    boostBonus: s.boostBonus,
  );
}

import 'dart:math' as math;

import 'package:core_models/core_models.dart';
import 'package:meta/meta.dart';

/// 웨이브를 깰 때마다 고르는 강화 카드(로그라이크).
///
/// 이게 없으면 편성을 짜고 도전을 누른 뒤엔 **개입할 지점이 없어** 재생만 보게
/// 된다. 실물 경품이 걸린 대회에서는 운이 아니라 판단이 순위를 갈라야 한다.
@immutable
class EventCard {
  const EventCard({
    required this.id,
    required this.kind,
    required this.value,
    this.weight = 10,
  });

  final String id;

  /// `heal`(즉시 회복) · `atk`/`def`/`maxHp`(판 끝까지 배율) ·
  /// `revive`(쓰러진 1마리 부활) · `skip`(다음 웨이브 건너뛰기).
  final String kind;

  /// 효과 크기. 배율 카드면 0.12 = +12%, `heal`/`revive` 면 최대 체력 대비 비율.
  final double value;

  /// 뽑힐 가중치.
  final int weight;

  factory EventCard.fromJson(Map<String, dynamic> json) => EventCard(
    id: json['id'] as String,
    kind: json['kind'] as String,
    value: (json['value'] as num).toDouble(),
    weight: (json['weight'] as num?)?.toInt() ?? 10,
  );
}

/// 판이 진행되며 쌓이는 강화(카드 선택의 누적 결과).
@immutable
class EventBuffs {
  const EventBuffs({this.atk = 0, this.def = 0, this.maxHp = 0});

  final double atk;
  final double def;
  final double maxHp;

  EventBuffs plus(String kind, double v) => switch (kind) {
    'atk' => EventBuffs(atk: atk + v, def: def, maxHp: maxHp),
    'def' => EventBuffs(atk: atk, def: def + v, maxHp: maxHp),
    'maxHp' => EventBuffs(atk: atk, def: def, maxHp: maxHp + v),
    _ => this,
  };

  Map<String, dynamic> toJson() => {'atk': atk, 'def': def, 'maxHp': maxHp};

  factory EventBuffs.fromJson(Map<String, dynamic>? json) => EventBuffs(
    atk: (json?['atk'] as num?)?.toDouble() ?? 0,
    def: (json?['def'] as num?)?.toDouble() ?? 0,
    maxHp: (json?['maxHp'] as num?)?.toDouble() ?? 0,
  );
}

/// 실물 경품 랭킹 이벤트(웨이브 방어전) 설정. 값은 전부 `event.json`(§6).
///
/// ⚠️ 이 설정은 **숫자만** 담는다. 웨이브 적을 실제로 만드는 것은
/// `core_battle` 의 `eventWaveEnemies` 다 — `core_run` 은 `core_battle` 을
/// 모르기 때문이다(§4 의존 방향). 서버·앱이 이 숫자를 그 함수에 넘긴다.
@immutable
class EventConfig {
  const EventConfig({
    this.roundDays = 14,
    this.anchorWeekday = DateTime.monday,
    this.anchorHourKst = 9,
    this.startsAt,
    this.endsAt,
    this.ticketMax = 5,
    this.ticketDailyGrant = 3,
    this.ticketAdGrant = 1,
    this.ticketAdDailyLimit = 2,
    this.fatigueHours = 24,
    this.normBaseHp = 120,
    this.normBaseAtk = 55,
    this.normBaseDef = 40,
    this.normBaseSpd = 40,
    this.gradeBonus = const {},
    this.maxWave = 50,
    this.waveHealPct = 0.2,
    this.enemyCount = 3,
    this.enemyBaseHp = 90,
    this.enemyBaseAtk = 26,
    this.enemyBaseDef = 18,
    this.enemyBaseSpd = 30,
    this.enemyGrowth = 1.11,
    this.wavePoint = 1000000,
    this.hpPoint = 1000,
    this.survivorPoint = 100,
    this.speedBase = 500,
    this.cardPicks = 3,
    this.cards = const [],
  });

  /// 회차 길이(일)와 리셋 앵커. 시즌과 같은 KST 월요일 09:00 을 쓴다 —
  /// 유저가 "월요일 아침" 하나만 기억하면 되고, 기기 시간대를 바꿔 회차를
  /// 늘리는 우회도 막힌다(§2.7 시즌과 같은 이유).
  final int roundDays;
  final int anchorWeekday;
  final int anchorHourKst;

  /// 이번 회차의 시작·종료(UTC). 둘 다 없으면 **상시 진행**(구버전 동작).
  ///
  /// 회차를 명시하는 이유: 실물 경품 대회는 "언제부터 언제까지"가 규칙의 일부다.
  /// 다음 회차를 열 때 이 두 값만 바꾸면 `roundId` 가 함께 바뀌므로, 지난 회차의
  /// 기록·순위와 섞이지 않는다.
  final DateTime? startsAt;
  final DateTime? endsAt;

  /// [utc] 시점에 대회가 열려 있는가.
  bool isOpen(DateTime utc) {
    final t = utc.toUtc();
    if (startsAt != null && t.isBefore(startsAt!)) return false;
    if (endsAt != null && !t.isBefore(endsAt!)) return false;
    return true;
  }

  /// 회차 키. 기간이 명시돼 있으면 **시작일(KST)** 로 고정한다 —
  /// 주차 계산과 달리 회차 경계가 사람이 정한 날짜와 정확히 일치한다.
  String roundIdAt(DateTime utc) {
    final s = startsAt;
    if (s == null) return roundIdOf(utc);
    final kst = s.toUtc().add(const Duration(hours: 9));
    final mm = kst.month.toString().padLeft(2, '0');
    final dd = kst.day.toString().padLeft(2, '0');
    return '${kst.year}-$mm$dd';
  }

  /// 참가권. ❌ 젤리로 사지 못한다(사행성·P2W — `event.json` 주석 참조).
  final int ticketMax;
  final int ticketDailyGrant;
  final int ticketAdGrant;
  final int ticketAdDailyLimit;

  /// 출전한 곤충이 다시 나갈 수 있게 되기까지(시간).
  final int fatigueHours;

  /// 이벤트 정규화 기준 스탯. 개체의 수련·돌파·강화·포텐셜·사이즈는 **버린다**.
  final double normBaseHp;
  final double normBaseAtk;
  final double normBaseDef;
  final double normBaseSpd;

  /// 등급별 보너스(0.3 = +30%). 종 기본 스탯을 그대로 쓰면 전설이 일반의
  /// 2~3배라 "전설 보유자가 이긴다"가 된다 — 격차를 여기서 압축한다.
  final Map<Grade, double> gradeBonus;

  final int maxWave;
  final double waveHealPct;
  final int enemyCount;
  final double enemyBaseHp;
  final double enemyBaseAtk;
  final double enemyBaseDef;
  final double enemyBaseSpd;
  final double enemyGrowth;

  final int wavePoint;
  final int hpPoint;
  final int survivorPoint;
  final int speedBase;

  /// 웨이브를 깰 때마다 보여줄 카드 수(0 이면 카드 없음 — 구버전 동작).
  final int cardPicks;
  final List<EventCard> cards;

  /// 웨이브 [wave] 클리어 보상으로 보여줄 카드 [cardPicks] 장.
  ///
  /// **회차 seed + 웨이브**로 뽑으므로 서버·앱이 같은 결과를 낸다. 판마다
  /// 새로 굴리면 "좋은 카드가 나올 때까지 다시 도전"이 되어 운 게임이 된다.
  List<EventCard> drawCards(int roundSeed, int wave) {
    if (cards.isEmpty || cardPicks <= 0) return const [];
    final rng = math.Random(roundSeed * 7717 + wave * 131);
    final pool = [...cards];
    final picked = <EventCard>[];
    for (var i = 0; i < cardPicks && pool.isNotEmpty; i++) {
      final total = pool.fold(0, (s, c) => s + c.weight);
      var r = rng.nextInt(total <= 0 ? 1 : total);
      var idx = 0;
      for (var j = 0; j < pool.length; j++) {
        r -= pool[j].weight;
        if (r < 0) {
          idx = j;
          break;
        }
      }
      picked.add(pool.removeAt(idx));
    }
    return picked;
  }

  EventCard? cardById(String id) {
    for (final c in cards) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// 등급 [g] 의 정규화 배율(설정이 없으면 보너스 없음).
  double gradeMult(Grade g) => 1 + (gradeBonus[g] ?? 0);

  /// 이벤트 규격으로 환산한 스탯.
  ({double hp, double atk, double def, double spd}) normalized(Grade g) {
    final m = gradeMult(g);
    return (
      hp: normBaseHp * m,
      atk: normBaseAtk * m,
      def: normBaseDef * m,
      spd: normBaseSpd * m,
    );
  }

  /// 점수 — 도달 웨이브가 압도적으로 크고, 나머지는 동점을 가르는 잔돈이다.
  ///
  /// [hpPct] 는 마지막으로 **진입한** 웨이브 시작 시점의 팀 체력 비율(0~1).
  int score({
    required int clearedWaves,
    required double hpPct,
    required int survivors,
    required int totalRounds,
  }) {
    final speed = speedBase - totalRounds;
    return clearedWaves * wavePoint +
        (hpPct.clamp(0.0, 1.0) * 100).round() * hpPoint +
        survivors * survivorPoint +
        (speed > 0 ? speed : 0);
  }

  /// 회차 키 — `2026-W34` 형태. 같은 회차의 모든 유저가 같은 웨이브를 만난다.
  ///
  /// 회차 seed 로도 쓰므로 **문자열이 같으면 웨이브도 같아야** 한다.
  static String roundIdOf(DateTime utc) {
    final kst = utc.toUtc().add(const Duration(hours: 9));
    // ISO 주차와 정확히 맞출 필요는 없다 — 회차를 가르는 안정된 키면 된다.
    final dayOfYear = kst.difference(DateTime.utc(kst.year, 1, 1)).inDays;
    final week = dayOfYear ~/ 7;
    return '${kst.year}-W${week.toString().padLeft(2, '0')}';
  }

  /// 회차 키에서 뽑은 seed(전 유저 공통).
  static int roundSeedOf(String roundId) {
    var h = 0;
    for (final c in roundId.codeUnits) {
      h = (h * 31 + c) & 0x3FFFFFFF;
    }
    return h;
  }

  factory EventConfig.fromJson(Map<String, dynamic> json) {
    final round = (json['round'] as Map<String, dynamic>?) ?? const {};
    final tickets = (json['tickets'] as Map<String, dynamic>?) ?? const {};
    final norm = (json['normalize'] as Map<String, dynamic>?) ?? const {};
    final wave = (json['wave'] as Map<String, dynamic>?) ?? const {};
    final score = (json['score'] as Map<String, dynamic>?) ?? const {};
    final bonus = (norm['gradeBonus'] as Map<String, dynamic>?) ?? const {};
    return EventConfig(
      roundDays: (round['days'] as num?)?.toInt() ?? 14,
      anchorWeekday: (round['anchorWeekday'] as num?)?.toInt() ?? 1,
      anchorHourKst: (round['anchorHourKst'] as num?)?.toInt() ?? 9,
      startsAt: round['startsAt'] == null
          ? null
          : DateTime.parse(round['startsAt'] as String).toUtc(),
      endsAt: round['endsAt'] == null
          ? null
          : DateTime.parse(round['endsAt'] as String).toUtc(),
      ticketMax: (tickets['max'] as num?)?.toInt() ?? 5,
      ticketDailyGrant: (tickets['dailyGrant'] as num?)?.toInt() ?? 3,
      ticketAdGrant: (tickets['adGrant'] as num?)?.toInt() ?? 1,
      ticketAdDailyLimit: (tickets['adDailyLimit'] as num?)?.toInt() ?? 2,
      fatigueHours: (json['fatigueHours'] as num?)?.toInt() ?? 24,
      normBaseHp: (norm['baseHp'] as num?)?.toDouble() ?? 120,
      normBaseAtk: (norm['baseAtk'] as num?)?.toDouble() ?? 55,
      normBaseDef: (norm['baseDef'] as num?)?.toDouble() ?? 40,
      normBaseSpd: (norm['baseSpd'] as num?)?.toDouble() ?? 40,
      gradeBonus: {
        for (final e in bonus.entries)
          if (Grade.values.any((g) => g.key == e.key))
            Grade.fromKey(e.key): (e.value as num).toDouble(),
      },
      maxWave: (wave['maxWave'] as num?)?.toInt() ?? 50,
      waveHealPct: (wave['healPct'] as num?)?.toDouble() ?? 0.2,
      enemyCount: (wave['count'] as num?)?.toInt() ?? 3,
      enemyBaseHp: (wave['baseHp'] as num?)?.toDouble() ?? 90,
      enemyBaseAtk: (wave['baseAtk'] as num?)?.toDouble() ?? 26,
      enemyBaseDef: (wave['baseDef'] as num?)?.toDouble() ?? 18,
      enemyBaseSpd: (wave['baseSpd'] as num?)?.toDouble() ?? 30,
      enemyGrowth: (wave['growth'] as num?)?.toDouble() ?? 1.11,
      wavePoint: (score['wavePoint'] as num?)?.toInt() ?? 1000000,
      hpPoint: (score['hpPoint'] as num?)?.toInt() ?? 1000,
      survivorPoint: (score['survivorPoint'] as num?)?.toInt() ?? 100,
      speedBase: (score['speedBase'] as num?)?.toInt() ?? 500,
      cardPicks:
          ((json['cards'] as Map<String, dynamic>?)?['picks'] as num?)
              ?.toInt() ??
          3,
      cards: [
        for (final c
            in ((json['cards'] as Map<String, dynamic>?)?['list'] as List?) ??
                const [])
          EventCard.fromJson(c as Map<String, dynamic>),
      ],
    );
  }
}

import 'package:core_models/core_models.dart';
import 'package:meta/meta.dart';

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
  });

  /// 회차 길이(일)와 리셋 앵커. 시즌과 같은 KST 월요일 09:00 을 쓴다 —
  /// 유저가 "월요일 아침" 하나만 기억하면 되고, 기기 시간대를 바꿔 회차를
  /// 늘리는 우회도 막힌다(§2.7 시즌과 같은 이유).
  final int roundDays;
  final int anchorWeekday;
  final int anchorHourKst;

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
    );
  }
}

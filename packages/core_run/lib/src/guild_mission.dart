import 'dart:math' as math;

import 'package:meta/meta.dart';

import 'run_config.dart';
import 'run_math.dart';

/// 길드 미션(docs/design_guild.md §2, 2026-10-01 2단계).
///
/// 하루(KST 09:00 경계) 3회 출발 · 게시판 5칸(**길드원마다 다름**) · 대기 1·3·10분 중 선택 ·
/// 그 사이 길드원이 **도와주기**로 전투력을 보탠다(최대 3명).
/// 판정·보상은 서버가 이 파일의 함수로 한다. 수치는 `guild.json → mission`.
///
/// 2026-10-01 사장님 확정: 돕는 사람의 몫에 **상한을 두지 않는다**(내가 약해도 센 길드원 한 명이
/// 도와주면 깬다). 대기 시간은 **도움이 다 찰 때까지 계속 흐르고**, 끝나면 합산 전투력으로 판정한다.
/// **도움이 [GuildMissionConfig.helperMax] 명 다 모이면 그 자리에서 성공**이다.
///
/// ⚠️ 요구 전투력 = 출발자 전투력 × 배율이라 출발자 전투력을 부풀려도 요구치가 같이 오른다.
/// 돕는 쪽 전투력은 상한이 없으니 부풀린 값으로 남의 미션을 깨 줄 수 있다 — 얻는 건 재료·코인뿐이고
/// 하루 도움 보상 5회로 막혀 있다(젤리 없음).
@immutable
class GuildMissionConfig {
  const GuildMissionConfig({
    this.dailyStarts = 3,
    this.boardMults = const [0.8, 1.3, 1.8, 2.5, 3.5],
    this.kinds = const ['forest', 'cave', 'swamp', 'ruins', 'canyon', 'meadow'],
    this.waitSeconds = const [60, 180, 600],
    this.waitMults = const [1.0, 1.1, 1.25],
    this.helperMax = 3,
    this.helpRewardsPerDay = 5,
    this.helperRewardShare = 0.5,
    this.partialRewardMult = 0.5,
    this.baseHours = 0.3,
    this.fossilBase = 5,
    this.coinBase = 10,
    this.helperCoins = 5,
    this.expSuccess = 10,
    this.expPartial = 5,
    this.eggChance = 0.05,
    this.eggGrade = 'common',
    this.rewardKeepDays = 7,
    this.dayAnchorHourKst = 9,
    this.pollSeconds = 10,
  });

  /// 하루 출발 횟수(도와주기는 제한 없음 — 보상만 [helpRewardsPerDay]).
  final int dailyStarts;

  /// 게시판 칸마다 요구 전투력 배율(= 보상 배율). 칸 수 = 길이.
  final List<double> boardMults;

  /// 게시판 칸의 이름(분위기) 후보 — 길드·날짜 seed 로 섞어 고른다.
  final List<String> kinds;

  /// 고를 수 있는 대기 시간(초)과 그 보상 배율(오래 기다린 대가).
  final List<int> waitSeconds;
  final List<double> waitMults;

  final int helperMax;

  /// 하루에 보상을 받는 도움 횟수. 그 뒤로도 도울 수는 있다(돕는 게 손해가 되지 않게).
  final int helpRewardsPerDay;

  /// 돕는 사람 보상 = 자기 사냥터 기준 출발자 보상 × 이 비율.
  final double helperRewardShare;

  /// 실패(요구 미달) 보상 = 배율 × 달성률 × 이 값.
  /// ⚠️ 설계 초안의 "최소 30%" 는 넣지 않았다 — 넣으면 가장 어려운 칸(×3.5)을 혼자 실패하는 쪽이
  /// 쉬운 칸(×0.8)을 성공하는 쪽보다 많이 받아(1.05 > 0.8) 모두가 혼자 ×3.5 만 누른다.
  final double partialRewardMult;

  /// 배율 1 짜리 미션 한 번 = 자기 사냥터에서 몇 시간 사냥한 재료인가.
  final double baseHours;

  /// 화석(제련 재료) — 스테이지를 보지 않는다(화석 규칙과 같다).
  final int fossilBase;

  /// 길드 코인(3단계 상점) — 서버 소유 `guild_members.coins`.
  final int coinBase;
  final int helperCoins;

  /// 길드 경험치(3단계 레벨) — 판정 때 한 번.
  final int expSuccess;
  final int expPartial;

  /// 성공한 출발자에게 요정 알(낮은 확률).
  final double eggChance;
  final String eggGrade;

  /// 끝난 미션 보상을 받을 수 있는 기간(일). 지나면 기록째 지운다(테이블 크기 방어).
  final int rewardKeepDays;

  /// 하루 경계(KST 시각) — 결투 시즌·대회 참가권과 같은 09시.
  final int dayAnchorHourKst;

  /// 길드 미션 탭을 **보고 있을 때만** 이 간격으로 조회한다(요금은 조회 수에 선형).
  final int pollSeconds;

  double waitMultOf(int seconds) {
    final i = waitSeconds.indexOf(seconds);
    return i < 0 || i >= waitMults.length ? 1.0 : waitMults[i];
  }

  factory GuildMissionConfig.fromJson(Map<String, dynamic>? j) {
    if (j == null) return const GuildMissionConfig();
    const d = GuildMissionConfig();
    int i(String k, int v) => (j[k] as num?)?.toInt() ?? v;
    double f(String k, double v) => (j[k] as num?)?.toDouble() ?? v;
    List<double> fl(String k, List<double> v) => j[k] is List
        ? [for (final x in j[k] as List) (x as num).toDouble()]
        : v;
    return GuildMissionConfig(
      dailyStarts: i('dailyStarts', d.dailyStarts),
      boardMults: fl('boardMults', d.boardMults),
      kinds: j['kinds'] is List
          ? [for (final x in j['kinds'] as List) '$x']
          : d.kinds,
      waitSeconds: j['waitSeconds'] is List
          ? [for (final x in j['waitSeconds'] as List) (x as num).toInt()]
          : d.waitSeconds,
      waitMults: fl('waitMults', d.waitMults),
      helperMax: i('helperMax', d.helperMax),
      helpRewardsPerDay: i('helpRewardsPerDay', d.helpRewardsPerDay),
      helperRewardShare: f('helperRewardShare', d.helperRewardShare),
      partialRewardMult: f('partialRewardMult', d.partialRewardMult),
      baseHours: f('baseHours', d.baseHours),
      fossilBase: i('fossilBase', d.fossilBase),
      coinBase: i('coinBase', d.coinBase),
      helperCoins: i('helperCoins', d.helperCoins),
      expSuccess: i('expSuccess', d.expSuccess),
      expPartial: i('expPartial', d.expPartial),
      eggChance: f('eggChance', d.eggChance),
      eggGrade: j['eggGrade'] as String? ?? d.eggGrade,
      rewardKeepDays: i('rewardKeepDays', d.rewardKeepDays),
      dayAnchorHourKst: i('dayAnchorHourKst', d.dayAnchorHourKst),
      pollSeconds: i('pollSeconds', d.pollSeconds),
    );
  }
}

/// 하루 키(KST [anchorHour]시 경계). 기기 시간대가 아니라 고정 오프셋 — 시간대를 바꿔
/// 하루에 두 번 받는 우회를 막는다.
String guildDayKey(DateTime utc, {int anchorHour = 9}) {
  final t = utc
      .toUtc()
      .add(const Duration(hours: 9))
      .subtract(Duration(hours: anchorHour));
  String two(int n) => n.toString().padLeft(2, '0');
  return '${t.year}-${two(t.month)}-${two(t.day)}';
}

/// 다음 하루 경계(UTC).
DateTime guildNextDayAt(DateTime utc, {int anchorHour = 9}) {
  final shift = Duration(hours: 9 - anchorHour);
  final local = utc.toUtc().add(shift);
  final next = DateTime.utc(local.year, local.month, local.day + 1);
  return next.subtract(shift);
}

/// 게시판 한 칸.
@immutable
class GuildMissionSlot {
  const GuildMissionSlot({
    required this.slot,
    required this.kind,
    required this.mult,
  });
  final int slot;
  final String kind;
  final double mult;

  Map<String, dynamic> toJson() => {'slot': slot, 'kind': kind, 'mult': mult};
}

/// 그날의 게시판 — **길드원마다 다르다**(유저·날짜 seed, 2026-10-01 사장님 확정). 배율은 칸 순서대로
/// (쉬움 → 어려움) 같고, 미션(분위기)이 사람마다 다르게 섞인다. seed 라 같은 날 다시 열어도 같다.
List<GuildMissionSlot> guildMissionBoard(
  GuildMissionConfig c,
  String userId,
  String dayKey,
) {
  final rng = math.Random(fnv1a32('$userId|$dayKey'));
  final kinds = [...c.kinds]..shuffle(rng);
  return [
    for (var i = 0; i < c.boardMults.length; i++)
      GuildMissionSlot(
        slot: i,
        kind: kinds.isEmpty ? 'forest' : kinds[i % kinds.length],
        mult: c.boardMults[i],
      ),
  ];
}

/// 안정적인 문자열 해시(FNV-1a 32비트). `String.hashCode` 는 실행마다 같다는 보장이 없다.
int fnv1a32(String s) {
  var h = 0x811c9dc5;
  for (final u in s.codeUnits) {
    h ^= u;
    h = (h * 0x01000193) & 0xffffffff;
  }
  return h;
}

/// 판정 — 달성률(0~1)과 성공 여부, 보상 배수(성공 1 · 실패 달성률 × [GuildMissionConfig.partialRewardMult]).
({double ratio, bool success, double factor}) guildMissionOutcome(
  GuildMissionConfig c, {
  required double total,
  required double need,
}) {
  final ratio = need <= 0 ? 1.0 : (total / need).clamp(0.0, 1.0).toDouble();
  final success = ratio >= 1.0;
  return (
    ratio: ratio,
    success: success,
    factor: success ? 1.0 : ratio * c.partialRewardMult,
  );
}

/// 미션 보상 한 몫.
@immutable
class GuildMissionReward {
  const GuildMissionReward({
    this.chitin = 0,
    this.mineral = 0,
    this.sap = 0,
    this.fossil = 0,
    this.coins = 0,
  });
  final int chitin;
  final int mineral;
  final int sap;
  final int fossil;
  final int coins;

  bool get isEmpty =>
      chitin == 0 && mineral == 0 && sap == 0 && fossil == 0 && coins == 0;

  GuildMissionReward operator +(GuildMissionReward o) => GuildMissionReward(
    chitin: chitin + o.chitin,
    mineral: mineral + o.mineral,
    sap: sap + o.sap,
    fossil: fossil + o.fossil,
    coins: coins + o.coins,
  );

  Map<String, dynamic> toJson() => {
    'chitin': chitin,
    'mineral': mineral,
    'sap': sap,
    'fossil': fossil,
    'coins': coins,
  };
}

/// 한 사람의 보상 — **자기 사냥터(스테이지)** 기준이다. 돕는 사람도 출발자의 사냥터가 아니라 자기 것으로
/// 잰다(쉬움 유저가 극한 친구를 도와 재료를 2,900배 받는 구멍을 막는다 — 재료가 `1.008^스테이지`).
///
/// [factor] = [guildMissionOutcome] 의 보상 배수, [waitMult] = 대기 배율(혼자 바로 성공이면 1),
/// [helper] 면 [GuildMissionConfig.helperRewardShare] 를 곱하고 코인은 고정.
GuildMissionReward guildMissionReward(
  GuildMissionConfig c,
  RunConfig run, {
  required int stage,
  required double mult,
  required double factor,
  double waitMult = 1.0,
  bool helper = false,
}) {
  final share = helper ? c.helperRewardShare : 1.0;
  final scale = mult * factor * waitMult * share;
  final each =
      materialAmountMult(run, stage) *
      run.exchangeKillsPerHour *
      c.baseHours *
      scale /
      3;
  final e = each.isFinite ? each.round() : 0;
  return GuildMissionReward(
    chitin: e,
    mineral: e,
    sap: e,
    fossil: (c.fossilBase * scale).round(),
    coins: helper
        ? (factor > 0 ? c.helperCoins : 0)
        : (c.coinBase * mult * factor).round(),
  );
}

/// 혼자 출발해도 바로 성공하는 칸인가 — 요구 = 내 전투력 × 배율이라 배율 ≤ 1 이면 혼자로 충분하다.
/// 이 칸은 **대기 배율을 받지 않는다**(바로 끝났는데 10분 배율을 받는 구멍). 서버 출발·앱 예상 보상 공용.
bool guildMissionSoloSlot(double mult) => mult <= 1.0;

/// 길드 버프 "미션 보상"([bonus], 0.2 = +20%) — **재료·화석만** 늘린다. 코인은 그대로
/// (코인 상점 가격이 흔들리지 않게). 서버 수령·앱 예상 보상 공용.
GuildMissionReward guildMissionBoost(GuildMissionReward r, double bonus) =>
    bonus <= 0
    ? r
    : GuildMissionReward(
        chitin: (r.chitin * (1 + bonus)).round(),
        mineral: (r.mineral * (1 + bonus)).round(),
        sap: (r.sap * (1 + bonus)).round(),
        fossil: (r.fossil * (1 + bonus)).round(),
        coins: r.coins,
      );

/// 출발 전 **성공했을 때 받을 보상**(게시판 카드·대기 시간 고르기 화면).
///
/// 서버가 수령 때 쓰는 [guildMissionReward] · [guildMissionBoost] 를 그대로 부른다 — 로직이 두 벌이면
/// "화면엔 120 이라더니 100 들어왔다"가 생긴다. [stage] 는 자기 사냥터(서버도 출발 순간 서버 세이브의
/// 스테이지를 쓴다), [bonus] 는 길드 버프 "미션 보상". [helper] 면 도와준 사람 몫(자기 사냥터 기준 × 비율).
/// 실패하면 이 값 × 달성률 × [GuildMissionConfig.partialRewardMult](재료·화석·코인, 도우미 코인은 그대로).
GuildMissionReward guildMissionExpected(
  GuildMissionConfig c,
  RunConfig run, {
  required int stage,
  required double mult,
  required int waitSec,
  double bonus = 0,
  bool helper = false,
}) {
  final waitMult = !helper && guildMissionSoloSlot(mult)
      ? 1.0
      : c.waitMultOf(waitSec);
  return guildMissionBoost(
    guildMissionReward(
      c,
      run,
      stage: stage < 1 ? 1 : stage,
      mult: mult,
      factor: 1.0,
      waitMult: waitMult,
      helper: helper,
    ),
    bonus,
  );
}

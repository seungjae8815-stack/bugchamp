import 'package:core_run/core_run.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 방치 런 화면의 기기 설정 — **보스 자동 도전**과 첫 보스 안내 기록(2026-10-08 사장님 확정).
///
/// 신규 유저 다수가 쉬움 사냥터 1 에서 수만 마리를 잡고도 보스를 한 번도 도전하지 않았다
/// ([보스 도전] 버튼을 몰랐다). 그래서 게이지가 차면 잠깐 뒤 스스로 도전하는 것을 **기본**으로 둔다.
///
/// 세이브가 아니라 기기 설정이다([NotifyPrefs] 와 같은 방식) — 진행·보상과 무관한 화면 흐름이라
/// 서버 동기화·구버전 앱 호환(`feat`)을 건드릴 이유가 없다. 오프라인/방치 정산에는 영향이 없다.
class PlayPrefs {
  PlayPrefs._();
  static final PlayPrefs instance = PlayPrefs._();

  static const _kAutoBoss = 'play.autoBoss';
  static const _kBossIntro = 'play.bossIntroSeen';
  static const _kDailyAuto = 'play.dailyAutoShown';
  static const _kBuffSheet = 'play.buffSheetSeen';
  static const _kBugDetailMore = 'play.bugDetailMore';
  static const _kTipPet = 'play.tipPetShown';
  static const _kTipGear = 'play.tipGearShown';
  static const _kTour = 'play.tourDone';
  static const _kTourNew = 'play.tourEligible';
  static const _kTabTours = 'play.tabToursSeen';

  /// 게이지(100마리)가 차면 자동으로 보스에 도전한다. 기본 켬.
  final ValueNotifier<bool> autoBoss = ValueNotifier(true);

  /// 처음 게이지가 찼을 때의 안내 팝업을 이미 보여 줬는가.
  bool bossIntroSeen = false;

  /// 일일보상 창을 마지막으로 저절로 띄운 시간대([dailyAutoOpenKey] 값). 시간대마다 한 번만 띄운다.
  String? dailyAutoShown;

  /// 버프 창을 한 번이라도 열어 봤는가 — 그 뒤엔 꺼진 버프에 빨간 점을 달지 않는다(맥동만).
  bool buffSheetSeen = false;

  /// 펫·장비 첫 안내(사냥터 2 부터, 한 번씩)를 이미 띄웠는가.
  bool tipPetShown = false;
  bool tipGearShown = false;

  /// 첫 실행 화면 둘러보기(튜토리얼)를 끝냈거나 건너뛰었는가.
  bool tourDone = false;

  /// 첫 실행 둘러보기를 실제로 본 기기(새 계정) — 탭 첫 방문 안내는 이 기기에만 띄운다(기존 유저 귀찮지 않게).
  bool tourEligible = false;

  /// 탭 첫 방문 안내를 본 탭 번호.
  Set<int> tabToursSeen = {};

  /// 곤충 상세의 "성장·능력치 자세히"를 펼쳐 둘지 — 유저가 고른 적 없으면 null(진행도로 정한다,
  /// [bugDetailMoreDefault]). 한 번 펼치거나 접으면 그 선택을 기억한다.
  final ValueNotifier<bool?> bugDetailMore = ValueNotifier(null);

  /// [load] 가 끝났는가 — 끝나기 전엔 자동 도전·안내를 걸지 않는다
  /// (기본값으로 먼저 돌면 이미 본 안내가 다시 뜨거나, 끈 자동 도전이 한 번 돈다).
  bool loaded = false;

  SharedPreferences? _prefs;

  Future<void> load() async {
    try {
      final p = _prefs = await SharedPreferences.getInstance();
      autoBoss.value = p.getBool(_kAutoBoss) ?? true;
      bossIntroSeen = p.getBool(_kBossIntro) ?? false;
      dailyAutoShown = p.getString(_kDailyAuto);
      buffSheetSeen = p.getBool(_kBuffSheet) ?? false;
      bugDetailMore.value = p.getBool(_kBugDetailMore);
      tipPetShown = p.getBool(_kTipPet) ?? false;
      tipGearShown = p.getBool(_kTipGear) ?? false;
      tourDone = p.getBool(_kTour) ?? false;
      tourEligible = p.getBool(_kTourNew) ?? false;
      tabToursSeen = {
        for (final v in p.getStringList(_kTabTours) ?? const <String>[])
          ?int.tryParse(v),
      };
    } catch (e) {
      debugPrint('PlayPrefs.load 실패(기본값 사용): $e');
    }
    loaded = true;
  }

  Future<void> setAutoBoss(bool v) async {
    autoBoss.value = v;
    await _prefs?.setBool(_kAutoBoss, v);
  }

  Future<void> markBossIntroSeen() async {
    bossIntroSeen = true;
    await _prefs?.setBool(_kBossIntro, true);
  }

  Future<void> markDailyAutoShown(String key) async {
    dailyAutoShown = key;
    await _prefs?.setString(_kDailyAuto, key);
  }

  Future<void> markBuffSheetSeen() async {
    buffSheetSeen = true;
    await _prefs?.setBool(_kBuffSheet, true);
  }

  Future<void> markTipPetShown() async {
    tipPetShown = true;
    await _prefs?.setBool(_kTipPet, true);
  }

  Future<void> markTipGearShown() async {
    tipGearShown = true;
    await _prefs?.setBool(_kTipGear, true);
  }

  Future<void> markTourDone() async {
    tourDone = true;
    await _prefs?.setBool(_kTour, true);
  }

  Future<void> markTourEligible() async {
    tourEligible = true;
    await _prefs?.setBool(_kTourNew, true);
  }

  Future<void> markTabTourSeen(int tab) async {
    tabToursSeen = {...tabToursSeen, tab};
    await _prefs?.setStringList(_kTabTours, [
      for (final t in tabToursSeen) '$t',
    ]);
  }

  Future<void> setBugDetailMore(bool v) async {
    bugDetailMore.value = v;
    await _prefs?.setBool(_kBugDetailMore, v);
  }

  /// 테스트용 — 싱글턴을 처음 상태로.
  @visibleForTesting
  void resetForTest() {
    autoBoss.value = true;
    bossIntroSeen = false;
    dailyAutoShown = null;
    buffSheetSeen = false;
    bugDetailMore.value = null;
    tipPetShown = false;
    tipGearShown = false;
    tourDone = false;
    tourEligible = false;
    tabToursSeen = {};
    loaded = false;
    _prefs = null;
  }
}

/// 일일보상 창을 저절로 띄울 시간대 열쇠(`날짜:보상id`) — 띄울 것이 없으면 null(2026-11-09 사장님 확정).
///
/// 일일보상(점심·저녁 사냥 분치)이 하루 골드의 대부분인데 우편 아이콘 안에만 있어서, 운영 DB 상
/// 쉬움 사냥터 1 유저의 73% 가 한 번도 받지 않았다(받는 유저와 진행 속도가 약 6배 갈렸다).
/// 열쇠는 **지금 열린 가장 늦은 시간대**(받았는지와 무관)다 — 그래야 저녁 창에서 저녁만 받고 닫아도
/// 열쇠가 점심으로 바뀌어 다시 뜨지 않는다(2026-11-09 검토). 열린 시간대 중 안 받은 것이 하나라도 있을 때만
/// 띄우고, 이미 띄운 열쇠([lastShown])면 다시 띄우지 않는다 — 닫고 안 받아도 그 시간대에는 한 번뿐.
/// 날짜·시각은 수령 판정([dailyDateKey])과 같은 기기 시각.
String? dailyAutoOpenKey(
  DailyConfig daily,
  Map<String, String> claims,
  DateTime localNow,
  String? lastShown,
) {
  final today = dailyDateKey(localNow);
  DailyReward? latest;
  var unclaimed = false;
  for (final rw in daily.rewards) {
    if (localNow.hour < rw.hour) continue;
    if (latest == null || rw.hour >= latest.hour) latest = rw;
    if (claims[rw.id] != today) unclaimed = true;
  }
  if (latest == null || !unclaimed) return null;
  final key = '$today:${latest.id}';
  return key == lastShown ? null : key;
}

/// 보스 자동 도전 카운트다운.
///
/// [tick] 에 매 프레임 "지금 도전할 수 있는 상태인가([armed])"를 넘긴다. 조건이 이어지는 동안
/// [seconds] 를 세고, 다 세면 한 번 `true` 를 돌려준다. 조건이 한 번이라도 깨지면
/// (자동 끔·도전 시작·쓰러짐·다른 탭·팝업이 위에 뜸) 처음부터 다시 센다.
///
/// 보스 도전에 실패해 게이지가 비면 다시 100마리 뒤에 같은 흐름으로 재도전한다 — 그게 진행 리듬이다.
class AutoBossCountdown {
  AutoBossCountdown({this.seconds = 3});

  /// 화면에 보여 주는 대기 시간(초). 밸런스 수치가 아니라 화면 연출이다.
  final double seconds;

  double? _left;

  /// 남은 시간(초). 세고 있지 않으면 null.
  double? get left => _left;

  /// 버튼에 띄울 남은 초(올림). 세고 있지 않으면 null.
  int? get secondsLeft => _left?.ceil().clamp(1, 99);

  bool tick(double dt, {required bool armed}) {
    if (!armed) {
      _left = null;
      return false;
    }
    final left = (_left ?? seconds) - dt;
    // 프레임 dt 를 더해 가면 부동소수 오차가 남는다(0.05 × 60 = 2.9999…) — 아주 작은 여유를 둔다.
    if (left <= 1e-6) {
      _left = null;
      return true;
    }
    _left = left;
    return false;
  }

  void reset() => _left = null;
}

/// 자동 도전 연패 멈춤(2026-10-09 사장님 확정).
///
/// 보스는 "겨우 잡히는" 체력이라 아직 약할 때 자동 도전을 그대로 두면 100마리마다 지고 게이지가 비워지는
/// 일이 끝없이 반복된다. 그래서 **같은 사냥터에서 자동 도전이 [maxFails] 번 연달아 지면** 그 사냥터에서는
/// 자동을 멈춘다([보스 도전] 버튼은 그대로 — 강해진 뒤 직접 누른다).
///
/// - 직접 눌러 진 도전은 세지도 비우지도 않는다(자동 도전의 연패만 센다).
/// - 보스를 잡거나(직접·자동) 다른 사냥터로 가면 기록이 비워져 다시 자동으로 도전한다.
/// - 기기 메모리에만 둔다 — 앱을 다시 켜면 처음부터(그사이 강해졌을 수 있다).
class AutoBossFailGuard {
  AutoBossFailGuard({this.maxFails = 2});

  /// 이만큼 연달아 지면 그 사냥터의 자동 도전을 멈춘다(화면 흐름 규칙 — 밸런스 수치가 아니다).
  final int maxFails;

  String? _zone;
  int _fails = 0;

  /// 지금 사냥터에서 연달아 진 자동 도전 수.
  int get fails => _fails;

  /// 지금 있는 사냥터를 알린다 — 바뀌었으면 기록을 비운다.
  void enter(String zone) {
    if (zone == _zone) return;
    _zone = zone;
    _fails = 0;
  }

  /// [zone] 에서 자동 도전이 멈췄는가.
  bool pausedAt(String zone) => _zone == zone && _fails >= maxFails;

  /// [zone] 에서 자동으로 건 도전이 졌다. 이번에 멈췄으면 true.
  bool recordAutoFail(String zone) {
    enter(zone);
    _fails++;
    return _fails >= maxFails;
  }

  /// 보스를 잡았다(직접·자동 모두) — 다시 자동으로 도전한다.
  void recordWin() => _fails = 0;
}

/// 곤충 상세의 "성장·능력치 자세히"를 처음에 펼쳐 둘지(2026-11-09 사장님 확정) — 유저가 고른 적 없을 때.
///
/// 상세 시트에 카드·버튼이 약 20개였고(품질 9칸·패시브·훈련·등급 올리기), 쉬움 사냥터 1~3 유저 대부분이
/// 그 단계에서 떠났다. 그래서 **쉬움 사냥터 3 전**에는 접어 두고 "이 곤충이 나에게 무엇을 해 주나"만 보인다.
/// 사냥터 3 이상·보통 이상 유저(기존 유저 대부분)는 예전처럼 펼친 채다 — 손에 익은 화면을 바꾸지 않는다.
bool bugDetailMoreDefault({required int topTier, required int bestStage}) =>
    topTier > 0 || bestStage >= 201;

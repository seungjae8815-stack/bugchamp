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

  /// 게이지(100마리)가 차면 자동으로 보스에 도전한다. 기본 켬.
  final ValueNotifier<bool> autoBoss = ValueNotifier(true);

  /// 처음 게이지가 찼을 때의 안내 팝업을 이미 보여 줬는가.
  bool bossIntroSeen = false;

  /// [load] 가 끝났는가 — 끝나기 전엔 자동 도전·안내를 걸지 않는다
  /// (기본값으로 먼저 돌면 이미 본 안내가 다시 뜨거나, 끈 자동 도전이 한 번 돈다).
  bool loaded = false;

  SharedPreferences? _prefs;

  Future<void> load() async {
    try {
      final p = _prefs = await SharedPreferences.getInstance();
      autoBoss.value = p.getBool(_kAutoBoss) ?? true;
      bossIntroSeen = p.getBool(_kBossIntro) ?? false;
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

  /// 테스트용 — 싱글턴을 처음 상태로.
  @visibleForTesting
  void resetForTest() {
    autoBoss.value = true;
    bossIntroSeen = false;
    loaded = false;
    _prefs = null;
  }
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

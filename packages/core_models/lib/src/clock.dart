/// 시간 공급 추상화 (§기술스택: 서버시간 보정 인터페이스).
///
/// 기기 시간 조작 방어를 위해, 게임 로직은 [DateTime.now] 를 직접 부르지 않고
/// 항상 주입된 [Clock] 을 통해 현재 시각을 얻는다.
/// 초기엔 [LocalClock], 이후 서버 보정 구현으로 교체 가능하다.
abstract interface class Clock {
  DateTime now();
}

/// 기기 로컬 시간을 그대로 쓰는 기본 구현. (Phase 1)
class LocalClock implements Clock {
  const LocalClock();

  @override
  DateTime now() => DateTime.now();
}

/// 고정 시각 Clock (테스트·재현용).
class FixedClock implements Clock {
  FixedClock(this._time);

  DateTime _time;

  /// 현재 반환할 시각을 바꾼다(시간 경과 시뮬레이션).
  set time(DateTime value) => _time = value;

  void advance(Duration d) => _time = _time.add(d);

  @override
  DateTime now() => _time;
}

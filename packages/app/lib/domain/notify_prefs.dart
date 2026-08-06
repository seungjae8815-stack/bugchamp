import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 알림 종류별 on/off (기기 로컬).
///
/// 알림을 늘리면서 끌 수단이 없으면 그냥 앱을 지운다 — 종류마다 따로 끌 수
/// 있어야 한다. 세이브가 아니라 기기 설정이다(기기마다 다른 게 자연스럽다).
@immutable
class NotifySettings {
  const NotifySettings({
    this.enabled = true,
    this.offlineFull = true,
    this.hatchDone = true,
    this.daily = true,
  });

  /// 알림 전체 스위치. 끄면 개별 설정과 무관하게 아무것도 보내지 않는다.
  final bool enabled;

  /// 오프라인 보상이 가득 찼을 때(8시간).
  final bool offlineFull;

  /// 부화가 끝났을 때.
  final bool hatchDone;

  /// 일일 보상 시각 안내.
  final bool daily;

  NotifySettings copyWith({
    bool? enabled,
    bool? offlineFull,
    bool? hatchDone,
    bool? daily,
  }) => NotifySettings(
    enabled: enabled ?? this.enabled,
    offlineFull: offlineFull ?? this.offlineFull,
    hatchDone: hatchDone ?? this.hatchDone,
    daily: daily ?? this.daily,
  );
}

/// [NotifySettings] 를 기기에 읽고 쓰는 싱글턴. [AudioService] 와 같은 방식이라
/// Riverpod 없는 자리에서도 바로 쓸 수 있다.
class NotifyPrefs {
  NotifyPrefs._();
  static final NotifyPrefs instance = NotifyPrefs._();

  final ValueNotifier<NotifySettings> settings = ValueNotifier(
    const NotifySettings(),
  );

  SharedPreferences? _prefs;

  Future<void> load() async {
    try {
      final p = _prefs = await SharedPreferences.getInstance();
      settings.value = NotifySettings(
        enabled: p.getBool('notify.enabled') ?? true,
        offlineFull: p.getBool('notify.offlineFull') ?? true,
        hatchDone: p.getBool('notify.hatchDone') ?? true,
        daily: p.getBool('notify.daily') ?? true,
      );
    } catch (e) {
      debugPrint('NotifyPrefs.load 실패(기본값 사용): $e');
    }
  }

  Future<void> setEnabled(bool v) async {
    settings.value = settings.value.copyWith(enabled: v);
    await _prefs?.setBool('notify.enabled', v);
  }

  Future<void> setOfflineFull(bool v) async {
    settings.value = settings.value.copyWith(offlineFull: v);
    await _prefs?.setBool('notify.offlineFull', v);
  }

  Future<void> setHatchDone(bool v) async {
    settings.value = settings.value.copyWith(hatchDone: v);
    await _prefs?.setBool('notify.hatchDone', v);
  }

  Future<void> setDaily(bool v) async {
    settings.value = settings.value.copyWith(daily: v);
    await _prefs?.setBool('notify.daily', v);
  }
}

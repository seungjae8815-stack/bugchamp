import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// 로컬 알림(점심·저녁 보상, 오프라인 보상 가득참).
///
/// 문구는 호출측(AppShell)이 현지화해 넘긴다(서비스는 데이터를 모른다).
/// 예약은 `zonedSchedule`(inexact) — 정확 알람 권한(SCHEDULE_EXACT_ALARM) 불필요.
/// 안드로이드 13+ 는 첫 실행 시 알림 권한을 요청한다.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  /// 오프라인 가득참 알림 id(고정). 일일 보상은 1부터 사용.
  static const int offlineId = 900;

  /// 부화 완료 알림 id 대역. 알 여러 개가 각자 다른 시각에 끝나므로
  /// 슬롯마다 다른 id 를 써야 서로 덮어쓰지 않는다.
  static const int hatchIdBase = 910;

  /// 깜짝선물 알림 id.
  static const int giftId = 905;

  /// 야간 휴식 시작·종료 시각(로컬). 이 사이에 잡힌 알림은 아침으로 미룬다.
  static const int quietFromHour = 22;
  static const int quietToHour = 8;

  /// [quiet] 이면 야간(22~08)에 잡힌 시각을 **다음 아침 8시**로 옮긴다.
  /// 잠든 사이 울리는 알림은 알림 자체를 꺼버리게 만든다.
  tz.TZDateTime _avoidQuiet(tz.TZDateTime t, {required bool quiet}) {
    if (!quiet) return t;
    if (t.hour >= quietFromHour) {
      return tz.TZDateTime(
        tz.local,
        t.year,
        t.month,
        t.day,
        quietToHour,
      ).add(const Duration(days: 1));
    }
    if (t.hour < quietToHour) {
      return tz.TZDateTime(tz.local, t.year, t.month, t.day, quietToHour);
    }
    return t;
  }

  /// 깜짝선물이 쌓였을 무렵 1회. 선물은 10~25분마다 생기므로 **매번 알리면
  /// 성가시다** — 백그라운드 진입 후 한 번만 부른다.
  Future<void> scheduleGift({
    required Duration after,
    required String title,
    required String body,
    bool quiet = true,
  }) async {
    if (!_ready) return;
    try {
      final at = _avoidQuiet(
        tz.TZDateTime.now(tz.local).add(after),
        quiet: quiet,
      );
      await _plugin.zonedSchedule(
        giftId,
        title,
        body,
        at,
        _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint('scheduleGift failed: $e');
    }
  }

  Future<void> cancelGift() async {
    try {
      await _plugin.cancel(giftId);
    } catch (_) {}
  }

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'bugchamp_daily',
    '보상 알림',
    description: '점심·저녁 보상, 오프라인 보상 가득참 알림',
    importance: Importance.defaultImportance,
  );

  Future<void> init() async {
    if (_ready) return;
    try {
      tzdata.initializeTimeZones();
      // 한국 우선 — 기기 타임존 감지는 추후(flutter_timezone). 기본 Asia/Seoul.
      tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      // iOS: 권한은 requestPermission() 에서 타이밍을 제어해 따로 요청 → 여기선 false.
      const darwinInit = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      await _plugin.initialize(
        const InitializationSettings(android: androidInit, iOS: darwinInit),
      );
      await _android?.createNotificationChannel(_channel);
      _ready = true;
    } catch (e) {
      debugPrint('NotificationService init failed: $e');
    }
  }

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  IOSFlutterLocalNotificationsPlugin? get _ios => _plugin
      .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin
      >();

  /// 알림 권한 요청(Android 13+ / iOS). 이미 허용·거부면 무시됨.
  Future<void> requestPermission() async {
    try {
      await _android?.requestNotificationsPermission();
      await _ios?.requestPermissions(alert: true, badge: true, sound: true);
    } catch (_) {}
  }

  NotificationDetails get _details => NotificationDetails(
    android: AndroidNotificationDetails(
      _channel.id,
      _channel.name,
      channelDescription: _channel.description,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    ),
    iOS: const DarwinNotificationDetails(),
  );

  tz.TZDateTime _nextAt(int hour) {
    final now = tz.TZDateTime.now(tz.local);
    var t = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour);
    if (!t.isAfter(now)) t = t.add(const Duration(days: 1));
    return t;
  }

  /// [hour] 시에 매일 반복되는 보상 알림 예약(같은 [id] 는 덮어씀).
  Future<void> scheduleDaily({
    required int id,
    required int hour,
    required String title,
    required String body,
  }) async {
    if (!_ready) return;
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        _nextAt(hour),
        _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time, // 매일 같은 시각 반복
      );
    } catch (e) {
      debugPrint('scheduleDaily($id) failed: $e');
    }
  }

  /// 앱이 백그라운드로 갈 때 호출 — [after] 뒤(오프라인 상한 도달) 1회 알림.
  Future<void> scheduleOfflineFull({
    required Duration after,
    required String title,
    required String body,
    bool quiet = true,
  }) async {
    if (!_ready) return;
    try {
      await _plugin.zonedSchedule(
        offlineId,
        title,
        body,
        _avoidQuiet(tz.TZDateTime.now(tz.local).add(after), quiet: quiet),
        _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint('scheduleOfflineFull failed: $e');
    }
  }

  /// 부화 완료 예정 시각마다 1회 알림. 이미 지난 시각은 건너뛴다.
  ///
  /// 부화는 앱을 꺼둔 채 기다리는 시간이라, 끝난 걸 알려주지 않으면 알이 다
  /// 익은 채 방치된다 — 복귀를 만드는 알림이다.
  Future<void> scheduleHatches(
    List<DateTime> endsAt, {
    required String title,
    required String body,
    bool quiet = true,
  }) async {
    if (!_ready) return;
    await cancelHatches();
    final now = tz.TZDateTime.now(tz.local);
    var i = 0;
    for (final t in endsAt) {
      if (i >= 8) break; // 부화기 슬롯 상한을 넉넉히 덮는다
      final at = _avoidQuiet(
        tz.TZDateTime.from(t.toLocal(), tz.local),
        quiet: quiet,
      );
      if (!at.isAfter(now)) continue;
      try {
        await _plugin.zonedSchedule(
          hatchIdBase + i,
          title,
          body,
          at,
          _details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
        i++;
      } catch (e) {
        debugPrint('scheduleHatches failed: $e');
      }
    }
  }

  Future<void> cancelHatches() async {
    for (var i = 0; i < 8; i++) {
      try {
        await _plugin.cancel(hatchIdBase + i);
      } catch (_) {}
    }
  }

  /// 앱 복귀 시 오프라인 알림 취소(이미 접속했으니 불필요).
  Future<void> cancelOfflineFull() async {
    try {
      await _plugin.cancel(offlineId);
    } catch (_) {}
  }
}

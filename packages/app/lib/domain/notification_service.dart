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
      await _plugin.initialize(
        const InitializationSettings(android: androidInit),
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

  /// 안드로이드 13+ 알림 권한 요청(이미 허용/거부면 무시됨).
  Future<void> requestPermission() async {
    try {
      await _android?.requestNotificationsPermission();
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
  }) async {
    if (!_ready) return;
    try {
      await _plugin.zonedSchedule(
        offlineId,
        title,
        body,
        tz.TZDateTime.now(tz.local).add(after),
        _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint('scheduleOfflineFull failed: $e');
    }
  }

  /// 앱 복귀 시 오프라인 알림 취소(이미 접속했으니 불필요).
  Future<void> cancelOfflineFull() async {
    try {
      await _plugin.cancel(offlineId);
    } catch (_) {}
  }
}

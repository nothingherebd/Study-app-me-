import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    tzdata.initializeTimeZones();
    try {
      final String tzName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzName));
    } catch (_) {
      // Falls back to whatever default the timezone package picked.
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );

    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.requestNotificationsPermission();
    await androidImpl?.requestExactAlarmsPermission();
  }

  static NotificationDetails _details() {
    const android = AndroidNotificationDetails(
      'bcs_planner_channel',
      'Study Reminders',
      channelDescription: 'Alarms and subject/task reminders',
      importance: Importance.max,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
    );
    const ios = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    return const NotificationDetails(android: android, iOS: ios);
  }

  /// Stable positive 32-bit id derived from a string id + weekday,
  /// so each weekday of a repeating alarm/subject gets its own slot
  /// and can be individually cancelled/rescheduled.
  static int _stableId(String baseId, int weekday) {
    final h = baseId.hashCode & 0x7fffffff;
    return (h % 100000) * 10 + weekday;
  }

  static tz.TZDateTime _nextInstanceOfWeekdayTime(
      int weekday, int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    while (scheduled.weekday != weekday || !scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  /// Schedules a weekly-repeating notification for each weekday in [weekdays]
  /// (1 = Monday ... 7 = Sunday, matching DateTime.weekday).
  static Future<void> scheduleWeekly({
    required String baseId,
    required String title,
    required String body,
    required int hour,
    required int minute,
    required List<int> weekdays,
  }) async {
    await cancelWeekly(baseId);
    for (final wd in weekdays) {
      final id = _stableId(baseId, wd);
      final scheduled = _nextInstanceOfWeekdayTime(wd, hour, minute);
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduled,
        _details(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }

  static Future<void> cancelWeekly(String baseId) async {
    for (var wd = 1; wd <= 7; wd++) {
      await _plugin.cancel(_stableId(baseId, wd));
    }
  }

  /// Schedules a single one-off notification (used for a task's own
  /// start-time reminder, which only applies to one specific date).
  static Future<void> scheduleOnce({
    required String baseId,
    required String title,
    required String body,
    required DateTime when,
  }) async {
    final tzWhen = tz.TZDateTime.from(when, tz.local);
    if (!tzWhen.isAfter(tz.TZDateTime.now(tz.local))) return;
    final id = _stableId(baseId, 0);
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tzWhen,
      _details(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<void> cancelOnce(String baseId) async {
    await _plugin.cancel(_stableId(baseId, 0));
  }

  static Future<void> testNotificationNow() async {
    await _plugin.show(
      999999,
      '🔔 Test notification',
      'If you see this, native alarms are working.',
      _details(),
    );
  }
}

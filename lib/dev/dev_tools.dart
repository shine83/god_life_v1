import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_new_test_app/services/notification_service.dart';
import 'package:my_new_test_app/services/health_service.dart';

class DevTools {
  /// 앱 내 알림 전부 취소
  static Future<void> cancelAllNotifications() async {
    await FlutterLocalNotificationsPlugin().cancelAll();
  }

  /// 알림 관련 프리퍼런스만 리셋
  static Future<void> resetNotificationPrefs() async {
    final p = await SharedPreferences.getInstance();
    await p.remove('notif_enabled');
    await p.remove('notif_offsets');
    await p.remove('notif_exact_alarm_prompted_at');
  }

  /// 헬스 캐시만 리셋 (계정/서버 데이터 영향 없음)
  static Future<void> resetHealthCache() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(HealthService.kCapturedAt);
    await p.remove(HealthService.kSteps);
    await p.remove(HealthService.kActiveCalories);
    await p.remove(HealthService.kBmi);
    await p.remove('health_sleep_asleep');
    await p.remove('health_sleep_in_bed');
    await p.remove(HealthService.kSleepTotal);
    await p.remove(HealthService.kSleepDeep);
    await p.remove(HealthService.kSleepRem);
    await p.remove(HealthService.kHeartRateResting);
    await p.remove(HealthService.kHeartRateMin);
    await p.remove(HealthService.kHeartRateMax);
  }

  /// 오프셋 빠르게 세팅 (예: 1,2분로 테스트 속도↑)
  static Future<void> setQuickOffsets(List<int> minutesDesc) async {
    await NotificationService.I.setOffsets(minutesDesc);
  }

  /// 10초 후 테스트 알림(전면/일반) 즉발
  static Future<void> fireTestAlarm({bool alarmStyle = false}) async {
    await NotificationService.I.scheduleTestIn10s(alarmStyle: alarmStyle);
  }
}

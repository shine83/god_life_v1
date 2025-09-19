// lib/services/notification_service.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';

// 타임존
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

// (선택) Android 정확 알람 설정 화면 열기
import 'package:android_intent_plus/android_intent.dart';

// 프리미엄 여부
import 'package:my_new_test_app/core/premium/premium_gate_compat.dart';

/// ──────────────────────────────────────────────────────────────
/// Android 액션 ID
const _kActionStop = 'STOP_ALARM';
const _kActionSnooze5 = 'SNOOZE_5';

/// 백그라운드 탭 콜백 (필요시 사용)
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  // 필요시 처리 (백그라운드에서 액션 응답 수신)
}

/// 로컬 알림(근무 N분 전) 전담 서비스
class NotificationService {
  NotificationService._();
  static final NotificationService I = NotificationService._();

  final _fln = FlutterLocalNotificationsPlugin();

  // 메인에서 쓰는 포그라운드 콜백: (id, title, body, payload)
  void Function(int id, String? title, String? body, String? payload)?
      onForeground;

  // 알림 탭 콜백(payload)
  void Function(String? payload)? onSelect;

  // 미리듣기 오디오
  final AudioPlayer _previewPlayer = AudioPlayer();
  bool _isPreviewing = false;
  String? _previewingKey;

  bool get isPreviewing => _isPreviewing;
  String? get previewingKey => _previewingKey;

  // ─────────────────────────────────────────────
  // 공용 설정 저장 키
  static const _prefEnabled = 'notif_enabled';
  static const _prefOffsets = 'notif_offsets'; // "60,30" (분)
  static const _prefPremiumSound = 'notif_premium_sound';

  // 무료용 채널
  static const _androidChannelIdFree = 'shift_channel_free';
  static const _androidChannelNameFree = 'Shift Reminders (Free)';
  static const _androidChannelDescFree = '무료용 - 기본 알림 사운드';

  // 프리미엄 채널 생성자 (채널 캐시 회피용 v2 suffix)
  String _androidPremiumChannelIdFor(String key) => 'shift_alarm_${key}_v2';
  String _androidPremiumChannelNameFor(String key) => 'Shift Alarm ($key)';

  // 프리미엄 사운드 세트 (1~9)
  static const int _premiumCount = 9;
  static final List<String> premiumKeys =
      List.generate(_premiumCount, (i) => 'premium${i + 1}');

  /// Android raw 리소스명(확장자 X)
  static final Map<String, String> premiumSoundsAndroid = {
    for (var i = 1; i <= _premiumCount; i++) 'premium$i': 'alarm_premium$i',
  };

  /// iOS 번들 파일명(확장자 O)
  static final Map<String, String> premiumSoundsIOS = {
    for (var i = 1; i <= _premiumCount; i++) 'premium$i': 'alarm_premium$i.wav',
  };

  /// 미리듣기용 Flutter asset 경로 (audioplayers에서 사용)
  static final Map<String, String> previewAssets = {
    for (var i = 1; i <= _premiumCount; i++)
      'premium$i': 'sounds/alarm_premium$i.wav',
  };

  /// UI 라벨
  static final Map<String, String> premiumSoundLabels = {
    for (var i = 1; i <= _premiumCount; i++) 'premium$i': '프리미엄 벨소리 $i',
  };

  static const String defaultPremiumKey = 'premium1';

  bool _inited = false;

  // 안드로이드 진동 패턴 (Int64List 필수)
  static final Int64List _vibrationPattern = Int64List.fromList(
    [0, 600, 400, 600, 400, 600],
  );

  // ─────────────────────────────────────────────
  Future<void> init() async {
    if (_inited) return;

    // 미리듣기 오디오 세션 (버전 호환: const 사용하지 않음)
    await _previewPlayer.setAudioContext(
      AudioContext(
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
        ),
        android: AudioContextAndroid(
          isSpeakerphoneOn: true,
          stayAwake: false,
        ),
      ),
    );
    _previewPlayer.setReleaseMode(ReleaseMode.stop);
    _previewPlayer.onPlayerStateChanged.listen((s) {
      _isPreviewing = (s == PlayerState.playing);
      if (!_isPreviewing) _previewingKey = null;
    });

    // 타임존
    try {
      tzdata.initializeTimeZones();
      tz.setLocalLocation(tz.local);
    } catch (_) {
      tz.setLocalLocation(tz.local);
    }

    // iOS
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // Android
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');

    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _fln.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse r) async {
        final id = r.id ?? 0;
        final payload = r.payload;

        // 액션 버튼 처리
        switch (r.actionId) {
          case _kActionStop:
            await _fln.cancel(id);
            break;
          case _kActionSnooze5:
            final now = DateTime.now().add(const Duration(minutes: 5));
            await scheduleOneShot(
              id: 'SNOOZE_$id',
              fireAtLocal: now,
              title: '스누즈된 알림',
              body: '5분 뒤 다시 울립니다.',
              alarmStyle: true,
            );
            await _fln.cancel(id);
            break;
          default:
            // 일반 탭
            onSelect?.call(payload);
            break;
        }

        // 포그라운드 알림 콜백 (스낵바 등)
        onForeground?.call(id, null, null, payload);
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    if (Platform.isAndroid) {
      final android = _fln.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      // 무료 채널 (importance: max 로 잠금화면 가시성 확보)
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          _androidChannelIdFree,
          _androidChannelNameFree,
          description: _androidChannelDescFree,
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        ),
      );

      // 프리미엄 기본 채널 보장
      final sel = await getSelectedPremiumSoundKey();
      await _ensurePremiumChannelExists(sel);

      // Android 13+ 알림권한
      try {
        await android?.requestNotificationsPermission();
      } catch (_) {}
    }

    _inited = true;
  }

  // ─────────────────────────────────────────────
  // 앱 시작시 1회: 안내 다이얼로그 → 시스템 팝업(정확알람 페이지)까지 유도
  Future<bool> requestPermissionWithDialog(BuildContext ctx) async {
    // 이미 권한 있으면 스킵
    if (await requestPermissionsIfNeeded()) return true;

    final agreed = await showDialog<bool>(
          context: ctx,
          builder: (c) => AlertDialog(
            title: const Text("알림 권한 필요"),
            content: const Text(
              "잠금화면에서도 알람이 울리려면 알림 권한과 정확한 알람 권한이 필요합니다.",
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(c).pop(false),
                  child: const Text("나중에")),
              TextButton(
                onPressed: () => Navigator.of(c).pop(true),
                child: const Text("권한 설정"),
              ),
            ],
          ),
        ) ??
        false;

    if (!agreed) return false;

    final ok = await requestPermissionsIfNeeded();
    if (!ok && Platform.isAndroid) {
      await openExactAlarmSettingsIfNeeded();
    }
    return ok;
  }

  // ─────────────────────────────────────────────
  Future<bool> requestPermissionsIfNeeded() async {
    if (Platform.isIOS) {
      final ok = await _fln
              .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin>()
              ?.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
      return ok;
    }
    if (Platform.isAndroid) {
      try {
        final android = _fln.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        final ok = await android?.requestNotificationsPermission();
        if (ok == true) return true;
      } catch (_) {}
      final status = await Permission.notification.status;
      if (status.isGranted) return true;
      final res = await Permission.notification.request();
      return res.isGranted;
    }
    return true;
  }

  Future<void> openExactAlarmSettingsIfNeeded() async {
    if (!Platform.isAndroid) return;
    try {
      const intent = AndroidIntent(
        action: 'android.settings.REQUEST_SCHEDULE_EXACT_ALARM',
      );
      await intent.launch();
    } catch (_) {}
  }

  // ─────────────────────────────────────────────
  // Prefs
  Future<void> setEnabled(bool enabled) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_prefEnabled, enabled);
  }

  Future<bool> isEnabled() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_prefEnabled) ?? true;
  }

  Future<void> setOffsets(List<int> minutes) async {
    minutes.sort((a, b) => b.compareTo(a));
    final p = await SharedPreferences.getInstance();
    await p.setString(_prefOffsets, minutes.join(','));
  }

  Future<List<int>> getOffsets() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString(_prefOffsets) ?? "60,30";
    return s
        .split(',')
        .map((e) => int.tryParse(e.trim()))
        .whereType<int>()
        .toList();
  }

  Future<String> getSelectedPremiumSoundKey() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_prefPremiumSound) ?? defaultPremiumKey;
  }

  Future<void> setSelectedPremiumSoundKey(String key) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_prefPremiumSound, key);
    await _ensurePremiumChannelExists(key); // Android 채널 새 보장
  }

  // ─────────────────────────────────────────────
  Future<void> _ensurePremiumChannelExists(String key) async {
    if (!Platform.isAndroid) return;
    final android = _fln.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final rawName = premiumSoundsAndroid[key];
    if (rawName == null) return;

    await android?.createNotificationChannel(
      AndroidNotificationChannel(
        _androidPremiumChannelIdFor(key),
        _androidPremiumChannelNameFor(key),
        description: '프리미엄 - 알람 사운드($key)',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        sound: RawResourceAndroidNotificationSound(rawName),
      ),
    );
  }

  // ─────────────────────────────────────────────
  Future<NotificationDetails> _details({
    required bool premium,
    bool fullScreen = false,
    bool alarmStyle = false,
  }) async {
    if (Platform.isAndroid) {
      if (premium) {
        final key = await getSelectedPremiumSoundKey();
        await _ensurePremiumChannelExists(key);
        return NotificationDetails(
          android: AndroidNotificationDetails(
            _androidPremiumChannelIdFor(key),
            _androidPremiumChannelNameFor(key),
            channelDescription: '프리미엄 - 알람 사운드($key)',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            vibrationPattern: _vibrationPattern,
            fullScreenIntent: true, // ✅ 잠금화면에서 화면 깨우기 (FLN 경로일 때)
            category: AndroidNotificationCategory.alarm, // ✅ 카드 강조
            visibility: NotificationVisibility.public, // ✅ 잠금화면 표시
            ticker: 'alarm',
            actions: const [
              AndroidNotificationAction(
                _kActionStop,
                '중지',
                showsUserInterface: false,
                cancelNotification: true,
              ),
              AndroidNotificationAction(
                _kActionSnooze5,
                '5분 뒤',
                showsUserInterface: false,
                cancelNotification: true,
              ),
            ],
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
            presentBadge: true,
            sound: premiumSoundsIOS[key] ?? premiumSoundsIOS[defaultPremiumKey],
          ),
        );
      } else {
        return NotificationDetails(
          android: AndroidNotificationDetails(
            _androidChannelIdFree,
            _androidChannelNameFree,
            channelDescription: _androidChannelDescFree,
            importance: Importance.max,
            priority: Priority.high,
            playSound: true, // ✅ 무료는 기기 기본음
            enableVibration: true,
            vibrationPattern: _vibrationPattern,
            fullScreenIntent: true,
            category: AndroidNotificationCategory.alarm,
            visibility: NotificationVisibility.public,
            ticker: 'alarm',
            actions: const [
              AndroidNotificationAction(
                _kActionStop,
                '중지',
                showsUserInterface: false,
                cancelNotification: true,
              ),
              AndroidNotificationAction(
                _kActionSnooze5,
                '5분 뒤',
                showsUserInterface: false,
                cancelNotification: true,
              ),
            ],
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
            presentBadge: true,
          ),
        );
      }
    } else {
      // iOS/기타
      if (premium) {
        final key = await getSelectedPremiumSoundKey();
        return NotificationDetails(
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
            presentBadge: true,
            sound: premiumSoundsIOS[key] ?? premiumSoundsIOS[defaultPremiumKey],
          ),
        );
      } else {
        return const NotificationDetails(
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
            presentBadge: true,
          ),
        );
      }
    }
  }

  // ─────────────────────────────────────────────
  // ✅ 미리듣기(토글): 알림과 무관, 즉시 재생
  Future<void> playPreview({required String key}) async {
    _previewingKey = key;
    await _previewPlayer.stop();
    final assetPath = previewAssets[key] ?? previewAssets[defaultPremiumKey]!;
    await _previewPlayer.play(AssetSource(assetPath));
  }

  Future<void> stopPreview() async {
    _previewingKey = null;
    await _previewPlayer.stop();
  }

  Future<bool> togglePreview({required String key}) async {
    if (_isPreviewing && _previewingKey == key) {
      await stopPreview();
      return false;
    } else {
      await playPreview(key: key);
      return true;
    }
  }

  // ─────────────────────────────────────────────
  // 빠른 진단용
  Future<void> debugShowNow() async {
    final premium = await PremiumGateCompat.effectivePremium();
    final details = await _details(premium: premium, fullScreen: true);
    await _fln.show(
        777001, premium ? 'Premium Now' : 'Free Now', 'channel check', details);
  }

  Future<void> debugLogAndSchedule5s() async {
    final key = await getSelectedPremiumSoundKey();
    // ignore: avoid_print
    print('[NotificationService] premiumKey=$key');
    final at = DateTime.now().add(const Duration(seconds: 5));
    await scheduleOneShot(
      id: 'DEBUG_5S_$key',
      fireAtLocal: at,
      title: '키=$key',
      body: '5초 후 울림',
      alarmStyle: true,
    );
  }

  // ─────────────────────────────────────────────
  Future<void> _safeZonedSchedule({
    required int id,
    required String title,
    String? body,
    required DateTime fireAtLocal,
    required bool premium,
    bool fullScreen = false,
    bool alarmStyle = false,
  }) async {
    if (!await isEnabled()) return;
    if (fireAtLocal.isBefore(DateTime.now())) return;

    // ✅ 프리미엄 + 알람스타일이면: Android는 네이티브 AlarmClock 경로(잠금화면 보장)
    if (Platform.isAndroid && premium && alarmStyle) {
      await NativeAlarmBridge.scheduleAlarmClock(fireAtLocal, title);
      // 참고: 시스템 알람 UI가 잠금화면에서 바로 깨우고, 중지/스누즈도 시스템이 처리.
      // (원한다면, 보조로 FLN을 함께 스케줄할 수도 있지만, 중복 울림 방지를 위해 생략)
      return;
    }

    // 임박시 show() 폴백 (FLN 경로)
    if (fireAtLocal.difference(DateTime.now()).inSeconds <= 1) {
      final details = await _details(
        premium: premium,
        fullScreen: true,
        alarmStyle: alarmStyle,
      );
      await _fln.show(id, title, body, details, payload: id.toString());
      return;
    }

    final at = tz.TZDateTime.from(fireAtLocal, tz.local);
    final details = await _details(
      premium: premium,
      fullScreen: true,
      alarmStyle: alarmStyle,
    );

    // FLN 스케줄 (무료 또는 프리미엄이지만 기본 알림 스타일일 때)
    try {
      await _fln.zonedSchedule(
        id,
        title,
        body,
        at,
        details,
        androidScheduleMode: (premium || alarmStyle)
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexact,
        payload: id.toString(),
      );
    } on PlatformException catch (e) {
      if (e.code == 'exact_alarms_not_permitted' && Platform.isAndroid) {
        await openExactAlarmSettingsIfNeeded();
        await _fln.zonedSchedule(
          id,
          title,
          body,
          at,
          details,
          androidScheduleMode: AndroidScheduleMode.inexact,
          payload: 'fallback:$id',
        );
      } else {
        rethrow;
      }
    }
  }

  // ─────────────────────────────────────────────
  Future<void> scheduleOneShot({
    required String id,
    required DateTime fireAtLocal,
    required String title,
    String? body,
    bool alarmStyle = false,
  }) async {
    final premium = await PremiumGateCompat.effectivePremium();
    final intKey = (id.hashCode & 0x7fffffff);
    await _safeZonedSchedule(
      id: intKey,
      title: title,
      body: body,
      fireAtLocal: fireAtLocal,
      premium: premium,
      fullScreen: alarmStyle && premium,
      alarmStyle: alarmStyle,
    );
  }

  Future<void> scheduleTestIn10s({bool alarmStyle = false}) async {
    final premium = await PremiumGateCompat.effectivePremium();
    final fireAt = DateTime.now().add(const Duration(seconds: 10));
    await scheduleOneShot(
      id: 'TEST_10S',
      fireAtLocal: fireAt,
      title: premium ? '프리미엄 테스트 알람' : '테스트 알림',
      body: premium ? '프리미엄 사운드로 재생됩니다.' : '기본 알림음으로 재생됩니다.',
      alarmStyle: alarmStyle && premium,
    );
  }

  Future<void> scheduleForShift({
    required String scheduleId,
    required DateTime startDateTimeLocal,
    required String title,
    bool alarmStyle = false,
  }) async {
    final premium = await PremiumGateCompat.effectivePremium();
    final offsets = await getOffsets();
    for (final m in offsets) {
      final fireAt = startDateTimeLocal.subtract(Duration(minutes: m));
      if (fireAt.isBefore(DateTime.now())) continue;

      await _safeZonedSchedule(
        id: _stableId(scheduleId, m),
        title: premium ? '근무 알람' : '근무 알림',
        body: premium ? '$m분 후 근무 시작: $title' : '$m분 후 근무 시작',
        fireAtLocal: fireAt,
        premium: premium,
        fullScreen: alarmStyle && premium,
        alarmStyle: alarmStyle,
      );
    }
  }

  Future<void> cancelForShift(String scheduleId) async {
    final offsets = await getOffsets();
    for (final m in offsets) {
      await _fln.cancel(_stableId(scheduleId, m));
    }
    // ⚠️ 네이티브 AlarmClock은 시스템 전역 예약이라 “개별 ID 취소”가 제한적.
    // 여기서는 일괄 취소만 제공(마지막 예약 취소 등). 필요한 경우 Kotlin 측에서
    // 예약당 고유 requestCode를 관리/매핑해 개별 취소 로직을 확장하세요.
    if (Platform.isAndroid) {
      await NativeAlarmBridge.cancelAlarmClock();
    }
  }

  Future<List<PendingNotificationRequest>> debugPending() async {
    return _fln.pendingNotificationRequests();
  }

  int _stableId(String base, int offset) =>
      ((base.hashCode ^ offset.hashCode) & 0x7fffffff);

  // ─────────────────────────────────────────────
  // 🔗 네이티브 알람(풀스크린 Activity/Service) 브릿지 편의 메소드
  Future<void> startNativeAlarmNow(String title) async {
    if (!Platform.isAndroid) return;
    await NativeAlarmBridge.scheduleAlarmClock(DateTime.now(), title);
  }

  Future<void> stopNativeAlarm() async {
    if (!Platform.isAndroid) return;
    await NativeAlarmBridge.cancelAlarmClock();
  }
}

/// ──────────────────────────────────────────────────────────────
/// Flutter ↔ Android 네이티브 알람 브릿지(MethodChannel)
/// - Kotlin 측: MainActivity.kt 에 CHANNEL = "com.my_new_test_app/alarm"
/// - 메소드: scheduleAlarmClock(at, title), cancelAlarmClock()
class NativeAlarmBridge {
  static const MethodChannel _channel =
      MethodChannel('com.my_new_test_app/alarm');

  /// Android의 setAlarmClock 기반 알람 예약 (잠금화면 깨우기 보장)
  static Future<void> scheduleAlarmClock(DateTime atLocal, String title) async {
    try {
      await _channel.invokeMethod('scheduleAlarmClock', {
        'at': atLocal.millisecondsSinceEpoch,
        'title': title,
      });
    } catch (e) {
      // ignore: avoid_print
      print('NativeAlarmBridge.scheduleAlarmClock error: $e');
    }
  }

  /// 예약된 알람 취소
  static Future<void> cancelAlarmClock() async {
    try {
      await _channel.invokeMethod('cancelAlarmClock');
    } catch (e) {
      // ignore: avoid_print
      print('NativeAlarmBridge.cancelAlarmClock error: $e');
    }
  }
}

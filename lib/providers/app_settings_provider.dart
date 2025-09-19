import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 모든 앱/알림 설정의 단일 소스.
/// - SharedPreferences에 저장
/// - UI는 이 프로바이더를 읽고/업데이트
final appSettingsProvider = NotifierProvider<AppSettingsNotifier, AppSettings>(
    () => AppSettingsNotifier());

class AppSettings {
  // 화면 & 표시
  final ThemeMode themeMode; // system/light/dark
  final bool use24hClock; // 24시간제
  final String weekStart; // 'mon' | 'sun'
  final String dateFormat; // 'yyyy.MM.dd' | 'yyyy-MM-dd' | 'MM/dd/yyyy'

  // 동기화 & 실시간
  final bool realtimeEnabled; // 실시간 스트림 사용
  final bool allowCellularSync; // 셀룰러에서도 동기화

  // 개인정보 & 보안
  final String shareWorkVisibility; // 'public' | 'friends' | 'private'
  final String shareMemoVisibility; // ''
  final String shareProfileVisibility; // ''
  final String appLock; // 'none' | 'pin' | 'biometric'

  // 알림 (상위 스위치)
  final bool notifEnabled;

  // 알림 상세(근무 알림)
  final List<int> notifOffsets; // [60,30,10]
  final bool notifSound;
  final bool notifVibrate;

  // DND
  final bool notifDndEnabled;
  final String notifDndStart; // '22:00'
  final String notifDndEnd; // '06:00'
  final String notifHolidayQuiet; // 'off' | 'mute' | 'skip'

  // 고급
  final bool notifRescheduleOnBoot; // 재부팅 시 재예약
  final bool notifDedupe; // 중복 억제
  final bool notifAdvancedPrecision; // 개발자 옵션

  const AppSettings({
    // 화면 & 표시
    this.themeMode = ThemeMode.system,
    this.use24hClock = true,
    this.weekStart = 'mon',
    this.dateFormat = 'yyyy.MM.dd',
    // 동기화
    this.realtimeEnabled = true,
    this.allowCellularSync = true,
    // 개인정보 & 보안
    this.shareWorkVisibility = 'friends',
    this.shareMemoVisibility = 'friends',
    this.shareProfileVisibility = 'friends',
    this.appLock = 'none',
    // 알림
    this.notifEnabled = true,
    this.notifOffsets = const [60, 30, 10],
    this.notifSound = true,
    this.notifVibrate = true,
    // DND
    this.notifDndEnabled = false,
    this.notifDndStart = '22:00',
    this.notifDndEnd = '06:00',
    this.notifHolidayQuiet = 'off',
    // 고급
    this.notifRescheduleOnBoot = true,
    this.notifDedupe = true,
    this.notifAdvancedPrecision = false,
  });

  AppSettings copyWith({
    ThemeMode? themeMode,
    bool? use24hClock,
    String? weekStart,
    String? dateFormat,
    bool? realtimeEnabled,
    bool? allowCellularSync,
    String? shareWorkVisibility,
    String? shareMemoVisibility,
    String? shareProfileVisibility,
    String? appLock,
    bool? notifEnabled,
    List<int>? notifOffsets,
    bool? notifSound,
    bool? notifVibrate,
    bool? notifDndEnabled,
    String? notifDndStart,
    String? notifDndEnd,
    String? notifHolidayQuiet,
    bool? notifRescheduleOnBoot,
    bool? notifDedupe,
    bool? notifAdvancedPrecision,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      use24hClock: use24hClock ?? this.use24hClock,
      weekStart: weekStart ?? this.weekStart,
      dateFormat: dateFormat ?? this.dateFormat,
      realtimeEnabled: realtimeEnabled ?? this.realtimeEnabled,
      allowCellularSync: allowCellularSync ?? this.allowCellularSync,
      shareWorkVisibility: shareWorkVisibility ?? this.shareWorkVisibility,
      shareMemoVisibility: shareMemoVisibility ?? this.shareMemoVisibility,
      shareProfileVisibility:
          shareProfileVisibility ?? this.shareProfileVisibility,
      appLock: appLock ?? this.appLock,
      notifEnabled: notifEnabled ?? this.notifEnabled,
      notifOffsets: notifOffsets ?? this.notifOffsets,
      notifSound: notifSound ?? this.notifSound,
      notifVibrate: notifVibrate ?? this.notifVibrate,
      notifDndEnabled: notifDndEnabled ?? this.notifDndEnabled,
      notifDndStart: notifDndStart ?? this.notifDndStart,
      notifDndEnd: notifDndEnd ?? this.notifDndEnd,
      notifHolidayQuiet: notifHolidayQuiet ?? this.notifHolidayQuiet,
      notifRescheduleOnBoot:
          notifRescheduleOnBoot ?? this.notifRescheduleOnBoot,
      notifDedupe: notifDedupe ?? this.notifDedupe,
      notifAdvancedPrecision:
          notifAdvancedPrecision ?? this.notifAdvancedPrecision,
    );
  }
}

class AppSettingsNotifier extends Notifier<AppSettings> {
  static const _kThemeMode = 'app_theme_mode';
  static const _kUse24h = 'use_24h_clock';
  static const _kWeekStart = 'week_start';
  static const _kDateFormat = 'date_format';
  static const _kRealtime = 'realtime_enabled';
  static const _kCellular = 'allow_cellular_sync';
  static const _kShareWork = 'share_work_visibility';
  static const _kShareMemo = 'share_memo_visibility';
  static const _kShareProfile = 'share_profile_visibility';
  static const _kAppLock = 'app_lock';

  static const _kNotifEnabled = 'notif_enabled';
  static const _kNotifOffsets = 'notif_offsets';
  static const _kNotifSound = 'notif_sound';
  static const _kNotifVibrate = 'notif_vibrate';

  static const _kDndEnabled = 'notif_dnd_enabled';
  static const _kDndStart = 'notif_dnd_start';
  static const _kDndEnd = 'notif_dnd_end';
  static const _kHolidayQuiet = 'notif_holiday_quiet';

  static const _kResched = 'notif_reschedule_on_boot';
  static const _kDedupe = 'notif_dedupe';
  static const _kAdvPrec = 'notif_advanced_precision';

  late SharedPreferences _prefs;

  @override
  AppSettings build() {
    _load();
    return const AppSettings();
  }

  Future<void> _load() async {
    _prefs = await SharedPreferences.getInstance();

    final saved = AppSettings(
      themeMode: _decodeTheme(_prefs.getString(_kThemeMode)),
      use24hClock: _prefs.getBool(_kUse24h) ?? true,
      weekStart: _prefs.getString(_kWeekStart) ?? 'mon',
      dateFormat: _prefs.getString(_kDateFormat) ?? 'yyyy.MM.dd',
      realtimeEnabled: _prefs.getBool(_kRealtime) ?? true,
      allowCellularSync: _prefs.getBool(_kCellular) ?? true,
      shareWorkVisibility: _prefs.getString(_kShareWork) ?? 'friends',
      shareMemoVisibility: _prefs.getString(_kShareMemo) ?? 'friends',
      shareProfileVisibility: _prefs.getString(_kShareProfile) ?? 'friends',
      appLock: _prefs.getString(_kAppLock) ?? 'none',
      notifEnabled: _prefs.getBool(_kNotifEnabled) ?? true,
      notifOffsets:
          _prefs.getStringList(_kNotifOffsets)?.map(int.parse).toList() ??
              const [60, 30, 10],
      notifSound: _prefs.getBool(_kNotifSound) ?? true,
      notifVibrate: _prefs.getBool(_kNotifVibrate) ?? true,
      notifDndEnabled: _prefs.getBool(_kDndEnabled) ?? false,
      notifDndStart: _prefs.getString(_kDndStart) ?? '22:00',
      notifDndEnd: _prefs.getString(_kDndEnd) ?? '06:00',
      notifHolidayQuiet: _prefs.getString(_kHolidayQuiet) ?? 'off',
      notifRescheduleOnBoot: _prefs.getBool(_kResched) ?? true,
      notifDedupe: _prefs.getBool(_kDedupe) ?? true,
      notifAdvancedPrecision: _prefs.getBool(_kAdvPrec) ?? false,
    );
    state = saved;
  }

  // 저장 헬퍼
  Future<void> setThemeMode(ThemeMode m) async {
    await _prefs.setString(_kThemeMode, _encodeTheme(m));
    state = state.copyWith(themeMode: m);
  }

  Future<void> setUse24h(bool v) async {
    await _prefs.setBool(_kUse24h, v);
    state = state.copyWith(use24hClock: v);
  }

  Future<void> setWeekStart(String v) async {
    await _prefs.setString(_kWeekStart, v);
    state = state.copyWith(weekStart: v);
  }

  Future<void> setDateFormat(String v) async {
    await _prefs.setString(_kDateFormat, v);
    state = state.copyWith(dateFormat: v);
  }

  Future<void> setRealtime(bool v) async {
    await _prefs.setBool(_kRealtime, v);
    state = state.copyWith(realtimeEnabled: v);
  }

  Future<void> setCellular(bool v) async {
    await _prefs.setBool(_kCellular, v);
    state = state.copyWith(allowCellularSync: v);
  }

  Future<void> setShareWork(String v) async {
    await _prefs.setString(_kShareWork, v);
    state = state.copyWith(shareWorkVisibility: v);
  }

  Future<void> setShareMemo(String v) async {
    await _prefs.setString(_kShareMemo, v);
    state = state.copyWith(shareMemoVisibility: v);
  }

  Future<void> setShareProfile(String v) async {
    await _prefs.setString(_kShareProfile, v);
    state = state.copyWith(shareProfileVisibility: v);
  }

  Future<void> setAppLock(String v) async {
    await _prefs.setString(_kAppLock, v);
    state = state.copyWith(appLock: v);
  }

  Future<void> setNotifEnabled(bool v) async {
    await _prefs.setBool(_kNotifEnabled, v);
    state = state.copyWith(notifEnabled: v);
  }

  Future<void> setNotifOffsets(List<int> mins) async {
    mins.sort((a, b) => b.compareTo(a));
    await _prefs.setStringList(
        _kNotifOffsets, mins.map((e) => e.toString()).toList());
    state = state.copyWith(notifOffsets: mins);
  }

  Future<void> setNotifSound(bool v) async {
    await _prefs.setBool(_kNotifSound, v);
    state = state.copyWith(notifSound: v);
  }

  Future<void> setNotifVibrate(bool v) async {
    await _prefs.setBool(_kNotifVibrate, v);
    state = state.copyWith(notifVibrate: v);
  }

  Future<void> setDndEnabled(bool v) async {
    await _prefs.setBool(_kDndEnabled, v);
    state = state.copyWith(notifDndEnabled: v);
  }

  Future<void> setDndStart(String v) async {
    await _prefs.setString(_kDndStart, v);
    state = state.copyWith(notifDndStart: v);
  }

  Future<void> setDndEnd(String v) async {
    await _prefs.setString(_kDndEnd, v);
    state = state.copyWith(notifDndEnd: v);
  }

  Future<void> setHolidayQuiet(String v) async {
    await _prefs.setString(_kHolidayQuiet, v);
    state = state.copyWith(notifHolidayQuiet: v);
  }

  Future<void> setRescheduleOnBoot(bool v) async {
    await _prefs.setBool(_kResched, v);
    state = state.copyWith(notifRescheduleOnBoot: v);
  }

  Future<void> setDedupe(bool v) async {
    await _prefs.setBool(_kDedupe, v);
    state = state.copyWith(notifDedupe: v);
  }

  Future<void> setAdvancedPrecision(bool v) async {
    await _prefs.setBool(_kAdvPrec, v);
    state = state.copyWith(notifAdvancedPrecision: v);
  }

  // 인코딩/디코딩
  static String _encodeTheme(ThemeMode m) {
    switch (m) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      default:
        return 'system';
    }
  }

  static ThemeMode _decodeTheme(String? s) {
    switch (s) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }
}

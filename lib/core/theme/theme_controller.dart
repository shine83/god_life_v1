import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 저장 키
const _kThemeModeKey = 'app_theme_mode_v1';

/// ThemeMode <-> String 변환
String _encode(ThemeMode m) => switch (m) {
      ThemeMode.system => 'system',
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
    };

ThemeMode _decode(String? s) => switch (s) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };

/// 컨트롤러
class ThemeModeController extends StateNotifier<ThemeMode> {
  ThemeModeController() : super(ThemeMode.system) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = _decode(prefs.getString(_kThemeModeKey));
    if (saved != state) state = saved; // 초기값 반영 → MaterialApp 리빌드
  }

  Future<void> setTheme(ThemeMode mode) async {
    if (state == mode) return;
    state = mode; // 즉시 리빌드
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeModeKey, _encode(mode));
  }

  Future<void> followSystem() => setTheme(ThemeMode.system);
  Future<void> setLight() => setTheme(ThemeMode.light);
  Future<void> setDark() => setTheme(ThemeMode.dark);
}

/// Provider (main.dart에서 watch하는 그거)
final themeModeProvider = StateNotifierProvider<ThemeModeController, ThemeMode>(
  (ref) => ThemeModeController(),
);

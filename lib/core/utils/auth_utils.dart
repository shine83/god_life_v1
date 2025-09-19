// lib/core/utils/auth_utils.dart

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthUtils {
  /// 회원탈퇴가 서버에서 성공한 직후, 또는 로그아웃 버튼에서 호출
  /// - Supabase 세션/토큰 클리어
  /// - 앱 로컬 캐시(SharedPreferences) 정리
  static Future<void> signOutEverywhere() async {
    try {
      await Supabase.instance.client.auth.signOut(); // << 세션/토큰 제거
    } finally {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    }
  }
}

// lib/features/authentication/repository/auth_repository.dart

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// 1. 이 Repository를 앱 전체에 제공할 Provider를 만듭니다.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(Supabase.instance.client);
});

// 2. 인증 관련 모든 Supabase 통신을 책임지는 클래스를 만듭니다.
class AuthRepository {
  final SupabaseClient _client;

  AuthRepository(this._client);

  // 현재 로그인된 사용자를 가져옵니다.
  User? get currentUser => _client.auth.currentUser;

  // 인증 상태의 변경을 실시간으로 감지합니다. (로그인, 로그아웃 등)
  Stream<AuthState> get authStateChange => _client.auth.onAuthStateChange;

  // 이메일과 비밀번호로 로그인합니다.
  Future<void> signInWithPassword(String email, String password) async {
    try {
      await _client.auth.signInWithPassword(email: email, password: password);
    } catch (e) {
      rethrow; // 오류를 호출한 곳으로 다시 던져서 UI에서 처리하도록 함
    }
  }

  // 이메일과 비밀번호로 회원가입합니다.
  Future<void> signUp(String email, String password) async {
    try {
      await _client.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: 'godlife://auth-callback',
      );
    } catch (e) {
      rethrow;
    }
  }

  // 로그아웃합니다.
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (e) {
      rethrow;
    }
  }

  // 비밀번호 재설정 이메일을 보냅니다.
  Future<void> resetPasswordForEmail(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(
        email,
        redirectTo: 'godlife://auth-callback',
      );
    } catch (e) {
      rethrow;
    }
  }
}

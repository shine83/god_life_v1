// lib/features/authentication/viewmodel/auth_viewmodel.dart

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:god_life_v1/features/authentication/repository/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final authViewModelProvider = AsyncNotifierProvider<AuthViewModel, User?>(() {
  return AuthViewModel();
});

class AuthViewModel extends AsyncNotifier<User?> {
  late final AuthRepository _authRepository;

  @override
  FutureOr<User?> build() {
    _authRepository = ref.watch(authRepositoryProvider);
    final authStream = _authRepository.authStateChange;
    authStream.listen((event) {
      state = AsyncValue.data(event.session?.user);
    });
    return _authRepository.currentUser;
  }

  // [수정됨] AsyncValue.guard가 User?를 반환하도록 수정
  Future<void> signInWithPassword(String email, String password) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _authRepository.signInWithPassword(email, password);
      return _authRepository.currentUser; // 성공 후 현재 유저 정보 반환
    });
  }

  // [수정됨] AsyncValue.guard가 User?를 반환하도록 수정
  Future<void> signUp(String email, String password) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _authRepository.signUp(email, password);
      // signUp 후에는 바로 로그인되지 않으므로 null을 반환하거나 기존 유저 상태를 유지
      // 여기서는 이메일 확인이 필요하므로, 로그인 상태가 즉시 변경되지 않음.
      // 따라서 현재 state를 그대로 유지하거나, 특정 상태를 반환하지 않고 stream의 변화를 기다림.
      // 하지만 guard는 값을 반환해야 하므로, 현재 유저(아직은 null)를 반환.
      return _authRepository.currentUser;
    });
  }

  Future<void> signOut() async {
    await _authRepository.signOut();
  }

  // [수정됨] 이 함수는 값을 반환할 필요가 없으므로 guard를 사용하지 않음
  Future<void> resetPasswordForEmail(String email) async {
    // 이 작업은 UI 상태를 loading으로 바꿀 필요가 없음 (스낵바로 피드백)
    // 따라서 guard 없이 직접 호출
    await _authRepository.resetPasswordForEmail(email);
  }
}

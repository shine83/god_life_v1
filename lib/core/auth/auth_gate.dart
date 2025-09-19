// lib/core/auth/auth_gate.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 앱 시작 시 세션을 확인하고,
/// 로그인/로그아웃 상태 변화에 따라 자동으로 라우팅해 주는 게이트 위젯.
/// - 세션 있으면: /home
/// - 세션 없으면: /login
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _supa = Supabase.instance.client;
  StreamSubscription<AuthState>? _sub;
  bool _checking = true;

  @override
  void initState() {
    super.initState();

    // 1) 앱 시작 시 현재 세션 확인
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final session = _supa.auth.currentSession;
      _go(session != null);
      // 2) 이후 로그인/로그아웃 이벤트 구독
      _sub = _supa.auth.onAuthStateChange.listen((data) {
        final event = data.event;
        final session = data.session;
        // SIGNED_IN / TOKEN_REFRESHED => 세션 존재
        // SIGNED_OUT / USER_DELETED    => 세션 없음
        if (!mounted) return;
        _go(session != null);
      });
    });
  }

  void _go(bool signedIn) {
    if (!mounted) return;
    // 첫 네비게이션은 중복 방지를 위해 Future.microtask 사용
    Future.microtask(() {
      if (!mounted) return;
      if (signedIn) {
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    });
    if (_checking) setState(() => _checking = false);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 아주 짧은 로딩 화면
    return Scaffold(
      body: Center(
        child: _checking
            ? const CircularProgressIndicator()
            : const SizedBox.shrink(),
      ),
    );
  }
}

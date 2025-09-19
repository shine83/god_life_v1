// lib/features/authentication/viewmodel/auth_gate.dart

import 'package:supabase_flutter/supabase_flutter.dart';

class AuthInspector {
  static final _sb = Supabase.instance.client;

  /// 세션 + profiles row 존재 → 완전 로그인
  static Future<bool> isFullySignedIn() async {
    final session = _sb.auth.currentSession;
    if (session == null) return false;

    final uid = session.user.id;

    // profiles 에 실제 row 있는지 확인 (탈퇴/정리된 계정은 row 없음)
    final res = await _sb
        .from('profiles')
        .select('id')
        .eq('id', uid)
        .limit(1)
        .maybeSingle();

    return res != null;
  }
}

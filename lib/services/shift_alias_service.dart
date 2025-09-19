// lib/services/shift_alias_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';

/// 표준 근무코드
/// D = Day, E = Evening, N = Night, O = Off
enum StandardShift { D, E, N, O }

class ShiftAliasService {
  final _supabase = Supabase.instance.client;

  /// 기본 내장 사전 (유저 커스텀 이전)
  final Map<String, StandardShift> _defaultAliases = {
    // 주간 계열
    "주": StandardShift.D,
    "데이": StandardShift.D,
    "day": StandardShift.D,
    "am": StandardShift.D,

    // 오후/이브닝 계열
    "이브닝": StandardShift.E,
    "evening": StandardShift.E,
    "swing": StandardShift.E,
    "pm": StandardShift.E,
    "S": StandardShift.E,

    // 야간 계열
    "야": StandardShift.N,
    "night": StandardShift.N,
    "N": StandardShift.N,

    // 휴무/휴식 계열
    "휴": StandardShift.O,
    "휴무": StandardShift.O,
    "비번": StandardShift.O,
    "off": StandardShift.O,
    "O": StandardShift.O,
  };

  /// Supabase DB: shift_aliases
  /// columns: user_id | alias (String) | code (String)
  Future<void> saveAlias(String alias, StandardShift code) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    await _supabase.from("shift_aliases").upsert({
      "user_id": userId,
      "alias": alias,
      "code": code.name, // enum → String (D/E/N/O)
    });
  }

  /// DB + 기본 사전에서 alias 매핑 찾기
  Future<StandardShift?> resolveAlias(String alias) async {
    final normalized = alias.trim().toLowerCase();

    // 1) DB에서 먼저 검색
    final userId = _supabase.auth.currentUser?.id;
    if (userId != null) {
      final response = await _supabase
          .from("shift_aliases")
          .select("code")
          .eq("user_id", userId)
          .eq("alias", normalized)
          .maybeSingle();

      if (response != null) {
        return StandardShift.values.firstWhere(
          (e) => e.name == response["code"],
          orElse: () => StandardShift.O,
        );
      }
    }

    // 2) 기본 사전 검색
    return _defaultAliases[normalized];
  }
}

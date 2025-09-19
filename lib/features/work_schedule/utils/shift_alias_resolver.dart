// lib/features/work_schedule/utils/shift_alias_resolver.dart
import 'dart:collection';

/// 표준 교대 근무 코드
/// D = Day, E = Evening, N = Night, O = Off
class ShiftAliasResolver {
  // 기본 사전 (alias → 표준 코드)
  static final Map<String, String> _aliasMap = {
    // Day 계열
    'day': 'D', 'd': 'D', '주': 'D', '주간': 'D', 'am': 'D', 'morning': 'D',

    // Evening 계열
    'evening': 'E', 'e': 'E', 'eve': 'E', 'swing': 'E', 's': 'E', 'pm': 'E',
    '이브닝': 'E', '오후': 'E',

    // Night 계열
    'night': 'N', 'n': 'N', '야': 'N', '야간': 'N', 'graveyard': 'N',
    'midnight': 'N',

    // Off / 휴식 계열
    'off': 'O', 'o': 'O', '휴': 'O', '휴무': 'O', '휴식': 'O',
    '비': 'O', '비번': 'O', 'offday': 'O',
  };

  /// 불변 맵 뷰 제공
  static UnmodifiableMapView<String, String> get aliasMap =>
      UnmodifiableMapView(_aliasMap);

  /// alias → 표준 코드 변환
  static String? resolve(String alias) {
    if (alias.isEmpty) return null;
    final key = alias.trim().toLowerCase();
    return _aliasMap[key];
  }

  /// 새로운 alias 학습 (런타임 저장)
  static void learnAlias(String alias, String code) {
    final key = alias.trim().toLowerCase();
    if (key.isNotEmpty) {
      _aliasMap[key] = code;
    }
  }
}

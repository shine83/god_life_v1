// lib/core/premium/premium_gate_compat.dart
import 'package:shared_preferences/shared_preferences.dart';

/// PremiumGateCompat
/// - 프로젝트별 PremiumGate API 차이를 흡수하기 위한 얇은 호환 레이어.
/// - 디버그 오버라이드 키: 'premium_debug_override' (bool)
/// - 서버/실제 구독 상태 키 후보: 'premium_active', 'is_premium', 'has_premium'
///
/// 사용:
///   final ok = await PremiumGateCompat.effectivePremium();
///   await PremiumGateCompat.setDevOverride(true/false/null);
class PremiumGateCompat {
  static const _kDevOverride = 'premium_debug_override';
  static const List<String> _kServerKeys = [
    'premium_active',
    'is_premium',
    'has_premium',
  ];

  /// 디버그 오버라이드 저장
  /// - true  : 프리미엄 강제
  /// - false : 무료 강제
  /// - null  : 오버라이드 해제(실제 상태 사용)
  static Future<void> setDevOverride(bool? value) async {
    final p = await SharedPreferences.getInstance();
    if (value == null) {
      await p.remove(_kDevOverride);
    } else {
      await p.setBool(_kDevOverride, value);
    }
  }

  /// 현재 화면에서 사용할 “실효 프리미엄 상태”
  /// - 디버그 오버라이드가 있으면 그 값을 최우선
  /// - 없으면 로컬에 저장된 서버/구독 상태 키들 중 하나라도 true면 true
  ///   (실제 결제 연동이 들어오면 여기서 연동 값 읽어오면 됨)
  static Future<bool> effectivePremium() async {
    final p = await SharedPreferences.getInstance();

    if (p.containsKey(_kDevOverride)) {
      final v = p.getBool(_kDevOverride);
      if (v != null) return v;
    }

    for (final k in _kServerKeys) {
      final b = p.getBool(k);
      if (b == true) return true;
    }
    return false;
  }
}

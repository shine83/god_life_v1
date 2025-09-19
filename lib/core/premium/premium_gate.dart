// lib/features/paywall/premium_gate.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 프리미엄 전역 게이트 (ANY-OR)
/// - 디버그 오버라이드가 최우선 (null 해제/ true 프리미엄 / false 무료)
/// - 구독 티어 또는 만료 시각 유효 OR 엔타이틀먼트 1개라도 있으면 => 프리미엄
///
/// SharedPreferences 키 (전역에서 동일 키 사용)
/// - premium_debug_override : bool?   // null=해제, true=프리미엄, false=무료
/// - premium_tier           : String? // 'premium' 등
/// - premium_until          : int?    // UTC seconds
/// - premium_entitlements   : String? // JSON array: ["ai.coach","alerts.pro"]
class PremiumGate extends ChangeNotifier {
  PremiumGate._();
  static final PremiumGate I = PremiumGate._();

  bool _isPremium = false;
  bool get isPremium => _isPremium;

  /// 전역 상태를 재계산하고 리스너에 알림
  static Future<void> refresh() async {
    final next = await _evaluate();
    if (I._isPremium != next) {
      I._isPremium = next;
      I.notifyListeners();
    }
  }

  /// 즉시 한 번 조회 (내부 상태도 동기화)
  static Future<bool> isPremiumNow() async {
    final next = await _evaluate();
    if (I._isPremium != next) {
      I._isPremium = next;
      I.notifyListeners();
    }
    return next;
  }

  // ANY-OR 판정
  static Future<bool> _evaluate() async {
    final p = await SharedPreferences.getInstance();

    // 1) 디버그 오버라이드
    final override = p.getBool('premium_debug_override');
    if (override != null) return override;

    // 2) 구독 티어 / 만료
    final tier = p.getString('premium_tier');
    final untilSec = p.getInt('premium_until') ?? 0;
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final hasActiveTier = (tier == 'premium') || (untilSec > nowSec);

    // 3) 엔타이틀먼트: 하나라도 있으면 프리미엄
    final entJson = p.getString('premium_entitlements');
    bool hasAnyEnt = false;
    if (entJson != null && entJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(entJson);
        if (decoded is List && decoded.isNotEmpty) {
          hasAnyEnt = true;
        }
      } catch (_) {}
    }

    return hasActiveTier || hasAnyEnt;
  }
}

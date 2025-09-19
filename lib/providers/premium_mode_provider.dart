import 'package:flutter_riverpod/flutter_riverpod.dart';

final premiumModeProvider = StateProvider<bool>((ref) {
  // 기본값: 무료 모드 (false)
  return false;
});

// lib/services/schedule_notifier.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

// 1. Notifier 클래스를 ChangeNotifier에서 StateNotifier로 변경합니다.
// StateNotifier는 상태(여기서는 간단한 정수)를 가지며, 상태가 변하면 알려줍니다.
class ScheduleStateNotifier extends StateNotifier<int> {
  // 초기 상태를 0으로 설정합니다.
  ScheduleStateNotifier() : super(0);

  // 2. 상태를 변경하고 구독자(리스너)에게 알리는 함수입니다.
  void notify() {
    state++; // 상태 값을 1 증가시켜 변화를 알립니다.
  }
}

// 3. 앱 어디서든 ScheduleStateNotifier에 접근할 수 있도록 전역 프로바이더를 만듭니다.
// 이 변수가 새로운 '방송국'의 주소 역할을 합니다.
final scheduleNotifierProvider =
    StateNotifierProvider<ScheduleStateNotifier, int>((ref) {
  return ScheduleStateNotifier();
});

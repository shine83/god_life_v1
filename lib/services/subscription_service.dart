import 'dart:async';

/// 실제로는 RevenueCat / Supabase / Play Billing 연동을 넣으면 됨.
/// 지금은 간단히 메모리 상태 + 스트림으로 구현.
class SubscriptionService {
  static final SubscriptionService _i = SubscriptionService._();
  factory SubscriptionService() => _i;
  SubscriptionService._();

  bool _isPro = false;
  final _ctrl = StreamController<bool>.broadcast();

  bool get isPro => _isPro;
  Stream<bool> get changes => _ctrl.stream;

  Future<void> setPro(bool v) async {
    _isPro = v;
    _ctrl.add(v);
  }
}

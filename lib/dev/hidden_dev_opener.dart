import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

/// 자식 위젯을 X회 탭하면 onTrigger를 실행하는 래퍼.
/// 기본: 5회, 3초 안에
class HiddenDevOpener extends StatefulWidget {
  final Widget child;
  final VoidCallback onTrigger;
  final int tapsRequired;
  final Duration window;

  const HiddenDevOpener({
    super.key,
    required this.child,
    required this.onTrigger,
    this.tapsRequired = 5,
    this.window = const Duration(seconds: 3),
  });

  @override
  State<HiddenDevOpener> createState() => _HiddenDevOpenerState();
}

class _HiddenDevOpenerState extends State<HiddenDevOpener> {
  int _count = 0;
  DateTime? _firstTapAt;

  void _onTap() {
    if (!kDebugMode) return; // 릴리즈 빌드에서 비활성화
    final now = DateTime.now();

    if (_firstTapAt == null || now.difference(_firstTapAt!) > widget.window) {
      _firstTapAt = now;
      _count = 1;
    } else {
      _count += 1;
    }

    if (_count >= widget.tapsRequired) {
      _count = 0;
      _firstTapAt = null;
      widget.onTrigger();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _onTap,
      child: widget.child,
    );
  }
}

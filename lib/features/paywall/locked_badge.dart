// lib/features/paywall/locked_badge.dart
import 'package:flutter/material.dart';

class LockedBadge extends StatelessWidget {
  const LockedBadge({super.key, this.label = 'PRO', this.compact = false});
  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF2A2547)
        : const Color(0xFFF2F0FF);
    final fg = const Color(0xFF6C4CE8);

    if (compact) {
      return Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: Icon(Icons.lock_rounded, size: 12, color: fg),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.lock_rounded, size: 14, color: fg),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: fg,
            )),
      ]),
    );
  }
}

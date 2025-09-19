// ✅ repeat_pattern_dialog.dart
import 'package:flutter/material.dart';

class RepeatPatternDialog extends StatefulWidget {
  final String initialPattern;

  const RepeatPatternDialog({super.key, this.initialPattern = ''});

  @override
  State<RepeatPatternDialog> createState() => _RepeatPatternDialogState();
}

class _RepeatPatternDialogState extends State<RepeatPatternDialog> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialPattern);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('반복 패턴 입력'),
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(
          labelText: '예: dan 또는 nnnoodddooaaaoo',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context, _controller.text.trim());
          },
          child: const Text('확인'),
        ),
      ],
    );
  }
}

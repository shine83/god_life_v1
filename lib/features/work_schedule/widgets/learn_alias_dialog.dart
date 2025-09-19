// lib/features/work_schedule/widgets/learn_alias_dialog.dart
import 'package:flutter/material.dart';
import 'package:my_new_test_app/core/models/shift_type.dart';
import 'package:my_new_test_app/services/shift_alias_service.dart';

class LearnAliasDialog extends StatefulWidget {
  const LearnAliasDialog({
    super.key,
    required this.unknownAlias,
    required this.standardShifts,
  });

  final String unknownAlias;
  final List<ShiftType> standardShifts;

  @override
  State<LearnAliasDialog> createState() => _LearnAliasDialogState();
}

class _LearnAliasDialogState extends State<LearnAliasDialog> {
  String? _selectedCode;
  final _aliasService = ShiftAliasService();

  @override
  void initState() {
    super.initState();
    _selectedCode = widget.standardShifts.first.abbreviation;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.titleLarge,
          children: [
            const TextSpan(text: "'"),
            TextSpan(
              text: widget.unknownAlias,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold),
            ),
            const TextSpan(text: "' 는 어떤 근무인가요?"),
          ],
        ),
      ),
      content: DropdownButton<String>(
        value: _selectedCode,
        isExpanded: true,
        items: widget.standardShifts.map((shift) {
          return DropdownMenuItem<String>(
            value: shift.abbreviation,
            child: Text('${shift.name} (${shift.abbreviation})'),
          );
        }).toList(),
        onChanged: (value) => setState(() => _selectedCode = value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context), // 취소
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: () async {
            if (_selectedCode != null) {
              // DB에 alias 저장
              final code = StandardShift.values
                  .firstWhere((e) => e.name == _selectedCode);

              await _aliasService.saveAlias(widget.unknownAlias, code);

              Navigator.pop(context, _selectedCode);
            }
          },
          child: const Text('학습 및 저장'),
        ),
      ],
    );
  }
}

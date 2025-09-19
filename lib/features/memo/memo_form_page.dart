// lib/features/memo/memo_form_page.dart

import 'package:flutter/material.dart';
import 'package:my_new_test_app/services/memo_service.dart';
import 'package:intl/intl.dart';

class MemoFormPage extends StatefulWidget {
  const MemoFormPage({super.key, required this.initialDateTime});
  final DateTime initialDateTime;

  @override
  State<MemoFormPage> createState() => _MemoFormPageState();
}

class _MemoFormPageState extends State<MemoFormPage> {
  final _ctrl = TextEditingController();
  late DateTime _date;
  late TimeOfDay _time;

  @override
  void initState() {
    super.initState();
    _date = DateTime(widget.initialDateTime.year, widget.initialDateTime.month,
        widget.initialDateTime.day);
    _time = TimeOfDay.fromDateTime(widget.initialDateTime);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    final dt =
        DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);
    await MemoService().addMemo(
      text: text,
      color: const Color(0xFF6C4CE8).value,
      startTime: dt,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('메모가 저장되었습니다.')));
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('메모 추가')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _ctrl,
            maxLines: 6,
            decoration: const InputDecoration(
              hintText: '메모 내용을 입력하세요',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton.icon(
                icon: const Icon(Icons.event),
                label: Text(DateFormat('yyyy.MM.dd').format(_date)),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => _date = picked);
                },
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                icon: const Icon(Icons.access_time),
                label: Text(
                    '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}'),
                onPressed: () async {
                  final picked = await showTimePicker(
                      context: context, initialTime: _time);
                  if (picked != null) setState(() => _time = picked);
                },
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save_outlined),
                label: const Text('저장'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

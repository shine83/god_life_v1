// lib/features/work_schedule/widgets/add_single_schedule_dialog.dart

import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:my_new_test_app/core/models/calendar_event.dart';
import 'package:my_new_test_app/services/work_schedule_service.dart';
import 'package:intl/intl.dart';

class AddSingleScheduleDialog extends StatefulWidget {
  final DateTime selectedDate;
  final CalendarEvent? eventToEdit;

  const AddSingleScheduleDialog({
    super.key,
    required this.selectedDate,
    this.eventToEdit,
  });

  @override
  State<AddSingleScheduleDialog> createState() =>
      _AddSingleScheduleDialogState();
}

class _AddSingleScheduleDialogState extends State<AddSingleScheduleDialog> {
  final _formKey = GlobalKey<FormState>();
  final _svc = WorkScheduleService();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _abbrCtrl;
  late final TextEditingController _memoCtrl;
  late final TextEditingController _todoCtrl;

  late DateTime _startTime;
  late DateTime _endTime;
  late Color _color;

  bool get _isEditMode => widget.eventToEdit != null;

  @override
  void initState() {
    super.initState();
    _initializeFormValues();
  }

  // [수정] _todoCtrl 초기화 코드 추가
  void _initializeFormValues() {
    _todoCtrl = TextEditingController(); // <-- ✨ 에러 해결을 위해 이 줄을 추가했습니다.

    if (_isEditMode) {
      final event = widget.eventToEdit!;
      final originalData = (event.originalData as Map?) ?? {};
      _nameCtrl = TextEditingController(text: event.title);
      _abbrCtrl = TextEditingController(
          text: event.short ?? (originalData['abbreviation'] ?? ''));
      _memoCtrl = TextEditingController(
          text: event.memo ?? (originalData['memo'] ?? ''));
      _color = event.color ?? const Color(0xFF5B8DEF);
      _startTime = _parseHHmm(originalData['start_time']?.toString()) ??
          _defaultStartTime();
      _endTime =
          _parseHHmm(originalData['end_time']?.toString()) ?? _defaultEndTime();
    } else {
      _nameCtrl = TextEditingController();
      _abbrCtrl = TextEditingController();
      _memoCtrl = TextEditingController();
      _color = const Color(0xFF5B8DEF);
      _startTime = _defaultStartTime();
      _endTime = _defaultEndTime();
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _abbrCtrl.dispose();
    _memoCtrl.dispose();
    _todoCtrl.dispose();
    super.dispose();
  }

  DateTime _defaultStartTime() {
    final d = widget.selectedDate;
    return DateTime(d.year, d.month, d.day, 9, 0);
  }

  DateTime _defaultEndTime() {
    final d = widget.selectedDate;
    return DateTime(d.year, d.month, d.day, 18, 0);
  }

  DateTime? _parseHHmm(String? hhmmss) {
    if (hhmmss == null || hhmmss.isEmpty) return null;
    final parts = hhmmss.split(':');
    if (parts.length < 2) return null;
    final d = widget.selectedDate;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    return DateTime(d.year, d.month, d.day, h, m);
  }

  double _calculateNightHours(DateTime start, DateTime end) {
    var e = end;
    if (e.isBefore(start)) e = e.add(const Duration(days: 1));
    final nightStart = DateTime(start.year, start.month, start.day, 22);
    final nightEnd = DateTime(start.year, start.month, start.day, 6)
        .add(const Duration(days: 1));
    final sEff = start.isAfter(nightStart) ? start : nightStart;
    final eEff = e.isBefore(nightEnd) ? e : nightEnd;
    if (eEff.isAfter(sEff)) {
      return eEff.difference(sEff).inMinutes / 60.0;
    }
    return 0.0;
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final title = _nameCtrl.text.trim().isEmpty
        ? _abbrCtrl.text.trim().toUpperCase()
        : _nameCtrl.text.trim();
    final abbr = _abbrCtrl.text.trim().toUpperCase();
    if (abbr.isEmpty) {
      _toast('약어를 입력해주세요.');
      return;
    }
    final night = _calculateNightHours(_startTime, _endTime);
    final todoText = _todoCtrl.text.trim();

    try {
      if (_isEditMode) {
        final eventId = (widget.eventToEdit!.originalData as Map?)?['id'];
        if (eventId == null) {
          _toast('오류: 원본 ID를 찾을 수 없습니다.');
          return;
        }
        await _svc.updateScheduleById(
          id: eventId.toString(),
          title: title,
          abbreviation: abbr,
          memo: _memoCtrl.text.trim(),
          color: _color.value,
          startTime: _startTime,
          endTime: _endTime,
          nightHours: night,
        );
      } else {
        await _svc.addWorkSchedule(
          title: title,
          memo: _memoCtrl.text.trim(),
          color: _color.value,
          startDate: widget.selectedDate,
          endDate: widget.selectedDate,
          nightHours: night,
          abbreviation: abbr,
          startTime: _startTime,
          endTime: _endTime,
        );
      }

      if (todoText.isNotEmpty) {
        await _svc.insertMemo(todoText, widget.selectedDate);
      }

      if (!mounted) return;
      _toast('✅ 저장되었습니다.');
      Navigator.pop(context, true);
    } catch (e) {
      _toast('저장 실패: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final cs = base.colorScheme;
    final isDark = base.brightness == Brightness.dark;

    final localTheme = base.copyWith(
      cardTheme: base.cardTheme.copyWith(
        color: isDark ? const Color(0xFF171717) : Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0.5,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: isDark
            ? Colors.white.withOpacity(0.06)
            : cs.surfaceContainerHighest.withOpacity(0.40),
        hintStyle: TextStyle(color: cs.onSurface.withOpacity(0.55)),
        labelStyle: TextStyle(
          color: cs.onSurface.withOpacity(0.90),
          fontWeight: FontWeight.w600,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.outline.withOpacity(0.28)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.primary, width: 1.6),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: cs.primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      dialogTheme: DialogThemeData(backgroundColor: cs.surface),
    );
    return Theme(
      data: localTheme,
      child: Dialog(
        insetPadding: const EdgeInsets.all(12),
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: localTheme.dialogBackgroundColor,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _isEditMode ? '근무 일정 편집' : '근무 일정 추가',
                style: base.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                DateFormat('yyyy.MM.dd (E)', 'ko_KR')
                    .format(widget.selectedDate),
                style: base.textTheme.bodyMedium
                    ?.copyWith(color: cs.onSurface.withOpacity(0.7)),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              children: [
                                TextFormField(
                                  controller: _nameCtrl,
                                  decoration:
                                      const InputDecoration(labelText: '근무명'),
                                  textInputAction: TextInputAction.next,
                                ),
                                const SizedBox(height: 10),
                                TextFormField(
                                  controller: _abbrCtrl,
                                  decoration:
                                      const InputDecoration(labelText: '약어'),
                                  textAlign: TextAlign.center,
                                  validator: (v) =>
                                      (v == null || v.trim().isEmpty)
                                          ? '약어를 입력하세요'
                                          : null,
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                        child: _timePicker(
                                            label: '시작',
                                            time: _startTime,
                                            onPick: (t) => setState(
                                                () => _startTime = t))),
                                    const SizedBox(width: 8),
                                    Expanded(
                                        child: _timePicker(
                                            label: '종료',
                                            time: _endTime,
                                            onPick: (t) =>
                                                setState(() => _endTime = t))),
                                    const SizedBox(width: 8),
                                    GestureDetector(
                                      onTap: _pickColor,
                                      child: Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: _color,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                              color: cs.onSurface
                                                  .withOpacity(0.12),
                                              width: 1),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                TextFormField(
                                  controller: _memoCtrl,
                                  minLines: 2,
                                  maxLines: 3,
                                  decoration: const InputDecoration(
                                      labelText: '근무 관련 메모 (선택)'),
                                ),
                                Builder(builder: (context) {
                                  final night = _calculateNightHours(
                                      _startTime, _endTime);
                                  if (night <= 0) {
                                    return const SizedBox.shrink();
                                  }
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Row(
                                      children: [
                                        Icon(Icons.nightlight_round,
                                            size: 14,
                                            color:
                                                cs.onSurface.withOpacity(0.6)),
                                        const SizedBox(width: 6),
                                        Text(
                                            '야간 시간: ${night.toStringAsFixed(1)} 시간',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: cs.onSurface
                                                    .withOpacity(0.75))),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        ),
                        if (!_isEditMode) ...[
                          const SizedBox(height: 12),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: TextFormField(
                                controller: _todoCtrl,
                                minLines: 2,
                                maxLines: 4,
                                decoration: const InputDecoration(
                                  labelText: 'To Do List (선택)',
                                  hintText: '이 날짜에 할 일을 입력하세요.',
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('취소'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _save,
                    child: const Text('저장'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _timePicker({
    required String label,
    required DateTime time,
    required ValueChanged<DateTime> onPick,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final deco = InputDecoration(
      labelText: label,
      filled: true,
      fillColor: theme.brightness == Brightness.dark
          ? Colors.white.withOpacity(0.06)
          : cs.surfaceContainerHighest.withOpacity(0.40),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    );

    return GestureDetector(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(time),
          helpText: '$label 시간 선택',
        );
        if (picked != null) {
          final d = widget.selectedDate;
          onPick(DateTime(d.year, d.month, d.day, picked.hour, picked.minute));
        }
      },
      child: InputDecorator(
        decoration: deco,
        child: Center(
          child: Text(
            DateFormat('HH:mm').format(time),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          ),
        ),
      ),
    );
  }

  void _pickColor() {
    showDialog<Color>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('색상 선택'),
        content: SingleChildScrollView(
          child: BlockPicker(
            pickerColor: _color,
            onColorChanged: (c) => setState(() => _color = c),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('완료'),
          ),
        ],
      ),
    );
  }
}

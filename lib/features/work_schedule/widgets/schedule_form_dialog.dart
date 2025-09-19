import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_new_test_app/core/models/shift_type.dart';
import 'package:my_new_test_app/features/onboarding/tutorial_service.dart';
import 'package:my_new_test_app/features/work_schedule/utils/shift_alias_resolver.dart';
import 'package:my_new_test_app/features/work_schedule/widgets/learn_alias_dialog.dart';
import 'package:my_new_test_app/services/schedule_notifier.dart';
import 'package:my_new_test_app/services/work_schedule_service.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ScheduleFormDialog extends ConsumerStatefulWidget {
  final DateTime initialDate;
  final bool isTutorialMode;

  const ScheduleFormDialog({
    super.key,
    required this.initialDate,
    this.isTutorialMode = false,
  });

  @override
  ConsumerState<ScheduleFormDialog> createState() => _ScheduleFormDialogState();
}

class _ScheduleFormDialogState extends ConsumerState<ScheduleFormDialog> {
  final _svc = WorkScheduleService();
  List<_WorkShift> _shifts = [];
  bool _isLoading = true;
  bool _editTypes = false;
  String _repeatPattern = '';
  int _repeatCount = 1;
  late DateTime _startDate;
  final _patternController = TextEditingController();

  final Map<String, _WorkShift> _defaultShifts = {
    'D': _WorkShift(
        name: '주간',
        code: 'D',
        start: DateTime(2025, 1, 1, 9, 0),
        end: DateTime(2025, 1, 1, 18, 0),
        color: const Color(0xFF3498DB)),
    'E': _WorkShift(
        name: '오후',
        code: 'E',
        start: DateTime(2025, 1, 1, 15, 0),
        end: DateTime(2025, 1, 1, 23, 0),
        color: const Color(0xFFE67E22)),
    'N': _WorkShift(
        name: '야간',
        code: 'N',
        start: DateTime(2025, 1, 1, 23, 0),
        end: DateTime(2025, 1, 2, 7, 0),
        color: const Color(0xFF34495E)),
  };

  @override
  void initState() {
    super.initState();
    _startDate = widget.initialDate;
    _loadInitialData();

    if (widget.isTutorialMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          GuidedTourController(context).startShiftFormTour();
        }
      });
    }
  }

  @override
  void dispose() {
    _patternController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final fetchedTypes = await _svc.listShiftTypes();
      final byCode = <String, Map<String, dynamic>>{};
      for (final s in fetchedTypes) {
        final code = (s['code'] ?? '').toString().trim().toUpperCase();
        if (code.isEmpty) continue;
        byCode[code] = s;
      }

      final now = DateTime.now();
      DateTime parseTime(String? t) {
        if (t == null || t.isEmpty) return now;
        final p = t.split(':');
        final h = int.tryParse(p[0]) ?? 0;
        final m = int.tryParse(p.length > 1 ? p[1] : '0') ?? 0;
        return DateTime(now.year, now.month, now.day, h, m);
      }

      if (byCode.isNotEmpty) {
        _shifts = byCode.values.map((s) {
          final num colorNum = s['color'] ?? 0xFF5B8DEF;
          return _WorkShift(
            name: (s['name'] ?? '').toString(),
            code: (s['code'] ?? '').toString().trim().toUpperCase(),
            start: parseTime(s['start_time'] as String?),
            end: parseTime(s['end_time'] as String?),
            color: Color(colorNum.toInt()),
          );
        }).toList();
      } else {
        _shifts = [_WorkShift.empty()];
      }

      final prefs = await SharedPreferences.getInstance();
      _repeatPattern = prefs.getString('lastRepeatPattern') ?? '';
      _patternController.text = _repeatPattern;
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _hhmmss(DateTime d) {
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}:${d.second.toString().padLeft(2, '0')}';
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

  Future<void> _saveShiftTypes() async {
    for (final s in _shifts) {
      if (s.code.trim().isEmpty) {
        _toast('약어를 모두 입력해주세요.');
        return;
      }
    }
    try {
      final defs = _shifts
          .map((s) => {
                'name': s.name.trim(),
                'code': s.code.trim().toUpperCase(),
                'start_time': _hhmmss(s.start),
                'end_time': _hhmmss(s.end),
                'color': s.color.value,
              })
          .toList();
      await _svc.upsertShiftTypes(defs);
      _toast('근무유형이 저장되었습니다.');
    } catch (e) {
      _toast('근무유형 저장 실패: $e');
    }
  }

  Future<void> _savePatternAsSchedules() async {
    final patternInput = _patternController.text.trim();
    if (patternInput.isEmpty) {
      _toast('패턴을 입력해주세요.');
      return;
    }
    if (_repeatCount <= 0) {
      _toast('반복 횟수를 1 이상으로 입력해주세요.');
      return;
    }
    setState(() => _isLoading = true);

    final tokens = patternInput
        .split(RegExp(r'[\s,-]+'))
        .where((s) => s.isNotEmpty)
        .toList();
    final standardCodes = <String>[];
    final standardShiftsForDialog = _shifts
        .map((s) => ShiftType(
              name: s.name,
              abbreviation: s.code,
              startTime: TimeOfDay.fromDateTime(s.start),
              endTime: TimeOfDay.fromDateTime(s.end),
              color: s.color,
            ))
        .toList();

    for (final token in tokens) {
      final String? resolvedCode = ShiftAliasResolver.resolve(token);
      if (resolvedCode != null) {
        standardCodes.add(resolvedCode);
      } else {
        bool allCharsResolved = true;
        final tempCharCodes = <String>[];
        for (final char in token.split('')) {
          final String? charResolvedCode = ShiftAliasResolver.resolve(char);
          if (charResolvedCode != null) {
            tempCharCodes.add(charResolvedCode);
          } else {
            allCharsResolved = false;
            break;
          }
        }
        if (allCharsResolved && tempCharCodes.isNotEmpty) {
          standardCodes.addAll(tempCharCodes);
        } else {
          if (!mounted) return;
          final learnedCode = await showDialog<String>(
            context: context,
            barrierDismissible: false,
            builder: (_) => LearnAliasDialog(
              unknownAlias: token,
              standardShifts: standardShiftsForDialog,
            ),
          );
          if (learnedCode == null) {
            setState(() => _isLoading = false);
            return;
          }
          ShiftAliasResolver.learnAlias(token, learnedCode);
          await _svc.addAlias(token, learnedCode);
          standardCodes.add(learnedCode);
        }
      }
    }

    if (standardCodes.isEmpty) {
      setState(() => _isLoading = false);
      _toast('유효한 근무 패턴을 찾지 못했습니다.');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastRepeatPattern', patternInput);

    try {
      for (int i = 0; i < standardCodes.length * _repeatCount; i++) {
        final date = _startDate.add(Duration(days: i));
        final code = standardCodes[i % standardCodes.length];

        if (code == 'O') {
          // 휴식일은 알림 예약 안 함
          await _svc.addWorkSchedule(
            title: '휴식',
            abbreviation: '휴',
            color: Colors.grey.value,
            startDate: date,
            endDate: date,
            scheduleNotifications: false,
          );
        } else {
          final shiftType = _shifts.firstWhere(
            (s) => s.code == code,
            orElse: () => _defaultShifts[code]!,
          );

          // 저장 + 즉시 알림 예약까지 (서비스 내부에서 안전하게 try/catch 처리)
          await _svc.addWorkSchedule(
            title: shiftType.name,
            abbreviation: shiftType.code,
            color: shiftType.color.value,
            startDate: date,
            endDate: date,
            startTime: shiftType.start,
            endTime: shiftType.end,
            nightHours: _calculateNightHours(shiftType.start, shiftType.end),
            scheduleNotifications: true,
            // notifyOffsets: null → NotificationService 기본값 사용
          );
        }
      }
      if (!mounted) return;
      _toast('✅ 저장되었습니다.');
      ref.read(scheduleNotifierProvider.notifier).notify();
      Navigator.pop(context, true);
    } catch (e) {
      _toast('저장 중 오류: $e');
      setState(() => _isLoading = false);
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
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '근무 일정 추가',
                            style: base.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Row(
                          children: [
                            Text('근무유형 잠금', style: base.textTheme.bodySmall),
                            const SizedBox(width: 6),
                            Switch.adaptive(
                              value: !_editTypes,
                              onChanged: (locked) {
                                setState(() => _editTypes = !locked);
                              },
                            )
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.lock, size: 14),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _editTypes
                                ? '근무유형을 편집 중입니다.'
                                : '근무유형은 설정에서 관리됩니다. (읽기 전용)',
                            style: base.textTheme.bodySmall?.copyWith(
                              color: cs.onSurface.withOpacity(0.7),
                            ),
                          ),
                        ),
                        if (_editTypes)
                          OutlinedButton.icon(
                            icon: const Icon(Icons.save_outlined, size: 18),
                            label: const Text('유형 저장'),
                            onPressed: _saveShiftTypes,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView(
                        padding: EdgeInsets.zero,
                        children: [
                          ..._shifts.asMap().entries.map((e) {
                            final i = e.key;
                            final s = e.value;
                            return _ShiftCard(
                              shift: s,
                              editable: _editTypes,
                              onChanged: (newShift) =>
                                  setState(() => _shifts[i] = newShift),
                              onRemove: _editTypes
                                  ? () => setState(() {
                                        if (_shifts.length > 1) {
                                          _shifts.removeAt(i);
                                        }
                                      })
                                  : null,
                            );
                          }),
                          if (_editTypes) ...[
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _shifts.add(_WorkShift.empty());
                                });
                              },
                              icon: const Icon(Icons.add_circle_outline),
                              label: const Text('근무유형 추가'),
                            ),
                          ],
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _patternController,
                            decoration: const InputDecoration(
                              labelText: '패턴 (예: 주-야-비-휴 / D-A-N-O)',
                              isDense: true,
                            ),
                            onChanged: (v) => _repeatPattern = v.trim(),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: TextButton.icon(
                                  icon: const Icon(Icons.calendar_today,
                                      size: 16),
                                  label: Text(
                                    '시작일: ${DateFormat('yyyy.MM.dd').format(_startDate)}',
                                  ),
                                  onPressed: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: _startDate,
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime(2100),
                                    );
                                    if (picked != null) {
                                      setState(() => _startDate = picked);
                                    }
                                  },
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10, horizontal: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 76,
                                child: TextFormField(
                                  initialValue: _repeatCount.toString(),
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  decoration: const InputDecoration(
                                    labelText: '반복',
                                    isDense: true,
                                  ),
                                  onChanged: (v) =>
                                      _repeatCount = int.tryParse(v) ?? 1,
                                ),
                              ),
                            ],
                          ),
                        ],
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
                          key: TutorialTargets.shiftFormSaveKey,
                          onPressed:
                              _isLoading ? null : _savePatternAsSchedules,
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
}

class _ShiftCard extends StatelessWidget {
  const _ShiftCard({
    required this.shift,
    required this.editable,
    required this.onChanged,
    this.onRemove,
  });
  final _WorkShift shift;
  final bool editable;
  final ValueChanged<_WorkShift> onChanged;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    InputDecoration deco(String label) => InputDecoration(
          labelText: label,
          isDense: true,
          filled: true,
          fillColor: theme.brightness == Brightness.dark
              ? Colors.white.withOpacity(0.06)
              : cs.surfaceContainerHighest.withOpacity(0.40),
        );
    Future<void> pickTime({
      required String label,
      required DateTime current,
      required void Function(DateTime) set,
    }) async {
      final t = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(current),
        helpText: '$label 시간 선택',
      );
      if (t != null) {
        final now = DateTime.now();
        set(DateTime(now.year, now.month, now.day, t.hour, t.minute));
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    enabled: editable,
                    initialValue: shift.name,
                    decoration: deco('근무명'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    onChanged: editable
                        ? (v) => onChanged(shift.copyWith(name: v))
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 72,
                  child: TextFormField(
                    enabled: editable,
                    initialValue: shift.code,
                    textAlign: TextAlign.center,
                    decoration: deco('약어'),
                    onChanged: editable
                        ? (v) =>
                            onChanged(shift.copyWith(code: v.toUpperCase()))
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 44,
                  height: 44,
                  child: IconButton(
                    tooltip: '삭제',
                    onPressed: editable ? onRemove : null,
                    icon: const Icon(Icons.remove_circle_outline),
                    color:
                        editable ? cs.onSurface.withOpacity(0.6) : cs.outline,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: editable
                      ? GestureDetector(
                          onTap: () => pickTime(
                            label: '시작',
                            current: shift.start,
                            set: (d) => onChanged(shift.copyWith(start: d)),
                          ),
                          child: InputDecorator(
                            decoration: deco('시작'),
                            child: Center(
                              child: Text(
                                DateFormat('HH:mm').format(shift.start),
                                style: const TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        )
                      : InputDecorator(
                          decoration: deco('시작'),
                          child: Center(
                            child: Text(
                              DateFormat('HH:mm').format(shift.start),
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: editable
                      ? GestureDetector(
                          onTap: () => pickTime(
                            label: '종료',
                            current: shift.end,
                            set: (d) => onChanged(shift.copyWith(end: d)),
                          ),
                          child: InputDecorator(
                            decoration: deco('종료'),
                            child: Center(
                              child: Text(
                                DateFormat('HH:mm').format(shift.end),
                                style: const TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        )
                      : InputDecorator(
                          decoration: deco('종료'),
                          child: Center(
                            child: Text(
                              DateFormat('HH:mm').format(shift.end),
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: !editable
                      ? null
                      : () async {
                          final picked = await showDialog<Color>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('색상 선택'),
                              content: SingleChildScrollView(
                                child: BlockPicker(
                                  pickerColor: shift.color,
                                  onColorChanged: (c) =>
                                      Navigator.of(context).pop(c),
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: const Text('닫기'),
                                )
                              ],
                            ),
                          );
                          if (picked != null) {
                            onChanged(shift.copyWith(color: picked));
                          }
                        },
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: shift.color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: cs.onSurface.withOpacity(0.12),
                        width: 1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Builder(builder: (context) {
              double nightHours(DateTime start, DateTime end) {
                var e = end;
                if (e.isBefore(start)) e = e.add(const Duration(days: 1));
                final nightStart =
                    DateTime(start.year, start.month, start.day, 22);
                final nightEnd = DateTime(start.year, start.month, start.day, 6)
                    .add(const Duration(days: 1));
                final sEff = start.isAfter(nightStart) ? start : nightStart;
                final eEff = e.isBefore(nightEnd) ? e : nightEnd;
                if (eEff.isAfter(sEff)) {
                  return eEff.difference(sEff).inMinutes / 60.0;
                }
                return 0.0;
              }

              final n = nightHours(shift.start, shift.end);
              if (n <= 0) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Icon(Icons.nightlight_round,
                        size: 14, color: cs.onSurface.withOpacity(0.6)),
                    const SizedBox(width: 6),
                    Text(
                      '야간 시간: ${n.toStringAsFixed(1)} 시간',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withOpacity(0.75),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _WorkShift {
  final String name;
  final String code;
  final DateTime start;
  final DateTime end;
  final Color color;

  _WorkShift({
    required this.name,
    required this.code,
    required this.start,
    required this.end,
    required this.color,
  });

  _WorkShift copyWith({
    String? name,
    String? code,
    DateTime? start,
    DateTime? end,
    Color? color,
  }) {
    return _WorkShift(
      name: name ?? this.name,
      code: code ?? this.code,
      start: start ?? this.start,
      end: end ?? this.end,
      color: color ?? this.color,
    );
  }

  factory _WorkShift.empty() => _WorkShift(
        name: '',
        code: '',
        start: DateTime.now(),
        end: DateTime.now().add(const Duration(hours: 8)),
        color: const Color(0xFF5B8DEF),
      );
}

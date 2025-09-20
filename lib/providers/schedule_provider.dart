// lib/providers/schedule_provider.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:god_life_v1/core/models/calendar_event.dart';
import 'package:god_life_v1/core/models/work_schedule.dart';
import 'package:god_life_v1/services/work_schedule_service.dart';

// 1) WorkScheduleService 프로바이더
final workScheduleServiceProvider = Provider<WorkScheduleService>((ref) {
  return WorkScheduleService();
});

// 2) 캘린더 상태 프로바이더
final focusedDayProvider = StateProvider<DateTime>((ref) => DateTime.now());
final selectedDayProvider = StateProvider<DateTime?>((ref) => null);

// 3) 근무 일정 (월 범위)
final scheduleProvider =
    AsyncNotifierProvider<ScheduleNotifier, Map<DateTime, List<CalendarEvent>>>(
  () => ScheduleNotifier(),
);

class ScheduleNotifier
    extends AsyncNotifier<Map<DateTime, List<CalendarEvent>>> {
  @override
  Future<Map<DateTime, List<CalendarEvent>>> build() async {
    final focusedDay = ref.watch(focusedDayProvider);
    return _fetchSchedules(focusedDay);
  }

  Future<Map<DateTime, List<CalendarEvent>>> _fetchSchedules(
      DateTime date) async {
    final service = ref.read(workScheduleServiceProvider);

    final firstDay = DateTime(date.year, date.month, 1);
    final lastDay = DateTime(date.year, date.month + 1, 0);

    final List<WorkSchedule> all =
        await service.getSchedulesInRange(firstDay: firstDay, lastDay: lastDay);

    final eventMap = <DateTime, List<CalendarEvent>>{};

    for (final ws in all) {
      // WorkSchedule에는 deletedAt 필드가 없으므로 단순 매핑
      final map = ws.toMap();

      final dayKey =
          DateTime(ws.startDate.year, ws.startDate.month, ws.startDate.day);

      final int colorValue = _parseColor(map['color']) ?? Colors.blue.value;

      // title 우선, 없으면 pattern, 둘 다 비면 '근무'
      final String title = (ws.title != null && ws.title!.trim().isNotEmpty)
          ? ws.title!.trim()
          : (ws.pattern.trim().isNotEmpty ? ws.pattern.trim() : '근무');

      final ce = CalendarEvent(
        title: title,
        isTodo: false,
        color: Color(colorValue),
        memo: ws.memo,
        short: ws.abbreviation,
        originalData: map,
        date: ws.startDate,
      );

      eventMap.putIfAbsent(dayKey, () => []).add(ce);
    }

    return eventMap;
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  int? _parseColor(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is String) return int.tryParse(v);
    return null;
  }
}

// 4) 메모(Todo) 리스트
final memoProvider = FutureProvider<List<CalendarEvent>>((ref) async {
  final service = ref.read(workScheduleServiceProvider);
  final List<Map<String, dynamic>> rows = await service.listAllMemos();

  final todos = <CalendarEvent>[];
  for (final r in rows) {
    // 만약 테이블에 deleted_at이 있다면 이 가드로 소프트삭제 스킵 (없어도 무해)
    if (r['deleted_at'] != null) continue;

    final dStr = r['date']?.toString();
    if (dStr == null) continue;
    final d = DateTime.tryParse(dStr);
    if (d == null) continue;

    final String text = (r['text']?.toString().trim().isNotEmpty == true)
        ? r['text'].toString()
        : '메모';
    final int colorValue = _parseColor(r['color']) ?? Colors.grey.value;

    todos.add(CalendarEvent(
      title: text,
      isTodo: true,
      color: Color(colorValue),
      originalData: r,
      date: d,
    ));
  }

  todos.sort((a, b) => a.date!.compareTo(b.date!));
  return todos;
});

int? _parseColor(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is String) return int.tryParse(v);
  return null;
}

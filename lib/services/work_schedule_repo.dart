// lib/services/work_schedule_repo.dart
import 'package:supabase_flutter/supabase_flutter.dart';

/// 근무 저장 전용 레포 (user_id+work_day 유니크 대응)
class WorkScheduleRepo {
  WorkScheduleRepo(this._sp);
  final SupabaseClient _sp;

  /// DateTime -> 'yyyy-MM-dd' (로컬 기준 work_day)
  String _toWorkDay(DateTime dt) {
    final d = DateTime(dt.year, dt.month, dt.day);
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }

  /// 단일 근무 저장 (같은 날 있으면 업데이트 처리)
  Future<Map<String, dynamic>> upsertOne({
    required String userId,
    required DateTime startAt,
    required DateTime endAt,
    required String shiftCode, // 'day' | 'evening' | 'night' | 'off'
    String? title,
    String? notes,
  }) async {
    final payload = {
      'user_id': userId,
      'start_date': startAt.toIso8601String(),
      'end_date': endAt.toIso8601String(),
      'shift_code': shiftCode,
      'title': title ?? shiftCode,
      'notes': notes,
      'work_day': _toWorkDay(startAt), // 🔑 유니크 키 일부
    };

    final row = await _sp
        .from('work_schedules')
        .upsert(payload, onConflict: 'user_id,work_day')
        .select()
        .single();

    return Map<String, dynamic>.from(row as Map);
  }

  /// 여러 날짜 범위를 한 번에 저장 (각 날짜별 1행 upsert)
  Future<List<Map<String, dynamic>>> upsertRange({
    required String userId,
    required DateTime startAt,
    required DateTime endAt,
    required String shiftCode,
    String? title,
    String? notes,
  }) async {
    final days = <DateTime>[];
    var d = DateTime(startAt.year, startAt.month, startAt.day);
    final last = DateTime(endAt.year, endAt.month, endAt.day);

    while (!d.isAfter(last)) {
      days.add(d);
      d = d.add(const Duration(days: 1));
    }

    final rows = days.map((day) {
      final s =
          DateTime(day.year, day.month, day.day, startAt.hour, startAt.minute);
      final e =
          DateTime(day.year, day.month, day.day, endAt.hour, endAt.minute);
      return {
        'user_id': userId,
        'start_date': s.toIso8601String(),
        'end_date': e.toIso8601String(),
        'shift_code': shiftCode,
        'title': title ?? shiftCode,
        'notes': notes,
        'work_day': _toWorkDay(day), // 🔑 충돌 키
      };
    }).toList();

    final res = await _sp
        .from('work_schedules')
        .upsert(rows, onConflict: 'user_id,work_day')
        .select();

    return (res as List).map((e) => Map<String, dynamic>.from(e)).toList();
  }

  /// 특정 날짜 삭제
  Future<void> deleteByDay({
    required String userId,
    required DateTime day,
  }) async {
    await _sp
        .from('work_schedules')
        .delete()
        .eq('user_id', userId)
        .eq('work_day', _toWorkDay(day));
  }
}

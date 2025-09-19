// lib/services/work_schedule_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_new_test_app/core/models/work_schedule.dart';
import 'package:my_new_test_app/services/notification_service.dart';

class WorkScheduleService {
  final SupabaseClient _sp = Supabase.instance.client;

  String _dateOnlyISO(DateTime d) =>
      DateTime(d.year, d.month, d.day).toIso8601String();

  String _yyyyMmDd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String? _hhmm(DateTime? t) {
    if (t == null) return null;
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    final s = t.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  Future<String> _ensureUserId() async {
    final u = _sp.auth.currentUser;
    if (u == null) throw Exception('로그인이 필요합니다.');
    return u.id;
  }

  DateTime _composeStartDateTime({
    required DateTime startDate,
    DateTime? startTime,
  }) {
    final clock = startTime ??
        DateTime(startDate.year, startDate.month, startDate.day, 9, 0);
    return DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
      clock.hour,
      clock.minute,
      clock.second,
    );
  }

  Future<Map<String, dynamic>> _loadScheduleRowById(String id) async {
    final userId = await _ensureUserId();
    final row = await _sp
        .from('work_schedules')
        .select()
        .eq('id', id)
        .eq('user_id', userId)
        .filter('deleted_at', 'is', null)
        .single();
    return Map<String, dynamic>.from(row as Map);
  }

  // ── Shift Types ────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> listShiftTypes() async {
    final userId = await _ensureUserId();
    final res = await _sp
        .from('shift_types')
        .select()
        .eq('user_id', userId)
        .order('code', ascending: true);
    return List<Map<String, dynamic>>.from(res as List);
  }

  Future<void> upsertShiftTypesForUser(
    String userId,
    List<Map<String, dynamic>> types,
  ) async {
    final dataToSave = types.map((t) => {...t, 'user_id': userId}).toList();
    if (dataToSave.isEmpty) return;
    await _sp.from('shift_types').delete().eq('user_id', userId);
    await _sp.from('shift_types').insert(dataToSave);
  }

  Future<void> upsertShiftTypes(List<Map<String, dynamic>> defs) async {
    final userId = await _ensureUserId();
    await upsertShiftTypesForUser(userId, defs);
  }

  // ── Work Schedules (Soft Delete + 알림) ────────────────────────────────────

  /// 근무 저장/덮어쓰기(하루 1건 고유) → 생성/유지된 id 반환
  Future<String> addWorkSchedule({
    required String title,
    required int color,
    required DateTime startDate,
    required DateTime endDate,
    double nightHours = 0,
    String? memo,
    String? abbreviation,
    DateTime? startTime,
    DateTime? endTime,
    bool scheduleNotifications = true,
  }) async {
    final userId = await _ensureUserId();

    // 날짜 파생값
    final workDay = _yyyyMmDd(startDate);

    final payload = <String, dynamic>{
      'user_id': userId,
      'title': title,
      'memo': memo,
      'color': color,
      'start_date': _dateOnlyISO(startDate),
      'end_date': _dateOnlyISO(endDate),
      'night_hours': nightHours,
      'abbreviation': abbreviation,
      'start_time': _hhmm(startTime),
      'end_time': _hhmm(endTime),
      'work_day': workDay, // ★ 하루-유니크 키
      'deleted_at': null, // 소프트 삭제 무효화(복원 겸)
    };

    // 같은 (user_id, work_day)이면 덮어쓰기
    final inserted = await _sp
        .from('work_schedules')
        .upsert(payload, onConflict: 'user_id,work_day')
        .select('id')
        .single();

    final id = inserted['id'] as String;

    if (scheduleNotifications) {
      try {
        final clock = startTime ??
            DateTime(startDate.year, startDate.month, startDate.day, 9, 0);
        final startDateTime = DateTime(
          startDate.year,
          startDate.month,
          startDate.day,
          clock.hour,
          clock.minute,
        );
        final ok = await _tryScheduleNotification(
          id: id,
          startDateTime: startDateTime,
          title: title,
        );
        if (!ok) {
          // TODO: UI 계층에서 사용자에게 “알림 권한이 필요합니다” 안내
        }
      } catch (_) {}
    }

    return id;
  }

  Future<void> updateScheduleById({
    required String id,
    String? title,
    String? memo,
    int? color,
    DateTime? startDate,
    DateTime? endDate,
    double? nightHours,
    String? abbreviation,
    DateTime? startTime,
    DateTime? endTime,
    bool rescheduleNotifications = true,
  }) async {
    final userId = await _ensureUserId();

    Map<String, dynamic>? old;
    if (rescheduleNotifications) {
      try {
        old = await _loadScheduleRowById(id);
      } catch (_) {}
    }

    final update = <String, dynamic>{};
    if (title != null) update['title'] = title;
    if (memo != null) update['memo'] = memo;
    if (color != null) update['color'] = color;
    if (startDate != null) {
      update['start_date'] = _dateOnlyISO(startDate);
      update['work_day'] = _yyyyMmDd(startDate); // ★ 날짜 바뀌면 work_day도
    }
    if (endDate != null) update['end_date'] = _dateOnlyISO(endDate);
    if (nightHours != null) update['night_hours'] = nightHours;
    if (abbreviation != null) update['abbreviation'] = abbreviation;
    if (startTime != null) update['start_time'] = _hhmm(startTime);
    if (endTime != null) update['end_time'] = _hhmm(endTime);

    await _sp
        .from('work_schedules')
        .update(update)
        .eq('id', id)
        .eq('user_id', userId)
        .filter('deleted_at', 'is', null);

    if (rescheduleNotifications) {
      try {
        final fresh = await _loadScheduleRowById(id);
        await _rescheduleForRow(id, fresh);
      } catch (_) {}
    }
  }

  Future<void> _rescheduleForRow(String id, Map<String, dynamic> row,
      {Map<String, dynamic>? override}) async {
    final data = {...row, ...?override};

    final title = (data['title'] as String?) ?? '근무';
    final startIso = (data['start_date'] as String?) ?? '';
    final startTimeStr = (data['start_time'] as String?);
    final startDate = DateTime.tryParse(startIso) ?? DateTime.now();

    DateTime? startTime;
    if (startTimeStr != null && startTimeStr.isNotEmpty) {
      final parts = startTimeStr.split(':');
      if (parts.length >= 2) {
        final h = int.tryParse(parts[0]) ?? 9;
        final m = int.tryParse(parts[1]) ?? 0;
        startTime =
            DateTime(startDate.year, startDate.month, startDate.day, h, m);
      }
    }

    try {
      await NotificationService.I.cancelForShift(id);
      final startDateTime =
          _composeStartDateTime(startDate: startDate, startTime: startTime);
      await _tryScheduleNotification(
          id: id, startDateTime: startDateTime, title: title);
    } catch (_) {}
  }

  Future<void> deleteScheduleById(String id) async {
    final userId = await _ensureUserId();
    try {
      await NotificationService.I.cancelForShift(id);
    } catch (_) {}
    await _sp
        .from('work_schedules')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id)
        .eq('user_id', userId)
        .filter('deleted_at', 'is', null);
  }

  Future<void> deleteAllSchedules() async {
    final userId = await _ensureUserId();

    final idsRes = await _sp
        .from('work_schedules')
        .select('id')
        .eq('user_id', userId)
        .filter('deleted_at', 'is', null);

    final List<dynamic> rows = idsRes as List<dynamic>;
    for (final row in rows) {
      final id = row['id'] as String;
      try {
        await NotificationService.I.cancelForShift(id);
      } catch (_) {}
    }

    await _sp
        .from('work_schedules')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('user_id', userId)
        .filter('deleted_at', 'is', null);
  }

  Future<List<WorkSchedule>> getSchedulesInRange({
    required DateTime firstDay,
    required DateTime lastDay,
  }) async {
    final userId = await _ensureUserId();
    final start = DateTime(firstDay.year, firstDay.month, firstDay.day);
    final end = DateTime(lastDay.year, lastDay.month, lastDay.day, 23, 59, 59);

    final res = await _sp
        .from('work_schedules')
        .select()
        .eq('user_id', userId)
        .filter('deleted_at', 'is', null)
        .gte('start_date', start.toIso8601String())
        .lte('start_date', end.toIso8601String())
        .order('start_date', ascending: true);

    return (res as List)
        .map((m) => WorkSchedule.fromMap(m as Map<String, dynamic>))
        .toList();
  }

  Future<List<Map<String, dynamic>>> getWorkSchedules({
    required DateTime start,
    required DateTime end,
  }) async {
    final userId = await _ensureUserId();
    final startDay = DateTime(start.year, start.month, start.day);
    final endDay = DateTime(end.year, end.month, end.day, 23, 59, 59);

    final res = await _sp
        .from('work_schedules')
        .select()
        .eq('user_id', userId)
        .filter('deleted_at', 'is', null)
        .gte('start_date', startDay.toIso8601String())
        .lte('start_date', endDay.toIso8601String())
        .order('start_date', ascending: true);

    return List<Map<String, dynamic>>.from(res as List);
  }

  // ── Memos ────────────────────────────────────────────────────────────────

  Future<void> insertMemo(String text, DateTime date) async {
    final userId = await _ensureUserId();
    await _sp.from('memos').insert({
      'user_id': userId,
      'date': _yyyyMmDd(date),
      'text': text,
    });
  }

  Future<void> updateMemo(String id, String newText) async {
    final userId = await _ensureUserId();
    await _sp
        .from('memos')
        .update({'text': newText})
        .eq('id', id)
        .eq('user_id', userId)
        .filter('deleted_at', 'is', null);
  }

  Future<void> deleteMemo(String id) async {
    final userId = await _ensureUserId();
    await _sp
        .from('memos')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id)
        .eq('user_id', userId)
        .filter('deleted_at', 'is', null);
  }

  Future<List<Map<String, dynamic>>> listAllMemos() async {
    final userId = await _ensureUserId();
    final res = await _sp
        .from('memos')
        .select()
        .eq('user_id', userId)
        .filter('deleted_at', 'is', null)
        .order('date', ascending: true);

    return List<Map<String, dynamic>>.from(res as List);
  }

  // ── Shift Aliases ─────────────────────────────────────────────────────────

  Future<Map<String, String>> getAliasMap() async {
    final userId = await _ensureUserId();
    final res = await _sp
        .from('shift_aliases')
        .select('alias, standard_code')
        .eq('user_id', userId);

    final map = <String, String>{};
    for (final row in res) {
      map[(row['alias'] as String)] = (row['standard_code'] as String);
    }
    return map;
  }

  Future<void> addAlias(String alias, String standardCode) async {
    final userId = await _ensureUserId();
    await _sp.from('shift_aliases').upsert({
      'user_id': userId,
      'alias': alias.trim(),
      'standard_code': standardCode.trim(),
    }, onConflict: 'user_id, alias');
  }

  // ── 내부 헬퍼 ─────────────────────────────────────────────────────────────
  Future<bool> _tryScheduleNotification({
    required String id,
    required DateTime startDateTime,
    required String title,
  }) async {
    try {
      await NotificationService.I.scheduleForShift(
        scheduleId: id,
        startDateTimeLocal: startDateTime,
        title: title,
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}

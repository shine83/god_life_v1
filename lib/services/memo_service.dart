import 'package:supabase_flutter/supabase_flutter.dart';

class MemoService {
  final SupabaseClient _sb = Supabase.instance.client;

  String get _uid {
    final uid = _sb.auth.currentUser?.id;
    if (uid == null) throw StateError('Not signed in');
    return uid;
  }

  /// 메모 추가: memos(date, title, is_done[, deleted_at]) 스키마에 맞춤
  Future<int> addMemo({
    required String text,
    required int color, // 컬럼이 없으면 UI용 파라미터일 뿐 DB에는 저장 안 함
    required DateTime startTime, // 시간 넘겨받아도 DB에는 'date'만 저장
    DateTime? endTime, // 미사용(스키마에 없으면 넣지 않음)
    bool isTodo = false, // 미사용(공유/표시는 is_done만 봄)
    bool isDone = false,
    DateTime? dueTime, // 미사용
  }) async {
    final onlyDate = DateTime(startTime.year, startTime.month, startTime.day);

    final payload = <String, dynamic>{
      'user_id': _uid,
      'date': onlyDate.toIso8601String(),
      'title': text,
      'is_done': isDone,
      // 필요한 경우, 컬럼이 있을 때만 수동으로 추가해서 쓰세요:
      // 'color': color,
      // 'start_time': startTime.toIso8601String(),
      // 'end_time': endTime?.toIso8601String(),
      // 'due_time': dueTime?.toIso8601String(),
      // 'is_todo': isTodo,
    };

    final row = await _sb.from('memos').insert(payload).select('id').single();
    return (row['id'] as num).toInt();
  }

  /// 메모 내용 수정 (id는 문자열/정수 어느 쪽이 와도 동작)
  Future<void> updateMemo({
    required dynamic id,
    String? text,
    int? color,
    DateTime? startTime,
    DateTime? endTime,
    bool? isTodo,
    bool? isDone,
    DateTime? dueTime,
  }) async {
    final payload = <String, dynamic>{};
    if (text != null) payload['title'] = text;
    if (isDone != null) payload['is_done'] = isDone;

    // 스키마에 컬럼이 있을 때만 쓰고 싶다면 필요시 열어서 사용
    // if (color != null) payload['color'] = color;
    // if (startTime != null) payload['start_time'] = startTime.toIso8601String();
    // if (endTime != null) payload['end_time'] = endTime.toIso8601String();
    // if (isTodo != null) payload['is_todo'] = isTodo;
    // if (dueTime != null) payload['due_time'] = dueTime.toIso8601String();

    final q = _sb.from('memos').update(payload).eq('user_id', _uid);
    (id is num) ? await q.eq('id', id) : await q.eq('id', int.parse('$id'));
  }

  Future<void> deleteMemo(dynamic id) async {
    final q = _sb.from('memos').delete().eq('user_id', _uid);
    (id is num) ? await q.eq('id', id) : await q.eq('id', int.parse('$id'));
    // 소프트 삭제를 쓰고 싶으면 위 두 줄 대신:
    // await _sb.from('memos').update({'deleted_at': DateTime.now().toIso8601String()})
    //   .eq('user_id', _uid).eq('id', id);
  }

  /// 특정 날짜의 메모 1건(있다면)
  Future<Map<String, dynamic>?> getMemoForDate(DateTime day) async {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));

    final rows = await _sb
        .from('memos')
        .select()
        .eq('user_id', _uid)
        .gte('date', start.toIso8601String())
        .lt('date', end.toIso8601String())
        .isFilter('deleted_at', null) // 컬럼 없으면 자동 무시됨
        .order('date', ascending: true)
        .limit(1);

    if (rows.isEmpty) return null;
    return rows.first as Map<String, dynamic>;
  }

  /// 범위 조회 (캘린더용)
  Future<List<Map<String, dynamic>>> getMemosInRange({
    required DateTime firstDay,
    required DateTime lastDay,
  }) async {
    final rows = await _sb
        .from('memos')
        .select()
        .eq('user_id', _uid)
        .gte(
            'date',
            DateTime(firstDay.year, firstDay.month, firstDay.day)
                .toIso8601String())
        .lt(
            'date',
            DateTime(lastDay.year, lastDay.month, lastDay.day)
                .add(const Duration(days: 1))
                .toIso8601String())
        .isFilter('deleted_at', null) // 소프트 삭제 컬럼 있을 때만 적용
        .order('date', ascending: true);

    return rows.cast<Map<String, dynamic>>();
  }
}

// lib/features/home/pages/post_compose_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PostComposePage extends StatefulWidget {
  const PostComposePage({super.key});

  @override
  State<PostComposePage> createState() => _PostComposePageState();
}

class _PostComposePageState extends State<PostComposePage> {
  final _sp = Supabase.instance.client;
  final _contentCtrl = TextEditingController();
  bool _saving = false;

  /// 체크박스 상태
  bool _tagMyRegion = true; // 기본 켬
  bool _tagMyShift = false; // 사용자가 의도적으로 켜도록

  /// 표시/저장 값
  String _myRegion = '프로필에 지역 없음';
  String _myShift = ''; // day/evening/night/off 또는 ''

  @override
  void initState() {
    super.initState();
    _loadMyMeta(); // 프로필 지역 + 오늘 근무(확정) 로드
  }

  @override
  void dispose() {
    _contentCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HH:mm[:ss] → (hour, minute). 파싱 실패 시 null
  ({int hour, int minute})? _parseHHmmss(String? s) {
    if (s == null || s.trim().isEmpty) return null;
    final parts = s.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return (hour: h, minute: m);
  }

  DateTime _combineDateAndTime(DateTime date, String? hhmmss) {
    final t = _parseHHmmss(hhmmss);
    return DateTime(
        date.year, date.month, date.day, t?.hour ?? 0, t?.minute ?? 0);
  }

  /// 문자열을 표준 근무코드로 매핑(+ alias 테이블 우선)
  /// - 단문 약어 D/E/N/O, 한글 약어 주/오/야/휴, 영문 키워드까지 모두 커버
  Future<String> _toStandardShiftCode({
    required String? abbreviation,
    required String? title,
  }) async {
    final src = (abbreviation ?? '').trim();
    final fall = (title ?? '').trim();

    // 0) 초간단 약어/한글 약어 즉시 매핑 (쿼리/네트워크 타기 전에 처리)
    String t0 = (src.isNotEmpty ? src : fall).toLowerCase();
    switch (t0) {
      case 'd':
      case '주':
        return 'day';
      case 'e':
      case '오':
        return 'evening';
      case 'n':
      case '야':
        return 'night';
      case 'o':
      case '휴':
        return 'off';
    }

    // 1) 사용자 alias 우선
    try {
      final uid = _sp.auth.currentUser?.id;
      if (uid != null) {
        final rows = await _sp
            .from('shift_aliases')
            .select('alias, standard_code')
            .eq('user_id', uid);

        final map = <String, String>{};
        for (final r in (rows as List)) {
          final a = (r['alias'] ?? '').toString().trim().toLowerCase();
          final sc = (r['standard_code'] ?? '').toString().trim().toLowerCase();
          if (a.isNotEmpty && sc.isNotEmpty) map[a] = sc;
        }

        final try1 = src.toLowerCase();
        final try2 = fall.toLowerCase();
        if (try1.isNotEmpty && map.containsKey(try1)) return map[try1]!;
        if (try2.isNotEmpty && map.containsKey(try2)) return map[try2]!;
      }
    } catch (_) {
      // alias 조회 실패는 무시
    }

    // 2) 기본 규칙(단어 포함 여부)
    String t = (src.isNotEmpty ? src : fall).toLowerCase();
    bool hasAny(Iterable<String> v) => v.any((n) => t.contains(n));

    if (hasAny(['day', '주간'])) return 'day';
    if (hasAny(['evening', 'eve', '오전', '이브닝'])) return 'evening';
    if (hasAny(['night', '야간'])) return 'night';
    if (hasAny(['off', '휴무', '휴가'])) return 'off';
    return '';
  }

  /// 프로필 지역 + 오늘 '확정' 근무 로드
  /// - 오늘 시작하거나 오늘 종료하는 스케줄 모두 포함(야간/오버나이트 대비)
  /// - 그 중 **가장 늦게 시작하는** 하나를 선택
  Future<void> _loadMyMeta() async {
    final uid = _sp.auth.currentUser?.id;
    if (uid == null) return;

    String region = '프로필에 지역 없음';
    String shift = '';

    // 1) 프로필 지역
    try {
      final row = await _sp
          .from('profiles')
          .select('activity_area')
          .eq('id', uid)
          .maybeSingle();

      final act = (row?['activity_area'] as String?)?.trim() ?? '';
      if (act.isNotEmpty) region = act;
    } catch (_) {}

    // 2) 오늘 근무 (오늘 00:00 ~ 내일 00:00)
    try {
      final now = DateTime.now();
      final today0 = DateTime(now.year, now.month, now.day);
      final tomorrow0 = today0.add(const Duration(days: 1));
      final todayIso = today0.toIso8601String();
      final tomorrowIso = tomorrow0.toIso8601String();

      // (start_date in today) OR (end_date in today)
      final rows = await _sp
          .from('work_schedules')
          .select('title, abbreviation, start_date, start_time, end_date')
          .eq('user_id', uid)
          .isFilter('deleted_at', null)
          .or(
            'and(start_date.gte.$todayIso,start_date.lt.$tomorrowIso),'
            'and(end_date.gte.$todayIso,end_date.lt.$tomorrowIso)',
          );

      final list = (rows as List).cast<Map<String, dynamic>>();

      // start_date + start_time 합성으로 정렬 → 가장 늦게 시작하는 근무 선택
      list.sort((a, b) {
        final da =
            DateTime.tryParse((a['start_date'] ?? '').toString()) ?? today0;
        final db =
            DateTime.tryParse((b['start_date'] ?? '').toString()) ?? today0;
        final dtA = _combineDateAndTime(da, (a['start_time'] as String?));
        final dtB = _combineDateAndTime(db, (b['start_time'] as String?));
        return dtA.compareTo(dtB);
      });

      if (list.isNotEmpty) {
        final last = list.last;
        shift = await _toStandardShiftCode(
          abbreviation: last['abbreviation'] as String?,
          title: last['title'] as String?,
        );
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _myRegion = region;
      _myShift = shift; // ''이면 UI에 “근무 정보 없음” 노출
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    final uid = _sp.auth.currentUser?.id;
    final content = _contentCtrl.text.trim();

    if (uid == null) {
      _snack('로그인이 필요합니다.');
      return;
    }
    if (content.isEmpty) {
      _snack('내용을 입력하세요.');
      return;
    }

    setState(() => _saving = true);
    try {
      final payload = <String, dynamic>{
        'user_id': uid,
        'content': content,
      };

      if (_tagMyRegion && _myRegion.isNotEmpty && _myRegion != '프로필에 지역 없음') {
        payload['location_text'] = _myRegion;
      }
      if (_tagMyShift && _myShift.isNotEmpty) {
        payload['shift_code'] = _myShift; // day/evening/night/off
      }

      await _sp.from('community_posts').insert(payload).select().single();

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      _snack('등록 실패: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final canSubmit = !_saving;

    String shiftLabel() {
      if (_myShift.isEmpty) return '내 근무 태그하기  •  (근무 정보 없음)';
      const map = {
        'day': 'day',
        'evening': 'evening',
        'night': 'night',
        'off': 'off',
      };
      return '내 근무 태그하기  •  ${map[_myShift] ?? _myShift}';
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('글쓰기'),
        actions: [
          TextButton(
            onPressed: canSubmit ? _submit : null,
            child: const Text('등록'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _contentCtrl,
            minLines: 5,
            maxLines: 12,
            decoration: const InputDecoration(
              hintText: '내용을 입력하세요 (첫 줄이 목록 제목으로 표시됩니다)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),

          // 내 지역 태그
          CheckboxListTile(
            value: _tagMyRegion,
            onChanged: (v) => setState(() => _tagMyRegion = v ?? true),
            controlAffinity: ListTileControlAffinity.leading,
            dense: true,
            title: Text(
              '내 지역 태그하기  •  ${_myRegion.isEmpty ? '프로필에 지역 없음' : _myRegion}',
            ),
          ),

          // 내 근무 태그 — 오늘 확정 근무 기반
          CheckboxListTile(
            value: _tagMyShift,
            onChanged: (v) => setState(() => _tagMyShift = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            dense: true,
            title: Text(shiftLabel()),
          ),

          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: canSubmit ? _submit : null,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
            label: const Text('등록'),
          ),
        ],
      ),
    );
  }
}

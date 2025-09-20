// lib/features/home/pages/share_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:god_life_v1/core/models/calendar_event.dart';
import 'package:god_life_v1/features/work_schedule/widgets/custom_calendar.dart';
import 'package:god_life_v1/features/home/pages/friend_management_page.dart';

// 전역 설정 (개인정보 공개 범위)
import 'package:god_life_v1/providers/app_settings_provider.dart';

// ✅ 친구목록 Provider는 외부 파일 것을 씁니다 (중복 정의 금지)
import 'package:god_life_v1/features/home/providers/friends_provider.dart'
    as fp;

/// ------------------------------------------------------------
/// 친구→나로 공유된 권한(보기 권한) 조회
/// ------------------------------------------------------------
class FriendViewPermission {
  final bool canSeeCalendar;
  final bool canSeeMemos;
  final String reason;

  const FriendViewPermission({
    required this.canSeeCalendar,
    required this.canSeeMemos,
    this.reason = '',
  });
}

final friendViewPermissionProvider =
    FutureProvider.family<FriendViewPermission, String>((ref, friendId) async {
  final sp = Supabase.instance.client;
  final me = sp.auth.currentUser?.id;

  // 전역 설정(상한) 감시
  final settings = ref.watch(appSettingsProvider);

  bool visibleByPolicy(String policy) {
    switch (policy) {
      case 'private':
        return false;
      case 'friends':
      case 'public':
      default:
        return true;
    }
  }

  final globalWork = visibleByPolicy(settings.shareWorkVisibility);
  final globalMemo = visibleByPolicy(settings.shareMemoVisibility);

  // 내가 나를 보는 경우: 전역설정 적용
  if (me != null && friendId == me) {
    return FriendViewPermission(
      canSeeCalendar: globalWork,
      canSeeMemos: globalMemo,
      reason: (!globalWork || !globalMemo)
          ? '상대방이 비공개 계정입니다. 일부 항목이 표시되지 않을 수 있습니다.'
          : '',
    );
  }

  if (me == null) {
    return const FriendViewPermission(
      canSeeCalendar: false,
      canSeeMemos: false,
      reason: '로그인이 필요합니다.',
    );
  }

  // 친구가 "나"에게 공개한 권한 (상태 accepted)
  final permRows = await sp
      .from('share_permissions')
      .select('share_calendar, share_memos, status')
      .eq('user_id', friendId)
      .eq('friend_id', me)
      .eq('status', 'accepted')
      .limit(1);

  if (permRows.isEmpty) {
    return const FriendViewPermission(
      canSeeCalendar: false,
      canSeeMemos: false,
      reason: '상대방이 비공개 계정입니다. 일부 항목이 표시되지 않을 수 있습니다.',
    );
  }

  final row = permRows.first;
  final shareCal = (row['share_calendar'] as bool?) ?? false;
  final shareMemo = (row['share_memos'] as bool?) ?? false;

  return FriendViewPermission(
    canSeeCalendar: shareCal && globalWork, // 전역 상한과 AND
    canSeeMemos: shareMemo && globalMemo,
    reason: (!shareCal || !shareMemo || !globalWork || !globalMemo)
        ? '상대방이 비공개 계정입니다. 일부 항목이 표시되지 않을 수 있습니다.'
        : '',
  );
});

/// ------------------------------------------------------------
/// 친구 근무일정/메모 실시간 구독
/// ------------------------------------------------------------
final friendSchedulesProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>((ref, friendId) {
  final sp = Supabase.instance.client;
  return sp
      .from('work_schedules')
      .stream(primaryKey: ['id'])
      .eq('user_id', friendId)
      .order('start_date', ascending: true)
      .map((rows) => rows.where((r) => r['deleted_at'] == null).toList());
});

final friendMemosProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>((ref, friendId) {
  final sp = Supabase.instance.client;
  return sp
      .from('memos')
      .stream(primaryKey: ['id'])
      .eq('user_id', friendId)
      .order('date', ascending: true)
      .map((rows) => rows.where((r) => r['deleted_at'] == null).toList());
});

/// ============================================================
/// Share Page
/// ============================================================
class SharePage extends ConsumerStatefulWidget {
  const SharePage({super.key});
  @override
  ConsumerState<SharePage> createState() => _SharePageState();
}

class _SharePageState extends ConsumerState<SharePage> {
  String? _selectedFriendId;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  // 실시간 권한 변경 감지
  final _sp = Supabase.instance.client;
  RealtimeChannel? _permCh;

  @override
  void initState() {
    super.initState();
    _bindPermRealtime();
  }

  @override
  void dispose() {
    try {
      _permCh?.unsubscribe();
      if (_permCh != null) _sp.removeChannel(_permCh!);
    } catch (_) {}
    super.dispose();
  }

  /// 모든 관련 provider 새로고침
  void _refreshAll() {
    ref.invalidate(fp.friendsProvider);
    final id = _selectedFriendId;
    if (id != null && id.isNotEmpty) {
      ref.invalidate(friendViewPermissionProvider(id));
      ref.invalidate(friendSchedulesProvider(id));
      ref.invalidate(friendMemosProvider(id));
    }
    setState(() {}); // 즉시 리빌드
  }

  /// share_permissions (내가 sender/receiver인 모든 변화) 실시간 구독
  void _bindPermRealtime() {
    final me = _sp.auth.currentUser?.id;
    if (me == null) return;

    // 기존 채널 정리
    try {
      _permCh?.unsubscribe();
      if (_permCh != null) _sp.removeChannel(_permCh!);
    } catch (_) {}

    _permCh = _sp.channel('share-perm-watch-$me')
      // user_id == me (내가 보낸 공유 변경)
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'share_permissions',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'user_id',
          value: me,
        ),
        callback: (_) => _refreshAll(),
      )
      // friend_id == me (내가 받은 공유 변경)
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'share_permissions',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'friend_id',
          value: me,
        ),
        callback: (_) => _refreshAll(),
      ).subscribe();
  }

  Future<void> _pickMonth(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _focusedDay,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('ko', 'KR'),
    );
    if (picked != null) {
      setState(() {
        _focusedDay = DateTime(picked.year, picked.month, 15);
        _selectedDay = DateTime(picked.year, picked.month, picked.day);
      });
    }
  }

  void _goToday() {
    final now = DateTime.now();
    setState(() {
      _focusedDay = DateTime(now.year, now.month, 15);
      _selectedDay = DateTime(now.year, now.month, now.day);
    });
  }

  @override
  Widget build(BuildContext context) {
    final friendsAsync = ref.watch(fp.friendsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('일정 공유'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: '새로고침',
            onPressed: _refreshAll,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            icon: const Icon(Icons.manage_accounts_outlined),
            tooltip: '친구 관리',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FriendManagementPage()),
              ).then((_) => _refreshAll());
            },
          ),
        ],
      ),
      body: friendsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text('친구 목록 로딩 실패: $err')),
        data: (friends) {
          if (friends.isEmpty) {
            return const Center(
              child: Text(
                '친구가 없습니다.\n친구 관리 페이지에서 친구를 추가해보세요.',
                textAlign: TextAlign.center,
              ),
            );
          }

          // 현재 선택값이 목록에 없으면 첫 번째로 보정
          if (_selectedFriendId == null ||
              !friends.any((f) => f['partner_id'] == _selectedFriendId)) {
            _selectedFriendId = friends.first['partner_id'] as String;
          }

          final selectedFriend = friends.firstWhere(
            (f) => f['partner_id'] == _selectedFriendId,
            orElse: () => friends.first,
          );

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: _buildFriendSelector(friends, selectedFriend),
              ),
              // 월 선택 헤더 + 오늘 이동 버튼
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _pickMonth(context),
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 6, horizontal: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                DateFormat('yyyy.MM', 'ko_KR')
                                    .format(_focusedDay),
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.expand_more, size: 18),
                            ],
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '오늘로 이동',
                      onPressed: _goToday,
                      icon: const Icon(Icons.today_outlined),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: _selectedFriendId == null
                    ? const Center(child: Text('선택된 친구가 없습니다.'))
                    : _FriendCalendarView(
                        friendId: _selectedFriendId!,
                        focusedDay: _focusedDay,
                        selectedDay: _selectedDay,
                        onPageChanged: (day) =>
                            setState(() => _focusedDay = day),
                        onDaySelected: (selected, focused) => setState(() {
                          _selectedDay =
                              DateUtils.isSameDay(_selectedDay, selected)
                                  ? null
                                  : selected;
                          _focusedDay = focused;
                        }),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFriendSelector(
    List<Map<String, dynamic>> friends,
    Map<String, dynamic> selectedFriend,
  ) {
    // items 안전 집합
    final allowedIds = friends
        .map((f) => (f['partner_id'] ?? '').toString())
        .where((s) => s.isNotEmpty)
        .toSet();

    // value는 items 안에 있을 때만 설정
    final currentValue =
        allowedIds.contains(_selectedFriendId) ? _selectedFriendId : null;

    return DropdownButtonFormField<String>(
      value: currentValue,
      isExpanded: true,
      decoration: InputDecoration(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      ),
      hint: const Text('친구를 선택하세요'),
      onChanged: (friendId) {
        if (friendId == null) return;
        setState(() {
          _selectedFriendId = friendId;
          _focusedDay = DateTime.now();
          _selectedDay = null;
        });
      },
      items: friends.map((friend) {
        final id = (friend['partner_id'] ?? '').toString();
        final name = (friend['partner_display_name'] ??
                friend['partner_username'] ??
                '이름 없음')
            .toString();
        return DropdownMenuItem<String>(
          value: id,
          child: Text(
            name,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        );
      }).toList(),
    );
  }
}

/// ============================================================
/// 내부 위젯들
/// ============================================================
class _FriendCalendarView extends ConsumerWidget {
  const _FriendCalendarView({
    required this.friendId,
    required this.focusedDay,
    this.selectedDay,
    required this.onDaySelected,
    required this.onPageChanged,
  });

  final String friendId;
  final DateTime focusedDay;
  final DateTime? selectedDay;
  final void Function(DateTime, DateTime) onDaySelected;
  final void Function(DateTime) onPageChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedulesAsync = ref.watch(friendSchedulesProvider(friendId));
    final memosAsync = ref.watch(friendMemosProvider(friendId));
    final permAsync = ref.watch(friendViewPermissionProvider(friendId));

    if (schedulesAsync.isLoading ||
        memosAsync.isLoading ||
        permAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (schedulesAsync.hasError || memosAsync.hasError || permAsync.hasError) {
      return const Center(child: Text('데이터 로딩 중 에러 발생'));
    }

    final schedulesRaw = schedulesAsync.value ?? const <Map<String, dynamic>>[];
    final memosRaw = memosAsync.value ?? const <Map<String, dynamic>>[];
    final perm = permAsync.value!;

    // 정책에 따라 데이터 차단
    final schedules =
        perm.canSeeCalendar ? schedulesRaw : const <Map<String, dynamic>>[];
    final memos = perm.canSeeMemos ? memosRaw : const <Map<String, dynamic>>[];

    final eventsMap = _buildEventsMap(schedules, memos);

    final policyNote =
        (!perm.canSeeCalendar || !perm.canSeeMemos) ? perm.reason : null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      children: [
        if (policyNote != null) ...[
          Card(
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withOpacity(.5),
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                policyNote,
                style: TextStyle(
                  fontSize: 12,
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(.8),
                ),
              ),
            ),
          ),
        ],
        CustomCalendar(
          focusedDay: focusedDay,
          selectedDay: selectedDay,
          eventLoader: (day) => _getEventsForDay(day, eventsMap),
          onDaySelected: onDaySelected,
          onPageChanged: onPageChanged,
        ),
        const SizedBox(height: 8),
        if (selectedDay != null)
          _FriendSelectedDayDetails(
            selectedDay: selectedDay!,
            eventsMap: eventsMap,
            canSeeCalendar: perm.canSeeCalendar,
            canSeeMemos: perm.canSeeMemos,
          ),
      ],
    );
  }

  // 안전한 날짜 파싱 + UTC 키 정규화
  DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is String && v.isNotEmpty) {
      try {
        return DateTime.parse(v);
      } catch (_) {
        try {
          final parts = v.split(RegExp(r'[\sT]')).first.split('-');
          if (parts.length == 3) {
            final y = int.parse(parts[0]);
            final m = int.parse(parts[1]);
            final d = int.parse(parts[2]);
            return DateTime(y, m, d);
          }
        } catch (_) {}
      }
    }
    return null;
  }

  Map<DateTime, List<CalendarEvent>> _buildEventsMap(
    List<Map<String, dynamic>> schedules,
    List<Map<String, dynamic>> memos,
  ) {
    final map = <DateTime, List<CalendarEvent>>{};

    for (final raw in schedules) {
      final dt = _parseDate(raw['start_date']);
      if (dt == null) continue;
      final key = DateTime.utc(dt.year, dt.month, dt.day);
      final list = map[key] ?? <CalendarEvent>[];
      list.add(CalendarEvent.fromWorkSchedule(raw));
      map[key] = list;
    }

    for (final raw in memos) {
      final dt = _parseDate(raw['date']);
      if (dt == null) continue;
      final key = DateTime.utc(dt.year, dt.month, dt.day);
      final list = map[key] ?? <CalendarEvent>[];
      list.add(CalendarEvent.fromMemo(raw));
      map[key] = list;
    }

    return map;
  }

  List<CalendarEvent> _getEventsForDay(
    DateTime day,
    Map<DateTime, List<CalendarEvent>> map,
  ) {
    final key = DateTime.utc(day.year, day.month, day.day);
    final events = map[key] ?? const <CalendarEvent>[];

    final works = events.where((e) => !e.isTodo).toList(growable: true);
    final hasMemo = events.any((e) => e.isTodo);
    if (hasMemo) {
      works.add(CalendarEvent(title: 'memo_marker', isTodo: true));
    }
    return works;
  }
}

class _FriendSelectedDayDetails extends StatelessWidget {
  const _FriendSelectedDayDetails({
    required this.selectedDay,
    required this.eventsMap,
    required this.canSeeCalendar,
    required this.canSeeMemos,
  });

  final DateTime selectedDay;
  final Map<DateTime, List<CalendarEvent>> eventsMap;
  final bool canSeeCalendar;
  final bool canSeeMemos;

  String _fmt(dynamic t) => t == null ? '' : t.toString();

  @override
  Widget build(BuildContext context) {
    final key =
        DateTime.utc(selectedDay.year, selectedDay.month, selectedDay.day);
    final all = eventsMap[key] ?? const <CalendarEvent>[];
    final works = all.where((e) => !e.isTodo).toList();
    final todos = all.where((e) => e.isTodo).toList();

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat('yyyy.MM.dd (E)', 'ko_KR').format(selectedDay),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 6),

            // 근무 일정
            Text('근무 일정', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            if (!canSeeCalendar)
              const Text('상대방의 설정으로 근무 일정이 표시되지 않습니다.',
                  style: TextStyle(color: Colors.grey))
            else if (works.isEmpty)
              const Text('표시할 근무 일정이 없습니다.',
                  style: TextStyle(color: Colors.grey))
            else
              ...works.map((e) {
                final m = (e.originalData ?? const {}) as Map;
                final time = [_fmt(m['start_time']), _fmt(m['end_time'])]
                    .where((s) => s.isNotEmpty)
                    .join('~');
                final dotColor = e.color;
                final memo = (e.memo ?? _fmt(m['memo'])).toString();
                final hasTimeOrMemo =
                    time.isNotEmpty || (memo.isNotEmpty && memo != 'null');
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: dotColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(e.short ?? e.title,
                                style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w600)),
                            if (hasTimeOrMemo)
                              Text(
                                [
                                  if (time.isNotEmpty) time,
                                  if (memo.isNotEmpty && memo != 'null') memo,
                                ].join(' / '),
                                style: const TextStyle(fontSize: 12),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),

            const Divider(),

            // To Do List
            Text('To Do List', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            if (!canSeeMemos)
              const Text('상대방의 설정으로 할 일이 표시되지 않습니다.',
                  style: TextStyle(color: Colors.grey))
            else if (todos.isEmpty)
              const Text('표시할 할 일이 없습니다.', style: TextStyle(color: Colors.grey))
            else
              ...todos.map(
                (t) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.check_box_outline_blank, size: 20),
                  title: Text(t.title),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

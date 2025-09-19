// lib/features/work_schedule/page/work_schedule_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_new_test_app/core/models/calendar_event.dart';
import 'package:my_new_test_app/features/onboarding/pages/onboarding_page.dart';
import 'package:my_new_test_app/features/onboarding/tutorial_service.dart';
import 'package:my_new_test_app/features/work_schedule/utils/shift_alias_resolver.dart';
import 'package:my_new_test_app/features/work_schedule/widgets/add_single_schedule_dialog.dart';
import 'package:my_new_test_app/features/work_schedule/widgets/custom_calendar.dart';
import 'package:my_new_test_app/features/work_schedule/widgets/schedule_form_dialog.dart';
import 'package:my_new_test_app/providers/schedule_provider.dart';
import 'package:my_new_test_app/providers/tutorial_provider.dart';
import 'package:my_new_test_app/work_stats_page.dart';
import 'package:intl/intl.dart';

// ✅ 추가: 알림 테스트 호출
import 'package:my_new_test_app/services/notification_service.dart';

const Color _kDefaultEventColor = Color(0xFF6C4CE8);

class WorkSchedulePage extends ConsumerStatefulWidget {
  const WorkSchedulePage({super.key});
  @override
  ConsumerState<WorkSchedulePage> createState() => _WorkSchedulePageState();
}

class _WorkSchedulePageState extends ConsumerState<WorkSchedulePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // 필요시 튜토리얼 시작
      // GuidedTourController(context).startCalendarPageTour();
    });
  }

  // ───────────────── 공통 하드 새로고침 ─────────────────
  Future<void> _hardRefresh(WidgetRef ref) async {
    // 일정/메모 모두 강제 갱신
    await ref.read(scheduleProvider.notifier).refresh();
    ref.invalidate(memoProvider);
  }

  List<CalendarEvent> _getEventsForDay(
    DateTime day,
    Map<DateTime, List<CalendarEvent>> workEvents,
    List<CalendarEvent> allTodos,
  ) {
    final key = DateTime(day.year, day.month, day.day);
    final works = (workEvents[key] ?? []).where((event) {
      final titleCode = ShiftAliasResolver.resolve(event.title);
      final shortCode = ShiftAliasResolver.resolve(event.short ?? '');
      return titleCode != 'O' && shortCode != 'O';
    }).toList();
    final todos = allTodos.where((t) => DateUtils.isSameDay(t.date, day));
    return [
      ...works,
      if (todos.isNotEmpty) CalendarEvent(title: 'memo_marker', isTodo: true),
    ];
  }

  Future<void> _openAddScheduleDialog(
      BuildContext context, WidgetRef ref) async {
    final focusedDay = ref.read(focusedDayProvider);
    final selectedDay = ref.read(selectedDayProvider);
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) =>
          ScheduleFormDialog(initialDate: selectedDay ?? focusedDay),
    );
    if (saved == true) {
      await _hardRefresh(ref);
    }
  }

  Future<void> _openAddSingleScheduleDialog(
      BuildContext context, WidgetRef ref, DateTime date) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => AddSingleScheduleDialog(selectedDate: date),
    );
    if (saved == true) {
      await _hardRefresh(ref);
    }
  }

  Future<void> _deleteAllConfirm(BuildContext context, WidgetRef ref) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('전체 삭제'),
        content: const Text('정말로 모든 근무 일정을 삭제할까요?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('삭제')),
        ],
      ),
    );
    if (yes == true) {
      await ref.read(workScheduleServiceProvider).deleteAllSchedules();
      await _hardRefresh(ref);
    }
  }

  Future<void> _deleteOne(
      BuildContext context, WidgetRef ref, CalendarEvent e) async {
    final id = (e.originalData as Map?)?['id']?.toString();
    if (id == null) return;
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('삭제'),
        content: const Text('이 일정을 삭제할까요?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('삭제')),
        ],
      ),
    );
    if (yes == true) {
      await ref.read(workScheduleServiceProvider).deleteScheduleById(id);
      await _hardRefresh(ref);
    }
  }

  Future<void> _editOne(
      BuildContext context, WidgetRef ref, CalendarEvent e) async {
    final selectedDay = ref.read(selectedDayProvider);
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => AddSingleScheduleDialog(
        selectedDate: selectedDay ?? DateTime.now(),
        eventToEdit: e,
      ),
    );
    if (saved == true) {
      await _hardRefresh(ref);
    }
  }

  Future<void> _openAddTodoDialog(BuildContext context, WidgetRef ref) async {
    final selectedDay = ref.read(selectedDayProvider);
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) {
        final textController = TextEditingController();
        return AlertDialog(
          title: const Text('할 일 추가'),
          content: TextField(
            controller: textController,
            autofocus: true,
            decoration: const InputDecoration(hintText: '할 일을 입력하세요'),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('취소')),
            ElevatedButton(
              onPressed: () {
                if (textController.text.trim().isNotEmpty) {
                  Navigator.pop(context, {
                    'text': textController.text.trim(),
                    'date': selectedDay ?? DateTime.now(),
                  });
                }
              },
              child: const Text('저장'),
            ),
          ],
        );
      },
    );
    if (result != null) {
      await ref
          .read(workScheduleServiceProvider)
          .insertMemo(result['text'], result['date']);
      ref.invalidate(memoProvider);
    }
  }

  Future<void> _editMemo(
      BuildContext context, WidgetRef ref, CalendarEvent event) async {
    final originalData = event.originalData as Map<String, dynamic>;
    final memoId = originalData['id']?.toString();
    if (memoId == null) return;
    final controller = TextEditingController(text: event.title);
    final newText = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('할 일 수정'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('취소')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('저장')),
        ],
      ),
    );
    if (newText != null && newText.trim().isNotEmpty) {
      await ref
          .read(workScheduleServiceProvider)
          .updateMemo(memoId, newText.trim());
      ref.invalidate(memoProvider);
    }
  }

  Future<void> _deleteMemo(
      BuildContext context, WidgetRef ref, CalendarEvent event) async {
    final originalData = event.originalData as Map<String, dynamic>;
    final memoId = originalData['id']?.toString();
    if (memoId == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('할 일 삭제'),
        content: const Text('이 항목을 삭제할까요?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('삭제')),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(workScheduleServiceProvider).deleteMemo(memoId);
      ref.invalidate(memoProvider);
    }
  }

  // ✅ 추가: 알림 테스트(10초 후)
  Future<void> _testNotification(BuildContext context) async {
    await NotificationService.I.scheduleTestIn10s(alarmStyle: true);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔔 10초 후 알림이 예약되었습니다.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheduleState = ref.watch(scheduleProvider);
    final memoState = ref.watch(memoProvider);
    final focusedDay = ref.watch(focusedDayProvider);
    final selectedDay = ref.watch(selectedDayProvider);

    // 튜토리얼 트리거
    ref.listen<bool>(calendarTutorialRequestProvider, (previous, next) {
      if (next == true) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            GuidedTourController(context).startCalendarPageTour();
          }
        });
        ref.read(calendarTutorialRequestProvider.notifier).state = false;
      }
    });

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        leading: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'change_pattern') {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const OnboardingPage()),
                (route) => false,
              );
            } else if (value == 'view_statistics') {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const WorkStatsPage()),
              );
            }
          },
          itemBuilder: (BuildContext context) => const <PopupMenuEntry<String>>[
            PopupMenuItem<String>(
                value: 'view_statistics', child: Text('근무 통계 보기')),
            PopupMenuDivider(),
            PopupMenuItem<String>(
                value: 'change_pattern', child: Text('직업군/패턴 변경')),
          ],
          icon: const Icon(Icons.tune),
        ),
        title: const Text('My Calendar'),
        actions: [
          IconButton(
            onPressed: () => _openAddScheduleDialog(context, ref),
            icon: const Icon(Icons.add_circle_outline),
            tooltip: '패턴으로 일정 추가',
          ),
          IconButton(
            tooltip: '새로고침',
            onPressed: () => _hardRefresh(ref),
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: '전체 삭제',
            onPressed: () => _deleteAllConfirm(context, ref),
            icon: const Icon(Icons.delete_forever_outlined),
          ),
          // ✅ 추가: 10초 후 알림 테스트
          IconButton(
            tooltip: '10초 후 알림 테스트',
            onPressed: () => _testNotification(context),
            icon: const Icon(Icons.alarm_add),
          ),
        ],
      ),
      body: scheduleState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('데이터 로딩 실패: $error')),
        data: (workEvents) {
          final allTodos = memoState.asData?.value ?? [];
          return RefreshIndicator(
            onRefresh: () => _hardRefresh(ref),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
              children: [
                _MonthSwitcherBar(
                  focused: focusedDay,
                  onPrev: () {
                    ref.read(focusedDayProvider.notifier).state =
                        DateTime(focusedDay.year, focusedDay.month - 1, 1);
                    ref.read(selectedDayProvider.notifier).state = null;
                  },
                  onNext: () {
                    ref.read(focusedDayProvider.notifier).state =
                        DateTime(focusedDay.year, focusedDay.month + 1, 1);
                    ref.read(selectedDayProvider.notifier).state = null;
                  },
                  onPick: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: focusedDay,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      ref.read(focusedDayProvider.notifier).state =
                          DateTime(picked.year, picked.month, 15);
                      ref.read(selectedDayProvider.notifier).state = null;
                      await _hardRefresh(ref);
                    }
                  },
                  onToday: () {
                    final now = DateTime.now();
                    ref.read(focusedDayProvider.notifier).state =
                        DateTime(now.year, now.month, 1);
                    ref.read(selectedDayProvider.notifier).state = now;
                  },
                ),
                CustomCalendar(
                  focusedDay: focusedDay,
                  selectedDay: selectedDay,
                  eventLoader: (day) =>
                      _getEventsForDay(day, workEvents, allTodos),
                  onDaySelected: (sDay, fDay) {
                    ref.read(selectedDayProvider.notifier).state = sDay;
                    ref.read(focusedDayProvider.notifier).state = fDay;
                  },
                  onPageChanged: (fDay) {
                    ref.read(focusedDayProvider.notifier).state = fDay;
                    ref.read(selectedDayProvider.notifier).state = null;
                  },
                ),
                const SizedBox(height: 8),
                if (selectedDay != null) ...[
                  _SelectedDayDetailCard(
                    date: selectedDay,
                    events: workEvents[DateTime(
                          selectedDay.year,
                          selectedDay.month,
                          selectedDay.day,
                        )] ??
                        [],
                    onDeleteOne: (e) => _deleteOne(context, ref, e),
                    onEditOne: (e) => _editOne(context, ref, e),
                    onAddOne: (date) =>
                        _openAddSingleScheduleDialog(context, ref, date),
                  ),
                  const SizedBox(height: 16),
                ],
                _TodoListCard(
                  todos: allTodos,
                  onEditMemo: (e) => _editMemo(context, ref, e),
                  onDeleteMemo: (e) => _deleteMemo(context, ref, e),
                  onAddTodo: () => _openAddTodoDialog(context, ref),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 하위 위젯
// ─────────────────────────────────────────────────────────────────────────────

class _MonthSwitcherBar extends StatelessWidget {
  const _MonthSwitcherBar({
    required this.focused,
    required this.onPrev,
    required this.onNext,
    required this.onPick,
    required this.onToday,
  });

  final DateTime focused;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final Future<void> Function() onPick;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    final label = DateFormat('yyyy.MM').format(focused);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            tooltip: '이전 달',
            onPressed: onPrev,
            icon: const Icon(Icons.chevron_left),
          ),
          GestureDetector(
            onTap: onPick,
            child: Text(
              label,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            tooltip: '다음 달',
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right),
          ),
          const SizedBox(width: 6),
          IconButton(
            tooltip: '오늘로 이동',
            onPressed: onToday,
            icon: const Icon(Icons.today_outlined),
          ),
        ],
      ),
    );
  }
}

class _SelectedDayDetailCard extends StatelessWidget {
  const _SelectedDayDetailCard({
    required this.date,
    required this.events,
    required this.onDeleteOne,
    required this.onEditOne,
    required this.onAddOne,
  });

  final DateTime date;
  final List<CalendarEvent> events;
  final void Function(CalendarEvent) onDeleteOne;
  final void Function(CalendarEvent) onEditOne;
  final void Function(DateTime) onAddOne;

  String _fmt(dynamic t) => t == null ? '' : t.toString();

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('yyyy.MM.dd (E)', 'ko_KR').format(date);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(dateLabel,
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 6),
            if (events.isEmpty)
              Row(
                children: [
                  const Icon(Icons.event_busy, size: 18),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('근무 일정이 없습니다.')),
                  TextButton(
                    onPressed: () => onAddOne(date),
                    child: const Text('추가'),
                  ),
                ],
              )
            else
              ...events.map((e) {
                final m = (e.originalData ?? const {}) as Map;
                final time = [_fmt(m['start_time']), _fmt(m['end_time'])]
                    .where((s) => s.isNotEmpty)
                    .join('~');
                final dotColor = e.color ?? _kDefaultEventColor;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                            color: dotColor, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(e.short ?? e.title,
                                style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w600)),
                            if (time.isNotEmpty || (e.memo ?? '').isNotEmpty)
                              Text(
                                [
                                  if (time.isNotEmpty) time,
                                  if ((e.memo ?? '').isNotEmpty) e.memo!,
                                ].join(' / '),
                                style: const TextStyle(fontSize: 12),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, size: 18),
                        tooltip: '수정',
                        onPressed: () => onEditOne(e),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18),
                        tooltip: '삭제',
                        onPressed: () => onDeleteOne(e),
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

class _TodoListCard extends StatelessWidget {
  const _TodoListCard({
    required this.todos,
    required this.onEditMemo,
    required this.onDeleteMemo,
    required this.onAddTodo,
  });

  final List<CalendarEvent> todos;
  final void Function(CalendarEvent) onEditMemo;
  final void Function(CalendarEvent) onDeleteMemo;
  final VoidCallback onAddTodo;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('To Do List',
                    style: Theme.of(context).textTheme.titleMedium),
                TextButton.icon(
                  onPressed: onAddTodo,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('추가'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (todos.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text('작성된 할 일이 없습니다.',
                    style: TextStyle(color: Colors.grey)),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: todos.length,
                itemBuilder: (context, index) {
                  final e = todos[index];
                  final dateLabel =
                      DateFormat('MM.dd (E)', 'ko_KR').format(e.date!);
                  final iconColor = e.color ?? _kDefaultEventColor;
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.check_box_outline_blank,
                        color: iconColor, size: 20),
                    title: Text(e.title),
                    subtitle: Text(dateLabel),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 18),
                          tooltip: '수정',
                          onPressed: () => onEditMemo(e),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18),
                          tooltip: '삭제',
                          onPressed: () => onDeleteMemo(e),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

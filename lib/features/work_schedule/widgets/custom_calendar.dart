// lib/features/work_schedule/widgets/custom_calendar.dart
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_new_test_app/core/models/calendar_event.dart';
import 'package:my_new_test_app/core/services/korean_holidays_service.dart';
import 'package:my_new_test_app/providers/app_settings_provider.dart';

class CustomCalendar extends ConsumerStatefulWidget {
  const CustomCalendar({
    super.key,
    required this.focusedDay,
    required this.eventLoader,
    required this.onDaySelected,
    required this.onPageChanged,
    this.selectedDay,
  });

  final DateTime focusedDay;
  final DateTime? selectedDay;
  final List<CalendarEvent> Function(DateTime day) eventLoader;
  final void Function(DateTime selected, DateTime focused) onDaySelected;
  final void Function(DateTime newFocused) onPageChanged;

  @override
  ConsumerState<CustomCalendar> createState() => _CustomCalendarState();
}

class _CustomCalendarState extends ConsumerState<CustomCalendar> {
  List<Holiday> _holidays = [];

  // ✅ 스와이프 감도 개선: 누적 가로 이동량 저장
  double _dragAccum = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchHolidays();
  }

  @override
  void didUpdateWidget(covariant CustomCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusedDay.year != widget.focusedDay.year) {
      _fetchHolidays();
    }
  }

  Future<void> _fetchHolidays() async {
    final holidays =
        await KoreanHolidaysService.getHolidays(year: widget.focusedDay.year);
    if (mounted) {
      setState(() {
        _holidays = holidays;
      });
    }
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Sunday=0, Monday=1, ... Saturday=6 로 정규화
  int _asSundayZero(DateTime d) => d.weekday % 7;

  /// 시작 요일을 기준으로 주의 offset 계산
  /// startOfMonthWeekday: 0(Sun)..6(Sat) 기준
  int _leadingBlankDays(int startOfMonthWeekday, int startWeekdayIndex) {
    // startWeekdayIndex: 0(Sun) 또는 1(Mon)
    final diff = (startOfMonthWeekday - startWeekdayIndex) % 7;
    return diff < 0 ? diff + 7 : diff;
  }

  /// 시작 요일에 맞춘 요일 라벨 회전
  List<String> _weekdayLabels(String weekStart) {
    const base = ['일', '월', '화', '수', '목', '금', '토']; // Sun..Sat
    if (weekStart == 'mon') {
      return [...base.skip(1), base.first]; // Mon..Sun
    }
    return base; // Sun..Sat
  }

  /// 시작 요일에 맞춰 컬러링할 index 반환 (0~6)
  bool _isSundayIndex(int index, String weekStart) =>
      (weekStart == 'mon' ? index == 6 : index == 0);
  bool _isSaturdayIndex(int index, String weekStart) =>
      (weekStart == 'mon' ? index == 5 : index == 6);

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final weekStart = settings.weekStart; // 'mon' | 'sun'
    final startWeekdayIndex = weekStart == 'mon' ? 1 : 0; // Mon:1, Sun:0

    final monthStart =
        DateTime(widget.focusedDay.year, widget.focusedDay.month, 1);
    final startOfMonthWday = _asSundayZero(monthStart); // 0..6 (Sun..Sat)
    final blanks = _leadingBlankDays(startOfMonthWday, startWeekdayIndex);
    final gridStart = monthStart.subtract(Duration(days: blanks));

    // 월의 마지막 날이 포함된 “그 주”의 마지막 날까지 채우기
    final lastDayOfMonth =
        DateTime(widget.focusedDay.year, widget.focusedDay.month + 1, 0);
    final lastWday = _asSundayZero(lastDayOfMonth);
    final trailing = (startWeekdayIndex + 6 - lastWday) % 7; // 끝에 필요한 칸 수 계산
    final endOfWeek = lastDayOfMonth.add(Duration(days: trailing));
    final totalDays = endOfWeek.difference(gridStart).inDays + 1; // inclusive
    final weeks = (totalDays / 7).ceil();

    final theme = Theme.of(context);
    final labels = _weekdayLabels(weekStart);

    return GestureDetector(
      behavior: HitTestBehavior.opaque, // ✅ 빈공간에서도 스와이프 잘 잡히게
      onHorizontalDragStart: (_) {
        _dragAccum = 0.0;
      },
      onHorizontalDragUpdate: (details) {
        _dragAccum += details.delta.dx;
      },
      onHorizontalDragEnd: (details) {
        // ✅ 속도 + 거리 둘 중 하나만 넘으면 전환
        const velocityThreshold = 100.0; // 완화
        const distanceThreshold = 60.0; // 완화

        final v = details.primaryVelocity ?? 0.0;

        // → 다음 달
        if (v < -velocityThreshold || _dragAccum <= -distanceThreshold) {
          final nextMonth =
              DateTime(widget.focusedDay.year, widget.focusedDay.month + 1, 15);
          widget.onPageChanged(nextMonth);
          return;
        }

        // ← 이전 달
        if (v > velocityThreshold || _dragAccum >= distanceThreshold) {
          final prevMonth =
              DateTime(widget.focusedDay.year, widget.focusedDay.month - 1, 15);
          widget.onPageChanged(prevMonth);
          return;
        }
        // 임계치 미달: 아무 동작 안 함 (실수 스와이프 방지)
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 요일 헤더
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
            child: Row(
              children: List.generate(7, (index) {
                Color dayColor = const Color(0xFF757575);
                if (_isSundayIndex(index, weekStart)) {
                  dayColor = Colors.red.shade600;
                } else if (_isSaturdayIndex(index, weekStart)) {
                  dayColor = Colors.blue.shade600;
                }
                return Expanded(
                  child: Center(
                    child: Text(
                      labels[index],
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: dayColor,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          // 주 단위 행
          for (int w = 0; w < weeks; w++) ...[
            if (w > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Divider(
                  height: 8,
                  thickness: 0.8,
                  color: theme.colorScheme.onSurface.withOpacity(0.06),
                ),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(10, 4, 10, w == weeks - 1 ? 0 : 4),
              child: _WeekRow(
                start: gridStart.add(Duration(days: w * 7)),
                month: widget.focusedDay.month,
                selectedDay: widget.selectedDay,
                today: _dateOnly(DateTime.now()),
                eventLoader: widget.eventLoader,
                onPick: (d) => widget.onDaySelected(d, widget.focusedDay),
                holidays: _holidays,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WeekRow extends StatelessWidget {
  const _WeekRow({
    required this.start,
    required this.month,
    required this.selectedDay,
    required this.today,
    required this.eventLoader,
    required this.onPick,
    required this.holidays,
  });

  final DateTime start;
  final int month;
  final DateTime? selectedDay;
  final DateTime today;
  final List<CalendarEvent> Function(DateTime) eventLoader;
  final void Function(DateTime) onPick;
  final List<Holiday> holidays;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(7, (i) {
        final day = DateTime(start.year, start.month, start.day + i);
        final isOutside = day.month != month;
        final isToday = _sameDate(day, today);
        final isSelected = selectedDay != null && _sameDate(day, selectedDay!);
        final holiday =
            holidays.firstWhereOrNull((h) => _sameDate(day, h.date));
        final events = eventLoader(day);

        return Expanded(
          child: _DayCell(
            day: day,
            isOutside: isOutside,
            isToday: isToday,
            isSelected: isSelected,
            holidayName: holiday?.name,
            events: events,
            onTap: () => onPick(day),
          ),
        );
      }),
    );
  }

  bool _sameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.isOutside,
    required this.isToday,
    required this.isSelected,
    this.holidayName,
    required this.events,
    required this.onTap,
  });

  final DateTime day;
  final bool isOutside;
  final bool isToday;
  final bool isSelected;
  final String? holidayName;
  final List<CalendarEvent> events;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // '휴식'은 근무에서 제외
    final CalendarEvent? work =
        events.firstWhereOrNull((e) => !e.isTodo && e.title != '휴식');

    final bool hasMemos =
        events.any((e) => e.isTodo && e.title == 'memo_marker');
    final bool isHoliday = holidayName != null;
    final String? abbr = work?.short?.trim();
    final bool hasWork = work != null && abbr != null && abbr.isNotEmpty;

    final Color workColor = work?.color ?? Colors.transparent;
    final Color? outsideBg = (!hasWork && isOutside)
        ? theme.colorScheme.onSurface.withOpacity(0.05)
        : null;

    Color holidayTextColor = isDark ? Colors.red.shade300 : Colors.red.shade700;

    if (hasWork &&
        workColor.red > 180 &&
        workColor.green < 120 &&
        workColor.blue < 120) {
      holidayTextColor = Colors.white.withOpacity(0.95);
    }

    Color dateTextColor;
    if (hasWork) {
      dateTextColor =
          ThemeData.estimateBrightnessForColor(workColor) == Brightness.dark
              ? Colors.white.withOpacity(0.9)
              : Colors.black.withOpacity(0.8);
    } else if (isOutside) {
      dateTextColor = theme.colorScheme.onSurface.withOpacity(0.4);
    } else if (isHoliday) {
      dateTextColor = holidayTextColor;
    } else if (day.weekday == DateTime.sunday) {
      dateTextColor = Colors.red.shade600;
    } else if (day.weekday == DateTime.saturday) {
      dateTextColor = Colors.blue.shade600;
    } else {
      dateTextColor = theme.colorScheme.onSurface;
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 64,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: hasWork ? workColor : outsideBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : (isToday
                    ? theme.colorScheme.onSurface.withOpacity(0.5)
                    : Colors.transparent),
            width: isSelected ? 2.2 : (isToday ? 1.5 : 0),
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 날짜 (상단 좌측)
            Positioned(
              top: 5,
              left: 7,
              child: Text(
                '${day.day}',
                style: TextStyle(
                  fontSize: 13,
                  color: dateTextColor,
                  fontWeight: isToday ? FontWeight.bold : FontWeight.w600,
                ),
              ),
            ),

            // 공휴일 이름 (날짜 아래, 중앙)
            if (isHoliday)
              Positioned(
                top: 22,
                left: 4,
                right: 4,
                child: Text(
                  holidayName!,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 9,
                    color: holidayTextColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

            // 근무 약어 (하단 우측)
            if (hasWork)
              Positioned(
                bottom: 5,
                right: 7,
                child: Text(
                  abbr,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: dateTextColor,
                  ),
                ),
              ),

            // 메모(할 일) 체크 표시 (하단 좌측)
            if (hasMemos)
              Positioned(
                bottom: 5,
                left: 7,
                child: Icon(
                  Icons.check,
                  size: 14,
                  color: hasWork
                      ? dateTextColor.withOpacity(0.8)
                      : theme.colorScheme.primary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

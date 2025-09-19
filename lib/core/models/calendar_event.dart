import 'package:flutter/material.dart';

class CalendarEvent {
  final String title;
  final String? short;
  final Color? color;
  final bool isTodo;
  final DateTime? date;
  final String? memo; // <<< ✅ 추가된 부분
  final dynamic originalData;

  CalendarEvent({
    required this.title,
    this.short,
    this.color,
    this.isTodo = false,
    this.date,
    this.memo, // <<< ✅ 추가된 부분
    this.originalData,
  });

  factory CalendarEvent.fromWorkSchedule(Map<String, dynamic> map) {
    final colorInt = (map['color'] ?? 0xFF5B8DEF) as int;
    return CalendarEvent(
      title: map['title']?.toString() ?? '',
      short: map['abbreviation']?.toString(),
      color: Color(colorInt),
      isTodo: false,
      date: DateTime.tryParse(map['start_date']?.toString() ?? ''),
      memo: map['memo']?.toString(), // <<< ✅ 추가된 부분
      originalData: map,
    );
  }

  factory CalendarEvent.fromMemo(Map<String, dynamic> map) {
    return CalendarEvent(
      title: map['text']?.toString() ?? '메모',
      isTodo: true,
      date: DateTime.tryParse(map['date']?.toString() ?? ''),
      memo: null, // 메모 자체이므로 별도 memo 필드는 없음
      originalData: map,
    );
  }
}

// lib/core/models/work_schedule.dart
import 'dart:convert';
import 'package:flutter/material.dart';

class WorkSchedule {
  // Supabase UUID 호환
  final String id;

  // 날짜
  final DateTime startDate;

  // 표시용 제목 (DB: title)
  final String? title; // ✅ 추가

  // 기존 필드 유지
  final String pattern;
  final String abbreviation;
  final int color;
  final String startTime; // "HH:mm:ss" 예상 (nullable 들어오면 빈 문자열 처리)
  final String endTime; // "
  final double nightHours;
  final String? memo;

  WorkSchedule({
    required this.id,
    required this.startDate,
    this.title, // ✅ 추가
    required this.pattern,
    required this.abbreviation,
    required this.color,
    required this.startTime,
    required this.endTime,
    required this.nightHours,
    this.memo,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'start_date': startDate.toIso8601String().split('T').first,
      'title': title, // ✅ 포함
      'pattern': pattern,
      'abbreviation': abbreviation,
      'color': color,
      'start_time': startTime,
      'end_time': endTime,
      'night_hours': nightHours,
      'memo': memo,
    };
  }

  factory WorkSchedule.fromMap(Map<String, dynamic> map) {
    String asString(dynamic v) => v?.toString() ?? '';
    int asInt(dynamic v, {int fallback = 0}) {
      if (v == null) return fallback;
      if (v is int) return v;
      return int.tryParse(v.toString()) ?? fallback;
    }

    double asDouble(dynamic v, {double fallback = 0.0}) {
      if (v == null) return fallback;
      if (v is double) return v;
      if (v is int) return v.toDouble();
      return double.tryParse(v.toString()) ?? fallback;
    }

    DateTime asDate(dynamic v) {
      if (v is DateTime) return v;
      // '2025-08-24' or ISO8601
      return DateTime.parse(v.toString());
    }

    return WorkSchedule(
      id: asString(map['id']),
      startDate: asDate(map['start_date']),
      title: map['title']?.toString(), // ✅ 매핑
      pattern: asString(map['pattern']),
      abbreviation: asString(map['abbreviation']),
      color: asInt(map['color'], fallback: 0xFF5B8DEF),
      startTime: asString(map['start_time']),
      endTime: asString(map['end_time']),
      nightHours: asDouble(map['night_hours']),
      memo: map['memo']?.toString(),
    );
  }
}

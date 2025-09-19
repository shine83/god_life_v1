// lib/core/models/shift_type.dart
import 'package:flutter/material.dart';

/// ShiftType: 클래스 형태이지만 enum처럼도 사용할 수 있도록
/// 정적 상수(day/evening/night/off)와 values를 제공합니다.
/// - 다른 파일에서 Color, TimeOfDay 타입으로 접근하는 코드와 호환됩니다.
class ShiftType {
  final String name; // 근무명 (예: 주간)
  final String abbreviation; // 약어   (예: D)
  final Color color; // UI 표시용 색상
  final TimeOfDay startTime; // 시작 시간
  final TimeOfDay endTime; // 종료 시간

  const ShiftType({
    required this.name,
    required this.abbreviation,
    required this.color,
    required this.startTime,
    required this.endTime,
  });

  // ---- enum처럼 쓰기 위한 정적 상수 ----
  static const ShiftType day = ShiftType(
    name: '주간',
    abbreviation: 'D',
    color: Color(0xFF5B8DEF),
    startTime: TimeOfDay(hour: 9, minute: 0),
    endTime: TimeOfDay(hour: 18, minute: 0),
  );

  static const ShiftType evening = ShiftType(
    name: '오후',
    abbreviation: 'E',
    color: Color(0xFFFFCA28),
    startTime: TimeOfDay(hour: 14, minute: 0),
    endTime: TimeOfDay(hour: 23, minute: 0),
  );
  // 안전한 기본 타입 반환
  static ShiftType defaultType() {
    return const ShiftType(
      name: '알 수 없음',
      abbreviation: '?',
      color: Colors.grey,
      startTime: TimeOfDay(hour: 0, minute: 0),
      endTime: TimeOfDay(hour: 0, minute: 0),
    );
  }

  static const ShiftType night = ShiftType(
    name: '야간',
    abbreviation: 'N',
    color: Color(0xFF7C4DFF),
    startTime: TimeOfDay(hour: 22, minute: 0),
    endTime: TimeOfDay(hour: 6, minute: 0),
  );

  static const ShiftType off = ShiftType(
    name: '휴무',
    abbreviation: 'O',
    color: Color(0xFF9E9E9E),
    startTime: TimeOfDay(hour: 0, minute: 0),
    endTime: TimeOfDay(hour: 0, minute: 0),
  );

  /// enum의 values처럼 순회용 리스트 제공
  static const List<ShiftType> values = [day, evening, night, off];

  /// 약어로 찾기 (대소문자 무시)
  static ShiftType? fromAbbreviation(String abbr) {
    final a = abbr.trim().toLowerCase();
    for (final s in values) {
      if (s.abbreviation.toLowerCase() == a) return s;
    }
    return null;
  }

  /// 이름으로 찾기
  static ShiftType? fromName(String name) {
    for (final s in values) {
      if (s.name == name) return s;
    }
    return null;
  }

  @override
  String toString() => 'ShiftType($abbreviation)';
}

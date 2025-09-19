// lib/features/onboarding/tutorial_service.dart
import 'package:flutter/material.dart';

/// 앱 전역 튜토리얼/가이드 투어 컨트롤러 (임시 스텁)
class GuidedTourController {
  final BuildContext context;
  GuidedTourController(this.context);

  /// 설정 페이지: 모든 튜토리얼 상태 초기화
  static Future<void> resetAllTutorials() async {
    // TODO: 여기서 SharedPreferences/DB 플래그 초기화 등 실제 로직 구현
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }

  /// 근무 캘린더 페이지의 가이드 투어 시작
  void startCalendarPageTour() {
    // TODO: 실제 튜토리얼 시작 로직 연결
  }

  /// 근무 폼 다이얼로그의 가이드 투어 시작
  void startShiftFormTour() {
    // TODO: 실제 튜토리얼 시작 로직 연결
  }
}

/// 튜토리얼에서 참조하는 전역 key 모음 (임시 스텁)
class TutorialTargets {
  static final GlobalKey shiftFormSaveKey = GlobalKey();
}

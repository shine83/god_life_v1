import 'package:flutter/material.dart';

/// 전역에서 쓰일 간격·모서리·그림자 등을 정의해 놓은 곳
class DesignTokens {
  // Spacing: 위젯 간격 단위
  static const double spacingSmall = 8.0; // 작을 때
  static const double spacingMedium = 16.0; // 보통
  static const double spacingLarge = 24.0; // 클 때

  // Border radius: 둥근 모서리 반지름
  static const BorderRadius borderRadiusDefault =
      BorderRadius.all(Radius.circular(12.0));

  // BoxShadow: 그림자 스타일
  static const List<BoxShadow> boxShadowDefault = [
    BoxShadow(
      color: Colors.black12, // 검정 12% 투명도
      blurRadius: 8.0, // 번짐 정도
      offset: Offset(0, 4), // x,y 오프셋
    ),
  ];
}

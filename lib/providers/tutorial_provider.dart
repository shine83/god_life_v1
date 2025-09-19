// lib/providers/tutorial_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

// '캘린더 튜토리얼을 보여달라'는 요청을 관리하는 Provider
final calendarTutorialRequestProvider = StateProvider<bool>((ref) => false);

// 하단 탭의 현재 인덱스를 관리하는 Provider (0 = 홈, 1 = 캘린더, ...)
final mainTabIndexProvider = StateProvider<int>((ref) => 0);

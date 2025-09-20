import 'package:god_life_v1/features/ai_coach/engines/recovery_engine.dart';

/// 교대근무자 맞춤 코칭 프롬프트 생성기 (이모지 소제목 스타일, 굵은표기 제거)
class CoachingPrompter {
  // ── 공용: 요약 카드용 ───────────────────────────────────────────
  static String summary(RecoveryEngineInput i, RecoveryResult r) {
    final isNight = i.shiftType.contains('야') ||
        i.shiftType.toLowerCase().contains('night');

    final contextHint = [
      if (isNight) '지금은 🌙 야간 근무 흐름을 고려해 회복 우선.',
      if (!isNight) '주간 리듬을 유지하면서 컨디션 관리.',
      if (r.recoveryScore < 40) '회복 점수가 낮으니 무리 금지.',
      if (r.loadScore > 70) '부하가 높아 회복 전략을 강조.',
      '데이터가 부족하면 보수적으로 조언.',
    ].join(' ');

    return '''
너는 교대근무자의 건강 코치야. 아래 데이터를 “한눈에 이해”될 1~2문장 한국어 조언으로 요약해줘. 이모지 1~2개만 사용하고, 실행 지시어 포함. 200자 이내.

[데이터]
• 근무: ${i.shiftType} (종료 후 ${i.sinceShiftEnd.inHours}h)
• 회복/부하: ${r.recoveryScore.toStringAsFixed(0)} / ${r.loadScore.toStringAsFixed(0)} (모드: ${r.mode})
• 수면: ${i.sleepHours.toStringAsFixed(1)}h (깸 ${i.awakeMin}분, in-bed ${i.inBedHours.toStringAsFixed(1)}h, deep ${i.deepPct.toStringAsFixed(0)}%, rem ${i.remPct.toStringAsFixed(0)}%)
• 심박: 안정 ${i.restHR.toStringAsFixed(0)}bpm
• 활동: 걸음 ${i.steps}, 거리 ${i.distanceKm.toStringAsFixed(2)}km, 에너지 ${i.activeKcal.toStringAsFixed(0)}kcal
• 수면부채: ${i.sleepDebtHours.toStringAsFixed(1)}h

[상황 힌트]
$contextHint

[형식 예]
- "💤 오늘은 회복 우선! 낮잠 20분과 수분 보충으로 리듬 회복, 고강도 운동은 내일로 미뤄요."
- "☀️ 컨디션 양호. 가벼운 유산소 20~30분과 점심 이후 카페인 컷오프로 오후 퍼포먼스를 유지해요."
''';
  }

  // ── 공용: 상세 코칭용 ─────────────────────────────────────────
  static String detail(RecoveryEngineInput i, RecoveryResult r) {
    final isNight = i.shiftType.contains('야') ||
        i.shiftType.toLowerCase().contains('night');
    final shiftHint =
        isNight ? '야간 근무 후 회복 우선, 서서히 주간 리듬 복귀.' : '주간/오전 활동을 활용해 리듬 강화.';

    return '''
너는 데이터 기반 교대근무 코치야. 아래 데이터를 해석해 "오늘 전략"을 제시해.
결과는 소제목(이모지+제목)과 불릿(•) 4~6개로 구성하고, 각 불릿은 실행 가능한 액션을 담아라.
한국어 400~700자. 특수문자는 과하게 쓰지 말고 깔끔하게.

[데이터]
• 근무: ${i.shiftType}, 종료 후 ${i.sinceShiftEnd.inHours}시간
• 회복/부하: ${r.recoveryScore.toStringAsFixed(0)} / ${r.loadScore.toStringAsFixed(0)} (모드: ${r.mode})
• 수면: 총 ${i.sleepHours.toStringAsFixed(1)}h, deep ${i.deepPct.toStringAsFixed(0)}%, rem ${i.remPct.toStringAsFixed(0)}%, 깸 ${i.awakeMin}분, in-bed ${i.inBedHours.toStringAsFixed(1)}h
• 심박: 안정 ${i.restHR.toStringAsFixed(0)}bpm
• 활동: 걸음 ${i.steps}, 거리 ${i.distanceKm.toStringAsFixed(2)}km, 에너지 ${i.activeKcal.toStringAsFixed(0)}kcal
• 수면부채: ${i.sleepDebtHours.toStringAsFixed(1)}h

[상황 힌트]
- $shiftHint
- 회복 점수가 낮거나 부하가 높으면 강도/시간을 낮추고, 회복/수면을 우선.
- 데이터가 부족하면 보편적이고 안전한 지침 제시.

[문단 구성 가이드]
🧭 컨디션 요약
• 텍스트…
• 텍스트…

🛌 수면/회복
• 텍스트…
• 텍스트…

🏃 활동/운동
• 텍스트…
• 텍스트…

🥗 영양/수분
• 텍스트…
• 텍스트…

☀️ 리듬 관리
• 텍스트…
• 텍스트…
''';
  }

  // ── PT 코치 전용 ──────────────────────────────────────────────
  static String ptSummary(RecoveryEngineInput i, RecoveryResult r) {
    return '''
너는 개인 트레이너야. 과부하 주의와 회복을 고려해 안전한 지침을 우선 제시해.
아래 데이터를 참고해 오늘 운동 권장안을 1~2문장으로 요약(200자 이내), 이모지 1개 사용.

[핵심 데이터]
• 회복/부하: ${r.recoveryScore.toStringAsFixed(0)} / ${r.loadScore.toStringAsFixed(0)} (모드: ${r.mode})
• 수면: ${i.sleepHours.toStringAsFixed(1)}h, 수면부채 ${i.sleepDebtHours.toStringAsFixed(1)}h
• 심박: 안정 ${i.restHR.toStringAsFixed(0)}bpm
• 활동: 걸음 ${i.steps}, 거리 ${i.distanceKm.toStringAsFixed(2)}km, 에너지 ${i.activeKcal.toStringAsFixed(0)}kcal
''';
  }

  static String ptDetail(RecoveryEngineInput i, RecoveryResult r) {
    return '''
너는 개인 트레이너야. 아래 데이터를 근거로 구체적인 운동 코칭을 제공해.
소제목(이모지) + 불릿(•) 형식, 400~700자. 워밍업/본운동/쿨다운, 강도/시간 범위를 제시.

[데이터]
• 회복/부하: ${r.recoveryScore.toStringAsFixed(0)} / ${r.loadScore.toStringAsFixed(0)} (모드: ${r.mode})
• 수면/부채: ${i.sleepHours.toStringAsFixed(1)}h / ${i.sleepDebtHours.toStringAsFixed(1)}h
• 안정심박: ${i.restHR.toStringAsFixed(0)}bpm
• 활동: 걸음 ${i.steps}, 거리 ${i.distanceKm.toStringAsFixed(2)}km, 에너지 ${i.activeKcal.toStringAsFixed(0)}kcal
''';
  }

  // ── 수면 루틴 전용 ─────────────────────────────────────────────
  static String sleepSummary(RecoveryEngineInput i, RecoveryResult r) {
    return '''
너는 수면 전문가야. 아래 데이터를 바탕으로 핵심 조언을 1~2문장으로 요약(200자 이내)하고, 실행 제안을 포함해.
이모지 1개만 사용.

[수면 데이터]
• 총수면: ${i.sleepHours.toStringAsFixed(1)}h (깸 ${i.awakeMin}분)
• in-bed: ${i.inBedHours.toStringAsFixed(1)}h
• deep: ${i.deepPct.toStringAsFixed(0)}%, rem: ${i.remPct.toStringAsFixed(0)}%
• 수면부채: ${i.sleepDebtHours.toStringAsFixed(1)}h
''';
  }

  static String sleepDetail(RecoveryEngineInput i, RecoveryResult r) {
    return '''
너는 수면 전문가야. 취침/기상 루틴과 수면의 질 향상을 위해 구체적인 행동 지침을 제시해.
소제목(이모지) + 불릿(•) 4~6개, 400~700자. 카페인 컷오프/빛 노출/낮잠/온도/수면위생 포함.

[수면 데이터]
• 총수면: ${i.sleepHours.toStringAsFixed(1)}h, 수면부채 ${i.sleepDebtHours.toStringAsFixed(1)}h
• in-bed: ${i.inBedHours.toStringAsFixed(1)}h, 깸 ${i.awakeMin}분
• deep: ${i.deepPct.toStringAsFixed(0)}%, rem: ${i.remPct.toStringAsFixed(0)}%
• 근무: ${i.shiftType} (종료 후 ${i.sinceShiftEnd.inHours}h)
''';
  }

  // ── 스트레스 관리 전용 ────────────────────────────────────────
  static String stressSummary(RecoveryEngineInput i, RecoveryResult r) {
    return '''
너는 스트레스 관리 전문가야. 안정심박과 수면/부하를 참조해 오늘의 스트레스/회복 상태를 1~2문장으로 요약(200자 이내)하고,
호흡/스트레칭 등 실행 제안을 포함해. 이모지 1개 사용.

[핵심 데이터]
• 안정심박: ${i.restHR.toStringAsFixed(0)}bpm
• 수면: ${i.sleepHours.toStringAsFixed(1)}h, 수면부채 ${i.sleepDebtHours.toStringAsFixed(1)}h
• 부하: ${r.loadScore.toStringAsFixed(0)} / 회복: ${r.recoveryScore.toStringAsFixed(0)}
''';
  }

  static String stressDetail(RecoveryEngineInput i, RecoveryResult r) {
    return '''
너는 스트레스 관리 전문가야. 호흡법, 근이완, 짧은 명상, 가벼운 유산소 등을 조합해 단계별 루틴을 제시해.
소제목(이모지) + 불릿(•) 4~6개, 400~700자. 야간/주간 근무 맥락을 반영.

[데이터]
• 안정심박: ${i.restHR.toStringAsFixed(0)}bpm
• 수면/부채: ${i.sleepHours.toStringAsFixed(1)}h / ${i.sleepDebtHours.toStringAsFixed(1)}h
• 활동/부하: 걸음 ${i.steps}, 에너지 ${i.activeKcal.toStringAsFixed(0)}kcal, 부하 ${r.loadScore.toStringAsFixed(0)}
• 근무: ${i.shiftType} (종료 후 ${i.sinceShiftEnd.inHours}h)
''';
  }
}

// lib/features/ai_coach/engines/recovery_engine.dart

class RecoveryEngineInput {
  final String shiftType; // '주','오','야','휴'
  final Duration sinceShiftEnd;

  // Sleep
  final double sleepHours, deepPct, remPct, inBedHours;
  final int awakeMin;

  // Activity
  final int steps;
  final double distanceKm, activeKcal;

  // Vitals
  final double restHR;

  // Percentiles / scaling
  final double stepsPct, distancePct, kcalPct;

  // Debt
  final double sleepDebtHours;

  const RecoveryEngineInput({
    required this.shiftType,
    required this.sinceShiftEnd,
    required this.sleepHours,
    required this.deepPct,
    required this.remPct,
    required this.inBedHours,
    required this.awakeMin,
    required this.steps,
    required this.distanceKm,
    required this.activeKcal,
    required this.restHR,
    required this.stepsPct,
    required this.distancePct,
    required this.kcalPct,
    required this.sleepDebtHours,
  });
}

class RecoveryResult {
  final double recoveryScore;
  final double loadScore;
  final String mode; // Train / Maintain / Recover
  const RecoveryResult(this.recoveryScore, this.loadScore, this.mode);
}

class RecoveryEngine {
  static double _clamp(double x, double lo, double hi) =>
      x < lo ? lo : (x > hi ? hi : x);

  static double _z(double x, double mean, double sd) =>
      sd <= 1e-6 ? 0 : (x - mean) / sd;

  /// HRV 없는 회복 점수 계산
  static RecoveryResult compute(
    RecoveryEngineInput i, {
    double restHrMean = 60,
    double restHrSd = 8,
  }) {
    // 안정심박이 낮을수록 좋음 → 점수화
    final restHRComp =
        _clamp(100 - _z(i.restHR, restHrMean, restHrSd) * 12.0, 0, 100);

    // 수면량/수면질
    final sleepQty = _clamp((i.sleepHours / 7.5) * 100, 0, 120);
    final fragPenalty = _clamp(i.awakeMin / 2.0, 0, 30);
    final sleepQual =
        _clamp((i.deepPct * 60 + i.remPct * 40) - fragPenalty, 0, 100);

    // ── 가중치 (합 1.0) ──
    // HRV(0.35) 제거분을 RHR(+0.25), 수면량(+0.05), 수면질(+0.05)에 분배
    final raw = 0.40 * restHRComp + 0.30 * sleepQty + 0.30 * sleepQual;

    // 교대 리듬 패널티
    double circadian = switch (i.shiftType) {
      '야' => 15,
      '오' => 8,
      _ => 0,
    };
    if (i.sinceShiftEnd.inHours <= 18 && circadian > 0) circadian += 5;

    final recovery = _clamp(
      raw - _clamp(i.sleepDebtHours * 6, 0, 25) - circadian,
      0,
      100,
    );

    // 일일 부하(간단 종합)
    final load = _clamp(
      0.4 * i.stepsPct + 0.3 * i.distancePct + 0.3 * i.kcalPct,
      0,
      100,
    );

    final mode =
        (recovery >= 70) ? 'Train' : (recovery >= 45 ? 'Maintain' : 'Recover');

    return RecoveryResult(recovery, load, mode);
  }
}

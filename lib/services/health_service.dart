// lib/services/health_service.dart

import 'package:collection/collection.dart';
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 권한 모음 (네가 쓰던 파일 경로 그대로)
import 'package:god_life_v1/features/health_connect/health_permissions.dart'
    as hp;

/// ====== 화면에서 쓰기 좋은 포인트 ======
class MetricPoint {
  final String label; // 예: '9/10', '오늘'
  final double value;
  const MetricPoint(this.label, this.value);
}

/// ====== 기존 스냅샷 모델 (그대로 유지) ======
class HealthSnapshot {
  final int steps;
  final double activeCalories;
  final double sleepTotalMin;
  final double sleepDeepMin;
  final double sleepRemMin;
  final int? heartMin;
  final int? heartMax;
  final int? heartResting;
  final double? hrvSdn;
  final int mindfulMinutes;
  final double? bmi;
  final DateTime capturedAt;

  const HealthSnapshot({
    required this.steps,
    required this.activeCalories,
    required this.sleepTotalMin,
    required this.sleepDeepMin,
    required this.sleepRemMin,
    required this.heartMin,
    required this.heartMax,
    required this.heartResting,
    required this.hrvSdn,
    required this.mindfulMinutes,
    required this.bmi,
    required this.capturedAt,
  });

  bool get isFresh =>
      DateTime.now().difference(capturedAt) <= const Duration(hours: 24);
}

class HealthService {
  // --- SharedPreferences Keys ---
  static const kCapturedAt = 'health_capturedAt';
  static const kSteps = 'health_steps';
  static const kActiveCalories = 'health_active_calories';

  static const kSleepTotal = 'health_sleep_total';
  static const kSleepDeep = 'health_sleep_deep';
  static const kSleepRem = 'health_sleep_rem';

  static const kHeartRateMin = 'health_hr_min';
  static const kHeartRateMax = 'health_hr_max';
  static const kHeartRateResting = 'health_hr_resting';

  static const kBmi = 'health_bmi';

  // 선택/확장 키
  static const kHrvSdn = 'health_hrv_sdn';
  static const kMindfulMinutes = 'health_mindful_minutes';

  // 프로필(문자열 저장) – 키/몸무게
  static const kProfileHeight = 'profile_height';
  static const kProfileWeight = 'profile_weight';

  /// =========================
  /// (기존) 오늘자 스냅샷 동기화
  /// =========================
  static Future<void> syncNow() async {
    final health = Health();
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);
    final yesterdayMidnight = midnight.subtract(const Duration(days: 1));
    final longWindow = now.subtract(const Duration(days: 365));

    const dailyTypes = [
      HealthDataType.STEPS,
      HealthDataType.ACTIVE_ENERGY_BURNED,
    ];
    const hrTypes = [
      HealthDataType.HEART_RATE,
      HealthDataType.RESTING_HEART_RATE,
    ];
    const staticTypes = [
      HealthDataType.HEIGHT,
      HealthDataType.WEIGHT,
      HealthDataType.BODY_MASS_INDEX,
    ];
    const sleepTypes = [
      HealthDataType.SLEEP_IN_BED,
      HealthDataType.SLEEP_LIGHT,
      HealthDataType.SLEEP_DEEP,
      HealthDataType.SLEEP_REM,
    ];

    final daily = dailyTypes.where(hp.types.contains).toList();
    final hr = hrTypes.where(hp.types.contains).toList();
    final stat = staticTypes.where(hp.types.contains).toList();
    final sleep = sleepTypes.where(hp.types.contains).toList();

    final futures = <Future<List<HealthDataPoint>>>[];
    if (daily.isNotEmpty) {
      futures.add(health.getHealthDataFromTypes(
          startTime: midnight, endTime: now, types: daily));
    }
    if (hr.isNotEmpty) {
      futures.add(health.getHealthDataFromTypes(
          startTime: yesterdayMidnight, endTime: now, types: hr));
    }
    if (stat.isNotEmpty) {
      futures.add(health.getHealthDataFromTypes(
          startTime: longWindow, endTime: now, types: stat));
    }
    for (final t in sleep) {
      futures.add(health.getHealthDataFromTypes(
          startTime: yesterdayMidnight, endTime: now, types: [t]));
    }

    List<HealthDataPoint> all = [];
    try {
      final results = await Future.wait(futures);
      for (final r in results) {
        all.addAll(r);
      }
    } catch (_) {
      return;
    }

    final summary = _summarize(all);
    await _cacheSnapshot(summary);
  }

  /// 포인트 → 요약값(Map) 생성 (기존 유지)
  static Map<String, dynamic> _summarize(List<HealthDataPoint> points) {
    final inBedPoints = points
        .where((p) => p.type == HealthDataType.SLEEP_IN_BED)
        .sortedBy<DateTime>((p) => p.dateFrom)
        .toList();

    final sessions = <List<HealthDataPoint>>[];
    if (inBedPoints.isNotEmpty) {
      sessions.add([inBedPoints.first]);
      for (int i = 1; i < inBedPoints.length; i++) {
        final prev = sessions.last.last;
        final cur = inBedPoints[i];
        if (cur.dateFrom.difference(prev.dateTo).inHours >= 4) {
          sessions.add([cur]);
        } else {
          sessions.last.add(cur);
        }
      }
    }
    List<HealthDataPoint> main = [];
    if (sessions.isNotEmpty) {
      sessions.sort((a, b) {
        final da = a.fold<double>(
            0, (s, p) => s + (p.value as NumericHealthValue).numericValue);
        final db = b.fold<double>(
            0, (s, p) => s + (p.value as NumericHealthValue).numericValue);
        return db.compareTo(da);
      });
      main = sessions.first;
    }
    DateTime? s0, e0;
    if (main.isNotEmpty) {
      s0 = main.first.dateFrom;
      e0 = main.last.dateTo;
    }

    double inBed = 0, light = 0, deep = 0, rem = 0;
    for (final p in points) {
      final v = (p.value is NumericHealthValue)
          ? (p.value as NumericHealthValue).numericValue.toDouble()
          : null;
      if (v == null) continue;

      bool inMain = false;
      if (s0 != null && e0 != null) {
        inMain = (p.dateFrom.isAfter(s0) || p.dateFrom.isAtSameMomentAs(s0)) &&
            (p.dateTo.isBefore(e0) || p.dateTo.isAtSameMomentAs(e0));
      }

      switch (p.type) {
        case HealthDataType.SLEEP_IN_BED:
          if (inMain) inBed += v;
          break;
        case HealthDataType.SLEEP_LIGHT:
          if (inMain) light += v;
          break;
        case HealthDataType.SLEEP_DEEP:
          if (inMain) deep += v;
          break;
        case HealthDataType.SLEEP_REM:
          if (inMain) rem += v;
          break;
        default:
          break;
      }
    }
    final asleep = light + deep + rem;

    int steps = 0;
    double active = 0;
    final hrs = <int>[];
    int? resting;

    final latestHeight = points
        .where((p) => p.type == HealthDataType.HEIGHT)
        .sortedBy<DateTime>((p) => p.dateFrom)
        .lastOrNull;
    final latestWeight = points
        .where((p) => p.type == HealthDataType.WEIGHT)
        .sortedBy<DateTime>((p) => p.dateFrom)
        .lastOrNull;
    final latestBmi = points
        .where((p) => p.type == HealthDataType.BODY_MASS_INDEX)
        .sortedBy<DateTime>((p) => p.dateFrom)
        .lastOrNull;

    for (final p in points) {
      final nv = (p.value is NumericHealthValue)
          ? (p.value as NumericHealthValue).numericValue
          : null;
      if (nv == null) continue;
      switch (p.type) {
        case HealthDataType.STEPS:
          steps += nv.toInt();
          break;
        case HealthDataType.ACTIVE_ENERGY_BURNED:
          active += nv.toDouble();
          break;
        case HealthDataType.HEART_RATE:
          hrs.add(nv.toInt());
          break;
        case HealthDataType.RESTING_HEART_RATE:
          resting = nv.toInt();
          break;
        default:
          break;
      }
    }

    double? bmiValue =
        (latestBmi?.value as NumericHealthValue?)?.numericValue.toDouble();
    if (bmiValue == null) {
      final hVal = latestHeight?.value;
      final wVal = latestWeight?.value;
      if (hVal is NumericHealthValue && wVal is NumericHealthValue) {
        final hM = hVal.numericValue.toDouble() / 100.0;
        final wKg = wVal.numericValue.toDouble();
        if (hM > 0 && wKg > 0) {
          bmiValue = wKg / (hM * hM);
        }
      }
    }

    final minHr = hrs.isEmpty ? 0 : hrs.reduce((a, b) => a < b ? a : b);
    final maxHr = hrs.isEmpty ? 0 : hrs.reduce((a, b) => a > b ? a : b);

    return {
      'capturedAt': DateTime.now().millisecondsSinceEpoch,
      'steps': steps,
      'activeCalories': active,
      'bmi': bmiValue,
      'sleepAsleep': asleep,
      'sleepInBed': inBed,
      'sleepTotalMin': asleep,
      'sleepDeepMin': deep,
      'sleepRemMin': rem,
      'hrResting': resting ?? 0,
      'hrMin': minHr,
      'hrMax': maxHr,
    };
  }

  static Future<void> _cacheSnapshot(Map<String, dynamic> s) async {
    final p = await SharedPreferences.getInstance();

    await p.setInt(kCapturedAt, s['capturedAt'] as int);
    await p.setInt(kSteps, s['steps'] as int);
    await p.setDouble(kActiveCalories, (s['activeCalories'] as num).toDouble());

    if (s['bmi'] != null) {
      await p.setDouble(kBmi, (s['bmi'] as num).toDouble());
    } else {
      await p.remove(kBmi);
    }

    await p.setDouble(
        'health_sleep_asleep', (s['sleepAsleep'] as num?)?.toDouble() ?? 0.0);
    await p.setDouble(
        'health_sleep_in_bed', (s['sleepInBed'] as num?)?.toDouble() ?? 0.0);

    await p.setDouble(
        kSleepTotal,
        (s['sleepTotalMin'] as num?)?.toDouble() ??
            (s['sleepAsleep'] as num?)?.toDouble() ??
            0.0);
    await p.setDouble(
        kSleepDeep, (s['sleepDeepMin'] as num?)?.toDouble() ?? 0.0);
    await p.setDouble(kSleepRem, (s['sleepRemMin'] as num?)?.toDouble() ?? 0.0);

    await p.setInt(kHeartRateResting, s['hrResting'] as int);
    await p.setInt(kHeartRateMin, s['hrMin'] as int);
    await p.setInt(kHeartRateMax, s['hrMax'] as int);

    await p.remove(kHrvSdn);
    await p.remove(kMindfulMinutes);
  }

  static Future<HealthSnapshot?> getSnapshot() async {
    final p = await SharedPreferences.getInstance();
    final tsMs = p.getInt(kCapturedAt);
    if (tsMs == null) return null;

    final asleepLegacy = p.getDouble('health_sleep_asleep') ?? 0.0;

    final captured = DateTime.fromMillisecondsSinceEpoch(tsMs);
    return HealthSnapshot(
      steps: p.getInt(kSteps) ?? 0,
      activeCalories: p.getDouble(kActiveCalories) ?? 0.0,
      sleepTotalMin: (p.getDouble(kSleepTotal) ?? asleepLegacy).toDouble(),
      sleepDeepMin: (p.getDouble(kSleepDeep) ?? 0).toDouble(),
      sleepRemMin: (p.getDouble(kSleepRem) ?? 0).toDouble(),
      heartMin: p.getInt(kHeartRateMin),
      heartMax: p.getInt(kHeartRateMax),
      heartResting: p.getInt(kHeartRateResting),
      hrvSdn: p.getDouble(kHrvSdn),
      mindfulMinutes: p.getInt(kMindfulMinutes) ?? 0,
      bmi: p.getDouble(kBmi),
      capturedAt: captured,
    );
  }

  static Future<Map<String, double?>> getProfileVitals() async {
    final p = await SharedPreferences.getInstance();
    final heightString = p.getString(kProfileHeight);
    final weightString = p.getString(kProfileWeight);

    final double? height = heightString != null && heightString.isNotEmpty
        ? double.tryParse(heightString)
        : null;
    final double? weight = weightString != null && weightString.isNotEmpty
        ? double.tryParse(weightString)
        : null;

    return {
      'height': height,
      'weight': weight,
    };
  }

  static Future<Map<String, int>> getDetailedSleepData() async {
    final s = await getSnapshot();
    return {
      'total': (s?.sleepTotalMin ?? 0).toInt(),
      'deep': (s?.sleepDeepMin ?? 0).toInt(),
      'rem': (s?.sleepRemMin ?? 0).toInt(),
    };
  }

  static Future<Map<String, int>> getDetailedHeartRateData() async {
    final s = await getSnapshot();
    return {
      'resting': s?.heartResting ?? 0,
      'min': s?.heartMin ?? 0,
      'max': s?.heartMax ?? 0,
    };
  }

  static Future<Map<String, num?>> getStressRecoveryData() async {
    final s = await getSnapshot();
    return {
      'hrv': s?.hrvSdn,
      'mindful': s?.mindfulMinutes ?? 0,
    };
  }

  static Future<List<int>> getLast3DaysSteps() async {
    final s = await getSnapshot();
    final v = s?.steps ?? 0;
    return [v, v, v];
  }

  /// =========================
  /// (신규) 최근 7일 집계 – 라인차트/바차트용
  /// =========================

  /// 최근 7일 걸음 수(일별 합) → MetricPoint(label=M/d 또는 '오늘', value=steps)
  static Future<List<MetricPoint>> getWeeklySteps() async {
    final health = Health();
    if (!hp.types.contains(HealthDataType.STEPS)) {
      // 권한 요청/허용 전이면 0으로 채움
      return _empty7();
    }

    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 6)); // 6일 전 00:00
    final end = now; // 지금

    final data = await health.getHealthDataFromTypes(
      startTime: start,
      endTime: end,
      types: const [HealthDataType.STEPS],
    );

    // 날짜(로컬 자정 기준)로 버킷팅
    final buckets = <DateTime, int>{};
    for (final p in data) {
      final v = (p.value is NumericHealthValue)
          ? (p.value as NumericHealthValue).numericValue.toInt()
          : 0;
      if (v <= 0) continue;

      final dayKey =
          DateTime(p.dateFrom.year, p.dateFrom.month, p.dateFrom.day);
      buckets.update(dayKey, (prev) => prev + v, ifAbsent: () => v);
    }

    // 7일 라벨 생성 + 값 채우기
    final out = <MetricPoint>[];
    for (int i = 0; i < 7; i++) {
      final d = start.add(Duration(days: i));
      final isToday =
          d.year == now.year && d.month == now.month && d.day == now.day;
      final label = isToday ? '오늘' : '${d.month}/${d.day}';
      final value = (buckets[d] ?? 0).toDouble();
      out.add(MetricPoint(label, value));
    }
    return out;
  }

  /// 최근 7일 수면(분) – LIGHT+DEEP+REM 합 (일별 합계)
  static Future<List<MetricPoint>> getWeeklySleepMinutes() async {
    final health = Health();
    final needed = <HealthDataType>[
      HealthDataType.SLEEP_LIGHT,
      HealthDataType.SLEEP_DEEP,
      HealthDataType.SLEEP_REM,
    ].where(hp.types.contains).toList();

    if (needed.isEmpty) return _empty7();

    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 6));
    final end = now;

    final data = await health.getHealthDataFromTypes(
      startTime: start,
      endTime: end,
      types: needed,
    );

    final buckets = <DateTime, double>{};
    for (final p in data) {
      final v = (p.value is NumericHealthValue)
          ? (p.value as NumericHealthValue).numericValue.toDouble()
          : 0.0;
      if (v <= 0) continue;

      final dayKey =
          DateTime(p.dateFrom.year, p.dateFrom.month, p.dateFrom.day);
      buckets.update(dayKey, (prev) => prev + v, ifAbsent: () => v);
    }

    final out = <MetricPoint>[];
    for (int i = 0; i < 7; i++) {
      final d = start.add(Duration(days: i));
      final isToday =
          d.year == now.year && d.month == now.month && d.day == now.day;
      final label = isToday ? '오늘' : '${d.month}/${d.day}';
      final value = (buckets[d] ?? 0).toDouble();
      out.add(MetricPoint(label, value));
    }
    return out;
  }

  static List<MetricPoint> _empty7() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 6));
    return List.generate(7, (i) {
      final d = start.add(Duration(days: i));
      final isToday =
          d.year == now.year && d.month == now.month && d.day == now.day;
      final label = isToday ? '오늘' : '${d.month}/${d.day}';
      return MetricPoint(label, 0);
    });
  }
}

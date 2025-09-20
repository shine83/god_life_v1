// lib/services/health_warmup.dart
import 'package:collection/collection.dart';
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:god_life_v1/services/health_service.dart';
import 'dart:developer' as dev;

/// 앱 런치 시 한 번 호출해서 "오늘 데이터"를 기기에서 읽어 캐시에 적재한다.
/// 권한이 없거나 Health 앱이 미설치면 조용히 실패하고 넘어간다.
class HealthWarmup {
  static final Health _health = Health();

  /// 안전하게: 실패해도 예외 터뜨리지 않음
  static Future<void> warmupTodayAndCache() async {
    try {
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);
      final yesterdayMidnight = midnight.subtract(const Duration(days: 1));
      final longWindow = now.subtract(const Duration(days: 365));

      // 요청 타입 (HealthConnectPage와 동일 셋)
      const dailyTypes = <HealthDataType>[
        HealthDataType.STEPS,
        HealthDataType.ACTIVE_ENERGY_BURNED,
      ];
      const sleepTypes = <HealthDataType>[
        HealthDataType.SLEEP_IN_BED,
        HealthDataType.SLEEP_LIGHT,
        HealthDataType.SLEEP_DEEP,
        HealthDataType.SLEEP_REM,
      ];
      const hrTypes = <HealthDataType>[
        HealthDataType.HEART_RATE,
        HealthDataType.RESTING_HEART_RATE,
      ];
      const staticTypes = <HealthDataType>[
        HealthDataType.HEIGHT,
        HealthDataType.WEIGHT,
        HealthDataType.BODY_MASS_INDEX,
      ];

      final futures = <Future<List<HealthDataPoint>>>[];
      futures.add(_health.getHealthDataFromTypes(
          startTime: midnight, endTime: now, types: dailyTypes));
      futures.add(_health.getHealthDataFromTypes(
          startTime: yesterdayMidnight, endTime: now, types: hrTypes));
      futures.add(_health.getHealthDataFromTypes(
          startTime: longWindow, endTime: now, types: staticTypes));
      for (final t in sleepTypes) {
        futures.add(_health.getHealthDataFromTypes(
            startTime: yesterdayMidnight, endTime: now, types: [t]));
      }

      final results = await Future.wait(futures);
      final all = <HealthDataPoint>[];
      for (final r in results) {
        all.addAll(r);
      }

      final summary = _summarize(all);
      await _cacheSnapshot(summary);
      dev.log('Health warmup done', name: 'HealthWarmup');
    } catch (e, st) {
      dev.log('Health warmup failed: $e', stackTrace: st, name: 'HealthWarmup');
      // 조용히 패스 (권한 없음/네트워크 등)
    }
  }

  static Map<String, dynamic> _summarize(List<HealthDataPoint> points) {
    // IN_BED 포인트로 가장 긴 세션 탐색
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
      'hrResting': resting ?? 0,
      'hrMin': minHr,
      'hrMax': maxHr,
    };
  }

  static Future<void> _cacheSnapshot(Map<String, dynamic> s) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(HealthService.kCapturedAt, s['capturedAt'] as int);
    await prefs.setInt(HealthService.kSteps, s['steps'] as int);
    await prefs.setDouble(
        HealthService.kActiveCalories, (s['activeCalories'] as num).toDouble());
    final bmi = s['bmi'];
    if (bmi is double) {
      await prefs.setDouble(HealthService.kBmi, bmi);
    } else {
      await prefs.remove(HealthService.kBmi);
    }
    await prefs.setDouble(
        'health_sleep_asleep', (s['sleepAsleep'] as num).toDouble());
    await prefs.setDouble(
        'health_sleep_in_bed', (s['sleepInBed'] as num).toDouble());
    await prefs.setInt(HealthService.kHeartRateResting, s['hrResting'] as int);
    await prefs.setInt(HealthService.kHeartRateMin, s['hrMin'] as int);
    await prefs.setInt(HealthService.kHeartRateMax, s['hrMax'] as int);

    // HRV/마인드풀 제거 키는 안전차원에서 삭제
    await prefs.remove(HealthService.kHrvSdn);
    await prefs.remove(HealthService.kMindfulMinutes);
  }
}

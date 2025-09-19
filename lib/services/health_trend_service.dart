import 'package:collection/collection.dart';
import 'package:health/health.dart';

/// 주간(마지막 N일) 트렌드 헬퍼
class HealthTrendService {
  final Health _health = Health();

  /// 최근 [days]일 수면 "asleep(= light+deep+rem)" 총합(분) – 애플 건강 방식 유지
  Future<List<_DayValue<double>>> getSleepAsleepMinutesForLastDays({
    int days = 7,
  }) async {
    final now = DateTime.now();
    final List<_DayValue<double>> out = [];

    for (int d = days - 1; d >= 0; d--) {
      final dayStart =
          DateTime(now.year, now.month, now.day).subtract(Duration(days: d));
      final dayEnd = dayStart.add(const Duration(days: 1));

      // 해당 일자 구간의 수면 관련 데이터만 조회
      final points = await _health.getHealthDataFromTypes(
        startTime:
            dayStart.subtract(const Duration(hours: 4)), // 밤샘 구간 여유 (변경 X)
        endTime: dayEnd.add(const Duration(hours: 4)),
        types: const [
          HealthDataType.SLEEP_IN_BED,
          HealthDataType.SLEEP_LIGHT,
          HealthDataType.SLEEP_DEEP,
          HealthDataType.SLEEP_REM,
        ],
      );

      // ── 아래 로직은 HealthService._summarize()의 수면 처리와 동일한 개념을 "해당 일자 구간"에만 적용 ──
      // IN_BED로 세션을 나누고 가장 긴 세션을 메인으로 선택
      final inBed = points
          .where((p) => p.type == HealthDataType.SLEEP_IN_BED)
          .sortedBy<DateTime>((p) => p.dateFrom)
          .toList();

      final sessions = <List<HealthDataPoint>>[];
      if (inBed.isNotEmpty) {
        sessions.add([inBed.first]);
        for (int i = 1; i < inBed.length; i++) {
          final prev = sessions.last.last;
          final cur = inBed[i];
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
          final da = a.fold<double>(0, (s, p) => s + _numVal(p));
          final db = b.fold<double>(0, (s, p) => s + _numVal(p));
          return db.compareTo(da);
        });
        main = sessions.first;
      }

      DateTime? s0, e0;
      if (main.isNotEmpty) {
        // 메인 세션의 시각을 하루 경계에 클램프(해당 날짜 밖으로 새나가는 걸 방지)
        s0 = main.first.dateFrom.isBefore(dayStart)
            ? dayStart
            : main.first.dateFrom;
        e0 = main.last.dateTo.isAfter(dayEnd) ? dayEnd : main.last.dateTo;
      }

      double light = 0, deep = 0, rem = 0;
      for (final p in points) {
        final v = _numVal(p);
        if (v == 0) continue;

        bool inMain = false;
        if (s0 != null && e0 != null) {
          inMain =
              (p.dateFrom.isAfter(s0) || p.dateFrom.isAtSameMomentAs(s0)) &&
                  (p.dateTo.isBefore(e0) || p.dateTo.isAtSameMomentAs(e0));
        }

        if (!inMain) continue;
        switch (p.type) {
          case HealthDataType.SLEEP_LIGHT:
            light += v;
            break;
          case HealthDataType.SLEEP_DEEP:
            deep += v;
            break;
          case HealthDataType.SLEEP_REM:
            rem += v;
            break;
          default:
            break;
        }
      }

      final asleep = light + deep + rem; // ← **애플 건강과 동일 컨셉 유지**
      out.add(_DayValue(dayStart, asleep)); // 단위: 분
    }

    return out;
  }

  /// 예: 걸음/칼로리 등 필요 시 같은 패턴으로 추가
  // Future<List<_DayValue<double>>> getStepsForLastDays({int days = 7}) async { ... }

  double _numVal(HealthDataPoint p) {
    final v = p.value;
    if (v is NumericHealthValue) return v.numericValue.toDouble();
    return 0;
  }
}

/// 내부 전달용 (date + value)
class _DayValue<T extends num> {
  final DateTime day; // 00:00 기준
  final T value;
  const _DayValue(this.day, this.value);
}

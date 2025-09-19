// lib/features/health_connect/health_permissions.dart
import 'package:health/health.dart';

const List<HealthDataType> kRequestedHealthTypes = [
  // Daily
  HealthDataType.STEPS,
  HealthDataType.ACTIVE_ENERGY_BURNED,

  // Sleep (요약 로직에 맞춤)
  HealthDataType.SLEEP_IN_BED,
  HealthDataType.SLEEP_LIGHT,
  HealthDataType.SLEEP_DEEP,
  HealthDataType.SLEEP_REM,

  // Heart rate (HRV 제거)
  HealthDataType.HEART_RATE,
  HealthDataType.RESTING_HEART_RATE,

  // Body composition
  HealthDataType.HEIGHT,
  HealthDataType.WEIGHT,
  HealthDataType.BODY_MASS_INDEX,
];

/// alias (기존 코드 호환)
const types = kRequestedHealthTypes;

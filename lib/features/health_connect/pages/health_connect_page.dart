// lib/features/health_connect/pages/health_connect_page.dart
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:god_life_v1/features/health_connect/health_permissions.dart'
    as hp;
import 'package:god_life_v1/services/health_service.dart';
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class HealthConnectPage extends StatefulWidget {
  const HealthConnectPage({super.key});

  @override
  State<HealthConnectPage> createState() => _HealthConnectPageState();
}

class _HealthConnectPageState extends State<HealthConnectPage> {
  final Health _health = Health();

  String _statusText = '권한을 요청하여 건강 데이터를 연동하세요.';
  bool _loading = false;

  int _steps = 0;
  double _activeCalories = 0;
  double? _bmi;
  Map<String, double> _sleep = {'inBed': 0, 'asleep': 0};
  Map<String, int> _hr = {'resting': 0, 'min': 0, 'max': 0};

  Future<void> _openAppSettings() async {
    final uri = Uri.parse('app-settings:');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('설정을 열 수 없어요. 설정 앱에서 수동으로 권한을 확인해주세요.')),
      );
    }
  }

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      try {
        await _health.installHealthConnect();
      } catch (_) {}
    }
    setState(() => _loading = true);
    try {
      final readPerms =
          List<HealthDataAccess>.filled(hp.types.length, HealthDataAccess.READ);
      final ok =
          await _health.requestAuthorization(hp.types, permissions: readPerms);
      if (!mounted) return;
      if (ok) {
        setState(() => _statusText = '✅ 권한 허용됨. 최신 데이터 동기화 중…');
        await _syncViaService();
      } else {
        setState(() => _statusText = '권한이 거절되었습니다. 설정에서 권한을 허용해주세요.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _statusText = '권한 요청 실패: $e');
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  /// AI 탭과 동일한 경로: HealthService.syncNow() → 캐시 갱신 → UI 반영
  Future<void> _syncViaService() async {
    setState(() => _loading = true);
    try {
      await HealthService.syncNow(); // ✅ 전역 동기화(오늘 데이터)
      await _loadFromCache(); // 캐시 값을 UI로 반영
      if (!mounted) return;
      setState(() => _statusText = '✅ 데이터 불러오기 완료!');
    } catch (e) {
      if (!mounted) return;
      setState(() => _statusText = '데이터 불러오기 실패: $e');
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _loadFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _steps = prefs.getInt(HealthService.kSteps) ?? 0;
      _activeCalories = prefs.getDouble(HealthService.kActiveCalories) ?? 0;
      _bmi = prefs.getDouble(HealthService.kBmi);
      _sleep = {
        // 레거시 키 그대로 표기(HealthService가 동기화 시 갱신)
        'asleep': prefs.getDouble('health_sleep_asleep') ?? 0,
        'inBed': prefs.getDouble('health_sleep_in_bed') ?? 0,
      };
      _hr = {
        'resting': prefs.getInt(HealthService.kHeartRateResting) ?? 0,
        'min': prefs.getInt(HealthService.kHeartRateMin) ?? 0,
        'max': prefs.getInt(HealthService.kHeartRateMax) ?? 0,
      };
    });
  }

  void _applyToUi(Map<String, dynamic> s) {
    setState(() {
      _steps = s['steps'] as int? ?? _steps;
      _activeCalories =
          (s['activeCalories'] as num?)?.toDouble() ?? _activeCalories;
      _bmi = s['bmi'] as double? ?? _bmi;
      _sleep = {
        'asleep':
            (s['sleepAsleep'] as num?)?.toDouble() ?? _sleep['asleep'] ?? 0,
        'inBed': (s['sleepInBed'] as num?)?.toDouble() ?? _sleep['inBed'] ?? 0,
      };
      _hr = {
        'resting': s['hrResting'] as int? ?? _hr['resting'] ?? 0,
        'min': s['hrMin'] as int? ?? _hr['min'] ?? 0,
        'max': s['hrMax'] as int? ?? _hr['max'] ?? 0,
      };
    });
  }

  @override
  void initState() {
    super.initState();
    _loadFromCache();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('건강앱 연동')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            children: [
              const Text(
                'AI 코칭 정확도를 높이려면, 가능한 모든 “읽기” 권한을 허용하세요.\n'
                '요청 후에도 값이 비어있다면 iOS 건강앱/Android Health Connect에서 공유 항목을 확인해 주세요.',
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _requestPermissions,
                      icon: const Icon(Icons.verified_user_outlined),
                      label: const Text('모든 건강 권한 요청하기'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _syncViaService, // ✅ 전역 동기화 사용
                      icon: const Icon(Icons.sync),
                      label: const Text('최신 데이터 새로고침'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _openAppSettings,
                  icon: const Icon(Icons.settings_outlined),
                  label: const Text('권한 설정 열기'),
                ),
              ),
              const SizedBox(height: 8),
              if (_loading) const LinearProgressIndicator(),
              const SizedBox(height: 8),
              Text(_statusText, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              _SummaryCard(
                steps: _steps,
                activeCalories: _activeCalories,
                bmi: _bmi,
                sleep: _sleep,
                hr: _hr,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.steps,
    required this.activeCalories,
    required this.bmi,
    required this.sleep,
    required this.hr,
  });

  final int steps;
  final double activeCalories;
  final double? bmi;
  final Map<String, double> sleep;
  final Map<String, int> hr;

  String _fmtSleep(double? minutes) {
    if (minutes == null || minutes <= 0) return '-';
    final m = minutes.toInt();
    final h = m ~/ 60;
    final mm = m % 60;
    return '$h시간 $mm분';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleStyle =
        theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold);
    final metricStyle = theme.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w800, color: theme.colorScheme.primary);
    final labelStyle = TextStyle(fontSize: 12, color: Colors.grey.shade600);

    Widget metric(String label, String value, String unit) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: labelStyle),
          const SizedBox(height: 6),
          Text(value, style: metricStyle),
          const SizedBox(height: 2),
          Text(unit, style: labelStyle),
        ],
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        child: Column(
          children: [
            Text('최근 건강 데이터 요약', style: titleStyle),
            const Divider(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                metric('걸음 수', '$steps', '걸음'),
                metric('활동 칼로리', activeCalories.toStringAsFixed(0), 'kcal'),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                metric('BMI', bmi != null ? bmi!.toStringAsFixed(1) : '-',
                    'kg/m²'),
              ],
            ),
            const Divider(height: 32),
            Text('수면 분석', style: titleStyle),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Column(
                  children: [
                    Text('취침 시간', style: theme.textTheme.bodyLarge),
                    const SizedBox(height: 4),
                    Text(_fmtSleep(sleep['inBed']),
                        style: theme.textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
                Column(
                  children: [
                    Text('수면 시간', style: theme.textTheme.bodyLarge),
                    const SizedBox(height: 4),
                    Text(_fmtSleep(sleep['asleep']),
                        style: theme.textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
            const Divider(height: 32),
            Text('심박수 분석', style: titleStyle),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                Text('안정: ${hr['resting'] ?? 0} bpm'),
                Text('최저: ${hr['min'] ?? 0} bpm'),
                Text('최고: ${hr['max'] ?? 0} bpm'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

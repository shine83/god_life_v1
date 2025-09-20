// lib/features/ai_coach/ai_coach_page.dart
import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:god_life_v1/core/models/work_schedule.dart';
import 'package:god_life_v1/features/ai_coach/engines/coaching_prompter.dart';
import 'package:god_life_v1/features/ai_coach/engines/recovery_engine.dart';
import 'package:god_life_v1/services/ai_service.dart';
import 'package:god_life_v1/services/health_service.dart';
import 'package:god_life_v1/services/work_schedule_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AiCoachPage extends StatefulWidget {
  const AiCoachPage({super.key, this.initialTabIndex = 0});
  final int initialTabIndex;

  @override
  State<AiCoachPage> createState() => _AiCoachPageState();
}

class _AiCoachPageState extends State<AiCoachPage>
    with SingleTickerProviderStateMixin {
  final _ai = AIService();
  final _ws = WorkScheduleService();

  late TabController _tab;
  bool _loading = true;

  // 생성된 코칭 결과
  String _managerSummary = 'AI 분석을 통해 일상 관리 팁을 제공합니다.';
  String _managerDetail = '';
  String _ptSummary = '오늘의 활동량에 맞춘 PT 코칭을 제공합니다.';
  String _ptDetail = '';
  String _sleepSummary = '수면 패턴을 바탕으로 코칭을 제공합니다.';
  String _sleepDetail = '';
  String _stressSummary = '스트레스와 회복 상태에 대한 코칭을 제공합니다.';
  String _stressDetail = '';

  @override
  void initState() {
    super.initState();
    _tab = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    _refreshAll();
  }

  Future<void> _refreshAll() async {
    setState(() => _loading = true);
    try {
      // ✅ 건강앱 동기화(Health Connect와 동일 동작)
      await HealthService.syncNow();

      // 1) 입력 데이터 구성
      final input = await _buildInput();

      // 2) 회복/부하 산출
      final result = RecoveryEngine.compute(input);

      // 3) 프롬프트 만들기 (CoachingPrompter 전용 메서드 사용)
      final managerSummaryPrompt = CoachingPrompter.summary(input, result);
      final managerDetailPrompt = CoachingPrompter.detail(input, result);

      final ptSummaryPrompt = CoachingPrompter.ptSummary(input, result);
      final ptDetailPrompt = CoachingPrompter.ptDetail(input, result);

      final sleepSummaryPrompt = CoachingPrompter.sleepSummary(input, result);
      final sleepDetailPrompt = CoachingPrompter.sleepDetail(input, result);

      final stressSummaryPrompt = CoachingPrompter.stressSummary(input, result);
      final stressDetailPrompt = CoachingPrompter.stressDetail(input, result);

      // 4) AI 호출
      final res = await Future.wait<String>([
        _ai.getResponse(managerSummaryPrompt),
        _ai.getResponse(managerDetailPrompt),
        _ai.getResponse(ptSummaryPrompt),
        _ai.getResponse(ptDetailPrompt),
        _ai.getResponse(sleepSummaryPrompt),
        _ai.getResponse(sleepDetailPrompt),
        _ai.getResponse(stressSummaryPrompt),
        _ai.getResponse(stressDetailPrompt),
      ]);

      // 5) 상태 반영 (빈 응답이면 기존 요약 유지)
      setState(() {
        _managerSummary =
            res[0].trim().isEmpty ? _managerSummary : res[0].trim();
        _managerDetail = res[1];

        _ptSummary = res[2].trim().isEmpty ? _ptSummary : res[2].trim();
        _ptDetail = res[3];

        _sleepSummary = res[4].trim().isEmpty ? _sleepSummary : res[4].trim();
        _sleepDetail = res[5];

        _stressSummary = res[6].trim().isEmpty ? _stressSummary : res[6].trim();
        _stressDetail = res[7];
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _managerSummary = '코칭 데이터를 불러오지 못했어요 😢';
        _ptSummary = '네트워크 상태를 확인하고 다시 시도해주세요.';
        _sleepSummary = '데이터를 불러오지 못했어요 😢';
        _stressSummary = '데이터를 불러오지 못했어요 😢';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('코칭 생성 실패: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 시간 헬퍼
  DateTime _combineDateAndHms(DateTime date, String hms) {
    if (hms.isEmpty) hms = '00:00:00';
    final parts = hms.split(':');
    final h = int.parse(parts[0]);
    final m = (parts.length > 1) ? int.parse(parts[1]) : 0;
    final s = (parts.length > 2) ? int.parse(parts[2]) : 0;
    return DateTime(date.year, date.month, date.day, h, m, s);
  }

  DateTime endDateTimeOf(WorkSchedule s) {
    final startDT = _combineDateAndHms(s.startDate, s.startTime);
    var endDT = _combineDateAndHms(s.startDate, s.endTime);
    if (endDT.isBefore(startDT)) {
      endDT = endDT.add(const Duration(days: 1));
    }
    return endDT;
  }
  // ─────────────────────────────────────────────────────────────

  Future<RecoveryEngineInput> _buildInput() async {
    final p = await SharedPreferences.getInstance();

    final steps = p.getInt(HealthService.kSteps) ?? 0;
    final activeKcal = p.getDouble(HealthService.kActiveCalories) ?? 0.0;
    final resting = p.getInt(HealthService.kHeartRateResting) ?? 60;

    final sleepAsleepMin = p.getDouble('health_sleep_asleep') ?? 0.0;
    final sleepInBedMin = p.getDouble('health_sleep_in_bed') ?? 0.0;
    final sleepH = sleepAsleepMin / 60.0;
    final inBedH = sleepInBedMin / 60.0;

    // 상세 분절(깊은/REM)은 아직 추정값 고정
    final deepPct = 20.0;
    final remPct = 20.0;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final schedules = await _ws.getSchedulesInRange(
      firstDay: today.subtract(const Duration(days: 1)),
      lastDay: today.add(const Duration(days: 1)),
    );

    WorkSchedule? recent;
    if (schedules.isNotEmpty) {
      schedules.sort((a, b) => endDateTimeOf(b).compareTo(endDateTimeOf(a)));
      recent = schedules.first;
    }

    final shiftType = recent?.pattern ?? '주';
    final recentEnd = (recent != null) ? endDateTimeOf(recent) : now;
    final sinceShiftEnd =
        now.isAfter(recentEnd) ? now.difference(recentEnd) : Duration.zero;

    double clamp01(double v) => v.isNaN ? 0 : (v < 0 ? 0 : (v > 1 ? 1 : v));
    final stepsPct = clamp01(steps / 10000.0) * 100.0;
    final distanceKm = steps / 1300.0;
    final distancePct = clamp01(distanceKm / 8.0) * 100.0;
    final kcalPct = clamp01(activeKcal / 600.0) * 100.0;

    final sleepDebtH = 7.5 - sleepH;
    final sleepDebtHours = sleepDebtH > 0 ? sleepDebtH : 0.0;

    return RecoveryEngineInput(
      shiftType: shiftType,
      sinceShiftEnd: sinceShiftEnd,
      sleepHours: sleepH,
      deepPct: deepPct,
      remPct: remPct,
      inBedHours: inBedH,
      awakeMin: (sleepInBedMin - sleepAsleepMin).clamp(0, 600).toInt(),
      steps: steps,
      distanceKm: distanceKm,
      activeKcal: activeKcal,
      restHR: resting.toDouble(),
      stepsPct: stepsPct,
      distancePct: distancePct,
      kcalPct: kcalPct,
      sleepDebtHours: sleepDebtHours,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 건강 브리핑'),
        actions: [
          IconButton(
            tooltip: '새로고침',
            onPressed: _loading ? null : _refreshAll,
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
        ],
        // 카드형 세그먼트 탭
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: cs.surfaceVariant.withOpacity(0.60),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.outlineVariant.withOpacity(0.50)),
              ),
              child: TabBar(
                controller: _tab,
                isScrollable: false, // 4등분 균등폭
                labelPadding: EdgeInsets.zero,
                labelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2, // 한글 잘림 최소화
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
                labelColor: cs.onPrimaryContainer,
                unselectedLabelColor: cs.onSurfaceVariant,
                indicatorPadding: const EdgeInsets.all(4),
                indicator: BoxDecoration(
                  color: cs.primaryContainer.withOpacity(0.92),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: cs.primary.withOpacity(0.20),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                      color: Colors.black.withOpacity(0.08),
                    ),
                  ],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(text: '컨디션'),
                  Tab(text: '운동'),
                  Tab(text: '수면'),
                  Tab(text: '스트레스'),
                ],
              ),
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _CoachPane(
            icon: Icons.shield_outlined,
            title: '오늘의 컨디션', // ← 유지
            summary: _managerSummary,
            detail: _managerDetail,
            loading: _loading,
            onRefresh: _refreshAll,
          ),
          _CoachPane(
            icon: Icons.fitness_center_outlined,
            title: '오늘의 운동 코칭',
            summary: _ptSummary,
            detail: _ptDetail,
            loading: _loading,
            onRefresh: _refreshAll,
          ),
          _CoachPane(
            icon: Icons.nightlight_outlined,
            title: '수면 루틴 코칭',
            summary: _sleepSummary,
            detail: _sleepDetail,
            loading: _loading,
            onRefresh: _refreshAll,
          ),
          _CoachPane(
            icon: Icons.self_improvement,
            title: '스트레스 관리 코칭',
            summary: _stressSummary,
            detail: _stressDetail,
            loading: _loading,
            onRefresh: _refreshAll,
          ),
        ],
      ),
    );
  }
}

class _CoachPane extends StatelessWidget {
  const _CoachPane({
    required this.icon,
    required this.title,
    required this.summary,
    required this.detail,
    required this.loading,
    required this.onRefresh,
  });

  final IconData icon;
  final String title;
  final String summary;
  final String detail;
  final bool loading;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 1.5, // 경계 강화
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(
                children: [
                  Icon(icon, color: cs.primary),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 1.5, // 경계 강화
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: loading
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          summary,
                          style: const TextStyle(fontSize: 15, height: 1.5),
                        ),
                        if (detail.trim().isNotEmpty) ...[
                          const SizedBox(height: 12),
                          const Divider(height: 24),
                          Text(
                            detail,
                            style: const TextStyle(height: 1.6),
                          ),
                        ],
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 구독 유도용 잠금 오버레이 — 필요 시 bottomSheet로 사용
class _LockedOverlay extends StatelessWidget {
  const _LockedOverlay({required this.onSubscribe});
  final VoidCallback onSubscribe;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 140,
      child: Stack(
        fit: StackFit.expand,
        children: [
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: Container(color: Colors.black.withOpacity(0.3)),
          ),
          Center(
            child: ElevatedButton.icon(
              onPressed: onSubscribe,
              icon: const Icon(Icons.lock),
              label: const Text('구독하고 전체 코칭 보기'),
            ),
          ),
        ],
      ),
    );
  }
}

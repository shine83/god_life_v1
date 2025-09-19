// lib/features/ai/pages/ai_hub_page.dart
import 'dart:async'; // unawaited 사용
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:my_new_test_app/core/models/work_schedule.dart';
import 'package:my_new_test_app/features/ai_coach/ai_coach_page.dart';
import 'package:my_new_test_app/services/health_service.dart';
import 'package:my_new_test_app/services/work_schedule_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_new_test_app/dev/notification_lab_page.dart';
// ▼ 페이월 & 프리미엄 게이트 (호환 레이어)
import 'package:my_new_test_app/features/paywall/unified_paywall.dart';
import 'package:my_new_test_app/core/premium/premium_gate_compat.dart';

// ▼▼▼ [유지] 리치형 상세 페이지 연결용 임포트
import 'package:my_new_test_app/features/ai/pages/ai_recommendation_detail_page.dart';
// ▲▲▲

// 앱 시작 시 메인에서 남겨두는 “헬스 동기화 워밍업” 플래그 키
// ⚠️ main.dart 의 LaunchWarmup._flagKey 와 반드시 동일해야 함!
const String _kLaunchWarmupFlagKey = 'health_sync_requested_at';

class AiHubPage extends StatefulWidget {
  const AiHubPage({super.key});
  @override
  State<AiHubPage> createState() => _AiHubPageState();
}

class _AiHubPageState extends State<AiHubPage> {
  final _ws = WorkScheduleService();

  bool _isLoading = true;

  // 근무
  String _todaySchedule = '...';
  String _nextSchedule = '...';

  // 표시 문자열
  String _sleepH = '-';
  String _stepsStr = '-';
  String _kcalStr = '-';
  String _bmiStr = '-';
  String _rhrStr = '-';

  // 원시값
  int _sleepMinRaw = 0; // 분
  int _stepsRaw = 0;
  int? _rhrRaw;
  double? _bmiRaw;

  // 프리뷰 타이틀
  String _healthTipTitle = '오늘의 컨디션 한눈에 보기 📊';
  String _workoutTitle = '오늘의 추천 루틴 💪';
  String _sleepTitle = '수면 루틴 🛌';
  String _stressTitle = '스트레스 관리 🧘';

  @override
  void initState() {
    super.initState();
    _consumeLaunchWarmupFlag().then((_) => _loadAllData());
  }

  Future<void> _consumeLaunchWarmupFlag() async {
    final p = await SharedPreferences.getInstance();
    final last = p.getInt(_kLaunchWarmupFlagKey) ?? 0;
    if (last == 0) return;
    try {
      // 필요 시 실제 동기화 함수 호출:
      // await HealthService.I.syncToday();
    } catch (e) {
      debugPrint('Health warmup sync failed: $e');
    } finally {
      await p.remove(_kLaunchWarmupFlagKey);
    }
  }

  Future<void> _loadAllData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    // ✅ 건강앱 동기화(Health Connect 새로고침과 동일한 효과)
    await HealthService.syncNow();

    await Future.wait([
      _loadConditionData(),
      _composePreviewTitles(),
    ]);

    unawaited(_prefetchForAiCoach());
    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  // ---------- 스케줄 라벨 유틸 ----------
  String _labelForSchedule(WorkSchedule s) {
    String? trimOrNull(String? v) {
      final t = v?.trim();
      return (t == null || t.isEmpty) ? null : t;
    }

    final abbr = trimOrNull(s.abbreviation);
    if (abbr != null) return abbr;
    final title = trimOrNull(s.title);
    if (title != null) return title;
    final pat = trimOrNull(s.pattern);
    if (pat != null) return pat;
    return '근무';
  }

  // ---------- 오늘/다음 근무 + 헬스 지표 ----------
  Future<void> _loadConditionData() async {
    final now = DateTime.now();
    final today0 = DateTime(now.year, now.month, now.day);
    final tomorrow0 = today0.add(const Duration(days: 1));

    // 오늘 일정(정확히 오늘)
    final todayList = await _ws.getSchedulesInRange(
      firstDay: today0,
      lastDay: today0,
    );

    // 다음 근무: 내일부터 +60일 사이에서 가장 가까운 일정 1건
    final nextList = await _ws.getSchedulesInRange(
      firstDay: tomorrow0,
      lastDay: today0.add(const Duration(days: 60)),
    );
    final next = nextList.isEmpty
        ? null
        : minBy<WorkSchedule, DateTime>(nextList, (w) => w.startDate);

    // 건강 데이터 캐시
    final p = await SharedPreferences.getInstance();

    final sleepAsleep = p.getDouble('health_sleep_asleep') ?? 0.0;
    final steps = p.getInt(HealthService.kSteps) ?? 0;
    final activeKcal = p.getDouble(HealthService.kActiveCalories) ?? 0.0;
    final bmi = p.getDouble(HealthService.kBmi);
    final rhr = p.getInt(HealthService.kHeartRateResting) ?? 0;

    String fmtSteps(int v) {
      if (v >= 10000) return '${(v / 1000).toStringAsFixed(1)}k';
      return v.toString();
    }

    setState(() {
      _todaySchedule =
          todayList.isNotEmpty ? _labelForSchedule(todayList.first) : '휴식';
      _nextSchedule = next != null ? _labelForSchedule(next) : '예정 없음';

      _sleepH = sleepAsleep > 0 ? (sleepAsleep / 60).toStringAsFixed(1) : '-';
      _stepsStr = steps > 0 ? fmtSteps(steps) : '-';
      _kcalStr = activeKcal > 0 ? activeKcal.toStringAsFixed(0) : '-';
      _bmiStr = bmi != null ? bmi.toStringAsFixed(1) : '-';
      _rhrStr = rhr > 0 ? '$rhr' : '-';

      _sleepMinRaw = sleepAsleep.toInt();
      _stepsRaw = steps;
      _bmiRaw = bmi;
      _rhrRaw = rhr > 0 ? rhr : null;
    });
  }

  // 상세 페이지용 간단 프리페치(빠른 진입용)
  Future<void> _prefetchForAiCoach() async {
    try {
      final now = DateTime.now();
      await _ws.getSchedulesInRange(
        firstDay: now.subtract(const Duration(days: 14)),
        lastDay: now.add(const Duration(days: 7)),
      );
    } catch (_) {}
  }

  // 타이틀만 간단 조정(프리뷰 텍스트는 아래 Tip100 함수들이 담당)
  Future<void> _composePreviewTitles() async {
    final p = await SharedPreferences.getInstance();
    final sleepAsleep = p.getDouble('health_sleep_asleep') ?? 0.0;
    final steps = p.getInt(HealthService.kSteps) ?? 0;
    final rhr = p.getInt(HealthService.kHeartRateResting) ?? 0;

    // 일상 매니저
    String healthTitle = '오늘의 컨디션: 보통 📊';
    if (sleepAsleep > 0 && sleepAsleep < 360) {
      healthTitle = '수면 부족 주의 📉';
    } else if (rhr > 0 && rhr < 60) {
      healthTitle = '회복 상태 양호 ✅';
    }

    // PT 코치
    String workoutTitle = '오늘의 추천: 가벼운 전신 활성화';
    if (steps > 10000) {
      workoutTitle = '오늘의 추천: 고효율 인터벌 트레이닝';
    } else if (steps > 4000) {
      workoutTitle = '오늘의 추천: 중강도 유산소 + 코어';
    }

    // 수면 루틴 / 스트레스 관리 타이틀
    String sleepTitle = '수면 루틴 점검 🛌';
    String stressTitle = '스트레스 관리 🧘';

    setState(() {
      _healthTipTitle = healthTitle;
      _workoutTitle = workoutTitle;
      _sleepTitle = sleepTitle;
      _stressTitle = stressTitle;
    });
  }

  // ────────────────────── 프리뷰(약 100자) 생성기들 ──────────────────────
  String _clip(String s, [int max = 100]) =>
      s.length <= max ? s : '${s.substring(0, max - 1)}…';

  String _dailyManagerTip100() {
    final h = _sleepMinRaw ~/ 60, m = _sleepMinRaw % 60;
    final rhr = _rhrRaw;
    final sleepTxt = (_sleepMinRaw > 0) ? '수면 ${h}시간 ${m}분' : '수면 데이터 없음';
    final rhrTxt = (rhr != null && rhr > 0) ? '· 안정심박 ${rhr}bpm' : '';
    final kcalTxt = (_kcalStr != '-' ? '· 활동 ${_kcalStr}kcal' : '');
    final tip = (rhr != null && rhr >= 76)
        ? '스트레칭·호흡 3분으로 긴장 완화'
        : (h < 6 ? '낮잠 20분·카페인 컷오프' : '수분 보충과 가벼운 걷기');
    return _clip('오늘 컨디션 체크: $sleepTxt$rhrTxt$kcalTxt. $tip로 페이스 유지하세요.');
  }

  String _ptCoachTip100() {
    final steps = _stepsRaw;
    final bmi = _bmiRaw;
    String rec;
    if (steps >= 10000) {
      rec = '인터벌 유산소 15~20분 + 코어 2세트';
    } else if (steps >= 4000) {
      rec = '중강도 유산소 20~30분 또는 순환운동 3세트';
    } else {
      rec = '가벼운 전신 활성화 10~15분(워킹, 힙힌지, 벽푸쉬업)';
    }
    if (bmi != null && bmi >= 25) {
      rec += ' · 마무리 스트레칭 5분';
    }
    return _clip('오늘 추천 루틴: $rec. 통증 시 강도 낮추고, 호흡은 여유 있게 유지하세요.');
  }

  String _sleepTip100() {
    final h = _sleepMinRaw ~/ 60;
    final text = (h >= 8)
        ? '숙면 👍 — 기상 고정·아침 햇빛 10분으로 리듬 유지, 카페인은 점심 이후 자제하세요.'
        : (h >= 6)
            ? '보통 — 오늘은 낮잠 15~20분, 저녁 화면 밝기↓, 취침 2~3시간 전 간단 스트레칭을 추천.'
            : '부족 ⚠️ — 카페인 컷오프·늦은 운동 지양, 취침 전 30분 루틴(샤워→빛 차단→호흡 4-7-8).';
    return _clip(text);
  }

  String _stressTip100() {
    final rhr = _rhrRaw;
    if (rhr == null || rhr <= 0) {
      return _clip('스트레스 상태: 기본. 목·어깨 스트레칭 3분과 횡격막 호흡 2세트로 긴장도 관리해요.');
    }
    if (rhr < 60) {
      return _clip('회복 양호 ✅ — 4-6호흡 2분과 가벼운 산책으로 안정감 유지, 카페인은 과하지 않게.');
    } else if (rhr <= 75) {
      return _clip('보통 — 점심 전 5분 걷기+목·흉곽 스트레칭, 저녁엔 스크린타임 줄이고 수면 준비.');
    } else {
      return _clip('긴장 ↑ — 코히어런스 호흡(5초 들숨/5초 날숨) 3분×2, 상체 스트레칭 후 따뜻한 물 한 잔.');
    }
  }
  // ─────────────────────────────────────────────────────────────

  Future<void> _openPremiumDebugMenu() async {
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        Widget tile({
          required String title,
          required String subtitle,
          required IconData icon,
          required VoidCallback onTap,
        }) {
          return ListTile(
            leading: Icon(icon),
            title: Text(title,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(subtitle),
            onTap: () {
              Navigator.pop(ctx);
              onTap();
            },
          );
        }

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 4),
              const Text('프리미엄 테스트',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              tile(
                title: '무료 모드로 보기',
                subtitle: 'devOverride = false',
                icon: Icons.lock_open,
                onTap: () async {
                  await PremiumGateCompat.setDevOverride(false);
                  if (mounted) setState(() {});
                },
              ),
              tile(
                title: '프리미엄 모드로 보기',
                subtitle: 'devOverride = true',
                icon: Icons.workspace_premium,
                onTap: () async {
                  await PremiumGateCompat.setDevOverride(true);
                  if (mounted) setState(() {});
                },
              ),
              tile(
                title: '오버라이드 해제 (실제 결제 상태 사용)',
                subtitle: 'devOverride = null',
                icon: Icons.refresh,
                onTap: () async {
                  await PremiumGateCompat.setDevOverride(null);
                  if (mounted) setState(() {});
                },
              ),
              const Divider(),
              tile(
                title: '페이월 열기',
                subtitle: 'UnifiedPaywall.openSheet(context)',
                icon: Icons.payment,
                onTap: () => UnifiedPaywall.openSheet(context),
              ),
              tile(
                title: 'Notification Lab 열기',
                subtitle: '알림/오프셋/권한 빠른 테스트',
                icon: Icons.notifications_active,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const NotificationLabPage(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  // lib/features/ai/pages/ai_hub_page.dart
// << 이 함수만 수정하면 됩니다.
  void _openRecoDetail() async {
    // << 이 줄을 수정
    final ok = await PremiumGateCompat.effectivePremium(); // << 이 줄을 추가
    if (!mounted) return; // << 이 줄을 추가
    if (ok) {
      // << 이 줄을 추가
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AiRecommendationDetailPage.sample(),
        ),
      );
    } else {
      // << 이 줄을 추가
      await UnifiedPaywall.open(context); // << 이 줄을 추가 (페이월로 유도)
    } // << 이 줄을 추가
  }
  // ▲▲▲

  void _openCoach(int index) async {
    final ok = await PremiumGateCompat.effectivePremium();
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => AiCoachPage(initialTabIndex: index)),
      );
    } else {
      UnifiedPaywall.openSheet(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('AI 추천'),
        actions: [
          IconButton(
            tooltip: '프리미엄 테스트',
            icon: const Icon(Icons.workspace_premium),
            onPressed: _openPremiumDebugMenu,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _conditionCard(
            loading: _isLoading,
            todaySchedule: _todaySchedule,
            nextSchedule: _nextSchedule,
            onRefresh: _loadAllData,
          ),
          const SizedBox(height: 8),
          _card(
            icon: Icons.health_and_safety_outlined,
            title: '컨디션',
            contentWidget: _RichPreview(
              title: _healthTipTitle,
              subtitle: _dailyManagerTip100(),
              cta: '더 보기 (프리미엄)',
            ),
            onRefresh: _loadAllData,

            // ▼▼▼ 상세 페이지로 이동
            onTap: _openRecoDetail,
          ),
          const SizedBox(height: 8),
          _card(
            icon: Icons.fitness_center_outlined,
            title: '운동',
            contentWidget: _RichPreview(
              title: _workoutTitle,
              subtitle: _ptCoachTip100(),
              cta: '더 보기 (프리미엄)',
            ),
            onRefresh: _loadAllData,
            onTap: _openRecoDetail,
          ),
          const SizedBox(height: 8),
          _card(
            icon: Icons.nightlight_outlined,
            title: '수면',
            contentWidget: _RichPreview(
              title: _sleepTitle,
              subtitle: _sleepTip100(),
              cta: '더 보기 (프리미엄)',
            ),
            onRefresh: _loadAllData,
            onTap: _openRecoDetail,
          ),
          const SizedBox(height: 8),
          _card(
            icon: Icons.self_improvement,
            title: '스트레스',
            contentWidget: _RichPreview(
              title: _stressTitle,
              subtitle: _stressTip100(),
              cta: '더 보기 (프리미엄)',
            ),
            onRefresh: _loadAllData,
            onTap: _openRecoDetail,
          ),
        ],
      ),
    );
  }

  // ─────────── UI 컴포넌트 ───────────

  Widget _card({
    required IconData icon,
    required String title,
    required Widget contentWidget,
    required VoidCallback onRefresh,
    required VoidCallback onTap,
  }) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: Colors.deepPurple),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(title,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800)),
                  ),
                  IconButton(
                    onPressed: onRefresh,
                    icon: const Icon(Icons.refresh, size: 18),
                    splashRadius: 16,
                    tooltip: '새로고침',
                  ),
                ],
              ),
              const SizedBox(height: 6),
              contentWidget,
            ],
          ),
        ),
      ),
    );
  }

  Widget _conditionCard({
    required bool loading,
    required String todaySchedule,
    required String nextSchedule,
    required VoidCallback onRefresh,
  }) {
    final cs = Theme.of(context).colorScheme;
    final subHint = TextStyle(
      fontSize: 11,
      color: Colors.grey.shade700,
      height: 1.15,
    );

    Widget metric({
      required IconData icon,
      required String label,
      required String value,
      required String sublabel,
    }) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20),
          const SizedBox(height: 6),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 2),
          Text(sublabel,
              maxLines: 1, overflow: TextOverflow.ellipsis, style: subHint),
        ],
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.place_outlined,
                    size: 18, color: Colors.blueAccent),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('오늘 나의 컨디션',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                ),
                IconButton(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh, size: 18),
                  splashRadius: 16,
                  tooltip: '새로고침',
                ),
              ],
            ),
            const SizedBox(height: 8),
            _shiftHeaderRow(
              todayLabel: todaySchedule,
              nextLabel: nextSchedule,
            ),
            const SizedBox(height: 8),
            Divider(height: 1, color: cs.outline.withOpacity(0.2)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Center(
                    child: metric(
                      icon: Icons.bedtime,
                      label: '수면',
                      value: '${_sleepMinRaw ~/ 60}h ${_sleepMinRaw % 60}m',
                      sublabel: _sleepSubLabel(_sleepMinRaw),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: metric(
                      icon: Icons.directions_walk,
                      label: '걸음',
                      value: _stepsRaw > 0 ? _stepsRaw.toString() : '-',
                      sublabel: _stepsSubLabelKcal(_kcalStr),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: metric(
                      icon: Icons.favorite,
                      label: '안정심박',
                      value: _rhrRaw == null ? '—' : '${_rhrRaw}bpm',
                      sublabel: _stressSubLabel(_rhrRaw),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: metric(
                      icon: Icons.monitor_weight,
                      label: 'BMI',
                      value:
                          _bmiRaw == null ? '—' : _bmiRaw!.toStringAsFixed(1),
                      sublabel: _bmiSubLabel(_bmiRaw),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _shiftHeaderRow({
    required String todayLabel,
    required String nextLabel,
  }) {
    Widget pill(String text, Color color) {
      return Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          border: Border.all(color: color.withOpacity(0.30)),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      );
    }

    final c1 = Colors.indigo;
    final c2 = Colors.teal;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: pill('오늘근무 : $todayLabel', c1)),
          const SizedBox(width: 8),
          Expanded(child: pill('다음근무 : $nextLabel', c2)),
        ],
      ),
    );
  }

  String _sleepSubLabel(int sleepMin) {
    if (sleepMin <= 0) return '—';
    if (sleepMin >= 420) return '충분'; // 7h+
    if (sleepMin >= 360) return '보통'; // 6h~
    return '부족';
  }

  String _stepsSubLabelKcal(String kcalStr) {
    if (kcalStr == '-' || kcalStr.isEmpty) return '—';
    return '$kcalStr kcal';
  }

  String _stressSubLabel(int? rhr) {
    if (rhr == null || rhr <= 0) return '—';
    if (rhr < 60) return '🟢 안정';
    if (rhr <= 75) return '🟡 주의';
    return '🔴 높음';
  }

  String _bmiSubLabel(double? bmi) {
    if (bmi == null) return '—';
    if (bmi < 18.5) return '저체중';
    if (bmi < 23.0) return '정상';
    if (bmi < 25.0) return '과체중';
    return '비만';
  }
}

class _RichPreview extends StatelessWidget {
  final String title;
  final String subtitle;
  final String cta;
  const _RichPreview(
      {required this.title, required this.subtitle, required this.cta});

  @override
  Widget build(BuildContext context) {
    final hint = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Colors.grey.shade700,
          height: 1.45,
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 14, height: 1.5, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(subtitle,
            style: hint, maxLines: 3, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 8),
        Text(
          cta,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor),
        ),
      ],
    );
  }
}

// lib/features/ai/pages/ai_recommendation_detail_page.dart

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:god_life_v1/services/health_service.dart' as hs;

/// 섹션 타입
enum AiSection { condition, workout, sleep, stress }

/// 점 값(라벨+값) – 이 화면 전용 타입(서비스 타입과 이름 충돌 방지)
class MetricPoint {
  final String label;
  final double value;
  const MetricPoint(this.label, this.value);
}

/// 카테고리 점수(막대)
class MetricScore {
  final String label;
  final double value;
  const MetricScore(this.label, this.value);
}

/// 섹션별 데이터 묶음
class AiSectionData {
  final String emoji;
  final IconData icon;
  final String title;
  final String subtitle;
  final List<String> badges;

  /// 라인 차트 (최근 n일 추이)
  final List<MetricPoint> weeklyTrend;

  /// 막대 점수 (0~100)
  final List<MetricScore> categoryScores;

  /// 본문 팁(400~500자)
  final String longTip;

  const AiSectionData({
    required this.emoji,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.badges = const [],
    this.weeklyTrend = const [],
    this.categoryScores = const [],
    required this.longTip,
  });

  AiSectionData copyWith({
    List<MetricPoint>? weeklyTrend,
    List<MetricScore>? categoryScores,
  }) {
    return AiSectionData(
      emoji: emoji,
      icon: icon,
      title: title,
      subtitle: subtitle,
      badges: badges,
      weeklyTrend: weeklyTrend ?? this.weeklyTrend,
      categoryScores: categoryScores ?? this.categoryScores,
      longTip: longTip,
    );
  }
}

/// 디테일 페이지
class AiRecommendationDetailPage extends StatefulWidget {
  const AiRecommendationDetailPage({
    super.key,
    required this.condition,
    required this.workout,
    required this.sleep,
    required this.stress,
    this.onUpgrade,
  });

  final AiSectionData condition;
  final AiSectionData workout;
  final AiSectionData sleep;
  final AiSectionData stress;
  final VoidCallback? onUpgrade;

  factory AiRecommendationDetailPage.sample() {
    final baseCond = AiSectionData(
      emoji: '📊',
      icon: Icons.health_and_safety_outlined,
      title: '컨디션 인사이트',
      subtitle: '수면·걸음·안정심박 기반 회복 상태 점검',
      badges: const ['회복 관리', '수분 보충'],
      categoryScores: const [
        MetricScore('에너지', 62),
        MetricScore('집중도', 58),
        MetricScore('피로도', 40),
      ],
      longTip:
          '오늘의 전반적인 컨디션은 중간 정도로, 에너지 레벨은 무난하지만 피로 누적의 신호가 조금 보입니다. 오전엔 5~10분 가벼운 스트레칭과 물 한 컵으로 순환을 먼저 깨우고, 점심 직후에는 10분 정도 밝은 곳을 산책하며 햇빛을 받아 리듬을 정돈하세요. 오후 집중력이 흔들리면 90~120분 단위로 짧은 휴식(2~3분)과 목·흉곽 스트레칭을 섞어 긴장을 풀어주는 것이 좋습니다. 카페인은 오후 늦게로 갈수록 수면의 질을 해칠 수 있으니 14시 이후 섭취는 지양하고, 대신 미지근한 물이나 허브티로 대체해 컨디션 변동폭을 줄이세요. 저녁에는 과식·야식보다 단백질 위주의 균형 잡힌 식사와 가벼운 걷기로 소화를 돕고, 취침 2~3시간 전에는 스크린 밝기/노출 시간을 줄여 멜라토닌 분비를 방해하지 않도록 관리하면 내일 아침의 상쾌함이 확실히 달라집니다.',
    );

    final baseWork = AiSectionData(
      emoji: '💪',
      icon: Icons.fitness_center_outlined,
      title: '운동 코칭',
      subtitle: '오늘의 체력 상태에 맞춘 루틴',
      badges: const ['코어', '유산소'],
      categoryScores: const [
        MetricScore('유산소', 65),
        MetricScore('근지구력', 55),
        MetricScore('코어', 60),
      ],
      longTip:
          '오늘은 과부하보다는 효율에 중점을 둔 구성으로 추천합니다. 먼저 5~7분간 워밍업(관절가동 + 가벼운 유산소)으로 체온을 올리고, 인터벌 유산소(예: 1분 빠르게/1분 천천히 × 8~10라운드)로 심박을 안전하게 올려 산소섭취 효율을 끌어올리세요. 근지구력은 스쿼트·힌지·푸시·로우 계열에서 체중 위주 2~3세트씩, 반복은 숨이 차지 않을 정도의 난이도로 조절합니다. 마무리로 플랭크·데드버그 등 코어 안정화 2세트, 그리고 하체·흉곽 스트레칭 5분으로 긴장을 풀어 회복 속도를 높이세요. 통증이 있거나 수면이 부족했다면 강도를 10~20% 낮춰 부상 리스크를 줄이는 것이 장기적으로 더 큰 성과를 만듭니다. 내일의 컨디션을 위해 운동 직후 수분·단백질 섭취를 챙기는 것도 잊지 마세요.',
    );

    final baseSlp = AiSectionData(
      emoji: '🛌',
      icon: Icons.nightlight_outlined,
      title: '수면 루틴',
      subtitle: '리듬 고정과 회복의 질 향상',
      badges: const ['취침루틴', '카페인컷오프'],
      categoryScores: const [
        MetricScore('수면시간', 75),
        MetricScore('규칙성', 60),
        MetricScore('회복감', 58),
      ],
      longTip:
          '일관된 기상 시각을 고정하는 것이 수면의 질을 좌우합니다. 아침에는 자연광에 5~10분 노출되어 생체리듬을 리셋하고, 낮 시간에는 과도한 카페인·늦은 낮잠을 피하세요. 취침 2~3시간 전에는 자극적인 콘텐츠와 과식·음주를 줄이고, 30~40분 전부터는 루틴(샤워→조명 낮춤→가벼운 스트레칭→호흡 4-7-8)으로 몸에 “잘 시간” 신호를 보내세요. 침실은 18~20℃의 서늘하고 어두운 환경으로 유지하고, 스마트폰은 침대에서 멀리 두어 각성도를 낮추는 것이 중요합니다. 기상 후 바로 침구를 정리하면 “하루가 시작됐다”는 뇌 신호에 도움이 되며, 수면이 부족했던 날은 낮 시간대 15~20분 파워냅으로 피로를 과하게 끌고 가지 않도록 관리해 주세요.',
    );

    final baseStr = AiSectionData(
      emoji: '🧘',
      icon: Icons.self_improvement,
      title: '스트레스 케어',
      subtitle: '자율신경 안정 & 긴장해소',
      badges: const ['호흡', '스트레칭'],
      categoryScores: const [
        MetricScore('안정감', 55),
        MetricScore('긴장도', 45),
        MetricScore('회복속도', 52),
      ],
      longTip:
          '짧은 시간에도 효과적인 호흡·이완 루틴을 분산 배치하세요. 오전에는 4초 들숨/6초 날숨으로 2분, 점심 전·오후 늦게 각 2분씩 추가해 하루 총 6분의 코히어런스 호흡을 권장합니다. 목·승모근·흉곽 스트레칭을 각 30초씩 2세트, 거북목을 줄이는 벽가슴펴기와 어깨 돌리기를 수시로 넣어 근긴장을 낮추세요. 스크린 타임이 길다면 50분 일 후 5분 휴식 규칙으로 눈·허리 부담을 줄이고, 저녁에는 산책 10분이나 따뜻한 샤워로 체온을 올렸다가 떨어뜨리는 “수면 준비”를 돕는 것도 좋습니다. 감정이 요동칠 땐 생각 기록(3줄 저널링)으로 사고의 속도를 늦추고, 카페인·니코틴·과식으로 해소하려는 패턴을 인지해 대체 행동(물, 심호흡, 스트레칭)으로 치환해 보세요.',
    );

    return AiRecommendationDetailPage(
      condition: baseCond,
      workout: baseWork,
      sleep: baseSlp,
      stress: baseStr,
    );
  }

  @override
  State<AiRecommendationDetailPage> createState() =>
      _AiRecommendationDetailPageState();
}

class _AiRecommendationDetailPageState extends State<AiRecommendationDetailPage>
    with TickerProviderStateMixin {
  late final TabController _tab;
  late Future<_WeeklyBundle> _weekly;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
    _weekly = _loadWeekly();
  }

  Future<_WeeklyBundle> _loadWeekly() async {
    // 서비스 타입 → 화면 타입으로 강제 변환(이름 충돌 방지)
    final rawSteps = await hs.HealthService.getWeeklySteps();
    final steps = rawSteps
        .map((e) => MetricPoint(e.label as String, (e.value as num).toDouble()))
        .toList();

    final rawSleep = await hs.HealthService.getWeeklySleepMinutes();
    final sleep = rawSleep
        .map((e) => MetricPoint(e.label as String, (e.value as num).toDouble()))
        .toList();

    final stressLike = steps;
    return _WeeklyBundle(steps: steps, sleep: sleep, stress: stressLike);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    return FutureBuilder<_WeeklyBundle>(
      future: _weekly,
      builder: (context, snap) {
        final weekly = snap.data;
        final cond = widget.condition.copyWith(
          weeklyTrend: weekly?.steps ?? const [],
        );
        final work = widget.workout.copyWith(
          weeklyTrend: weekly?.steps ?? const [],
        );
        final slp = widget.sleep.copyWith(
          weeklyTrend: weekly?.sleep ?? const [],
        );
        final str = widget.stress.copyWith(
          weeklyTrend: weekly?.stress ?? const [],
        );

        return Scaffold(
          appBar: AppBar(
            title: const Text('AI 추천 상세'),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: _ChipTabBar(controller: _tab),
            ),
          ),
          body: TabBarView(
            controller: _tab,
            children: [
              _SectionView(data: cond, onUpgrade: widget.onUpgrade),
              _SectionView(data: work, onUpgrade: widget.onUpgrade),
              _SectionView(data: slp, onUpgrade: widget.onUpgrade),
              _SectionView(data: str, onUpgrade: widget.onUpgrade),
            ],
          ),
          backgroundColor: t.colorScheme.surface,
        );
      },
    );
  }
}

class _WeeklyBundle {
  final List<MetricPoint> steps;
  final List<MetricPoint> sleep;
  final List<MetricPoint> stress;
  const _WeeklyBundle({
    required this.steps,
    required this.sleep,
    required this.stress,
  });
}

/// 상단 칩 스타일 탭바
class _ChipTabBar extends StatelessWidget {
  const _ChipTabBar({required this.controller});
  final TabController controller;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.only(bottom: 8),
      child: TabBar(
        controller: controller,
        tabs: const [
          Tab(
              child: Center(
                  child: Text('📊  컨디션',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13)))),
          Tab(
              child: Center(
                  child: Text('💪  운동',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13)))),
          Tab(
              child: Center(
                  child: Text('🛌  수면',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13)))),
          Tab(
              child: Center(
                  child: Text('🧘  스트레스',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13)))),
        ],
        isScrollable: false,
        indicator: BoxDecoration(
          color: cs.primary.withOpacity(.08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: cs.primary.withOpacity(.18)),
        ),
        labelPadding: const EdgeInsets.symmetric(horizontal: 6),
        indicatorPadding:
            const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      ),
    );
  }
}

/// 각 섹션 뷰
class _SectionView extends StatelessWidget {
  const _SectionView({required this.data, this.onUpgrade});
  final AiSectionData data;
  final VoidCallback? onUpgrade;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
      children: [
        _Header(
          emoji: data.emoji,
          icon: data.icon,
          title: data.title,
          subtitle: data.subtitle,
          badges: data.badges,
        ),
        const SizedBox(height: 12),

        // 주간 추이(라인)
        _CardWrap(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionTitle(emoji: '📈', title: '주간 추이', subtitle: '최근 변화'),
              const SizedBox(height: 8),
              AspectRatio(
                aspectRatio: 16 / 9,
                child: _LineTrendChart(points: data.weeklyTrend),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 지표 점수(막대)
        _CardWrap(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionTitle(emoji: '📊', title: '지표 점수', subtitle: '한 눈에 보기'),
              const SizedBox(height: 8),
              AspectRatio(
                aspectRatio: 16 / 9,
                child: _BarScoreChart(scores: data.categoryScores),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 긴 팁
        _CardWrap(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionTitle(
                  emoji: '🛠️', title: '바로 적용 가능한 팁', subtitle: '실전 관리 가이드'),
              const SizedBox(height: 8),
              Text(
                data.longTip,
                style: t.textTheme.bodyMedium?.copyWith(height: 1.5),
              ),
            ],
          ),
        ),

        if (onUpgrade != null) ...[
          const SizedBox(height: 16),
          _Upsell(onUpgrade: onUpgrade!),
        ],
      ],
    );
  }
}

/// 헤더
class _Header extends StatelessWidget {
  const _Header({
    required this.emoji,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.badges = const [],
  });

  final String emoji;
  final IconData icon;
  final String title;
  final String subtitle;
  final List<String> badges;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: t.colorScheme.primary.withOpacity(.12),
          child: Text(emoji, style: const TextStyle(fontSize: 20)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                runSpacing: 4,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 18, color: t.colorScheme.primary),
                      const SizedBox(width: 6),
                      Text(
                        title,
                        style: t.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  ...badges.take(3).map(
                        (b) => Chip(
                          visualDensity:
                              const VisualDensity(horizontal: -3, vertical: -3),
                          label: Text(
                            b,
                            style: t.textTheme.labelSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          labelPadding:
                              const EdgeInsets.symmetric(horizontal: 6),
                          padding: EdgeInsets.zero,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          side:
                              BorderSide(color: t.dividerColor.withOpacity(.4)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                          backgroundColor: t.colorScheme.surface,
                        ),
                      ),
                  if (badges.length > 3)
                    Chip(
                      visualDensity:
                          const VisualDensity(horizontal: -3, vertical: -3),
                      label: Text(
                        '+${badges.length - 3}',
                        style: t.textTheme.labelSmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      side: BorderSide(color: t.dividerColor.withOpacity(.4)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                      backgroundColor: t.colorScheme.surface,
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: t.textTheme.bodySmall?.copyWith(
                  color: t.colorScheme.onSurface.withOpacity(.7),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 소제목
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(
      {required this.emoji, required this.title, this.subtitle});
  final String emoji;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: t.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800)),
              if ((subtitle ?? '').isNotEmpty)
                Text(subtitle!,
                    style: t.textTheme.bodySmall?.copyWith(color: t.hintColor)),
            ],
          ),
        ),
      ],
    );
  }
}

/// 공통 카드
class _CardWrap extends StatelessWidget {
  const _CardWrap({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: child,
      ),
    );
  }
}

/// 라인차트
class _LineTrendChart extends StatelessWidget {
  const _LineTrendChart({required this.points});
  final List<MetricPoint> points;

  List<MetricPoint> _normalized(List<MetricPoint> src) {
    if (src.isEmpty) {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day)
          .subtract(const Duration(days: 6));
      return List.generate(7, (i) {
        final d = start.add(Duration(days: i));
        final isToday =
            d.year == now.year && d.month == now.month && d.day == now.day;
        return MetricPoint(isToday ? '오늘' : '${d.month}/${d.day}', 0);
      });
    }
    if (src.length > 7) return src.sublist(src.length - 7);
    if (src.length < 7) {
      final pad = List<MetricPoint>.from(src);
      while (pad.length < 7) {
        pad.insert(0, const MetricPoint('', 0));
      }
      return pad;
    }
    return src;
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final safe = _normalized(points);

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: t.dividerColor.withOpacity(.12),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(
            // ← fl_chart 최신 API 맞춤
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (v, meta) {
                final i = v.toInt();
                if (i < 0 || i >= safe.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(safe[i].label,
                      style: TextStyle(fontSize: 11, color: t.hintColor)),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: (safe.length - 1).toDouble(),
        lineBarsData: [
          LineChartBarData(
            isCurved: true,
            barWidth: 3,
            spots: List.generate(
                safe.length, (i) => FlSpot(i.toDouble(), safe[i].value)),
            color: t.colorScheme.primary,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
                show: true, color: t.colorScheme.primary.withOpacity(.12)),
          ),
        ],
      ),
    );
  }
}

/// 막대차트
class _BarScoreChart extends StatelessWidget {
  const _BarScoreChart({required this.scores});
  final List<MetricScore> scores;

  List<MetricScore> _normalized(List<MetricScore> src) {
    if (src.isNotEmpty) return src;
    return const [
      MetricScore('지표 A', 0),
      MetricScore('지표 B', 0),
      MetricScore('지표 C', 0),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final data = _normalized(scores);
    const maxY = 100.0;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(
            // ← 일관성 유지
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= data.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(data[i].label,
                      style: TextStyle(
                          fontSize: 11, color: Theme.of(context).hintColor)),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, gi, rod, ri) {
              final label = data[gi].label;
              final v = data[gi].value.toStringAsFixed(0);
              return BarTooltipItem(
                  "$label\n$v", const TextStyle(fontWeight: FontWeight.w700));
            },
          ),
        ),
        maxY: maxY,
        barGroups: List.generate(data.length, (i) {
          final v = data[i].value.clamp(0, 100).toDouble();
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: v,
                width: 18,
                borderRadius: BorderRadius.circular(6),
                color: t.colorScheme.primary,
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: maxY,
                  color: t.colorScheme.primary.withOpacity(.12),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

/// 업셀(선택)
class _Upsell extends StatelessWidget {
  const _Upsell({required this.onUpgrade});
  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.colorScheme.primary.withOpacity(.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Text('🚀'),
          const SizedBox(width: 8),
          Expanded(
            child: Text('프리미엄 전환 시 더 깊은 인사이트와 맞춤 루틴이 열립니다.',
                style: t.textTheme.bodySmall),
          ),
          TextButton(onPressed: onUpgrade, child: const Text('업그레이드')),
        ],
      ),
    );
  }
}

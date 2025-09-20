import 'package:flutter/material.dart';
import 'package:god_life_v1/services/ai_service.dart';

class WorkoutTipCard extends StatefulWidget {
  const WorkoutTipCard({
    super.key,
    this.steps,
    this.bmi,
    this.restingHr,
    this.todayWorkType,
  });

  final int? steps;
  final double? bmi;
  final int? restingHr;
  final String? todayWorkType;

  @override
  State<WorkoutTipCard> createState() => _WorkoutTipCardState();
}

class _WorkoutTipCardState extends State<WorkoutTipCard> {
  bool _loading = true;
  String? _summary;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    setState(() => _loading = true);
    try {
      final ai = AIService();
      final prompt = '''
너는 교대근무자의 '피지컬 코치'야.
아래 데이터를 참고해 오늘의 20~30분 루틴을 3단계로 제시해줘.
- 근무: ${widget.todayWorkType ?? '-'}
- 걸음 수: ${widget.steps ?? '-'} 보
- BMI: ${widget.bmi != null ? widget.bmi!.toStringAsFixed(1) : '-'}
- 안정 심박: ${widget.restingHr ?? '-'} bpm
제약: 한국어, 각 단계 한 줄, 강도는 무리 금지(야간/피로 시 저강도).
''';
      final res = (await ai.getResponse(prompt)).trim();
      if (!mounted) return;
      setState(() {
        _summary =
            res.isEmpty ? '가벼운 전신 스트레칭 10분 → 느린 걷기 15분 → 마무리 호흡 5분' : res;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _summary = '운동 팁을 불러오지 못했어요. 잠시 후 다시 시도해 주세요.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openDetail() async {
    try {
      final ai = AIService();
      final prompt = '''
같은 조건에서 오늘의 운동 루틴을 자세히 설명해줘.
- 준비운동(세부 동작/시간)
- 본 운동(세트/반복 또는 분 단위)
- 마무리(스트레칭/호흡)
- 주의사항(야간/피로 고려)
한국어, 불릿으로 간결하게.
''';
      final detail = (await ai.getResponse(prompt)).trim();
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _WorkoutDetailPage(
              text: detail.isEmpty
                  ? '준비운동 5분, 본운동 15분, 마무리 5분으로 구성해 보세요.'
                  : detail),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const _WorkoutDetailPage(text: '잠시 후 다시 시도해 주세요.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _openDetail,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(
                icon: Icons.fitness_center_outlined,
                color: Colors.teal,
                title: '오늘의 운동 팁',
                onRefresh: _loadSummary,
              ),
              const SizedBox(height: 6),
              if (_loading)
                const SizedBox(
                    height: 18, child: LinearProgressIndicator(minHeight: 2))
              else
                Text(
                  _summary ?? '운동 팁을 불러오지 못했어요.',
                  style: const TextStyle(fontSize: 14, height: 1.45),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkoutDetailPage extends StatelessWidget {
  const _WorkoutDetailPage({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('운동 루틴')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Text(text, style: const TextStyle(fontSize: 16, height: 1.55)),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.icon,
    required this.color,
    required this.title,
    this.onRefresh,
  });

  final IconData icon;
  final Color color;
  final String title;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w800,
          fontSize: 16,
        );
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(title, style: titleStyle)),
        if (onRefresh != null)
          IconButton(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh, size: 18),
            splashRadius: 16,
            tooltip: '새로고침',
          ),
      ],
    );
  }
}

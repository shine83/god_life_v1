import 'package:flutter/material.dart';
import 'package:god_life_v1/services/ai_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HealthTipCard extends StatefulWidget {
  const HealthTipCard({
    super.key,
    this.todayType,
    this.yesterdayType,
  });

  final String? todayType;
  final String? yesterdayType;

  @override
  State<HealthTipCard> createState() => _HealthTipCardState();
}

class _HealthTipCardState extends State<HealthTipCard> {
  String? _summary;
  bool _loading = true;

  int? _steps;
  double? _sleepHours;
  int? _hr;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _loadHealthSnapshot();
    await _loadSummary();
  }

  Future<void> _loadHealthSnapshot() async {
    final prefs = await SharedPreferences.getInstance();
    final steps = prefs.getInt('health_steps');
    final sleepMin = prefs.getDouble('health_sleepMinutes');
    final hr = prefs.getInt('health_heartRate');
    if (!mounted) return;
    setState(() {
      _steps = steps;
      _sleepHours =
          (sleepMin != null && sleepMin > 0) ? (sleepMin / 60.0) : null;
      _hr = hr;
    });
  }

  Future<void> _loadSummary() async {
    setState(() => _loading = true);
    try {
      final ai = AIService();
      final prompt = '''
너는 교대근무자의 건강 큐레이터야.
아래 정보를 참고해 한국어로 2문장 내로 현실적인 건강 팁을 제시해.
- 오늘 근무: ${widget.todayType ?? '-'}
- 어제 근무: ${widget.yesterdayType ?? '-'}
- 걸음 수: ${_steps ?? '-'} 보
- 수면: ${_sleepHours != null ? '${_sleepHours!.toStringAsFixed(1)}시간' : '-'}
- 심박수(안정): ${_hr ?? '-'} bpm
제약: 과장된 표현 금지, 식습관/수면/가벼운 활동 중심, 이모지 1개 이내.
''';
      final text = (await ai.getResponse(prompt)).trim();
      if (!mounted) return;
      setState(() {
        _summary = text.isEmpty ? '오늘도 무리하지 말고 작은 실천 하나면 충분해요.' : text;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _summary = '건강 팁을 불러오지 못했어요. 잠시 후 다시 시도해 주세요.';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openDetail() async {
    try {
      final ai = AIService();
      final prompt = '''
너는 교대근무자의 건강 코치야.
아래 데이터를 바탕으로 오늘 하루를 위한 간단 체크리스트(불릿 4~5개)를 작성해줘.
- 오늘 근무: ${widget.todayType ?? '-'}
- 어제 근무: ${widget.yesterdayType ?? '-'}
- 걸음 수: ${_steps ?? '-'} 보
- 수면: ${_sleepHours != null ? '${_sleepHours!.toStringAsFixed(1)}시간' : '-'}
- 심박수(안정): ${_hr ?? '-'} bpm
제약: 문장 짧게, 실천 가능하게, 한국어.
''';
      final detail = (await ai.getResponse(prompt)).trim();
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _HealthTipDetailPage(
              text: detail.isEmpty ? '오늘은 물 충분히 마시고 가벼운 스트레칭부터 시작해요.' : detail),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const _HealthTipDetailPage(text: '잠시 후 다시 시도해 주세요.'),
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
                icon: Icons.health_and_safety_outlined,
                color: Colors.purple,
                title: '오늘의 건강 팁',
                onRefresh: _loadSummary,
              ),
              const SizedBox(height: 6),
              if (_loading)
                const SizedBox(
                    height: 18, child: LinearProgressIndicator(minHeight: 2))
              else
                Text(
                  _summary ?? '건강 팁을 불러오지 못했어요.',
                  style: const TextStyle(fontSize: 14, height: 1.45),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HealthTipDetailPage extends StatelessWidget {
  const _HealthTipDetailPage({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('건강 팁')),
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

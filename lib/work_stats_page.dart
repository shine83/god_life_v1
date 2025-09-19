// lib/work_stats_page.dart
import 'package:flutter/material.dart';
import 'package:my_new_test_app/services/work_schedule_service.dart';
import 'package:intl/intl.dart';

class WorkStatsPage extends StatefulWidget {
  const WorkStatsPage({super.key});

  @override
  State<WorkStatsPage> createState() => _WorkStatsPageState();
}

class _WorkStatsPageState extends State<WorkStatsPage> {
  final _svc = WorkScheduleService();

  bool _loading = true;
  List<Map<String, dynamic>> _rows = [];

  // 간단 통계
  int _totalCount = 0;
  double _totalNightHours = 0.0;
  Map<String, int> _byCodeCount = {}; // code/abbreviation 별 갯수
  DateTime _rangeStart = DateTime.now();
  DateTime _rangeEnd = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadStatsForThisMonth();
  }

  Future<void> _loadStatsForThisMonth() async {
    final now = DateTime.now();
    final first = DateTime(now.year, now.month, 1);
    final last = DateTime(now.year, now.month + 1, 0);
    final endOfLast = DateTime(last.year, last.month, last.day, 23, 59, 59);
    await _loadStats(start: first, end: endOfLast);
  }

  Future<void> _loadStats(
      {required DateTime start, required DateTime end}) async {
    setState(() {
      _loading = true;
      _rangeStart = start;
      _rangeEnd = end;
    });

    try {
      final rows = await _svc.getWorkSchedules(start: start, end: end);

      // 통계 집계
      final int total = rows.length;
      double night = 0.0;
      final byCode = <String, int>{};

      for (final r in rows) {
        // night_hours
        final nh = (r['night_hours'] is num)
            ? (r['night_hours'] as num).toDouble()
            : (double.tryParse('${r['night_hours']}') ?? 0.0);
        night += nh;

        // code 또는 abbreviation
        final code = (r['abbreviation'] ?? r['code'] ?? '').toString();
        if (code.isNotEmpty) {
          byCode.update(code, (v) => v + 1, ifAbsent: () => 1);
        }
      }

      setState(() {
        _rows = rows;
        _totalCount = total;
        _totalNightHours = night;
        _byCodeCount = byCode;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('통계 불러오기 실패: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(start: _rangeStart, end: _rangeEnd),
      helpText: '통계 범위 선택',
    );
    if (picked == null) return;

    // 끝 날짜는 23:59:59로 보정
    final endOfDay = DateTime(
      picked.end.year,
      picked.end.month,
      picked.end.day,
      23,
      59,
      59,
    );
    await _loadStats(start: picked.start, end: endOfDay);
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('yyyy.MM.dd');

    return Scaffold(
      appBar: AppBar(
        title: const Text('근무 통계'),
        actions: [
          IconButton(
            tooltip: '범위 선택',
            onPressed: _pickRange,
            icon: const Icon(Icons.date_range),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                // 기간 요약
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    child: Row(
                      children: [
                        const Icon(Icons.timeline),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${df.format(_rangeStart)} ~ ${df.format(_rangeEnd)}',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _pickRange,
                          icon: const Icon(Icons.edit_calendar, size: 18),
                          label: const Text('변경'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // 요약 카드
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: Row(
                      children: [
                        _StatTile(label: '총 일정', value: '$_totalCount'),
                        _DividerV(),
                        _StatTile(
                          label: '야간 합계',
                          value: '${_totalNightHours.toStringAsFixed(1)}h',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // 코드별 카운트
                if (_byCodeCount.isNotEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('근무 유형별 빈도',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 10,
                            runSpacing: 8,
                            children: _byCodeCount.entries.map((e) {
                              return Chip(
                                label: Text('${e.key}  ${e.value}회'),
                                visualDensity: VisualDensity.compact,
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 12),

                // 원자료 리스트 (간단 표시)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                    child: Column(
                      children: [
                        const ListTile(
                          dense: true,
                          title: Text('상세 목록',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w700)),
                        ),
                        const Divider(height: 0),
                        for (final r in _rows) _rowTile(r),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _rowTile(Map<String, dynamic> r) {
    // title, start_date, abbreviation, night_hours
    final title = (r['title'] ?? '').toString();
    final code = (r['abbreviation'] ?? r['code'] ?? '').toString();
    final night = (r['night_hours'] is num)
        ? (r['night_hours'] as num).toDouble()
        : (double.tryParse('${r['night_hours']}') ?? 0.0);

    String dateLabel = '';
    final sd = (r['start_date'] ?? r['date'])?.toString();
    if (sd != null) {
      final dt = DateTime.tryParse(sd);
      if (dt != null) {
        dateLabel = DateFormat('yyyy.MM.dd').format(dt);
      } else if (sd.length >= 10) {
        dateLabel = sd.substring(0, 10).replaceAll('-', '.');
      }
    }

    return ListTile(
      dense: true,
      leading: const Icon(Icons.event_note),
      title: Text(title.isEmpty ? (code.isEmpty ? '근무' : code) : title),
      subtitle: Text('$dateLabel  ${code.isNotEmpty ? '[$code] ' : ''}'
          '${night > 0 ? '  야간 ${night.toStringAsFixed(1)}h' : ''}'),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  const _StatTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(label,
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7))),
          const SizedBox(height: 4),
          Text(value,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _DividerV extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 36,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: Theme.of(context).dividerColor.withOpacity(0.6),
    );
  }
}

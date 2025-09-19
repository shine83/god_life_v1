// lib/dev/notification_lab_page.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:my_new_test_app/services/notification_service.dart';
// ✨ 프리미엄 상태
import 'package:my_new_test_app/core/premium/premium_gate_compat.dart';

class NotificationLabPage extends StatefulWidget {
  const NotificationLabPage({super.key});

  @override
  State<NotificationLabPage> createState() => _NotificationLabPageState();
}

class _NotificationLabPageState extends State<NotificationLabPage> {
  bool _enabled = true;
  List<int> _offsets = const [60, 30]; // 무료 기본
  bool _loading = false;
  bool _isPremium = false; // ✨ 프리미엄 여부

  // UI 상태
  List<PendingNotificationRequest> _pending = [];
  final _shiftTitleCtrl = TextEditingController(text: '예시 근무');
  DateTime _fakeShiftStart = DateTime.now().add(const Duration(minutes: 65));

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() => _loading = true);
    try {
      _isPremium = await PremiumGateCompat.effectivePremium();
      await NotificationService.I.init();
      final enabled = await NotificationService.I.isEnabled();
      final offsets = await NotificationService.I.getOffsets();
      setState(() {
        _enabled = enabled;
        _offsets = offsets;
      });
      await _refreshPending();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refreshPending() async {
    final list = await NotificationService.I.debugPending();
    if (!mounted) return;
    setState(() => _pending = list);
  }

  Future<void> _requestPermissions() async {
    final ok = await NotificationService.I.requestPermissionsIfNeeded();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? '알림 권한 OK' : '알림 권한 거절됨 또는 미지원')),
    );
  }

  Future<void> _openExactAlarmSettings() async {
    if (Platform.isAndroid) {
      await NotificationService.I.openExactAlarmSettingsIfNeeded();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('iOS에서는 해당 설정이 없습니다.')),
      );
    }
  }

  Future<void> _toggleEnabled(bool v) async {
    await NotificationService.I.setEnabled(v);
    if (!mounted) return;
    setState(() => _enabled = v);
  }

  Future<void> _saveOffsets(List<int> minutes) async {
    await NotificationService.I.setOffsets(minutes);
    if (!mounted) return;
    final enforced = await NotificationService.I.getOffsets(); // 정책 반영본 재로딩
    setState(() => _offsets = enforced);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('오프셋 저장됨: ${enforced.join(", ")} 분 전')),
    );
  }

  Future<void> _testNotify({required bool alarm}) async {
    // 무료는 전면 알람 버튼 비활성화 되어 호출되지 않지만, 혹시 대비
    await NotificationService.I.scheduleTestIn10s(alarmStyle: alarm);
    await _refreshPending();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(alarm ? '10초 뒤 전면 알람 예약 완료' : '10초 뒤 알림 예약 완료')),
    );
  }

  Future<void> _scheduleFakeShift() async {
    final id = 'DEV_SHIFT_${_fakeShiftStart.millisecondsSinceEpoch}';
    await NotificationService.I.scheduleForShift(
      scheduleId: id,
      startDateTimeLocal: _fakeShiftStart,
      title: _shiftTitleCtrl.text.trim().isEmpty
          ? '근무'
          : _shiftTitleCtrl.text.trim(),
      // alarmStyle: null → 서비스가 프리미엄 정책대로 결정
    );
    await _refreshPending();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('근무 알림 예약 완료 (${_offsets.join(", ")}분 전)')),
    );
  }

  Future<void> _cancelAll() async {
    // 안전하게 모두 삭제
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.cancelAll();
    await _refreshPending();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('대기 중 알림 모두 취소됨')),
    );
  }

  Future<void> _pickFakeShiftTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _fakeShiftStart,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_fakeShiftStart),
    );
    if (time == null) return;

    final dt = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() => _fakeShiftStart = dt);
  }

  @override
  void dispose() {
    _shiftTitleCtrl.dispose();
    super.dispose();
  }

  // ───────────────── UI ─────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Lab'),
        actions: [
          IconButton(
            tooltip: '새로고침',
            onPressed: _loading ? null : _bootstrap,
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _sectionCard(
            title: '권한',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: _requestPermissions,
                  icon: const Icon(Icons.notifications_active),
                  label: const Text('알림 권한 요청'),
                ),
                ElevatedButton.icon(
                  onPressed: _openExactAlarmSettings,
                  icon: const Icon(Icons.alarm_on),
                  label: const Text('정확 알람 설정 열기 (Android)'),
                ),
              ],
            ),
          ),
          _sectionCard(
            title: '마스터 스위치',
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('알림 사용'),
                Switch(
                  value: _enabled,
                  onChanged: (v) => _toggleEnabled(v),
                ),
              ],
            ),
          ),
          _sectionCard(
            title: _isPremium ? '오프셋(분 전) 설정 · 프리미엄' : '오프셋(분 전) 설정 · 무료',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _buildOffsetChips(isPremium: _isPremium),
                ),
                const SizedBox(height: 8),
                if (_isPremium)
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () async {
                          final m = await _askCustomOffset(context);
                          if (m == null) return;
                          final next = {..._offsets, m}.toList()
                            ..sort((a, b) => b.compareTo(a));
                          _saveOffsets(next);
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('커스텀 추가'),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '최대 10개까지 저장됩니다.',
                        style: TextStyle(color: cs.outline),
                      ),
                    ],
                  )
                else
                  Text(
                    '무료: 60분/30분만 설정할 수 있어요. (프리미엄에서 자유 설정 가능)',
                    style: TextStyle(color: cs.outline),
                  ),
                const SizedBox(height: 8),
                Text(
                  '현재: ${_offsets.join(", ")}분 전',
                  style: TextStyle(color: cs.primary),
                ),
              ],
            ),
          ),
          _sectionCard(
            title: '퀵 테스트',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _testNotify(alarm: false),
                  icon: const Icon(Icons.timelapse),
                  label: const Text('10초 뒤 알림'),
                ),
                OutlinedButton.icon(
                  onPressed: _isPremium ? () => _testNotify(alarm: true) : null,
                  icon: const Icon(Icons.emergency_share),
                  label: const Text('10초 뒤 전면 알람(프리미엄)'),
                ),
              ],
            ),
          ),
          _sectionCard(
            title: '가짜 근무 예약',
            child: Column(
              children: [
                TextField(
                  controller: _shiftTitleCtrl,
                  decoration: const InputDecoration(
                    labelText: '근무 제목',
                    hintText: '예) 조간 근무',
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '근무 시작: ${_formatDateTime(_fakeShiftStart)}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _pickFakeShiftTime,
                      icon: const Icon(Icons.edit_calendar),
                      label: const Text('시간 선택'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _scheduleFakeShift,
                        icon: const Icon(Icons.schedule),
                        label: const Text('오프셋대로 예약'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _fakeShiftStart =
                                DateTime.now().add(const Duration(minutes: 1));
                          });
                          _scheduleFakeShift();
                        },
                        icon: const Icon(Icons.flash_on),
                        label: const Text('1분 뒤 시작으로 예약'),
                      ),
                    ],
                  ),
                ),
                if (!_isPremium)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '무료: 전면/잠금화면 알람은 제공되지 않아요. (프리미엄에서 자동 활성화)',
                      style: TextStyle(color: cs.outline),
                    ),
                  ),
              ],
            ),
          ),
          _sectionCard(
            title: '대기 중 알림',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _refreshPending,
                      icon: const Icon(Icons.list_alt),
                      label: const Text('목록 새로고침'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _cancelAll,
                      icon: const Icon(Icons.cancel_schedule_send),
                      label: const Text('모두 취소'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_pending.isEmpty)
                  const Text('대기 중인 알림이 없습니다.')
                else
                  Column(
                    children: _pending
                        .map((p) => ListTile(
                              dense: true,
                              title: Text(
                                '#${p.id}  ${p.title ?? "(제목 없음)"}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(p.body ?? ''),
                              trailing: Text(
                                p.payload ?? '',
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontSize: 12,
                                ),
                              ),
                            ))
                        .toList(),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '• Android 12+에서 정확 알람 권한이 없으면 Inexact로 폴백합니다.\n'
            '• 무료: 60/30분만 설정 가능 · 전면/잠금화면 알람 미제공\n'
            '• 프리미엄: 자유 오프셋, 전면/잠금화면 알람, 정확 알람 우선',
            style: TextStyle(color: Colors.grey.shade700, height: 1.4),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ───────── helpers ─────────

  List<Widget> _buildOffsetChips({required bool isPremium}) {
    final presets =
        isPremium ? const [120, 90, 60, 45, 30, 20, 15, 10, 5] : const [60, 30];
    final sel = {..._offsets};
    return [
      ...presets.map((m) {
        final selected = sel.contains(m);
        return FilterChip(
          label: Text('$m분 전'),
          selected: selected,
          onSelected: (on) {
            final next = {...sel};
            if (on) {
              next.add(m);
            } else {
              next.remove(m);
            }
            final list = next.toList()..sort((a, b) => b.compareTo(a));
            _saveOffsets(list);
          },
        );
      }),
      if (isPremium)
        ActionChip(
          label: const Text('초기화 (60,30,10)'),
          onPressed: () => _saveOffsets([60, 30, 10]),
        )
      else
        ActionChip(
          label: const Text('초기화 (60,30)'),
          onPressed: () => _saveOffsets([60, 30]),
        ),
    ];
  }

  Future<int?> _askCustomOffset(BuildContext context) async {
    final ctrl = TextEditingController();
    final v = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('커스텀 오프셋 추가'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            hintText: '분(예: 75)',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          TextButton(
            onPressed: () {
              final m = int.tryParse(ctrl.text.trim());
              Navigator.pop(ctx, (m != null && m > 0) ? m : null);
            },
            child: const Text('추가'),
          ),
        ],
      ),
    );
    return v;
  }

  String _two(int n) => n < 10 ? '0$n' : '$n';

  String _formatDateTime(DateTime dt) {
    final y = dt.year;
    final m = _two(dt.month);
    final d = _two(dt.day);
    final hh = _two(dt.hour);
    final mm = _two(dt.minute);
    return '$y-$m-$d $hh:$mm';
  }
}

// ── 공용 섹션 카드
Widget _sectionCard({required String title, required Widget child}) {
  return Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          child,
        ],
      ),
    ),
  );
}

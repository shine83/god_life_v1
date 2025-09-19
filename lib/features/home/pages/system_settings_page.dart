// lib/features/home/pages/system_settings_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_new_test_app/features/settings/notification_settings_page.dart';
import 'package:my_new_test_app/providers/app_settings_provider.dart';

class SystemSettingsPage extends ConsumerWidget {
  const SystemSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appSettingsProvider);
    final n = ref.read(appSettingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('시스템 설정')),
      body: ListView(
        children: [
          // ───────────────── 화면 & 표시 ─────────────────
          const _SectionHeader('화면 & 표시'),
          ListTile(
            leading: const Icon(Icons.dark_mode_outlined),
            title: const Text('테마 모드'),
            subtitle: Text(_themeLabel(s.themeMode)),
            onTap: () => _pickTheme(context, n, s.themeMode),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.access_time),
            title: const Text('24시간제 시계'),
            value: s.use24hClock,
            onChanged: n.setUse24h,
          ),
          ListTile(
            leading: const Icon(Icons.calendar_view_month),
            title: const Text('요일 시작'),
            subtitle: Text(s.weekStart == 'mon' ? '월요일' : '일요일'),
            onTap: () => _pickWeekStart(context, n, s.weekStart),
          ),

          // ───────────────── 동기화 & 실시간 ─────────────────
          const _SectionHeader('동기화 & 실시간'),
          SwitchListTile(
            secondary: const Icon(Icons.bolt_outlined),
            title: const Text('실시간 업데이트 사용'),
            value: s.realtimeEnabled,
            onChanged: n.setRealtime,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.network_cell),
            title: const Text('모바일 데이터 사용 허용'),
            value: s.allowCellularSync,
            onChanged: n.setCellular,
          ),

          // ───────────────── 개인정보 & 보안 ─────────────────
          const _SectionHeader('개인정보 & 보안'),
          ListTile(
            leading: const Icon(Icons.visibility_outlined),
            title: const Text('근무 공개 범위'),
            subtitle: Text(_visLabel(s.shareWorkVisibility)),
            onTap: () => _pickVisibility(
              context,
              '근무 공개 범위',
              s.shareWorkVisibility,
              (v) => n.setShareWork(v),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.sticky_note_2_outlined),
            title: const Text('메모 공개 범위'),
            subtitle: Text(_visLabel(s.shareMemoVisibility)),
            onTap: () => _pickVisibility(
              context,
              '메모 공개 범위',
              s.shareMemoVisibility,
              (v) => n.setShareMemo(v),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('프로필 공개 범위'),
            subtitle: Text(_visLabel(s.shareProfileVisibility)),
            onTap: () => _pickVisibility(
              context,
              '프로필 공개 범위',
              s.shareProfileVisibility,
              (v) => n.setShareProfile(v),
            ),
          ),
        ],
      ),
    );
  }

  String _themeLabel(ThemeMode m) =>
      m == ThemeMode.light ? '라이트' : (m == ThemeMode.dark ? '다크' : '시스템');

  String _visLabel(String v) =>
      v == 'public' ? '전체 공개' : (v == 'friends' ? '친구만' : '비공개');

  Future<void> _pickTheme(
    BuildContext ctx,
    AppSettingsNotifier n,
    ThemeMode cur,
  ) async {
    final picked = await showModalBottomSheet<ThemeMode>(
      context: ctx,
      builder: (_) => _PickerSheet<ThemeMode>(
        title: '테마 모드',
        items: const [
          _Item('시스템', ThemeMode.system),
          _Item('라이트', ThemeMode.light),
          _Item('다크', ThemeMode.dark),
        ],
        current: cur,
      ),
    );
    if (picked != null) await n.setThemeMode(picked);
  }

  Future<void> _pickWeekStart(
    BuildContext ctx,
    AppSettingsNotifier n,
    String cur,
  ) async {
    final picked = await showModalBottomSheet<String>(
      context: ctx,
      builder: (_) => _PickerSheet<String>(
        title: '요일 시작',
        items: const [_Item('월요일', 'mon'), _Item('일요일', 'sun')],
        current: cur,
      ),
    );
    if (picked != null) await n.setWeekStart(picked);
  }

  Future<void> _pickVisibility(
    BuildContext ctx,
    String title,
    String cur,
    Future<void> Function(String) onPick,
  ) async {
    final picked = await showModalBottomSheet<String>(
      context: ctx,
      builder: (_) => _PickerSheet<String>(
        title: title,
        items: const [
          _Item('전체 공개', 'public'),
          _Item('친구만', 'friends'),
          _Item('비공개', 'private'),
        ],
        current: cur,
      ),
    );
    if (picked != null) await onPick(picked);
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _PickerSheet<T> extends StatelessWidget {
  const _PickerSheet({
    required this.title,
    required this.items,
    required this.current,
  });
  final String title;
  final List<_Item<T>> items;
  final T current;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
        ...items.map((e) => RadioListTile<T>(
              value: e.value,
              groupValue: current,
              onChanged: (v) => Navigator.pop(context, v),
              title: Text(e.label),
            )),
        const SizedBox(height: 8),
      ]),
    );
  }
}

class _Item<T> {
  final String label;
  final T value;
  const _Item(this.label, this.value);
}

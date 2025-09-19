import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_new_test_app/core/theme/theme_controller.dart';

class ThemeModeSettingsPage extends ConsumerWidget {
  const ThemeModeSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final ctrl = ref.read(themeModeProvider.notifier);

    void set(ThemeMode m) {
      ctrl.setTheme(m);
      // 적용 즉시 확인 가능. 뒤로 가도 유지됨.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_label(m)} 적용')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('테마 모드')),
      body: ListView(
        children: [
          RadioListTile<ThemeMode>(
            value: ThemeMode.system,
            groupValue: mode,
            onChanged: (v) => set(ThemeMode.system),
            title: const Text('시스템 설정에 따름'),
            subtitle: const Text('기기 다크모드 여부를 따릅니다'),
          ),
          const Divider(height: 0),
          RadioListTile<ThemeMode>(
            value: ThemeMode.light,
            groupValue: mode,
            onChanged: (v) => set(ThemeMode.light),
            title: const Text('라이트 모드'),
          ),
          const Divider(height: 0),
          RadioListTile<ThemeMode>(
            value: ThemeMode.dark,
            groupValue: mode,
            onChanged: (v) => set(ThemeMode.dark),
            title: const Text('다크 모드'),
          ),
        ],
      ),
    );
  }

  String _label(ThemeMode m) => switch (m) {
        ThemeMode.system => '시스템 모드',
        ThemeMode.light => '라이트 모드',
        ThemeMode.dark => '다크 모드',
      };
}

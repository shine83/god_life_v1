import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ShareSettingsPage extends StatefulWidget {
  const ShareSettingsPage({super.key});

  @override
  State<ShareSettingsPage> createState() => _ShareSettingsPageState();
}

class _ShareSettingsPageState extends State<ShareSettingsPage> {
  bool shareCalendar = false;
  bool shareMemo = false;
  bool isLoading = true;

  final user = Supabase.instance.client.auth.currentUser;
  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadShareSettings();
  }

  // 🔄 공유 설정 불러오기
  Future<void> _loadShareSettings() async {
    if (user == null) return;

    final res = await supabase
        .from('share_settings')
        .select()
        .eq('user_id', user!.id)
        .maybeSingle();

    if (res != null) {
      setState(() {
        shareCalendar = res['share_calendar'] ?? false;
        shareMemo = res['share_memo'] ?? false;
      });
    }

    setState(() => isLoading = false);
  }

  // 💾 저장
  Future<void> _saveSettings() async {
    if (user == null) return;

    await supabase.from('share_settings').upsert({
      'user_id': user!.id,
      'share_calendar': shareCalendar,
      'share_memo': shareMemo,
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('공유 설정이 저장되었습니다.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('공유 설정'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveSettings,
            tooltip: '저장',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔑 내 공유 ID 표시
            Text(
              '내 공유 ID',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            SelectableText(
              user?.id ?? '로그인 필요',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 24),

            // ☑️ 공유 항목 체크박스
            Text(
              '공유할 항목 선택',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              value: shareCalendar,
              onChanged: (val) {
                setState(() {
                  shareCalendar = val ?? false;
                });
              },
              title: const Text('캘린더 일정 공유'),
            ),
            CheckboxListTile(
              value: shareMemo,
              onChanged: (val) {
                setState(() {
                  shareMemo = val ?? false;
                });
              },
              title: const Text('메모 공유'),
            ),
          ],
        ),
      ),
    );
  }
}

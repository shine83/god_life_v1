import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ← 복사 기능을 위해 추가
import 'package:supabase_flutter/supabase_flutter.dart';

class ShareManagePage extends StatefulWidget {
  const ShareManagePage({super.key});

  @override
  State<ShareManagePage> createState() => _ShareManagePageState();
}

class _ShareManagePageState extends State<ShareManagePage> {
  final user = Supabase.instance.client.auth.currentUser;
  final supabase = Supabase.instance.client;

  bool isLoading = true;
  bool shareCalendar = false;
  bool shareMemos = false;

  @override
  void initState() {
    super.initState();
    _loadShareSettings();
  }

  Future<void> _loadShareSettings() async {
    if (user == null) {
      setState(() => isLoading = false);
      return;
    }

    try {
      final res = await supabase
          .from('share_settings')
          .select()
          .eq('user_id', user!.id)
          .maybeSingle();

      if (res != null) {
        shareCalendar = res['share_calendar'] ?? false;
        shareMemos = res['share_memos'] ?? false;
      }
    } catch (e) {
      debugPrint('공유 설정 불러오기 오류: $e');
    }

    setState(() => isLoading = false);
  }

  Future<void> _updateShareSetting(String field, bool value) async {
    if (user == null) return;

    try {
      await supabase.from('share_settings').upsert({
        'user_id': user!.id,
        'share_calendar': field == 'share_calendar' ? value : shareCalendar,
        'share_memos': field == 'share_memos' ? value : shareMemos,
      });
    } catch (e) {
      debugPrint('공유 설정 업데이트 오류: $e');
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
      appBar: AppBar(title: const Text('공유 관리')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: user == null
            ? const Center(child: Text('로그인이 필요합니다'))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '내 공유 ID',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: SelectableText(
                          user!.id,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy),
                        tooltip: '복사',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: user!.id));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('공유 ID가 복사되었습니다')),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '공유 중인 항목',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    value: shareCalendar,
                    title: const Text('📅 캘린더'),
                    onChanged: (val) async {
                      if (val == null) return;
                      setState(() => shareCalendar = val);
                      await _updateShareSetting('share_calendar', val);
                    },
                  ),
                  CheckboxListTile(
                    value: shareMemos,
                    title: const Text('📝 메모'),
                    onChanged: (val) async {
                      if (val == null) return;
                      setState(() => shareMemos = val);
                      await _updateShareSetting('share_memos', val);
                    },
                  ),
                ],
              ),
      ),
    );
  }
}

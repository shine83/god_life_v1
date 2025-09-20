import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:god_life_v1/features/authentication/pages/login_page.dart';
import 'package:god_life_v1/features/home/pages/home_page.dart';
import 'package:god_life_v1/providers/tutorial_provider.dart';
import 'package:god_life_v1/services/work_schedule_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ✨ [수정] ConsumerStatefulWidget으로 변경하여 Riverpod(ref)에 접근합니다.
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final _svc = WorkScheduleService();
  bool _isLoading = false;

  final Map<String, List<Map<String, dynamic>>> _presets = {
    '간호사 (3교대)': [
      {
        'name': '데이',
        'code': 'D',
        'color': 0xFF3498DB,
        'start_time': '07:00:00',
        'end_time': '15:00:00'
      },
      {
        'name': '이브닝',
        'code': 'E',
        'color': 0xFFE67E22,
        'start_time': '15:00:00',
        'end_time': '23:00:00'
      },
      {
        'name': '나이트',
        'code': 'N',
        'color': 0xFF34495E,
        'start_time': '23:00:00',
        'end_time': '07:00:00'
      },
      {
        'name': '오프',
        'code': 'O',
        'color': 0xFF95A5A6,
        'start_time': '00:00:00',
        'end_time': '00:00:00'
      },
    ],
    '소방/경찰': [
      {
        'name': '주간',
        'code': '주',
        'color': 0xFF2ECC71,
        'start_time': '09:00:00',
        'end_time': '18:00:00'
      },
      {
        'name': '야간',
        'code': '야',
        'color': 0xFF34495E,
        'start_time': '18:00:00',
        'end_time': '09:00:00'
      },
      {
        'name': '비번',
        'code': '비',
        'color': 0xFF9B59B6,
        'start_time': '00:00:00',
        'end_time': '00:00:00'
      },
      {
        'name': '휴무',
        'code': '휴',
        'color': 0xFF95A5A6,
        'start_time': '00:00:00',
        'end_time': '00:00:00'
      },
    ],
    '생산/제조 (4조 2교대)': [
      {
        'name': '주간',
        'code': '주',
        'color': 0xFF27AE60,
        'start_time': '08:00:00',
        'end_time': '20:00:00'
      },
      {
        'name': '야간',
        'code': '야',
        'color': 0xFF2C3E50,
        'start_time': '20:00:00',
        'end_time': '08:00:00'
      },
      {
        'name': '휴무',
        'code': '휴',
        'color': 0xFF95A5A6,
        'start_time': '00:00:00',
        'end_time': '00:00:00'
      },
    ],
  };

  Future<void> _selectPreset(String? job) async {
    setState(() => _isLoading = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('오류: 사용자 정보가 없습니다. 다시 로그인해주세요.')),
          );
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginPage()),
            (route) => false,
          );
        }
        return;
      }

      if (job != null && _presets.containsKey(job)) {
        await _svc.upsertShiftTypesForUser(userId, _presets[job]!);
      }

      if (mounted) {
        // ✨ [수정] HomePage로 이동하기 직전에 Provider 상태를 변경합니다.
        // 1. 캘린더 탭(인덱스 1)으로 바로 이동하라는 신호
        ref.read(mainTabIndexProvider.notifier).state = 1;
        // 2. 캘린더 튜토리얼을 시작하라는 신호 (신규 사용자이므로)
        ref.read(calendarTutorialRequestProvider.notifier).state = true;

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomePage()),
        );
      }
    } catch (e) {
      print('프리셋 선택 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류가 발생했습니다: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '갓생살기에 오신 것을 환영합니다!',
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '더 빠른 시작을 위해, 직업군을 선택해주세요.\n나중에 언제든지 직접 수정할 수 있습니다.',
                      style:
                          TextStyle(fontSize: 16, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 32),
                    Expanded(
                      child: ListView(
                        children: [
                          ..._presets.keys
                              .map((job) => _buildJobCard(job, Icons.work)),
                          const SizedBox(height: 16),
                          _buildJobCard('직접 입력하기', Icons.edit, isManual: true),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildJobCard(String jobTitle, IconData icon,
      {bool isManual = false}) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading:
            Icon(icon, size: 32, color: Theme.of(context).colorScheme.primary),
        title:
            Text(jobTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: isManual ? const Text('모든 근무 유형을 직접 설정합니다.') : null,
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _selectPreset(isManual ? null : jobTitle),
      ),
    );
  }
}

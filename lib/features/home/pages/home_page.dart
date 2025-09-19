import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_new_test_app/features/ai/pages/ai_hub_page.dart';
import 'package:my_new_test_app/features/authentication/pages/login_page.dart';
import 'package:my_new_test_app/features/authentication/viewmodel/auth_viewmodel.dart'; // ✅ 누락되었던 import
import 'package:my_new_test_app/features/home/pages/community_page.dart';
import 'package:my_new_test_app/features/home/pages/settings_page.dart';
import 'package:my_new_test_app/features/home/pages/share_page.dart';
import 'package:my_new_test_app/features/work_schedule/page/work_schedule_page.dart';
import 'package:my_new_test_app/providers/tutorial_provider.dart';
import 'package:my_new_test_app/services/ai_service.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(mainTabIndexProvider);

    final pages = <Widget>[
      const _HomeLanding(),
      const WorkSchedulePage(),
      const AiHubPage(),
      const SharePage(),
      const CommunityPage(),
      const SettingsPage(),
    ];

    return Scaffold(
      body: IndexedStack(index: currentIndex, children: pages),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: currentIndex,
        onTap: (i) => ref.read(mainTabIndexProvider.notifier).state = i,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: '홈'),
          BottomNavigationBarItem(
              icon: Icon(Icons.calendar_month_outlined), label: '캘린더'),
          BottomNavigationBarItem(icon: Icon(Icons.auto_awesome), label: 'AI'),
          BottomNavigationBarItem(
              icon: Icon(Icons.group_outlined), label: '공유'),
          BottomNavigationBarItem(
              icon: Icon(Icons.forum_outlined), label: '커뮤니티'),
          BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined), label: '설정'),
        ],
      ),
    );
  }
}

// ... (_HomeLanding, _TodayQuoteCard 위젯은 기존과 동일) ...
class _HomeLanding extends ConsumerWidget {
  const _HomeLanding();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final authState =
        ref.watch(authViewModelProvider); // ✅ 이 부분을 위해 import가 필요했습니다.
    final user = authState.asData?.value;
    final screenH = MediaQuery.of(context).size.height;
    final imageH = (screenH * 0.45).clamp(240, 520).toDouble();

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('갓생살기',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('일정 관리로 지키는 건강, 공유로 이어지는 관계',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.3,
                    color: theme.colorScheme.onSurface.withOpacity(0.7))),
            const SizedBox(height: 18),
            SizedBox(
              height: imageH,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.asset('assets/images/home_illustration.png',
                    fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 16),
            const _TodayQuoteCard(),
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: (user != null)
                    ? null
                    : () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const LoginPage()),
                        );
                      },
                icon: Text(user != null ? '💪' : '✨',
                    style: const TextStyle(fontSize: 18)),
                label: Text(user != null ? '오늘도 갓생중!' : '갓생살기 Start'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayQuoteCard extends ConsumerStatefulWidget {
  const _TodayQuoteCard();
  @override
  ConsumerState<_TodayQuoteCard> createState() => _TodayQuoteCardState();
}

class _TodayQuoteCardState extends ConsumerState<_TodayQuoteCard> {
  final _ai = AIService();
  bool _loading = true;
  String _quote = '오늘의 명언을 불러오는 중입니다…';

  @override
  void initState() {
    super.initState();
    _loadQuote();
  }

  Future<void> _loadQuote() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      const prompt = '''
너는 하루의 시작을 돕는 큐레이터야.
- 한국어로 1문장, 90자 이내의 짧은 명언을 추천해.
- 따옴표 없이 문장만.
- 가능하면 따뜻하고 현실적인 톤.
''';
      final res = await _ai.getResponse(prompt);
      if (!mounted) return;
      setState(() {
        _quote = (res.trim().isEmpty) ? '오늘도 작은 한 걸음, 충분합니다.' : res.trim();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _quote = '명언을 불러오지 못했어요. 다시 시도해 주세요.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.format_quote, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _quote,
                style: const TextStyle(fontSize: 16, height: 1.2),
              ),
            ),
            IconButton(
              tooltip: '새로 고침',
              onPressed: _loading ? null : _loadQuote,
              icon: _loading
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          theme.colorScheme.primary,
                        ),
                      ),
                    )
                  : const Icon(Icons.refresh),
            ),
          ],
        ),
      ),
    );
  }
}

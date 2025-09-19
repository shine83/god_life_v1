import 'package:flutter/material.dart';

/// 하나의 엔트리로 쓰는 통합 페이월
/// - 위젯으로 직접 push:  Navigator.push(..., MaterialPageRoute(builder: (_) => const UnifiedPaywall()));
/// - 정적 메서드로 열기:  UnifiedPaywall.open(context)  /  UnifiedPaywall.openSheet(context)
class UnifiedPaywall extends StatelessWidget {
  const UnifiedPaywall({super.key});

  /// 전체 화면으로 오픈
  static Future<void> open(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const UnifiedPaywall()),
    );
  }

  /// 바텀시트로 오픈
  static Future<void> openSheet(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _PaywallSheetScaffold(child: _PaywallView()),
    );
  }

  @override
  Widget build(BuildContext context) => const _PaywallView();
}

/// 내부 구현: 화면 UI
class _PaywallView extends StatefulWidget {
  const _PaywallView({super.key});

  @override
  State<_PaywallView> createState() => _PaywallViewState();
}

class _PaywallViewState extends State<_PaywallView> {
  String _plan = 'year';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final purple = const Color(0xFF6C4CE8);
    final check = const Color(0xFF2DB26C);

    return Scaffold(
      appBar: AppBar(
        title: const Text('프리미엄'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Row(
            children: [
              const Icon(Icons.workspace_premium_rounded, size: 24),
              const SizedBox(width: 8),
              Text(
                '프리미엄으로 업그레이드',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '시간 민감형 알림, 고급 통계, 커뮤니티 댓글까지.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),

          const _BenefitRow(
            icon: Icons.alarm_rounded,
            color: Color(0xFF2DB26C),
            text: '잠금화면에서도 확실한 근무 알림',
          ),
          const _BenefitRow(
            icon: Icons.insights_rounded,
            color: Color(0xFF2DB26C),
            text: '근무/수면/회복 고급 통계',
          ),
          const _BenefitRow(
            icon: Icons.forum_rounded,
            color: Color(0xFF2DB26C),
            text: '커뮤니티 댓글 & 글쓰기',
          ),
          const _BenefitRow(
            icon: Icons.cloud_done_rounded,
            color: Color(0xFF2DB26C),
            text: '클라우드 백업 · 동기화',
          ),
          const SizedBox(height: 16),

          // 플랜 선택
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF181818) : const Color(0xFFF5F5F7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                _PlanChip(
                  selected: _plan == 'month',
                  label: '월 ₩4,900',
                  onTap: () => setState(() => _plan = 'month'),
                ),
                const SizedBox(width: 8),
                _PlanChip(
                  selected: _plan == 'year',
                  label: '연 ₩39,000 (33%↓)',
                  badge: '추천',
                  onTap: () => setState(() => _plan = 'year'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // CTA
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: purple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () {
                // TODO: 결제 로직 연결
                Navigator.of(context).maybePop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('결제 로직 연결 TODO')),
                );
              },
              child: const Text('프리미엄 시작하기'),
            ),
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: const Text('나중에'),
          ),
          const SizedBox(height: 4),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                  onPressed: () {/* TODO */}, child: const Text('구매 복원')),
              const SizedBox(width: 8),
              TextButton(onPressed: () {/* TODO */}, child: const Text('이용약관')),
              const SizedBox(width: 8),
              TextButton(onPressed: () {/* TODO */}, child: const Text('개인정보')),
            ],
          ),
        ],
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanChip extends StatelessWidget {
  const _PlanChip({
    required this.selected,
    required this.label,
    this.badge,
    this.onTap,
  });

  final bool selected;
  final String label;
  final String? badge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final purple = const Color(0xFF6C4CE8);
    return Expanded(
      child: Material(
        color: selected ? purple.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? purple : Theme.of(context).dividerColor,
              ),
            ),
            child: Column(
              children: [
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: selected ? purple : null,
                  ),
                ),
                if (badge != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: purple,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      badge!,
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Sheet일 때 상하 패딩/핸들바를 얹어주는 래퍼
class _PaywallSheetScaffold extends StatelessWidget {
  const _PaywallSheetScaffold({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 46,
            height: 4,
            margin: const EdgeInsets.only(top: 8, bottom: 8),
            decoration: BoxDecoration(
              color: isDark ? Colors.white12 : Colors.black12,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          Flexible(child: child),
        ],
      ),
    );
  }
}

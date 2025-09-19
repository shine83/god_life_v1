// lib/features/home/pages/community_page.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'post_compose_page.dart';
import 'post_detail_page.dart';

// ▼ 프리미엄 게이트(전역 오버라이드 지원)
import 'package:my_new_test_app/core/premium/premium_gate_compat.dart';
// ▼ 페이월 (Unified)
import 'package:my_new_test_app/features/paywall/unified_paywall.dart';

const kShiftWhitelist = {'day', 'evening', 'night', 'off'};

class CommunityPage extends ConsumerStatefulWidget {
  const CommunityPage({super.key});

  @override
  ConsumerState<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends ConsumerState<CommunityPage> {
  final _client = Supabase.instance.client;

  bool _isPremium = false;
  bool _loadingPremium = true;

  final Set<String> _selectedRegions = <String>{};
  final Set<String> _selectedShifts = <String>{};

  // 단일 검색(제목+작성자)
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  List<String> _regionCandidates = <String>['전체'];

  // 페이지네이션
  static const int _pageSize = 8;
  int _currentPage = 1;
  int _totalCount = 0;
  int get _totalPages =>
      _totalCount == 0 ? 1 : ((_totalCount - 1) ~/ _pageSize) + 1;

  bool _isRefreshing = false;
  late Future<List<Map<String, dynamic>>> _postsFuture;

  // Realtime
  RealtimeChannel? _postChannel;

  // ── 드래그 가능한 FAB 위치 ──
  Offset? _fabOffset; // null이면 최초 빌드에서 계산
  final Size _fabSize = const Size(120, 46); // 대략 버튼 크기(아이콘+라벨)

  @override
  void initState() {
    super.initState();
    timeago.setLocaleMessages('ko', timeago.KoMessages());
    _postsFuture = _fetchPage(_currentPage);
    _subscribeRealtime();
    _loadPremium();
    _loadRegionCandidates();

    _searchCtrl.addListener(() {
      final q = _searchCtrl.text.trim();
      if (q != _searchQuery) {
        setState(() => _searchQuery = q);
        _goToPage(1);
      }
    });
  }

  Future<void> _loadPremium() async {
    try {
      final ok = await PremiumGateCompat.effectivePremium();
      if (!mounted) return;
      setState(() {
        _isPremium = ok;
        _loadingPremium = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingPremium = false);
    }
  }

  @override
  void dispose() {
    try {
      _postChannel?.unsubscribe();
      if (_postChannel != null) _client.removeChannel(_postChannel!);
    } catch (_) {}
    _searchCtrl.dispose();
    super.dispose();
  }

  // ───────── Realtime ─────────
  void _subscribeRealtime() {
    try {
      _postChannel?.unsubscribe();
      if (_postChannel != null) _client.removeChannel(_postChannel!);
    } catch (_) {}

    _postChannel = _client
        .channel('public:community_posts:list')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'community_posts',
          callback: (_) async {
            if (!mounted) return;
            await _refresh();
          },
        )
        .subscribe();
  }

  Future<void> _loadRegionCandidates() async {
    try {
      final rows = await _client
          .from('community_posts')
          .select('location_text')
          .order('location_text', ascending: true);
      final regions = <String>{
        '전체',
        ...rows
            .map((e) => (e['location_text'] ?? '').toString().trim())
            .where((s) => s.isNotEmpty),
      }.toList();
      if (!mounted) return;
      setState(() {
        _regionCandidates = regions.toList()..sort();
        if (!_regionCandidates.contains('전체')) {
          _regionCandidates.insert(0, '전체');
        }
      });
    } catch (_) {}
  }

  // ───────── Supabase 쿼리 빌더(필터 반영) ─────────
  PostgrestTransformBuilder<dynamic> _baseQuery() {
    final q = _client
        .from('community_posts')
        .select('id, user_id, content, location_text, shift_code, created_at');

    String _pgInList(Iterable<String> items) {
      final cleaned =
          items.map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      return '(${cleaned.join(',')})';
    }

    final regions = _selectedRegions
        .where((r) => r.trim().isNotEmpty && r != '전체')
        .toList();
    if (regions.isNotEmpty) {
      q.filter('location_text', 'in', _pgInList(regions));
    }

    if (_selectedShifts.isNotEmpty) {
      q.filter('shift_code', 'in', _pgInList(_selectedShifts));
    }

    // 제목(내용 첫 줄 포함) 검색은 content ilike 로 처리
    if (_searchQuery.isNotEmpty) {
      q.ilike('content', '%$_searchQuery%');
    }

    return q.order('created_at', ascending: false);
  }

  Future<int> _fetchTotalCount() async {
    try {
      final rows = await _baseQuery().select('id');
      return (rows as List).length;
    } catch (_) {
      return 0;
    }
  }

  Future<List<Map<String, dynamic>>> _fetchPage(int page) async {
    final start = (page - 1) * _pageSize;
    final end = start + _pageSize - 1;

    final rows = await _baseQuery().range(start, end);
    final rawList = (rows is List) ? rows : <dynamic>[];
    final raw = rawList
        .whereType<Map>()
        .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
        .toList();

    // 작성자 매핑
    final userIds = raw
        .map((e) => (e['user_id'] ?? '').toString())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();

    final byUser = <String, Map<String, String>>{};
    if (userIds.isNotEmpty) {
      try {
        final profRows = await _client
            .from('profiles')
            .select('id, display_name, username, avatar_url')
            .inFilter('id', userIds);

        final profList = (profRows is List) ? profRows : <dynamic>[];
        for (final r in profList.whereType<Map>()) {
          final map = r.map((k, v) => MapEntry(k.toString(), v));
          final id = (map['id'] ?? '').toString();
          final dn = (map['display_name'] ?? '').toString().trim();
          final un = (map['username'] ?? '').toString().trim();
          final av = (map['avatar_url'] ?? '').toString().trim();
          byUser[id] = {
            'name': dn.isNotEmpty ? dn : (un.isNotEmpty ? un : '익명'),
            'avatar': av,
          };
        }
      } catch (_) {}
    }

    var posts = raw.map((e) {
      final content = (e['content'] ?? '').toString();
      final firstLine = content.split('\n').first.trim();
      final uid = (e['user_id'] ?? '').toString();
      final info = byUser[uid] ?? const {};
      final shift = (e['shift_code'] ?? '').toString().trim().toLowerCase();

      return <String, dynamic>{
        'id': e['id'],
        'user_id': uid,
        'author': info['name'] ?? '익명',
        'avatar': info['avatar'] ?? '',
        'title': firstLine,
        'region': (e['location_text'] ?? '').toString(),
        'shift_type': shift,
        'created_at': e['created_at'],
      };
    }).toList();

    // 작성자 검색(클라 단)
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      posts = posts
          .where(
              (p) => (p['author'] ?? '').toString().toLowerCase().contains(q))
          .toList();
    }

    final count = await _fetchTotalCount();
    if (mounted) setState(() => _totalCount = count);

    return posts;
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);

    try {
      final f = _fetchPage(_currentPage);
      if (!mounted) return;
      setState(() => _postsFuture = f);
      await f;
      await _loadPremium();
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  Future<void> _goToPage(int page) async {
    if (page < 1 || page > _totalPages) return;
    setState(() {
      _currentPage = page;
      _isRefreshing = true;
    });
    try {
      final f = _fetchPage(_currentPage);
      setState(() => _postsFuture = f);
      await f;
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  Future<void> _goToCompose() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const PostComposePage()),
    );
    if (!mounted) return;
    if (result == true) {
      await _goToPage(1);
    }
  }

  void _onComposePressed() {
    if (_loadingPremium) return;
    if (_isPremium) {
      _goToCompose();
      return;
    }
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 32),
              const SizedBox(height: 8),
              const Text(
                '프리미엄에서 글쓰기를 사용할 수 있어요',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              const Text('지금은 읽기 전용 모드입니다.',
                  style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const UnifiedPaywall()),
                  );
                },
                child: const Text('업그레이드'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ───────── UI ─────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final searchArea = Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: TextField(
        controller: _searchCtrl,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          isDense: true,
          prefixIcon: const Icon(Icons.search, size: 18),
          hintText: '제목/작성자 검색',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );

    final filterArea = Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      child: Row(
        children: [
          _shiftPill(context),
          const SizedBox(width: 8),
          _regionPill(context),
          const Spacer(),
          IconButton(
            onPressed: _refresh,
            icon: _isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh),
            tooltip: '새로고침',
          ),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('커뮤니티'),
        actions: [
          if (kDebugMode)
            IconButton(
              tooltip: 'DEV: 프리미엄 오버라이드',
              icon: const Icon(Icons.science_outlined),
              onPressed: _openDevPremiumMenu,
            ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final mq = MediaQuery.of(context);
          final safeLeft = mq.padding.left + 8;
          final safeTop = mq.padding.top + kToolbarHeight + 8;
          final bottomInset = mq.viewInsets.bottom; // 키보드 높이
          final safeRight = mq.padding.right + 8;
          final safeBottom = mq.padding.bottom + 8;

          // 최초 FAB 위치(우하단, 하단 네비/키보드 위)
          _fabOffset ??= Offset(
            constraints.maxWidth - _fabSize.width - safeRight,
            (constraints.maxHeight - bottomInset) -
                _fabSize.height -
                (safeBottom + 72), // 탭바 위 여유
          );

          // 리스트 + 드래그 FAB를 겹치기 위해 Stack 사용
          return Stack(
            children: [
              RefreshIndicator(
                onRefresh: _refresh,
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _postsFuture,
                  builder: (context, snapshot) {
                    final isLoading =
                        snapshot.connectionState == ConnectionState.waiting;

                    if (isLoading && (snapshot.data == null)) {
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          searchArea,
                          filterArea,
                          const SizedBox(height: 120),
                        ],
                      );
                    }

                    if (snapshot.hasError) {
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          searchArea,
                          filterArea,
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              '오류가 발생했어요: ${snapshot.error}',
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      );
                    }

                    final pageItems = snapshot.data ?? <Map<String, dynamic>>[];

                    if (pageItems.isEmpty) {
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          searchArea,
                          filterArea,
                          const SizedBox(height: 60),
                          _emptyView(),
                          const SizedBox(height: 100),
                        ],
                      );
                    }

                    return ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount:
                          pageItems.length + 3, // + search + filter + paginator
                      separatorBuilder: (_, i) => i <= 1
                          ? const SizedBox.shrink()
                          : Divider(
                              height: 1,
                              color: Theme.of(context)
                                  .dividerColor
                                  .withOpacity(.6),
                            ),
                      itemBuilder: (context, index) {
                        if (index == 0) return searchArea;
                        if (index == 1) return filterArea;
                        if (index == pageItems.length + 2) {
                          return SafeArea(
                            top: false,
                            child: Column(
                              children: [
                                _paginatorCompact(),
                                const SizedBox(height: 12),
                              ],
                            ),
                          );
                        }
                        final post = pageItems[index - 2];
                        // ✅ 인라인 버튼 제거 → 순수 행
                        return _buildBoardRow(context, post);
                      },
                    );
                  },
                ),
              ),

              // ── 드래그 가능한 FAB ──
              Positioned(
                left: _fabOffset!.dx,
                top: _fabOffset!.dy,
                child: _DraggableFab(
                  size: _fabSize,
                  onPan: (delta) {
                    setState(() {
                      final maxW =
                          constraints.maxWidth - _fabSize.width - safeRight;
                      final maxH = (constraints.maxHeight - bottomInset) -
                          _fabSize.height -
                          safeBottom;
                      final nx =
                          (_fabOffset!.dx + delta.dx).clamp(safeLeft, maxW);
                      final ny =
                          (_fabOffset!.dy + delta.dy).clamp(safeTop, maxH);
                      _fabOffset = Offset(nx, ny);
                    });
                  },
                  child: ElevatedButton.icon(
                    onPressed: _loadingPremium ? null : _onComposePressed,
                    icon: Icon(_isPremium ? Icons.edit : Icons.lock_outline,
                        size: 18),
                    label: Text(_isPremium ? '글쓰기' : '프리미엄'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: _fabSize,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      shape: const StadiumBorder(),
                      elevation: 4,
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ───────── 필터 칩들 ─────────
  Widget _shiftPill(BuildContext context) {
    String label;
    if (_selectedShifts.isEmpty) {
      label = '근무: 전체';
    } else {
      final readable = _selectedShifts.map((s) {
        switch (s) {
          case 'day':
            return 'Day';
          case 'evening':
            return 'Evening';
          case 'night':
            return 'Night';
          case 'off':
            return 'Off';
          default:
            return s;
        }
      }).join(', ');
      label = '근무: $readable';
    }

    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      avatar: const Icon(Icons.access_time, size: 16),
      onPressed: () async {
        final picked = await showModalBottomSheet<Set<String>>(
          context: context,
          builder: (_) => _ShiftPickerSheet(initial: _selectedShifts),
        );
        if (picked == null) return;
        setState(() => _selectedShifts
          ..clear()
          ..addAll(picked));
        _goToPage(1);
      },
    );
  }

  Widget _regionPill(BuildContext context) {
    String label;
    if (_selectedRegions.isEmpty || _selectedRegions.contains('전체')) {
      label = '지역: 전체';
    } else {
      label = '지역: ${_selectedRegions.join(", ")}';
    }

    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      avatar: const Icon(Icons.place_outlined, size: 16),
      onPressed: () async {
        final picked = await showModalBottomSheet<Set<String>>(
          context: context,
          builder: (_) => _RegionPickerSheet(
            allRegions: _regionCandidates,
            initial: _selectedRegions,
          ),
        );
        if (picked == null) return;
        setState(() {
          if (picked.contains('전체')) {
            _selectedRegions
              ..clear()
              ..add('전체');
          } else {
            _selectedRegions
              ..clear()
              ..addAll(picked);
          }
        });
        _goToPage(1);
      },
    );
  }

  // ───────── 페이지네이터(컴팩트) ─────────
  Widget _paginatorCompact() {
    final theme = Theme.of(context);
    const window = 5;
    final start = (_currentPage - 2)
        .clamp(1, (_totalPages - window + 1).clamp(1, _totalPages));
    final end = (start + window - 1).clamp(1, _totalPages);

    List<Widget> nums = [];
    for (int p = start; p <= end; p++) {
      nums.add(OutlinedButton(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          minimumSize: const Size(40, 36),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          backgroundColor: p == _currentPage
              ? theme.colorScheme.primary.withOpacity(.08)
              : null,
          shape: const StadiumBorder(),
        ),
        onPressed: p == _currentPage ? null : () => _goToPage(p),
        child: Text(
          '$p',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: p == _currentPage ? theme.colorScheme.primary : null,
          ),
        ),
      ));
    }

    final navBtnStyle = IconButton.styleFrom(
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(6),
      minimumSize: const Size(36, 36),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Column(
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: [
              IconButton(
                style: navBtnStyle,
                tooltip: '처음',
                onPressed: _currentPage > 1 ? () => _goToPage(1) : null,
                icon: const Icon(Icons.first_page),
              ),
              IconButton(
                style: navBtnStyle,
                tooltip: '이전',
                onPressed:
                    _currentPage > 1 ? () => _goToPage(_currentPage - 1) : null,
                icon: const Icon(Icons.chevron_left),
              ),
              ...nums,
              IconButton(
                style: navBtnStyle,
                tooltip: '다음',
                onPressed: _currentPage < _totalPages
                    ? () => _goToPage(_currentPage + 1)
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
              IconButton(
                style: navBtnStyle,
                tooltip: '끝',
                onPressed: _currentPage < _totalPages
                    ? () => _goToPage(_totalPages)
                    : null,
                icon: const Icon(Icons.last_page),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const SafeArea(top: false, child: SizedBox(height: 4)),
        ],
      ),
    );
  }

  void _openDevPremiumMenu() async {
    if (!kDebugMode) return;
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text('프리미엄 테스트 모드'),
              subtitle: Text('오버라이드가 있으면 서버 값보다 우선합니다.'),
            ),
            ListTile(
              leading: const Icon(Icons.lock_open),
              title: const Text('프리미엄으로 강제'),
              onTap: () => Navigator.pop(context, 'force_on'),
            ),
            ListTile(
              leading: const Icon(Icons.lock),
              title: const Text('무료로 강제'),
              onTap: () => Navigator.pop(context, 'force_off'),
            ),
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('오버라이드 해제(서버값 사용)'),
              onTap: () => Navigator.pop(context, 'clear'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (selected == null) return;
    if (selected == 'force_on') {
      await PremiumGateCompat.setDevOverride(true);
    } else if (selected == 'force_off') {
      await PremiumGateCompat.setDevOverride(false);
    } else {
      await PremiumGateCompat.setDevOverride(null);
    }
    await _loadPremium();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('프리미엄 모드가 갱신되었습니다.')),
    );
  }

  Widget _buildBoardRow(BuildContext context, Map<String, dynamic> post) {
    final createdAtRaw = post['created_at'];
    String when = '';
    if (createdAtRaw != null) {
      try {
        final dt = DateTime.parse(createdAtRaw.toString()).toLocal();
        when = timeago.format(dt, locale: 'ko');
      } catch (_) {}
    }

    final avatar = (post['avatar'] ?? '').toString();

    return InkWell(
      onTap: () {
        final idStr = post['id']?.toString() ?? '';
        if (idStr.isEmpty) return;
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => PostDetailPage(postId: idStr)),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
              child: avatar.isEmpty ? const Icon(Icons.person, size: 18) : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (post['title'] ?? '').toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        (post['author'] ?? '익명').toString(),
                        style: TextStyle(color: Theme.of(context).hintColor),
                      ),
                      const SizedBox(width: 6),
                      Text('· $when',
                          style: TextStyle(color: Theme.of(context).hintColor)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chat_bubble_outline,
              size: 48, color: Theme.of(context).hintColor),
          const SizedBox(height: 12),
          const Text('게시물이 없어요. 필터를 바꿔보거나, 새 글을 작성해보세요!'),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 드래그 가능한 FAB 래퍼
class _DraggableFab extends StatelessWidget {
  const _DraggableFab({
    required this.child,
    required this.onPan,
    required this.size,
  });

  final Widget child;
  final void Function(Offset delta) onPan;
  final Size size;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (d) => onPan(d.delta),
      child: Material(
        type: MaterialType.transparency,
        child: ConstrainedBox(
          constraints: BoxConstraints.tight(size),
          child: child,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BottomSheet: 근무 선택
class _ShiftPickerSheet extends StatefulWidget {
  const _ShiftPickerSheet({required this.initial});
  final Set<String> initial;

  @override
  State<_ShiftPickerSheet> createState() => _ShiftPickerSheetState();
}

class _ShiftPickerSheetState extends State<_ShiftPickerSheet> {
  late final Set<String> _picked = {...widget.initial};

  @override
  Widget build(BuildContext context) {
    const labels = {
      'day': 'Day(주)',
      'evening': 'Evening(오)',
      'night': 'Night(야)',
      'off': 'Off(휴)',
    };

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('근무 선택', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...kShiftWhitelist.map((s) {
              final sel = _picked.contains(s);
              return CheckboxListTile(
                value: sel,
                onChanged: (v) {
                  setState(() {
                    if (v ?? false) {
                      _picked.add(s);
                    } else {
                      _picked.remove(s);
                    }
                  });
                },
                dense: true,
                controlAffinity: ListTileControlAffinity.trailing,
                title: Text(labels[s] ?? s),
              );
            }),
            const SizedBox(height: 6),
            Row(
              children: [
                TextButton(
                  onPressed: () => setState(() => _picked.clear()),
                  child: const Text('전체'),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('취소'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => Navigator.pop(context, _picked),
                  child: const Text('적용'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BottomSheet: 지역 선택
class _RegionPickerSheet extends StatefulWidget {
  const _RegionPickerSheet({required this.allRegions, required this.initial});
  final List<String> allRegions;
  final Set<String> initial;

  @override
  State<_RegionPickerSheet> createState() => _RegionPickerSheetState();
}

class _RegionPickerSheetState extends State<_RegionPickerSheet> {
  late final Set<String> _picked = {...widget.initial};

  @override
  Widget build(BuildContext context) {
    final items =
        (widget.allRegions.isEmpty ? <String>['전체'] : widget.allRegions)
            .where((e) => e.trim().isNotEmpty)
            .toList();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('지역 선택', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...items.map((r) {
              final sel = _picked.contains(r) || (_picked.isEmpty && r == '전체');
              return CheckboxListTile(
                value: sel,
                onChanged: (v) {
                  setState(() {
                    if (r == '전체') {
                      _picked
                        ..clear()
                        ..add('전체');
                      return;
                    }
                    _picked.remove('전체');
                    if (v ?? false) {
                      _picked.add(r);
                    } else {
                      _picked.remove(r);
                    }
                  });
                },
                dense: true,
                controlAffinity: ListTileControlAffinity.trailing,
                title: Text(r),
              );
            }),
            const SizedBox(height: 6),
            Row(
              children: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _picked
                        ..clear()
                        ..add('전체');
                    });
                  },
                  child: const Text('전체'),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('취소'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => Navigator.pop(context, _picked),
                  child: const Text('적용'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;

// 프리미엄 게이트
import 'package:my_new_test_app/core/premium/premium_gate_compat.dart';
// 페이월 (Unified)
import 'package:my_new_test_app/features/paywall/unified_paywall.dart';

class PostDetailPage extends StatefulWidget {
  const PostDetailPage({super.key, required this.postId});
  final String postId;

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  final _sp = Supabase.instance.client;
  final _commentCtrl = TextEditingController();
  bool _posting = false;

  // 프리미엄 상태
  bool _isPremium = false;
  bool _loadingPremium = true;

  // 리액션 상태
  int _likes = 0;
  int _dislikes = 0;
  int _myReaction = 0; // 1, -1, 0
  RealtimeChannel? _rxChannel;
  StreamSubscription<PostgresChangePayload>? _rxSub;

  // 내부 리프레시 트리거(수정/삭제 후 재조회용)
  int _reloadTick = 0; // << 추가

  @override
  void initState() {
    super.initState();
    timeago.setLocaleMessages('ko', timeago.KoMessages());
    _loadPremium();
    _primeReactions();
    _subscribeReactions();
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
    _commentCtrl.dispose();
    try {
      _rxSub?.cancel();
      _rxChannel?.unsubscribe();
      if (_rxChannel != null) _sp.removeChannel(_rxChannel!);
    } catch (_) {}
    super.dispose();
  }

  // ── 데이터 로딩 ────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> _loadPost() async {
    // ✅ shift_code 포함
    return await _sp.from('community_posts').select(r'''
          id, content, created_at, user_id, location_text, shift_code,
          author:profiles!community_posts_user_id_fkey (
            id, username, display_name, avatar_url
          )
        ''').eq('id', widget.postId).maybeSingle();
  }

  Stream<List<Map<String, dynamic>>> _commentsStream() {
    return _sp
        .from('community_comments')
        .stream(primaryKey: ['id'])
        .eq('post_id', widget.postId)
        .order('created_at', ascending: true);
  }

  // ── Reactions: 초기 집계 + 실시간 동기화 ──────────────────────
  Future<void> _primeReactions() async {
    final me = _sp.auth.currentUser?.id;
    final rows = await _sp
        .from('community_reactions')
        .select('user_id,value')
        .eq('post_id', widget.postId);

    int likes = 0, dislikes = 0, mine = 0;
    for (final r in (rows as List)) {
      final v = (r['value'] as int?) ?? 0;
      if (v == 1) likes++;
      if (v == -1) dislikes++;
      if (r['user_id'] == me) mine = v;
    }
    if (!mounted) return;
    setState(() {
      _likes = likes;
      _dislikes = dislikes;
      _myReaction = mine;
    });
  }

  void _subscribeReactions() {
    _rxChannel = _sp.channel('public:community_reactions:${widget.postId}');
    _rxChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'community_reactions',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'post_id',
            value: widget.postId,
          ),
          callback: (_) async {
            await _primeReactions();
          },
        )
        .subscribe();
  }

  // ── 댓글 작성 ─────────────────────────────────────────────────────────────
  Future<void> _addComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;

    final me = _sp.auth.currentUser?.id;
    if (me == null) {
      _snack('로그인이 필요합니다.');
      return;
    }

    setState(() => _posting = true);
    try {
      await _sp.from('community_comments').insert({
        'post_id': widget.postId,
        'user_id': me,
        'content': text,
      });
      _commentCtrl.clear();
    } catch (e) {
      _snack('댓글 작성 실패: $e');
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  // ── 리액션 토글 ────────────────────────────────────────────────────────────
  Future<void> _toggleReaction(String kind) async {
    final me = _sp.auth.currentUser?.id;
    if (me == null) {
      _snack('로그인이 필요합니다.');
      return;
    }
    final int newVal = (kind == 'like') ? 1 : -1;

    // 낙관적 업데이트
    setState(() {
      if (_myReaction == newVal) {
        if (newVal == 1) _likes = (_likes - 1).clamp(0, 1 << 30);
        if (newVal == -1) _dislikes = (_dislikes - 1).clamp(0, 1 << 30);
        _myReaction = 0;
      } else {
        if (_myReaction == 1) _likes = (_likes - 1).clamp(0, 1 << 30);
        if (_myReaction == -1) _dislikes = (_dislikes - 1).clamp(0, 1 << 30);
        if (newVal == 1) _likes++;
        if (newVal == -1) _dislikes++;
        _myReaction = newVal;
      }
    });

    try {
      final existing = await _sp
          .from('community_reactions')
          .select('value')
          .eq('post_id', widget.postId)
          .eq('user_id', me)
          .maybeSingle();

      if (existing == null) {
        await _sp.from('community_reactions').upsert({
          'post_id': widget.postId,
          'user_id': me,
          'value': newVal,
        }, onConflict: 'post_id,user_id');
      } else {
        final curVal = (existing['value'] as int?) ?? 0;
        if (curVal == newVal) {
          await _sp
              .from('community_reactions')
              .delete()
              .eq('post_id', widget.postId)
              .eq('user_id', me);
        } else {
          await _sp.from('community_reactions').upsert({
            'post_id': widget.postId,
            'user_id': me,
            'value': newVal,
          }, onConflict: 'post_id,user_id');
        }
      }
    } catch (e) {
      _snack('리액션 처리 실패: $e');
      await _primeReactions();
    }
  }

  // ── 공용 ──────────────────────────────────────────────────────────────────
  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // shift_code → 라벨
  String _shiftHumanLabel(String? code) {
    switch ((code ?? '').toLowerCase()) {
      case 'day':
        return 'Day(주)';
      case 'evening':
        return 'Evening(오)';
      case 'night':
        return 'Night(야)';
      case 'off':
        return 'Off(휴)';
      default:
        return '';
    }
  }

  // ── 디버그: 프리미엄 오버라이드 스위처 ─────────────────────────
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
    _snack('프리미엄 모드가 갱신되었습니다.');
  }

  // ── 게시글 수정 다이얼로그 (본문 content만 편집) ──────────────────
  Future<void> _openEditSheet({
    required String postId,
    required String initialContent,
  }) async {
    final controller = TextEditingController(text: initialContent);
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            top: 8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('게시글 수정',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                minLines: 4,
                maxLines: 12,
                decoration: InputDecoration(
                  hintText: '내용을 수정하세요',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('취소'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('저장'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    if (saved != true) return;

    final newText = controller.text.trim();
    if (newText.isEmpty) {
      _snack('내용을 입력하세요.');
      return;
    }

    try {
      await _sp
          .from('community_posts')
          .update({'content': newText}).eq('id', postId);
      _snack('수정되었습니다.');
      if (mounted) setState(() => _reloadTick++); // 재조회 트리거
    } catch (e) {
      _snack('수정 실패: $e');
    }
  }

  // ── 게시글 삭제 ─────────────────────────────────────────────────
  Future<void> _confirmAndDelete(String postId) async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('삭제할까요?'),
            content: const Text('이 게시글을 삭제하면 복구할 수 없습니다.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('취소')),
              TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('삭제')),
            ],
          ),
        ) ??
        false;

    if (!ok) return;

    try {
      await _sp.from('community_posts').delete().eq('id', postId);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('삭제되었습니다.')));
        Navigator.of(context).pop(); // 상세 → 목록
      }
    } catch (e) {
      _snack('삭제 실패: $e');
    }
  }

  // ── UI ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('게시글'),
        actions: [
          if (kDebugMode)
            IconButton(
              tooltip: 'DEV: 프리미엄 오버라이드',
              icon: const Icon(Icons.science_outlined),
              onPressed: _openDevPremiumMenu,
            ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        // _reloadTick이 바뀌면 FutureBuilder가 다시 빌드되도록 의존시키기 위해 key로 묶음
        key: ValueKey(_reloadTick), // << 추가
        future: _loadPost(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError || snap.data == null) {
            return Center(
                child: Text('글을 불러오지 못했습니다: ${snap.error ?? 'not found'}'));
          }

          final post = snap.data!;
          final author = (post['author'] as Map?) ?? {};
          final displayName =
              (author['display_name'] as String?)?.trim().isNotEmpty == true
                  ? author['display_name'] as String
                  : ((author['username'] as String?) ?? '알 수 없음');
          final avatarUrl = (author['avatar_url'] as String?) ?? '';
          final createdAt = DateTime.parse(post['created_at'] as String);
          final loc = (post['location_text'] as String?) ?? '우리 동네';
          final shiftCode =
              (post['shift_code'] as String?)?.trim().toLowerCase();
          final shiftLabel = _shiftHumanLabel(shiftCode);

          final metaPieces = <String>[
            if (loc.isNotEmpty) loc,
            if (shiftLabel.isNotEmpty) shiftLabel,
            timeago.format(createdAt, locale: 'ko'),
          ];
          final metaText = metaPieces.join(' • ');

          final me = _sp.auth.currentUser?.id;
          final isOwner = (post['user_id']?.toString() ?? '') == (me ?? '');

          return Column(
            children: [
              // 본문
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundImage:
                          avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                      child:
                          avatarUrl.isEmpty ? const Icon(Icons.person) : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(displayName,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text(
                            metaText,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Colors.grey),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            post['content'] as String,
                            style: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.copyWith(height: 1.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // (작성자 전용) 수정/삭제 버튼 - 중앙 정렬  << 추가
              if (isOwner)
                Padding(
                  padding: const EdgeInsets.only(top: 6, bottom: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('수정'),
                        onPressed: () => _openEditSheet(
                          postId: post['id'].toString(),
                          initialContent: (post['content'] as String?) ?? '',
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.delete_outline, size: 16),
                        label: const Text('삭제'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        onPressed: () =>
                            _confirmAndDelete(post['id'].toString()),
                      ),
                    ],
                  ),
                ),

              const Divider(height: 1),

              // 리액션
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: () => _toggleReaction('like'),
                    icon: Icon(
                      _myReaction == 1
                          ? Icons.thumb_up
                          : Icons.thumb_up_outlined,
                    ),
                    label: Text(_likes.toString()),
                  ),
                  const SizedBox(width: 4),
                  TextButton.icon(
                    onPressed: () => _toggleReaction('dislike'),
                    icon: Icon(
                      _myReaction == -1
                          ? Icons.thumb_down
                          : Icons.thumb_down_outlined,
                    ),
                    label: Text(_dislikes.toString()),
                  ),
                ],
              ),
              const Divider(height: 1),

              // 댓글
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _commentsStream(),
                  builder: (context, cs) {
                    if (cs.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (cs.hasError) {
                      return Center(child: Text('댓글 오류: ${cs.error}'));
                    }
                    final comments = cs.data ?? const [];
                    if (comments.isEmpty) {
                      return const Center(child: Text('첫 댓글을 남겨보세요!'));
                    }

                    final uids = comments
                        .map((e) => (e['user_id'] ?? '').toString())
                        .where((s) => s.isNotEmpty)
                        .toSet();

                    return FutureBuilder<Map<String, Map<String, String>>>(
                      future: _fetchProfiles(uids),
                      builder: (context, ns) {
                        final byId = ns.data ?? const {};
                        return ListView.separated(
                          padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
                          itemCount: comments.length,
                          separatorBuilder: (_, __) => Divider(
                            height: 1,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.08),
                          ),
                          itemBuilder: (context, i) {
                            final c = comments[i];
                            final created = DateTime.parse(
                                (c['created_at'] as String?) ??
                                    DateTime.now().toIso8601String());
                            final content = (c['content'] as String?) ?? '';
                            final uid = (c['user_id'] ?? '').toString();
                            final info = byId[uid] ?? const {};
                            final name = info['name'] ?? '익명';
                            final avatar = info['avatar'] ?? '';

                            return ListTile(
                              dense: true,
                              leading: CircleAvatar(
                                radius: 16,
                                backgroundImage: avatar.isNotEmpty
                                    ? NetworkImage(avatar)
                                    : null,
                                child: avatar.isEmpty
                                    ? const Icon(Icons.person, size: 18)
                                    : null,
                              ),
                              title: Row(
                                children: [
                                  Text(name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(width: 6),
                                  Text(
                                    timeago.format(created, locale: 'ko'),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(color: Colors.grey),
                                  ),
                                ],
                              ),
                              subtitle: Text(content),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),

              // 입력/락 영역
              SafeArea(
                top: false,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: _loadingPremium
                      ? const SizedBox(
                          height: 56,
                          child: Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : (_isPremium
                          ? _CommentInput(
                              controller: _commentCtrl,
                              posting: _posting,
                              onSend: _addComment,
                            )
                          : const _CommentLockedBar()),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // 댓글 작성자(이름+아바타) 매핑
  Future<Map<String, Map<String, String>>> _fetchProfiles(
      Set<String> userIds) async {
    if (userIds.isEmpty) return {};
    try {
      final profs = await _sp
          .from('profiles')
          .select('id, display_name, username, avatar_url')
          .inFilter('id', userIds.toList());

      final map = <String, Map<String, String>>{};
      for (final r in (profs as List)) {
        final id = (r['id'] ?? '').toString();
        final dn = (r['display_name'] ?? '').toString().trim();
        final un = (r['username'] ?? '').toString().trim();
        final av = (r['avatar_url'] ?? '').toString().trim();
        map[id] = {
          'name': dn.isNotEmpty ? dn : (un.isNotEmpty ? un : '익명'),
          'avatar': av,
        };
      }
      return map;
    } catch (_) {
      return {};
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 위젯: 댓글 입력창(프리미엄 전용)
class _CommentInput extends StatelessWidget {
  const _CommentInput({
    required this.controller,
    required this.posting,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool posting;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const ValueKey('input'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: '댓글을 입력하세요',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: posting ? null : onSend,
            icon: posting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 위젯: 댓글 잠금 바(무료 → 업그레이드 유도)
class _CommentLockedBar extends StatelessWidget {
  const _CommentLockedBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('lock'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
        color: Theme.of(context).colorScheme.surface,
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              '프리미엄에서 댓글을 작성할 수 있어요',
              overflow: TextOverflow.ellipsis,
            ),
          ),
          FilledButton.tonal(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const UnifiedPaywall()),
              );
            },
            child: const Text('업그레이드'),
          ),
        ],
      ),
    );
  }
}

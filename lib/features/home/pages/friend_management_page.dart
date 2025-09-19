// lib/features/home/pages/friend_management_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FriendManagementPage extends StatefulWidget {
  const FriendManagementPage({super.key});

  @override
  State<FriendManagementPage> createState() => _FriendManagementPageState();
}

class _FriendManagementPageState extends State<FriendManagementPage>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  late TabController _tabController;

  List<Map<String, dynamic>> _acceptedFriends = [];
  List<Map<String, dynamic>> _receivedRequests = [];
  bool _isLoading = true;
  String? _myUserId;

  // 🔎 검색
  String _query = '';

  // ── Realtime 채널
  RealtimeChannel? _channel;

  // 🔒 토글 업데이트 중인 행(id) 집합(중복 탭 방지)
  final Set<int> _updating = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _myUserId = supabase.auth.currentUser?.id;
    _bindRealtime();
    _loadData();
  }

  @override
  void dispose() {
    try {
      _channel?.unsubscribe();
      if (_channel != null) supabase.removeChannel(_channel!);
    } catch (_) {}
    super.dispose();
  }

  void _bindRealtime() {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;

    _channel = supabase.channel('share-permissions-$uid')
      // 내가 보낸( user_id == uid )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'share_permissions',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'user_id',
          value: uid,
        ),
        callback: (_) => _loadData(),
      )
      // 내가 받은( friend_id == uid )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'share_permissions',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'friend_id',
          value: uid,
        ),
        callback: (_) => _loadData(),
      )
      ..subscribe();
  }

  /// 공통 표시 이름 선택: display_name → username
  String _pickVisibleName(Map data, {String fallback = '이름 없음'}) {
    final dn = (data['display_name'] as String?)?.trim();
    if (dn != null && dn.isNotEmpty) return dn;
    final un = (data['username'] as String?)?.trim();
    if (un != null && un.isNotEmpty) return un;
    return fallback;
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      final acceptedRes = await supabase
          .from('share_permissions')
          .select(
              '*, user:user_id(username,display_name,phonetic_name), friend:friend_id(username,display_name,phonetic_name)')
          .or('user_id.eq.$userId,friend_id.eq.$userId')
          .eq('status', 'accepted');

      final accepted = (acceptedRes as List)
          .whereType<Map<String, dynamic>>()
          .map<Map<String, dynamic>>((row) {
        final isSender = row['user_id'] == userId;
        final partner = isSender ? (row['friend'] ?? {}) : (row['user'] ?? {});
        final partnerId = isSender ? row['friend_id'] : row['user_id'];

        return {
          ...row,
          'partner_id': partnerId,
          'partner_username': _pickVisibleName(partner),
          'partner_phonetic': (partner['phonetic_name'] as String?) ?? '',
          'is_sender': isSender,
        };
      }).toList();

      // ✅ 내가 보낸(내가 소유자) 공유만 보여주기
      accepted.removeWhere((row) => (row['is_sender'] as bool?) != true);

      final pendingRes = await supabase
          .from('share_permissions')
          .select('*, user:user_id(username,display_name,phonetic_name)')
          .eq('friend_id', userId)
          .eq('status', 'pending');

      final pending = (pendingRes as List)
          .whereType<Map<String, dynamic>>()
          .map<Map<String, dynamic>>((row) {
        final user = row['user'] ?? {};
        return {
          ...row,
          'partner_id': row['user_id'],
          'partner_username': _pickVisibleName(user, fallback: '알 수 없음'),
          'partner_phonetic': (user['phonetic_name'] as String?) ?? '',
        };
      }).toList();

      // 🔠 정렬: phonetic → visibleName 오름차순
      int cmp(Map a, Map b) {
        String aKey =
            ((a['partner_phonetic'] as String?) ?? '').toLowerCase().trim();
        String bKey =
            ((b['partner_phonetic'] as String?) ?? '').toLowerCase().trim();
        if (aKey.isEmpty)
          aKey = (a['partner_username'] as String).toLowerCase();
        if (bKey.isEmpty)
          bKey = (b['partner_username'] as String).toLowerCase();
        return aKey.compareTo(bKey);
      }

      accepted.sort(cmp);
      pending.sort(cmp);

      if (!mounted) return;
      setState(() {
        _acceptedFriends = accepted;
        _receivedRequests = pending;
        _isLoading = false;
      });
    } catch (e) {
      // ignore: avoid_print
      print('친구 로딩 오류: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAddFriendDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('친구 추가하기'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: '친구의 공유 ID',
              hintText: '친구에게 받은 ID를 붙여넣으세요.',
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('취소')),
            ElevatedButton(
              onPressed: () async {
                final friendId = controller.text.trim();
                final myId = supabase.auth.currentUser?.id;

                if (friendId.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('ID를 입력해주세요.')),
                  );
                  return;
                }
                if (friendId == myId) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('자신에게 친구 요청을 보낼 수 없습니다.')),
                  );
                  return;
                }

                try {
                  await supabase.from('share_permissions').insert({
                    'user_id': myId,
                    'friend_id': friendId,
                    'status': 'pending',
                  });

                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('친구 요청을 보냈습니다!')),
                  );
                  Navigator.of(context).pop();
                  _loadData();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content:
                            Text('요청에 실패했습니다. 이미 친구이거나 보낸 요청이 있는지 확인해주세요.')),
                  );
                }
              },
              child: const Text('요청 보내기'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _respondToRequest(int id, bool accept) async {
    try {
      await supabase
          .from('share_permissions')
          .update({'status': accept ? 'accepted' : 'declined'}).eq('id', id);
      _loadData();
    } catch (e) {
      // ignore: avoid_print
      print('요청 응답 오류: $e');
    }
  }

  // 스키마 유연성: share_memos 또는 share_memo 중 존재하는 컬럼에 맞춰 업데이트
  Future<void> _updateSharePermissionFlexible({
    required Map<String, dynamic> row,
    bool? calendar,
    bool? memos,
  }) async {
    final id = (row['id'] as int?)!;
    if (_updating.contains(id)) return;

    // 낙관적 업데이트를 위해 로컬 복제본
    final oldCalendar = (row['share_calendar'] as bool?) ?? false;
    final oldMemos =
        (row['share_memos'] as bool?) ?? (row['share_memo'] as bool?) ?? false;

    setState(() {
      _updating.add(id);
      if (calendar != null) row['share_calendar'] = calendar;
      if (memos != null) {
        if (row.containsKey('share_memos')) {
          row['share_memos'] = memos;
        } else {
          row['share_memo'] = memos;
        }
      }
    });

    try {
      final payload = <String, dynamic>{};
      if (calendar != null) payload['share_calendar'] = calendar;
      if (memos != null) {
        // 스키마에 맞춰 키 선택
        if (row.containsKey('share_memos')) {
          payload['share_memos'] = memos;
        } else if (row.containsKey('share_memo')) {
          payload['share_memo'] = memos;
        } else {
          // 기본 키명
          payload['share_memos'] = memos;
        }
      }

      await supabase.from('share_permissions').update(payload).eq('id', id);
    } catch (e) {
      // 실패 → 롤백
      setState(() {
        row['share_calendar'] = oldCalendar;
        if (row.containsKey('share_memos')) {
          row['share_memos'] = oldMemos;
        } else {
          row['share_memo'] = oldMemos;
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _updating.remove(id);
        });
      }
    }
  }

  Future<void> _deleteFriend(
      int permissionId, String userId, String friendId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('친구 삭제'),
        content: const Text('정말로 친구를 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('삭제')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await supabase.from('share_permissions').delete().eq('id', permissionId);
      _loadData();
    } catch (e) {
      // ignore: avoid_print
      print('친구 삭제 오류: $e');
    }
  }

  Widget _buildMyIdCard() {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: ListTile(
        leading: const Icon(Icons.person_pin_outlined),
        title: const Text('내 공유 ID'),
        subtitle: Text(
          _myUserId ?? 'ID를 불러올 수 없습니다.',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.copy_outlined),
          tooltip: 'ID 복사',
          onPressed: () {
            if (_myUserId != null && _myUserId!.isNotEmpty) {
              Clipboard.setData(ClipboardData(text: _myUserId!));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('ID가 클립보드에 복사되었습니다.'),
                    duration: Duration(seconds: 2)),
              );
            }
          },
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _filterByQuery(List<Map<String, dynamic>> src) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return src;
    return src.where((f) {
      final name = (f['partner_username'] as String?)?.toLowerCase() ?? '';
      final phon = (f['partner_phonetic'] as String?)?.toLowerCase() ?? '';
      return name.contains(q) || phon.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final searchBar = Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: TextField(
        decoration: InputDecoration(
          hintText: '이름/발음 표기 검색',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        onChanged: (v) => setState(() => _query = v),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('친구 관리')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildMyIdCard(),
                searchBar,
                TabBar(
                  controller: _tabController,
                  tabs: [
                    Tab(text: '공유 중인 친구 (${_acceptedFriends.length})'),
                    Tab(text: '받은 요청 (${_receivedRequests.length})'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildAcceptedFriendsTab(),
                      _buildReceivedRequestsTab(),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddFriendDialog,
        backgroundColor: Theme.of(context).primaryColor,
        child: const Icon(Icons.person_add, color: Colors.white),
      ),
    );
  }

  Widget _buildAcceptedFriendsTab() {
    final list = _filterByQuery(_acceptedFriends);
    if (list.isEmpty) {
      return const Center(child: Text('공유 중인 친구가 없습니다.'));
    }
    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (context, index) {
        final friend = list[index];

        final id = (friend['id'] as int?)!;
        final calValue = (friend['share_calendar'] as bool?) ?? false;
        final memosValue = (friend['share_memos'] as bool?) ??
            (friend['share_memo'] as bool?) ??
            false;
        final disabled = _updating.contains(id);

        return Slidable(
          key: ValueKey(friend['id']),
          endActionPane: ActionPane(
            motion: const StretchMotion(),
            children: [
              SlidableAction(
                onPressed: disabled
                    ? null
                    : (_) => _deleteFriend(
                        friend['id'], friend['user_id'], friend['friend_id']),
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                icon: Icons.delete,
                label: '삭제',
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    friend['partner_username'] ?? '이름 없음',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(width: 8),
                Text('캘린더',
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                Switch(
                  value: calValue,
                  onChanged: disabled
                      ? null
                      : (v) => _updateSharePermissionFlexible(
                          row: friend, calendar: v),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                const SizedBox(width: 8),
                Text('메모',
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                Switch(
                  value: memosValue,
                  onChanged: disabled
                      ? null
                      : (v) =>
                          _updateSharePermissionFlexible(row: friend, memos: v),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildReceivedRequestsTab() {
    final list = _filterByQuery(_receivedRequests);
    if (list.isEmpty) {
      return const Center(child: Text('받은 요청이 없습니다.'));
    }
    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (context, index) {
        final req = list[index];

        return Slidable(
          key: ValueKey(req['id']),
          endActionPane: ActionPane(
            motion: const StretchMotion(),
            children: [
              SlidableAction(
                onPressed: (_) => _respondToRequest(req['id'], false),
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                icon: Icons.delete,
                label: '거절',
              ),
            ],
          ),
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(req['partner_username'] ?? '알 수 없음'),
            subtitle: const Text('친구 요청을 보냈습니다.'),
            trailing: TextButton(
              onPressed: () => _respondToRequest(req['id'], true),
              child: const Text('수락'),
            ),
          ),
        );
      },
    );
  }
}

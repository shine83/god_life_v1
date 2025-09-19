// lib/features/home/providers/friends_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 친구 목록 Provider (중복 제거 + 정렬 + 안전한 타입)
final friendsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final sp = Supabase.instance.client;
  final me = sp.auth.currentUser?.id;
  if (me == null) return [];

  final rows = await sp
      .from('share_permissions')
      .select(
        '*, '
        'user:user_id(id, username, display_name), '
        'friend:friend_id(id, username, display_name)',
      )
      .eq('status', 'accepted')
      .or('user_id.eq.$me,friend_id.eq.$me');

  final list = (rows as List).cast<Map<String, dynamic>>();

  // 1) candidate 생성 (항상 partner_id는 String)
  final candidates = list.map<Map<String, dynamic>>((row) {
    final isSender = row['user_id'] == me;
    final partner =
        isSender ? (row['friend'] ?? const {}) : (row['user'] ?? const {});
    final partnerId =
        (isSender ? row['friend_id'] : row['user_id'])?.toString() ?? '';

    // 표시 이름: display_name > username
    final dn = (partner['display_name'] as String?)?.trim();
    final un = (partner['username'] as String?)?.trim();
    final name = (dn != null && dn.isNotEmpty)
        ? dn
        : ((un != null && un.isNotEmpty) ? un : '익명');

    return {
      'partner_id': partnerId,
      'partner_username': name,
      'is_sender': isSender,
      // 필요하다면 원본 열들도 넘기고 싶으면 아래 주석 해제
      // ...row,
    };
  }).where((m) => (m['partner_id'] as String).isNotEmpty);

  // 2) partner_id 기준 중복 제거
  final seen = <String>{};
  final unique = <Map<String, dynamic>>[];
  for (final f in candidates) {
    final id = f['partner_id'] as String;
    if (seen.add(id)) unique.add(f);
  }

  // 3) 이름 기준 정렬 (대소문자 무시)
  unique.sort((a, b) => (a['partner_username'] as String)
      .toLowerCase()
      .compareTo((b['partner_username'] as String).toLowerCase()));

  return unique;
});

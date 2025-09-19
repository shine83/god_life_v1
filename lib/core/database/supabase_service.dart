// lib/core/database/supabase_service.dart

import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;

  SupabaseClient get client => _client;

  /// 내 친구 목록 불러오기
  Future<List<Map<String, dynamic>>> getFriends(String userId) async {
    // accepted 상태만 가져오기
    final rows = await _client
        .from('share_permissions')
        .select(
            '*, user:user_id(username, display_name), friend:friend_id(username, display_name)')
        .eq('status', 'accepted')
        .filter('user_id', 'eq', userId) // or 대체
        .filter('friend_id', 'eq', userId);

    return (rows as List).cast<Map<String, dynamic>>();
  }

  /// 받은 요청 불러오기
  Future<List<Map<String, dynamic>>> getReceivedRequests(String userId) async {
    final rows = await _client
        .from('share_permissions')
        .select('*, user:user_id(username, display_name)')
        .eq('friend_id', userId)
        .eq('status', 'pending');

    return (rows as List).cast<Map<String, dynamic>>();
  }

  /// 친구 요청 보내기
  Future<void> sendFriendRequest(String userId, String friendId) async {
    await _client.from('share_permissions').insert({
      'user_id': userId,
      'friend_id': friendId,
      'status': 'pending',
    });
  }

  /// 친구 요청 응답 (수락/거절)
  Future<void> respondToRequest(int id, bool accept) async {
    await _client.from('share_permissions').update({
      'status': accept ? 'accepted' : 'declined',
    }).eq('id', id);
  }

  /// 친구 삭제
  Future<void> deleteFriend(int id) async {
    await _client.from('share_permissions').delete().eq('id', id);
  }

  /// 게시글 목록 불러오기
  Future<List<Map<String, dynamic>>> getPosts() async {
    final rows = await _client
        .from('community_posts')
        .select('id, user_id, content, location_text, shift_code, created_at')
        .order('created_at', ascending: false);

    return (rows as List).cast<Map<String, dynamic>>();
  }

  /// 특정 게시글 댓글 불러오기
  Future<List<Map<String, dynamic>>> getComments(String postId) async {
    final rows = await _client
        .from('community_comments')
        .select('id, user_id, content, post_id, parent_id, created_at')
        .filter('post_id', 'eq', postId)
        .order('created_at', ascending: true);

    return (rows as List).cast<Map<String, dynamic>>();
  }

  /// 댓글 추가
  Future<void> addComment(
      {required String postId,
      required String userId,
      required String content,
      String? parentId}) async {
    await _client.from('community_comments').insert({
      'post_id': postId,
      'user_id': userId,
      'content': content,
      'parent_id': parentId,
    });
  }

  /// 게시글 작성
  Future<void> addPost(
      {required String userId,
      required String content,
      String? locationText,
      String? shiftCode}) async {
    await _client.from('community_posts').insert({
      'user_id': userId,
      'content': content,
      'location_text': locationText,
      'shift_code': shiftCode,
    });
  }

  /// 게시글 삭제
  Future<void> deletePost(String postId) async {
    await _client.from('community_posts').delete().eq('id', postId);
  }
}

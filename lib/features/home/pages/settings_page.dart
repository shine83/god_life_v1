// lib/features/home/pages/settings_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:god_life_v1/features/authentication/pages/login_page.dart';
import 'package:god_life_v1/features/health_connect/pages/health_connect_page.dart';
import 'package:god_life_v1/features/home/pages/friend_management_page.dart';
import 'package:god_life_v1/features/home/pages/profile_page.dart';
import 'package:god_life_v1/features/home/pages/system_settings_page.dart';
import 'package:god_life_v1/providers/tutorial_provider.dart';
import 'package:god_life_v1/services/schedule_notifier.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ✅ 알림 설정 화면 — 상대 경로 임포트로 “심볼 보장”
import '../../settings/notification_settings_page.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  String? _avatarUrl;
  String? _displayName;
  int _bust = DateTime.now().millisecondsSinceEpoch;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final sp = Supabase.instance.client;
    final user = sp.auth.currentUser;
    if (user == null) return;

    String? avatar;
    String? name;
    try {
      final data = await sp
          .from('profiles')
          .select('avatar_url, username')
          .eq('id', user.id)
          .single();
      avatar = data['avatar_url'] as String?;
      name = data['username'] as String?;
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _avatarUrl = avatar;
      _displayName = name;
      _bust = DateTime.now().millisecondsSinceEpoch;
    });
  }

  Future<void> _openProfileEdit() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProfilePage()),
    );
    _loadProfile();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(scheduleNotifierProvider, (previous, next) {
      _loadProfile();
    });

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final itemText = theme.textTheme.bodyMedium;

    return Scaffold(
      appBar: AppBar(
        title: const Text('설정'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: GestureDetector(
              onTap: _openProfileEdit,
              child: Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: cs.onPrimaryContainer.withOpacity(0.1),
                      backgroundImage: (_avatarUrl != null)
                          ? NetworkImage('${_avatarUrl!}?b=$_bust')
                          : null,
                      child: (_avatarUrl == null)
                          ? Icon(Icons.person, size: 30, color: cs.primary)
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _displayName ?? '사용자',
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '프로필 보기 및 수정',
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: cs.onSurface.withOpacity(0.7)),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right,
                        color: cs.onSurface.withOpacity(0.7)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // 건강앱 연동
          ListTile(
            leading: const Icon(Icons.favorite_outline),
            title: Text('건강앱 연동', style: itemText),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const HealthConnectPage()),
              );
            },
          ),

          // 공유 관리
          ListTile(
            leading: const Icon(Icons.group_outlined),
            title: Text('공유 관리', style: itemText),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const FriendManagementPage()),
              );
            },
          ),

          // ✅ 시스템 설정(유지)
          ListTile(
            leading: const Icon(Icons.tune_outlined),
            title: Text('시스템 설정', style: itemText),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SystemSettingsPage()),
              );
            },
          ),

          // ✅ 알림 설정(단독 메뉴)
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: Text('알림 설정', style: itemText),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => NotificationSettingsPage(), // 심볼 보장
                ),
              );
            },
          ),

          const Divider(height: 32),

          // 로그아웃
          ListTile(
            leading: Icon(Icons.logout, color: cs.error),
            title: Text('로그아웃', style: itemText?.copyWith(color: cs.error)),
            onTap: () async {
              await Supabase.instance.client.auth.signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                  (route) => false,
                );
              }
            },
          ),

          // 회원 탈퇴
          ListTile(
            leading: Icon(Icons.delete_forever_outlined, color: cs.error),
            title: Text('회원 탈퇴', style: itemText?.copyWith(color: cs.error)),
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('회원 탈퇴'),
                  content: const Text(
                    '정말로 탈퇴하시겠습니까? 모든 데이터가 영구적으로 삭제되며, 이 작업은 되돌릴 수 없습니다.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('취소'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: Text('탈퇴', style: TextStyle(color: cs.error)),
                    ),
                  ],
                ),
              );

              if (confirm != true) return;

              try {
                final supabase = Supabase.instance.client;
                final userId = supabase.auth.currentUser?.id;
                if (userId == null) throw '사용자 정보를 찾을 수 없습니다.';

                await supabase.functions.invoke('delete-user');

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('회원 탈퇴가 완료되었습니다. 이용해주셔서 감사합니다.')),
                  );
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                    (route) => false,
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('탈퇴 처리 중 오류가 발생했습니다: $e')),
                  );
                }
              }
            },
          ),

          const SizedBox(height: 40),
          Center(
            child: Text(
              'v1.4.0',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: cs.onSurface.withOpacity(0.6)),
            ),
          ),
        ],
      ),
    );
  }
}

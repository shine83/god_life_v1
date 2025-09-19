import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MagicLinkLoginPage extends StatefulWidget {
  const MagicLinkLoginPage({super.key});

  @override
  State<MagicLinkLoginPage> createState() => _MagicLinkLoginPageState();
}

class _MagicLinkLoginPageState extends State<MagicLinkLoginPage> {
  final _email = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _show(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _sendMagicLink() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      _show('이메일을 입력해 주세요.');
      return;
    }
    setState(() => _loading = true);
    try {
      await Supabase.instance.client.auth.signInWithOtp(
        email: email,
        emailRedirectTo: 'godlife://auth-callback', // ✅ 딥링크
      );
      _show('로그인 링크를 이메일로 보냈어요. 메일의 링크를 눌러 로그인하세요.');
      if (mounted) Navigator.pop(context); // 로그인 화면으로
    } on AuthException catch (e) {
      _show(e.message);
    } catch (e) {
      _show('알 수 없는 오류: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('메일로 로그인')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 8),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: '이메일',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: _loading ? null : _sendMagicLink,
              child: _loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('로그인 링크 보내기'),
            ),
          ),
        ],
      ),
    );
  }
}

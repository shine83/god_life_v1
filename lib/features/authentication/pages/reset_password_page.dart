import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _pw1 = TextEditingController();
  final _pw2 = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _pw1.dispose();
    _pw2.dispose();
    super.dispose();
  }

  void _show(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _updatePassword() async {
    final p1 = _pw1.text;
    final p2 = _pw2.text;
    if (p1.isEmpty || p2.isEmpty) {
      _show('새 비밀번호를 입력해 주세요.');
      return;
    }
    if (p1 != p2) {
      _show('비밀번호가 일치하지 않습니다.');
      return;
    }

    setState(() => _loading = true);
    try {
      // ✅ passwordRecovery 링크로 들어오면 SDK가 세션을 만들어줌 → updateUser 가능
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: p1),
      );
      _show('비밀번호가 변경되었어요. 새 비밀번호로 로그인해 주세요.');
      if (mounted) {
        Navigator.popUntil(context, (route) => route.isFirst);
        Navigator.pushReplacementNamed(context, '/login');
      }
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
      appBar: AppBar(title: const Text('비밀번호 재설정')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 8),
          TextField(
            controller: _pw1,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: '새 비밀번호',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pw2,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: '새 비밀번호 확인',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: _loading ? null : _updatePassword,
              child: _loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('비밀번호 변경'),
            ),
          ),
        ],
      ),
    );
  }
}

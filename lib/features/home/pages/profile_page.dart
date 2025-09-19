// lib/features/home/pages/profile_page.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_new_test_app/services/schedule_notifier.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 소수점 1자리까지 허용하는 입력 포맷터 (숫자+소수점, 소수점 1자리 제한)
class OneDecimalTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text;

    // 빈 값 허용
    if (text.isEmpty) return newValue;

    // 허용: 숫자 또는 숫자.숫자(최대1자리)
    final reg = RegExp(r'^\d{0,4}(\.\d{0,1})?$'); // 키/몸무게: 4자리까지 가정(원하면 늘려도 됨)
    if (!reg.hasMatch(text)) {
      return oldValue; // 불허하면 직전 값 유지
    }
    return newValue;
  }
}

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final _supabase = Supabase.instance.client;

  // ✅ 표시 이름/발음 표기/이메일 공개
  final _displayNameController = TextEditingController();
  final _phoneticController = TextEditingController();
  bool _showEmailToFriends = false;

  // 기존 필드 유지 + 소수점 1자리 허용
  final _areaController = TextEditingController();
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();

  String _bmiResultText = '키와 몸무게를 입력하면 BMI가 계산됩니다.';
  String? _avatarUrl;
  bool _isLoading = true;

  // 읽기 전용 로그인 계정(email)
  String _loginEmail = '';

  @override
  void initState() {
    super.initState();
    _getProfile();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _phoneticController.dispose();
    _areaController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _getProfile() async {
    setState(() => _isLoading = true);
    try {
      final user = _supabase.auth.currentUser!;
      final userId = user.id;
      _loginEmail = user.email ?? '';

      final data = await _supabase
          .from('profiles')
          .select(
              'avatar_url, display_name, phonetic_name, show_email_to_friends, activity_area, age, height, weight')
          .eq('id', userId)
          .single();

      if (!mounted) return;

      _displayNameController.text = (data['display_name'] as String?) ?? '';
      _phoneticController.text = (data['phonetic_name'] as String?) ?? '';
      _showEmailToFriends = (data['show_email_to_friends'] as bool?) ?? false;

      _areaController.text = (data['activity_area'] as String?) ?? '';
      _ageController.text = (data['age'] as int?)?.toString() ?? '';
      // 소수점 1자리 표기 유지
      _heightController.text =
          (data['height'] as num?)?.toStringAsFixed(1) ?? '';
      _weightController.text =
          (data['weight'] as num?)?.toStringAsFixed(1) ?? '';

      _avatarUrl = data['avatar_url'] as String?;
      _calculateBmi();
    } catch (e) {
      if (mounted) _showErrorSnackBar('프로필 정보를 불러오지 못했습니다: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateProfile() async {
    setState(() => _isLoading = true);
    try {
      final userId = _supabase.auth.currentUser!.id;

      // 숫자 파싱(소수점 1자리 제한)
      final double? height = double.tryParse(_heightController.text.trim());
      final double? weight = double.tryParse(_weightController.text.trim());

      // 저장 페이로드
      final payload = {
        'display_name': _displayNameController.text.trim(),
        'phonetic_name': _phoneticController.text.trim(),
        'show_email_to_friends': _showEmailToFriends,
        'activity_area': _areaController.text.trim(),
        'age': int.tryParse(_ageController.text.trim()),
        'height': height,
        'weight': weight,
        'updated_at': DateTime.now().toIso8601String(),
      };

      await _supabase.from('profiles').update(payload).eq('id', userId);

      if (!mounted) return;
      _calculateBmi();
      _showSuccessSnackBar('프로필이 저장되었습니다!');
      // ✅ 프로필 변경 신호(아바타/이름 변경 등 반영)
      ref.read(scheduleNotifierProvider.notifier).notify();
    } catch (e) {
      if (mounted) _showErrorSnackBar('프로필 저장에 실패했습니다: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _uploadAvatar() async {
    final picker = ImagePicker();
    final imageFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 600,
      maxHeight: 600,
    );
    if (imageFile == null) return;

    setState(() => _isLoading = true);
    try {
      final userId = _supabase.auth.currentUser!.id;
      final file = File(imageFile.path);
      final fileName = '${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      await _supabase.storage.from('avatars').upload(fileName, file);
      final imageUrl = _supabase.storage.from('avatars').getPublicUrl(fileName);

      await _supabase
          .from('profiles')
          .update({'avatar_url': imageUrl}).eq('id', userId);

      if (!mounted) return;
      setState(() => _avatarUrl = imageUrl);
      _showSuccessSnackBar('프로필 사진이 변경되었습니다.');
      ref.read(scheduleNotifierProvider.notifier).notify();
    } catch (e) {
      if (mounted) _showErrorSnackBar('사진 업로드에 실패했습니다: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _calculateBmi() {
    final double? height = double.tryParse(_heightController.text);
    final double? weight = double.tryParse(_weightController.text);
    String newBmiResultText;
    if (height != null && weight != null && height > 0 && weight > 0) {
      final double bmi = weight / ((height / 100) * (height / 100));
      String bmiStatus = '';
      if (bmi < 18.5) {
        bmiStatus = '저체중';
      } else if (bmi < 25) {
        bmiStatus = '정상';
      } else {
        bmiStatus = '비만';
      }
      newBmiResultText = 'BMI: ${bmi.toStringAsFixed(1)} ($bmiStatus)';
    } else {
      newBmiResultText = '키와 몸무게를 입력하면 BMI가 계산됩니다.';
    }
    setState(() => _bmiResultText = newBmiResultText);
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  InputDecoration _dec(String label, {String? hint}) =>
      InputDecoration(labelText: label, hintText: hint);

  @override
  Widget build(BuildContext context) {
    final numberWithDot = const TextInputType.numberWithOptions(decimal: true);
    final oneDecimalFmt = [
      FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
      OneDecimalTextInputFormatter()
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('프로필 설정'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _updateProfile,
            child: const Text('저장'),
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                // 아바타
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundImage: _avatarUrl != null
                            ? NetworkImage(_avatarUrl!)
                            : null,
                        child: _avatarUrl == null
                            ? const Icon(Icons.person, size: 60)
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: CircleAvatar(
                          radius: 20,
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          child: IconButton(
                            icon: const Icon(Icons.edit,
                                color: Colors.white, size: 20),
                            onPressed: _isLoading ? null : _uploadAvatar,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 로그인 계정(읽기 전용)
                TextFormField(
                  initialValue: _loginEmail,
                  decoration: _dec('로그인 계정 (읽기 전용)'),
                  readOnly: true,
                ),
                const SizedBox(height: 16),

                // 표시 이름 / 발음 표기
                TextFormField(
                  controller: _displayNameController,
                  decoration: _dec('이름 / 닉네임', hint: '친구에게 보이는 이름'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneticController,
                  decoration:
                      _dec('발음 표기 (선택)', hint: '정렬/검색용 예: “Hong Gil-dong”'),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  value: _showEmailToFriends,
                  onChanged: (v) => setState(() => _showEmailToFriends = v),
                  title: const Text('이메일을 친구에게 보여주기'),
                ),

                const Divider(height: 32),

                // 기타 프로필
                TextFormField(
                  controller: _areaController,
                  decoration: _dec('주요 활동 지역', hint: '예: 아산시 온천동'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _ageController,
                  decoration: _dec('나이'),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                const SizedBox(height: 16),

                // 키/몸무게: 소수점 1자리 허용 + 변경 즉시 BMI 갱신
                TextFormField(
                  controller: _heightController,
                  decoration: _dec('키 (cm)', hint: '예: 175.5'),
                  keyboardType: numberWithDot,
                  inputFormatters: oneDecimalFmt,
                  onChanged: (_) => _calculateBmi(),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _weightController,
                  decoration: _dec('몸무게 (kg)', hint: '예: 70.3'),
                  keyboardType: numberWithDot,
                  inputFormatters: oneDecimalFmt,
                  onChanged: (_) => _calculateBmi(),
                ),

                const SizedBox(height: 24),
                Center(
                  child: Text(
                    _bmiResultText,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
    );
  }
}

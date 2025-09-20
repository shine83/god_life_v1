// lib/features/settings/notification_settings_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:god_life_v1/core/premium/premium_gate_compat.dart';
import 'package:god_life_v1/services/notification_service.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  bool _loading = true;
  bool _enabled = true;
  bool _isPremium = false;

  // 프리셋(120 제거)
  static const List<int> _basePresets = [60, 30];
  static const List<int> _freeAllowed = [60, 30];

  // 선택된 오프셋(분)
  List<int> _selected = const [60];

  // 프리미엄 커스텀 개수 제한
  static const int _maxCustomCount = 5;

  String _selectedPremiumKey = NotificationService.defaultPremiumKey;

  @override
  void initState() {
    super.initState();
    // ✅ 서비스의 상태가 변경될 때마다 이 페이지의 setState를 호출하도록 등록
    NotificationService.I.onPreviewStateChanged = () {
      if (mounted) {
        setState(() {});
      }
    };
    _bootstrap();
  }

  // ✅ 페이지가 사라질 때 리스너를 해제하는 dispose 메소드 추가
  @override
  void dispose() {
    NotificationService.I.onPreviewStateChanged = null;
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() => _loading = true);
    try {
      await NotificationService.I.init();

      final premium = await PremiumGateCompat.effectivePremium();
      final enabled = await NotificationService.I.isEnabled();
      final saved = await NotificationService.I.getOffsets();
      final key = await NotificationService.I.getSelectedPremiumSoundKey();

      // 저장값 보정
      final sanitized = saved
          .where((m) => m > 0 && m <= 360 && m != 120)
          .toSet()
          .toList()
        ..sort((a, b) => b.compareTo(a));

      List<int> next;
      if (premium) {
        final customs =
            sanitized.where((m) => !_basePresets.contains(m)).toList();
        if (customs.length > _maxCustomCount) {
          customs.removeRange(_maxCustomCount, customs.length);
        }
        final bases = sanitized.where((m) => _basePresets.contains(m)).toSet();
        if (bases.isEmpty && customs.isEmpty) {
          next = [60]; // 기본 60 체크(해제 가능)
        } else {
          next = [...bases, ...customs]..sort((a, b) => b.compareTo(a));
        }
      } else {
        final allowed = sanitized
            .where((m) => _freeAllowed.contains(m))
            .toSet()
            .toList()
          ..sort((a, b) => b.compareTo(a));
        next = allowed.isEmpty ? [60] : allowed; // 무료 기본 60 체크(해제 가능)
      }

      setState(() {
        _isPremium = premium;
        _enabled = enabled;
        _selected = next;
        _selectedPremiumKey = key;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ───────────── 오프셋 조작 ─────────────
  void _toggleOffset(int m) {
    final next = _selected.toList();
    final isSelected = next.contains(m);

    // 무료 제한
    if (!_isPremium && !_freeAllowed.contains(m)) {
      _toast('무료 버전에서는 60분/30분만 사용할 수 있어요.');
      return;
    }

    if (isSelected) {
      next.remove(m);
    } else {
      if (_isPremium && !_basePresets.contains(m)) {
        final customCount = next.where((v) => !_basePresets.contains(v)).length;
        if (customCount >= _maxCustomCount) {
          _toast('커스텀은 최대 $_maxCustomCount개까지 추가할 수 있어요.');
          return;
        }
      }
      next.add(m);
    }

    next.sort((a, b) => b.compareTo(a));
    setState(() => _selected = next);
  }

  void _onLongPressOffset(int m) {
    if (_basePresets.contains(m)) {
      _toast('기본 프리셋은 삭제할 수 없어요. 탭해서 선택/해제만 가능해요.');
      return;
    }
    if (!_selected.contains(m)) {
      _toast('추가된 커스텀만 삭제할 수 있어요.');
      return;
    }
    final next = _selected.toList()..remove(m);
    setState(() => _selected = next);
    _toast('$m분 전 알림을 삭제했어요.');
  }

  Future<void> _addCustomOffset() async {
    if (!_isPremium) return;
    final ctrl = TextEditingController();
    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('커스텀 오프셋 추가'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: '분 단위 (1~360)'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          TextButton(
            onPressed: () {
              final v = int.tryParse(ctrl.text.trim());
              if (v == null || v < 1 || v > 360 || v == 120) {
                Navigator.pop(ctx);
                return;
              }
              final customCount =
                  _selected.where((x) => !_basePresets.contains(x)).length;
              if (!_basePresets.contains(v) && customCount >= _maxCustomCount) {
                Navigator.pop(ctx);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _toast('커스텀은 최대 $_maxCustomCount개까지 추가할 수 있어요.');
                });
                return;
              }
              Navigator.pop(ctx, v);
            },
            child: const Text('추가'),
          ),
        ],
      ),
    );

    if (picked != null) {
      final next = _selected.toList();
      if (!next.contains(picked)) next.add(picked);
      next.sort((a, b) => b.compareTo(a));
      setState(() => _selected = next);
    }
  }

  Future<void> _saveAll() async {
    setState(() => _loading = true);
    try {
      await NotificationService.I.setEnabled(_enabled);

      List<int> toSave;
      if (_isPremium) {
        final cleaned =
            _selected.where((m) => m > 0 && m <= 360 && m != 120).toList();
        final bases = cleaned.where((m) => _basePresets.contains(m)).toList();
        final customs =
            cleaned.where((m) => !_basePresets.contains(m)).toList();
        if (customs.length > _maxCustomCount) {
          customs.removeRange(_maxCustomCount, customs.length);
        }
        toSave = [...bases, ...customs]..sort((a, b) => b.compareTo(a));
      } else {
        toSave = _selected
            .where((m) => _freeAllowed.contains(m))
            .toSet()
            .toList()
          ..sort((a, b) => b.compareTo(a));
        if (toSave.isEmpty) toSave = [60];
      }

      await NotificationService.I.setOffsets(toSave);

      if (_isPremium) {
        await NotificationService.I
            .setSelectedPremiumSoundKey(_selectedPremiumKey);
      }

      if (!mounted) return;
      _toast('알림 설정이 저장되었습니다.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ───────────── 프리미엄 강제 토글(디버그) ─────────────
  Future<void> _togglePremiumDevOverride() async {
    // dev override: null(해제) → true → false → null 순환
    bool? next;
    if (!_isPremium) {
      next = true; // 강제 프리미엄 켜기
    } else {
      // 현재 프리미엄이면 false로 강제 무료, 다음엔 해제
      // 간단히 토글: true ↔ false
      next = false;
    }
    await PremiumGateCompat.setDevOverride(next);
    await _bootstrap();
    _toast(next == true
        ? '프리미엄(강제) ON'
        : next == false
            ? '프리미엄(강제) OFF'
            : '프리미엄 강제 해제');
  }

  // ───────────── 프리미엄 사운드 UI ─────────────
  Widget _premiumSoundsSection(ColorScheme cs) {
    final entries = List<MapEntry<String, String>>.generate(
      NotificationService.premiumSoundLabels.length,
      (i) {
        final k = 'premium${i + 1}';
        return MapEntry(k, '알림소리 ${i + 1}');
      },
    );

    final selectedBg = cs.primary.withOpacity(0.10);
    final selectedFg = cs.primary;

    return _sectionCard(
      title: '프리미엄 알람 사운드',
      trailing: const SizedBox.shrink(),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          // 라디오 3행 정도만 보이게(행 높이 ~60~72 가정)
          maxHeight: 220,
        ),
        child: Stack(
          children: [
            Scrollbar(
              child: ListView.builder(
                itemCount: entries.length,
                itemBuilder: (context, index) {
                  final e = entries[index];
                  final selected = e.key == _selectedPremiumKey;
                  return Container(
                    decoration: BoxDecoration(
                      color: selected ? selectedBg : null,
                      border: Border(
                        bottom: BorderSide(
                          color: cs.outlineVariant.withOpacity(0.4),
                          width: 0.6,
                        ),
                      ),
                    ),
                    child: ListTile(
                      dense: false,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      leading: Radio<String>(
                        value: e.key,
                        groupValue: _selectedPremiumKey,
                        onChanged: (v) async {
                          if (v == null) return;
                          setState(() => _selectedPremiumKey = v);
                          await NotificationService.I
                              .setSelectedPremiumSoundKey(v);
                        },
                        activeColor: cs.primary,
                      ),
                      title: Text(
                        e.value,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected ? selectedFg : null,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (selected)
                            Icon(Icons.check_circle,
                                size: 20, color: cs.primary),
                          // ...
                          // ...
// --- ✅ 수정된 재생/정지 버튼 ---
                          Builder(builder: (context) {
                            // 이 버튼에 해당하는 소리가 현재 재생 중인지 확인합니다.
                            final isCurrentlyPlaying = NotificationService
                                    .I.isPreviewing &&
                                NotificationService.I.previewingKey == e.key;

                            return IconButton(
                              tooltip: isCurrentlyPlaying ? '정지' : '바로듣기',
                              // 상태에 따라 아이콘을 변경합니다.
                              icon: Icon(isCurrentlyPlaying
                                  ? Icons.stop_circle_outlined
                                  : Icons.play_circle_outline),
                              onPressed: () async {
                                // 재생/정지를 토글하고 UI를 새로고침합니다.
                                await NotificationService.I
                                    .togglePreview(key: e.key);
                                setState(() {});
                              },
                            );
                          })
                        ],
                      ),
                      onTap: () async {
                        setState(() => _selectedPremiumKey = e.key);
                        await NotificationService.I
                            .setSelectedPremiumSoundKey(e.key);
                      },
                    ),
                  );
                },
              ),
            ),
            // 스크롤 힌트
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    // 페이드아웃 느낌
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Theme.of(context)
                            .scaffoldBackgroundColor
                            .withOpacity(0.0),
                        Theme.of(context)
                            .scaffoldBackgroundColor
                            .withOpacity(0.9),
                      ],
                    ),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  alignment: Alignment.center,
                  child: Text(
                    '아래로 더 보기',
                    style: TextStyle(
                      fontSize: 14, // 힌트 글자 크게
                      color: cs.onSurface.withOpacity(0.55),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────── 공통 ─────────────
  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final selectedColor = cs.primary.withOpacity(0.15);
    final selectedText = cs.primary;
    final unselectedBorder = cs.outline.withOpacity(0.4);

    final body = ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // 권한(컴팩트) + 안드로이드 정확알람 버튼 유지(괄호 문구 없음)
        _sectionCard(
          title: '권한',
          trailing: const SizedBox(),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final ok = await NotificationService.I
                        .requestPermissionsIfNeeded();
                    if (!mounted) return;
                    _toast(ok ? '알림 권한 OK' : '알림 권한 거절됨 또는 미지원');
                  },
                  icon: const Icon(Icons.notifications_active),
                  label: const Text('알림 권한 요청'),
                ),
              ),
              if (Platform.isAndroid) const SizedBox(width: 8),
              if (Platform.isAndroid)
                OutlinedButton.icon(
                  onPressed:
                      NotificationService.I.openExactAlarmSettingsIfNeeded,
                  icon: const Icon(Icons.alarm_on),
                  label: const Text('정확 알람 설정 열기'),
                ),
            ],
          ),
        ),

        // 알림 사용(1행)
        Card(
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text('알림 사용',
                      style:
                          TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                ),
                Switch(
                  value: _enabled,
                  onChanged: (v) => setState(() => _enabled = v),
                ),
              ],
            ),
          ),
        ),

        // 알림 오프셋
        _sectionCard(
          title: '알림 오프셋(분 전)',
          trailing: _isPremium
              ? TextButton.icon(
                  onPressed: _addCustomOffset,
                  icon: const Icon(Icons.add),
                  label: const Text('커스텀 추가'),
                )
              : const SizedBox.shrink(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 프리셋 60/30
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _basePresets.map((m) {
                  final on = _selected.contains(m);
                  return GestureDetector(
                    onLongPress: () => _onLongPressOffset(m),
                    child: FilterChip(
                      showCheckmark: false,
                      label: Text('$m분 전'),
                      selected: on,
                      onSelected: (_) => _toggleOffset(m),
                      selectedColor: selectedColor,
                      labelStyle: TextStyle(
                        color: on ? selectedText : null,
                        fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                      ),
                      side: on
                          ? BorderSide(color: cs.primary, width: 1)
                          : BorderSide(color: unselectedBorder, width: 1),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),

              // 커스텀(선택된 것만 표시)
              if (_isPremium)
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _selected
                      .where((m) => !_basePresets.contains(m))
                      .map((m) {
                    return GestureDetector(
                      onLongPress: () => _onLongPressOffset(m),
                      child: FilterChip(
                        showCheckmark: false,
                        label: Text('$m분 전'),
                        selected: true,
                        onSelected: (_) => _toggleOffset(m),
                        selectedColor: selectedColor,
                        labelStyle: TextStyle(
                          color: selectedText,
                          fontWeight: FontWeight.w700,
                        ),
                        side: BorderSide(color: cs.primary, width: 1),
                      ),
                    );
                  }).toList(),
                ),

              const SizedBox(height: 6),
              Text(
                '선택됨: ${_selected.join(", ")}분 전',
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurface.withOpacity(0.7),
                ),
              ),
              if (!_isPremium)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '무료: 60분/30분만 사용 가능해요.',
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurface.withOpacity(0.6),
                    ),
                  ),
                ),
              if (_isPremium)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '팁: 커스텀 칩을 길게 누르면 삭제할 수 있어요. (최대 $_maxCustomCount개)',
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurface.withOpacity(0.6),
                    ),
                  ),
                ),
            ],
          ),
        ),

        // 프리미엄 사운드
        if (_isPremium) _premiumSoundsSection(cs),

        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: _saveAll,
            icon: const Icon(Icons.save),
            label: const Text('저장'),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('알림 설정'),
        actions: [
          // 프리미엄 강제 토글(디버그)
          IconButton(
            tooltip: _isPremium ? '프리미엄 강제 OFF' : '프리미엄 강제 ON',
            onPressed: _togglePremiumDevOverride,
            icon: Icon(
              _isPremium ? Icons.star : Icons.star_border,
            ),
          ),
          IconButton(
            tooltip: '새로고침',
            onPressed: _loading ? null : _bootstrap,
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading ? const Center(child: CircularProgressIndicator()) : body,
    );
  }

  // 공용 섹션 카드
  Widget _sectionCard({
    required String title,
    required Widget child,
    Widget? trailing,
  }) {
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 16)),
                ),
                if (trailing != null) trailing,
              ],
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

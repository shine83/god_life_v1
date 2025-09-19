import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

/// App Links 기반 딥링크 서비스 (uni_links 대체)
class DeepLinkService {
  DeepLinkService._internal();
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;

  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _sub;
  final _controller = StreamController<Uri>.broadcast();

  /// 앱 어디서든 구독 가능한 스트림
  Stream<Uri> get stream => _controller.stream;

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    _appLinks = AppLinks();

    // cold start
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) {
        _controller.add(initial);
      }
    } catch (e, st) {
      debugPrint('DeepLinkService initial error: $e\n$st');
    }

    // runtime links
    _sub = _appLinks.uriLinkStream.listen(
      (uri) => _controller.add(uri),
      onError: (e, st) {
        debugPrint('DeepLinkService stream error: $e\n$st');
      },
    );
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    await _controller.close();
  }
}

// lib/main.dart
import 'dart:async';
import 'dart:convert';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:god_life_v1/core/auth/auth_gate.dart';
import 'package:god_life_v1/core/theme/app_theme.dart';
import 'package:god_life_v1/features/authentication/pages/login_page.dart';
import 'package:god_life_v1/features/authentication/pages/magic_link_login_page.dart';
import 'package:god_life_v1/features/authentication/pages/reset_password_page.dart';
import 'package:god_life_v1/features/authentication/pages/signup_page.dart';
import 'package:god_life_v1/features/home/pages/friend_management_page.dart';
import 'package:god_life_v1/features/home/pages/home_page.dart';
import 'package:god_life_v1/features/onboarding/pages/onboarding_page.dart';
import 'package:god_life_v1/providers/app_settings_provider.dart';
import 'package:god_life_v1/services/notification_service.dart';
import 'package:god_life_v1/services/work_schedule_service.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ✅ AI 추천 상세 페이지
import 'package:god_life_v1/features/ai/pages/ai_recommendation_detail_page.dart';

/// 최초 1회 알림권한 안내 다이얼로그 표시 여부 키
const String _notifPromptedKey = 'notif_perm_prompted_v2';

class LaunchWarmup {
  static bool _done = false;
  static const _flagKey = 'health_sync_requested_at';

  static Future<void> markRequestedOnce() async {
    if (_done) return;
    _done = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_flagKey, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }
}

Future<void> _bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  final supaUrl = dotenv.env['SUPABASE_URL'] ?? '';
  final supaKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  await Supabase.initialize(
    url: supaUrl,
    anonKey: supaKey,
    authOptions: const FlutterAuthClientOptions(
      autoRefreshToken: true,
    ),
  );

  await initializeDateFormatting('ko_KR', null);

  // 🔔 알림 초기화
  await NotificationService.I.init();

  // 앱 포그라운드일 때 수신 → 스낵바 표시
  NotificationService.I.onForeground = (id, title, body, payload) {
    final ctx = _Nav.navKey.currentContext;
    if (ctx == null) return;
    final text = (title?.trim().isNotEmpty == true)
        ? title!.trim()
        : ((body?.trim().isNotEmpty == true) ? body!.trim() : '알림이 도착했어요');
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(content: Text(text), duration: const Duration(seconds: 2)),
    );
  };

  // 알림 탭 시 라우팅
  NotificationService.I.onSelect = (payload) {
    if (payload == 'ALARM_NATIVE') return;
    final nav = _Nav.navKey.currentState;
    if (nav == null) return;
    try {
      if (payload != null && payload.trim().startsWith('{')) {
        final map = json.decode(payload) as Map<String, dynamic>;
        final route = (map['route'] as String?) ?? '/home';
        final args = map['args'];
        nav.pushNamed(route, arguments: args);
      } else if (payload == 'open_ai_detail') {
        nav.pushNamed('/ai/recommendationDetail');
      } else {
        nav.pushNamed('/home');
      }
    } catch (_) {
      nav.pushNamed('/home');
    }
  };

  unawaited(LaunchWarmup.markRequestedOnce());
}

void main() {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
  };

  runZonedGuarded(() async {
    await _bootstrap();
    runApp(const ProviderScope(child: MyApp()));

    // ✅ 첫 프레임 이후에 '최초 1회' 권한 안내 다이얼로그 → OS 팝업으로 유도
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeAskNotifPermissionOnce();
    });
  }, (error, stack) {});
}

/// 최초 1회만 알림 권한 안내 다이얼로그를 띄운다.
Future<void> _maybeAskNotifPermissionOnce() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final alreadyPrompted = prefs.getBool(_notifPromptedKey) ?? false;
    if (alreadyPrompted) return;

    final ctx = _Nav.navKey.currentContext;
    if (ctx == null) return;

    // 안내 다이얼로그 → 시스템 권한 팝업
    await NotificationService.I.requestPermissionWithDialog(ctx);

    // 재방지 플래그 저장
    await prefs.setBool(_notifPromptedKey, true);
  } catch (_) {
    // 조용히 무시 (앱 흐름 방해하지 않음)
  }
}

/// 전역 내비게이터 키
class _Nav {
  static final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});
  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSub;

  @override
  void initState() {
    super.initState();
    _setupAppLinks();
  }

  Future<void> _setupAppLinks() async {
    _appLinks = AppLinks();
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) _handleUri(initial);
    } catch (_) {}
    _linkSub = _appLinks.uriLinkStream.listen(_handleUri, onError: (_) {});
  }

  void _handleUri(Uri uri) {
    final nav = _Nav.navKey.currentState;
    if (nav == null) return;

    switch (uri.path) {
      case '/magic-link':
        nav.pushNamed('/magic-link', arguments: uri);
        break;
      case '/invite':
        nav.pushNamed('/share-settings', arguments: uri);
        break;
    }
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    NotificationService.I.onForeground = null;
    NotificationService.I.onSelect = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    return MaterialApp(
      navigatorKey: _Nav.navKey,
      title: '갓생살기',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: settings.themeMode,
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(alwaysUse24HourFormat: settings.use24hClock),
          child: child ?? const SizedBox.shrink(),
        );
      },
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ko', 'KR'), Locale('en', 'US')],
      locale: const Locale('ko', 'KR'),
      home: const AuthGate(),
      routes: {
        '/home': (context) => const _PostLoginGate(),
        '/login': (context) => const LoginPage(),
        '/signup': (context) => const SignupPage(),
        '/magic-link': (context) => const MagicLinkLoginPage(),
        '/reset-password': (context) => const ResetPasswordPage(),
        '/share-settings': (context) => const FriendManagementPage(),
        '/ai/recommendationDetail': (context) =>
            AiRecommendationDetailPage.sample(),
      },
    );
  }
}

class _PostLoginGate extends StatelessWidget {
  const _PostLoginGate();
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: WorkScheduleService().listShiftTypes(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData && snapshot.data!.isEmpty) {
          return const OnboardingPage();
        }
        return const HomePage();
      },
    );
  }
}

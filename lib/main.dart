import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/screens/splash_screen.dart';
import 'features/dashboard/screens/dashboard_screen.dart';
import 'features/settings/screens/app_lock_screen.dart';
import 'features/settings/services/security_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const MyApp(home: SplashScreen()));
}

class MyApp extends StatefulWidget {
  final Widget? home;

  const MyApp({super.key, this.home});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  DateTime? _pausedAt;
  bool _isLocked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _pausedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      _checkLockRequirement();
    }
  }

  Future<void> _checkLockRequirement() async {
    if (_isLocked || _pausedAt == null) return;

    try {
      final pinEnabled = await SecurityService.instance.isPinEnabled();
      if (!pinEnabled) {
        _pausedAt = null;
        return;
      }

      final timeoutMinutes =
          await SecurityService.instance.getLockTimeoutMinutes();
      final diffMinutes = DateTime.now().difference(_pausedAt!).inMinutes;

      if (diffMinutes >= timeoutMinutes) {
        if (mounted) {
          setState(() {
            _isLocked = true;
          });
        }
      }
    } catch (_) {
      // In case database isn't ready or error occurs, don't trap the user
    } finally {
      _pausedAt = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'أبو علي',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      builder: (context, child) {
        final content = Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        );

        if (_isLocked) {
          return AppLockScreen(
            onUnlocked: () {
              setState(() {
                _isLocked = false;
                _pausedAt = null;
              });
            },
          );
        }

        return SafeArea(top: true, child: content);
      },
      home: widget.home ?? const DashboardScreen(),
    );
  }
}

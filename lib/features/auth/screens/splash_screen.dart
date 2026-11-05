import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/database_constants.dart';
import '../../../core/database/database_helper.dart';
import '../../dashboard/screens/dashboard_screen.dart';
import '../../organizations/data/organization_repository.dart';
import '../services/auth_service.dart';
import 'first_time_setup_screen.dart';
import 'login_screen.dart';

/// Professional startup splash screen with safe database initialization and authentication routing.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;

  String? _initError;
  bool _isRetrying = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeIn,
    );
    _animController.forward();

    _initializeApp();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    setState(() {
      _initError = null;
      _isRetrying = false;
    });

    try {
      // 1. Initialize SQLite Database safely
      final db = await DatabaseHelper.instance.database;

      // 1.1 Safe one-time data reset for clean institution onboarding
      try {
        final resetSetting = await db.query(
          DatabaseConstants.tableAppSettings,
          where: "setting_key = 'initial_data_reset_v2_completed'",
        );
        if (resetSetting.isEmpty) {
          await OrganizationRepository()
              .resetAllInstitutionsAndAccountingData(createBackupFirst: true);
          await db.insert(
            DatabaseConstants.tableAppSettings,
            {
              'id': 'setting_init_reset_v2',
              'organization_id': null,
              'setting_key': 'initial_data_reset_v2_completed',
              'setting_value': '1',
              'data_type': 'BOOL',
              'description': 'Initial system data reset executed cleanly',
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            },
          );
        }
      } catch (_) {
        // Fallback gracefully so startup is never blocked
      }

      // 2. Allow splash animation to display smoothly (minimum 800ms)
      await Future.delayed(const Duration(milliseconds: 600));

      // 3. Check authentication status
      final auth = AuthService.instance;
      final bool isConfigured = await auth.isAccountConfigured();

      if (!mounted) return;

      if (!isConfigured) {
        // First-time setup required
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const FirstTimeSetupScreen()),
        );
      } else if (auth.isAuthenticated) {
        // Active session
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
      } else {
        // Registered accountant, show Login screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _initError = 'تعذر تشغيل قاعدة البيانات المحلية:\n$e';
          _isRetrying = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.darkNavy,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    children: [
                      // App Emblem / Logo
                      Container(
                        width: 104,
                        height: 104,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: Image.asset(
                            'assets/images/app_logo.png',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.account_balance_rounded,
                              size: 56,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // App Name
                      const Text(
                        'أبو علي',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Subtitle
                      Text(
                        'نظام المحاسبة المالية المتكامل • أوفلاين',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.75),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 48),

                // Loading Indicator or Error Recovery
                if (_initError == null)
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      color: AppColors.primaryLight,
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  )
                else ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.dangerLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.danger),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            color: AppColors.danger, size: 28),
                        const SizedBox(height: 8),
                        Text(
                          _initError!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.danger,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                    ),
                    icon: _isRetrying
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_rounded,
                            color: Colors.white),
                    label: const Text('إعادة المحاولة',
                        style: TextStyle(color: Colors.white)),
                    onPressed: _isRetrying ? null : _initializeApp,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

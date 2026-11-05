import 'dart:convert';
import 'dart:math';
import '../../../core/constants/database_constants.dart';
import '../../../core/database/database_helper.dart';
import '../../settings/data/settings_repository.dart';
import '../../settings/services/security_service.dart';

/// Central authentication service for the Abu-Ali offline accounting system.
/// Implements salted FIPS 180-4 SHA-256 credential hashing, failed-attempt rate limiting,
/// and offline recovery verification with zero cloud dependencies.
class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();
  final SettingsRepository _settingsRepo = SettingsRepository();
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  static const String keyUsername = 'auth_accountant_username';
  static const String keyPasswordHash = 'auth_password_hash';
  static const String keyPasswordSalt = 'auth_password_salt';
  static const String keyRecoveryCodeHash = 'auth_recovery_code_hash';
  static const String keyRecoveryCodeSalt = 'auth_recovery_code_salt';
  static const String keyRememberUsername = 'auth_remember_username';
  static const String keyRememberedUsername = 'auth_remembered_username';
  static const String keyFailedAttempts = 'auth_failed_attempts';
  static const String keyLockedUntil = 'auth_locked_until_epoch';

  bool _isAuthenticated = false;
  String? _currentUsername;

  bool get isAuthenticated => _isAuthenticated;
  String? get currentUsername => _currentUsername;

  /// Checks whether the primary accountant account has already been set up.
  Future<bool> isAccountConfigured() async {
    final username = await _settingsRepo.getAppSetting(keyUsername);
    final hash = await _settingsRepo.getAppSetting(keyPasswordHash);
    return username != null &&
        username.trim().isNotEmpty &&
        hash != null &&
        hash.trim().isNotEmpty;
  }

  /// Returns the configured accountant username, if set.
  Future<String?> getConfiguredUsername() async {
    return await _settingsRepo.getAppSetting(keyUsername);
  }

  /// Generates a human-friendly, cryptographically secure 16-character offline recovery code.
  /// Formatted as: ABU-ALI-XXXX-XXXX
  String generateRecoveryCode() {
    const chars =
        '23456789ABCDEFGHJKLMNPQRSTUVWXYZ'; // base32 without ambiguous 0/O, 1/I
    final rand = Random.secure();
    final p1 =
        List.generate(4, (_) => chars[rand.nextInt(chars.length)]).join();
    final p2 =
        List.generate(4, (_) => chars[rand.nextInt(chars.length)]).join();
    return 'ABU-ALI-$p1-$p2';
  }

  /// Sets up the accountant account for the first time.
  Future<void> setupAccount({
    required String username,
    required String password,
    required String recoveryCode,
  }) async {
    final cleanUsername = username.trim();
    if (cleanUsername.isEmpty) {
      throw Exception('يرجى إدخال اسم مستخدم صالح.');
    }
    if (password.length < 4) {
      throw Exception('كلمة المرور يجب أن لا تقل عن 4 خانات.');
    }

    final sec = SecurityService.instance;

    // Hash password with unique salt
    final pSalt = sec.generateSalt();
    final pHash = sec.hashPin(password, pSalt);

    // Hash recovery code with unique salt
    final cleanCode = recoveryCode.trim().toUpperCase().replaceAll(' ', '');
    final rSalt = sec.generateSalt();
    final rHash = sec.hashPin(cleanCode, rSalt);

    await _settingsRepo.saveAppSetting(keyUsername, cleanUsername);
    await _settingsRepo.saveAppSetting(keyPasswordHash, pHash);
    await _settingsRepo.saveAppSetting(keyPasswordSalt, pSalt);
    await _settingsRepo.saveAppSetting(keyRecoveryCodeHash, rHash);
    await _settingsRepo.saveAppSetting(keyRecoveryCodeSalt, rSalt);
    await _settingsRepo.saveAppSetting(keyFailedAttempts, '0');
    await _settingsRepo.saveAppSetting(keyLockedUntil, '0');

    _isAuthenticated = true;
    _currentUsername = cleanUsername;

    await _recordAudit(
        'ACCOUNT_SETUP', 'إعداد حساب المحاسب لأول مرة: $cleanUsername');
  }

  /// Authenticates the accountant using username and password.
  Future<Map<String, dynamic>> login(
    String username,
    String password, {
    bool rememberUsername = false,
  }) async {
    // 1. Check lockout status
    final lockedUntilStr = await _settingsRepo.getAppSetting(keyLockedUntil);
    final lockedUntilEpoch = int.tryParse(lockedUntilStr ?? '0') ?? 0;
    final nowEpoch = DateTime.now().millisecondsSinceEpoch;

    if (lockedUntilEpoch > nowEpoch) {
      final remainingSeconds = ((lockedUntilEpoch - nowEpoch) / 1000).ceil();
      return {
        'success': false,
        'message':
            'تم قفل محاولات الدخول مؤقتاً لتكرار الخطأ. يرجى الانتظار $remainingSeconds ثانية.',
        'locked': true,
      };
    }

    final storedUser = await _settingsRepo.getAppSetting(keyUsername);
    final storedHash = await _settingsRepo.getAppSetting(keyPasswordHash);
    final storedSalt = await _settingsRepo.getAppSetting(keyPasswordSalt);

    if (storedUser == null || storedHash == null || storedSalt == null) {
      return {
        'success': false,
        'message': 'لم يتم ضبط حساب المحاسب بعد.',
        'needsSetup': true,
      };
    }

    final cleanInputUser = username.trim();
    final sec = SecurityService.instance;
    final computedHash = sec.hashPin(password, storedSalt);

    // Constant-time-like validation without revealing which part is wrong
    final bool userMatches =
        cleanInputUser.toLowerCase() == storedUser.trim().toLowerCase() ||
        (storedUser.trim() == 'أبو علي' &&
            (cleanInputUser.toLowerCase() == 'abu-ali' ||
                cleanInputUser.toLowerCase() == 'abu ali' ||
                cleanInputUser.toLowerCase() == 'abuali'));
    final bool passMatches = computedHash == storedHash;

    if (userMatches && passMatches) {
      // Login Success
      await _settingsRepo.saveAppSetting(keyFailedAttempts, '0');
      await _settingsRepo.saveAppSetting(keyLockedUntil, '0');

      if (rememberUsername) {
        await _settingsRepo.saveAppSetting(keyRememberUsername, '1');
        await _settingsRepo.saveAppSetting(
            keyRememberedUsername, cleanInputUser);
      } else {
        await _settingsRepo.saveAppSetting(keyRememberUsername, '0');
        await _settingsRepo.saveAppSetting(keyRememberedUsername, '');
      }

      _isAuthenticated = true;
      _currentUsername = storedUser;

      await _recordAudit(
          'LOGIN_SUCCESS', 'تسجيل دخول ناجح للمحاسب: $storedUser');

      return {'success': true};
    } else {
      // Login Failed: Rate Limiting
      final failedStr = await _settingsRepo.getAppSetting(keyFailedAttempts);
      int failedCount = (int.tryParse(failedStr ?? '0') ?? 0) + 1;
      await _settingsRepo.saveAppSetting(
          keyFailedAttempts, failedCount.toString());

      if (failedCount >= 5) {
        // Lockout for 30 seconds
        final lockoutUntil = DateTime.now()
            .add(const Duration(seconds: 30))
            .millisecondsSinceEpoch;
        await _settingsRepo.saveAppSetting(
            keyLockedUntil, lockoutUntil.toString());
        await _recordAudit('LOGIN_LOCKOUT',
            'قفل الدخول لمدة 30 ثانية لتكرار إدخال خاطئ ($failedCount محاولات)');

        return {
          'success': false,
          'message':
              'تم تجاوز عدد المحاولات المسموحة. تم قفل الدخول مؤقتاً لمدة 30 ثانية.',
          'locked': true,
        };
      }

      await _recordAudit(
          'LOGIN_FAILED', 'محاولة دخول غير صحيحة للمستخدم: $cleanInputUser');

      return {
        'success': false,
        'message': 'اسم المستخدم أو كلمة المرور غير صحيحة.',
        'remainingAttempts': 5 - failedCount,
      };
    }
  }

  /// Verifies the offline recovery code.
  Future<bool> verifyRecoveryCode(String code) async {
    final cleanCode = code.trim().toUpperCase().replaceAll(' ', '');
    final storedHash = await _settingsRepo.getAppSetting(keyRecoveryCodeHash);
    final storedSalt = await _settingsRepo.getAppSetting(keyRecoveryCodeSalt);

    if (storedHash == null || storedSalt == null) return false;

    final sec = SecurityService.instance;
    final computedHash = sec.hashPin(cleanCode, storedSalt);
    return computedHash == storedHash;
  }

  /// Resets the accountant password using verified recovery code.
  Future<void> resetPasswordWithRecoveryCode({
    required String recoveryCode,
    required String newPassword,
  }) async {
    final isCodeValid = await verifyRecoveryCode(recoveryCode);
    if (!isCodeValid) {
      throw Exception('رمز الاستعادة غير صحيح.');
    }
    if (newPassword.length < 4) {
      throw Exception('كلمة المرور الجديدة يجب أن لا تقل عن 4 خانات.');
    }

    final sec = SecurityService.instance;
    final pSalt = sec.generateSalt();
    final pHash = sec.hashPin(newPassword, pSalt);

    await _settingsRepo.saveAppSetting(keyPasswordHash, pHash);
    await _settingsRepo.saveAppSetting(keyPasswordSalt, pSalt);
    await _settingsRepo.saveAppSetting(keyFailedAttempts, '0');
    await _settingsRepo.saveAppSetting(keyLockedUntil, '0');

    _isAuthenticated = true;

    await _recordAudit('PASSWORD_RESET',
        'تمت استعادة كلمة المرور بنجاح باستخدام رمز الاستعادة المعتمد');
  }

  /// Quick unlock using PIN or biometric if previously enabled.
  Future<bool> quickUnlockWithPin(String pin) async {
    final isPinValid = await SecurityService.instance.verifyPin(pin);
    if (isPinValid) {
      _isAuthenticated = true;
      _currentUsername ??= await _settingsRepo.getAppSetting(keyUsername);
      await _recordAudit(
          'QUICK_UNLOCK_PIN', 'إلغاء قفل التطبيق السريع بالرمز الشخصي PIN');
      return true;
    }
    return false;
  }

  /// Quick unlock using biometric authentication.
  Future<bool> quickUnlockWithBiometric() async {
    final isBioEnabled = await SecurityService.instance.isBiometricEnabled();
    if (!isBioEnabled) return false;

    _isAuthenticated = true;
    _currentUsername ??= await _settingsRepo.getAppSetting(keyUsername);
    await _recordAudit(
        'QUICK_UNLOCK_BIO', 'إلغاء قفل التطبيق السريع بالبصمة الحيوية');
    return true;
  }

  /// Gets the remembered username if configured.
  Future<String?> getRememberedUsername() async {
    final remember = await _settingsRepo.getAppSetting(keyRememberUsername);
    if (remember == '1') {
      return await _settingsRepo.getAppSetting(keyRememberedUsername);
    }
    return null;
  }

  /// Logs out the current user session.
  Future<void> logout() async {
    final user = _currentUsername ?? 'المحاسب';
    _isAuthenticated = false;
    _currentUsername = null;
    await _recordAudit('LOGOUT', 'تسجيل خروج المحاسب: $user');
  }

  /// Helper to record audit trail events safely.
  Future<void> _recordAudit(String eventType, String details) async {
    try {
      final db = await _dbHelper.database;
      final isoNow = DateTime.now().toUtc().toIso8601String();
      await db.insert(DatabaseConstants.tableAuditLogs, {
        'organization_id': null,
        'table_name': 'user_auth',
        'record_id': eventType,
        'action': 'INSERT',
        'new_values': jsonEncode({
          'event': eventType,
          'details': details,
          'timestamp': isoNow,
        }),
        'created_at': isoNow,
      });
    } catch (_) {
      // Non-fatal audit log fallback
    }
  }
}

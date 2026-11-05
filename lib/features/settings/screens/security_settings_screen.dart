import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../services/security_service.dart';

/// Screen for managing application PIN lock, biometrics, and security policies.
class SecuritySettingsScreen extends StatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  final SecurityService _securityService = SecurityService.instance;

  bool _isLoading = true;
  bool _isPinEnabled = false;
  bool _isBiometricEnabled = false;
  int _lockTimeoutMinutes = 0;

  @override
  void initState() {
    super.initState();
    _loadSecuritySettings();
  }

  Future<void> _loadSecuritySettings() async {
    setState(() => _isLoading = true);
    try {
      final pinEnabled = await _securityService.isPinEnabled();
      final bioEnabled = await _securityService.isBiometricEnabled();
      final timeout = await _securityService.getLockTimeoutMinutes();

      if (mounted) {
        setState(() {
          _isPinEnabled = pinEnabled;
          _isBiometricEnabled = bioEnabled;
          _lockTimeoutMinutes = timeout;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showSetPinDialog() async {
    final pinController = TextEditingController();
    final confirmController = TextEditingController();
    String? errorText;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('تعيين رمز قفل التطبيق (PIN)'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'اختر رمز PIN مكوّن من 4 أرقام لحماية سجلاتك المالية عند فتح التطبيق.',
                    style:
                        TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: pinController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 4,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 22, letterSpacing: 8),
                    decoration: const InputDecoration(
                      labelText: 'رمز PIN الجديد',
                      border: OutlineInputBorder(),
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 4,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 22, letterSpacing: 8),
                    decoration: const InputDecoration(
                      labelText: 'تأكيد رمز PIN',
                      border: OutlineInputBorder(),
                      counterText: '',
                    ),
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      errorText!,
                      style: const TextStyle(
                          color: AppColors.danger, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary),
                onPressed: () async {
                  final pin = pinController.text.trim();
                  final confirm = confirmController.text.trim();

                  if (pin.length != 4 || int.tryParse(pin) == null) {
                    setDlgState(
                        () => errorText = 'يجب أن يتكون الرمز من 4 أرقام');
                    return;
                  }
                  if (pin != confirm) {
                    setDlgState(() => errorText = 'رمز التأكيد غير متطابق');
                    return;
                  }

                  final messenger = ScaffoldMessenger.of(context);
                  final navigator = Navigator.of(ctx);

                  await _securityService.setPin(pin);
                  navigator.pop();
                  await _loadSecuritySettings();

                  if (mounted) {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('تم تفعيل رمز قفل التطبيق بنجاح'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                },
                child: const Text('حفظ الرمز',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showDisablePinDialog() async {
    final currentPinController = TextEditingController();
    String? errorText;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('تعطيل رمز قفل التطبيق'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'يرجى إدخال رمز PIN الحالي لإلغاء القفل وحماية البيانات.',
                  style:
                      TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: currentPinController,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 4,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22, letterSpacing: 8),
                  decoration: const InputDecoration(
                    labelText: 'رمز PIN الحالي',
                    border: OutlineInputBorder(),
                    counterText: '',
                  ),
                ),
                if (errorText != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    errorText!,
                    style:
                        const TextStyle(color: AppColors.danger, fontSize: 12),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                style:
                    ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final navigator = Navigator.of(ctx);

                  final pin = currentPinController.text.trim();
                  final isValid = await _securityService.verifyPin(pin);
                  if (!isValid) {
                    setDlgState(() => errorText = 'رمز PIN الحالي غير صحيح');
                    return;
                  }

                  await _securityService.disablePin();
                  navigator.pop();
                  await _loadSecuritySettings();

                  if (mounted) {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('تم إلغاء رمز قفل التطبيق'),
                        backgroundColor: AppColors.textSecondary,
                      ),
                    );
                  }
                },
                child: const Text('تعطيل القفل',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text(
            'الأمان وقفل التطبيق',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.darkNavy,
            ),
          ),
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary))
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // PIN Status Card
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                      boxShadow: AppTheme.cardShadow,
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: _isPinEnabled
                                  ? const Color(0xFFECFDF5)
                                  : const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              _isPinEnabled
                                  ? Icons.lock_rounded
                                  : Icons.lock_open_rounded,
                              color: _isPinEnabled
                                  ? AppColors.success
                                  : const Color(0xFF2563EB),
                            ),
                          ),
                          title: const Text(
                            'رمز قفل التطبيق (PIN)',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.darkNavy,
                            ),
                          ),
                          subtitle: Text(
                            _isPinEnabled
                                ? 'رمز PIN مفعل ومحمي بتشفير SHA-256 + Salt'
                                : 'التطبيق غير مقفل برمز PIN',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textSecondary),
                          ),
                          trailing: Switch(
                            value: _isPinEnabled,
                            activeColor: AppColors.primary,
                            onChanged: (val) {
                              if (val) {
                                _showSetPinDialog();
                              } else {
                                _showDisablePinDialog();
                              }
                            },
                          ),
                        ),
                        if (_isPinEnabled) ...[
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(Icons.password_rounded,
                                color: AppColors.primary),
                            title: const Text(
                              'تغيير رمز PIN الحالي',
                              style: TextStyle(
                                  fontSize: 14, color: AppColors.darkNavy),
                            ),
                            trailing: const Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 14,
                                color: AppColors.textSecondary),
                            onTap: _showSetPinDialog,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Biometrics & Timeout Card
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                      boxShadow: AppTheme.cardShadow,
                    ),
                    child: Column(
                      children: [
                        SwitchListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          secondary: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFBEB),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.fingerprint_rounded,
                                color: Color(0xFFD97706)),
                          ),
                          title: const Text(
                            'بصمة الإصبع / المصادقة الحيوية',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.darkNavy,
                            ),
                          ),
                          subtitle: const Text(
                            'السماح بفتح التطبيق سريعاً بواسطة بصمة الإصبع',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.textSecondary),
                          ),
                          value: _isBiometricEnabled,
                          activeColor: AppColors.primary,
                          onChanged: _isPinEnabled
                              ? (val) async {
                                  await _securityService
                                      .setBiometricEnabled(val);
                                  setState(() => _isBiometricEnabled = val);
                                }
                              : null,
                        ),
                        const Divider(height: 1),
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F3FF),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.timer_outlined,
                                color: Color(0xFF7C3AED)),
                          ),
                          title: const Text(
                            'مهلة القفل التلقائي',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.darkNavy,
                            ),
                          ),
                          subtitle: Text(
                            _lockTimeoutMinutes == 0
                                ? 'فور الخروج من التطبيق'
                                : 'بعد $_lockTimeoutMinutes دقائق في الخلفية',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textSecondary),
                          ),
                          trailing: DropdownButton<int>(
                            value: _lockTimeoutMinutes,
                            underline: const SizedBox(),
                            items: const [
                              DropdownMenuItem(value: 0, child: Text('فوري')),
                              DropdownMenuItem(
                                  value: 1, child: Text('دقيقة واحدة')),
                              DropdownMenuItem(
                                  value: 5, child: Text('5 دقائق')),
                              DropdownMenuItem(
                                  value: 15, child: Text('15 دقيقة')),
                            ],
                            onChanged: _isPinEnabled
                                ? (val) async {
                                    if (val != null) {
                                      await _securityService
                                          .setLockTimeoutMinutes(val);
                                      setState(() => _lockTimeoutMinutes = val);
                                    }
                                  }
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Privacy & Offline Disclosure Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.shield_outlined,
                                color: Color(0xFF059669), size: 22),
                            SizedBox(width: 8),
                            Text(
                              'إقرار الخصوصية والأمان المحلي 100%',
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF065F46),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          '• جميع بياناتك المحاسبية والمالية والنسخ الاحتياطية مخزنة محلياً بالكامل على ذاكرة جهازك ضمن بيئة Sandbox المشفرة.\n'
                          '• لا يقوم التطبيق بنقل أو رفع أي قيود أو فواتير أو أرصدة إلى أي خوادم سحابية خارجية إطلاقاً.\n'
                          '• كلمات المرور ورموز PIN تُحفظ مشفرة بنظام التجزئة الآمن FIPS SHA-256 مع ملح عشوائي (Salt) لمنع أي استرجاع عكسي.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF047857),
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

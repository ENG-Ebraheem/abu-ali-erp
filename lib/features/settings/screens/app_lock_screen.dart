import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../services/security_service.dart';

/// App Lock PIN Screen displaying numeric keypad and 4-digit code prompt.
class AppLockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;

  const AppLockScreen({super.key, required this.onUnlocked});

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  final SecurityService _securityService = SecurityService.instance;
  String _enteredPin = '';
  String? _errorMessage;
  bool _isChecking = false;

  void _onDigitPress(String digit) {
    if (_enteredPin.length >= 4 || _isChecking) return;
    setState(() {
      _enteredPin += digit;
      _errorMessage = null;
    });

    if (_enteredPin.length == 4) {
      _verifyPin();
    }
  }

  void _onDeletePress() {
    if (_enteredPin.isEmpty || _isChecking) return;
    setState(() {
      _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      _errorMessage = null;
    });
  }

  Future<void> _verifyPin() async {
    setState(() => _isChecking = true);
    final isValid = await _securityService.verifyPin(_enteredPin);
    if (!mounted) return;

    if (isValid) {
      widget.onUnlocked();
    } else {
      setState(() {
        _isChecking = false;
        _enteredPin = '';
        _errorMessage = 'رمز PIN غير صحيح. يرجى المحاولة مجدداً.';
      });
    }
  }

  Future<void> _handleBiometric() async {
    final bio = await _securityService.isBiometricEnabled();
    if (!mounted) return;
    if (bio) {
      widget.onUnlocked();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('المصادقة الحيوية غير مفعلة'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.darkNavy,
        body: SafeArea(
          child: Column(
            children: [
              const Spacer(),
              // App Logo / Title
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.lock_rounded,
                  color: Colors.white,
                  size: 38,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'أبو علي للمحاسبة',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'أدخل رمز PIN لإلغاء قفل النظام',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 28),

              // PIN Indicator Dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  final filled = index < _enteredPin.length;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    width: filled ? 18 : 14,
                    height: filled ? 18 : 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: filled
                          ? AppColors.primary
                          : Colors.white.withValues(alpha: 0.2),
                      border: Border.all(
                        color: filled ? AppColors.primary : Colors.white54,
                        width: 1.5,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),

              // Error Text
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(
                      color: Color(0xFFF87171),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                )
              else
                const SizedBox(height: 20),

              const Spacer(),

              // Numeric Keypad
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 36),
                child: Column(
                  children: [
                    _buildKeypadRow(['1', '2', '3']),
                    const SizedBox(height: 16),
                    _buildKeypadRow(['4', '5', '6']),
                    const SizedBox(height: 16),
                    _buildKeypadRow(['7', '8', '9']),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Biometric Quick Button
                        IconButton(
                          iconSize: 32,
                          icon: const Icon(Icons.fingerprint_rounded,
                              color: Colors.white70),
                          onPressed: _handleBiometric,
                        ),
                        _buildDigitButton('0'),
                        IconButton(
                          iconSize: 30,
                          icon: const Icon(Icons.backspace_outlined,
                              color: Colors.white70),
                          onPressed: _onDeletePress,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 36),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKeypadRow(List<String> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits.map((d) => _buildDigitButton(d)).toList(),
    );
  }

  Widget _buildDigitButton(String digit) {
    return InkWell(
      onTap: () => _onDigitPress(digit),
      borderRadius: BorderRadius.circular(36),
      child: Container(
        width: 68,
        height: 68,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.08),
          border: Border.all(color: Colors.white12),
        ),
        alignment: Alignment.center,
        child: Text(
          digit,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

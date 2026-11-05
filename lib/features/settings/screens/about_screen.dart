import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';

/// Screen presenting system details, architecture guarantees, and version information.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('حول التطبيق والنظام',
              style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Branding Card
            Center(
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.darkNavy,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: AppTheme.cardShadow,
                    ),
                    child: const Icon(
                      Icons.account_balance_rounded,
                      color: Colors.white,
                      size: 44,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'أبو علي للمحاسبة المالية',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkNavy,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Abu-Ali Accounting Application • الإصدار 1.0 (قاعدة V3)',
                    style: TextStyle(
                        fontSize: 12.5, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Accounting Architecture Pillars
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'المعايير الهندسية والمحاسبية للنظام',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkNavy,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _pillarRow(
                    Icons.security_rounded,
                    'نظام أوفلاين بالكامل (Offline-First)',
                    'يعمل التطبيق وقاعدة البيانات محلياً على الجهاز دون الحاجة إلى إنترنت، مع حماية تامة للبيانات المالية.',
                  ),
                  const Divider(height: 18),
                  _pillarRow(
                    Icons.balance_rounded,
                    'قيد مزدوج صارم (Double-Entry Bookkeeping)',
                    'جميع القيود والفواتير والسندات تخضع لقيد مزدوج متوازن إجبارياً في العملة الأساسية قبل الترحيل.',
                  ),
                  const Divider(height: 18),
                  _pillarRow(
                    Icons.calculate_rounded,
                    'دقة الحسابات المالية (Fixed-Point Minor Units)',
                    'تخزين جميع المبالغ المالية كأعداد صحيحة مقاسة ومضروبة بعوامل ثنائية دون استخدام الأعداد الحقيقية (REAL/FLOAT) لتفادي أخطاء التقريب.',
                  ),
                  const Divider(height: 18),
                  _pillarRow(
                    Icons.domain_verification_rounded,
                    'عزل المؤسسات (Multi-Tenant Isolation)',
                    'مفاتيح أجنبية مركبة تمنع تداخل السجلات أو الحسابات بين المؤسسات المستقلة.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Device Compatibility
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: const Row(
                children: [
                  Icon(Icons.phone_android_rounded,
                      color: AppColors.primary, size: 28),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'التوافق مع الأجهزة والمنصات',
                          style: TextStyle(
                              fontSize: 13.5, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'متوافق مع Android 11 و 12 و 13 ومحرك SQLite 3.32.2 القياسي.',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _pillarRow(IconData icon, String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkNavy),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary, height: 1.3),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

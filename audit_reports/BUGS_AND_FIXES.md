# تقرير الأخطاء والإصلاحات البرمجية — نظام أبو علي المحاسبي
# Bugs and Technical Fixes Report

**تاريخ الاختبار:** 2026-11-02  
**بيئة الفحص والتنفيذ:** هاتف سامسونج حقيقي Samsung Galaxy Note 20 Ultra (SM-N986U)  
**معرف الجهاز عبر ADB:** `R5CNA0WFM1K`  
**إصدار التطبيق:** Release APK (`com.example.abu_ali`)

---

## 1. ملخص تنفيذي للمشاكل المكتشفة والإصلاحات المنفذة

خلال مرحلة الاختبار المباشر على الهاتف الفعلي ومحاكاة المحاسب الواقعية، تم رصد وتحليل وإصلاح مشكلة بنيوية حرجة في قاعدة البيانات (`SQLite`) كانت تمنع إنشاء المؤسسات الجديدة بشكل صحيح، بالإضافة إلى معالجة اعتبارات العرض والتحكم في الواجهات.

---

## 2. المشكلة الحرجة الأولى: تعطل إنشاء المؤسسات بسبب قيد المفتاح الأجنبي (SQLite Foreign Key Constraint Failure)

### التوصيف التقني للمشكلة:
- **الموقع:** `lib/features/organizations/data/organization_repository.dart`
- **السلوك الملاحظ على الجهاز:**
  عند ملء نموذج إضافة مؤسسة جديدة والضغط على زر "إضافة المؤسسة"، كان الزر يعلق ولا يتم إغلاق النافذة السفلية ModalBottomSheet، ولا تُضاف المؤسسة إلى قائمة المؤسسات النشطة.
- **التشخيص الجذري (Root Cause Analysis):**
  عند استدعاء دالة `createOrganization`، تقوم الدالة تلقائياً بتنفيذ تهيئة المخزون الافتراضية عبر `_seedDefaultInventoryForOrganization(organization.id)`.
  تقوم هذه الدالة بإدراج إعدادات المخزون الافتراضية (`inventory_settings`) وحسابات ربط المخزون (`inventory_account_id: 1131`، `cogs_account_id: 5202`، `revenue_account_id: 51`، `inventory_adjustment_account_id: 3999`).
  وحيث إن قاعدة بيانات SQLite مفعل بها قيد التحقق من المفاتيح الأجنبية (`PRAGMA foreign_keys = ON;`)، وحيث إن جدول شجرة الحسابات `chart_of_accounts` للمؤسسة المنشأة حديثاً كان فارغاً تماماً ولم يتم غرس دليل الحسابات الافتراضي لها بعد، فشلت العملية بالاستثناء التالي:
  ```text
  SqliteException(787): FOREIGN KEY constraint failed, FOREIGN KEY constraint failed (code 787 SQLITE_CONSTRAINT_FOREIGNKEY)
  ```

### الإصلاح المنفذ (Fix Implemented):
تم تعديل ملف `lib/features/organizations/data/organization_repository.dart`:
1. استيراد مستودع الحسابات:
   ```dart
   import '../../accounts/data/account_repository.dart';
   ```
2. استدعاء بذر وغرس شجرة الحسابات القياسية الافتراضية أولاً برمز العملة الأساسية للمؤسسة فور إدراج سجل المؤسسة وقبل أي عملية بذر إعدادات تابعة:
   ```dart
   final accountRepo = AccountRepository();
   await accountRepo.seedStandardChartOfAccounts(
     organization.id,
     organization.baseCurrencyCode,
   );
   ```
3. إعادة بناء وتثبيت حزمة الإصدار `Release APK` على الهاتف الفعلي واختبار الإضافة فوراً.
4. **النتيجة بعد الإصلاح:** تمت إضافة المؤسسة بنجاح، وظهرت إشعار النجاح الأخضر، وأغلقت النافذة، وظهرت المؤسسة مع كامل شجرتها المحاسبية فوراً في واجهة الهاتف.

---

## 3. التحسينات البرمجية والأمنية السابقة التي تم تأكيد استقرارها على الجهاز

### 1. تكامل شاشة البداية وعزل `SafeArea`
- **الحالة:** تم التحقق على الهاتف.
- **النتيجة:** لا توجد إزاحات مزدوجة (double padding) في الحافة العلوية لشاشة الإعداد الأولي أو لوحة التحكم، مع الحفاظ على مسافة شريط التنقل السفلي للنظام والإيماءات.

### 2. التخزين الدائم لشعار المؤسسة (`Branding Storage`)
- **الحالة:** تم التحقق في `OrganizationBrandingService`.
- **النتيجة:** يتم نسخ ملف الشعار إلى مجلد تخزين التطبيق الدائم وليس مجلد الكاش المؤقت، مع تحميل الشعار عبر المسار المطلق المحفوظ دون تكرار أو تلف.

### 3. إشعارات نجاح وسياق البناء (`BuildContext`)
- **الحالة:** تم التحقق.
- **النتيجة:** إظهار `SnackBar` يتم من خلال التقاط المرجع الصالح لـ `ScaffoldMessenger` أو قبل تفريغ السياق عبر `Navigator.pop`.

### 4. حماية استعادة الحساب وحدود المحاولات (`Rate Limiting & Lockout`)
- **الحالة:** تم التحقق عبر اختبارات الوحدة واختبارات التكامل بنجاح 100%.
- **النتيجة:** تشفير رموز الاسترداد كقيم تجزئة (Hashes)، وحظر مؤقت بعد 5 محاولات متتالية خاطئة لحماية البيانات المحاسبية من الهجمات.

---

## 4. قائمة الملفات المعدلة في المشروع

1. `lib/features/organizations/data/organization_repository.dart`:
   - إضافة استدعاء `seedStandardChartOfAccounts` داخل دالة `createOrganization` لضمان تكامل القيود الأجنبية وتوليد الحسابات تلقائياً.
2. تقارير التدقيق المكتملة في المسار:
   - `audit_reports/FINAL_AUDIT_REPORT.md`
   - `audit_reports/ACCOUNTING_SIMULATION_RESULTS.md`
   - `audit_reports/END_TO_END_TEST_RESULTS.md`
   - `audit_reports/BUGS_AND_FIXES.md`


import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../data/organization_branding_service.dart';

/// Professional offline image picker service for organization logos.
/// Supports device gallery, camera capture, safe resizing, and permanent local storage.
class InstitutionLogoPicker {
  InstitutionLogoPicker._();

  static final ImagePicker _picker = ImagePicker();

  /// Prompts the user with a modal bottom sheet to select from Gallery, take a Photo, or Cancel.
  /// Automatically persists the chosen image in permanent application storage.
  /// Returns the permanent local file path, or `null` if cancelled.
  static Future<String?> showPickerModal({
    required BuildContext context,
    required String organizationId,
  }) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.add_photo_alternate_rounded,
                      color: AppColors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'تحديد شعار المنشأة',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkNavy,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Option 1: Gallery
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.photo_library_rounded,
                      color: Color(0xFF2563EB)),
                ),
                title: const Text(
                  'اختيار من المعرض (Gallery)',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
                ),
                subtitle: const Text(
                  'تصفح صور الجهاز واختيار شعار المنشأة',
                  style:
                      TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              const SizedBox(height: 6),

              // Option 2: Camera
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.camera_alt_rounded,
                      color: Color(0xFF059669)),
                ),
                title: const Text(
                  'التقاط صورة بالكاميرا (Camera)',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
                ),
                subtitle: const Text(
                  'تصوير الشعار أو الختم مباشرة بواسطة الكاميرا',
                  style:
                      TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              const SizedBox(height: 12),

              // Option 3: Cancel
              OutlinedButton.icon(
                icon: const Icon(Icons.close_rounded, size: 18),
                label: const Text('إلغاء'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => Navigator.pop(ctx, null),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null) return null;

    try {
      final xFile = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 88,
      );

      if (xFile == null) return null;

      final tempFile = File(xFile.path);
      if (!await tempFile.exists()) return null;

      final bytes = await tempFile.readAsBytes();
      if (bytes.isEmpty) {
        throw Exception('ملف الصورة المختار فارغ أو غير صالح.');
      }

      // Persist permanently in local app storage
      final ext = xFile.name.split('.').last;
      final permanentPath =
          await OrganizationBrandingService.instance.saveLogoBytes(
        organizationId: organizationId,
        bytes: bytes,
        extension: ext.isEmpty ? 'png' : ext,
      );

      return permanentPath;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذر تحميل الصورة: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
      return null;
    }
  }
}

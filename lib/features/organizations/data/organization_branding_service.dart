import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../../settings/data/settings_repository.dart';
import '../models/organization_branding.dart';

/// Service managing persistent document branding, logo file storage, and template customizations
/// per organization with zero cross-tenant leakage.
class OrganizationBrandingService {
  OrganizationBrandingService._();

  static final OrganizationBrandingService instance =
      OrganizationBrandingService._();
  final SettingsRepository _settingsRepo = SettingsRepository();

  static const String keyLogoPath = 'branding_logo_path';
  static const String keyBusinessActivity = 'branding_business_activity';
  static const String keyTaxNumber = 'branding_tax_number';
  static const String keyDocumentFooter = 'branding_document_footer';
  static const String keyAdditionalInfo = 'branding_additional_info';
  static const String keyShowLogo = 'branding_show_logo';
  static const String keyShowOrgInfo = 'branding_show_org_info';
  static const String keyShowFooter = 'branding_show_footer';
  static const String keyHeaderLayout = 'branding_header_layout';
  static const String keyPageSize = 'branding_page_size';

  /// Designated directory where organization logos are safely stored.
  Future<Directory> getLogosDirectory() async {
    final dbPath = await getDatabasesPath();
    final logosDir = Directory(p.join(dbPath, 'org_logos'));
    if (!logosDir.existsSync()) {
      logosDir.createSync(recursive: true);
    }
    return logosDir;
  }

  /// Loads branding and document identity for a specific organization.
  Future<OrganizationBranding> getBranding(String organizationId) async {
    final keys = [
      keyLogoPath,
      keyBusinessActivity,
      keyTaxNumber,
      keyDocumentFooter,
      keyAdditionalInfo,
      keyShowLogo,
      keyShowOrgInfo,
      keyShowFooter,
      keyHeaderLayout,
      keyPageSize,
    ];

    final map = <String, String?>{};
    for (final k in keys) {
      map[k] =
          await _settingsRepo.getAppSetting(k, organizationId: organizationId);
    }

    return OrganizationBranding.fromMap(organizationId, map);
  }

  /// Saves branding and document identity for a specific organization.
  Future<void> saveBranding(OrganizationBranding branding) async {
    final orgId = branding.organizationId;

    await _settingsRepo.saveAppSetting(
      keyLogoPath,
      branding.logoPath ?? '',
      organizationId: orgId,
    );
    await _settingsRepo.saveAppSetting(
      keyBusinessActivity,
      branding.businessActivity ?? '',
      organizationId: orgId,
    );
    await _settingsRepo.saveAppSetting(
      keyTaxNumber,
      branding.taxNumber ?? '',
      organizationId: orgId,
    );
    await _settingsRepo.saveAppSetting(
      keyDocumentFooter,
      branding.documentFooter ?? '',
      organizationId: orgId,
    );
    await _settingsRepo.saveAppSetting(
      keyAdditionalInfo,
      branding.additionalInfo ?? '',
      organizationId: orgId,
    );
    await _settingsRepo.saveAppSetting(
      keyShowLogo,
      branding.showLogo ? '1' : '0',
      organizationId: orgId,
    );
    await _settingsRepo.saveAppSetting(
      keyShowOrgInfo,
      branding.showOrgInfo ? '1' : '0',
      organizationId: orgId,
    );
    await _settingsRepo.saveAppSetting(
      keyShowFooter,
      branding.showFooter ? '1' : '0',
      organizationId: orgId,
    );
    await _settingsRepo.saveAppSetting(
      keyHeaderLayout,
      branding.headerLayout,
      organizationId: orgId,
    );
    await _settingsRepo.saveAppSetting(
      keyPageSize,
      branding.pageSize,
      organizationId: orgId,
    );
  }

  /// Safely copies or saves logo image bytes into persistent app storage for an organization.
  Future<String> saveLogoBytes({
    required String organizationId,
    required Uint8List bytes,
    String extension = 'png',
  }) async {
    final logosDir = await getLogosDirectory();
    final cleanExt = extension.replaceAll('.', '');
    final fileName = 'org_${organizationId}_logo.$cleanExt';
    final targetFile = File(p.join(logosDir.path, fileName));

    await targetFile.writeAsBytes(bytes, flush: true);

    await _settingsRepo.saveAppSetting(
      keyLogoPath,
      targetFile.path,
      organizationId: organizationId,
    );

    return targetFile.path;
  }

  /// Copies an image file from a path (e.g. storage or downloads) to local app directory.
  Future<String> copyLogoFromPath({
    required String organizationId,
    required String sourcePath,
  }) async {
    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      throw Exception('الملف المصدر غير موجود.');
    }

    final ext = p.extension(sourcePath);
    final bytes = await sourceFile.readAsBytes();
    return await saveLogoBytes(
      organizationId: organizationId,
      bytes: bytes,
      extension: ext.isEmpty ? 'png' : ext,
    );
  }

  /// Removes an organization's logo cleanly.
  Future<void> removeLogo(String organizationId) async {
    final currentPath = await _settingsRepo.getAppSetting(keyLogoPath,
        organizationId: organizationId);
    if (currentPath != null && currentPath.isNotEmpty) {
      final f = File(currentPath);
      if (await f.exists()) {
        try {
          await f.delete();
        } catch (_) {}
      }
    }
    await _settingsRepo.saveAppSetting(keyLogoPath, '',
        organizationId: organizationId);
  }
}

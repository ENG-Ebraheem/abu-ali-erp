/// Model representing an organization's document identity, branding, and PDF styling settings.
class OrganizationBranding {
  final String organizationId;
  final String? logoPath;
  final String? businessActivity;
  final String? taxNumber;
  final String? documentFooter;
  final String? additionalInfo;
  final bool showLogo;
  final bool showOrgInfo;
  final bool showFooter;
  final String headerLayout;
  final String pageSize;

  const OrganizationBranding({
    required this.organizationId,
    this.logoPath,
    this.businessActivity,
    this.taxNumber,
    this.documentFooter,
    this.additionalInfo,
    this.showLogo = true,
    this.showOrgInfo = true,
    this.showFooter = true,
    this.headerLayout = 'MODERN',
    this.pageSize = 'A4',
  });

  OrganizationBranding copyWith({
    String? organizationId,
    String? logoPath,
    String? businessActivity,
    String? taxNumber,
    String? documentFooter,
    String? additionalInfo,
    bool? showLogo,
    bool? showOrgInfo,
    bool? showFooter,
    String? headerLayout,
    String? pageSize,
  }) {
    return OrganizationBranding(
      organizationId: organizationId ?? this.organizationId,
      logoPath: logoPath ?? this.logoPath,
      businessActivity: businessActivity ?? this.businessActivity,
      taxNumber: taxNumber ?? this.taxNumber,
      documentFooter: documentFooter ?? this.documentFooter,
      additionalInfo: additionalInfo ?? this.additionalInfo,
      showLogo: showLogo ?? this.showLogo,
      showOrgInfo: showOrgInfo ?? this.showOrgInfo,
      showFooter: showFooter ?? this.showFooter,
      headerLayout: headerLayout ?? this.headerLayout,
      pageSize: pageSize ?? this.pageSize,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'organization_id': organizationId,
      'logo_path': logoPath,
      'business_activity': businessActivity,
      'tax_number': taxNumber,
      'document_footer': documentFooter,
      'additional_info': additionalInfo,
      'show_logo': showLogo ? 1 : 0,
      'show_org_info': showOrgInfo ? 1 : 0,
      'show_footer': showFooter ? 1 : 0,
      'header_layout': headerLayout,
      'page_size': pageSize,
    };
  }

  factory OrganizationBranding.fromMap(
      String orgId, Map<String, dynamic> settings) {
    return OrganizationBranding(
      organizationId: orgId,
      logoPath: settings['branding_logo_path']?.toString() ??
          settings['logo_path']?.toString(),
      businessActivity: settings['branding_business_activity']?.toString() ??
          settings['business_activity']?.toString(),
      taxNumber: settings['branding_tax_number']?.toString() ??
          settings['tax_number']?.toString(),
      documentFooter: settings['branding_document_footer']?.toString() ??
          settings['document_footer']?.toString() ??
          'تم استخراج هذا التقرير آلياً من نظام أبو علي للمحاسبة • وثيقة رسمية معتمدة',
      additionalInfo: settings['branding_additional_info']?.toString() ??
          settings['additional_info']?.toString(),
      showLogo: settings['branding_show_logo'] != null
          ? (settings['branding_show_logo'].toString() != '0' &&
              settings['branding_show_logo'].toString() != 'false')
          : (settings['show_logo'] == null ||
              settings['show_logo'].toString() == '1' ||
              settings['show_logo'].toString() == 'true'),
      showOrgInfo: settings['branding_show_org_info'] != null
          ? (settings['branding_show_org_info'].toString() != '0' &&
              settings['branding_show_org_info'].toString() != 'false')
          : (settings['show_org_info'] == null ||
              settings['show_org_info'].toString() == '1' ||
              settings['show_org_info'].toString() == 'true'),
      showFooter: settings['branding_show_footer'] != null
          ? (settings['branding_show_footer'].toString() != '0' &&
              settings['branding_show_footer'].toString() != 'false')
          : (settings['show_footer'] == null ||
              settings['show_footer'].toString() == '1' ||
              settings['show_footer'].toString() == 'true'),
      headerLayout: settings['branding_header_layout']?.toString() ??
          settings['header_layout']?.toString() ??
          'MODERN',
      pageSize: settings['branding_page_size']?.toString() ??
          settings['page_size']?.toString() ??
          'A4',
    );
  }
}

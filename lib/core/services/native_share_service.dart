import 'package:flutter/services.dart';

/// Service interfacing with native Android sharing and document opening via MethodChannel.
class NativeShareService {
  NativeShareService._();

  static final NativeShareService instance = NativeShareService._();
  static const MethodChannel _channel =
      MethodChannel('com.example.abu_ali/native_share');

  /// Shares a local file (e.g. PDF or HTML) via Android standard share sheet (WhatsApp, Email, etc.).
  Future<bool> shareFile({
    required String filePath,
    String mimeType = 'application/pdf',
  }) async {
    try {
      final res = await _channel.invokeMethod<bool>('shareFile', {
        'filePath': filePath,
        'mimeType': mimeType,
      });
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Opens a local file using the system default viewer or print provider.
  Future<bool> openFile({
    required String filePath,
    String mimeType = 'application/pdf',
  }) async {
    try {
      final res = await _channel.invokeMethod<bool>('openFile', {
        'filePath': filePath,
        'mimeType': mimeType,
      });
      return res ?? false;
    } catch (_) {
      return false;
    }
  }
}

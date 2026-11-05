import 'dart:convert';
import 'dart:math';
import '../data/settings_repository.dart';

/// Pure-Dart cryptographic security service handling PIN hashing, salt generation,
/// and application lock state completely offline with zero third-party dependencies.
class SecurityService {
  SecurityService._();

  static final SecurityService instance = SecurityService._();
  final SettingsRepository _settingsRepo = SettingsRepository();

  static const String keyPinEnabled = 'security_pin_enabled';
  static const String keyPinHash = 'security_pin_hash';
  static const String keyPinSalt = 'security_pin_salt';
  static const String keyBiometricEnabled = 'security_biometric_enabled';
  static const String keyLockTimeout = 'security_lock_timeout_minutes';

  /// Generates a random cryptographic hex salt.
  String generateSalt([int length = 16]) {
    final rand = Random.secure();
    final bytes = List<int>.generate(length, (_) => rand.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Hashes a PIN with a salt using standard SHA-256.
  String hashPin(String pin, String salt) {
    return _sha256Hex(utf8.encode('$salt:$pin'));
  }

  /// Sets up or updates the application lock PIN.
  Future<void> setPin(String pin) async {
    final salt = generateSalt();
    final hash = hashPin(pin, salt);
    await _settingsRepo.saveAppSetting(keyPinSalt, salt);
    await _settingsRepo.saveAppSetting(keyPinHash, hash);
    await _settingsRepo.saveAppSetting(keyPinEnabled, '1');
  }

  /// Validates an entered PIN against the stored salt and hash.
  Future<bool> verifyPin(String enteredPin) async {
    final enabled = await isPinEnabled();
    if (!enabled) return true;

    final salt = await _settingsRepo.getAppSetting(keyPinSalt);
    final storedHash = await _settingsRepo.getAppSetting(keyPinHash);

    if (salt == null || storedHash == null) return false;
    final computedHash = hashPin(enteredPin, salt);
    return computedHash == storedHash;
  }

  /// Checks if PIN protection is active.
  Future<bool> isPinEnabled() async {
    final val = await _settingsRepo.getAppSetting(keyPinEnabled);
    return val == '1';
  }

  /// Disables PIN protection.
  Future<void> disablePin() async {
    await _settingsRepo.saveAppSetting(keyPinEnabled, '0');
    await _settingsRepo.saveAppSetting(keyPinHash, '');
    await _settingsRepo.saveAppSetting(keyPinSalt, '');
  }

  /// Checks if biometric authentication is enabled.
  Future<bool> isBiometricEnabled() async {
    final val = await _settingsRepo.getAppSetting(keyBiometricEnabled);
    return val == '1';
  }

  /// Toggles biometric authentication.
  Future<void> setBiometricEnabled(bool enabled) async {
    await _settingsRepo.saveAppSetting(
        keyBiometricEnabled, enabled ? '1' : '0');
  }

  /// Gets the lock timeout in minutes (0 = immediately on backgrounding).
  Future<int> getLockTimeoutMinutes() async {
    final val = await _settingsRepo.getAppSetting(keyLockTimeout);
    return int.tryParse(val ?? '0') ?? 0;
  }

  /// Sets the lock timeout in minutes.
  Future<void> setLockTimeoutMinutes(int minutes) async {
    await _settingsRepo.saveAppSetting(keyLockTimeout, minutes.toString());
  }

  /// Computes SHA-256 hex digest of given byte list.
  static String computeSha256(List<int> bytes) => _sha256Hex(bytes);

  // ===========================================================================
  // PURE DART SHA-256 ENGINE (NIST FIPS 180-4 COMPLIANT)
  // ===========================================================================
  static String _sha256Hex(List<int> message) {
    final bitLength = message.length * 8;
    final paddedWordsLength = (((bitLength + 64) >> 9) + 1) << 4;
    final extendedWords = List<int>.filled(paddedWordsLength, 0);

    for (int i = 0; i < message.length; i++) {
      extendedWords[i >> 2] |= (message[i] & 0xFF) << (24 - ((i % 4) * 8));
    }

    // Append padding bit
    extendedWords[bitLength >> 5] |= 0x80 << (24 - (bitLength % 32));

    // Append 64-bit original length
    extendedWords[paddedWordsLength - 1] = bitLength & 0xFFFFFFFF;
    extendedWords[paddedWordsLength - 2] = (bitLength / 0x100000000).floor();

    // Initial hash values (first 32 bits of fractional parts of square roots of first 8 primes)
    var h0 = 0x6a09e667;
    var h1 = 0xbb67ae85;
    var h2 = 0x3c6ef372;
    var h3 = 0xa54ff53a;
    var h4 = 0x510e527f;
    var h5 = 0x9b05688c;
    var h6 = 0x1f83d9ab;
    var h7 = 0x5be0cd19;

    // Constants (first 32 bits of fractional parts of cube roots of first 64 primes)
    const k = [
      0x428a2f98,
      0x71374491,
      0xb5c0fbcf,
      0xe9b5dba5,
      0x3956c25b,
      0x59f111f1,
      0x923f82a4,
      0xab1c5ed5,
      0xd807aa98,
      0x12835b01,
      0x243185be,
      0x550c7dc3,
      0x72be5d74,
      0x80deb1fe,
      0x9bdc06a7,
      0xc19bf174,
      0xe49b69c1,
      0xefbe4786,
      0x0fc19dc6,
      0x240ca1cc,
      0x2de92c6f,
      0x4a7484aa,
      0x5cb0a9dc,
      0x76f988da,
      0x983e5152,
      0xa831c66d,
      0xb00327c8,
      0xbf597fc7,
      0xc6e00bf3,
      0xd5a79147,
      0x06ca6351,
      0x14292967,
      0x27b70a85,
      0x2e1b2138,
      0x4d2c6dfc,
      0x53380d13,
      0x650a7354,
      0x766a0abb,
      0x81c2c92e,
      0x92722c85,
      0xa2bfe8a1,
      0xa81a664b,
      0xc24b8b70,
      0xc76c51a3,
      0xd192e819,
      0xd6990624,
      0xf40e3585,
      0x106aa070,
      0x19a4c116,
      0x1e376c08,
      0x2748774c,
      0x34b0bcb5,
      0x391c0cb3,
      0x4ed8aa4a,
      0x5b9cca4f,
      0x682e6ff3,
      0x748f82ee,
      0x78a5636f,
      0x84c87814,
      0x8cc70208,
      0x90befffa,
      0xa4506ceb,
      0xbef9a3f7,
      0xc67178f2,
    ];

    final w = List<int>.filled(64, 0);

    for (int i = 0; i < extendedWords.length; i += 16) {
      for (int t = 0; t < 16; t++) {
        w[t] = extendedWords[i + t];
      }
      for (int t = 16; t < 64; t++) {
        final s0 =
            _rotr(w[t - 15], 7) ^ _rotr(w[t - 15], 18) ^ (w[t - 15] >>> 3);
        final s1 =
            _rotr(w[t - 2], 17) ^ _rotr(w[t - 2], 19) ^ (w[t - 2] >>> 10);
        w[t] = (w[t - 16] + s0 + w[t - 7] + s1) & 0xFFFFFFFF;
      }

      var a = h0;
      var b = h1;
      var c = h2;
      var d = h3;
      var e = h4;
      var f = h5;
      var g = h6;
      var h = h7;

      for (int t = 0; t < 64; t++) {
        final s1 = _rotr(e, 6) ^ _rotr(e, 11) ^ _rotr(e, 25);
        final ch = (e & f) ^ ((~e) & g);
        final temp1 = (h + s1 + ch + k[t] + w[t]) & 0xFFFFFFFF;
        final s0 = _rotr(a, 2) ^ _rotr(a, 13) ^ _rotr(a, 22);
        final maj = (a & b) ^ (a & c) ^ (b & c);
        final temp2 = (s0 + maj) & 0xFFFFFFFF;

        h = g;
        g = f;
        f = e;
        e = (d + temp1) & 0xFFFFFFFF;
        d = c;
        c = b;
        b = a;
        a = (temp1 + temp2) & 0xFFFFFFFF;
      }

      h0 = (h0 + a) & 0xFFFFFFFF;
      h1 = (h1 + b) & 0xFFFFFFFF;
      h2 = (h2 + c) & 0xFFFFFFFF;
      h3 = (h3 + d) & 0xFFFFFFFF;
      h4 = (h4 + e) & 0xFFFFFFFF;
      h5 = (h5 + f) & 0xFFFFFFFF;
      h6 = (h6 + g) & 0xFFFFFFFF;
      h7 = (h7 + h) & 0xFFFFFFFF;
    }

    final out = [h0, h1, h2, h3, h4, h5, h6, h7];
    return out.map((v) => v.toRadixString(16).padLeft(8, '0')).join();
  }

  static int _rotr(int n, int shift) {
    return ((n >>> shift) | (n << (32 - shift))) & 0xFFFFFFFF;
  }
}

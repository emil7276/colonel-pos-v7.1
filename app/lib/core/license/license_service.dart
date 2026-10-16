import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LicenseInfo {
  final String licenseId;
  final String plan;
  final DateTime issuedAt;
  final DateTime? expiresAt;

  const LicenseInfo({
    required this.licenseId,
    required this.plan,
    required this.issuedAt,
    required this.expiresAt,
  });

  bool get isActive {
    final now = DateTime.now().toUtc();

    if (now.isBefore(issuedAt.toUtc())) {
      return false;
    }

    final expiry = expiresAt;
    return expiry == null || now.isBefore(expiry.toUtc());
  }
}

class LicenseService {
  static const String _licenseKey = 'cp_license';

  // Public key resmi yang sudah cocok dengan generator v7.2.
  static const String publicKeyBase64 =
      'ToLK9IwCbIaZSg2Emho11f6JC1KGeGO7uEtUjQNIoG4';

  static final Ed25519 _algorithm = Ed25519();

  static String lastError = '';

  static Future<LicenseInfo?> getLicense() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_licenseKey);

    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final issuedAt = DateTime.parse(data['issuedAt'] as String);
      final rawExpiry = data['expiresAt'];

      return LicenseInfo(
        licenseId: data['licenseId'] as String,
        plan: data['plan'] as String,
        issuedAt: issuedAt,
        expiresAt: rawExpiry == null
            ? null
            : DateTime.parse(rawExpiry as String),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<bool> saveLicense(String licenseCode) async {
    lastError = '';

    final license = await _verifyLicense(licenseCode);

    if (license == null) {
      return false;
    }

    final now = DateTime.now().toUtc();

    // Lisensi valid boleh disimpan sebelum tanggal mulainya.
    // Status aktif tetap ditentukan oleh LicenseInfo.isActive.
    final expiry = license.expiresAt;
    if (expiry != null && !now.isBefore(expiry.toUtc())) {
      lastError = 'Lisensi sudah kedaluwarsa';
      return false;
    }

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      _licenseKey,
      jsonEncode({
        'licenseId': license.licenseId,
        'plan': license.plan,
        'issuedAt': license.issuedAt.toIso8601String(),
        'expiresAt': license.expiresAt?.toIso8601String(),
      }),
    );

    lastError = 'OK';
    return true;
  }

  static Future<LicenseInfo?> _verifyLicense(
    String licenseCode,
  ) async {
    if (publicKeyBase64.isEmpty) {
      lastError = 'PUBLIC KEY kosong';
      return null;
    }

    try {
      final normalizedCode =
          licenseCode.replaceAll(RegExp(r'\s+'), '');
      final parts = normalizedCode.split('.');

      if (parts.length != 2) {
        lastError = 'Format kode tidak valid';
        return null;
      }

      final payloadBytes =
          base64Url.decode(base64Url.normalize(parts[0]));
      final signatureBytes =
          base64Url.decode(base64Url.normalize(parts[1]));
      final publicKeyBytes =
          base64Url.decode(base64Url.normalize(publicKeyBase64));

      final publicKey = SimplePublicKey(
        publicKeyBytes,
        type: KeyPairType.ed25519,
      );

      final signature = Signature(
        signatureBytes,
        publicKey: publicKey,
      );

      final valid = await _algorithm.verify(
        payloadBytes,
        signature: signature,
      );

      if (!valid) {
        lastError = 'Signature tidak cocok dengan public key';
        return null;
      }

      final data =
          jsonDecode(utf8.decode(payloadBytes)) as Map<String, dynamic>;

      final licenseId = data['licenseId'] as String;
      final plan = data['plan'] as String;
      final issuedAt = DateTime.parse(data['issuedAt'] as String);
      final rawExpiry = data['expiresAt'];

      if (licenseId.trim().isEmpty) {
        lastError = 'ID lisensi kosong';
        return null;
      }

      const supportedPlans = {
        '7D',
        '1M',
        '3M',
        '1Y',
        'LIFETIME',
        'CUSTOM',
      };

      if (!supportedPlans.contains(plan)) {
        lastError = 'Jenis lisensi tidak dikenal';
        return null;
      }

      // Hanya LIFETIME yang boleh tidak memiliki tanggal kedaluwarsa.
      if (plan == 'LIFETIME' && rawExpiry != null) {
        lastError = 'Format lisensi LIFETIME tidak valid';
        return null;
      }

      if (plan != 'LIFETIME' && rawExpiry == null) {
        lastError = 'Tanggal kedaluwarsa tidak tersedia';
        return null;
      }

      final expiresAt = rawExpiry == null
          ? null
          : DateTime.parse(rawExpiry as String);

      if (expiresAt != null &&
          !expiresAt.isAfter(issuedAt)) {
        lastError = 'Rentang tanggal lisensi tidak valid';
        return null;
      }

      return LicenseInfo(
        licenseId: licenseId,
        plan: plan,
        issuedAt: issuedAt,
        expiresAt: expiresAt,
      );
    } catch (e) {
      lastError = 'Gagal verifikasi: $e';
      return null;
    }
  }

  static Future<void> clearLicense() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_licenseKey);
  }
}

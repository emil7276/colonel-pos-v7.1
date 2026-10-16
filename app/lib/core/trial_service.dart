import 'package:shared_preferences/shared_preferences.dart';

class TrialStatus {
  final bool active;
  final DateTime startedAt;
  final DateTime expiresAt;

  const TrialStatus({
    required this.active,
    required this.startedAt,
    required this.expiresAt,
  });
}

class TrialService {
  static const Duration trialDuration = Duration(days: 3);
  static const String _startedAtKey = 'cp_trial_started_at';

  /// Membaca status saja. Tidak memulai trial secara otomatis.
  /// Mengembalikan null jika trial belum pernah dimulai.
  static Future<TrialStatus?> status() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_startedAtKey);

    if (saved == null) return null;

    final startedAt = DateTime.tryParse(saved);
    if (startedAt == null) {
      throw StateError(
        'Data waktu mulai trial tidak valid. Trial tidak dimulai ulang.',
      );
    }

    final expiresAt = startedAt.add(trialDuration);

    return TrialStatus(
      active: DateTime.now().isBefore(expiresAt),
      startedAt: startedAt,
      expiresAt: expiresAt,
    );
  }

  /// Memulai trial hanya jika belum pernah dimulai.
  /// Timestamp yang sudah ada tetapi rusak tidak di-reset otomatis.
  static Future<TrialStatus> startIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_startedAtKey);

    late final DateTime startedAt;

    if (saved == null) {
      startedAt = DateTime.now();
      await prefs.setString(
        _startedAtKey,
        startedAt.toIso8601String(),
      );
    } else {
      final parsed = DateTime.tryParse(saved);

      if (parsed == null) {
        throw StateError(
          'Data waktu mulai trial tidak valid. Trial tidak dimulai ulang.',
        );
      }

      startedAt = parsed;
    }

    final expiresAt = startedAt.add(trialDuration);

    return TrialStatus(
      active: DateTime.now().isBefore(expiresAt),
      startedAt: startedAt,
      expiresAt: expiresAt,
    );
  }
}

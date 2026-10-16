import 'package:flutter/material.dart';
import 'app.dart';
import 'data/database.dart';
import 'core/license/license_service.dart';
import 'core/theme/skin_controller.dart';
import 'core/trial_service.dart';
import 'features/auth/trial_expired_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final license = await LicenseService.getLicense();

  if (license != null && license.isActive) {
    await DB.database;
    await SkinController.load();
    runApp(const ColonelApp());
    return;
  }

  TrialStatus? trial;

  try {
    trial = await TrialService.status();

  } on StateError {
    // Timestamp tersimpan tidak valid: jangan reset trial.
    await SkinController.load();
    runApp(const ActivationApp());
    return;
  }

  if (trial != null && trial.active) {
    await DB.database;
    await SkinController.load();
    runApp(const ColonelApp());
    return;
  }

  // Trial belum dimulai: izinkan pengguna menyiapkan menu pertama.
  // Trial baru dimulai setelah menu pertama berhasil disimpan dan
  // pengguna memilih Coba Gratis.
  if (trial == null) {
    await DB.database;
    await SkinController.load();
    runApp(const ColonelApp());
    return;
  }

  // Trial kedaluwarsa: tampilkan halaman aktivasi.
  await SkinController.load();
  runApp(const ActivationApp());
}

class ActivationApp extends StatelessWidget {
  const ActivationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const ColonelApp(home: ActivationPage());
  }
}

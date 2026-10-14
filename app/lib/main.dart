import 'package:flutter/material.dart';
import 'app.dart';
import 'data/database.dart';
import 'core/license/license_service.dart';
import 'core/theme/skin_controller.dart';
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

  // Trial 7 hari dihapus. Aktivasi wajib sebelum login/POS.
  runApp(const ActivationApp());
}

class ActivationApp extends StatelessWidget {
  const ActivationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ActivationPage(),
    );
  }
}

import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/widgets.dart';
import 'store_page.dart';
import 'menu_page.dart';
import 'stock_page.dart';
import 'users_page.dart';
import 'qris_page.dart';
import 'backup_page.dart';
import 'printer_page.dart';
import 'qa_page.dart';
import 'contact_page.dart';
import 'language_page.dart';
class SettingsPage
    extends StatelessWidget {
  final String username;

  const SettingsPage({
    super.key,
    required this.username,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding:
          const EdgeInsets.all(16),
      children: [
        settingsTile(
          context,
          'Bahasa / Language',
          Icons.language_rounded,
          const LanguagePage(),
        ),
        settingsTile(
          context,
          'Identitas Toko',
          Icons.store,
          const StorePage(),
        ),
        settingsTile(
          context,
          'Menu & Harga',
          Icons.restaurant_menu,
          const MenuPage(),
        ),
        settingsTile(
          context,
          'Stok',
          Icons.inventory_2,
          const StockPage(),
        ),
        settingsTile(
          context,
          'Manajemen Pengguna',
          Icons.people,
          const UsersPage(),
        ),
        settingsTile(
          context,
          'QRIS',
          Icons.qr_code_2,
          const QrisPage(),
        ),
        settingsTile(
          context,
          'Printer',
          Icons.print_outlined,
          const PrinterPage(),
        ),
        settingsTile(
          context,
          'Backup',
          Icons.backup_outlined,
          const BackupPage(),
        ),
        settingsTile(
          context,
          'Q&A mengenai aplikasi ini',
          Icons.help_outline_rounded,
          const QaPage(),
        ),
        settingsTile(
          context,
          'Hubungi Kami',
          Icons.support_agent_rounded,
          const ContactPage(),
        ),
        const CopyrightFooter(),
      ],
    );
  }

  Widget settingsTile(
    BuildContext context,
    String title,
    IconData icon,
    Widget page,
  ) {
    return Card(
      child: ListTile(
        leading: Icon(
          icon,
          color: red,
        ),
        title: Text(title),
        trailing: const Icon(
          Icons.chevron_right,
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => page,
            ),
          );
        },
      ),
    );
  }
}

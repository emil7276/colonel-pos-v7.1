import 'package:flutter/material.dart';

import '../../core/app_localizations.dart';
import '../../core/constants.dart';

class QaPage extends StatelessWidget {
  const QaPage({super.key});

  static List<(String, String)> get items => [
        (
          AppLocalizations.t(
            'Apa fungsi CP Colonel POS?',
            'What is CP Colonel POS used for?',
          ),
          AppLocalizations.t(
            'CP Colonel POS membantu mengelola menu dan harga, stok, transaksi penjualan, laporan, retur, pengguna, backup data, printer, QRIS, dan keuangan.',
            'CP Colonel POS helps manage menus and prices, inventory, sales transactions, reports, returns, users, data backups, printers, QRIS, and finances.',
          ),
        ),
        (
          AppLocalizations.t(
            'Bagaimana cara membuat transaksi?',
            'How do I create a transaction?',
          ),
          AppLocalizations.t(
            'Masuk ke menu Transaksi, pilih menu yang dibeli, atur jumlahnya, isi pelanggan bila perlu, gunakan diskon jika diperlukan, lalu tekan BAYAR dan pilih metode pembayaran.',
            'Open Transactions, select the items being purchased, set the quantity, add a customer if needed, apply a discount if necessary, then tap PAY and choose a payment method.',
          ),
        ),
        (
          AppLocalizations.t(
            'Apa yang terjadi setelah transaksi berhasil?',
            'What happens after a transaction is completed?',
          ),
          AppLocalizations.t(
            'Transaksi tersimpan, stok otomatis berkurang, laporan ikut diperbarui, dan jika printer otomatis diaktifkan maka struk dapat langsung dicetak.',
            'The transaction is saved, inventory is automatically reduced, reports are updated, and if automatic printing is enabled, the receipt can be printed immediately.',
          ),
        ),
        (
          AppLocalizations.t(
            'Bagaimana mengatur menu dan harga?',
            'How do I manage menus and prices?',
          ),
          AppLocalizations.t(
            'Administrator dapat membuka Pengaturan lalu memilih Menu & Harga. Dari sana menu dapat ditambah, diubah, diaktifkan, dinonaktifkan, dan harganya diperbarui.',
            'Administrators can open Settings and select Menu & Prices. From there, menus can be added, edited, enabled, disabled, and their prices updated.',
          ),
        ),
        (
          AppLocalizations.t(
            'Bagaimana mengelola stok?',
            'How do I manage inventory?',
          ),
          AppLocalizations.t(
            'Administrator dapat membuka Pengaturan lalu Stok untuk melihat dan memperbarui jumlah stok barang. Stok juga otomatis berkurang ketika transaksi berhasil.',
            'Administrators can open Settings and select Inventory to view and update item stock quantities. Inventory is also automatically reduced when a transaction is completed.',
          ),
        ),
        (
          AppLocalizations.t(
            'Apa fungsi Laporan?',
            'What is the Reports feature used for?',
          ),
          AppLocalizations.t(
            'Laporan digunakan untuk melihat ringkasan penjualan, barang terjual, pelanggan, omzet, transaksi retur, dan informasi penjualan berdasarkan periode.',
            'Reports are used to view sales summaries, items sold, customers, revenue, return transactions, and sales information by period.',
          ),
        ),
        (
          AppLocalizations.t(
            'Bagaimana melakukan retur transaksi?',
            'How do I process a transaction return?',
          ),
          AppLocalizations.t(
            'Administrator dapat memilih transaksi yang akan diretur dari bagian laporan/transaksi yang tersedia. Setelah retur berhasil, stok barang dikembalikan dan transaksi ditandai sebagai retur.',
            'Administrators can select a transaction to return from the available reports or transaction section. After the return is completed, item stock is restored and the transaction is marked as returned.',
          ),
        ),
        (
          AppLocalizations.t(
            'Apa fungsi Keuangan?',
            'What is the Finance feature used for?',
          ),
          AppLocalizations.t(
            'Keuangan khusus Administrator digunakan untuk mencatat pengeluaran dan melihat pendapatan, pengeluaran, serta hasil bersih. Pengeluaran tidak mengubah jumlah transaksi atau omzet pada laporan penjualan.',
            'Finance, available to Administrators, is used to record expenses and view income, expenses, and net results. Expenses do not change the transaction count or revenue shown in sales reports.',
          ),
        ),
        (
          AppLocalizations.t(
            'Bagaimana melakukan Backup dan Restore?',
            'How do I perform Backup and Restore?',
          ),
          AppLocalizations.t(
            'Administrator dapat membuka Pengaturan > Backup. Backup digunakan untuk menyimpan data aplikasi, sedangkan Restore digunakan untuk mengembalikan data dari file backup.',
            'Administrators can open Settings > Backup. Backup is used to save application data, while Restore is used to restore data from a backup file.',
          ),
        ),
        (
          AppLocalizations.t(
            'Apa perbedaan Administrator dan Kasir?',
            'What is the difference between an Administrator and a Cashier?',
          ),
          AppLocalizations.t(
            'Kasir fokus pada transaksi. Administrator memiliki akses tambahan untuk pengaturan, menu, stok, pengguna, QRIS, printer, backup, laporan administrasi, dan Keuangan.',
            'Cashiers focus on transactions. Administrators have additional access to settings, menus, inventory, users, QRIS, printers, backups, administrative reports, and Finance.',
          ),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppLocalizations.t(
            'Q&A mengenai aplikasi ini',
            'App Q&A',
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
            child: Text(
              AppLocalizations.t(
                'Panduan singkat CP Colonel POS',
                'CP Colonel POS Quick Guide',
              ),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          ...items.map(
            (item) => Card(
              child: ExpansionTile(
                leading: const Icon(
                  Icons.help_outline_rounded,
                  color: red,
                ),
                title: Text(
                  item.$1,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      item.$2,
                      style: const TextStyle(
                        color: inkMuted,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

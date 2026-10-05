import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants.dart';
import '../../core/license/license_service.dart';
import '../../core/utils.dart';
import '../../core/widgets.dart';
import '../../data/database.dart';
import '../../models/models.dart';
import '../settings/finance_page.dart';

class DashboardPage extends StatefulWidget {
  final String username;
  final String role;
  final ValueChanged<String>? onQuickAccess;

  const DashboardPage({
    super.key,
    required this.username,
    this.role = 'Kasir',
    this.onQuickAccess,
  });
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int omzet = 0, transaksi = 0, item = 0, pengeluaran = 0;
  List<SaleModel> recent = [];

  DateTime selectedDate = DateTime.now();
  DateTime? selectedEndDate;

  DateTime get start =>
      DateTime(selectedDate.year, selectedDate.month, selectedDate.day);

  DateTime get end =>
      selectedEndDate == null
          ? start.add(const Duration(days: 1))
          : DateTime(
              selectedEndDate!.year,
              selectedEndDate!.month,
              selectedEndDate!.day,
            ).add(const Duration(days: 1));

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final all = await DB.sales();
    var om = 0;
    var tr = 0;

    for (final raw in all) {
      final s = SaleModel.fromMap(raw);
      final d = DateTime.tryParse(s.time);
      if (d != null && !d.isBefore(start) && d.isBefore(end) && !s.returned) {
        om += s.total;
        tr++;
      }
    }

    final db = await DB.database;
    final ymd = (DateTime d) {
      final y = d.year.toString().padLeft(4, '0');
      final m = d.month.toString().padLeft(2, '0');
      final day = d.day.toString().padLeft(2, '0');
      return '$y-$m-$day';
    };
    final from = '${ymd(start)} 00:00:00';
    final to = '${ymd(end)} 00:00:00';
    final rows = await db.rawQuery(
      '''SELECT COALESCE(SUM(si.qty),0) jumlah
         FROM sale_items si INNER JOIN sales s ON s.id=si.sale_id
         WHERE s.sale_time >= ? AND s.sale_time < ? AND s.returned=0''',
      [from, to],
    );

    var expenseToday = 0;
    if (widget.role == 'Administrator') {
      expenseToday = await DB.expenseTotal(start, end);
    }

    if (!mounted) return;
    setState(() {
      omzet = om;
      transaksi = tr;
      item = (rows.first['jumlah'] as num).toInt();
      pengeluaran = expenseToday;
      recent = all.take(5).map(SaleModel.fromMap).toList();
    });
  }


  Future<void> pickDateRange() async {
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: selectedDate,
        end: selectedEndDate ?? selectedDate,
      ),
    );

    if (r != null) {
      setState(() {
        selectedDate = r.start;
        selectedEndDate = r.end;
      });

      await load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [

          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Dashboard',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '${displayDate(start)} - ${displayDate(end.subtract(const Duration(days: 1)))}',
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: pickDateRange,
                icon: const Icon(Icons.calendar_month_outlined),
                label: const Text('Pilih Rentang'),
              ),
            ],
          ),

          const SizedBox(height: 12),

          CpGradientCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('AKTIVASI LISENSI', style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      const Text('Berlangganan Sekarang', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                  FilledButton.icon(
                    onPressed: () async {
                      final controller = TextEditingController();

                      final code = await showDialog<String>(
                        context: context,
                        builder: (dialogContext) => AlertDialog(
                          title: const Text('Aktivasi Lisensi'),
                          content: TextField(
                            controller: controller,
                            maxLines: 4,
                            decoration: const InputDecoration(
                              labelText: 'Kode Aktivasi',
                              hintText: 'Tempel kode aktivasi di sini',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              child: const Text('BATAL'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(
                                dialogContext,
                                controller.text.trim(),
                              ),
                              child: const Text('AKTIVASI'),
                            ),
                          ],
                        ),
                      );

                      controller.dispose();

                      if (code == null || code.isEmpty || !context.mounted) return;

                      final ok = await LicenseService.saveLicense(code);

                      if (!context.mounted) return;

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            ok
                                ? 'Lisensi berhasil diaktifkan.'
                                : 'Gagal: ${LicenseService.lastError}',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.key_rounded, size: 18),
                    label: const Text('Aktivasi'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Center(
            child: TextButton(
              onPressed: () async {
                final uri = Uri(
                  scheme: 'mailto',
                  path: 'cp.colonel.pos@gmail.com',
                  queryParameters: {
                    'subject': 'Saya ingin menambah layanan',
                  },
                );
                await launchUrl(uri);
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Berlangganan Sekarang • cp.colonel.pos@gmail.com',
                style: TextStyle(
                  fontSize: 12,
                  color: red,
                  fontWeight: FontWeight.w800,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const SizedBox(height: 4),
                    LayoutBuilder(
            builder: (context, c) {
              final cross = c.maxWidth > 700 ? 4 : 2;
              return GridView.count(
                crossAxisCount: cross,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.72,
                children: [
                  _stat('Omzet', rp(omzet), Icons.payments_rounded, true),
                  _stat('Transaksi', '$transaksi', Icons.receipt_long_rounded, false, onTap: showTransactions),
                  _stat('Item Terjual', '$item', Icons.fastfood_rounded, false, onTap: showItemsSold),
                  if (widget.role == 'Administrator')
                    _stat(
                      'Pengeluaran',
                      rp(pengeluaran),
                      Icons.account_balance_wallet_rounded,
                      false,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const FinancePage(),
                          ),
                        );
                      },
                    )
                  else
                    _stat(
                      'Status',
                      'V6.5.0',
                      Icons.verified_rounded,
                      false,
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          const Text('Akses Cepat', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, c) {
              final cols = c.maxWidth >= 700 ? 4 : 2;
              return GridView.count(
                crossAxisCount: cols,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 2.25,
                children: [
                  _quick('Transaksi Baru', Icons.point_of_sale_rounded, 'transaksi'),
                  _quick('Laporan', Icons.analytics_rounded, 'laporan'),
                  if (widget.role == 'Administrator')
                    _quick('Produk', Icons.restaurant_menu_rounded, 'produk'),
                  if (widget.role == 'Administrator')
                    _quick('Printer', Icons.print_rounded, 'printer'),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          const Text('Transaksi Terbaru', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
          const SizedBox(height: 9),
          if (recent.isEmpty)
            Card(child: Padding(padding: const EdgeInsets.all(18), child: Text('Belum ada transaksi.', style: Theme.of(context).textTheme.bodyMedium)))
          else
            ...recent.map(
              (s) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
                  leading: CircleAvatar(backgroundColor: redSoft, foregroundColor: red, child: const Icon(Icons.receipt_long_rounded)),
                  title: Text(s.no, style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('${s.time} • ${s.cashier}'),
                  trailing: Text(rp(s.total), style: const TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
            ),
          const CopyrightFooter(),
        ],
      ),
    );
  }


  Widget _quick(String title, IconData icon, String action) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => widget.onQuickAccess?.call(action),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: redSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: red, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, size: 19, color: inkMuted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(String title, String value, IconData icon, bool primary, {VoidCallback? onTap}) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: primary ? redSoft : const Color(0xFFF3F3F5), borderRadius: BorderRadius.circular(11)),
                child: Icon(icon, color: primary ? red : ink, size: 19),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(children: [Expanded(child: Text(title, style: const TextStyle(color: inkMuted, fontSize: 11, fontWeight: FontWeight.w700))), if (onTap != null) const Icon(Icons.chevron_right_rounded, size: 17, color: inkMuted)]),
                    const SizedBox(height: 2),
                    FittedBox(alignment: Alignment.centerLeft, child: Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: primary ? red : ink))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> showTransactions() async {
    final summary = await DB.daySummary(DateTime.now());
    final sales = (summary['sales'] as List).map((e) => SaleModel.fromMap(e as Map<String, dynamic>)).toList();
    if (!mounted) return;
    if (sales.isEmpty) {
      await showDialog<void>(context: context, builder: (_) => const AlertDialog(title: Text('Transaksi'), content: Text('Belum ada transaksi hari ini.')));
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * .72,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Transaksi Hari Ini', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    itemCount: sales.length,
                    itemBuilder: (_, i) {
                      final sale = sales[i];
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.receipt_long_rounded, color: red),
                        title: Text(sale.no, style: const TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Text('${sale.time} • ${sale.payment}'),
                        trailing: Text(rp(sale.total), style: const TextStyle(fontWeight: FontWeight.w800)),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> showItemsSold() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    final rows = await DB.bestSelling(start, end);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Item Terjual Hari Ini', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              if (rows.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('Belum ada item terjual hari ini.')),
              ...rows.take(12).map((r) => ListTile(
                dense: true,
                leading: CircleAvatar(radius: 17, backgroundColor: redSoft, foregroundColor: red, child: Text('${r['qty']}')),
                title: Text(r['name'].toString(), style: const TextStyle(fontWeight: FontWeight.w800)),
                trailing: Text(rp(r['omzet'] as num), style: const TextStyle(fontWeight: FontWeight.w800)),
              )),
            ],
          ),
        ),
      ),
    );
  }

}

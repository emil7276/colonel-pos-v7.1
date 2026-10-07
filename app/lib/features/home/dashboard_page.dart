import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
  int omzet = 0, transaksi = 0, item = 0, retur = 0, pengeluaran = 0, piutang = 0, hutang = 0, labaBersih = 0;
  int piutangReminder = 0, hutangReminder = 0;
  List<SaleModel> recent = [];
  List<_TrendPoint> trendPoints = [];
  int selectedTrendIndex = -1;

  Map<String, int> paymentTotals = {
    'Tunai': 0,
    'QRIS': 0,
    'Transfer': 0,
    'Bayar Tunda': 0,
  };

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
    final summary = await DB.rangeSummary(start, end);

    final calculatedPayments = <String, int>{
      'Tunai': 0,
      'QRIS': 0,
      'Transfer': 0,
      'Bayar Tunda': 0,
    };

    final summarySales =
        (summary['sales'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();

    final saleNetTotals = <int, int>{};

    for (final sale in summarySales) {
      var payment = (sale['payment'] ?? 'Tunai').toString().trim();

      if (payment.toLowerCase() == 'cash' ||
          payment.toLowerCase() == 'tunai') {
        payment = 'Tunai';
      } else if (payment.toLowerCase() == 'qris') {
        payment = 'QRIS';
      } else if (payment.toLowerCase() == 'transfer') {
        payment = 'Transfer';
      } else if (payment.toLowerCase() == 'bayar tunda' ||
          payment.toLowerCase() == 'bayar nanti') {
        payment = 'Bayar Tunda';
      }

      if (calculatedPayments.containsKey(payment)) {
        final gross = (sale['total'] as num?)?.toInt() ?? 0;
        final returned = await DB.returnedAmount(
          (sale['id'] as num).toInt(),
        );
        final net = gross - returned;
        final saleId = (sale['id'] as num).toInt();

        saleNetTotals[saleId] = net;

        calculatedPayments[payment] =
            (calculatedPayments[payment] ?? 0) + net;
      }
    }

    final trendData = widget.role == 'Administrator'
        ? await _buildTrendPoints(summarySales, saleNetTotals)
        : <_TrendPoint>[];

    var expenseTotal = 0;
    var expenseDebt = 0;
    var receivable = 0;
    var reminderReceivable = 0;
    var reminderPayable = 0;

    if (widget.role == 'Administrator') {
      expenseTotal = await DB.expenseTotal(start, end);
      final activePayables = await DB.payables();
      expenseDebt = activePayables.fold<int>(
        0,
        (sum, item) =>
            sum + ((item['amount'] as num?)?.toInt() ?? 0),
      );
      receivable = await DB.payLaterTotal(start, end);
      final reminders = await DB.reminderItems();
      final storage = const FlutterSecureStorage();
      final activeReminders = <Map<String, dynamic>>[];

      for (final item in reminders) {
        final key =
            'cp_reminder_handled_${item['type']}_${item['id']}_${item['due_date']}';

        if (await storage.read(key: key) != '1') {
          activeReminders.add(item);
        }
      }

      reminderReceivable = activeReminders
          .where((item) => item['type'] == 'piutang')
          .length;

      reminderPayable = activeReminders
          .where((item) => item['type'] == 'hutang')
          .length;
    }

    final netIncome = summary['omzet'] as int;
    final netProfit = netIncome - expenseTotal;

    if (!mounted) return;

    setState(() {
      omzet = netIncome;
      transaksi = summary['transaksi'] as int;
      item = summary['item'] as int;
      retur = summary['returned'] as int;
      pengeluaran = expenseTotal;
      piutang = receivable;
      hutang = expenseDebt;
      piutangReminder = reminderReceivable;
      hutangReminder = reminderPayable;
      labaBersih = netProfit;
      paymentTotals = calculatedPayments;
      trendPoints = trendData;
      selectedTrendIndex =
          trendData.isEmpty ? -1 : trendData.length - 1;

      recent = (summary['sales'] as List)
          .map((e) => SaleModel.fromMap(e as Map<String, dynamic>))
          .take(5)
          .toList();
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
                          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
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
                  _stat(
                    'Omzet',
                    rp(omzet),
                    Icons.payments_rounded,
                    true,
                    onTap: showOmzet,
                  ),
                  _stat(
                    'Transaksi',
                    '$transaksi',
                    Icons.receipt_long_rounded,
                    false,
                    onTap: showTransactions,
                  ),
                  _stat(
                    'Retur',
                    '$retur',
                    Icons.assignment_return_rounded,
                    false,
                    onTap: showReturns,
                  ),
                  if (widget.role == 'Administrator') ...[
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
                    ),
                    _stat(
                      'Piutang',
                      rp(piutang),
                      Icons.account_balance_rounded,
                      false,
                      reminder: piutangReminder > 0,
                      onTap: showReceivables,
                    ),
                    _stat(
                      'Hutang',
                      rp(hutang),
                      Icons.receipt_long_rounded,
                      false,
                      reminder: hutangReminder > 0,
                      onTap: showPayables,
                    ),
                    _stat(
                      'Laba Bersih',
                      rp(labaBersih),
                      Icons.trending_up_rounded,
                      false,
                      onTap: showNetIncome,
                    ),
                    _stat(
                      'Item Terjual',
                      '$item',
                      Icons.inventory_2_rounded,
                      false,
                    ),
                  ],
                ],
              );
            },
          ),
          if (widget.role == 'Administrator') ...[
            const SizedBox(height: 18),
            _paymentCard(),
          ],
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
          if (widget.role == 'Administrator') ...[
            const SizedBox(height: 18),
            _trendChartCard(),
          ],
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
                  onTap: () => _showSaleDetail(s),
                ),
              ),
            ),
          const CopyrightFooter(),
        ],
      ),
    );
  }


  String _trendModeLabel() {
    final days = end.difference(start).inDays;

    if (days <= 1) return 'Per jam';
    if (days <= 31) return 'Per hari';
    return 'Per bulan';
  }

  Widget _trendChartCard() {
    if (trendPoints.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: redSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.show_chart_rounded,
                      color: red,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 11),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Grafik Keuangan',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Belum ada data pada rentang ini.',
                          style: TextStyle(
                            color: inkMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    final safeIndex = selectedTrendIndex.clamp(
      0,
      trendPoints.length - 1,
    );
    final selected = trendPoints[safeIndex];

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 15, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: redSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.show_chart_rounded,
                    color: red,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 11),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Grafik Keuangan',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Omzet • Biaya • Hasil Bersih',
                        style: TextStyle(
                          color: inkMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F7),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    _trendModeLabel(),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: inkMuted,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),
            Wrap(
              spacing: 14,
              runSpacing: 7,
              children: const [
                _TrendLegend(
                  label: 'Omzet',
                  color: red,
                ),
                _TrendLegend(
                  label: 'Biaya',
                  color: Color(0xFFE38B22),
                ),
                _TrendLegend(
                  label: 'Hasil Bersih',
                  color: Color(0xFF2E9B63),
                ),
              ],
            ),
            const SizedBox(height: 7),
            SizedBox(
              height: 245,
              width: double.infinity,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (details) {
                      final left = 54.0;
                      final right = constraints.maxWidth - 12.0;
                      final usable = right - left;

                      if (usable <= 0 || trendPoints.length == 1) {
                        setState(() {
                          selectedTrendIndex = 0;
                        });
                        return;
                      }

                      final x = details.localPosition.dx
                          .clamp(left, right);

                      final ratio = (x - left) / usable;
                      final index = (ratio * (trendPoints.length - 1))
                          .round()
                          .clamp(0, trendPoints.length - 1);

                      setState(() {
                        selectedTrendIndex = index;
                      });
                    },
                    child: CustomPaint(
                      painter: _TrendChartPainter(
                        points: trendPoints,
                        selectedIndex: safeIndex,
                      ),
                      size: const Size(double.infinity, 245),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 2),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F7F8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFEAEAEF),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Periode Terpilih • ${selected.label}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  _TrendValue(
                    label: 'Omzet',
                    value: selected.omzet,
                    color: red,
                  ),
                  const SizedBox(width: 13),
                  _TrendValue(
                    label: 'Biaya',
                    value: selected.biaya,
                    color: Color(0xFFE38B22),
                  ),
                  const SizedBox(width: 13),
                  _TrendValue(
                    label: 'Bersih',
                    value: selected.bersih,
                    color: Color(0xFF2E9B63),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 9),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
              decoration: BoxDecoration(
                color: redSoft,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFEAEAEF),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Total Periode',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _TrendValue(
                          label: 'Omzet',
                          value: omzet,
                          color: red,
                        ),
                      ),
                      Expanded(
                        child: _TrendValue(
                          label: 'Biaya',
                          value: pengeluaran,
                          color: Color(0xFFE38B22),
                        ),
                      ),
                      Expanded(
                        child: _TrendValue(
                          label: 'Bersih',
                          value: labaBersih,
                          color: Color(0xFF2E9B63),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<List<_TrendPoint>> _buildTrendPoints(
    List<Map<String, dynamic>> sales,
    Map<int, int> saleNetTotals,
  ) async {
    final expenses = await DB.expenses(start, end);
    final days = end.difference(start).inDays;

    final mode = days <= 1
        ? _TrendMode.hour
        : days <= 31
            ? _TrendMode.day
            : _TrendMode.month;

    final buckets = <String, _TrendAccumulator>{};

    DateTime cursor;
    if (mode == _TrendMode.month) {
      cursor = DateTime(start.year, start.month, 1);
    } else {
      cursor = start;
    }

    while (cursor.isBefore(end)) {
      final key = _trendKey(cursor, mode);

      buckets.putIfAbsent(
        key,
        () => _TrendAccumulator(
          bucket: cursor,
          label: _trendLabel(cursor, mode),
        ),
      );

      if (mode == _TrendMode.hour) {
        cursor = cursor.add(const Duration(hours: 1));
      } else if (mode == _TrendMode.day) {
        cursor = cursor.add(const Duration(days: 1));
      } else {
        cursor = DateTime(cursor.year, cursor.month + 1, 1);
      }
    }

    for (final sale in sales) {
      final rawDate = sale['sale_time']?.toString() ?? '';
      final date = DateTime.tryParse(rawDate);

      if (date == null) continue;

      final key = _trendKey(date.toLocal(), mode);
      final bucket = buckets[key];

      if (bucket == null) continue;

      final saleId = (sale['id'] as num?)?.toInt();
      final net = saleId == null
          ? (sale['total'] as num?)?.toInt() ?? 0
          : saleNetTotals[saleId] ??
              (sale['total'] as num?)?.toInt() ??
              0;

      bucket.omzet += net;
    }

    for (final expense in expenses) {
      final status = (expense['payment_status'] ?? '')
          .toString()
          .trim()
          .toLowerCase();

      if (status != 'lunas' && status != 'sudah dibayar') {
        continue;
      }

      final rawDate = expense['expense_date']?.toString() ?? '';
      var date = DateTime.tryParse(rawDate);

      if (date == null) continue;

      date = date.toLocal();

      // Data pengeluaran hanya menyimpan tanggal, bukan jam.
      // Pada mode per jam ditempatkan di ujung hari agar tidak
      // terlihat seperti biaya terjadi di awal hari.
      if (mode == _TrendMode.hour) {
        date = DateTime(date.year, date.month, date.day, 23);
      }

      final key = _trendKey(date, mode);
      final bucket = buckets[key];

      if (bucket == null) continue;

      bucket.biaya += (expense['amount'] as num?)?.toInt() ?? 0;
    }

    return buckets.values
        .map(
          (bucket) => _TrendPoint(
            bucket: bucket.bucket,
            label: bucket.label,
            omzet: bucket.omzet,
            biaya: bucket.biaya,
            bersih: bucket.omzet - bucket.biaya,
          ),
        )
        .toList();
  }

  String _trendKey(DateTime date, _TrendMode mode) {
    if (mode == _TrendMode.hour) {
      return '${date.year.toString().padLeft(4, '0')}-'
          '${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}-'
          '${date.hour.toString().padLeft(2, '0')}';
    }

    if (mode == _TrendMode.day) {
      return '${date.year.toString().padLeft(4, '0')}-'
          '${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}';
    }

    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}';
  }

  String _trendLabel(DateTime date, _TrendMode mode) {
    if (mode == _TrendMode.hour) {
      return '${date.hour.toString().padLeft(2, '0')}:00';
    }

    if (mode == _TrendMode.day) {
      return '${date.day.toString().padLeft(2, '0')}/'
          '${date.month.toString().padLeft(2, '0')}';
    }

    return '${date.month.toString().padLeft(2, '0')}/'
        '${date.year.toString().substring(2)}';
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

  Widget _stat(
    String title,
    String value,
    IconData icon,
    bool primary, {
    VoidCallback? onTap,
    bool reminder = false,
  }) {
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              color: inkMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (reminder)
                          Container(
                            width: 9,
                            height: 9,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                        if (onTap != null)
                          const Icon(
                            Icons.chevron_right_rounded,
                            size: 17,
                            color: inkMuted,
                          ),
                      ],
                    ),
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
    final summary = await DB.rangeSummary(start, end);
    final sales = (summary['sales'] as List)
        .map((e) => SaleModel.fromMap(e as Map<String, dynamic>))
        .toList();

    await _showSalesSheet(
      title: 'Riwayat Transaksi',
      sales: sales,
    );
  }

  Future<void> showOmzet() async {
    final summary = await DB.rangeSummary(start, end);
    final sales = (summary['sales'] as List)
        .map((e) => SaleModel.fromMap(e as Map<String, dynamic>))
        .toList();

    await _showSalesSheet(
      title: 'Riwayat Omzet',
      sales: sales,
      showNetTotal: true,
    );
  }

  Future<void> showReturns() async {
    final summary = await DB.rangeSummary(start, end);
    final sales = (summary['returnedSales'] as List)
        .map((e) => SaleModel.fromMap(e as Map<String, dynamic>))
        .toList();

    await _showSalesSheet(
      title: 'Riwayat Retur',
      sales: sales,
      returnsOnly: true,
    );
  }

  Future<void> showReceivables() async {
    final rows = await DB.receivables();

    final sales = rows
        .where((row) {
          final raw = row['sale_time']?.toString() ?? '';
          final date = DateTime.tryParse(raw);
          return date != null &&
              !date.isBefore(start) &&
              date.isBefore(end);
        })
        .map((row) => SaleModel.fromMap(row))
        .toList();

    await _showSalesSheet(
      title: 'Riwayat Piutang',
      sales: sales,
    );
  }

  Future<void> showPayables() async {
    final rows = await DB.payables();

    await _showExpenseSheet(
      title: 'Hutang Aktif',
      rows: rows,
    );
  }

  Future<void> showNetIncome() async {
    final summary = await DB.rangeSummary(start, end);
    final sales = (summary['sales'] as List)
        .map((e) => SaleModel.fromMap(e as Map<String, dynamic>))
        .toList();

    final expenses = await DB.expenses(start, end);

    await _showNetIncomeSheet(
      sales: sales,
      expenses: expenses,
    );
  }

  Future<void> showPaymentTransactions(String payment) async {
    final summary = await DB.rangeSummary(start, end);

    final sales = (summary['sales'] as List)
        .map((e) => SaleModel.fromMap(e as Map<String, dynamic>))
        .where((sale) {
          final raw = sale.payment.trim().toLowerCase();

          if (payment == 'Tunai') {
            return raw == 'tunai' || raw == 'cash';
          }

          if (payment == 'QRIS') {
            return raw == 'qris';
          }

          if (payment == 'Transfer') {
            return raw == 'transfer';
          }

          if (payment == 'Bayar Tunda') {
            return raw == 'bayar tunda' || raw == 'bayar nanti';
          }

          return false;
        })
        .toList();

    await _showSalesSheet(
      title: 'Transaksi $payment',
      sales: sales,
      showNetTotal: true,
    );
  }

  Future<void> _showSalesSheet({
    required String title,
    required List<SaleModel> sales,
    bool returnsOnly = false,
    bool showNetTotal = false,
  }) async {
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * .78,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${displayDate(start)} - ${displayDate(end.subtract(const Duration(days: 1)))}',
                  style: const TextStyle(color: inkMuted),
                ),
                const SizedBox(height: 10),
                if (sales.isEmpty)
                  const Expanded(
                    child: Center(
                      child: Text('Tidak ada transaksi pada rentang ini.'),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.separated(
                      itemCount: sales.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1),
                      itemBuilder: (_, index) {
                        final sale = sales[index];

                        return ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            radius: 18,
                            backgroundColor: redSoft,
                            foregroundColor: red,
                            child: Icon(
                              returnsOnly
                                  ? Icons.assignment_return_rounded
                                  : Icons.receipt_long_rounded,
                              size: 19,
                            ),
                          ),
                          title: Text(
                            sale.no,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          subtitle: Text(
                            '${sale.time} • ${sale.customerName} • ${sale.payment}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Text(
                            rp(sale.total),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          onTap: () => _showSaleDetail(sale),
                        );
                      },
                    ),
                  ),
                if (showNetTotal && sales.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: FutureBuilder<int>(
                      future: _salesNetTotal(sales),
                      builder: (_, snapshot) {
                        final total = snapshot.data ?? 0;

                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Total Bersih',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                Text(
                                  rp(total),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
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

  Future<int> _salesNetTotal(List<SaleModel> sales) async {
    var total = 0;

    for (final sale in sales) {
      total += sale.total;
      total -= await DB.returnedAmount(sale.id);
    }

    return total;
  }

  Future<void> _showExpenseSheet({
    required String title,
    required List<Map<String, dynamic>> rows,
  }) async {
    if (!mounted) return;

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
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${displayDate(start)} - ${displayDate(end.subtract(const Duration(days: 1)))}',
                  style: const TextStyle(color: inkMuted),
                ),
                const SizedBox(height: 10),
                if (rows.isEmpty)
                  const Expanded(
                    child: Center(
                      child: Text('Tidak ada hutang pada rentang ini.'),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.separated(
                      itemCount: rows.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1),
                      itemBuilder: (_, index) {
                        final row = rows[index];

                        final amount =
                            (row['amount'] as num?)?.toInt() ?? 0;

                        final note =
                            (row['note'] ?? 'Pengeluaran').toString();

                        final category =
                            (row['category'] ?? '').toString();

                        final status =
                            (row['payment_status'] ?? '').toString();

                        return ListTile(
                          leading: const CircleAvatar(
                            radius: 18,
                            child: Icon(
                              Icons.receipt_long_rounded,
                              size: 19,
                            ),
                          ),
                          title: Text(
                            note,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          subtitle: Text(
                            '$category • ${row['expense_date'] ?? ''} • $status',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Text(
                            rp(amount),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
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

  Future<void> _showNetIncomeSheet({
    required List<SaleModel> sales,
    required List<Map<String, dynamic>> expenses,
  }) async {
    if (!mounted) return;

    final salesTotal = await _salesNetTotal(sales);

    var expenseTotal = 0;

    for (final row in expenses) {
      final status =
          (row['payment_status'] ?? '').toString().trim().toLowerCase();

      if (status == 'lunas' || status == 'sudah dibayar') {
        expenseTotal += (row['amount'] as num?)?.toInt() ?? 0;
      }
    }

    final net = salesTotal - expenseTotal;

    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Rincian Laba Bersih',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              ListTile(
                title: const Text('Omzet Bersih'),
                trailing: Text(
                  rp(salesTotal),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              ListTile(
                title: const Text('Pengeluaran Dibayar'),
                trailing: Text(
                  rp(expenseTotal),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              const Divider(),
              ListTile(
                title: const Text(
                  'Laba Bersih',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                trailing: Text(
                  rp(net),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Ketuk transaksi pada kartu Omzet untuk melihat detail penjualan.',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showSaleDetail(SaleModel sale) async {
    if (!mounted) return;

    final items = await DB.saleItems(sale.id);
    final returnedAmount = await DB.returnedAmount(sale.id);

    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * .78,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
            children: [
              Text(
                'Detail ${sale.no}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              _detailRow('Tanggal', sale.time),
              _detailRow('Kasir', sale.cashier),
              _detailRow('Pelanggan', sale.customerName),
              if (sale.customerPhone.isNotEmpty)
                _detailRow('Telepon', sale.customerPhone),
              _detailRow('Tipe Pelanggan', sale.customerType),
              _detailRow('Pembayaran', sale.payment),
              if (sale.transferBank.isNotEmpty)
                _detailRow('Bank', sale.transferBank),
              if (sale.transferAccount.isNotEmpty)
                _detailRow('Rekening', sale.transferAccount),
              if (sale.dueDate.isNotEmpty)
                _detailRow('Jatuh Tempo', sale.dueDate),
              const SizedBox(height: 12),
              const Divider(),
              const Text(
                'Item',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Detail item tidak tersedia.'),
                )
              else
                ...items.map((item) {
                  final name = (item['name'] ?? 'Item').toString();
                  final qty = (item['qty'] as num?)?.toInt() ?? 0;
                  final returned =
                      (item['returned_qty'] as num?)?.toInt() ?? 0;
                  final price =
                      (item['price'] as num?)?.toInt() ?? 0;

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    subtitle: Text(
                      returned > 0
                          ? 'Qty $qty • Retur $returned • Harga ${rp(price)}'
                          : 'Qty $qty • Harga ${rp(price)}',
                    ),
                    trailing: Text(
                      rp(price * qty),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  );
                }),
              const Divider(),
              _detailRow('Subtotal', rp(sale.subtotal)),
              _detailRow('Diskon', rp(sale.discount)),
              _detailRow('Total', rp(sale.total)),
              if (returnedAmount > 0)
                _detailRow('Nilai Retur', rp(returnedAmount)),
              if (returnedAmount > 0)
                _detailRow(
                  'Total Bersih',
                  rp(sale.total - returnedAmount),
                ),
              if (sale.returned)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'TRANSAKSI SUDAH DIRETUR SELURUHNYA',
                    style: TextStyle(
                      color: red,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 125,
            child: Text(
              label,
              style: const TextStyle(
                color: inkMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _paymentCard() {
    Widget paymentItem(String title, int amount) {
      return Expanded(
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => showPaymentTransactions(title),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  FittedBox(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      rp(amount),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 17,
                    color: inkMuted,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Metode Pembayaran',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            paymentItem(
              'Tunai',
              paymentTotals['Tunai'] ?? 0,
            ),
            const SizedBox(width: 8),
            paymentItem(
              'QRIS',
              paymentTotals['QRIS'] ?? 0,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            paymentItem(
              'Transfer',
              paymentTotals['Transfer'] ?? 0,
            ),
            const SizedBox(width: 8),
            paymentItem(
              'Bayar Tunda',
              paymentTotals['Bayar Tunda'] ?? 0,
            ),
          ],
        ),
      ],
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


enum _TrendMode {
  hour,
  day,
  month,
}

class _TrendPoint {
  final DateTime bucket;
  final String label;
  final int omzet;
  final int biaya;
  final int bersih;

  const _TrendPoint({
    required this.bucket,
    required this.label,
    required this.omzet,
    required this.biaya,
    required this.bersih,
  });
}

class _TrendAccumulator {
  final DateTime bucket;
  final String label;
  int omzet = 0;
  int biaya = 0;

  _TrendAccumulator({
    required this.bucket,
    required this.label,
  });
}

class _TrendLegend extends StatelessWidget {
  final String label;
  final Color color;

  const _TrendLegend({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: inkMuted,
          ),
        ),
      ],
    );
  }
}

class _TrendValue extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _TrendValue({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            color: inkMuted,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          _compactRupiah(value),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ],
    );
  }
}

String _compactRupiah(num value) {
  final absolute = value.abs();

  if (absolute >= 1000000000) {
    final v = value / 1000000000;
    return 'Rp${v.toStringAsFixed(v.abs() >= 10 ? 0 : 1)}M';
  }

  if (absolute >= 1000000) {
    final v = value / 1000000;
    return 'Rp${v.toStringAsFixed(v.abs() >= 10 ? 0 : 1)}jt';
  }

  if (absolute >= 1000) {
    final v = value / 1000;
    return 'Rp${v.toStringAsFixed(v.abs() >= 10 ? 0 : 1)}rb';
  }

  return 'Rp${value.round()}';
}

class _TrendChartPainter extends CustomPainter {
  final List<_TrendPoint> points;
  final int selectedIndex;

  const _TrendChartPainter({
    required this.points,
    required this.selectedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    const left = 54.0;
    const top = 14.0;
    const bottom = 38.0;
    const right = 12.0;

    final chartWidth = size.width - left - right;
    final chartHeight = size.height - top - bottom;

    if (chartWidth <= 0 || chartHeight <= 0) return;

    final maxValue = points
        .expand<double>((point) => [
              point.omzet.toDouble(),
              point.biaya.toDouble(),
              point.bersih.toDouble(),
            ])
        .fold<double>(0, (max, value) => value > max ? value : max);

    final minValue = points
        .expand<double>((point) => [
              point.omzet.toDouble(),
              point.biaya.toDouble(),
              point.bersih.toDouble(),
            ])
        .fold<double>(0, (min, value) => value < min ? value : min);

    final range = (maxValue - minValue).abs() < 1
        ? 1.0
        : (maxValue - minValue);

    final paddedMin = minValue < 0
        ? minValue - range * .12
        : 0.0;

    final paddedMax = maxValue + range * .12;
    final paddedRange = (paddedMax - paddedMin).abs() < 1
        ? 1.0
        : (paddedMax - paddedMin);

    Offset pointOffset(int index, double value) {
      final x = points.length == 1
          ? left + chartWidth / 2
          : left +
              (chartWidth * index / (points.length - 1));

      final normalized =
          (value - paddedMin) / paddedRange;

      final y = top +
          chartHeight -
          normalized.clamp(0.0, 1.0) * chartHeight;

      return Offset(x, y);
    }

    final gridPaint = Paint()
      ..color = const Color(0xFFEAEAF0)
      ..strokeWidth = 1;

    final axisPaint = Paint()
      ..color = const Color(0xFFDCDCE3)
      ..strokeWidth = 1;

    for (var i = 0; i <= 4; i++) {
      final y = top + chartHeight * i / 4;

      canvas.drawLine(
        Offset(left, y),
        Offset(size.width - right, y),
        gridPaint,
      );

      final value = paddedMax -
          paddedRange * i / 4;

      final painter = TextPainter(
        text: TextSpan(
          text: _compactRupiah(value),
          style: const TextStyle(
            fontSize: 9,
            color: inkMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: left - 7);

      painter.paint(
        canvas,
        Offset(
          left - painter.width - 7,
          y - painter.height / 2,
        ),
      );
    }

    canvas.drawLine(
      Offset(left, top + chartHeight),
      Offset(size.width - right, top + chartHeight),
      axisPaint,
    );

    final xLabelStep = points.length <= 8
        ? 1
        : points.length <= 16
            ? 2
            : points.length <= 24
                ? 3
                : 5;

    for (var i = 0; i < points.length; i += xLabelStep) {
      final p = pointOffset(i, paddedMin);
      final painter = TextPainter(
        text: TextSpan(
          text: points[i].label,
          style: const TextStyle(
            fontSize: 9,
            color: inkMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final x = (p.dx - painter.width / 2)
          .clamp(0.0, size.width - painter.width);

      painter.paint(
        canvas,
        Offset(
          x,
          top + chartHeight + 9,
        ),
      );
    }

    void drawSeries(
      List<double> values,
      Color color,
    ) {
      final path = Path();

      for (var i = 0; i < values.length; i++) {
        final point = pointOffset(i, values[i]);

        if (i == 0) {
          path.moveTo(point.dx, point.dy);
          continue;
        }

        final previous = pointOffset(i - 1, values[i - 1]);
        final control = (point.dx - previous.dx) * .35;

        path.cubicTo(
          previous.dx + control,
          previous.dy,
          point.dx - control,
          point.dy,
          point.dx,
          point.dy,
        );
      }

      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.7
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      canvas.drawPath(path, paint);

      final dotPaint = Paint()..color = color;

      for (var i = 0; i < values.length; i++) {
        final point = pointOffset(i, values[i]);

        if (i == selectedIndex) {
          canvas.drawCircle(
            point,
            5.5,
            Paint()..color = Colors.white,
          );
          canvas.drawCircle(
            point,
            4,
            dotPaint,
          );
        } else if (points.length <= 16) {
          canvas.drawCircle(
            point,
            2.2,
            dotPaint,
          );
        }
      }
    }

    drawSeries(
      points.map((e) => e.omzet.toDouble()).toList(),
      red,
    );

    drawSeries(
      points.map((e) => e.biaya.toDouble()).toList(),
      const Color(0xFFE38B22),
    );

    drawSeries(
      points.map((e) => e.bersih.toDouble()).toList(),
      const Color(0xFF2E9B63),
    );

    if (selectedIndex >= 0 &&
        selectedIndex < points.length) {
      final selected = pointOffset(
        selectedIndex,
        points[selectedIndex].bersih.toDouble(),
      );

      final verticalPaint = Paint()
        ..color = const Color(0xFFBFC0C8)
        ..strokeWidth = 1.2;

      canvas.drawLine(
        Offset(selected.dx, top),
        Offset(selected.dx, top + chartHeight),
        verticalPaint,
      );

      final markerPaint = Paint()
        ..color = const Color(0xFF666772)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        Offset(selected.dx, top + chartHeight),
        3,
        markerPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TrendChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.selectedIndex != selectedIndex;
  }
}

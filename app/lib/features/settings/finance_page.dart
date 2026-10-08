import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/app_localizations.dart';
import '../../core/utils.dart';
import '../../data/database.dart';

class FinancePage extends StatefulWidget {
  const FinancePage({super.key});

  @override
  State<FinancePage> createState() => _FinancePageState();
}

class _FinancePageState extends State<FinancePage> {
  String period = 'Hari';
  DateTime selectedDate = DateTime.now();
  DateTime? selectedEndDate;

  int income = 0;
  int payLater = 0;
  int expense = 0;
  int debt = 0;
  int receivable = 0;
  int payable = 0;
  int actualCash = 0;
  List<Map<String, dynamic>> expenseRows = [];
  List<Map<String, dynamic>> receivableRows = [];
  List<Map<String, dynamic>> payableRows = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  DateTime get from =>
      DateTime(selectedDate.year, selectedDate.month, selectedDate.day);

  DateTime get to =>
      selectedEndDate == null
          ? from.add(const Duration(days: 1))
          : DateTime(
              selectedEndDate!.year,
              selectedEndDate!.month,
              selectedEndDate!.day,
            ).add(const Duration(days: 1));

  Future<int> _actualCashTotal() async {
    final db = await DB.database;

    final salesRows = await db.rawQuery('''
      SELECT COALESCE(
        SUM(
          s.total - COALESCE(
            (
              SELECT SUM(si.returned_qty * si.price)
              FROM sale_items si
              WHERE si.sale_id = s.id
            ),
            0
          )
        ),
        0
      ) AS total
      FROM sales s
      WHERE (
        UPPER(TRIM(COALESCE(s.payment, ''))) NOT IN
          ('BAYAR TUNDA', 'BAYAR NANTI')
        OR (
          UPPER(TRIM(COALESCE(s.payment, ''))) IN
            ('BAYAR TUNDA', 'BAYAR NANTI')
          AND UPPER(TRIM(COALESCE(s.receivable_status, ''))) = 'LUNAS'
        )
      )
    ''');

    var cash = (salesRows.first['total'] as num?)?.toInt() ?? 0;

    final expenseRows = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) AS total
      FROM expenses
      WHERE UPPER(TRIM(COALESCE(payment_status, ''))) = 'LUNAS'
    ''');

    cash -= (expenseRows.first['total'] as num?)?.toInt() ?? 0;
    return cash;
  }

  Future<void> _load() async {
    final results = await Future.wait([
      DB.cashIncome(from, to),
      DB.payLaterTotal(from, to),
      DB.expenseTotal(from, to),
      DB.expenses(from, to),
      DB.receivables(),
      DB.payables(),
      _actualCashTotal(),
    ]);

    if (!mounted) return;

    setState(() {
      income = results[0] as int;
      payLater = results[1] as int;
      expense = results[2] as int;

      expenseRows = results[3] as List<Map<String, dynamic>>;
      receivableRows = results[4] as List<Map<String, dynamic>>;
      payableRows = results[5] as List<Map<String, dynamic>>;

      receivable = payLater;

      // Kartu Hutang memakai sumber yang sama dengan daftar
      // Hutang aktif agar jumlah kartu selalu sinkron.
      payable = payableRows.fold<int>(
        0,
        (sum, item) =>
            sum + ((item['amount'] as num?)?.toInt() ?? 0),
      );

      actualCash = results[6] as int;
      debt = payable;
    });
  }

  String _periodLabel() {
    return '${displayDate(from)} - ${displayDate(to.subtract(const Duration(days: 1)))}';
  }

  Future<void> _pickDate() async {
    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(
        start: selectedDate,
        end: selectedEndDate ?? selectedDate,
      ),
    );

    if (result == null) return;

    setState(() {
      selectedDate = result.start;
      selectedEndDate = result.end;
    });

    _load();
  }

  Future<void> _showExpenseDialog([
    Map<String, dynamic>? item,
  ]) async {
    final category = TextEditingController(
      text: item?['category']?.toString() ?? '',
    );
    final note = TextEditingController(
      text: item?['note']?.toString() ?? '',
    );
    final amount = TextEditingController(text: item?['amount']?.toString() ?? '');
    String paymentStatus =
        item?['payment_status']?.toString() == 'Hutang' ||
                item?['payment_status']?.toString() == 'Jatuh Tempo'
            ? 'Hutang'
            : 'Lunas';

    DateTime date = item == null
        ? DateTime.now()
        : DateTime.tryParse(
              item['expense_date'].toString(),
            ) ??
            DateTime.now();

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              title: Text(
                item == null
                    ? AppLocalizations.t('Catat Pengeluaran', 'Record Expense')
                    : AppLocalizations.t('Edit Pengeluaran', 'Edit Expense'),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: category,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.t('Kategori', 'Category'),
                        hintText: AppLocalizations.t('Contoh: Listrik', 'Example: Electricity'),
                      ),
                    ),
                    TextField(
                      controller: note,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.t('Keterangan', 'Description'),
                      ),
                    ),
                    TextField(
                      controller: amount,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.t('Nominal', 'Amount'),
                        prefixText: 'Rp ',
                      ),
                    ),
                    DropdownButtonFormField<String>(
                      value: paymentStatus,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.t('Status Pembayaran', 'Payment Status'),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'Lunas',
                          child: Text(AppLocalizations.t('Lunas', 'Paid')),
                        ),
                        DropdownMenuItem(
                          value: 'Hutang',
                          child: Text(AppLocalizations.t('Hutang', 'Debt')),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          setDialogState(() => paymentStatus = v);
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.calendar_today_outlined,
                      ),
                      title: Text(AppLocalizations.t('Tanggal', 'Date')),
                      subtitle: Text(displayDate(date)),
                      onTap: () async {
                        final result = await showDatePicker(
                          context: context,
                          initialDate: date,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );

                        if (result != null) {
                          setDialogState(() => date = result);
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () =>
                      Navigator.pop(dialogContext, false),
                  child: Text(AppLocalizations.t('Batal', 'Cancel')),
                ),
                FilledButton(
                  onPressed: () async {
                    final nominal = int.tryParse(
                      amount.text
                          .replaceAll('.', '')
                          .replaceAll(',', '')
                          .trim(),
                    );

                    try {
                      await DB.saveExpense(
                        id: item?['id'] as int?,
                        date: date,
                        category: category.text,
                        note: note.text,
                        amount: nominal ?? 0,
                        paymentStatus: paymentStatus,
                        dueDate: paymentStatus == 'Hutang' ? date : null,
                      );

                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext, true);
                      }
                    } catch (e) {
                      if (!dialogContext.mounted) return;

                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        SnackBar(
                          content: Text(
                            e.toString().replaceFirst(
                              'Exception: ',
                              '',
                            ),
                          ),
                        ),
                      );
                    }
                  },
                  child: Text(AppLocalizations.t('Simpan', 'Save')),
                ),
              ],
            );
          },
        );
      },
    );

    category.dispose();
    note.dispose();
    amount.dispose();

    if (saved == true) {
      _load();
    }
  }

  Future<void> _settleReceivable(
    Map<String, dynamic> item,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        title: Text(AppLocalizations.t('Lunasi Piutang?', 'Settle Receivable?')),
        content: Text(
          '${item['sale_no']} • ${rp(item['outstanding_amount'] as num)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.t('Batal', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppLocalizations.t('Lunasi', 'Settle')),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await DB.settleReceivable(item['id'] as int);
    _load();
  }

  Future<void> _settlePayable(
    Map<String, dynamic> item,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        title: Text(AppLocalizations.t('Lunasi Hutang?', 'Settle Debt?')),
        content: Text(
          '${item['category']} • ${rp(item['amount'] as num)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.t('Batal', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppLocalizations.t('Lunasi', 'Settle')),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await DB.settlePayable(item['id'] as int);
    _load();
  }

  Future<void> _deleteExpense(
    Map<String, dynamic> item,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        title: Text(AppLocalizations.t('Hapus Pengeluaran?', 'Delete Expense?')),
        content: Text(
          '${item['category']} • ${rp(item['amount'] as num)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.t('Batal', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppLocalizations.t('Hapus', 'Delete')),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await DB.deleteExpense(item['id'] as int);
      _load();
    }
  }

  Widget _metric(
    String title,
    int value,
    IconData icon,
  ) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: red),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  color: inkMuted,
                ),
              ),
              const SizedBox(height: 4),
              FittedBox(
                alignment: Alignment.centerLeft,
                child: Text(
                  rp(value),
                  style: const TextStyle(
                    fontSize: 17,
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

  @override
  Widget build(BuildContext context) {
    final net = income - (expense - debt);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.t('Keuangan', 'Finance')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showExpenseDialog(),
        backgroundColor: red,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text(AppLocalizations.t('Pengeluaran', 'Expenses')),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: AppLocalizations.t('Rentang Tanggal', 'Date Range'),
                      border: OutlineInputBorder(),
                    ),
                    child: Text(
                      _periodLabel(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filled(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_month),
                  tooltip: AppLocalizations.t('Pilih tanggal', 'Select date'),
                ),
              ],
            ),

            Row(
              children: [
                Expanded(
                  child: _metric(
                    AppLocalizations.t('Pendapatan', 'Revenue'),
                    income,
                    Icons.trending_up_rounded,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _metric(
                    AppLocalizations.t('Bayar Tunda', 'Pay Later'),
                    payLater,
                    Icons.schedule_rounded,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _metric(
                    AppLocalizations.t('Pengeluaran', 'Expenses'),
                    expense,
                    Icons.trending_down_rounded,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: _metric(
                    AppLocalizations.t('Kas Aktual', 'Actual Cash'),
                    actualCash,
                    Icons.account_balance_wallet_rounded,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _metric(
                    AppLocalizations.t('Hasil Bersih', 'Net Result'),
                    net,
                    Icons.trending_up_rounded,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),
            const SizedBox(height: 14),

            Card(
              child: ExpansionTile(
                leading: const Icon(
                  Icons.account_balance_rounded,
                  color: red,
                ),
                title: Text(
                  AppLocalizations.t('Piutang', 'Receivables'),
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: Text(
                  '${receivableRows.length} transaksi • ${rp(receivable)}',
                ),
                children: receivableRows.isEmpty
                    ? [
                        Padding(
                          padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(AppLocalizations.t('Tidak ada piutang aktif.', 'No active receivables.')),
                          ),
                        ),
                      ]
                    : receivableRows.map((item) {
                        final outstanding =
                            (item['outstanding_amount'] as num).toInt();
                        final returned =
                            (item['returned_amount'] as num).toInt();

                        return ListTile(
                          title: Text(
                            item['customer_name']?.toString().isNotEmpty == true
                                ? item['customer_name'].toString()
                                : AppLocalizations.t('Pelanggan Umum', 'General Customer'),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          subtitle: Text(
                            '${item['sale_no']} • '
                            '${item['sale_time'].toString().substring(0, 10)}'
                            '${returned > 0 ? ' • ${AppLocalizations.t('Retur', 'Return')} ${rp(returned)}' : ''}',
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                rp(outstanding),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              TextButton(
                                onPressed: () => _settleReceivable(item),
                                child: Text(AppLocalizations.t('Lunasi', 'Settle')),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
              ),
            ),

            const SizedBox(height: 8),

            Card(
              child: ExpansionTile(
                leading: const Icon(
                  Icons.receipt_long_rounded,
                  color: red,
                ),
                title: Text(
                  AppLocalizations.t('Hutang', 'Debt'),
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: Text(
                  '${payableRows.length} transaksi • ${rp(payable)}',
                ),
                children: payableRows.isEmpty
                    ? [
                        Padding(
                          padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(AppLocalizations.t('Tidak ada hutang aktif.', 'No active debts.')),
                          ),
                        ),
                      ]
                    : payableRows.map((item) {
                        final dueDate =
                            item['due_date']?.toString() ?? '';

                        return ListTile(
                          title: Text(
                            item['category'].toString(),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          subtitle: Text(
                            '${item['note']} • '
                            '${item['expense_date'].toString().substring(0, 10)}'
                            '${dueDate.isNotEmpty ? ' • ${AppLocalizations.t('Jatuh tempo', 'Due date')} $dueDate' : ''}',
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                rp(item['amount'] as num),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              TextButton(
                                onPressed: () => _settlePayable(item),
                                child: Text(AppLocalizations.t('Lunasi', 'Settle')),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
              ),
            ),

            const SizedBox(height: 14),


            Text(
              AppLocalizations.t('Riwayat Pengeluaran', 'Expense History'),
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),

            if (expenseRows.isEmpty)
              Card(
                child: ListTile(
                  title: Text(
                    AppLocalizations.t(
                      'Belum ada pengeluaran pada periode ini.',
                      'No expenses for this period.',
                    ),
                  ),
                ),
              )
            else
              ...expenseRows.map(
                (item) => Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: redSoft,
                      foregroundColor: red,
                      child: const Icon(
                        Icons.receipt_long_outlined,
                      ),
                    ),
                    title: Text(
                      item['category'].toString(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    subtitle: Text(
                      '${item['note']} • '
                      '${item['expense_date'].toString().substring(0, 10)}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          rp(item['amount'] as num),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'edit') {
                              _showExpenseDialog(item);
                            } else if (value == 'delete') {
                              _deleteExpense(item);
                            }
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              value: 'edit',
                              child: Text(AppLocalizations.t('Edit', 'Edit')),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text(AppLocalizations.t('Hapus', 'Delete')),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 90),
          ],
        ),
      ),
    );
  }
}

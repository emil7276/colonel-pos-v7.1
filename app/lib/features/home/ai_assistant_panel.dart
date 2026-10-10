import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_localizations.dart';
import '../../core/utils.dart';
import '../../data/database.dart';

class AiAssistantPanel extends StatefulWidget {
  final String username;
  final String role;
  const AiAssistantPanel({super.key, required this.username, required this.role});

  @override
  State<AiAssistantPanel> createState() => _AiAssistantPanelState();
}

class _AssistantTurn {
  _AssistantTurn(this.question);
  final String question;
  String? answer;
  bool loading = true;
  bool expanded = false;
}

class _AiAssistantPanelState extends State<AiAssistantPanel>
    with SingleTickerProviderStateMixin {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<_AssistantTurn> _turns = [];
  List<Map<String, dynamic>> _questionBank = [];
  late final AnimationController _typingController;
  String _conversationStyle = 'aku';
  int _fallbackReplyCount = 0;

  bool get _en => AppLocalizations.isEnglish;
  bool get _admin => widget.role == 'Administrator';

  @override
  void initState() {
    super.initState();
    _typingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _loadQuestionBank();
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    _typingController.dispose();
    super.dispose();
  }

  String _stamp(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    final h = date.hour.toString().padLeft(2, '0');
    final min = date.minute.toString().padLeft(2, '0');
    final sec = date.second.toString().padLeft(2, '0');
    return '$y-$m-$d $h:$min:$sec';
  }

  List<DateTime> _period(String q) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (q.contains('kemarin') || q.contains('yesterday')) {
      final start = today.subtract(const Duration(days: 1));
      return [start, today];
    }
    if (q.contains('minggu lalu') || q.contains('last week')) {
      final monday = today.subtract(Duration(days: today.weekday - 1));
      return [monday.subtract(const Duration(days: 7)), monday];
    }
    if (q.contains('minggu ini') || q.contains('this week')) {
      return [today.subtract(Duration(days: today.weekday - 1)), today.add(const Duration(days: 1))];
    }
    if (q.contains('bulan lalu') || q.contains('last month')) {
      final start = DateTime(now.year, now.month - 1, 1);
      return [start, DateTime(now.year, now.month, 1)];
    }
    if (q.contains('bulan ini') || q.contains('this month')) {
      return [DateTime(now.year, now.month, 1), today.add(const Duration(days: 1))];
    }
    if (q.contains('tahun lalu') || q.contains('last year')) {
      return [DateTime(now.year - 1, 1, 1), DateTime(now.year, 1, 1)];
    }
    if (q.contains('tahun ini') || q.contains('this year')) {
      return [DateTime(now.year, 1, 1), today.add(const Duration(days: 1))];
    }
    return [today, today.add(const Duration(days: 1))];
  }

  String _periodLabel(String q) {
    if (q.contains('kemarin') || q.contains('yesterday')) return _en ? 'yesterday' : 'kemarin';
    if (q.contains('minggu lalu') || q.contains('last week')) return _en ? 'last week' : 'minggu lalu';
    if (q.contains('minggu ini') || q.contains('this week')) return _en ? 'this week' : 'minggu ini';
    if (q.contains('bulan lalu') || q.contains('last month')) return _en ? 'last month' : 'bulan lalu';
    if (q.contains('bulan ini') || q.contains('this month')) return _en ? 'this month' : 'bulan ini';
    if (q.contains('tahun lalu') || q.contains('last year')) return _en ? 'last year' : 'tahun lalu';
    if (q.contains('tahun ini') || q.contains('this year')) return _en ? 'this year' : 'tahun ini';
    return _en ? 'today' : 'hari ini';
  }

  bool _hasAny(String q, List<String> words) => words.any(q.contains);

  // Remember a recognizable Indonesian speaking style during this chat session.
  String _rememberConversationStyle(String question) {
    final q = question.toLowerCase();
    if (RegExp(r'\b(gue|gua|gw|lo|lu|elo|elu)\b').hasMatch(q)) {
      _conversationStyle = 'gue';
    } else if (RegExp(r'\b(saya|anda|bapak|ibu)\b').hasMatch(q)) {
      _conversationStyle = 'formal';
    } else if (RegExp(r'\b(aku|kamu)\b').hasMatch(q)) {
      _conversationStyle = 'aku';
    }
    return _conversationStyle;
  }

  String _replacePronouns(String text, String style) {
    if (_en || style == 'neutral') return text;
    var result = text;
    if (style == 'gue') {
      result = result
          .replaceAll(RegExp(r'\b[Aa]ku\b'), 'gue')
          .replaceAll(RegExp(r'\b[Ss]aya\b'), 'gue')
          .replaceAll(RegExp(r'\b[Kk]amu\b'), 'lo')
          .replaceAll(RegExp(r'\b[Aa]nda\b'), 'lo');
    } else if (style == 'formal') {
      result = result
          .replaceAll(RegExp(r'\b[Aa]ku\b'), 'saya')
          .replaceAll(RegExp(r'\b[Gg]ue\b'), 'saya')
          .replaceAll(RegExp(r'\b[Gg]ua\b'), 'saya')
          .replaceAll(RegExp(r'\b[Kk]amu\b'), 'Anda')
          .replaceAll(RegExp(r'\b[Ll]o\b'), 'Anda')
          .replaceAll(RegExp(r'\b[Ll]u\b'), 'Anda');
    } else {
      result = result
          .replaceAll(RegExp(r'\b[Ss]aya\b'), 'aku')
          .replaceAll(RegExp(r'\b[Gg]ue\b'), 'aku')
          .replaceAll(RegExp(r'\b[Gg]ua\b'), 'aku')
          .replaceAll(RegExp(r'\b[Aa]nda\b'), 'kamu')
          .replaceAll(RegExp(r'\b[Ll]o\b'), 'kamu')
          .replaceAll(RegExp(r'\b[Ll]u\b'), 'kamu');
    }
    return result;
  }

  bool _isCustomerQuestion(String q) {
    if (_hasAny(q, [
      'hutang usaha', 'utang usaha', 'hutang toko', 'utang toko',
      'hutang supplier', 'utang supplier', 'hutang ke supplier',
      'utang ke supplier', 'hutang kepada supplier',
      'utang kepada supplier', 'hutang pada supplier',
      'utang pada supplier', 'business debt', 'supplier debt',
      'payable', 'payables',
    ])) return false;
    if (_hasAny(q, ['berapa pelanggan', 'jumlah pelanggan', 'customer count'])) return false;
    if (_hasAny(q, ['pelanggan', 'customer', 'nama pelanggan', 'customer name'])) return true;
    final debt = _hasAny(q, ['utang', 'hutang', 'piutang', 'owes', 'debt']);
    if (debt && !_hasAny(q, [
      'hutang usaha', 'utang usaha', 'hutang toko', 'utang toko',
      'hutang supplier', 'utang supplier', 'hutang ke supplier',
      'utang ke supplier', 'hutang kepada supplier',
      'utang kepada supplier', 'hutang pada supplier',
      'utang pada supplier', 'business debt', 'supplier debt',
      'payable', 'payables',
    ])) {
      final words = _extractTerms(q, customer: true);
      return words.isNotEmpty;
    }
    return false;
  }

  bool _isCustomerDebtQuestion(String q) =>
      _isCustomerQuestion(q) && _hasAny(q, ['utang', 'hutang', 'piutang', 'owes', 'debt']);

  bool _adminOnlyQuestion(String q) {
    return _hasAny(q, [
      'laba', 'rugi', 'profit', 'loss', 'pengeluaran', 'expenses',
      'hutang usaha', 'utang usaha', 'hutang toko', 'utang toko',
      'hutang supplier', 'utang supplier', 'hutang ke supplier',
      'utang ke supplier', 'hutang kepada supplier',
      'utang kepada supplier', 'hutang pada supplier',
      'utang pada supplier', 'payable', 'payables',
      'database backup', 'backup database', 'restore database',
      'pengaturan pengguna', 'tambah pengguna', 'hapus pengguna',
      'hak akses', 'aktivasi lisensi', 'pengaturan toko',
      'user management', 'add user', 'delete user', 'access rights',
      'license activation', 'business settings',
    ]) || (_hasAny(q, ['hutang', 'utang', 'payables']) && !_isCustomerQuestion(q)) ||
        (_hasAny(q, ['piutang', 'receivable']) && !_isCustomerQuestion(q));
  }

  List<String> _extractTerms(String q, {bool customer = false}) {
    final cleaned = q.toLowerCase().replaceAll(RegExp(r'[^a-z0-9 ]'), ' ');
    final stop = <String>{
      'min', 'om', 'kak', 'tolong', 'dong', 'ya', 'yang', 'ada', 'gak', 'ga', 'nggak', 'enggak',
      'apakah', 'coba', 'cek', 'carikan', 'cari', 'lihat', 'tampilkan', 'berapa', 'jumlah', 'total',
      'aku', 'saya', 'ku', 'punya', 'milik', 'di', 'dari', 'ke', 'untuk', 'pada', 'hari', 'ini',
      'kemarin', 'minggu', 'bulan', 'tahun', 'lalu', 'transaksi', 'transaksinya', 'tercatat', 'catatan',
      'database', 'nama', 'namanya', 'pelanggan', 'customer', 'customers', 'orang', 'siapa', 'bener',
      'benar', 'betul', 'tidak', 'salah', 'sudah', 'belum', 'lunas', 'bayar', 'dibayar', 'utang',
      'hutang', 'piutang', 'debt', 'owes', 'owe', 'berapa', 'is', 'there', 'a', 'the', 'customer',
      'named', 'name', 'do', 'does', 'have', 'has', 'any', 'how', 'much', 'many', 'show', 'find',
      'me', 'for', 'of', 'and', 'please', 'today', 'yesterday', 'this', 'last', 'week', 'month', 'year',
      'stok', 'stock', 'persediaan', 'produk', 'barang', 'harga', 'price', 'product', 'products',
      'omzet', 'omset', 'penjualan', 'jualan', 'revenue', 'sales', 'qris', 'transfer', 'tunai',
      'retur', 'return', 'laba', 'rugi', 'profit', 'loss', 'pengeluaran', 'expenses', 'usaha', 'toko',
      'supplier', 'business', 'debt', 'payable', 'piutang', 'receivable', 'jumlahnya', 'nominal',
    };
    final words = cleaned.split(RegExp(r'\s+')).where((w) => w.isNotEmpty && !stop.contains(w)).toList();
    return words;
  }

  Future<List<Map<String, dynamic>>> _salesForPeriod(DateTime from, DateTime to) async {
    final db = await DB.database;
    return db.rawQuery(
      'SELECT s.*, '
      'COALESCE((SELECT SUM(si.returned_qty * si.price) FROM sale_items si WHERE si.sale_id = s.id),0) AS returned_amount, '
      '(s.total - COALESCE((SELECT SUM(si.returned_qty * si.price) FROM sale_items si WHERE si.sale_id = s.id),0)) AS net_total '
      'FROM sales s WHERE s.sale_time >= ? AND s.sale_time < ? ORDER BY s.sale_time DESC',
      [_stamp(from), _stamp(to)],
    );
  }

  int _n(dynamic value) => value is num ? value.toInt() : int.tryParse('$value') ?? 0;

  String _customerSearchTerm(String q) => _extractTerms(q, customer: true).join(' ').trim();

  Future<String?> _answerCustomerQuestion(String q) async {
    final term = _customerSearchTerm(q);
    if (term.isEmpty) {
      return _en ? 'Please include the customer name so I can search the saved sales records.'
          : 'Sebutkan nama pelanggannya, ya, supaya aku bisa mencari di catatan penjualan yang tersimpan.';
    }
    final tokens = term.split(' ').where((e) => e.isNotEmpty).toList();
    final where = tokens.map((_) => "LOWER(COALESCE(customer_name,'')) LIKE ?").join(' AND ');
    final db = await DB.database;
    final rows = await db.rawQuery(
      'SELECT s.*, '
      'COALESCE((SELECT SUM(si.returned_qty * si.price) FROM sale_items si WHERE si.sale_id = s.id),0) AS returned_amount, '
      '(s.total - COALESCE((SELECT SUM(si.returned_qty * si.price) FROM sale_items si WHERE si.sale_id = s.id),0)) AS net_total '
      'FROM sales s WHERE $where ORDER BY s.sale_time DESC',
      tokens.map((t) => '%$t%').toList(),
    );
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final row in rows) {
      final name = (row['customer_name'] ?? '').toString().trim();
      if (name.isEmpty || name.toLowerCase() == 'pelanggan umum') continue;
      grouped.putIfAbsent(name, () => []).add(row);
    }
    if (grouped.isEmpty) {
      return _en ? 'I could not find "$term" in the saved customer names from sales records. This only checks records currently stored in the app.'
          : 'Aku tidak menemukan "$term" pada nama pelanggan di catatan penjualan yang tersimpan. Pencarian ini hanya memeriksa data yang ada di aplikasi saat ini.';
    }
    final wantsDebt = _hasAny(q, ['utang', 'hutang', 'piutang', 'debt', 'owes']);
    final out = <String>[];
    for (final entry in grouped.entries.take(4)) {
      final sales = entry.value;
      final total = sales.fold<int>(0, (sum, row) => sum + _n(row['net_total']));
      final debt = sales.where((row) {
        final payment = (row['payment'] ?? '').toString().toLowerCase().trim();
        final status = (row['receivable_status'] ?? '').toString().toLowerCase().trim();
        return (payment == 'bayar tunda' || payment == 'bayar nanti') && status != 'lunas';
      }).fold<int>(0, (sum, row) => sum + _n(row['net_total']));
      final phone = sales.map((r) => (r['customer_phone'] ?? '').toString().trim()).firstWhere((v) => v.isNotEmpty, orElse: () => '');
      out.add('${entry.key}\n${_en ? 'Recorded transactions' : 'Transaksi tercatat'}: ${sales.length}\n${_en ? 'Net purchases recorded' : 'Total pembelian tercatat'}: ${rp(total)}'
          '${phone.isNotEmpty ? '\n${_en ? 'Phone' : 'Telepon'}: $phone' : ''}'
          '${wantsDebt ? '\n${_en ? 'Unpaid pay-later balance recorded' : 'Sisa bayar tunda tercatat'}: ${rp(debt)}' : ''}');
    }
    return _en ? 'Here is what I found in the saved sales records:\n\n${out.join('\n\n')}'
        : 'Ini yang aku temukan di catatan penjualan yang tersimpan:\n\n${out.join('\n\n')}';
  }

  Future<String?> _answerProductQuestion(String q) async {
    final db = await DB.database;
    final products = await db.query('products', where: 'active = ?', whereArgs: [1], orderBy: 'name COLLATE NOCASE');
    final terms = _extractTerms(q).where((t) => t.isNotEmpty).toList();
    final matches = products.where((p) {
      final name = (p['name'] ?? '').toString().toLowerCase();
      final category = (p['category'] ?? '').toString().toLowerCase();
      return terms.isEmpty || terms.every((t) => name.contains(t) || category.contains(t));
    }).toList();
    if (matches.isEmpty) {
      return _en ? 'I could not find a matching active product in the saved product list. Check the product name or spelling.'
          : 'Aku tidak menemukan produk aktif yang cocok di daftar produk tersimpan. Coba periksa nama atau ejaan produknya.';
    }
    final lines = matches.take(6).map((p) =>
      '• ${(p['name'] ?? '').toString()} — ${_en ? 'stock' : 'stok'}: ${_n(p['stock'])}, ${_en ? 'price' : 'harga'}: ${rp(_n(p['price']))}'
    ).join('\n');
    return _en ? 'Product data from Colonel POS:\n$lines' : 'Data produk dari Colonel POS:\n$lines';
  }

  Future<String?> _answerDataQuestion(String q) async {
    final asksCustomer = _isCustomerQuestion(q);
    if (asksCustomer) return _answerCustomerQuestion(q);

    if (_hasAny(q, ['stok', 'stock', 'persediaan', 'harga produk', 'product price'])) {
      return _answerProductQuestion(q);
    }

    final isQrisReport = q.contains('qris') && _hasAny(q, ['berapa', 'jumlah', 'total', 'omzet', 'omset', 'transaksi', 'laporan', 'amount', 'count', 'how much', 'how many']);
    final isPaymentReport = _hasAny(q, ['transfer', 'tunai', 'cash', 'bayar tunda', 'bayar nanti']) && _hasAny(q, ['berapa', 'jumlah', 'total', 'transaksi', 'laporan', 'amount', 'count', 'how much', 'how many']);
    final isSalesReport = _hasAny(q, ['omzet', 'omset', 'revenue']) ||
        (_hasAny(q, ['penjualan', 'jualan', 'sales', 'transaksi']) &&
        _hasAny(q, ['berapa', 'jumlah', 'total', 'laporan', 'hari ini', 'kemarin', 'bulan ini', 'bulan lalu', 'tahun ini', 'minggu ini', 'amount', 'count', 'how much', 'how many']));
    final isProfit = _hasAny(q, ['laba', 'rugi', 'profit', 'loss']);
    final isExpense = _hasAny(q, ['pengeluaran', 'biaya operasional', 'expenses', 'expense total']);
    final isPayable = _hasAny(q, [
      'hutang usaha', 'utang usaha', 'hutang toko', 'utang toko',
      'hutang supplier', 'utang supplier', 'hutang ke supplier',
      'utang ke supplier', 'hutang kepada supplier',
      'utang kepada supplier', 'hutang pada supplier',
      'utang pada supplier', 'payable', 'payables',
    ]) || (_hasAny(q, ['hutang', 'utang']) && !_isCustomerQuestion(q));
    final isReceivable = _hasAny(q, ['bayar tunda', 'bayar nanti', 'piutang', 'receivable', 'unpaid customer']);
    final isReturnReport = q.contains('retur') && _hasAny(q, ['berapa', 'jumlah', 'total', 'nominal', 'laporan', 'hari ini', 'kemarin', 'bulan ini', 'bulan lalu', 'tahun ini', 'amount', 'count', 'how much', 'how many']);
    final isQris = isQrisReport;
    final period = _period(q);
    final label = _periodLabel(q);

    if (isProfit || isExpense || isPayable) {
      if (!_admin) {
        return _en ? 'This financial report requires Administrator permission. Please ask your Admin to check it for you.'
            : 'Laporan keuangan ini memerlukan izin Administrator. Minta Admin memeriksanya, ya.';
      }
      if (isProfit) {
        final summary = await DB.rangeSummary(period[0], period[1]);
        final revenue = _n(summary['omzet']);
        final expense = await DB.expenseTotal(period[0], period[1]);
        final result = revenue - expense;
        final labelResult = result < 0
            ? (_en ? 'shortfall after recorded expenses (not final profit/loss)' : 'kekurangan setelah pengeluaran tercatat (belum laba/rugi final)')
            : (_en ? 'surplus before product costs' : 'surplus sebelum modal barang');
        return _en
            ? 'Financial summary for $label:\nNet sales after recorded returns: ${rp(revenue)}\nRecorded paid expenses: ${rp(expense)}\n$labelResult: ${rp(result.abs())}.\nImportant: this is only net sales minus recorded paid expenses. It is not actual business profit/loss because cost of goods sold and other unrecorded costs may be missing.'
            : 'Ringkasan keuangan $label:\nPenjualan bersih setelah retur tercatat: ${rp(revenue)}\nPengeluaran yang tercatat sudah dibayar: ${rp(expense)}\n$labelResult: ${rp(result.abs())}.\nPenting: angka ini hanya penjualan bersih dikurangi pengeluaran tercatat yang sudah dibayar. Ini belum merupakan laba/rugi usaha sebenarnya karena modal barang terjual dan biaya lain yang belum dicatat mungkin belum diperhitungkan.';
      }
      if (isExpense) {
        final amount = await DB.expenseTotal(period[0], period[1]);
        final rows = await DB.expenses(period[0], period[1]);
        return _en ? 'Recorded paid expenses for $label: ${rp(amount)} (${rows.length} expense records).'
            : 'Total pengeluaran tercatat yang sudah dibayar $label: ${rp(amount)} (${rows.length} catatan pengeluaran).';
      }
      final rows = await DB.payables();
      final amount = rows.fold<int>(0, (sum, row) => sum + _n(row['amount']));
      return _en ? 'Recorded unpaid business payables: ${rp(amount)} across ${rows.length} records.'
          : 'Total hutang usaha yang belum lunas tercatat: ${rp(amount)} dari ${rows.length} catatan.';
    }

    if (isReceivable) {
      if (!_admin) {
        return _en ? 'Receivables and pay-later balances require Administrator permission. Please ask your Admin to check the report.'
            : 'Rincian piutang dan saldo bayar tunda memerlukan izin Administrator. Minta Admin memeriksa laporan ini, ya.';
      }
      final rows = await DB.receivables();
      final selected = rows.where((r) {
        final time = (r['sale_time'] ?? '').toString();
        return time.compareTo(_stamp(period[0])) >= 0 && time.compareTo(_stamp(period[1])) < 0;
      }).toList();
      final amount = selected.fold<int>(0, (sum, row) => sum + _n(row['outstanding_amount']));
      return _en ? 'Outstanding pay-later balance for sales recorded $label: ${rp(amount)} (${selected.length} unpaid transactions).'
          : 'Sisa saldo bayar tunda dari penjualan yang tercatat $label: ${rp(amount)} (${selected.length} transaksi belum lunas).';
    }

    if (isQris || isPaymentReport || isSalesReport || isReturnReport || _hasAny(q, ['berapa pelanggan', 'jumlah pelanggan', 'customer count'])) {
      final sales = await _salesForPeriod(period[0], period[1]);
      if (isQris) {
        final selected = sales.where((s) => (s['payment'] ?? '').toString().trim().toLowerCase() == 'qris').toList();
        final amount = selected.fold<int>(0, (sum, row) => sum + _n(row['net_total']));
        return _en ? 'QRIS report for $label: ${rp(amount)} from ${selected.length} transactions (after recorded returns).'
            : 'Laporan QRIS $label: ${rp(amount)} dari ${selected.length} transaksi (setelah dikurangi retur yang tercatat).';
      }
      if (isPaymentReport) {
        String? method;
        if (q.contains('qris')) method = 'qris';
        else if (q.contains('transfer')) method = 'transfer';
        else if (q.contains('bayar tunda') || q.contains('bayar nanti')) method = 'bayar tunda';
        else if (q.contains('tunai') || q.contains('cash')) method = 'tunai';
        final selected = sales.where((s) {
          final p = (s['payment'] ?? '').toString().trim().toLowerCase();
          if (method == 'bayar tunda') return p == 'bayar tunda' || p == 'bayar nanti';
          if (method == 'tunai') return p == 'tunai' || p == 'cash';
          return method == null || p == method;
        }).toList();
        final amount = selected.fold<int>(0, (sum, row) => sum + _n(row['net_total']));
        final title = method == null ? (_en ? 'payment methods' : 'metode pembayaran') : method.toUpperCase();
        return _en ? '$title for $label: ${rp(amount)} from ${selected.length} transactions (after recorded returns).'
            : '$title $label: ${rp(amount)} dari ${selected.length} transaksi (setelah dikurangi retur yang tercatat).';
      }
      if (isReturnReport) {
        final amount = sales.fold<int>(0, (sum, row) => sum + _n(row['returned_amount']));
        final count = sales.where((row) => _n(row['returned_amount']) > 0).length;
        return _en ? 'Recorded returns for $label: ${rp(amount)} across $count transactions with returns.'
            : 'Retur yang tercatat $label: ${rp(amount)} pada $count transaksi yang memiliki retur.';
      }
      if (_hasAny(q, ['berapa pelanggan', 'jumlah pelanggan', 'customer count'])) {
        final names = sales.map((s) => (s['customer_name'] ?? '').toString().trim().toLowerCase()).where((s) => s.isNotEmpty && s != 'pelanggan umum').toSet();
        return _en ? 'There are ${names.length} distinct named customers with sales recorded for $label.'
            : 'Ada ${names.length} pelanggan berbeda yang namanya tercatat pada penjualan $label.';
      }
      final amount = sales.fold<int>(0, (sum, row) => sum + _n(row['net_total']));
      final returns = sales.fold<int>(0, (sum, row) => sum + _n(row['returned_amount']));
      final txCount = sales.length;
      final items = await (await DB.database).rawQuery(
        'SELECT COALESCE(SUM(si.qty - si.returned_qty),0) AS qty FROM sale_items si INNER JOIN sales s ON s.id = si.sale_id WHERE s.sale_time >= ? AND s.sale_time < ?',
        [_stamp(period[0]), _stamp(period[1])],
      );
      return _en ? 'Sales summary for $label:\nNet sales after recorded returns: ${rp(amount)}\nTransactions: $txCount\nItems sold (after recorded returns): ${_n(items.first['qty'])}\nRecorded returns: ${rp(returns)}.'
          : 'Ringkasan penjualan $label:\nOmzet bersih setelah retur tercatat: ${rp(amount)}\nJumlah transaksi: $txCount\nBarang terjual setelah retur tercatat: ${_n(items.first['qty'])}\nNilai retur yang tercatat: ${rp(returns)}.';
    }

    if (_hasAny(q, ['produk terlaris', 'barang terlaris', 'best selling', 'best seller'])) {
      final rows = await DB.bestSelling(period[0], period[1]);
      if (rows.isEmpty) return _en ? 'No product sales are recorded for $label.' : 'Belum ada penjualan produk yang tercatat $label.';
      final lines = rows.take(5).map((r) => '• ${(r['name'] ?? r['product_name'] ?? 'Product').toString()}: ${_n(r['qty'])}').join('\n');
      return _en ? 'Best-selling products for $label:\n$lines' : 'Produk terlaris $label:\n$lines';
    }

    return null;
  }

  String? _socialReply(String q) {
    // COLONEL_V72_CONVERSATION_HELP_V1
    // Normalize punctuation/spacing so casual spellings are matched consistently.
    final normalized = q.toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final addressMatch = RegExp(r'\b(bro|sis|mas|mbak|mba|pak|bapak|bu|ibu|kang|lur|min|kak)\b')
        .firstMatch(normalized);
    final addressSuffix = addressMatch == null ? '' : ' ${addressMatch.group(1)}';
    bool hasWord(List<String> words) => words.any((word) =>
        RegExp('(?:^|\\s)' + RegExp.escape(word) + r'(?:$|\s)')
            .hasMatch(normalized));

    // Common Islamic expressions and everyday replies.
    if (hasWord(['assalamualaikum', 'assalamu alaikum', 'salamualaikum', 'assalamuallaikum'])) {
      return _en
          ? 'Waalaikumussalam warahmatullahi wabarakatuh 😊 How are you today? I can help with the shop or we can chat.'
          : 'Waalaikumsalam warahmatullahi wabarakatuh$addressSuffix 😊 Semoga sehat, lancar, dan penuh berkah. Ada yang ingin dibantu atau mau ngobrol dulu?';
    }
    if (hasWord(['waalaikumsalam', 'waalaikumussalam', 'waalaikum salam', 'wa alaikum salam'])) {
      return _en ? 'Thank you 😊 What can I help you with today?' : 'Sama-sama 😊 Semoga urusannya lancar. Ada yang bisa aku bantu?';
    }
    if (hasWord(['alhamdulillah', 'hamdulillah'])) {
      return _en ? 'Alhamdulillah 😊 I hope things keep going well. Is there good news, or would you like to share how your day is going?' : 'Alhamdulillah 😊 Semoga nikmat dan urusannya terus diberi kelancaran serta keberkahan. Ada kabar baik yang ingin diceritakan?';
    }
    if (hasWord(['bismillah', 'bis millah', 'bismilah'])) {
      return _en ? 'Bismillah 😊 I hope it goes smoothly. What are we starting today?' : 'Bismillah 😊 Semoga dimudahkan dan dilancarkan. Mau mulai mengerjakan apa hari ini?';
    }
    if (hasWord(['insyaallah', 'inshaallah', 'insya allah', 'insha allah'])) {
      return _en ? 'InshaAllah 😊 I hope it works out well. Let me know if you want help preparing for it.' : 'Insyaallah 😊 Semoga benar-benar dimudahkan. Kalau ada yang perlu disiapkan atau direncanakan, aku bantu, ya.';
    }
    if (hasWord(['aamiin', 'amin', 'ameen', 'aamiiin'])) {
      return _en ? 'Ameen, may it be so 😊' : 'Aamiin ya Rabbal ‘alamin 🤲😊 Semoga doa baiknya dikabulkan.';
    }
    if (hasWord(['masyaallah', 'masya allah', 'mashaallah', 'masha allah'])) {
      return _en ? 'MashaAllah 😊 That is lovely to hear. What happened?' : 'Masyaallah 😊 Semoga menjadi kebaikan dan keberkahan. Ada cerita apa nih?';
    }
    if (hasWord(['subhanallah', 'subhan allah'])) {
      return _en ? 'SubhanAllah 😊 What made you say that?' : 'Subhanallah 😊 Ada hal yang membuat kamu takjub, ya? Cerita dong.';
    }
    if (hasWord(['astaghfirullah', 'astagfirullah', 'astagfirullahaladzim'])) {
      return _en ? 'Astaghfirullah. I hope things get easier. Would you like to tell me what happened?' : 'Astaghfirullah. Semoga diberi ketenangan dan jalan keluar yang baik. Kalau ada yang mengganjal, boleh cerita.';
    }
    if (hasWord(['jazakallah', 'jazakumullah', 'barakallah', 'barakallahu', 'syukron', 'syukran'])) {
      return _en ? 'Wa iyyakum 😊 Thank you, and may goodness return to you too.' : 'Wa iyyakum, sama-sama 😊 Semoga kebaikan dan keberkahan juga kembali untukmu.';
    }
    if (hasWord(['innalillahi', 'innalillahiwainnailaihirojiun'])) {
      return _en ? 'Inna lillahi wa inna ilayhi raji’un. I’m sorry to hear that. May you and your family be given strength.' : 'Innalillahi wa inna ilaihi raji’un. Turut berduka, ya. Semoga yang ditinggalkan diberi kekuatan dan ketabahan.';
    }

    // Single-word forms of address, e.g. "Min", "Bro!", or "Kang..."
    // Punctuation is already normalized above.
    final singleAddress = RegExp(
      r'^(bro|sis|mas|mbak|mba|pak|bapak|bu|ibu|kang|lur|min|kak)$',
    ).firstMatch(normalized);

    if (singleAddress != null) {
      final address = singleAddress.group(1)!;
      return _en
          ? 'Yes, $address 😊 What can I help you with?'
          : 'Iya, $address 😊 Ada yang bisa aku bantu? Mau ngobrol santai juga boleh.';
    }

    // Exact short greetings; avoid matching words that merely contain hai.
    final greeting = RegExp(r'^(hai|halo|hello|hi)(?:\s+(bro|sis|mas|mbak|mba|pak|bapak|bu|ibu|kang|lur|min|kak))?$')
        .firstMatch(normalized);
    if (greeting != null) {
      final salutation = greeting.group(1)!;
      final address = greeting.group(2);
      final shown = salutation[0].toUpperCase() + salutation.substring(1);
      return address == null
          ? (_en ? 'Hi! 😊 I am ready to help, or we can chat.' : '$shown! 😊 Aku siap membantu atau ngobrol santai. Ada yang ingin kamu bahas?')
          : (_en ? '$shown $address! 😊 What can I help you with?' : '$shown $address! 😊 Ada yang bisa aku bantu?');
    }

    // Restore intent must be checked before backup intent.
    final wantsRestore = hasWord([
      'restore', 'pulihkan', 'pemulihan', 'mengembalikan',
    ]) || normalized.contains('restore backup');

    if (wantsRestore) {
      return _en
          ? 'To restore locally, open Settings → Backup & Restore → RESTORE and select a valid Colonel POS .json backup. For cloud restore, tap RESTORE FROM GOOGLE DRIVE and choose the backup. Restore replaces current data, so verify the file and version and make a fresh backup first.'
          : 'Cara restore: buka Pengaturan → Backup & Restore → tekan RESTORE lalu pilih file backup Colonel POS berformat .json. Untuk cloud, tekan RESTORE DARI GOOGLE DRIVE lalu pilih file. Restore mengganti data saat ini, jadi periksa file dan kecocokan versi serta buat backup terbaru terlebih dahulu.';
    }

    final wantsBackup = hasWord([
      'backup', 'cadangkan', 'mencadangkan', 'backupnya',
    ]);

    if (wantsBackup) {
      return _en
          ? 'To create a backup, open Settings → Backup & Restore → BACKUP and choose where to save the .json file. For a cloud copy, use BACKUP TO GOOGLE DRIVE. Keep a safe copy. RESTORE replaces current app data, so verify the file before restoring.'
          : 'Cara backup data: buka Pengaturan → Backup & Restore → tekan BACKUP, lalu pilih lokasi penyimpanan file .json. Untuk salinan cloud, tekan BACKUP KE GOOGLE DRIVE. Simpan salinan di tempat aman. Ingat, RESTORE mengganti data aplikasi saat ini, jadi periksa file sebelum memulihkan.';
    }

    // Receipt sharing uses the existing PDF/JPG share sheet in POS.
    if (RegExp(r'\b(struk|receipt|nota)\b').hasMatch(normalized) &&
        RegExp(r'\b(wa|whatsapp|kirim|bagikan|share|send|gambar|foto|pdf|jpg|jpeg)\b').hasMatch(normalized)) {
      return _en
          ? 'To send a receipt, open the transaction in POS and tap its share receipt option. Choose Share as PDF or Share as image (JPG). In Android’s share sheet, select WhatsApp, choose the contact, check the attachment, then send. If WhatsApp is not listed, install/update it or use the system share menu.'
          : 'Cara kirim struk ke WhatsApp: buka transaksi di halaman POS/riwayat transaksi, lalu pilih opsi bagikan struk. Pilih “Bagikan sebagai PDF” atau “Bagikan sebagai gambar” (JPG). Saat menu berbagi Android muncul, pilih WhatsApp, pilih kontak, periksa lampirannya, lalu tekan Kirim. Kalau WhatsApp tidak muncul, pastikan aplikasinya terpasang/terbarui dan coba menu berbagi lagi.';
    }
    if (_hasAny(q, ['siapa yang ngajarin', 'siapa yg ngajarin', 'yang ngajarin kamu', 'siapa gurumu', 'who taught you', 'who trained you'])) {
      return _en ? 'I was trained using many examples of language and knowledge, not by just one teacher. 😊 For your shop, I should still check the saved records rather than pretend to know numbers I have not verified.'
          : 'Hehe, aku dilatih menggunakan banyak contoh bahasa dan pengetahuan, Min, jadi bukan cuma diajari satu guru. 😄 Kalau urusan toko Min, aku tetap perlu memeriksa data yang tersimpan supaya nggak asal jawab.';
    }
    if (_hasAny(q, ['bisa bantu apa', 'bisa bantu apa aja', 'bisa ngapain', 'kamu bisa apa', 'what can you help', 'what can you do'])) {
      return _en ? 'I can help check sales, transactions, QRIS, stock, products, returns, and available reports. I can also brainstorm promotions, think through competition, or chat when the shop is quiet. Some financial details require Administrator access.'
          : 'Banyak, Min! Aku bisa bantu cek omzet, transaksi, QRIS, stok, produk, retur, dan laporan yang tersedia. Aku juga bisa bantu cari ide promosi, memikirkan strategi menghadapi pesaing, atau ngobrol santai saat toko sepi. Data tertentu tetap mengikuti izin Administrator, ya. 😊';
    }
    if (_hasAny(q, ['kok pinter', 'kok pintar', 'pinter banget', 'pintar banget', 'kamu hebat', 'hebat banget', 'mantap min', 'makasih', 'terima kasih', 'thanks', 'thank you', 'love you', 'kamu baik', 'good job', 'you are smart', 'so smart', 'you are clever'])) {
      return _en ? 'Hehe, thank you! 😊 I’m glad if I can help. Ask about your shop, request an idea, or just chat for a bit.'
          : 'Hehehe, makasih, Min! 😄 Senang kalau aku bisa membantu. Mau tanya soal toko, cari ide, atau ngobrol santai juga boleh.';
    }
    if (_hasAny(q, ['bosen jaga toko', 'bosan jaga toko', 'kamu bosan', 'are you bored'])) {
      return _en ? 'I do not get bored like a person, but we can use a quiet moment to brainstorm ideas—or just chat. Want to talk about something fun or ways to bring customers in?'
          : 'Wkwk, aku nggak bisa bosan seperti manusia, Min. 😄 Kalau toko lagi sepi, kita bisa cari ide supaya lebih ramai atau ngobrol ringan dulu. Min pilih yang mana?';
    }
    if (_hasAny(q, ['punya perasaan', 'kamu punya perasaan', 'do you have feelings', 'are you human'])) {
      return _en ? 'I do not have feelings like a human, but I can listen to what you share and try to respond kindly. You can talk to me or ask for help with the shop.'
          : 'Aku nggak punya perasaan seperti manusia, Min. Tapi aku bisa menanggapi ceritamu dengan hangat dan berusaha membantu. Kalau mau ngobrol atau curhat, ayo aja. 😊';
    }
    if (_hasAny(q, ['kok ngitung cepat', 'ngitungnya cepat', 'hitung cepat', 'kok cepat', 'cepat banget', 'how are you so fast', 'calculate so fast', 'why so fast'])) {
      return _en ? 'I can calculate directly from saved records, so there is no need to count them one by one manually. We can still verify important numbers against the source records.'
          : 'Karena aku bisa menghitung langsung dari catatan yang tersimpan, jadi nggak perlu menghitung satu-satu secara manual. Angka penting tetap bisa kita cocokkan dengan data sumbernya, ya.';
    }
    if (_hasAny(q, ['akurat', 'akurasi', 'ga salah', 'gak salah', 'nggak salah', 'tidak salah', 'beneran segini', 'benar kan', 'betul kan', 'are you sure', 'is this accurate', 'is it correct', 'not wrong'])) {
      return _en ? 'I’ll use the records available in Colonel POS and explain the calculation where possible. I can still be wrong if the source data is incomplete or a record was entered incorrectly. Tell me which number you want me to check.'
          : 'Aku akan memakai catatan yang tersedia di Colonel POS dan menjelaskan hitungannya kalau memungkinkan. Aku tetap bisa keliru kalau data sumber belum lengkap atau ada catatan yang salah diinput. Sebutkan angka mana yang mau kita cek, ya.';
    }
    if (_hasAny(q, ['kok hari ini sepi', 'hari ini sepi', 'kok sepi', 'toko sepi', 'jualan sepi', 'sepi banget', 'quiet today', 'shop is quiet'])) {
      return _en ? 'That can feel worrying. It may be the time of day, customer patterns, purchasing power, stock availability, or competition—we should not guess the cause. I can compare today’s sales and transaction count with a previous day to look for clues.'
          : 'Wah, semoga sebentar lagi ramai ya, Min. 😊 Jangan langsung menyimpulkan penyebabnya. Bisa jadi jamnya belum ramai, pola belanja berubah, stok barang penting kosong, atau ada faktor lain. Kalau mau, kita cek omzet dan jumlah transaksi hari ini dibanding hari sebelumnya untuk mencari petunjuk.';
    }
    if (_hasAny(q, ['minggu ini sepi', 'bulan ini sepi', 'tahun ini sepi', 'minggu sepi', 'bulan sepi', 'tahun sepi', 'omzet turun', 'omset turun', 'penjualan turun', 'sales are down', 'business is slow'])) {
      return _en ? 'I understand—that can be stressful. We can compare sales, transaction counts, and average sale size with the previous period. Those numbers can show where the change happened, though they cannot prove the cause by themselves.'
          : 'Pasti kepikiran ya, Min, kalau penjualan menurun. Kita bisa bandingkan omzet, jumlah transaksi, dan rata-rata nilai belanja dengan periode sebelumnya. Angka itu membantu mencari petunjuk apakah pembeli berkurang atau nilai belanjanya mengecil, walau penyebab pastinya perlu dilihat dari kondisi toko juga.';
    }
    if (_hasAny(q, ['naikin omset', 'naikkan omset', 'menaikkan omzet', 'cara meningkatkan omzet', 'resep naikin', 'biar ramai', 'biar rame', 'increase sales', 'boost revenue', 'marketing ideas'])) {
      return _en ? 'Try a few measurable steps: focus on products with healthy margins, create relevant bundles, offer useful add-ons, keep key items in stock, and invite repeat visits with a simple promotion. Compare transactions and profit before and after; avoid discounts that erase your margin.'
          : 'Siap, Min! Kita coba resep realistis: (1) fokus pada barang yang laku dan marginnya sehat, (2) buat paket barang yang cocok dibeli bersama, (3) tawarkan produk pelengkap yang relevan, (4) jaga stok barang penting, dan (5) buat promo sederhana untuk pelanggan lama. Bandingkan transaksi dan keuntungan sebelum-sesudah, ya. Jangan sampai diskon bikin margin habis.';
    }
    if (_hasAny(q, ['banyak saingan', 'banyak pesaing', 'kompetitor', 'saingan jual', 'pesaing jual', 'bersaing gimana', 'cara bersaing', 'competition', 'competitors'])) {
      return _en ? 'Do not rush into a price war. Compare key-item prices, keep popular products available, make service reliable and friendly, and give customers a reason to return. Compete on convenience and trust as well as price.'
          : 'Kalau pesaing banyak, jangan buru-buru perang harga, Min. Coba jaga stok barang yang sering dicari, layani dengan ramah dan konsisten, pastikan harga barang utama tetap kompetitif, dan beri alasan pelanggan untuk kembali. Kepercayaan serta kenyamanan juga bisa jadi keunggulan toko.';
    }
    if (_hasAny(q, ['jual lebih murah', 'harga pesaing', 'ikut murah', 'perang harga', 'cheaper than me', 'price war'])) {
      return _en ? 'Not every item needs to be the cheapest. Check purchase cost and margin first; stay competitive on price-sensitive essentials, and compete on service, availability, and convenience elsewhere.'
          : 'Belum tentu semua barang harus paling murah, Min. Cek modal dan margin dulu. Untuk barang yang sensitif terhadap harga, pertimbangkan harga kompetitif; untuk barang lain, unggulkan pelayanan, ketersediaan, dan kenyamanan. Jangan sampai omzet naik tetapi keuntungan habis.';
    }
    if (_hasAny(q, ['pelanggan balik', 'pelanggan kembali', 'pelanggan tetap', 'repeat customers', 'customer loyalty'])) {
      return _en ? 'Make the experience reliable: friendly service, clear prices, popular items in stock, and thoughtful handling of complaints. If suitable, offer a simple repeat-customer promotion and measure whether it helps.'
          : 'Mulai dari hal sederhana, Min: pelayanan ramah, harga jelas, stok barang yang dicari tersedia, dan komplain ditangani dengan baik. Kalau cocok, buat promo sederhana untuk pelanggan yang kembali, lalu lihat apakah hasilnya benar-benar membantu.';
    }
    if (_hasAny(q, ['kasih diskon', 'promo apa', 'ide promosi', 'promosi apa', 'diskon biar', 'discount', 'promotion idea'])) {
      return _en ? 'Promotions can help, but check margin first. A bundle, a small gift, or a minimum-purchase offer may work better than a broad discount. Test one idea and compare sales and profit.'
          : 'Promo boleh dicoba, Min, tapi hitung margin dulu. Paket hemat, bonus kecil, atau promo dengan minimum belanja kadang lebih sehat daripada diskon besar untuk semua barang. Uji satu ide, lalu bandingkan omzet dan keuntungan.';
    }
    if (_hasAny(q, ['ramal besok', 'besok ramai', 'besok bakal ramai', 'predict tomorrow', 'will it be busy'])) {
      return _en ? 'I cannot know for sure. We can look at sales patterns from similar days and hours to make a rough estimate, but it is not a guarantee.'
          : 'Kalau memastikan besok ramai atau tidak, aku belum bisa, Min. 😄 Tapi kita bisa melihat pola penjualan pada hari dan jam yang mirip untuk membuat perkiraan sederhana. Itu petunjuk, bukan jaminan.';
    }
    if (_hasAny(q, ['nggak kaya', 'ga kaya', 'gak kaya', 'tidak kaya', 'jualan kok', 'jualan tidak maju', 'usaha nggak maju', 'usaha tidak maju', 'not getting rich', 'business is not growing'])) {
      return _en ? 'Sales are not the same as profit. Review product margins, operating expenses, slow-moving stock, and unpaid receivables. Do not blame yourself too quickly; start with one number you can improve this week.'
          : 'Aku paham rasanya, Min. Uang yang masuk belum tentu jadi keuntungan karena ada modal barang, biaya, stok lambat laku, dan piutang. Jangan langsung menyalahkan diri sendiri. Kita bisa mulai dari cek margin produk, pengeluaran, dan barang yang lama tidak bergerak, lalu pilih satu hal untuk dibenahi dulu.';
    }
    if (_hasAny(q, ['aku capek', 'saya capek', 'capek banget', 'lelah jualan', 'capek jualan', 'bad mood', 'sedih banget', 'lagi sedih', 'lagi stres', 'stress', 'stressed', 'i am tired', 'i feel tired'])) {
      return _en ? 'That sounds exhausting. Running a shop means handling customers, stock, money, and lots of little problems. If you can, take a short break. Want to tell me what has been weighing on you most?'
          : 'Aduh, kedengarannya berat ya, Min. Jualan itu banyak yang dipikirkan: pelanggan, stok, modal, dan biaya. Kalau memungkinkan, istirahat sebentar dulu. Mau cerita, apa yang paling bikin Min capek akhir-akhir ini? Aku dengarkan.';
    }
    if (_hasAny(q, ['punya perasaan', 'kamu punya perasaan', 'do you have feelings', 'are you human'])) {
      return _en ? 'I do not have feelings like a human, but I can listen to what you share and try to respond kindly.'
          : 'Aku nggak punya perasaan seperti manusia, Min. Tapi aku bisa menanggapi ceritamu dengan hangat dan berusaha membantu. Kalau mau ngobrol atau curhat, ayo aja. 😊';
    }
    // Opening greetings and polite replies should be handled before general fallback.
    if (_hasAny(q, ['assalamualaikum', 'assalamu alaikum', 'assalamu’alaikum', "assalamu'alaikum", 'salamualaikum'])) {
      return _en
          ? 'Waalaikumussalam! 😊 Welcome, how can I help you today? We can check your shop records, think about business ideas, or just chat.'
          : 'Waalaikumsalam warahmatullahi wabarakatuh, Min. 😊 Semoga hari ini lancar dan penuh berkah. Ada yang mau ditanyakan, cek data toko, cari ide usaha, atau ngobrol santai dulu?';
    }
    if (_hasAny(q, ['waalaikumsalam', 'wa alaikum salam', 'waalaikum salam', 'waalaikumussalam'])) {
      return _en ? 'Thank you! 😊 What can I help you with today?' : 'Sama-sama, Min. 😊 Semoga urusannya lancar. Ada yang bisa aku bantu?';
    }
    if (_hasAny(q, ['selamat pagi', 'pagi min', 'pagi, min', 'good morning', 'morning'])) {
      return _en ? 'Good morning! ☀️ Hope your day goes smoothly. Want to check the shop numbers, plan a promotion, or just chat?' : 'Selamat pagi, Min! ☀️ Semoga dagangannya lancar, pembelinya ramai, dan rezekinya berkah. Mau cek data toko, cari ide promosi, atau ngobrol santai dulu?';
    }
    if (_hasAny(q, ['selamat siang', 'siang min', 'siang, min', 'good afternoon'])) {
      return _en ? 'Good afternoon! 😊 Hope everything is going well. What can I help you with?' : 'Selamat siang, Min! 😊 Semoga jualannya lancar, ya. Ada yang mau dicek atau mau ngobrol sebentar sambil menunggu pembeli?';
    }
    if (_hasAny(q, ['selamat sore', 'sore min', 'sore, min', 'good evening'])) {
      return _en ? 'Good evening! 😊 How is the shop going? I can help check the numbers or brainstorm ways to bring customers in.' : 'Selamat sore, Min! 😊 Gimana kabar toko hari ini? Mau cek hasil penjualan sementara, cari ide supaya lebih ramai, atau ngobrol santai?';
    }
    if (_hasAny(q, ['selamat malam', 'malam min', 'malam, min', 'good night'])) {
      return _en ? 'Good evening! 🌙 Hope your day went well. Would you like to review today’s sales or wind down with a chat?' : 'Selamat malam, Min! 🌙 Semoga hari ini tetap membawa rezeki. Kalau mau, kita bisa cek penjualan hari ini atau ngobrol santai dulu. Kalau sudah lelah, jangan lupa istirahat juga, ya.';
    }
    if (_hasAny(q, ['apa kabar', 'gimana kabar', 'kabarmu', 'how are you'])) {
      return _en ? 'I’m here and ready to help! 😊 How are you and how is the shop today?' : 'Aku siap menemani dan membantu, Min! 😊 Kalau Min sendiri gimana kabarnya? Toko hari ini ramai atau lagi agak sepi?';
    }
    if (_hasAny(q, ['halo', 'hai', 'hello', 'hi', 'permisi min', 'tes min', 'test min'])) {
      return _en ? 'Hi! 👋 Ask me about sales, QRIS, products, stock, customers, returns, and reports. We can also brainstorm business ideas or just chat.' : 'Halo, Min! 👋 Aku siap bantu. Bisa tanya soal omzet, QRIS, stok, produk, pelanggan, retur, dan laporan. Mau cari ide usaha atau ngobrol santai juga boleh.';
    }
    return null;
  }

  int _consecutiveDataQuestionCount = 0;


  Future<void> _loadQuestionBank() async {
    try {
      final source = await rootBundle.loadString(
        'lib/features/home/assistant_question_bank_v72.json',
      );
      final decoded = jsonDecode(source);
      if (!mounted || decoded is! List) return;
      final entries = decoded
          .whereType<Map>()
          .map((entry) => Map<String, dynamic>.from(entry))
          .where((entry) =>
              entry['question'] is String && entry['intent'] is String)
          .toList();
      if (!mounted) return;
      setState(() => _questionBank = entries);
    } catch (_) {
      // Keep the existing assistant working if the optional bank cannot load.
    }
  }

  String _bankPeriodPhrase(String q) {
    for (final phrase in [
      'kemarin', 'yesterday', 'minggu lalu', 'last week',
      'minggu ini', 'this week', 'bulan lalu', 'last month',
      'bulan ini', 'this month', 'tahun lalu', 'last year',
      'tahun ini', 'this year',
    ]) {
      if (q.contains(phrase)) return phrase;
    }
    return _en ? 'today' : 'hari ini';
  }

  String? _detectBankIntent(String q) {
    if (_hasAny(q, [
      'hutang usaha', 'utang usaha', 'hutang toko', 'utang toko',
      'hutang supplier', 'utang supplier', 'hutang ke supplier',
      'utang ke supplier', 'hutang kepada supplier',
      'utang kepada supplier', 'hutang pada supplier',
      'utang pada supplier', 'payable', 'payables',
    ])) return 'hutang_usaha';

    // Keep named-customer searches on their existing database path.
    if (_isCustomerQuestion(q) &&
        !_hasAny(q, [
          'berapa pelanggan', 'jumlah pelanggan',
          'total pelanggan', 'customer count',
        ])) {
      return null;
    }

    if (_hasAny(q, [
      'qris pending', 'qris gagal', 'qris belum masuk', 'status qris',
      'transfer belum masuk', 'pembayaran pending',
      'pembayaran belum terkonfirmasi',
    ])) return 'status_pembayaran';

    if (_hasAny(q, [
      'cara retur', 'prosedur retur', 'bagaimana retur',
      'how to return', 'return procedure',
    ])) return 'panduan_retur';

    if (_hasAny(q, ['printer', 'struk', 'cetak', 'print'])) {
      return 'bantuan_printer';
    }
    if (_hasAny(q, [
      'lupa password', 'lupa sandi', 'kata sandi', 'akun terkunci',
      'tidak bisa masuk', 'login', 'password',
    ])) return 'bantuan_login';
    if (_hasAny(q, [
      'keamanan', 'privasi', 'data pribadi', 'security', 'privacy',
    ])) return 'keamanan';
    if (_hasAny(q, [
      'backup', 'cadangkan database', 'ekspor backup',
      'pemulihan database', 'restore database',
    ])) return 'panduan_backup';

    if (_hasAny(q, [
      'berapa pelanggan', 'jumlah pelanggan', 'total pelanggan',
      'customer count',
    ])) return 'jumlah_pelanggan';

    if (_hasAny(q, ['retur', 'return barang', 'pengembalian barang'])) {
      return 'laporan_retur';
    }
    if (_hasAny(q, ['qris']) &&
        _hasAny(q, [
          'berapa', 'jumlah', 'total', 'omzet', 'omset', 'transaksi',
          'laporan', 'amount', 'count', 'how much', 'how many',
        ])) return 'laporan_qris';

    if (_hasAny(q, ['transfer']) &&
        _hasAny(q, [
          'berapa', 'jumlah', 'total', 'transaksi', 'laporan',
          'amount', 'count', 'how much', 'how many',
        ])) return 'laporan_transfer';

    if (_hasAny(q, ['tunai', 'cash']) &&
        _hasAny(q, [
          'berapa', 'jumlah', 'total', 'transaksi', 'laporan',
          'amount', 'count', 'how much', 'how many',
        ])) return 'laporan_tunai';

    if (_hasAny(q, [
      'pengeluaran', 'biaya', 'biaya operasional', 'expense',
      'expenses', 'expense total',
    ])) return 'laporan_pengeluaran';

    if (_hasAny(q, ['laba', 'rugi', 'profit', 'loss', 'ringkasan keuangan'])) {
      return 'ringkasan_keuangan';
    }

    if (_hasAny(q, [
      'bayar tunda', 'bayar nanti', 'piutang', 'receivable',
      'unpaid customer',
    ])) return 'piutang';

    if (_hasAny(q, [
      'produk terlaris', 'barang terlaris', 'best selling', 'best seller',
      'produk paling laku',
    ])) return 'produk_terlaris';

    if (_hasAny(q, ['stok', 'stock', 'persediaan'])) {
      return 'stok_produk';
    }
    if (_hasAny(q, ['harga produk', 'harga barang', 'harga jual', 'product price'])) {
      return 'harga_produk';
    }

    if (_hasAny(q, ['omzet', 'omset', 'revenue']) ||
        (_hasAny(q, ['penjualan', 'jualan', 'sales', 'transaksi']) &&
         _hasAny(q, [
           'berapa', 'jumlah', 'total', 'laporan', 'hari ini', 'kemarin',
           'bulan ini', 'bulan lalu', 'tahun ini', 'minggu ini',
           'amount', 'count', 'how much', 'how many',
         ]))) {
      return 'laporan_penjualan';
    }
    return null;
  }

  String _normalizeQuestionFromBank(String q) {
    if (_questionBank.isEmpty) return q;
    final intent = _detectBankIntent(q);
    if (intent == null ||
        !_questionBank.any((entry) => entry['intent'] == intent)) {
      return q;
    }

    final period = _bankPeriodPhrase(q);
    switch (intent) {
      case 'laporan_penjualan':
        return 'omzet $period';
      case 'laporan_qris':
        return 'berapa total qris $period';
      case 'laporan_tunai':
        return 'berapa total tunai $period';
      case 'laporan_transfer':
        return 'berapa total transfer $period';
      case 'laporan_retur':
        return 'berapa total retur $period';
      case 'laporan_pengeluaran':
        return 'total pengeluaran $period';
      case 'ringkasan_keuangan':
        return 'laba $period';
      case 'hutang_usaha':
        return 'hutang usaha $period';
      case 'piutang':
        return 'piutang $period';
      case 'produk_terlaris':
        return 'produk terlaris $period';
      case 'jumlah_pelanggan':
        return 'jumlah pelanggan $period';
      default:
        return q;
    }
  }


  String _unknownReply() {
    final id = <String>[
      "Hmm, coba ceritain sedikit lagi maksudmu 😊 Biar aku nggak salah nangkep.",
      "Wah, aku belum nyambung nih 😄 Maksudmu bagian yang mana?",
      "Boleh jelasin sedikit lagi? Aku ingin jawab sesuai maksudmu.",
      "Hehe, sepertinya aku belum menangkap maksudmu 😅 Coba dengan cara lain, yuk.",
      "Aku simak, kok 😊 Tambahin sedikit konteks, ya.",
      "Hmm, aku masih agak bingung. Bisa kasih contoh?",
      "Bisa jadi aku salah paham. Ceritain lagi, ya.",
      "Oke, kita coba dari awal 😊 Kamu ingin membahas apa?",
      "Aku mau bantu, nih. Kasih sedikit petunjuk, dong.",
      "Sepertinya aku perlu penjelasan tambahan. Santai aja, ceritain pelan-pelan.",
      "Belum ketemu maksudnya, nih 😅 Coba jelasin sedikit lagi.",
      "Daripada asal jawab, boleh aku minta sedikit penjelasan?",
      "Hmm, bisa diperjelas? Aku nggak mau menebak-nebak.",
      "Kasih aku gambaran sedikit lagi, ya. Kita cari tahu bareng.",
      "Aku belum paham betul, tapi kita bisa coba lagi 😊",
      "Kayaknya ada konteks yang belum aku tangkap. Ceritain sedikit, boleh?",
      "Boleh banget kita bahas. Aku cuma perlu sedikit konteks.",
      "Aku belum bisa menjawab dengan yakin. Apa yang ingin kamu capai?",
      "Kalau aku salah menangkap, koreksi aja, ya 😄",
      "Aku nggak mau sok tahu lalu malah menyesatkanmu.",
      "Kamu mau mencari informasi, minta saran, atau sekadar ngobrol?",
      "Aku belum memahami kalimat itu. Bisa dibuat lebih sederhana?",
      "Nggak apa-apa, kita coba cara lain. Bagian mana yang ingin dibahas?",
      "Aku di sini untuk membantu. Ceritakan sedikit lebih banyak, ya.",
      "Sepertinya aku butuh petunjuk tambahan 😄",
      "Kalau tentang toko, sebutkan bagian yang ingin dicek. Kalau mau ngobrol juga boleh.",
      "Aku belum yakin dengan maksud pertanyaanmu. Coba susun ulang, ya.",
      "Biar nggak salah paham, apa maksudmu dengan pertanyaan tadi?",
      "Kita bisa pecah pertanyaannya jadi lebih sederhana.",
      "Hmm, aku belum paham sepenuhnya. Lanjutkan ceritamu, yuk."
    ];
    final en = <String>[
      "Hmm, could you tell me a little more? I don't want to misunderstand 😊",
      "I haven't quite got you yet. Which part do you mean?",
      "Could you add some context so I can help?",
      "I might be missing something 😅 Could you phrase that another way?",
      "I'm listening. Tell me a little more and we'll work it out.",
      "I don't want to guess and give you the wrong answer. Could you clarify?",
      "Could you give me an example?",
      "Let's try again 😊 What are you hoping to find out?",
      "I may have misunderstood. Could you explain a little more?",
      "No worries—we can approach it another way.",
      "I can't confidently answer that yet. A little more detail would help.",
      "Could you share what happened before this question?",
      "I'm not quite following yet, but I'm happy to try again.",
      "Would you mind narrowing it down a little?",
      "I don't have enough context to answer accurately.",
      "Let's break it into smaller pieces. What's the main thing you want to know?",
      "I may be taking that the wrong way. Feel free to correct me.",
      "Could you describe what you're trying to do?",
      "If this is about your store, tell me what you'd like to check. We can also chat.",
      "I'm not sure what you mean yet. Try asking another way."
    ];
    final choices = _en ? en : id;
    final i = _fallbackReplyCount % choices.length;
    _fallbackReplyCount++;
    return choices[i];
  }

  Future<String> _reply(String raw) async {
    final originalQ = raw.toLowerCase().trim();
    final q = _normalizeQuestionFromBank(originalQ);
    if (q.isEmpty) return _en ? 'Please type a question first.' : 'Tulis pertanyaanmu dulu, ya.';

    if (!_admin && (_adminOnlyQuestion(q) || (_isCustomerDebtQuestion(originalQ)))) {
      return _en ? 'Sorry 😊 This information requires Administrator permission. Please ask your Admin to check it. Your access remains limited to the functions allowed for your cashier role.'
          : 'Maaf ya 😊 Informasi ini memerlukan izin Administrator. Minta Admin memeriksanya, ya. Aksesmu tetap dibatasi sesuai fungsi yang diizinkan untuk Kasir.';
    }

    // Prioritize explicit POS data questions even when they include a greeting or thanks.
    final dataAnswer = await _answerDataQuestion(q);
    if (dataAnswer != null) {
      _consecutiveDataQuestionCount++;
      if (_consecutiveDataQuestionCount % 3 == 0) {
        final reminder = _en
            ? 'For extra confidence, you can also verify the figures directly on the Reports or Finance page 😊'
            : 'Biar makin yakin, kamu juga bisa cek langsung angkanya di halaman Laporan atau Keuangan, ya 😊';
        return '$dataAnswer\n\n$reminder';
      }
      return dataAnswer;
    }

    // A non-data answer breaks the sequence, so reminders only follow every third consecutive data answer.
    _consecutiveDataQuestionCount = 0;
    final social = _socialReply(originalQ);
    if (social != null) return social;

    if (_hasAny(q, ['laci', 'uang fisik', 'selisih uang', 'cash drawer', 'cash mismatch'])) {
      return _en
          ? 'Let’s check step by step:\n1. Count the physical cash again.\n2. Check the report date and period.\n3. Review cash sales, change, returns, and cash movements.\n4. Compare the amounts again. Do not delete transactions just to force a match.'
          : 'Kita cek pelan-pelan, ya:\n1. Hitung ulang uang fisik di laci.\n2. Pastikan tanggal dan periode laporan benar.\n3. Periksa penjualan tunai, uang kembalian, retur, serta uang masuk atau keluar dari laci.\n4. Cocokkan lagi jumlahnya. Jangan menghapus transaksi hanya agar angkanya sama.';
    }
    if (_hasAny(q, ['qris pending', 'qris gagal', 'qris belum masuk', 'status qris', 'transfer belum masuk', 'pembayaran pending'])) {
      return _en ? 'Check the payment status with the payment provider first. Do not mark an unconfirmed payment as successful. If the status remains unclear, ask your Admin to verify the transaction.'
          : 'Periksa status pembayaran melalui penyedia pembayaran terlebih dahulu. Jangan tandai pembayaran yang belum terkonfirmasi sebagai berhasil. Jika statusnya belum jelas, minta Admin memeriksa transaksi tersebut.';
    }
    if (_hasAny(q, ['retur', 'return barang', 'mengembalikan barang', 'barang dikembalikan'])) {
      return _en ? 'Open the original transaction and verify the returned items and quantities. Follow the store return procedure and check that the saved return is reflected in the report.'
          : 'Buka transaksi asal, lalu cocokkan barang dan jumlah yang dikembalikan. Ikuti prosedur retur toko dan pastikan retur yang disimpan sudah tercermin di laporan.';
    }
    if (_hasAny(q, ['login', 'password', 'kata sandi', 'lupa sandi'])) {
      return _en ? 'Check your username and password. If you forgot your password or your account is blocked, contact your Admin. Never share your password.'
          : 'Periksa username dan kata sandi. Jika lupa kata sandi atau akun terkunci, hubungi Admin. Jangan membagikan kata sandi.';
    }
    if (_hasAny(q, ['printer', 'struk', 'cetak', 'print'])) {
      return _en ? 'Check that the printer is powered on, connected, and selected correctly. If it still fails, ask your Admin to check the printer configuration.'
          : 'Pastikan printer menyala, terhubung, dan dipilih dengan benar. Jika masih gagal, minta Admin memeriksa pengaturan printer.';
    }
    if (_hasAny(q, ['aman', 'keamanan', 'keamanan data', 'data pribadi', 'privasi', 'security', 'safe', 'secure', 'privacy', 'personal data'])) {
      return _en ? 'Good question 😊 No application should be assumed to be 100% secure. Use a strong, unique password, do not share your login, lock your device, and give Administrator access only to trusted people. I cannot confirm specific security protections without verified details.'
          : 'Pertanyaan bagus 😊 Tidak ada aplikasi yang bisa dianggap 100% aman. Gunakan kata sandi yang kuat dan berbeda, jangan bagikan akun, kunci perangkat, dan berikan akses Administrator hanya kepada orang tepercaya. Aku belum bisa memastikan perlindungan keamanan tertentu tanpa informasi yang terverifikasi.';
    }
    if (_hasAny(q, ['langganan', 'berlangganan', 'biaya langganan', 'harga langganan', 'paket langganan', 'cara berlangganan', 'lisensi', 'aktivasi lisensi', 'subscription', 'subscribe', 'subscription price', 'pricing', 'license', 'licence'])) {
      return _en ? 'For subscription or license details, check the official Colonel POS information or contact the application provider or your Administrator. I do not have verified current pricing or plans, so I do not want to guess. Verify payment details through an official channel before paying.'
          : 'Untuk informasi langganan atau lisensi, periksa informasi resmi Colonel POS atau hubungi penyedia aplikasi maupun Administrator. Aku belum memiliki informasi terverifikasi tentang harga atau paket, jadi aku tidak ingin menebak. Pastikan detail pembayaran melalui kanal resmi sebelum membayar.';
    }
    return _unknownReply();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
  }

  void _ask() {
    final question = _input.text.trim();
    if (question.isEmpty) return;
    final turn = _AssistantTurn(question);
    setState(() {
      _turns.add(turn);
      _input.clear();
    });
    _typingController.repeat();
    _scrollToBottom();
    _processTurn(turn);
  }

  Future<void> _processTurn(_AssistantTurn turn) async {
    String answer;
    final style = _rememberConversationStyle(turn.question);
    try {
      answer = await _reply(turn.question);
    } catch (_) {
      answer = _en
          ? 'I could not read the required records right now. Please try again. No amount has been guessed.'
          : 'Aku belum bisa membaca data yang diperlukan saat ini. Coba lagi, ya. Aku tidak akan menebak nominalnya.';
    }
    answer = _replacePronouns(answer, style);
    if (!mounted) return;
    setState(() {
      turn.answer = answer;
      turn.loading = false;
    });
    if (!_turns.any((t) => t.loading)) _typingController.stop();
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: SizedBox(
        height: 370,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.support_agent_rounded, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  AppLocalizations.t('Colonel Smart Assistent', 'Colonel Smart Assistent'),
                  style: const TextStyle(fontFamily: 'sans-serif-condensed', fontSize: 16, fontWeight: FontWeight.w800, color: Colors.red),
                )),
                Container(
                  width: 9,
                  height: 9,
                  decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                ),
              ]),
              const SizedBox(height: 7),
              Expanded(
                child: ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.only(bottom: 6),
                  itemCount: _turns.isEmpty ? 1 : _turns.length,
                  itemBuilder: (context, index) {
                    if (_turns.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.chat_bubble_outline_rounded, color: Colors.green, size: 28),
                            const SizedBox(height: 8),
                            Text(
                              AppLocalizations.t('Tanyakan apa saja tentang data Colonel POS.', 'Ask about data saved in Colonel POS.'),
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      );
                    }
                    final turn = _turns[index];
                    final answer = turn.answer ?? '';
                    final canCollapse = answer.length > 180;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Align(
                            alignment: Alignment.centerRight,
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 290),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(color: colors.primaryContainer, borderRadius: BorderRadius.circular(12)),
                              child: Text(turn.question, style: const TextStyle(fontSize: 12.5, height: 1.3)),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Padding(padding: EdgeInsets.only(top: 4, right: 7), child: Icon(Icons.support_agent_rounded, color: Colors.green, size: 19)),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(color: colors.surface, border: Border.all(color: colors.outlineVariant), borderRadius: BorderRadius.circular(12)),
                                child: turn.loading
                                    ? Row(mainAxisSize: MainAxisSize.min, children: [
                                        _TypingDots(controller: _typingController),
                                        const SizedBox(width: 8),
                                        Text(AppLocalizations.t('Sedang menyiapkan jawaban…', 'Preparing an answer…'), style: TextStyle(fontSize: 11.5, color: colors.onSurfaceVariant)),
                                      ])
                                    : Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          AnimatedSize(
                                            duration: const Duration(milliseconds: 180),
                                            alignment: Alignment.topLeft,
                                            child: Text(
                                              answer,
                                              maxLines: canCollapse && !turn.expanded ? 4 : null,
                                              overflow: canCollapse && !turn.expanded ? TextOverflow.ellipsis : TextOverflow.visible,
                                              style: const TextStyle(fontSize: 12.5, height: 1.35),
                                            ),
                                          ),
                                          if (canCollapse)
                                            Align(
                                              alignment: Alignment.centerRight,
                                              child: TextButton.icon(
                                                style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 4)),
                                                onPressed: () => setState(() => turn.expanded = !turn.expanded),
                                                icon: Icon(turn.expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, size: 18),
                                                label: Text(turn.expanded ? AppLocalizations.t('Ringkas', 'Show less') : AppLocalizations.t('Buka jawaban', 'Read more'), style: const TextStyle(fontSize: 11)),
                                              ),
                                            ),
                                        ],
                                      ),
                              ),
                            ),
                          ]),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    minLines: 1,
                    maxLines: 3,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _ask(),
                    decoration: InputDecoration(
                      hintText: AppLocalizations.t('Assalamualaikum.. 👋', 'Assalamualaikum.. 👋'),
                      hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                      isDense: true,
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.all(10),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton.filled(
                  tooltip: AppLocalizations.t('Kirim', 'Send'),
                  style: IconButton.styleFrom(backgroundColor: const Color(0xFF38BDF8), foregroundColor: Colors.white),
                  onPressed: _ask,
                  icon: const Icon(Icons.arrow_upward_rounded),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypingDots extends StatelessWidget {
  const _TypingDots({required this.controller});
  final Animation<double> controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final active = (controller.value * 3).floor().clamp(0, 2);
        return Row(mainAxisSize: MainAxisSize.min, children: List.generate(3, (i) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 90),
            margin: const EdgeInsets.only(right: 4),
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.green.withOpacity(i == active ? 1 : 0.25),
            ),
          );
        }));
      },
    );
  }
}

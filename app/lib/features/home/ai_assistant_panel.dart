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
    ]) || (_hasAny(q, ['hutang', 'utang', 'payables']) &&
            !_hasAny(q, ['piutang', 'receivable']) && !_isCustomerQuestion(q)) ||
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
    final asksCustomerRanking = _hasAny(q, [
      'pelanggan teratas', 'pelanggan terunggul', 'pelanggan paling royal',
      'pelanggan paling loyal', 'paling royal', 'paling loyal',
      'top customers', 'best customer', 'most loyal customer',
    ]);

    final asksCustomer = _isCustomerQuestion(q);

    final asksTopCustomersExpanded = asksCustomerRanking || _hasAny(q, [
      'top customer', 'top customers', 'customer teratas',
      'pelanggan paling atas', 'pembeli teratas',
      'pelanggan paling royal', 'pelanggan paling loyal',
      'pelanggan belanja terbanyak', 'pelanggan paling banyak belanja',
      'pembeli paling banyak belanja', 'most valuable customer',
      'highest spending customer', 'most frequent customer',
    ]);

    final hasExplicitPeriod = _hasAny(q, [
      'hari ini', 'today', 'kemarin', 'yesterday',
      'minggu ini', 'minggu lalu', 'this week', 'last week',
      'bulan ini', 'bulan lalu', 'this month', 'last month',
      'tahun ini', 'tahun lalu', 'this year', 'last year',
    ]);

    final reportRange = hasExplicitPeriod
        ? _period(q)
        : <DateTime>[
            DateTime(1970, 1, 1),
            DateTime.now().add(const Duration(days: 1)),
          ];

    final reportLabel = hasExplicitPeriod
        ? _periodLabel(q)
        : (_en ? 'all recorded history' : 'seluruh riwayat tersimpan');

    // KAS AKTUAL: samakan rumus dengan kartu Kas Aktual di FinancePage.
    final asksCashActual = _hasAny(q, [
      'kas aktual', 'saldo kas aktual', 'jumlah kas aktual',
      'kas saat ini', 'saldo kas saat ini', 'uang kas aktual',
      'actual cash', 'actual cash balance', 'cash balance',
      'kas bersih aktual',
    ]);

    if (asksCashActual) {
      if (!_admin) {
        return _en
            ? 'The actual-cash balance is restricted to Administrator access. Please ask your Admin to check Finance.'
            : 'Informasi kas aktual hanya tersedia untuk Administrator. Minta Admin memeriksanya di halaman Keuangan, ya.';
      }

      final db = await DB.database;

      final salesRows = await db.rawQuery('''
        SELECT COALESCE(
          SUM(
            s.total - COALESCE(
              (
                SELECT SUM(si.returned_qty * si.price)
                FROM sale_items si
                WHERE si.sale_id = s.id
              ), 0
            )
          ), 0
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

      final expenseRows = await db.rawQuery('''
        SELECT COALESCE(SUM(amount), 0) AS total
        FROM expenses
        WHERE UPPER(TRIM(COALESCE(payment_status, ''))) = 'LUNAS'
      ''');

      final collected = _n(salesRows.first['total']);
      final paidExpenses = _n(expenseRows.first['total']);
      final actualCash = collected - paidExpenses;

      return _en
          ? 'Recorded actual-cash balance: ${rp(actualCash)}. '
            'Calculation: collected sales after recorded returns '
            'and settled pay-later transactions (${rp(collected)}) '
            'minus expenses marked paid (${rp(paidExpenses)}). '
            'This is the app-recorded balance, not a physical count '
            'of money in the cash drawer.'
          : 'Kas aktual tercatat saat ini: ${rp(actualCash)}. '
            'Perhitungan: pemasukan penjualan setelah retur tercatat '
            'termasuk transaksi bayar tunda yang sudah lunas (${rp(collected)}) '
            'dikurangi pengeluaran berstatus lunas (${rp(paidExpenses)}). '
            'Ini saldo menurut catatan aplikasi, bukan hasil menghitung '
            'uang fisik di laci kasir.';
    }

    // JAM / HARI / MINGGU / BULAN TERSIBUK.
    // Peringkat menggunakan jumlah transaksi, bukan nilai omzet.
    final busyHour = _hasAny(q, [
      'jam paling sibuk', 'jam tersibuk', 'jam paling ramai',
      'jam teramai', 'waktu paling sibuk', 'waktu paling ramai',
      'peak hour', 'busiest hour', 'busiest time',
    ]);

    final busyWeekday = !busyHour && _hasAny(q, [
      'hari paling sibuk', 'hari tersibuk', 'hari paling ramai',
      'hari teramai', 'hari apa paling ramai', 'hari apa paling sibuk',
      'busiest day', 'busiest weekday',
    ]);

    final busyWeek = !busyHour && !busyWeekday && _hasAny(q, [
      'minggu paling sibuk', 'minggu tersibuk',
      'pekan paling sibuk', 'pekan tersibuk',
      'minggu paling ramai', 'busiest week',
    ]);

    final busyMonth = !busyHour && !busyWeekday && !busyWeek &&
        _hasAny(q, [
          'bulan paling sibuk', 'bulan tersibuk',
          'bulan paling ramai', 'bulan teramai',
          'busiest month', 'peak month',
        ]);

    if (busyHour || busyWeekday || busyWeek || busyMonth) {
      if (!_admin) {
        return _en
            ? 'Busy-period analysis requires Administrator access.'
            : 'Analisis waktu tersibuk memerlukan akses Administrator.';
      }

      final String bucketExpr;
      if (busyHour) {
        bucketExpr = "substr(sale_time,12,2)";
      } else if (busyWeekday) {
        bucketExpr = "strftime('%w', substr(sale_time,1,10))";
      } else if (busyWeek) {
        bucketExpr = "strftime('%Y-%W', sale_time)";
      } else {
        bucketExpr = "substr(sale_time,1,7)";
      }

      final db = await DB.database;
      final rows = await db.rawQuery(
        'SELECT $bucketExpr AS bucket, COUNT(*) AS transactions '
        'FROM sales WHERE sale_time >= ? AND sale_time < ? '
        'GROUP BY bucket '
        'ORDER BY transactions DESC, bucket ASC LIMIT 5',
        [_stamp(reportRange[0]), _stamp(reportRange[1])],
      );

      if (rows.isEmpty) {
        return _en
            ? 'No transactions were recorded for $reportLabel, so the busiest period cannot be determined yet.'
            : 'Belum ada transaksi tercatat untuk $reportLabel, jadi waktu tersibuk belum bisa ditentukan.';
      }

      const weekdaysId = [
        'Minggu', 'Senin', 'Selasa', 'Rabu',
        'Kamis', 'Jumat', 'Sabtu',
      ];
      const weekdaysEn = [
        'Sunday', 'Monday', 'Tuesday', 'Wednesday',
        'Thursday', 'Friday', 'Saturday',
      ];

      final lines = rows.map((row) {
        final bucket = (row['bucket'] ?? '-').toString();
        String label = bucket;

        if (busyHour) {
          label = '$bucket:00–$bucket:59';
        } else if (busyWeekday) {
          final index = int.tryParse(bucket);
          if (index != null && index >= 0 && index < 7) {
            label = _en ? weekdaysEn[index] : weekdaysId[index];
          }
        } else if (busyWeek) {
          label = '${_en ? 'Week' : 'Minggu'} $bucket';
        }

        return '• $label — ${_n(row['transactions'])} '
            '${_en ? 'transactions' : 'transaksi'}';
      }).join('\n');

      final type = busyHour
          ? (_en ? 'busiest hours' : 'jam tersibuk')
          : busyWeekday
              ? (_en ? 'busiest weekdays' : 'hari tersibuk')
              : busyWeek
                  ? (_en ? 'busiest weeks' : 'minggu tersibuk')
                  : (_en ? 'busiest months' : 'bulan tersibuk');

      return _en
          ? 'Here are the $type by transaction count for $reportLabel:\n$lines'
          : 'Berikut $type berdasarkan jumlah transaksi untuk $reportLabel:\n$lines';
    }

    // RANKING PRODUK: gunakan unit bersih setelah retur.
    final asksLeastProduct = _hasAny(q, [
      'produk paling tidak laku', 'produk paling gak laku',
      'produk paling nggak laku', 'produk paling enggak laku',
      'item paling tidak laku', 'item paling gak laku',
      'item paling nggak laku', 'item paling enggak laku',
      'barang paling tidak laku', 'barang paling gak laku',
      'barang paling nggak laku', 'paling tidak laku',
      'paling gak laku', 'paling nggak laku', 'paling enggak laku',
      'produk kurang laku', 'barang kurang laku', 'item kurang laku',
      'produk tidak laku', 'barang tidak laku', 'item tidak laku',
      'produk gak laku', 'barang gak laku', 'item gak laku',
      'produk nggak laku', 'barang nggak laku', 'item nggak laku',
      'produk belum laku', 'barang belum laku', 'item belum laku',
      'least selling', 'least sold', 'worst selling', 'slow moving',
      'unsold products', 'unsold items',
    ]);

    final asksBestProduct = !asksLeastProduct && _hasAny(q, [
      'produk paling laku', 'item paling laku', 'barang paling laku',
      'produk paling laris', 'item paling laris', 'barang paling laris',
      'produk terlaris', 'item terlaris', 'barang terlaris',
      'produk terjual terbanyak', 'item terjual terbanyak',
      'barang terjual terbanyak', 'paling banyak terjual',
      'best selling', 'best seller', 'top selling', 'most sold',
    ]);

    if (asksLeastProduct || asksBestProduct) {
      final db = await DB.database;
      final List<Map<String, dynamic>> rows;

      if (asksBestProduct) {
        rows = await db.rawQuery('''
          SELECT si.name AS product_name,
            SUM(CASE WHEN si.qty > si.returned_qty
              THEN si.qty - si.returned_qty ELSE 0 END) AS units_sold
          FROM sale_items si
          INNER JOIN sales s ON s.id = si.sale_id
          WHERE s.sale_time >= ? AND s.sale_time < ?
          GROUP BY si.name
          HAVING SUM(CASE WHEN si.qty > si.returned_qty
            THEN si.qty - si.returned_qty ELSE 0 END) > 0
          ORDER BY units_sold DESC, si.name COLLATE NOCASE ASC
          LIMIT 8
        ''', [_stamp(reportRange[0]), _stamp(reportRange[1])]);
      } else {
        rows = await db.rawQuery('''
          SELECT p.name AS product_name,
            COALESCE((
              SELECT SUM(CASE WHEN si.qty > si.returned_qty
                THEN si.qty - si.returned_qty ELSE 0 END)
              FROM sale_items si
              INNER JOIN sales s ON s.id = si.sale_id
              WHERE (
                si.product_id = p.id OR (
                  si.product_id IS NULL AND
                  LOWER(TRIM(si.name)) = LOWER(TRIM(p.name))
                )
              )
              AND s.sale_time >= ? AND s.sale_time < ?
            ), 0) AS units_sold
          FROM products p
          WHERE p.active = 1
          ORDER BY units_sold ASC, p.name COLLATE NOCASE ASC
          LIMIT 8
        ''', [_stamp(reportRange[0]), _stamp(reportRange[1])]);
      }

      if (rows.isEmpty) {
        return _en
            ? 'No matching product records were found for $reportLabel.'
            : 'Tidak ditemukan catatan produk yang sesuai untuk $reportLabel.';
      }

      final lines = rows.map((row) =>
        '• ${(row['product_name'] ?? '-').toString()} — '
        '${_n(row['units_sold'])} ${_en ? 'net units sold' : 'unit bersih terjual'}'
      ).join('\n');

      return asksBestProduct
          ? (_en
              ? 'Best-selling products for $reportLabel, ranked by net units sold after recorded returns:\n$lines'
              : 'Produk/item paling laku untuk $reportLabel, diurutkan berdasarkan jumlah unit terjual bersih setelah retur:\n$lines')
          : (_en
              ? 'Products with the lowest net sales quantities for $reportLabel:\n$lines'
              : 'Produk/item dengan penjualan unit bersih terendah untuk $reportLabel:\n$lines');
    }

    // DAFTAR PRODUK: tidak memerlukan kata "stok" atau "harga".
    final asksProductList = _hasAny(q, [
      'daftar produk', 'daftar item', 'daftar barang',
      'daftar semua produk', 'daftar semua item',
      'semua produk', 'semua item', 'semua barang',
      'list products', 'list items', 'product list', 'item list',
      'daftar menu', 'semua menu', 'produk apa saja',
      'produk apa aja', 'item apa saja', 'item apa aja',
      'barang apa saja', 'barang apa aja',
    ]);

    if (asksProductList) {
      final db = await DB.database;
      final products = await db.query(
        'products',
        where: 'active = ?',
        whereArgs: [1],
        orderBy: 'name COLLATE NOCASE',
      );

      if (products.isEmpty) {
        return _en
            ? 'There are no active products in the saved product list.'
            : 'Belum ada produk aktif dalam daftar produk tersimpan.';
      }

      final lines = products.take(20).map((p) =>
        '• ${(p['name'] ?? '-').toString()} — '
        '${_en ? 'stock' : 'stok'}: ${_n(p['stock'])}; '
        '${_en ? 'price' : 'harga'}: ${rp(_n(p['price']))}'
      ).join('\n');

      final suffix = products.length > 20
          ? (_en
              ? '\nShowing 20 of ${products.length} active products.'
              : '\nDitampilkan 20 dari ${products.length} produk aktif.')
          : '';

      return _en
          ? 'Active products saved in Colonel POS:\n$lines$suffix'
          : 'Ini daftar produk aktif yang tersimpan di Colonel POS:\n$lines$suffix';
    }

    // PELANGGAN TERATAS: default seluruh riwayat; periode eksplisit tetap dihormati.
    if (asksTopCustomersExpanded) {
      if (!_admin) {
        return _en
            ? 'Top-customer rankings require Administrator permission.'
            : 'Peringkat pelanggan teratas memerlukan izin Administrator.';
      }

      final sales = await _salesForPeriod(
        reportRange[0], reportRange[1],
      );
      final grouped = <String, Map<String, int>>{};

      for (final sale in sales) {
        final name = (sale['customer_name'] ?? '').toString().trim();
        if (name.isEmpty || name.toLowerCase() == 'pelanggan umum') {
          continue;
        }

        final metric = grouped.putIfAbsent(
          name, () => {'sales': 0, 'transactions': 0},
        );
        metric['sales'] = metric['sales']! + _n(sale['net_total']);
        metric['transactions'] = metric['transactions']! + 1;
      }

      final rankByFrequency = _hasAny(q, [
        'loyal', 'loyalitas', 'sering beli', 'repeat',
        'paling sering', 'frekuensi', 'sering transaksi',
      ]);

      final ranked = grouped.entries.toList()
        ..sort((a, b) => (rankByFrequency
                ? b.value['transactions']!
                : b.value['sales']!)
            .compareTo(rankByFrequency
                ? a.value['transactions']!
                : a.value['sales']!));

      if (ranked.isEmpty) {
        return _en
            ? 'No named-customer sales were recorded for $reportLabel.'
            : 'Belum ada penjualan dengan nama pelanggan tercatat untuk $reportLabel.';
      }

      final lines = ranked.take(5).map((entry) => rankByFrequency
          ? '• ${entry.key} — ${entry.value['transactions']} '
            '${_en ? 'transactions' : 'transaksi'}; '
            '${rp(entry.value['sales'] ?? 0)}'
          : '• ${entry.key} — ${rp(entry.value['sales'] ?? 0)}; '
            '${entry.value['transactions']} '
            '${_en ? 'transactions' : 'transaksi'}'
      ).join('\n');

      return rankByFrequency
          ? (_en
              ? 'Most frequent named customers for $reportLabel (frequency is an indicator, not proof of loyalty):\n$lines'
              : 'Pelanggan yang paling sering bertransaksi untuk $reportLabel (frekuensi bukan bukti pasti loyalitas):\n$lines')
          : (_en
              ? 'Top customers for $reportLabel, ranked by net sales after recorded returns:\n$lines'
              : 'Pelanggan teratas untuk $reportLabel, diurutkan berdasarkan penjualan bersih setelah retur tercatat:\n$lines');
    }

    if (asksCustomer && !asksCustomerRanking) return _answerCustomerQuestion(q);



    final asksMenuDelete = _hasAny(q, [
      'hapus menu', 'menghapus menu', 'delete menu', 'remove menu',
      'hapus produk', 'menghapus produk', 'delete product', 'remove product',
    ]);
    final asksMenuActive = _hasAny(q, [
      'nonaktifkan menu', 'menonaktifkan menu', 'aktifkan menu',
      'mengaktifkan menu', 'menu nonaktif', 'menu aktif', 'status menu',
      'deactivate menu', 'activate menu', 'inactive menu', 'active menu',
    ]);
    final asksMenuEdit = _hasAny(q, [
      'edit menu', 'ubah menu', 'mengubah menu', 'update menu',
      'edit product', 'ubah produk', 'mengubah produk', 'perbarui menu',
    ]);
    final asksMenuAdd = _hasAny(q, [
      'tambah menu', 'menambah menu', 'buat menu', 'membuat menu',
      'add menu', 'new menu', 'tambah produk', 'menambah produk',
      'add product',
    ]);
    final asksMenuManagement = asksMenuDelete ||
        asksMenuActive ||
        asksMenuEdit ||
        asksMenuAdd ||
        _hasAny(q, [
          'kelola menu', 'pengaturan menu', 'menu dan harga',
          'menu management', 'manage menu',
        ]);
    if (asksMenuManagement) {
      if (!_admin) {
        return _en
            ? 'Menu management is available to Admin. Please ask your Admin to open Settings → Menu & Prices.'
            : 'Pengelolaan menu dilakukan oleh Admin. Minta Admin membuka Pengaturan → Menu & Harga.';
      }
      if (asksMenuDelete) {
        return _en
            ? 'The Menu & Prices page provides add, edit, and Active/Inactive controls. I could not find a permanent menu deletion action in the current interface. To hide a product, open Settings → Menu & Prices and turn off Active.'
            : 'Halaman Menu & Harga menyediakan fitur tambah, edit, dan sakelar Aktif/Nonaktif. Saya belum menemukan fitur hapus menu permanen pada antarmuka saat ini. Untuk menyembunyikan produk, buka Pengaturan → Menu & Harga lalu matikan sakelar Aktif.';
      }
      if (asksMenuActive) {
        return _en
            ? 'Open Settings → Menu & Prices, then use the Active switch on the product. Turn it on to activate the product or off to deactivate it.'
            : 'Buka Pengaturan → Menu & Harga, lalu gunakan sakelar Aktif pada produk. Aktifkan sakelar untuk mengaktifkan produk atau matikan untuk menonaktifkannya.';
      }
      if (asksMenuEdit) {
        return _en
            ? 'Open Settings → Menu & Prices, select the product using its Edit icon, change the needed fields, then tap Save.'
            : 'Buka Pengaturan → Menu & Harga, pilih produk melalui ikon Edit, ubah bagian yang diperlukan, lalu tekan Simpan.';
      }
      if (asksMenuAdd) {
        return _en
            ? 'Open Settings → Menu & Prices, tap Add menu (+), fill in the product details, then tap Save.'
            : 'Buka Pengaturan → Menu & Harga, tekan Tambah menu (+), isi detail produk, lalu tekan Simpan.';
      }
      return _en
          ? 'To manage products, open Settings → Menu & Prices. You can add products, edit their details, or use the Active switch to activate or deactivate them.'
          : 'Untuk mengelola produk, buka Pengaturan → Menu & Harga. Anda dapat menambah produk, mengedit detailnya, atau menggunakan sakelar Aktif untuk mengaktifkan maupun menonaktifkan produk.';
    }

    final asksStockReduction = _hasAny(q, [
      'kurangi stok', 'mengurangi stok', 'pengurangan stok',
      'kurangin stok', 'ngurangin stok', 'hapus stok',
      'menghapus stok', 'hilangkan stok', 'menghilangkan stok',
      'kosongkan stok', 'nolkan stok', 'kurangi stock',
      'mengurangi stock', 'hapus stock', 'remove stock',
      'reduce stock', 'decrease stock', 'delete stock',
      'cara mengurangi stok', 'cara kurangi stok',
      'cara kurangin stok', 'cara mengurangi persediaan',
      'kurangi jumlah barang', 'mengurangi jumlah barang',
      'stock reduction', 'stock out', 'stok keluar',
      'stock to zero', 'set stock to zero', 'zero out stock',
      'stok jadi nol', 'stok ke nol', 'stok sampai nol',
      'stock jadi nol', 'stock ke nol', 'stok kosong',
      'ubah stok', 'merubah stok', 'mengubah stok',
      'cara ubah stok', 'cara merubah stok',
      'cara mengubah stok', 'edit stok', 'cara edit stok',
      'rubah stok', 'cara rubah stok', 'perubahan stok',
    ]);
    if (_hasAny(q, [
      'stok', 'stock', 'persediaan', 'harga produk', 'product price',
    ]) || asksStockReduction) {
      if (asksStockReduction) {
        if (!_admin) {
          return _en
              ? 'Stock adjustment is available to Admin. Please ask your Admin to open Settings → Stock, select the product, and choose Stock Out.'
              : 'Pengurangan stok dilakukan oleh Admin. Minta Admin membuka Pengaturan → Stok, memilih produk, lalu menekan Kurangi Stok.';
        }

        return _en
            ? 'To reduce stock: open Settings → Stock, find the product, tap the Stock Out icon, enter a quantity, then confirm. The quantity must be greater than zero and cannot exceed the available stock. Stock can reach zero; the product remains in the menu.'
            : 'Cara mengurangi stok: buka Pengaturan → Stok, cari produk, tekan ikon Kurangi Stok, masukkan jumlah, lalu konfirmasi. Jumlah harus lebih dari nol dan tidak boleh melebihi stok tersedia. Stok boleh menjadi nol; produknya tetap ada di daftar menu.';
      }

      return _answerProductQuestion(q);
    }

    final reportCue = _hasAny(q, [
      'berapa', 'jumlah', 'total', 'nominal', 'nilai', 'laporan',
      'hari ini', 'kemarin', 'minggu ini', 'minggu lalu', 'bulan ini',
      'bulan lalu', 'tahun ini', 'tahun lalu', 'amount', 'count', 'how much', 'how many',
    ]);
    final isQrisReport = q.contains('qris') && reportCue;
    final isPaymentReport = _hasAny(q, [
      'transfer', 'tunai', 'cash', 'bayar tunda', 'bayar nanti', 'qris',
    ]) && reportCue;
    final asksDefinition = _hasAny(q, [
      'apa itu', 'apa arti', 'pengertian', 'jelaskan', 'maksud', 'what is', 'explain',
    ]);
    final isSalesReport = _hasAny(q, ['omzet', 'omset', 'revenue']) ||
        (!asksDefinition && _hasAny(q, ['penjualan', 'jualan', 'sales']) &&
        (reportCue || _hasAny(q, ['penjualan', 'jualan', 'sales'])));
    final isProfit = _hasAny(q, ['laba', 'rugi', 'profit', 'loss']);
    final isExpense = _hasAny(q, ['pengeluaran', 'biaya operasional', 'expenses', 'expense total']);
    final isPayable = _hasAny(q, [
      'hutang usaha', 'utang usaha', 'hutang toko', 'utang toko',
      'hutang supplier', 'utang supplier', 'hutang ke supplier',
      'utang ke supplier', 'hutang kepada supplier',
      'utang kepada supplier', 'hutang pada supplier',
      'utang pada supplier', 'payable', 'payables',
    ]) || (_hasAny(q, ['hutang', 'utang']) &&
        !_hasAny(q, ['piutang', 'receivable']) && !_isCustomerQuestion(q));
    final isReceivable = _hasAny(q, ['bayar tunda', 'bayar nanti', 'piutang', 'receivable', 'unpaid customer']);
    final asksUnsoldProducts = _hasAny(q, [
      'produk tidak laku', 'produk gak laku', 'produk nggak laku',
      'barang tidak laku', 'barang gak laku', 'barang nggak laku',
      'produk belum laku', 'barang belum laku', 'slow moving', 'unsold products',
    ]);
    final asksBestProducts = !asksUnsoldProducts && _hasAny(q, [
      'produk terlaris', 'barang terlaris', 'produk paling laku',
      'barang paling laku', 'produk paling laris', 'barang paling laris',
      'produk terjual terbanyak', 'best selling', 'best seller',
    ]);
    final asksItemCount = !asksUnsoldProducts && !asksBestProducts &&
        _hasAny(q, ['item terjual', 'barang terjual', 'produk terjual',
          'jumlah item', 'jumlah produk terjual', 'berapa item', 'berapa produk',
          'unit terjual', 'item laku', 'jumlah barang laku']);
    final asksTopCustomers = asksCustomerRanking;
    final asksLatestTransactions = _hasAny(q, [
      'transaksi terbaru', 'transaksi terakhir', 'penjualan terbaru',
      'latest transactions', 'most recent transactions', 'recent transactions',
    ]);
    final isReturnReport = q.contains('retur') && _hasAny(q, ['berapa', 'jumlah', 'total', 'nominal', 'laporan', 'hari ini', 'kemarin', 'bulan ini', 'bulan lalu', 'tahun ini', 'amount', 'count', 'how much', 'how many']);
    final isQris = isQrisReport;
    final period = _period(q);
    final label = _periodLabel(q);

    if (asksUnsoldProducts || asksBestProducts) {
      final db = await DB.database;
      final rows = await db.rawQuery(
        'SELECT p.name AS product_name, '
        'COALESCE(SUM(CASE WHEN s.id IS NOT NULL THEN si.qty - si.returned_qty ELSE 0 END), 0) AS units_sold '
        'FROM products p LEFT JOIN sale_items si ON si.product_id = p.id '
        'LEFT JOIN sales s ON s.id = si.sale_id AND s.sale_time >= ? AND s.sale_time < ? '
        'WHERE p.active = 1 GROUP BY p.id, p.name '
        'ORDER BY units_sold ${asksUnsoldProducts ? 'ASC' : 'DESC'}, p.name COLLATE NOCASE',
        [_stamp(period[0]), _stamp(period[1])],
      );
      final selected = asksUnsoldProducts
          ? rows.where((r) => _n(r['units_sold']) <= 0).take(8).toList()
          : rows.where((r) => _n(r['units_sold']) > 0).take(8).toList();
      if (selected.isEmpty) {
        return asksUnsoldProducts
            ? (_en ? 'No active products with zero net units sold were found for $label.' : 'Tidak ada produk aktif dengan unit terjual bersih nol yang ditemukan untuk $label.')
            : (_en ? 'No product sales were found for $label.' : 'Belum ada penjualan produk yang tercatat untuk $label.');
      }
      final lines = selected.map((r) => '• ${(r['product_name'] ?? '').toString()} — ${_n(r['units_sold'])} ${_en ? 'units' : 'unit'}').join('\n');
      return asksUnsoldProducts
          ? (_en ? 'Products with no net units sold for $label:\n$lines' : 'Produk yang belum laku (unit terjual bersih 0) $label:\n$lines')
          : (_en ? 'Best-selling products for $label, ranked by net units sold:\n$lines' : 'Produk paling laku $label, berdasarkan unit bersih setelah retur:\n$lines');
    }

    if (asksItemCount) {
      final db = await DB.database;
      final rows = await db.rawQuery(
        'SELECT COALESCE(SUM(si.qty - si.returned_qty), 0) AS qty '
        'FROM sale_items si INNER JOIN sales s ON s.id = si.sale_id '
        'WHERE s.sale_time >= ? AND s.sale_time < ?',
        [_stamp(period[0]), _stamp(period[1])],
      );
      return _en
          ? 'Net units sold for $label: ${_n(rows.first['qty'])} (recorded returned quantities deducted).'
          : 'Jumlah item/produk terjual bersih $label: ${_n(rows.first['qty'])} unit (sudah dikurangi kuantitas retur yang tercatat).';
    }

    if (asksTopCustomers) {
      if (!_admin) return _en ? 'Top-customer rankings require Administrator permission.' : 'Peringkat pelanggan teratas memerlukan izin Administrator.';
      final sales = await _salesForPeriod(period[0], period[1]);
      final grouped = <String, Map<String, int>>{};
      for (final sale in sales) {
        final name = (sale['customer_name'] ?? '').toString().trim();
        if (name.isEmpty || name.toLowerCase() == 'pelanggan umum') continue;
        final metric = grouped.putIfAbsent(name, () => {'sales': 0, 'transactions': 0});
        metric['sales'] = metric['sales']! + _n(sale['net_total']);
        metric['transactions'] = metric['transactions']! + 1;
      }
      final rankByLoyalty = _hasAny(q, ['loyal', 'loyalitas', 'sering beli', 'repeat', 'paling sering']);
      final ranked = grouped.entries.toList()
        ..sort((a, b) => (rankByLoyalty ? b.value['transactions']! : b.value['sales']!)
            .compareTo(rankByLoyalty ? a.value['transactions']! : a.value['sales']!));
      if (ranked.isEmpty) return _en ? 'No named customer sales were recorded for $label.' : 'Belum ada penjualan dengan nama pelanggan tercatat untuk $label.';
      final lines = ranked.take(5).map((e) => rankByLoyalty
          ? '• ${e.key} — ${e.value['transactions']} ${_en ? 'transactions' : 'transaksi'}; ${rp(e.value['sales'] ?? 0)}'
          : '• ${e.key} — ${rp(e.value['sales'] ?? 0)}; ${e.value['transactions']} ${_en ? 'transactions' : 'transaksi'}').join('\n');
      return rankByLoyalty
          ? (_en ? 'Most frequent customers for $label (purchase frequency is only a loyalty indicator):\n$lines' : 'Pelanggan paling sering bertransaksi $label (frekuensi adalah indikator loyalitas, bukan bukti pasti):\n$lines')
          : (_en ? 'Top customers for $label, ranked by recorded net sales:\n$lines' : 'Pelanggan teratas/terroyal $label berdasarkan penjualan bersih tercatat:\n$lines');
    }

    if (asksLatestTransactions) {
      final db = await DB.database;
      final recent = await db.rawQuery(
        'SELECT s.sale_no, s.sale_time, s.customer_name, s.total, '
        '(s.total - COALESCE((SELECT SUM(si.returned_qty * si.price) FROM sale_items si WHERE si.sale_id = s.id), 0)) AS net_total '
        'FROM sales s ORDER BY s.sale_time DESC, s.id DESC LIMIT 5',
      );
      if (recent.isEmpty) return _en ? 'No saved transactions were found.' : 'Belum ada transaksi tersimpan.';
      final wantsCount = _hasAny(q, ['jumlah', 'berapa', 'total', 'count', 'how many']);
      final todaySales = wantsCount ? await _salesForPeriod(period[0], period[1]) : <Map<String, dynamic>>[];
      final lines = recent.map((r) => '• ${(r['sale_time'] ?? '').toString()} — ${(r['sale_no'] ?? '').toString()} — ${(r['customer_name'] ?? '').toString()} — ${rp(_n(r['net_total']))}').join('\n');
      return wantsCount
          ? (_en ? 'Transactions recorded for $label: ${todaySales.length}. Latest saved transactions (up to 5):\n$lines' : 'Jumlah transaksi tercatat $label: ${todaySales.length}. Transaksi tersimpan terbaru (maksimal 5):\n$lines')
          : (_en ? 'Latest saved transactions (up to 5):\n$lines' : 'Transaksi tersimpan terbaru (maksimal 5):\n$lines');
    }

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
          ? 'Waalaikumussalam warahmatullahi wabarakatuh 😊 May your day be peaceful and blessed.'
          : 'Waalaikumsalam warahmatullahi wabarakatuh$addressSuffix 😊 Semoga sehat, lancar, dan penuh berkah.';
    }
    if (hasWord(['waalaikumsalam', 'waalaikumussalam', 'waalaikum salam', 'wa alaikum salam'])) {
      return _en ? 'Thank you 😊 I’m glad I could help.' : 'Sama-sama 😊 Semoga urusannya lancar.';
    }
    if (hasWord(['alhamdulillah', 'hamdulillah'])) {
      return _en ? 'Alhamdulillah 😊 May things continue to go well and be blessed.' : 'Alhamdulillah 😊 Semoga nikmat dan urusannya terus diberi kelancaran serta keberkahan.';
    }
    if (hasWord(['bismillah', 'bis millah', 'bismilah'])) {
      return _en ? 'Bismillah 😊 May everything go smoothly.' : 'Bismillah 😊 Semoga dimudahkan dan dilancarkan.';
    }
    if (hasWord(['insyaallah', 'inshaallah', 'insya allah', 'insha allah'])) {
      return _en ? 'InshaAllah 😊 I hope it works out well. Let me know if you want help preparing for it.' : 'Insyaallah 😊 Semoga benar-benar dimudahkan. Kalau ada yang perlu disiapkan atau direncanakan, aku bantu, ya.';
    }
    if (hasWord(['aamiin', 'amin', 'ameen', 'aamiiin'])) {
      return _en ? 'Ameen, may it be so 😊' : 'Aamiin ya Rabbal ‘alamin 🤲😊 Semoga doa baiknya dikabulkan.';
    }
    if (hasWord(['masyaallah', 'masya allah', 'mashaallah', 'masha allah'])) {
      return _en ? 'MashaAllah 😊 That is lovely to hear. What happened?' : 'Masyaallah 😊 Semoga menjadi kebaikan dan keberkahan.';
    }
    if (hasWord(['subhanallah', 'subhan allah'])) {
      return _en ? 'SubhanAllah 😊 Truly, all glory belongs to Allah.' : 'Subhanallah 😊 Mahasuci Allah.';
    }
    if (hasWord(['astaghfirullah', 'astagfirullah', 'astagfirullahaladzim'])) {
      return _en ? 'Astaghfirullah. I hope things become easier and more peaceful.' : 'Astaghfirullah. Semoga diberi ketenangan dan jalan keluar yang baik.';
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
          ? 'Yes, $address 😊 I’m here to help.'
          : 'Iya, $address 😊 Ada yang bisa aku bantu?';
    }

    // Exact short greetings; avoid matching words that merely contain hai.
    final greeting = RegExp(r'^(hai|halo|hello|hi)(?:\s+(bro|sis|mas|mbak|mba|pak|bapak|bu|ibu|kang|lur|min|kak))?$')
        .firstMatch(normalized);
    if (greeting != null) {
      final salutation = greeting.group(1)!;
      final address = greeting.group(2);
      final shown = salutation[0].toUpperCase() + salutation.substring(1);
      return address == null
          ? (_en ? 'Hi! 😊 I’m ready to help.' : '$shown! 😊 Aku siap membantu.')
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
      return _en ? 'I can help check sales, transactions, QRIS, stock, products, returns, and available reports. I can also brainstorm promotions, think through competition, and suggest practical steps for quiet business hours. Some financial details require Administrator access.'
          : 'Banyak, Min! Aku bisa bantu cek omzet, transaksi, QRIS, stok, produk, retur, dan laporan yang tersedia. Aku juga bisa bantu cari ide promosi, memikirkan strategi menghadapi pesaing, serta menyusun langkah praktis saat toko sepi. Data tertentu tetap mengikuti izin Administrator, ya. 😊';
    }
    if (_hasAny(q, ['kok pinter', 'kok pintar', 'pinter banget', 'pintar banget', 'kamu hebat', 'hebat banget', 'mantap min', 'makasih', 'terima kasih', 'thanks', 'thank you', 'love you', 'kamu baik', 'good job', 'you are smart', 'so smart', 'you are clever'])) {
      return _en ? 'Hehe, thank you! 😊 I’m glad I could help.'
          : 'Hehehe, makasih, Min! 😄 Senang kalau aku bisa membantu.';
    }
    if (_hasAny(q, ['bosen jaga toko', 'bosan jaga toko', 'kamu bosan', 'are you bored'])) {
      return _en ? 'I do not get bored like a person. When the shop is quiet, I can help review sales or think of practical ways to attract customers.'
          : 'Wkwk, aku nggak bisa bosan seperti manusia, Min. 😄 Kalau toko lagi sepi, kita bisa cek penjualan atau mencari ide promosi yang terukur.';
    }
    if (_hasAny(q, ['punya perasaan', 'kamu punya perasaan', 'do you have feelings', 'are you human'])) {
      return _en ? 'I do not have feelings like a human, but I can respond respectfully and help with questions about your shop.'
          : 'Aku nggak punya perasaan seperti manusia, Min, tetapi aku bisa menanggapi dengan baik dan membantu pertanyaan tentang toko. 😊';
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
          : 'Aduh, kedengarannya berat ya, Min. Jualan memang banyak yang dipikirkan: pelanggan, stok, modal, dan biaya. Kalau memungkinkan, istirahat sebentar dan selesaikan satu hal dulu.';
    }
    if (_hasAny(q, ['punya perasaan', 'kamu punya perasaan', 'do you have feelings', 'are you human'])) {
      return _en ? 'I do not have feelings like a human, but I can listen to what you share and try to respond kindly.'
          : 'Aku nggak punya perasaan seperti manusia, Min, tetapi aku bisa menanggapi dengan baik dan membantu pertanyaan tentang toko. 😊';
    }
    // Opening greetings and polite replies should be handled before general fallback.
    if (_hasAny(q, ['assalamualaikum', 'assalamu alaikum', 'assalamu’alaikum', "assalamu'alaikum", 'salamualaikum'])) {
      return _en
          ? 'Waalaikumussalam! 😊 Welcome, how can I help you today? I can help review shop records or develop practical business ideas.'
          : 'Waalaikumsalam warahmatullahi wabarakatuh, Min. 😊 Semoga hari ini lancar dan penuh berkah. Aku siap membantu mengecek data toko. Kalau sedang ingin mengembangkan usaha, aku juga punya kiat praktis untuk membuat toko lebih ramai atau meningkatkan omzet.';
    }
    if (_hasAny(q, ['waalaikumsalam', 'wa alaikum salam', 'waalaikum salam', 'waalaikumussalam'])) {
      return _en ? 'Thank you! 😊 What can I help you with today?' : 'Sama-sama, Min. 😊 Semoga urusannya lancar. Ada yang bisa aku bantu?';
    }
    if (_hasAny(q, ['selamat pagi', 'pagi min', 'pagi, min', 'good morning', 'morning'])) {
      return _en ? 'Good morning! ☀️ Hope your day goes smoothly. I can help check shop numbers or plan a promotion.' : 'Selamat pagi, Min! ☀️ Semoga dagangannya lancar, pembelinya ramai, dan rezekinya berkah. Kita bisa cek data toko atau menyusun ide promosi yang praktis.';
    }
    if (_hasAny(q, ['selamat siang', 'siang min', 'siang, min', 'good afternoon'])) {
      return _en ? 'Good afternoon! 😊 Hope everything is going well. What can I help you with?' : 'Selamat siang, Min! 😊 Semoga jualannya lancar, ya. Kita bisa mengecek data toko atau mencari ide promosi yang praktis.';
    }
    if (_hasAny(q, ['selamat sore', 'sore min', 'sore, min', 'good evening'])) {
      return _en ? 'Good evening! 😊 How is the shop going? I can help check the numbers or brainstorm ways to bring customers in.' : 'Selamat sore, Min! 😊 Gimana kabar toko hari ini? Kita bisa cek penjualan sementara atau mencari cara agar toko lebih ramai.';
    }
    if (_hasAny(q, ['selamat malam', 'malam min', 'malam, min', 'good night'])) {
      return _en ? 'Good evening! 🌙 Hope your day went well. We can review today’s sales or consider ways to improve the shop.' : 'Selamat malam, Min! 🌙 Semoga hari ini tetap membawa rezeki. Kita bisa mengecek penjualan hari ini atau merencanakan langkah usaha berikutnya. Kalau sudah lelah, jangan lupa istirahat juga, ya.';
    }
    if (_hasAny(q, ['apa kabar', 'gimana kabar', 'kabarmu', 'how are you'])) {
      return _en ? 'I’m here and ready to help! 😊 How are you and how is the shop today?' : 'Aku siap menemani dan membantu, Min! 😊 Kalau Min sendiri gimana kabarnya? Toko hari ini ramai atau lagi agak sepi?';
    }
    if (_hasAny(q, ['halo', 'hai', 'hello', 'hi', 'permisi min', 'tes min', 'test min'])) {
      return _en ? 'Hi! 👋 Ask me about sales, QRIS, products, stock, customers, returns, and reports. I can also help with practical business ideas and promotions.' : 'Halo, Min! 👋 Aku siap bantu. Bisa tanya soal omzet, QRIS, stok, produk, pelanggan, retur, dan laporan. Aku juga bisa bantu menyusun ide promosi dan strategi usaha yang praktis.';
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
      'transaksi terbaru', 'transaksi terakhir', 'penjualan terbaru',
      'latest transactions', 'most recent transactions', 'recent transactions',
    ])) return null;
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
        return q;
      case 'jumlah_pelanggan':
        return 'jumlah pelanggan $period';
      default:
        return q;
    }
  }


  String _unknownReply() {
    final id = <String>[
      "Aku belum memahami maksudnya. Bisa jelaskan bagian yang ingin ditanyakan supaya aku tidak salah menjawab?",
      "Wah, aku belum nyambung nih 😄 Maksudmu bagian yang mana?",
      "Bisa perjelas bagian yang dimaksud? Aku ingin menjawab dengan tepat.",
      "Hehe, sepertinya aku belum menangkap maksudmu 😅 Coba dengan cara lain, yuk.",
      "Aku simak, kok 😊 Tambahin sedikit konteks, ya.",
      "Hmm, aku masih agak bingung. Bisa kasih contoh?",
      "Mungkin aku salah memahami maksudnya. Tolong tulis ulang bagian yang ingin ditanyakan.",
      "Aku belum menangkap maksud kalimat itu. Coba tulis pertanyaannya dengan lebih spesifik.",
      "Aku mau bantu, nih. Kasih sedikit petunjuk, dong.",
      "Aku perlu sedikit konteks tambahan agar jawabannya tepat.",
      "Belum ketemu maksudnya, nih 😅 Coba jelasin sedikit lagi.",
      "Daripada asal jawab, boleh aku minta sedikit penjelasan?",
      "Hmm, bisa diperjelas? Aku nggak mau menebak-nebak.",
      "Kasih aku gambaran sedikit lagi, ya. Kita cari tahu bareng.",
      "Aku belum paham betul, tapi kita bisa coba lagi 😊",
      "Konteksnya belum cukup jelas untuk kujawab dengan yakin.",
      "Aku bisa membantu setelah maksud pertanyaannya lebih jelas.",
      "Aku belum bisa menjawab dengan yakin. Apa yang ingin kamu capai?",
      "Kalau aku salah menangkap, koreksi aja, ya 😄",
      "Aku nggak mau sok tahu lalu malah menyesatkanmu.",
      "Tolong sebutkan informasi atau tindakan yang kamu maksud.",
      "Aku belum memahami kalimat itu. Bisa dibuat lebih sederhana?",
      "Nggak apa-apa, kita coba cara lain. Bagian mana yang ingin dibahas?",
      "Tambahkan detail yang relevan agar aku bisa menjawab dengan tepat.",
      "Sepertinya aku butuh petunjuk tambahan 😄",
      "Kalau tentang toko, sebutkan fitur atau data yang ingin diperiksa.",
      "Aku belum yakin dengan maksud pertanyaanmu. Coba susun ulang, ya.",
      "Biar nggak salah paham, apa maksudmu dengan pertanyaan tadi?",
      "Kita bisa pecah pertanyaannya jadi lebih sederhana.",
      "Aku belum memahami maksudnya. Tolong perjelas pertanyaan yang ingin dijawab."
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

  // Definitions follow the current Dashboard/Finance/Reports implementation.

  String? _growthTipsAnswer(String rawQuestion) {
    final q = rawQuestion.toLowerCase().trim();

    bool hasAny(List<String> words) =>
        words.any((word) => q.contains(word));

    final asksForTips = hasAny([
      'tips usaha', 'kiat usaha', 'trik usaha', 'strategi usaha',
      'spill tips', 'spill kiat', 'spill jurus', 'jurus', 'kiat', 'tips',
      'sepi', 'ramai', 'rame', 'laris', 'laku', 'duh sepi', 'yah sepi',
      'kok sepi', 'supaya ramai', 'supaya laris', 'supaya rame',
      'biar laris', 'biar laku', 'agar laris', 'agar ramai',
      'jualan rame', 'jualan ramai', 'jualan laku', 'toko rame',
      'cara meningkatkan omzet', 'cara menaikkan omzet',
      'cara meningkatkan omset', 'cara menaikkan omset',
      'tips meningkatkan penjualan', 'tips agar toko ramai',
      'cara agar toko ramai', 'cara biar ramai', 'biar toko ramai',
      'toko sepi', 'jualan sepi', 'penjualan turun',
      'menarik lebih banyak pelanggan', 'menambah pelanggan',
      'meningkatkan penjualan', 'menaikkan penjualan',
      'meningkatkan omzet', 'menaikkan omzet',
      'meningkatkan omset', 'menaikkan omset',
      'promosi apa', 'ide promosi', 'strategi promosi',
      'paket bundling', 'repeat order', 'pelanggan kembali',
      'business tips', 'increase sales', 'boost revenue',
      'get more customers', 'more customers', 'slow sales',
      'marketing ideas', 'business is not growing',
      'not getting rich',
    'lanjut', 'lanjutin', 'terus', 'trus', 'apalagi',
    'tips lain', 'kiat lain', 'tips berikutnya', 'lanjutkan',
    'another tip', 'more tips', 'next tip', 'go on',
    ]);

    if (!asksForTips) return null;
    if (hasAny([
      'lebih detail', 'lebih jauh', 'secara mendalam',
      'strategi khusus', 'strategi tingkat lanjut',
      'jamin berhasil', 'pasti berhasil', 'guaranteed results',
      'in depth', 'advanced strategy', 'specific competitor analysis',
      'latest market forecast',
    ])) {
      return _en
          ? 'For deeper or highly specialized research, you can continue '
              'with ChatGPT or Gemini, or search the web. Include your '
              'business type, general location, target customers, budget, '
              'and relevant sales figures. Verify important claims and test '
              'ideas on a small scale before investing. No strategy can '
              'guarantee results without evidence from your own business.'
          : 'Untuk riset yang lebih mendalam atau sangat khusus, kamu bisa '
              'melanjutkannya di ChatGPT atau Gemini, atau mencari referensi '
              'melalui web. Sertakan jenis usaha, lokasi umum, target '
              'pelanggan, anggaran, dan angka penjualan yang relevan. '
              'Periksa klaim penting dan uji ide dalam skala kecil sebelum '
              'berinvestasi. Tidak ada strategi yang bisa menjamin hasil '
              'tanpa bukti dari usaha kamu sendiri.';
    }

    // COLONEL_V72_ABDURRAHMAN_MARKET_TIP_V1
    if (hasAny([
      'lanjut', 'lanjutin', 'terus', 'trus', 'apalagi',
      'tips lain', 'kiat lain', 'tips berikutnya', 'lanjutkan',
      'another tip', 'more tips', 'next tip', 'go on',
    ])) {
      return _en
          ? 'A useful lesson comes from Abdur-Rahman ibn Awf, a Companion of the Prophet. After arriving in Madinah, he asked to be shown the marketplace and began trading. The lesson is not that success is guaranteed, but to learn what people need, understand prices and competition, trade honestly, and build trust patiently. Try one practical step today: check your best-selling items and stock in Colonel POS, then make sure the products customers need are available. Grow steadily rather than chasing quick riches. This account is reported in Sahih al-Bukhari; numbering can vary by edition.'
          : 'Ada pelajaran usaha dari Abdurrahman bin Auf r.a., sahabat Nabi. Setelah tiba di Madinah, beliau meminta ditunjukkan pasar lalu mulai berdagang. Pelajarannya bukan bahwa sukses pasti datang, melainkan pentingnya mengenali kebutuhan pembeli, memahami harga dan persaingan, berdagang dengan jujur, serta membangun kepercayaan dengan sabar. Coba satu langkah hari ini: periksa produk terlaris dan stok di Colonel POS, lalu pastikan barang yang dicari pelanggan tersedia. Bangun usaha secara bertahap, bukan mengejar kaya secara instan. Kisah ini diriwayatkan dalam Sahih al-Bukhari; nomor hadis dapat berbeda menurut edisi.';
    }

    if (hasAny([
      'promosi', 'promo', 'diskon', 'iklan', 'instagram',
      'tiktok', 'konten', 'status wa', 'whatsapp', 'marketing',
    ])) {
      return _en
          ? 'Try a measurable promotion: choose one goal, such as attracting '
              'new customers or moving specific stock. Pick relevant products, '
              'show clear prices and promotion dates, and use channels your '
              'customers already follow. Set a budget limit. Afterwards, '
              'compare transactions, sales after returns, and promotion costs '
              'against a comparable period. Higher revenue alone does not '
              'prove higher profit because discounts can reduce margins.'
          : 'Coba promosi yang hasilnya bisa diukur: tentukan satu tujuan, '
              'misalnya menarik pelanggan baru atau menghabiskan stok '
              'tertentu. Pilih produk yang relevan, tampilkan harga dan '
              'masa promo dengan jelas, lalu gunakan kanal yang biasa '
              'dilihat pelanggan. Batasi anggaran. Setelahnya, bandingkan '
              'transaksi, penjualan setelah retur, dan biaya promosi dengan '
              'periode yang sebanding. Omzet yang naik belum tentu berarti '
              'laba naik karena diskon bisa mengurangi margin.';
    }

    if (hasAny([
      'bundling', 'paket hemat', 'paket produk', 'upsell',
      'cross sell', 'produk pelengkap', 'tambah item',
    ])) {
      return _en
          ? 'Test a small bundle of two or three products customers commonly '
              'buy together, or offer a relevant complementary item. Make '
              'sure the price covers product cost and related expenses. '
              'Track bundle sales, average transaction value, and margin '
              'against regular sales. Avoid pressuring customers to buy '
              'things they do not need.'
          : 'Uji paket kecil berisi dua atau tiga produk yang sering dibeli '
              'bersama, atau tawarkan produk pelengkap yang memang relevan. '
              'Pastikan harganya menutup modal barang dan biaya terkait. '
              'Catat jumlah paket terjual, nilai rata-rata transaksi, dan '
              'margin dibandingkan penjualan biasa. Jangan memaksa pelanggan '
              'membeli barang yang tidak mereka butuhkan.';
    }

    if (hasAny([
      'pelanggan kembali', 'repeat order', 'pelanggan loyal',
      'langganan', 'retensi pelanggan', 'pelanggan lama',
    ])) {
      return _en
          ? 'Encourage repeat visits with reliable stock, consistent service, '
              'clear prices, and a simple loyalty offer with understandable '
              'rules. If sending promotional messages, respect customer '
              'consent and privacy. Measure repeat purchases and program cost, '
              'not just the number of messages sent.'
          : 'Dorong pelanggan kembali dengan menjaga stok yang mereka cari, '
              'memberikan pelayanan konsisten, memasang harga yang jelas, '
              'dan menawarkan program loyalitas sederhana dengan aturan '
              'yang mudah dipahami. Jika mengirim pesan promosi, hormati '
              'persetujuan dan privasi pelanggan. Ukur pembelian ulang '
              'serta biaya program, bukan sekadar jumlah pesan terkirim.';
    }

    if (hasAny([
      'toko sepi', 'jualan sepi', 'sepi', 'lebih ramai', 'biar ramai',
      'biar rame', 'toko ramai', 'toko rame', 'supaya ramai', 'supaya laris',
      'biar laris', 'biar laku', 'jualan laris', 'jualan rame', 'jualan ramai',
      'banyak pembeli', 'menarik pembeli',
      'menambah pelanggan', 'pengunjung', 'kurang laku',
      'penjualan turun', 'get more customers', 'slow sales',
    ])) {
      return _en
          ? 'If business is slow, start with low-cost steps: improve the '
              'display of key products, make prices easy to see, check stock '
              'for items customers often seek, and feature one clear offer. '
              'Review transaction times to identify busy periods. Test one '
              'change for a defined period and compare transactions and '
              'margin with a similar period. Avoid large spending until '
              'the results justify it.'
          : 'Jika toko sedang sepi, mulai dari langkah berbiaya rendah: '
              'rapikan tampilan produk utama, pastikan harga mudah terlihat, '
              'periksa stok barang yang sering dicari, dan tampilkan satu '
              'penawaran yang jelas. Periksa jam transaksi untuk menemukan '
              'waktu ramai. Uji satu perubahan selama periode tertentu, lalu '
              'bandingkan transaksi dan margin dengan periode yang sebanding. '
              'Hindari pengeluaran besar sebelum hasilnya mendukung.';
    }

    return _en
        ? 'To improve sales, look at three factors: number of transactions, '
            'conversion to purchases, and average transaction value. Choose '
            'one area to improve, test a small change, and track the results. '
            'Also account for returns, discounts, product costs, and operating '
            'expenses; higher revenue does not automatically mean higher profit. '
            'For specialized market research, you can consult ChatGPT, Gemini, '
            'or web search and verify suggestions before acting.'
        : 'Untuk meningkatkan omzet, periksa tiga hal: jumlah transaksi, '
            'berapa banyak calon pembeli yang jadi membeli, dan nilai '
            'rata-rata transaksi. Pilih satu bagian untuk diperbaiki, uji '
            'perubahan kecil, lalu catat hasilnya. Perhitungkan juga retur, '
            'diskon, modal barang, dan biaya operasional; omzet yang naik '
            'tidak otomatis berarti laba naik. Untuk riset pasar khusus, '
            'kamu bisa menggunakan ChatGPT, Gemini, atau pencarian web, '
            'lalu verifikasi sarannya sebelum diterapkan.';
  }

  String? _explainPosConcept(String rawQuestion) {
    final q = rawQuestion.toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final asksMeaning = _hasAny(q, [
      'apa itu', 'apa arti', 'artinya', 'pengertian', 'maksud', 'jelaskan',
      'jelasin', 'fungsi kartu', 'arti kartu', 'kenapa beda', 'mengapa beda',
      'apa bedanya', 'perbedaan', 'what is', 'what does', 'explain',
      'meaning of', 'difference between',
    ]) || (_hasAny(q, ['dashboard', 'halaman keuangan', 'halaman laporan', 'kartu', 'metrik']) &&
        _hasAny(q, ['arti', 'jelaskan', 'apa itu', 'pengertian', 'maksud', 'fungsi']));
    final bareMetric = q.split(' ').length <= 4 && _hasAny(q, [
      'omzet', 'omset', 'transaksi', 'retur', 'item terjual', 'pengeluaran',
      'piutang', 'hutang', 'utang', 'laba bersih', 'hasil bersih',
      'kas aktual', 'pendapatan', 'bayar tunda', 'produk paling laku',
      'produk terlaris', 'pelanggan teratas', 'waktu paling laku',
      'grafik keuangan', 'grafik penjualan', 'ringkasan pembayaran',
      'modal', 'modal barang', 'harga pokok', 'hpp', 'laba kotor',
      'laba rugi', 'arus kas', 'cash flow', 'margin', 'saldo',
    ]) && !_hasAny(q, [
      'hari ini', 'kemarin', 'minggu ini', 'minggu lalu', 'bulan ini',
      'bulan lalu', 'tahun ini', 'tahun lalu', 'today', 'yesterday',
      'this week', 'last week', 'this month', 'last month', 'this year',
      'last year', 'berapa', 'jumlah', 'total', 'cek', 'tampilkan',
      'lihat', 'laporan', 'how much', 'how many',
    ]);
    if (!asksMeaning && !bareMetric) return null;
    String a(String id, String en) => _en ? en : id;

    if (_hasAny(q, ['kas aktual', 'actual cash', 'uang kas aktual'])) {
      return a(
        'Kas Aktual saat ini dihitung dari penjualan yang dianggap sudah menjadi kas (setelah dikurangi retur dan mengecualikan bayar tunda yang belum lunas), lalu dikurangi seluruh pengeluaran berstatus lunas. Rumus saat ini memakai data keseluruhan, bukan rentang tanggal yang dipilih, dan belum memperhitungkan saldo awal, setoran/penarikan kas, atau pergerakan kas lain yang tidak dicatat sebagai penjualan/pengeluaran. Jadi ini estimasi catatan aplikasi, bukan jaminan uang fisik di laci.',
        'Actual Cash is calculated from sales treated as collected (after returns and excluding unpaid pay-later sales), minus all expenses marked paid. The current formula uses all-time records, not the selected date range, and omits opening cash, deposits/withdrawals, and other unrecorded cash movements. It is an app-record estimate, not a guarantee of physical cash in the drawer.'
      );
    }
    if (_hasAny(q, ['laba bersih', 'hasil bersih', 'net profit', 'net result', 'laba rugi', 'rugi laba', 'profit', 'loss'])) {
      return a(
        'Di aplikasi saat ini, kartu Dashboard “Laba Bersih” = omzet bersih setelah retur − pengeluaran tercatat yang sudah dibayar. Kartu Keuangan “Hasil Bersih” memakai rumus Pendapatan − (Pengeluaran − total Hutang aktif). Angka ini belum tentu laba/rugi akuntansi sebenarnya karena HPP barang terjual dan biaya lain mungkin belum dihitung; rumus Hasil Bersih juga menambahkan kembali total hutang aktif. Anggap sebagai ringkasan sesuai rumus aplikasi, bukan laba bersih final.',
        'The Dashboard “Net Profit” card currently equals net revenue after returns minus recorded paid expenses. Finance “Net Result” uses Revenue − (Expenses − total active Payables). Neither is necessarily accounting profit/loss because COGS and other costs may be missing; the Net Result formula also adds back active payables. Treat these as app-defined summaries, not final net profit.'
      );
    }
    if (_hasAny(q, ['omzet', 'omset', 'revenue', 'penjualan bersih', 'net sales'])) {
      return a(
        'Omzet adalah nilai penjualan, bukan uang tunai yang pasti diterima dan bukan laba. Dashboard/Laporan menghitung total transaksi pada periode terpilih dikurangi nilai barang retur yang tercatat. Penjualan bayar tunda tetap dapat masuk omzet meski piutang belum lunas. Omzet belum dikurangi HPP dan seluruh biaya usaha.',
        'Revenue is sales value, not necessarily cash collected and not profit. Dashboard/Reports calculate sales in the selected period minus recorded returned-item value. Pay-later sales can count while unpaid. Revenue has not been reduced by COGS and all business expenses.'
      );
    }
    if (_hasAny(q, ['transaksi', 'transactions', 'jumlah transaksi'])) {
      return a(
        'Kartu Transaksi menghitung catatan penjualan pada rentang tanggal terpilih. Ini bukan jumlah pelanggan unik atau jumlah transaksi yang pasti lunas. Transaksi bayar tunda dan transaksi yang memiliki retur tetap dapat terhitung.',
        'The Transactions card counts saved sales records in the selected date range. It is not unique customers or necessarily fully paid transactions. Pay-later sales and sales with returns can still count.'
      );
    }
    if (_hasAny(q, ['retur', 'returns', 'pengembalian'])) {
      return a(
        'Kartu Retur menghitung transaksi yang memiliki barang retur pada periode penjualan tersebut. Jumlah transaksi retur berbeda dari nominal uang retur. Nilai retur yang tercatat mengurangi omzet bersih.',
        'The Returns card counts sales records with returned items in the selected sales period. Return transaction count differs from monetary return value. Recorded returns reduce net revenue.'
      );
    }
    if (_hasAny(q, ['item terjual', 'barang terjual', 'items sold', 'jumlah item'])) {
      return a(
        'Item Terjual adalah jumlah unit barang terjual dikurangi kuantitas retur yang tercatat. Ini menghitung unit, bukan jumlah transaksi atau nominal omzet.',
        'Items Sold is units sold minus recorded returned quantities. It counts units, not transactions or revenue value.'
      );
    }
    if (_hasAny(q, ['pengeluaran', 'expenses', 'biaya operasional'])) {
      return a(
        'Total Pengeluaran periode menghitung catatan pengeluaran bertanggal dalam periode terpilih dengan status Lunas/Sudah Dibayar. Pengeluaran berstatus Hutang/Jatuh Tempo tidak masuk total pengeluaran yang sudah dibayar; catatan itu muncul sebagai kewajiban di daftar Hutang.',
        'Period Expenses counts records dated in the selected period and marked Paid. Expenses marked Debt/Due are excluded from paid expenses and appear as liabilities in Payables.'
      );
    }
    if (_hasAny(q, ['piutang', 'receivable', 'bayar tunda', 'bayar nanti'])) {
      return a(
        'Piutang adalah saldo penjualan yang belum dibayar pelanggan. Bayar Tunda/Bayar Nanti menjadi piutang sampai ditandai lunas; retur tercatat dapat memengaruhi saldo. Kartu Dashboard mengikuti periode tanggal penjualan, sedangkan daftar Piutang Keuangan menampilkan piutang aktif.',
        'Receivables are sales balances customers have not paid. Pay Later transactions remain receivables until settled; recorded returns can affect the balance. Dashboard follows the selected sale-date period, while Finance lists active receivables.'
      );
    }
    if (_hasAny(q, ['hutang', 'utang', 'payable', 'payables', 'kewajiban'])) {
      return a(
        'Hutang adalah kewajiban usaha yang belum lunas. Di Colonel POS, daftar Hutang aktif berasal dari pengeluaran berstatus Hutang/Jatuh Tempo. Total Hutang aktif bukan omzet dan bukan uang yang sudah dibayar pada periode terpilih.',
        'Payables are unpaid business obligations. In Colonel POS, active Payables come from expenses marked Debt/Due. Active Payables are neither revenue nor cash paid during the selected period.'
      );
    }
    if (_hasAny(q, ['pendapatan', 'income'])) {
      return a(
        'Pendapatan pada halaman Keuangan menghitung penjualan dalam rentang tanggal terpilih setelah retur, dengan Bayar Tunda/Bayar Nanti dikecualikan sampai piutangnya berstatus Lunas. Karena itu nilainya bisa berbeda dari omzet Dashboard/Laporan yang dapat memasukkan penjualan tempo.',
        'Finance Revenue counts sales in the selected date range after returns, excluding Pay Later sales until the receivable is marked settled. It can differ from Dashboard/Reports revenue, which can include pay-later sales.'
      );
    }
    if (_hasAny(q, ['bayar tunda', 'pay later'])) {
      return a(
        'Bayar Tunda adalah penjualan ketika pelanggan belum membayar saat transaksi dibuat. Nilainya dapat masuk omzet, tetapi belum dianggap kas aktual selama piutangnya belum lunas. Pantau saldo tersisa di Piutang.',
        'Pay Later is a sale where the customer has not paid at transaction time. It can count toward revenue, but is not treated as collected cash while unpaid. Track the balance under Receivables.'
      );
    }
    if (_hasAny(q, ['produk paling laku', 'produk terlaris', 'best selling', 'best seller'])) {
      return a(
        'Produk Paling Laku menampilkan produk dengan unit terjual terbanyak pada periode terpilih setelah kuantitas retur dikurangi. Produk dengan unit terbanyak belum tentu memiliki omzet terbesar.',
        'Best-Selling Products ranks products by units sold in the selected period after returned quantities are deducted. The most units sold does not necessarily mean highest revenue.'
      );
    }
    if (_hasAny(q, ['pelanggan teratas', 'top customers'])) {
      return a(
        'Pelanggan Teratas merangkum pelanggan berdasarkan nilai penjualan bersih yang tercatat pada periode itu. Ini bukan otomatis peringkat pelanggan paling menguntungkan karena biaya, margin, dan piutang belum tentu diperhitungkan.',
        'Top Customers summarizes customers by recorded net sales for the period. It is not necessarily a profitability ranking because costs, margins, and receivables may not be accounted for.'
      );
    }
    if (_hasAny(q, ['waktu paling laku', 'jam ramai', 'peak hours'])) {
      return a(
        'Waktu Paling Laku menunjukkan jam dengan nilai penjualan tertinggi pada periode terpilih. Gunakan sebagai petunjuk pola ramai, bukan jaminan bahwa jam itu selalu paling ramai.',
        'Peak Hours shows the hour with the highest sales value in the selected period. Use it as a pattern indicator, not a guarantee that the same hour is always busiest.'
      );
    }
    if (_hasAny(q, ['ringkasan pembayaran', 'metode pembayaran', 'payment summary'])) {
      return a(
        'Ringkasan Pembayaran pada halaman Laporan menampilkan jumlah transaksi per metode pembayaran, bukan nominal rupiah per metode. Untuk nominal, tanyakan total QRIS, tunai, transfer, atau bayar tunda pada periode tertentu.',
        'The Reports Payment Summary shows transaction counts by payment method, not rupiah amounts per method. Ask for QRIS, cash, transfer, or pay-later totals for a specific period to get amounts.'
      );
    }
    if (_hasAny(q, ['grafik keuangan', 'grafik penjualan', 'financial chart', 'sales chart'])) {
      return a(
        'Grafik Keuangan Dashboard membandingkan omzet, pengeluaran tercatat, dan hasil bersih menurut Jam/Hari/Minggu/Bulan/Tahun. Grafik Penjualan Laporan menunjukkan tren omzet menurut Hari/Bulan/Tahun. Hasil bersih mengikuti rumus aplikasi, bukan otomatis laba akuntansi final.',
        'The Dashboard Financial Chart compares revenue, recorded expenses, and net result by Hour/Day/Week/Month/Year. The Reports Sales Chart shows revenue trends by Day/Month/Year. Net result follows the app formula, not automatically final accounting profit.'
      );
    }
    if (_hasAny(q, ['penjualan bulan ini', 'sales this month'])) {
      return a(
        'Penjualan Bulan Ini adalah omzet bulan kalender berjalan dari tanggal 1 sampai hari ini. Angka ini dapat berbeda dari kartu laporan yang mengikuti rentang tanggal pilihan.',
        'Sales This Month is revenue for the current calendar month from day 1 through today. It can differ from cards that follow the selected date range.'
      );
    }
    if (_hasAny(q, ['modal barang', 'harga pokok', 'hpp', 'cost of goods sold', 'cogs'])) {
      return a(
        'HPP (Harga Pokok Penjualan) adalah biaya perolehan barang yang benar-benar terjual. Secara sederhana, laba kotor = penjualan bersih − HPP. HPP berbeda dari total pembelian stok dan biaya operasional; laba/rugi akurat memerlukan data biaya produk yang memadai.',
        'COGS is the cost of acquiring the goods actually sold. Gross profit = net sales − COGS. COGS differs from total stock purchases and operating expenses; accurate profit/loss requires reliable product-cost data.'
      );
    }
    if (_hasAny(q, ['laba kotor', 'gross profit'])) {
      return a(
        'Laba Kotor = penjualan bersih − HPP barang terjual. Angka ini belum dikurangi biaya operasional seperti listrik, sewa, atau gaji, dan bukan saldo kas.',
        'Gross Profit = net sales − COGS of goods sold. It has not deducted operating expenses such as electricity, rent, or wages, and is not the cash balance.'
      );
    }
    if (_hasAny(q, ['margin', 'marjin'])) {
      return a(
        'Margin laba kotor biasanya dihitung (penjualan bersih − HPP) ÷ penjualan bersih × 100%. Diskon dapat menaikkan volume penjualan tetapi menurunkan margin jika terlalu besar.',
        'Gross margin is commonly calculated as (net sales − COGS) ÷ net sales × 100%. Discounts can increase volume but reduce margin if too large.'
      );
    }
    if (_hasAny(q, ['arus kas', 'cash flow'])) {
      return a(
        'Arus kas adalah pergerakan uang masuk dan keluar dalam periode tertentu. Penjualan tempo bisa menambah omzet tanpa uang diterima saat itu; pembayaran hutang bisa mengurangi kas tanpa menjadi penjualan baru.',
        'Cash flow is money moving in and out during a period. A pay-later sale can increase revenue before cash is received; paying an existing debt reduces cash without being a new sale.'
      );
    }
    if (_hasAny(q, ['modal', 'capital'])) {
      return a(
        'Modal adalah dana atau nilai yang ditanamkan pemilik dalam usaha. Modal berbeda dari omzet, saldo kas, dan laba. Untuk menilai keuntungan, HPP dan biaya operasional perlu dihitung.',
        'Capital is funding or value invested by the owner. It differs from revenue, cash balance, and profit. Assessing profit requires COGS and operating expenses.'
      );
    }
    if (_hasAny(q, ['saldo', 'balance'])) {
      return a(
        'Saldo adalah nilai yang tersisa pada akun/catatan pada waktu tertentu. Pastikan saldo apa yang dimaksud—kas, piutang, hutang, atau stok—beserta tanggal dan sumber datanya.',
        'A balance is the remaining value in an account or record at a given time. Confirm whether it means cash, receivables, payables, or stock, and check its date and source.'
      );
    }
    if (_hasAny(q, ['laporan', 'reports', 'dashboard', 'kartu'])) {
      return a(
        'Dashboard merangkum omzet, transaksi, retur, serta—untuk Admin—pengeluaran, piutang, hutang, hasil bersih, item terjual, produk paling laku, waktu paling laku, pelanggan teratas, ringkasan pembayaran, dan grafik keuangan. Laporan memuat omzet, transaksi, item terjual, retur, penjualan bulan ini, grafik penjualan, pelanggan, metode pembayaran, item, jam transaksi, dan transaksi tercatat. Sebut nama kartu tertentu agar penjelasannya lebih tepat.',
        'Dashboard summarizes revenue, transactions, returns, and—for Admin—expenses, receivables, payables, net result, items sold, best-selling products, peak hours, top customers, payment summary, and financial chart. Reports contains revenue, transactions, items sold, returns, sales this month, sales chart, customers, payment methods, items, transaction hours, and saved transactions. Name a specific card for a more precise explanation.'
      );
    }
    return null;
  }

  Future<String> _reply(String raw) async {
    final originalQ = raw.toLowerCase().trim();
    final q = _normalizeQuestionFromBank(originalQ)
        .replaceAll(RegExp(r'\bhutang\b', caseSensitive: false), 'utang')
        .replaceAll(RegExp(r'\bbrp\b', caseSensitive: false), 'berapa')
        .replaceAll(RegExp(r'\bbrapa\b', caseSensitive: false), 'berapa')
        .replaceAll(RegExp(r'\bpalinh\b'), 'paling')
        .replaceAll(RegExp(r'\bpalingg\b'), 'paling')
        .replaceAll(RegExp(r'\bterlariss\b'), 'terlaris')
        .replaceAll(RegExp(r'\blakuu\b'), 'laku')
        .replaceAll(RegExp(r'\bsibukk\b'), 'sibuk')
        .replaceAll(RegExp(r'\bpelangaan\b'), 'pelanggan')
        .replaceAll(RegExp(r'\bpelanggann\b'), 'pelanggan')
        .replaceAll(RegExp(r'\bblm\b'), 'belum');
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

    final growthTips = _growthTipsAnswer(originalQ);
    if (growthTips != null) return growthTips;

    final explanation = _explainPosConcept(originalQ);
    if (explanation != null) return explanation;
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
    return SizedBox.expand(
      child: Card(
        margin: const EdgeInsets.only(bottom: 4),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.support_agent_rounded, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  AppLocalizations.t('Colonel Smart Assistant', 'Colonel Smart Assistant'),
                  style: const TextStyle(fontFamily: 'sans-serif-condensed', fontSize: 18, fontWeight: FontWeight.w800, color: Colors.red),
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
                              child: Text(turn.question, style: const TextStyle(fontSize: 14, height: 1.4)),
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
                                              style: const TextStyle(fontSize: 14, height: 1.45),
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
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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

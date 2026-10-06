import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import '../models/models.dart';
import '../core/utils.dart';

class DB {
  static Database? _db;

  static String _dbDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    final h = date.hour.toString().padLeft(2, '0');
    final min = date.minute.toString().padLeft(2, '0');
    final s = date.second.toString().padLeft(2, '0');
    return '$y-$m-$d $h:$min:$s';
  }

  static Future<Database> get database async {
    if (_db != null) return _db!;

    final dir = await getDatabasesPath();

    _db = await openDatabase(
      path.join(dir, 'colonel_pos_v64.db'),
      version: 5,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE products(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            category TEXT NOT NULL,
            price INTEGER NOT NULL,
            stock INTEGER NOT NULL DEFAULT 0,
            active INTEGER NOT NULL DEFAULT 1
          )
        ''');

        await db.execute('''
          CREATE TABLE users(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT NOT NULL UNIQUE,
            password TEXT NOT NULL,
            role TEXT NOT NULL,
            active INTEGER NOT NULL DEFAULT 1
          )
        ''');

        await db.execute('''
          CREATE TABLE sales(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            sale_no TEXT NOT NULL UNIQUE,
            sale_time TEXT NOT NULL,
            cashier TEXT NOT NULL,
            customer_name TEXT NOT NULL DEFAULT 'Pelanggan Umum',
            customer_type TEXT NOT NULL DEFAULT 'Retail',
            subtotal INTEGER NOT NULL,
            discount INTEGER NOT NULL,
            total INTEGER NOT NULL,
            cash INTEGER NOT NULL,
            change_amount INTEGER NOT NULL,
            payment TEXT NOT NULL,
            returned INTEGER NOT NULL DEFAULT 0,
            customer_phone TEXT NOT NULL DEFAULT '',
            transfer_bank TEXT NOT NULL DEFAULT '',
            transfer_account TEXT NOT NULL DEFAULT '',
            due_date TEXT NOT NULL DEFAULT ''
          )
        ''');

        await db.execute('''
          CREATE TABLE sale_items(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            sale_id INTEGER NOT NULL,
            product_id INTEGER,
            name TEXT NOT NULL,
            qty INTEGER NOT NULL,
            price INTEGER NOT NULL,
            returned_qty INTEGER NOT NULL DEFAULT 0
          )
        ''');

        await db.execute('''
          CREATE TABLE stock_logs(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            product_id INTEGER NOT NULL,
            time TEXT NOT NULL,
            type TEXT NOT NULL,
            qty INTEGER NOT NULL,
            note TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE expenses(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            expense_date TEXT NOT NULL,
            category TEXT NOT NULL,
            note TEXT NOT NULL,
            amount INTEGER NOT NULL,
            payment_status TEXT NOT NULL DEFAULT 'Sudah Dibayar',
            due_date TEXT NOT NULL DEFAULT ''
          )
        ''');

        await db.insert('users', {
          'username': 'admin',
          'password': '1234',
          'role': 'Administrator',
          'active': 1,
        });

        await db.insert('users', {
          'username': 'kasir',
          'password': '1234',
          'role': 'Kasir',
          'active': 1,
        });

        final products = [
      ['Contoh', 'Contoh', 1000],
    ];

        for (final p in products) {
          await db.insert('products', {
            'name': p[0],
            'category': p[1],
            'price': p[2],
            'stock': 1,
            'active': 1,
          });
        }
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            "ALTER TABLE sales ADD COLUMN customer_name TEXT NOT NULL DEFAULT 'Pelanggan Umum'",
          );
          await db.execute(
            "ALTER TABLE sales ADD COLUMN customer_type TEXT NOT NULL DEFAULT 'Retail'",
          );
        }

        if (oldVersion < 3) {
          await db.execute('''
            CREATE TABLE expenses(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              expense_date TEXT NOT NULL,
              category TEXT NOT NULL,
              note TEXT NOT NULL,
              amount INTEGER NOT NULL
            )
          ''');
        }
        if (oldVersion < 4) {
          await db.execute("ALTER TABLE sales ADD COLUMN customer_phone TEXT NOT NULL DEFAULT ''");
          await db.execute("ALTER TABLE sales ADD COLUMN transfer_bank TEXT NOT NULL DEFAULT ''");
          await db.execute("ALTER TABLE sales ADD COLUMN transfer_account TEXT NOT NULL DEFAULT ''");
          await db.execute("ALTER TABLE sales ADD COLUMN due_date TEXT NOT NULL DEFAULT ''");
          await db.execute("ALTER TABLE expenses ADD COLUMN payment_status TEXT NOT NULL DEFAULT 'Sudah Dibayar'");
          await db.execute("ALTER TABLE expenses ADD COLUMN due_date TEXT NOT NULL DEFAULT ''");
        }
        if (oldVersion < 5) {
          await db.execute(
            "ALTER TABLE sale_items ADD COLUMN returned_qty INTEGER NOT NULL DEFAULT 0",
          );
        }
      },
    );

    return _db!;
  }

  static Future<List<Map<String, dynamic>>> products() async {
    final db = await database;

    return db.query(
      'products',
      orderBy: 'category,name',
    );
  }

  static Future<List<Map<String, dynamic>>> users() async {
    final db = await database;

    return db.query(
      'users',
      orderBy: 'username',
    );
  }

  static Future<List<Map<String, dynamic>>> sales() async {
    final db = await database;

    return db.query(
      'sales',
      orderBy: 'sale_time DESC',
    );
  }

  static Future<Map<String, dynamic>?> login(
    String username,
    String password,
  ) async {
    final db = await database;

    final rows = await db.query(
      'users',
      where: 'username=? AND password=? AND active=1',
      whereArgs: [username, password],
      limit: 1,
    );

    return rows.isEmpty ? null : rows.first;
  }

  static Future<void> saveProduct({
    int? id,
    required String name,
    required String category,
    required int price,
    required int stock,
    required bool active,
  }) async {
    final db = await database;

    if (name.trim().isEmpty) {
      throw Exception('Nama menu tidak boleh kosong.');
    }

    if (category.trim().isEmpty) {
      throw Exception('Kategori tidak boleh kosong.');
    }

    if (price <= 0) {
      throw Exception('Harga harus lebih dari 0.');
    }

    if (stock < 0) {
      throw Exception('Stok tidak boleh negatif.');
    }

    final data = {
      'name': name.trim(),
      'category': category.trim(),
      'price': price,
      'stock': stock,
      'active': active ? 1 : 0,
    };

    if (id == null) {
      await db.insert('products', data);
    } else {
      await db.update(
        'products',
        data,
        where: 'id=?',
        whereArgs: [id],
      );
    }
  }

  static Future<void> deleteProduct(int id) async {
    final db = await database;

    await db.update(
      'products',
      {'active': 0},
      where: 'id=?',
      whereArgs: [id],
    );
  }

  static Future<void> addStock(
    int productId,
    int qty,
    String note,
  ) async {
    if (qty <= 0) {
      throw Exception(
        'Jumlah stok harus lebih dari 0.',
      );
    }

    final db = await database;

    await db.transaction((txn) async {
      final product = await txn.query(
        'products',
        where: 'id=?',
        whereArgs: [productId],
        limit: 1,
      );

      if (product.isEmpty) {
        throw Exception(
          'Produk tidak ditemukan.',
        );
      }

      await txn.rawUpdate(
        'UPDATE products SET stock=stock+? WHERE id=?',
        [qty, productId],
      );

      await txn.insert('stock_logs', {
        'product_id': productId,
        'time': stamp(),
        'type': 'MASUK',
        'qty': qty,
        'note': note,
      });
    });
  }

  static Future<String> nextSaleNo(
    Transaction txn,
  ) async {
    final rows = await txn.rawQuery(
      'SELECT id FROM sales ORDER BY id DESC LIMIT 1',
    );

    final next = rows.isEmpty
        ? 1
        : (rows.first['id'] as int) + 1;

    return 'CFC-${next.toString().padLeft(6, '0')}';
  }

  static Future<int> createSale({
    required String cashier,
    required String customerName,
    required String customerPhone,
    required String customerType,
    required List<CartLine> items,
    required int subtotal,
    required int discount,
    required int total,
    required int cash,
    required int change,
    required String payment,
    String transferBank = '',
    String transferAccount = '',
    String dueDate = '',
  }) async {
    if (items.isEmpty) {
      throw Exception(
        'Keranjang masih kosong.',
      );
    }

    if (total < 0) {
      throw Exception(
        'Total transaksi tidak valid.',
      );
    }

    final db = await database;

    return db.transaction<int>((txn) async {
      for (final line in items) {
        final rows = await txn.query(
          'products',
          columns: [
            'id',
            'name',
            'stock',
            'active',
          ],
          where: 'id=?',
          whereArgs: [line.product.id],
          limit: 1,
        );

        if (rows.isEmpty) {
          throw Exception(
            'Produk ${line.product.name} tidak ditemukan.',
          );
        }

        final product = rows.first;

        if ((product['active'] as int) != 1) {
          throw Exception(
            'Produk ${line.product.name} tidak aktif.',
          );
        }

        final stock =
            (product['stock'] as num).toInt();

        if (stock < line.qty) {
          throw Exception(
            'Stok ${line.product.name} tidak cukup. '
            'Tersedia $stock, diperlukan ${line.qty}.',
          );
        }
      }

      // IMPORTANT:
      // Gunakan transaction yang sama.
      final no = await nextSaleNo(txn);

      final saleId = await txn.insert(
        'sales',
        {
          'sale_no': no,
          'sale_time': stamp(),
          'cashier': cashier,
          'customer_name': customerName.trim().isEmpty ? 'Pelanggan Umum' : customerName.trim(),
          'customer_phone': customerPhone.trim(),
          'customer_type': customerType,
          'subtotal': subtotal,
          'discount': discount,
          'total': total,
          'cash': cash,
          'change_amount': change,
          'payment': payment,
          'transfer_bank': transferBank.trim(),
          'transfer_account': transferAccount.trim(),
          'due_date': dueDate.trim(),
          'returned': 0,
        },
      );

      for (final line in items) {
        await txn.insert(
          'sale_items',
          {
            'sale_id': saleId,
            'product_id': line.product.id,
            'name': line.product.name,
            'qty': line.qty,
            'price': line.product.price,
            'returned_qty': 0,
          },
        );

        final updated = await txn.rawUpdate(
          'UPDATE products '
          'SET stock=stock-? '
          'WHERE id=? AND stock>=?',
          [
            line.qty,
            line.product.id,
            line.qty,
          ],
        );

        if (updated != 1) {
          throw Exception(
            'Stok ${line.product.name} berubah. '
            'Silakan ulangi transaksi.',
          );
        }

        await txn.insert(
          'stock_logs',
          {
            'product_id': line.product.id,
            'time': stamp(),
            'type': 'KELUAR',
            'qty': line.qty,
            'note': 'Penjualan $no',
          },
        );
      }

      return saleId;
    });
  }

  static Future<List<Map<String, dynamic>>> saleItems(
    int saleId,
  ) async {
    final db = await database;

    return db.query(
      'sale_items',
      where: 'sale_id=?',
      whereArgs: [saleId],
    );
  }

  static Future<void> returnSalePartial(
    int saleId,
    String adminUser,
    Map<int, int> returnQtyByItem,
  ) async {
    final db = await database;

    if (returnQtyByItem.isEmpty) {
      throw Exception('Tidak ada item yang diretur.');
    }

    await db.transaction((txn) async {
      final saleRows = await txn.query(
        'sales',
        where: 'id=?',
        whereArgs: [saleId],
        limit: 1,
      );

      if (saleRows.isEmpty) {
        throw Exception('Transaksi tidak ditemukan.');
      }

      final items = await txn.query(
        'sale_items',
        where: 'sale_id=?',
        whereArgs: [saleId],
      );

      if (items.isEmpty) {
        throw Exception('Item transaksi tidak ditemukan.');
      }

      final itemById = <int, Map<String, dynamic>>{
        for (final item in items)
          (item['id'] as num).toInt(): item,
      };

      for (final entry in returnQtyByItem.entries) {
        final itemId = entry.key;
        final requested = entry.value;

        if (requested < 0) {
          throw Exception('Jumlah retur tidak boleh negatif.');
        }

        if (requested == 0) continue;

        final item = itemById[itemId];
        if (item == null) {
          throw Exception('Item retur tidak ditemukan.');
        }

        final originalQty = (item['qty'] as num).toInt();
        final returnedQty =
            (item['returned_qty'] as num?)?.toInt() ?? 0;
        final remainingQty = originalQty - returnedQty;

        if (requested > remainingQty) {
          throw Exception(
            'Jumlah retur melebihi sisa item ${item['name']}. '
            'Sisa yang dapat diretur: $remainingQty.',
          );
        }

        final productId = item['product_id'];

        if (productId != null) {
          await txn.rawUpdate(
            'UPDATE products SET stock=stock+? WHERE id=?',
            [requested, productId],
          );

          await txn.insert(
            'stock_logs',
            {
              'product_id': productId,
              'time': stamp(),
              'type': 'RETUR',
              'qty': requested,
              'note': 'Retur oleh $adminUser',
            },
          );
        }

        await txn.rawUpdate(
          'UPDATE sale_items '
          'SET returned_qty = returned_qty + ? '
          'WHERE id=?',
          [requested, itemId],
        );
      }

      final remainingRows = await txn.rawQuery(
        'SELECT COUNT(*) jumlah '
        'FROM sale_items '
        'WHERE sale_id=? AND returned_qty < qty',
        [saleId],
      );

      final remaining =
          (remainingRows.first['jumlah'] as num).toInt();

      await txn.update(
        'sales',
        {'returned': remaining == 0 ? 1 : 0},
        where: 'id=?',
        whereArgs: [saleId],
      );
    });
  }

  static Future<void> returnSale(
    int saleId,
    String adminUser,
  ) async {
    final items = await saleItems(saleId);

    if (items.isEmpty) {
      throw Exception('Item transaksi tidak ditemukan.');
    }

    final returnQtyByItem = <int, int>{};

    for (final item in items) {
      final id = (item['id'] as num).toInt();
      final qty = (item['qty'] as num).toInt();
      final returned =
          (item['returned_qty'] as num?)?.toInt() ?? 0;
      final remaining = qty - returned;

      if (remaining > 0) {
        returnQtyByItem[id] = remaining;
      }
    }

    if (returnQtyByItem.isEmpty) {
      throw Exception('Transaksi sudah diretur seluruhnya.');
    }

    await returnSalePartial(
      saleId,
      adminUser,
      returnQtyByItem,
    );
  }

  static Future<int> returnedAmount(int saleId) async {
    final db = await database;

    final rows = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(returned_qty * price),0) amount
      FROM sale_items
      WHERE sale_id=?
      ''',
      [saleId],
    );

    return (rows.first['amount'] as num).toInt();
  }

  static Future<List<Map<String, dynamic>>> bestSelling(
    DateTime from,
    DateTime to,
  ) async {
    final db = await database;

    return db.rawQuery(
      '''
      SELECT name,
             SUM(qty - returned_qty) qty,
             SUM((qty - returned_qty) * price) omzet
      FROM sale_items
      WHERE sale_id IN (
        SELECT id
        FROM sales
        WHERE sale_time >= ?
          AND sale_time < ?
          AND payment != 'Bayar Tunda'
      )
      GROUP BY name
      HAVING SUM(qty - returned_qty) > 0
      ORDER BY qty DESC
      ''',
      [
        _dbDate(from),
        _dbDate(to),
      ],
    );
  }

  static Future<List<Map<String, dynamic>>> hourly(
    DateTime from,
    DateTime to,
  ) async {
    final db = await database;

    return db.rawQuery(
      '''
      SELECT substr(sale_time,12,2) jam,
             COUNT(*) transaksi,
             SUM((
  total - COALESCE(
    (
      SELECT SUM(si.returned_qty * si.price)
      FROM sale_items si
      WHERE si.sale_id = sales.id
    ),
    0
  )
)) omzet
      FROM sales
      WHERE sale_time >= ?
        AND sale_time < ?
        AND payment != 'Bayar Tunda'
      GROUP BY jam
      ORDER BY transaksi DESC
      ''',
      [
        _dbDate(from),
        _dbDate(to),
      ],
    );
  }

  static Future<List<Map<String, dynamic>>> daily(
    DateTime from,
    DateTime to,
  ) async {
    final db = await database;

    return db.rawQuery(
      '''
      SELECT substr(sale_time,1,10) tanggal,
             COUNT(*) transaksi,
             SUM((
  total - COALESCE(
    (
      SELECT SUM(si.returned_qty * si.price)
      FROM sale_items si
      WHERE si.sale_id = sales.id
    ),
    0
  )
)) omzet
      FROM sales
      WHERE sale_time >= ?
        AND sale_time < ?
        AND payment != 'Bayar Tunda'
      GROUP BY tanggal
      ORDER BY transaksi DESC
      ''',
      [
        _dbDate(from),
        _dbDate(to),
      ],
    );
  }


  static Future<List<Map<String, dynamic>>> customerSales(
    DateTime from,
    DateTime to,
  ) async {
    final db = await database;
    return db.rawQuery(
      '''
      SELECT
        COALESCE(NULLIF(customer_name,''),'Pelanggan Umum') customer_name,
        COALESCE(NULLIF(customer_type,''),'Retail') customer_type,
        COUNT(*) transaksi,
        COALESCE(SUM((
  total - COALESCE(
    (
      SELECT SUM(si.returned_qty * si.price)
      FROM sale_items si
      WHERE si.sale_id = sales.id
    ),
    0
  )
)),0) omzet
      FROM sales
      WHERE sale_time >= ?
        AND sale_time < ?
        AND payment != 'Bayar Tunda'
      GROUP BY customer_name, customer_type
      ORDER BY omzet DESC
      ''',
      [_dbDate(from), _dbDate(to)],
    );
  }

  static Future<int> monthOmzet(DateTime date) async {
    final from = DateTime(date.year, date.month, 1);
    final to = DateTime(date.year, date.month + 1, 1);
    return omzet(from, to);
  }

  static Future<List<Map<String, dynamic>>> monthlyTrend(
    DateTime from,
    DateTime to,
  ) async {
    final db = await database;
    return db.rawQuery(
      '''
      SELECT substr(sale_time,1,7) periode,
             COUNT(*) transaksi,
             COALESCE(SUM((
  total - COALESCE(
    (
      SELECT SUM(si.returned_qty * si.price)
      FROM sale_items si
      WHERE si.sale_id = sales.id
    ),
    0
  )
)),0) omzet
      FROM sales
      WHERE sale_time >= ?
        AND sale_time < ?
        AND payment != 'Bayar Tunda'
      GROUP BY periode
      ORDER BY periode
      ''',
      [_dbDate(from), _dbDate(to)],
    );
  }

  static Future<List<Map<String, dynamic>>> yearlyTrend(
    DateTime from,
    DateTime to,
  ) async {
    final db = await database;
    return db.rawQuery(
      '''
      SELECT substr(sale_time,1,4) periode,
             COUNT(*) transaksi,
             COALESCE(SUM((
  total - COALESCE(
    (
      SELECT SUM(si.returned_qty * si.price)
      FROM sale_items si
      WHERE si.sale_id = sales.id
    ),
    0
  )
)),0) omzet
      FROM sales
      WHERE sale_time >= ?
        AND sale_time < ?
        AND payment != 'Bayar Tunda'
      GROUP BY periode
      ORDER BY periode
      ''',
      [_dbDate(from), _dbDate(to)],
    );
  }


  static Future<List<String>> customerSuggestions(String keyword) async {
    final db = await database;

    final rows = await db.rawQuery(
      '''
      SELECT DISTINCT customer_name
      FROM sales
      WHERE TRIM(COALESCE(customer_name,'')) != ''
        AND customer_name LIKE ?
      ORDER BY customer_name
      LIMIT 10
      ''',
      ['$keyword%'],
    );

    return rows
        .map((e) => e['customer_name'].toString())
        .toList();
  }

  static Future<int> omzet(
    DateTime from,
    DateTime to,
  ) async {
    final db = await database;

    final rows = await db.rawQuery(
      '''
      SELECT COALESCE(
        SUM(
          total - COALESCE(
            (
              SELECT SUM(si.returned_qty * si.price)
              FROM sale_items si
              WHERE si.sale_id = sales.id
            ),
            0
          )
        ),
        0
      ) total
      FROM sales
      WHERE sale_time >= ?
        AND sale_time < ?
        AND payment != 'Bayar Tunda'
      ''',
      [
        _dbDate(from),
        _dbDate(to),
      ],
    );

    return (rows.first['total'] as num).toInt();
  }

  static Future<int> payLaterTotal(
    DateTime from,
    DateTime to,
  ) async {
    final db = await database;

    final rows = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(total),0) total
      FROM sales
      WHERE sale_time >= ?
        AND sale_time < ?
        AND returned=0
        AND payment = 'Bayar Tunda'
      ''',
      [
        _dbDate(from),
        _dbDate(to),
      ],
    );

    return (rows.first['total'] as num).toInt();
  }

  static Future<void> saveUser({
    int? id,
    required String username,
    required String password,
    required String role,
    required bool active,
  }) async {
    final db = await database;

    final cleanUsername = username.trim();

    if (cleanUsername.isEmpty) {
      throw Exception(
        'Username tidak boleh kosong.',
      );
    }

    if (password.isEmpty) {
      throw Exception(
        'Password tidak boleh kosong.',
      );
    }

    if (role != 'Administrator' &&
        role != 'Kasir') {
      throw Exception(
        'Role pengguna tidak valid.',
      );
    }

    final duplicate = await db.query(
      'users',
      columns: ['id'],
      where: 'username=? AND id!=?',
      whereArgs: [
        cleanUsername,
        id ?? -1,
      ],
      limit: 1,
    );

    if (duplicate.isNotEmpty) {
      throw Exception(
        'Username "$cleanUsername" sudah digunakan.',
      );
    }

    final data = {
      'username': cleanUsername,
      'password': password,
      'role': role,
      'active': active ? 1 : 0,
    };

    if (id == null) {
      await db.insert('users', data);
    } else {
      await db.update(
        'users',
        data,
        where: 'id=?',
        whereArgs: [id],
      );
    }
  }

  static Future<Map<String, dynamic>> daySummary(DateTime day) async {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    final db = await database;

    final salesRows = await db.query(
      'sales',
      where: 'sale_time >= ? AND sale_time < ?',
      whereArgs: [_dbDate(start), _dbDate(end)],
      orderBy: 'sale_time DESC',
    );

    final valid = salesRows.toList();
    final returnedRows = await db.rawQuery(
      '''
      SELECT DISTINCT s.*
      FROM sales s
      INNER JOIN sale_items si ON si.sale_id = s.id
      WHERE s.sale_time >= ?
        AND s.sale_time < ?
        AND si.returned_qty > 0
      ORDER BY s.sale_time DESC
      ''',
      [_dbDate(start), _dbDate(end)],
    );
    final returned = returnedRows;

    final summaryRows = await db.rawQuery(
      "SELECT "
      "COALESCE(SUM(si.qty - si.returned_qty),0) item, "
      "COALESCE(SUM(si.returned_qty * si.price),0) returned_amount "
      "FROM sale_items si "
      "INNER JOIN sales s ON s.id=si.sale_id "
      "WHERE s.sale_time >= ? "
      "AND s.sale_time < ? "
      "AND s.payment != 'Bayar Tunda'",
      [_dbDate(start), _dbDate(end)],
    );

    final gross = valid
        .where((x) => x['payment'] != 'Bayar Tunda')
        .fold<int>(
          0,
          (sum, x) => sum + (x['total'] as num).toInt(),
        );

    final returnAmount =
        (summaryRows.first['returned_amount'] as num).toInt();

    final net = gross - returnAmount;

    final payments = <String, int>{};

    for (final row in valid) {
      final payment = row['payment']?.toString() ?? 'Lainnya';
      payments[payment] = (payments[payment] ?? 0) + 1;
    }

    return {
      'sales': valid,
      'returnedSales': returned,
      'returned': returned.length,
      'gross': gross,
      'returnAmount': returnAmount,
      'omzet': net,
      'net': net,
      'transaksi': valid
          .where((x) => x['payment'] != 'Bayar Tunda')
          .length,
      'item': (summaryRows.first['item'] as num).toInt(),
      'payments': payments,
    };
  }

  static Future<Map<String, dynamic>> rangeSummary(
    DateTime from,
    DateTime to,
  ) async {
    final db = await database;

    final salesRows = await db.query(
      'sales',
      where: 'sale_time >= ? AND sale_time < ?',
      whereArgs: [_dbDate(from), _dbDate(to)],
      orderBy: 'sale_time DESC',
    );

    final valid = salesRows.toList();
    final returnedRows = await db.rawQuery(
      '''
      SELECT DISTINCT s.*
      FROM sales s
      INNER JOIN sale_items si ON si.sale_id = s.id
      WHERE s.sale_time >= ?
        AND s.sale_time < ?
        AND si.returned_qty > 0
      ORDER BY s.sale_time DESC
      ''',
      [_dbDate(from), _dbDate(to)],
    );
    final returned = returnedRows;

    final summaryRows = await db.rawQuery(
      "SELECT "
      "COALESCE(SUM(si.qty - si.returned_qty),0) item, "
      "COALESCE(SUM(si.returned_qty * si.price),0) returned_amount "
      "FROM sale_items si "
      "INNER JOIN sales s ON s.id=si.sale_id "
      "WHERE s.sale_time >= ? "
      "AND s.sale_time < ? "
      "AND s.payment != 'Bayar Tunda'",
      [_dbDate(from), _dbDate(to)],
    );

    final gross = valid
        .where((x) => x['payment'] != 'Bayar Tunda')
        .fold<int>(
          0,
          (sum, x) => sum + (x['total'] as num).toInt(),
        );

    final returnAmount =
        (summaryRows.first['returned_amount'] as num).toInt();

    final net = gross - returnAmount;

    final payments = <String, int>{};

    for (final row in valid) {
      final payment = row['payment']?.toString() ?? 'Lainnya';
      payments[payment] = (payments[payment] ?? 0) + 1;
    }

    return {
      'sales': valid,
      'returnedSales': returned,
      'returned': returned.length,
      'gross': gross,
      'returnAmount': returnAmount,
      'omzet': net,
      'net': net,
      'transaksi': valid
          .where((x) => x['payment'] != 'Bayar Tunda')
          .length,
      'item': (summaryRows.first['item'] as num).toInt(),
      'payments': payments,
    };
  }

  static Future<List<Map<String, dynamic>>> expenses(
    DateTime from,
    DateTime to,
  ) async {
    final db = await database;
    return db.query(
      'expenses',
      where: 'expense_date >= ? AND expense_date < ?',
      whereArgs: [_dbDate(from), _dbDate(to)],
      orderBy: 'expense_date DESC, id DESC',
    );
  }

  static Future<int> expenseTotal(
    DateTime from,
    DateTime to,
  ) async {
    final db = await database;
    final rows = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(amount), 0) AS total
      FROM expenses
      WHERE expense_date >= ? AND expense_date < ?
      ''',
      [_dbDate(from), _dbDate(to)],
    );
    return (rows.first['total'] as num).toInt();
  }

  static Future<int> expenseDebtTotal(DateTime from, DateTime to) async {
    final db = await database;
    final rows = await db.rawQuery("SELECT COALESCE(SUM(amount),0) total FROM expenses WHERE expense_date >= ? AND expense_date < ? AND payment_status='Jatuh Tempo'", [_dbDate(from), _dbDate(to)]);
    return (rows.first['total'] as num).toInt();
  }

  static Future<void> saveExpense({
    int? id,
    required DateTime date,
    required String category,
    required String note,
    required int amount,
    String paymentStatus = 'Sudah Dibayar',
    DateTime? dueDate,
  }) async {
    if (category.trim().isEmpty) {
      throw Exception('Kategori wajib diisi.');
    }
    if (note.trim().isEmpty) {
      throw Exception('Keterangan wajib diisi.');
    }
    if (amount <= 0) {
      throw Exception('Nominal harus lebih dari 0.');
    }

    final db = await database;

    final data = {
      'expense_date': _dbDate(date),
      'category': category.trim(),
      'note': note.trim(),
      'amount': amount,
      'payment_status': paymentStatus,
      'due_date': paymentStatus == 'Jatuh Tempo' && dueDate != null ? _dbDate(dueDate) : '',
    };

    if (id == null) {
      await db.insert('expenses', data);
    } else {
      await db.update(
        'expenses',
        data,
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  static Future<void> deleteExpense(int id) async {
    final db = await database;
    await db.delete(
      'expenses',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<Map<String, dynamic>> backup() async {
    final db = await database;

    return {
      'version': '7.0.0',
      'created': stamp(),
      'products': await db.query('products'),
      'users': await db.query('users'),
      'sales': await db.query('sales'),
      'sale_items': await db.query('sale_items'),
      'stock_logs': await db.query('stock_logs'),
      'expenses': await db.query('expenses'),
    };
  }
  static Future<void> restoreBackup(Map<String, dynamic> data) async {
    const tables = ['products', 'users', 'sales', 'sale_items', 'stock_logs'];
    for (final table in tables) {
      if (data[table] is! List) {
        throw Exception('Format backup tidak valid: $table');
      }
    }
    final db = await database;
    await db.transaction((txn) async {
      for (final table in tables) {
        await txn.delete(table);
      }
      for (final row in (data['products'] as List)) {
        await txn.insert('products', Map<String, Object?>.from(row as Map));
      }
      for (final row in (data['users'] as List)) {
        await txn.insert('users', Map<String, Object?>.from(row as Map));
      }
      for (final row in (data['sales'] as List)) {
        await txn.insert('sales', Map<String, Object?>.from(row as Map));
      }
      for (final row in (data['sale_items'] as List)) {
        await txn.insert('sale_items', Map<String, Object?>.from(row as Map));
      }
      for (final row in (data['stock_logs'] as List)) {
        await txn.insert('stock_logs', Map<String, Object?>.from(row as Map));
      }

      if (data['expenses'] is List) {
        for (final row in (data['expenses'] as List)) {
          await txn.insert('expenses', Map<String, Object?>.from(row as Map));
        }
      }
    });
  }

}
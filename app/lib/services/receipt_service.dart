import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';
import '../core/utils.dart';
import '../data/database.dart';
import '../models/models.dart';

Future<String> storeName() async {
  final p = await SharedPreferences.getInstance();
  return p.getString('store_name') ?? 'COLONEL FRIED CHICKEN';
}

Future<String> storeAddress() async {
  final p = await SharedPreferences.getInstance();
  return p.getString('store_address') ?? '';
}

Future<String> storePhone() async {
  final p = await SharedPreferences.getInstance();
  return p.getString('store_phone') ?? '';
}

Future<String> printerPaper() async {
  final p = await SharedPreferences.getInstance();
  return p.getString('printer_paper') ?? '58 mm';
}

Future<int> printerCopies() async {
  final p = await SharedPreferences.getInstance();
  return p.getInt('printer_copies') ?? 1;
}

Future<bool> printerAutoPrint() async {
  final p = await SharedPreferences.getInstance();
  return p.getBool('printer_auto_print') ?? false;
}

Future<String> printerMode() async {
  final p = await SharedPreferences.getInstance();
  return p.getString('printer_mode') ?? 'System';
}

Future<String?> printerMac() async {
  final p = await SharedPreferences.getInstance();
  return p.getString('printer_mac');
}

PdfPageFormat _paperFormat(String paper) {
  final width = paper == '80 mm' ? 80.0 : 58.0;
  final widthPt = width / 25.4 * 72.0;
  final heightPt = 220.0 / 25.4 * 72.0;
  return PdfPageFormat(widthPt, heightPt, marginAll: 8);
}

Future<pw.Document> _buildReceipt(SaleModel sale, {int copies = 1}) async {
  final name = await storeName();
  final address = await storeAddress();
  final phone = await storePhone();
  final items = await DB.saleItems(sale.id);
  final doc = pw.Document();
  final format = _paperFormat(await printerPaper());

  for (var copy = 0; copy < copies; copy++) {
    doc.addPage(
      pw.Page(
        pageFormat: format,
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text(name, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
            if (address.isNotEmpty) pw.Text(address, textAlign: pw.TextAlign.center),
            if (phone.isNotEmpty) pw.Text(phone, textAlign: pw.TextAlign.center),
            pw.SizedBox(height: 7),
            pw.Text('NOTA PENJUALAN', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Divider(),
            pw.Align(alignment: pw.Alignment.centerLeft, child: pw.Text('${sale.no}\n${sale.time}\nKasir: ${sale.cashier}')),
            pw.SizedBox(height: 7),
            ...items.map((i) => pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Expanded(child: pw.Text('${i['name']} x${i['qty']}')),
                    pw.SizedBox(width: 8),
                    pw.Text(rp((i['price'] as int) * (i['qty'] as int))),
                  ],
                )),
            pw.Divider(),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Subtotal'), pw.Text(rp(sale.subtotal))]),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Diskon'), pw.Text(rp(sale.discount))]),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('TOTAL', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text(rp(sale.total), style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Text('Pembayaran: ${sale.payment}'),
            if (sale.payment == 'Tunai') ...[
              pw.Text('Tunai: ${rp(sale.cash)}'),
              pw.Text('Kembalian: ${rp(sale.change)}'),
            ],
            pw.SizedBox(height: 14),
            pw.Text('Terima kasih'),
            pw.SizedBox(height: 10),
            pw.Text(copyright1),
            pw.Text(copyright2),
          ],
        ),
      ),
    );
  }
  return doc;
}

Future<List<int>> _escPosReceipt(SaleModel sale, {required String paper, int copies = 1}) async {
  final profile = await CapabilityProfile.load();
  final generator = Generator(paper == '80 mm' ? PaperSize.mm80 : PaperSize.mm58, profile);
  final name = await storeName();
  final address = await storeAddress();
  final phone = await storePhone();
  final items = await DB.saleItems(sale.id);
  final bytes = <int>[];

  for (var copy = 0; copy < copies; copy++) {
    bytes.addAll(generator.reset());
    bytes.addAll(generator.text(name, styles: PosStyles(align: PosAlign.center, bold: true)));
    if (address.isNotEmpty) bytes.addAll(generator.text(address, styles: PosStyles(align: PosAlign.center)));
    if (phone.isNotEmpty) bytes.addAll(generator.text(phone, styles: PosStyles(align: PosAlign.center)));
    bytes.addAll(generator.text('NOTA PENJUALAN', styles: PosStyles(align: PosAlign.center, bold: true)));
    bytes.addAll(generator.hr());
    bytes.addAll(generator.text('${sale.no}\n${sale.time}\nKasir: ${sale.cashier}'));
    bytes.addAll(generator.feed(1));

    for (final item in items) {
      final itemName = '${item['name']} x${item['qty']}';
      final amount = rp((item['price'] as int) * (item['qty'] as int));
      bytes.addAll(generator.row([
        PosColumn(text: itemName, width: 8),
        PosColumn(text: amount, width: 4, styles: PosStyles(align: PosAlign.right)),
      ]));
    }

    bytes.addAll(generator.hr());
    bytes.addAll(generator.row([
      PosColumn(text: 'Subtotal', width: 7),
      PosColumn(text: rp(sale.subtotal), width: 5, styles: PosStyles(align: PosAlign.right)),
    ]));
    bytes.addAll(generator.row([
      PosColumn(text: 'Diskon', width: 7),
      PosColumn(text: rp(sale.discount), width: 5, styles: PosStyles(align: PosAlign.right)),
    ]));
    bytes.addAll(generator.row([
      PosColumn(text: 'TOTAL', width: 7, styles: PosStyles(bold: true)),
      PosColumn(text: rp(sale.total), width: 5, styles: PosStyles(align: PosAlign.right, bold: true)),
    ]));
    bytes.addAll(generator.feed(1));
    bytes.addAll(generator.text('Pembayaran: ${sale.payment}', styles: PosStyles(align: PosAlign.center)));
    if (sale.payment == 'Tunai') {
      bytes.addAll(generator.text('Tunai: ${rp(sale.cash)}', styles: PosStyles(align: PosAlign.center)));
      bytes.addAll(generator.text('Kembalian: ${rp(sale.change)}', styles: PosStyles(align: PosAlign.center)));
    }
    bytes.addAll(generator.feed(2));
    bytes.addAll(generator.text('Terima kasih', styles: PosStyles(align: PosAlign.center, bold: true)));
    bytes.addAll(generator.text('CP Colonel POS V6.5', styles: PosStyles(align: PosAlign.center)));
    bytes.addAll(generator.feed(2));
    bytes.addAll(generator.cut());
  }
  return bytes;
}

Future<bool> _ensureBluetoothConnection() async {
  final permission = await PrintBluetoothThermal.isPermissionBluetoothGranted;
  if (!permission) {
    throw Exception('Izin Perangkat Terdekat/Bluetooth belum diberikan. Buka Pengaturan Android > Aplikasi > CP Colonel POS > Izin, lalu izinkan Perangkat Terdekat.');
  }
  final enabled = await PrintBluetoothThermal.bluetoothEnabled;
  if (!enabled) {
    throw Exception('Bluetooth HP sedang mati. Nyalakan Bluetooth lalu coba lagi.');
  }
  final mac = await printerMac();
  if (mac == null || mac.trim().isEmpty) {
    throw Exception('Printer belum dipilih. Buka Pengaturan > Printer dan pilih printer yang sudah dipasangkan.');
  }
  if (await PrintBluetoothThermal.connectionStatus) return true;
  return PrintBluetoothThermal.connect(macPrinterAddress: mac.trim());
}

Future<void> _printBluetoothSale(SaleModel sale) async {
  final ok = await _ensureBluetoothConnection();
  if (!ok) {
    throw Exception('Printer Bluetooth belum terhubung. Buka Pengaturan > Printer, pilih printer dan tekan Hubungkan.');
  }
  final bytes = await _escPosReceipt(sale, paper: await printerPaper(), copies: (await printerCopies()).clamp(1, 2));
  final sent = await PrintBluetoothThermal.writeBytes(bytes);
  if (!sent) throw Exception('Data struk gagal dikirim ke printer Bluetooth.');
}

Future<pw.Document> _buildExpenseReceipt(
  Map<String, dynamic> item,
) async {
  final name = await storeName();
  final address = await storeAddress();
  final phone = await storePhone();

  final doc = pw.Document();
  final format = _paperFormat(await printerPaper());

  final category = item['category']?.toString() ?? 'Pembelian';
  final note = item['note']?.toString() ?? '';
  final amount = (item['amount'] as num?)?.toInt() ?? 0;
  final date = item['expense_date']?.toString() ?? '';
  final dueDate = item['due_date']?.toString() ?? '';
  final status = item['payment_status']?.toString() ?? 'Hutang';

  doc.addPage(
    pw.Page(
      pageFormat: format,
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(
            name,
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
            ),
            textAlign: pw.TextAlign.center,
          ),
          if (address.isNotEmpty)
            pw.Text(
              address,
              textAlign: pw.TextAlign.center,
            ),
          if (phone.isNotEmpty)
            pw.Text(
              phone,
              textAlign: pw.TextAlign.center,
            ),

          pw.SizedBox(height: 8),

          pw.Text(
            'NOTA HUTANG PEMBELIAN',
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
            ),
          ),

          pw.Divider(),

          pw.Align(
            alignment: pw.Alignment.centerLeft,
            child: pw.Text('Tanggal: $date'),
          ),
          pw.Align(
            alignment: pw.Alignment.centerLeft,
            child: pw.Text('Kategori: $category'),
          ),

          if (note.isNotEmpty)
            pw.Align(
              alignment: pw.Alignment.centerLeft,
              child: pw.Text('Keterangan: $note'),
            ),

          if (dueDate.isNotEmpty)
            pw.Align(
              alignment: pw.Alignment.centerLeft,
              child: pw.Text('Jatuh tempo: $dueDate'),
            ),

          pw.Align(
            alignment: pw.Alignment.centerLeft,
            child: pw.Text('Status: $status'),
          ),

          pw.Divider(),

          pw.Row(
            mainAxisAlignment:
                pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'TOTAL',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                rp(amount),
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 14),

          pw.Text('Bukti pencatatan hutang pembelian'),
        ],
      ),
    ),
  );

  return doc;
}

Future<List<int>> _escPosExpenseReceipt(
  Map<String, dynamic> item,
) async {
  final profile = await CapabilityProfile.load();

  final paper = await printerPaper();

  final generator = Generator(
    paper == '80 mm'
        ? PaperSize.mm80
        : PaperSize.mm58,
    profile,
  );

  final name = await storeName();
  final address = await storeAddress();
  final phone = await storePhone();

  final category = item['category']?.toString() ?? 'Pembelian';
  final note = item['note']?.toString() ?? '';
  final amount = (item['amount'] as num?)?.toInt() ?? 0;
  final date = item['expense_date']?.toString() ?? '';
  final dueDate = item['due_date']?.toString() ?? '';
  final status = item['payment_status']?.toString() ?? 'Hutang';

  final bytes = <int>[];

  bytes.addAll(generator.reset());

  bytes.addAll(
    generator.text(
      name,
      styles: PosStyles(
        align: PosAlign.center,
        bold: true,
      ),
    ),
  );

  if (address.isNotEmpty) {
    bytes.addAll(
      generator.text(
        address,
        styles: PosStyles(
          align: PosAlign.center,
        ),
      ),
    );
  }

  if (phone.isNotEmpty) {
    bytes.addAll(
      generator.text(
        phone,
        styles: PosStyles(
          align: PosAlign.center,
        ),
      ),
    );
  }

  bytes.addAll(
    generator.text(
      'NOTA HUTANG PEMBELIAN',
      styles: PosStyles(
        align: PosAlign.center,
        bold: true,
      ),
    ),
  );

  bytes.addAll(generator.hr());

  bytes.addAll(generator.text('Tanggal: $date'));
  bytes.addAll(generator.text('Kategori: $category'));

  if (note.isNotEmpty) {
    bytes.addAll(generator.text('Keterangan: $note'));
  }

  if (dueDate.isNotEmpty) {
    bytes.addAll(
      generator.text('Jatuh tempo: $dueDate'),
    );
  }

  bytes.addAll(generator.text('Status: $status'));

  bytes.addAll(generator.hr());

  bytes.addAll(
    generator.row([
      PosColumn(
        text: 'TOTAL',
        width: 7,
        styles: PosStyles(
          bold: true,
        ),
      ),
      PosColumn(
        text: rp(amount),
        width: 5,
        styles: PosStyles(
          align: PosAlign.right,
          bold: true,
        ),
      ),
    ]),
  );

  bytes.addAll(generator.feed(2));

  bytes.addAll(
    generator.text(
      'Bukti pencatatan hutang pembelian',
      styles: PosStyles(
        align: PosAlign.center,
      ),
    ),
  );

  bytes.addAll(generator.feed(2));
  bytes.addAll(generator.cut());

  return bytes;
}

Future<void> printExpenseReceipt(
  Map<String, dynamic> item,
) async {
  final mode = await printerMode();

  if (mode == 'Bluetooth') {
    final connected =
        await _ensureBluetoothConnection();

    if (!connected) {
      throw Exception(
        'Printer Bluetooth belum terhubung.',
      );
    }

    final bytes =
        await _escPosExpenseReceipt(item);

    final sent =
        await PrintBluetoothThermal.writeBytes(bytes);

    if (!sent) {
      throw Exception(
        'Gagal mengirim bukti hutang ke printer.',
      );
    }

    return;
  }

  final doc =
      await _buildExpenseReceipt(item);

  await Printing.layoutPdf(
    name: 'CP POS Hutang',
    onLayout: (_) => doc.save(),
  );
}

Future<void> printReceipt(SaleModel sale) async {
  final copies = (await printerCopies()).clamp(1, 2);
  if (await printerMode() == 'Bluetooth') {
    await _printBluetoothSale(sale);
    return;
  }
  final doc = await _buildReceipt(sale, copies: copies);
  await Printing.layoutPdf(name: 'CP POS ${sale.no}', onLayout: (_) => doc.save());
}

Future<void> testPrinterReceipt() async {
  final mode = await printerMode();
  if (mode == 'Bluetooth') {
    final ok = await _ensureBluetoothConnection();
    if (!ok) throw Exception('Printer Bluetooth belum terhubung.');
    final paper = await printerPaper();
    final profile = await CapabilityProfile.load();
    final generator = Generator(paper == '80 mm' ? PaperSize.mm80 : PaperSize.mm58, profile);
    final bytes = <int>[];
    bytes.addAll(generator.reset());
    bytes.addAll(generator.text('CP POS', styles: PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size2)));
    bytes.addAll(generator.text('TEST PRINT', styles: PosStyles(align: PosAlign.center, bold: true)));
    bytes.addAll(generator.hr());
    bytes.addAll(generator.text('Printer Bluetooth siap digunakan.', styles: PosStyles(align: PosAlign.center)));
    bytes.addAll(generator.text('Kertas: $paper', styles: PosStyles(align: PosAlign.center)));
    bytes.addAll(generator.feed(3));
    bytes.addAll(generator.cut());
    final sent = await PrintBluetoothThermal.writeBytes(bytes);
    if (!sent) throw Exception('Test print gagal dikirim.');
    return;
  }

  final paper = await printerPaper();
  final doc = pw.Document();
  doc.addPage(
    pw.Page(
      pageFormat: _paperFormat(paper),
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text('CP POS', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Text('TEST PRINT'),
          pw.Divider(),
          pw.Text('Printer siap digunakan.'),
          pw.SizedBox(height: 12),
          pw.Text('Kertas: $paper'),
          pw.SizedBox(height: 14),
          pw.Text('CP Colonel POS V6.5'),
        ],
      ),
    ),
  );
  await Printing.layoutPdf(name: 'CP POS Test Print', onLayout: (_) => doc.save());
}

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import '../../core/app_localizations.dart';
import '../../core/widgets.dart';
import '../../data/database.dart';
import '../../services/google_drive_backup_service.dart';

class BackupPage extends StatefulWidget {
  const BackupPage({super.key});
  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  bool working=false;

  Future<File> makeBackup() async {
    final data=await DB.backup();
    final dir=await getApplicationDocumentsDirectory();
    final file=File(path.join(dir.path,'colonel_pos_v65_backup_${DateTime.now().millisecondsSinceEpoch}.json'));
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
    return file;
  }

  Future<void> backup() async {
    if(working) return;
    setState(()=>working=true);

    try {
      final data = await DB.backup();
      final bytes = utf8.encode(
        const JsonEncoder.withIndent('  ').convert(data),
      );

      final fileName =
          'colonel_pos_v65_backup_${DateTime.now().millisecondsSinceEpoch}.json';

      final savedPath = await FilePicker.platform.saveFile(
        dialogTitle: AppLocalizations.t(
          'Simpan Backup CP Colonel POS',
          'Save CP Colonel POS Backup',
        ),
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['json'],
        bytes: bytes,
      );

      if (!mounted) return;

      if (savedPath == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
          content: Text(
            AppLocalizations.t(
              'Backup dibatalkan.',
              'Backup cancelled.',
            ),
          ),
        ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
          content: Text(
            AppLocalizations.t(
              'Backup berhasil disimpan.',
              'Backup saved successfully.',
            ),
          ),
        ),
        );
      }
    } catch(e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
          content: Text(
            AppLocalizations.t(
              'Backup gagal: $e',
              'Backup failed: $e',
            ),
          ),
        ),
        );
      }
    } finally {
      if(mounted) setState(()=>working=false);
    }
  }

  Future<void> backupToGoogleDrive() async {
    if (working) return;

    setState(() => working = true);

    try {
      final data = await DB.backup();

      final fileName =
          await GoogleDriveBackupService.uploadBackup(data: data);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              AppLocalizations.t(
                'Backup Google Drive berhasil: $fileName',
                'Google Drive backup successful: $fileName',
              ),
            ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.t(
                'Backup Google Drive gagal: $e',
                'Google Drive backup failed: $e',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => working = false);
    }
  }


  String _reportMoney(dynamic value) {
    final n = value is num ? value.round() : int.tryParse('$value') ?? 0;
    return 'Rp ${n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.')}';
  }

  String _reportText(dynamic value) => value == null ? '' : '$value';

  Future<Map<String, List<Map<String, Object?>>>> _readReportData() async {
    final db = await DB.database;
    return {
      'sales': await db.query('sales', orderBy: 'sale_time DESC'),
      'items': await db.query('sale_items', orderBy: 'sale_id DESC'),
      'products': await db.query('products', orderBy: 'name ASC'),
      'stock': await db.query('stock_logs', orderBy: 'time DESC'),
      'expenses': await db.query('expenses', orderBy: 'expense_date DESC'),
    };
  }

  Future<void> exportExcelReport() async {
    if (working) return;
    setState(() => working = true);
    try {
      final data = await _readReportData();
      final book = Excel.createExcel();

      void addSheet(String name, List<String> headers,
          List<List<String>> rows) {
        final sheet = book[name];
        sheet.appendRow(headers.map((v) => TextCellValue(v)).toList());
        for (final row in rows) {
          sheet.appendRow(row.map((v) => TextCellValue(v)).toList());
        }
      }

      final sales = data['sales']!;
      final items = data['items']!;
      final products = data['products']!;
      final stock = data['stock']!;
      final expenses = data['expenses']!;

      final totalSales = sales.fold<int>(
          0, (sum, r) => sum + ((r['total'] as num?)?.toInt() ?? 0));
      final totalExpenses = expenses.fold<int>(
          0, (sum, r) => sum + ((r['amount'] as num?)?.toInt() ?? 0));
      final now = DateTime.now().toString().substring(0, 19);

      addSheet('Ringkasan', ['Informasi', 'Nilai'], [
        ['Laporan Colonel POS', ''],
        ['Waktu ekspor', now],
        ['Jumlah transaksi tercatat', '${sales.length}'],
        ['Total penjualan tercatat', _reportMoney(totalSales)],
        ['Jumlah produk', '${products.length}'],
        ['Total pengeluaran tercatat', _reportMoney(totalExpenses)],
      ]);

      addSheet('Penjualan',
        ['No. Transaksi','Waktu','Kasir','Pelanggan','Tipe','Subtotal','Diskon','Total','Pembayaran','Status Retur'],
        sales.map((r) => [
          _reportText(r['sale_no']), _reportText(r['sale_time']),
          _reportText(r['cashier']), _reportText(r['customer_name']),
          _reportText(r['customer_type']), _reportMoney(r['subtotal']),
          _reportMoney(r['discount']), _reportMoney(r['total']),
          _reportText(r['payment']), _reportText(r['returned']),
        ]).toList());

      final saleNo = {for (final r in sales) '${r['id']}': r['sale_no']};
      addSheet('Detail Penjualan',
        ['No. Transaksi','Nama Barang','Qty','Qty Retur','Harga'],
        items.map((r) => [
          _reportText(saleNo['${r['sale_id']}']), _reportText(r['name']),
          _reportText(r['qty']), _reportText(r['returned_qty']),
          _reportMoney(r['price']),
        ]).toList());

      addSheet('Produk dan Stok',
        ['ID','Nama Produk','Kategori','Harga','Stok','Aktif'],
        products.map((r) => [
          _reportText(r['id']), _reportText(r['name']),
          _reportText(r['category']), _reportMoney(r['price']),
          _reportText(r['stock']), _reportText(r['active']),
        ]).toList());

      addSheet('Mutasi Stok',
        ['Waktu','ID Produk','Jenis','Qty','Catatan'],
        stock.map((r) => [
          _reportText(r['time']), _reportText(r['product_id']),
          _reportText(r['type']), _reportText(r['qty']),
          _reportText(r['note']),
        ]).toList());

      addSheet('Pengeluaran',
        ['Tanggal','Kategori','Catatan','Jumlah','Status Bayar','Jatuh Tempo'],
        expenses.map((r) => [
          _reportText(r['expense_date']), _reportText(r['category']),
          _reportText(r['note']), _reportMoney(r['amount']),
          _reportText(r['payment_status']), _reportText(r['due_date']),
        ]).toList());

      final bytes = book.encode();
      if (bytes == null) throw Exception('Gagal membuat file Excel.');
      await FilePicker.platform.saveFile(
        fileName: 'colonel_pos_laporan_${DateTime.now().millisecondsSinceEpoch}.xlsx',
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        bytes: Uint8List.fromList(bytes),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ekspor Excel gagal: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  Future<void> exportPdfReport() async {
    if (working) return;
    setState(() => working = true);
    try {
      final data = await _readReportData();
      final sales = data['sales']!;
      final expenses = data['expenses']!;
      final products = data['products']!;
      final totalSales = sales.fold<int>(
          0, (sum, r) => sum + ((r['total'] as num?)?.toInt() ?? 0));
      final totalExpenses = expenses.fold<int>(
          0, (sum, r) => sum + ((r['amount'] as num?)?.toInt() ?? 0));
      final pdf = pw.Document();
      final stamp = DateTime.now().toString().substring(0, 19);

      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (_) => pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 8),
          child: pw.Text('COLONEL POS  |  LAPORAN USAHA',
            style: pw.TextStyle(fontSize: 10, color: PdfColors.blueGrey700)),
        ),
        build: (_) => [
          pw.Text('Laporan Penjualan dan Operasional',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 5),
          pw.Text('Waktu ekspor: $stamp',
            style: const pw.TextStyle(fontSize: 9)),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headers: ['Ringkasan', 'Nilai'],
            data: [
              ['Transaksi tercatat', '${sales.length}'],
              ['Total penjualan tercatat', _reportMoney(totalSales)],
              ['Jumlah produk', '${products.length}'],
              ['Total pengeluaran tercatat', _reportMoney(totalExpenses)],
            ],
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey100),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellStyle: const pw.TextStyle(fontSize: 9),
          ),
          pw.SizedBox(height: 18),
          pw.Text('Daftar Penjualan',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: ['No. Transaksi', 'Tanggal', 'Pelanggan', 'Total'],
            data: sales.map((r) => [
              _reportText(r['sale_no']), _reportText(r['sale_time']),
              _reportText(r['customer_name']), _reportMoney(r['total']),
            ]).toList(),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey100),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
            cellStyle: const pw.TextStyle(fontSize: 7),
          ),
          pw.SizedBox(height: 18),
          pw.Text('Daftar Pengeluaran',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: ['Tanggal', 'Kategori', 'Catatan', 'Jumlah'],
            data: expenses.map((r) => [
              _reportText(r['expense_date']), _reportText(r['category']),
              _reportText(r['note']), _reportMoney(r['amount']),
            ]).toList(),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey100),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
            cellStyle: const pw.TextStyle(fontSize: 7),
          ),
        ],
      ));

      final bytes = await pdf.save();
      await FilePicker.platform.saveFile(
        fileName: 'colonel_pos_laporan_${DateTime.now().millisecondsSinceEpoch}.pdf',
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        bytes: Uint8List.fromList(bytes),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ekspor PDF gagal: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  Future<void> restore() async {
    if(working) return;
    final ok=await showDialog<bool>(
      context:context,
      builder:(_)=>AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        title: Text(
          AppLocalizations.t(
            'Restore database?',
            'Restore database?',
          ),
        ),
        content: Text(
          AppLocalizations.t(
            'Data saat ini akan diganti dengan isi file backup. Pastikan file berasal dari CP POS.',
            'Current data will be replaced with the contents of the backup file. Make sure the file comes from CP POS.',
          ),
        ),
        actions:[
          TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            AppLocalizations.t('Batal', 'Cancel'),
          ),
        ),
          FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(
            AppLocalizations.t('Restore', 'Restore'),
          ),
        ),
        ],
      ),
    );
    if(ok!=true) return;
    final result=await FilePicker.platform.pickFiles(type:FileType.custom,allowedExtensions:['json'],withData:true);
    if(result==null) return;
    setState(()=>working=true);
    try {
      final f=result.files.single;
      final raw=f.bytes!=null ? utf8.decode(f.bytes!) : await File(f.path!).readAsString();
      final decoded=jsonDecode(raw);
      if(decoded is! Map<String,dynamic>) throw Exception(AppLocalizations.t('File backup tidak valid.', 'Invalid backup file.'));
      await DB.restoreBackup(decoded);
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            AppLocalizations.t(
              'Restore berhasil.',
              'Restore completed successfully.',
            ),
          ),
        ));
        Navigator.pop(context);
      }
    } catch(e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            AppLocalizations.t(
              'Restore gagal: $e',
              'Restore failed: $e',
            ),
          ),
        ));
    } finally {
      if(mounted) setState(()=>working=false);
    }
  }

  Future<void> restoreFromGoogleDrive() async {
    if (working) return;
    setState(() => working = true);
    try {
      final backups = await GoogleDriveBackupService.listBackups();
      if (!mounted) return;
      if (backups.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.t('Tidak ada file backup JSON di folder Google Drive.', 'No JSON backups found in the Google Drive folder.'))),
        );
        return;
      }
      final selected = await showDialog<dynamic>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(AppLocalizations.t('Pilih backup Google Drive', 'Choose Google Drive backup')),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: backups.length,
              itemBuilder: (context, index) {
                final item = backups[index];
                final created = item.createdTime?.toLocal().toString().split('.').first ?? '';
                return ListTile(
                  leading: const Icon(Icons.cloud_download_rounded),
                  title: Text(item.name ?? 'backup.json', maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: Text(created),
                  onTap: () => Navigator.pop(dialogContext, item),
                );
              },
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(AppLocalizations.t('Batal', 'Cancel')))],
        ),
      );
      if (selected == null || !mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(AppLocalizations.t('Ganti seluruh data?', 'Replace all data?')),
          content: Text(AppLocalizations.t(
            'Data di perangkat akan diganti dengan backup Google Drive yang dipilih. Pastikan backup benar dan versi aplikasi sesuai.',
            'Data on this device will be replaced with the selected Google Drive backup. Make sure it is valid and compatible.',
          )),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(AppLocalizations.t('Batal', 'Cancel'))),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(AppLocalizations.t('Restore', 'Restore'))),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      final bytes = await GoogleDriveBackupService.downloadBackup(selected.id as String);
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map<String, dynamic>) {
        throw Exception(AppLocalizations.t('File backup tidak valid.', 'Invalid backup file.'));
      }
      await DB.restoreBackup(decoded);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.t('Restore Google Drive berhasil.', 'Google Drive restore completed.'))),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.t('Restore Google Drive gagal: $e', 'Google Drive restore failed: $e'))),
        );
      }
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppLocalizations.t(
            'Backup & Restore',
            'Backup & Restore',
          ),
        ),
      ),
      body:ListView(
        padding:const EdgeInsets.all(16),
        children:[
          Card(
            child:Padding(
              padding:const EdgeInsets.all(18),
              child:Column(
                crossAxisAlignment:CrossAxisAlignment.start,
                children:[
                  Text(
              AppLocalizations.t(
                'Backup & Restore Database',
                'Backup & Restore Database',
              ),
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
                  const SizedBox(height:8),
                  Text(
              AppLocalizations.t(
                'Backup menyimpan menu, pengguna, transaksi, detail transaksi dan stok. Restore mengganti seluruh data dengan file backup.',
                'Backup saves menus, users, transactions, transaction details, and inventory. Restore replaces all data with the backup file.',
              ),
            ),
                  const SizedBox(height:16),
                  Row(children:[
                    Expanded(child:FilledButton.icon(onPressed:working?null:backup,icon:const Icon(Icons.backup_rounded),label: Text(
                      AppLocalizations.t('BACKUP', 'BACKUP'),
                    ))),
                    const SizedBox(width:10),
                    Expanded(child:OutlinedButton.icon(onPressed:working?null:restore,icon:const Icon(Icons.restore_rounded),label: Text(
                      AppLocalizations.t('RESTORE', 'RESTORE'),
                    ))),
                  ]),
                  const SizedBox(height:10),
                  SizedBox(
  width: double.infinity,
  child: FilledButton.icon(
    style: FilledButton.styleFrom(
  backgroundColor: const Color(0xFF1877D2),
  foregroundColor: Colors.white,
  minimumSize: const Size.fromHeight(58),
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 0.4),
  elevation: 2,
),
    onPressed: working ? null : backupToGoogleDrive,
    icon: const Icon(Icons.cloud_upload_rounded),
    label: Text(AppLocalizations.t('BACKUP KE GOOGLE DRIVE', 'BACKUP TO GOOGLE DRIVE')),
  ),
),
const SizedBox(height: 10),
SizedBox(
  width: double.infinity,
  child: OutlinedButton.icon(
    onPressed: working ? null : restoreFromGoogleDrive,
    icon: const Icon(Icons.cloud_download_rounded),
    label: Text(AppLocalizations.t('RESTORE DARI GOOGLE DRIVE', 'RESTORE FROM GOOGLE DRIVE')),
    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(54)),
  ),
),
const SizedBox(height: 10),
Row(
  children: [
    Expanded(
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
  backgroundColor: const Color(0xFF16A34A),
  foregroundColor: Colors.white,
  minimumSize: const Size(0, 68),
  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.2),
  elevation: 2,
),
        onPressed: working ? null : exportExcelReport,
        icon: const Icon(Icons.table_chart_rounded),
        label: const Text('EXPORT TO EXCELL'),
      ),
    ),
    const SizedBox(width: 10),
    Expanded(
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
  backgroundColor: const Color(0xFFDC2626),
  foregroundColor: Colors.white,
  minimumSize: const Size(0, 68),
  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.2),
  elevation: 2,
),
        onPressed: working ? null : exportPdfReport,
        icon: const Icon(Icons.picture_as_pdf_rounded),
        label: const Text('EXPORT PDF'),
      ),
    ),
  ],
),
                ],
              ),
            ),
          ),
          const SizedBox(height:10),
          Text(
          AppLocalizations.t(
            'Simpan file backup di lokasi aman sebelum melakukan restore.',
            'Save the backup file in a secure location before performing a restore.',
          ),
          style: const TextStyle(
            color: Color(0xFF6F7177),
            fontSize: 12,
          ),
        ),
          const CopyrightFooter(),
        ],
      ),
    );
  }
}

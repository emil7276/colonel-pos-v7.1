import 'package:audioplayers/audioplayers.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants.dart';
import '../../core/app_localizations.dart';
import '../../core/utils.dart';
import '../../data/database.dart';
import '../../models/models.dart';
import '../../services/receipt_service.dart';
import '../../services/quote_service.dart';
class PosPage extends StatefulWidget {
  final String cashier;
  final ValueChanged<String>? onTransactionSuccess;

  const PosPage({
    super.key,
    required this.cashier,
    this.onTransactionSuccess,
  });

  @override
  State<PosPage> createState() =>
      PosPageState();
}
class PosPageState extends State<PosPage> {
  List<Product> products = [];
  final List<CartLine> cart = [];

  String category = 'Semua';
  int discount = 0;
  String customerType = 'Retail';
  final TextEditingController customerNameController = TextEditingController();
  final TextEditingController customerPhoneController = TextEditingController();
  final TextEditingController searchController = TextEditingController();


  String searchQuery = '';
  bool saveCustomer = false;

  @override
  void dispose() {
    customerNameController.dispose();
    customerPhoneController.dispose();
    searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final raw = await DB.products();

      if (!mounted) return;

      setState(() {
        products = raw
            .map(Product.fromMap)
            .where((p) => p.active)
            .toList();
      });

      // If stock changed while a product was
      // already in the cart, adjust cart quantity.
      for (final line in cart) {
        final fresh = products.where(
          (p) => p.id == line.product.id,
        );

        if (fresh.isNotEmpty &&
            line.qty > fresh.first.stock) {
          line.qty = fresh.first.stock;
        }
      }

      cart.removeWhere(
        (line) => line.qty <= 0,
      );

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.t('Gagal memuat stok: $e', 'Failed to load stock: $e'),
          ),
        ),
      );
    }
  }

  List<String> get categories {
    final x = <String>{'Semua'};
    x.addAll(
      products.map((p) => p.category),
    );
    return x.toList();
  }

  int get subtotal => cart.fold(
        0,
        (sum, x) =>
            sum + x.product.price * x.qty,
      );

  int get total =>
      (subtotal - discount)
          .clamp(0, 1 << 31);

  int get totalItems =>
      cart.fold(0, (sum, line) => sum + line.qty);

  void add(Product p) {
    final found = cart.where(
      (x) => x.product.id == p.id,
    );

    if (found.isEmpty) {
      if (p.stock <= 0) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          SnackBar(
            content:
                Text(AppLocalizations.t('Stok ${p.name} habis.', 'Stock ${p.name} is out.')),
          ),
        );
        return;
      }

      setState(() {
        cart.add(CartLine(p, 1));
      });
    } else {
      final line = found.first;

      if (line.qty >= p.stock) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.t('Stok ${p.name} hanya ${p.stock}.', 'Only ${p.stock} ${p.name} in stock.'),
            ),
          ),
        );
        return;
      }

      setState(() => line.qty++);
    }
  }

  void minus(CartLine line) {
    setState(() {
      line.qty--;

      if (line.qty <= 0) {
        cart.remove(line);
      }
    });
  }

  Future<void> discountDialog() async {
    final c = TextEditingController(
      text: discount == 0
          ? ''
          : discount.toString(),
    );

    final value =
        await showDialog<int>(
      context: context,
      builder: (_) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        title: Text(AppLocalizations.t('Diskon', 'Discount')),
        content: TextField(
          controller: c,
          keyboardType:
              TextInputType.number,
          decoration:
              InputDecoration(
            labelText:
                AppLocalizations.t('Nominal diskon', 'Discount amount'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(context),
            child: Text(AppLocalizations.t('Batal', 'Cancel')),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(
                context,
                int.tryParse(c.text) ??
                    0,
              );
            },
            child: Text(AppLocalizations.t('Simpan', 'Save')),
          ),
        ],
      ),
    );

    if (value != null) {
      setState(() {
        discount = value.clamp(
          0,
          subtotal,
        );
      });
    }
  }


  Future<void> customerDialog() async {
    final nameController =
        TextEditingController(text: customerNameController.text);
    final phoneController =
        TextEditingController(text: customerPhoneController.text);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        title: Text(AppLocalizations.t('Simpan Pelanggan', 'Save Customer')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: AppLocalizations.t('Nama pelanggan', 'Customer name'),
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: AppLocalizations.t('Nomor HP', 'Phone number'),
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.t('Batal', 'Cancel')),
          ),
          FilledButton(
            onPressed: () {
              if (nameController.text.trim().isEmpty) return;

              customerNameController.text = nameController.text.trim();
              customerPhoneController.text = phoneController.text.trim();

              Navigator.pop(context, true);
            },
            child: Text(AppLocalizations.t('Simpan', 'Save')),
          ),
        ],
      ),
    );

    if (result != true && mounted) {
      setState(() => saveCustomer = false);
    }

    nameController.dispose();
    phoneController.dispose();
  }

  Future<void> payLater() async {
    if (cart.isEmpty) return;

    String method = 'Tunai';
    final bankController =
        TextEditingController();

    DateTime? dueDate;

    final result =
        await showDialog<bool>(
      context: context,
      builder: (context) =>
          StatefulBuilder(
        builder: (
          context,
          setDialogState,
        ) {
          return AlertDialog(
            title:
                Text(
              AppLocalizations.t('Bayar Tunda', 'Pay Later'),
            ),
            content:
                SingleChildScrollView(
              child: Column(
                mainAxisSize:
                    MainAxisSize.min,
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.t('Total', 'Total') + ': ${rp(total)}',
                    style:
                        const TextStyle(
                      fontWeight:
                          FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(
                    height: 16,
                  ),
                  Text(
                    AppLocalizations.t('Metode pembayaran', 'Payment method'),
                    style:
                        TextStyle(
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                  const SizedBox(
                    height: 8,
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label:
                            Text(
                          AppLocalizations.t('Tunai', 'Cash'),
                        ),
                        selected:
                            method == 'Tunai',
                        onSelected: (_) {
                          setDialogState(
                            () => method = 'Tunai',
                          );
                        },
                      ),
                      ChoiceChip(
                        label:
                            Text(
                          'Transfer',
                        ),
                        selected:
                            method ==
                                'Transfer',
                        onSelected: (_) {
                          setDialogState(
                            () => method =
                                'Transfer',
                          );
                        },
                      ),
                    ],
                  ),
                  if (method ==
                      'Transfer') ...[
                    const SizedBox(
                      height: 12,
                    ),
                    TextField(
                      controller:
                          bankController,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.t('Transfer ke Bank', 'Bank transfer'),
                        hintText:
                            AppLocalizations.t('Contoh: BCA', 'Example: BCA'),
                        prefixIcon:
                            Icon(
                          Icons
                              .account_balance,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(
                    height: 12,
                  ),
                  Text(
                    AppLocalizations.t('Tgl Jatuh Tempo (opsional)', 'Due date (optional)'),
                    style:
                        TextStyle(
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                  const SizedBox(
                    height: 8,
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          dueDate == null
                              ? AppLocalizations.t('Tidak diisi', 'Not set')
                              : '${dueDate!.day.toString().padLeft(2, '0')}/'
                                '${dueDate!.month.toString().padLeft(2, '0')}/'
                                '${dueDate!.year}',
                        ),
                      ),
                      IconButton(
                        icon:
                            const Icon(
                          Icons
                              .calendar_month,
                        ),
                        onPressed:
                            () async {
                          final picked =
                              await showDatePicker(
                            context:
                                context,
                            initialDate:
                                dueDate ??
                                    DateTime.now(),
                            firstDate:
                                DateTime.now(),
                            lastDate:
                                DateTime(
                              2100,
                            ),
                          );

                          if (picked !=
                              null) {
                            setDialogState(
                              () =>
                                  dueDate =
                                      picked,
                            );
                          }
                        },
                      ),
                      if (dueDate !=
                          null)
                        IconButton(
                          icon:
                              const Icon(
                            Icons.clear,
                          ),
                          onPressed: () {
                            setDialogState(
                              () => dueDate =
                                  null,
                            );
                          },
                        ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.pop(
                  context,
                  false,
                ),
                child:
                    Text(
                  AppLocalizations.t('Batal', 'Cancel'),
                ),
              ),
              FilledButton(
                onPressed: () {
                  if (method ==
                          'Transfer' &&
                      bankController
                          .text
                          .trim()
                          .isEmpty) {
                    return;
                  }

                  Navigator.pop(
                    context,
                    true,
                  );
                },
                child:
                    Text(
                  AppLocalizations.t('Simpan', 'Save'),
                ),
              ),
            ],
          );
        },
      ),
    );

    if (result != true) {
      bankController.dispose();
      return;
    }

    String dueDateText = '';

    if (dueDate != null) {
      dueDateText =
          '${dueDate!.year.toString().padLeft(4, '0')}-'
          '${dueDate!.month.toString().padLeft(2, '0')}-'
          '${dueDate!.day.toString().padLeft(2, '0')}';
    }

    try {
      final id =
          await DB.createSale(
        cashier:
            widget.cashier,
        customerName:
            customerNameController
                .text,
        customerPhone:
            customerPhoneController
                .text,
        customerType:
            customerType,
        items: cart,
        subtotal:
            subtotal,
        discount:
            discount,
        total:
            total,
        cash: 0,
        change: 0,
        payment:
            'Bayar Tunda',
        transferBank:
            method ==
                    'Transfer'
                ? bankController
                    .text
                    .trim()
                : '',
        dueDate:
            dueDateText,
      );

      final db =
          await DB.database;

      final rows =
          await db.query(
        'sales',
        where: 'id=?',
        whereArgs: [id],
        limit: 1,
      );

      bankController
          .dispose();

      if (!mounted) return;

      setState(() {
        cart.clear();
        discount = 0;

        if (!saveCustomer) {
          customerNameController
              .clear();
          customerPhoneController
              .clear();
        }

        saveCustomer = false;
        customerType =
            'Retail';
      });

      await load();

      if (rows.isEmpty) {
        return;
      }

      final sale =
          SaleModel.fromMap(
        rows.first,
      );

      // Cetak otomatis mengikuti setting Printer.
      if (await printerAutoPrint()) {
        try {
          await printReceipt(
            sale,
          );
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger
                    .of(context)
                .showSnackBar(
              SnackBar(
                content: Text(
                  AppLocalizations.t(
                    'Transaksi tersimpan, tetapi cetak otomatis gagal: $e',
                    'Transaction saved, but automatic printing failed: $e',
                  ),
                ),
              ),
            );
          }
        }
      }

      if (!mounted) return;

      await showDialog(
        context: context,
        builder: (_) =>
            AlertDialog(
          title:
              Text(
            AppLocalizations.t('Transaksi Berhasil', 'Transaction Successful'),
          ),
          content: Text(
            '${sale.no}\n'
            'Total ${rp(sale.total)}\n'
            AppLocalizations.t('Pembayaran: Bayar Tunda', 'Payment: Pay Later'),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(
                context,
              ),
              child:
                  Text(
                AppLocalizations.t('Tutup', 'Close'),
              ),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(
                  context,
                );

                try {
                  await printReceipt(
                    sale,
                  );
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger
                            .of(context)
                        .showSnackBar(
                      SnackBar(
                        content: Text(
                          AppLocalizations.t('Gagal mencetak: $e', 'Failed to print: $e'),
                        ),
                      ),
                    );
                  }
                }
              },
              child:
                  Text(
                AppLocalizations.t('Cetak', 'Print'),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      bankController.dispose();

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          duration:
              const Duration(
            seconds: 5,
          ),
          content: Text(
            AppLocalizations.t('Transaksi Bayar Tunda gagal diproses:\n$e', 'Pay Later transaction failed to process:\n$e'),
          ),
        ),
      );
    }
  }

  Future<void> payment() async {
    if (cart.isEmpty) return;

    final cashController =
        TextEditingController();

    String method = 'Tunai';

    final result =
        await showDialog<
            Map<String, dynamic>>(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (
            context,
            setDialog,
          ) {
            final cash =
                int.tryParse(
                      cashController
                          .text,
                    ) ??
                    0;

            final change =
                method == 'Tunai'
                    ? cash - total
                    : 0;

            return AlertDialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              title: Text(AppLocalizations.t('Pembayaran', 'Payment')),
              content: Column(
                mainAxisSize:
                    MainAxisSize.min,
                children: [
                  Text(
                    AppLocalizations.t('TOTAL', 'TOTAL') + ' ${rp(total)}',
                    style:
                        const TextStyle(
                      fontSize: 20,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                  const SizedBox(
                    height: 15,
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final x in const [
                          'Tunai',
                          'QRIS',
                          'Transfer',
                          'Wallet (Platform)',
                          'Bayar Tunda',
                        ])
                          ChoiceChip(
                            label: Text(AppLocalizations.t(x == 'Tunai' ? 'Tunai' : x == 'Bayar Tunda' ? 'Bayar Tunda' : x, x == 'Tunai' ? 'Cash' : x == 'Bayar Tunda' ? 'Pay Later' : x)),
                            selected: method == x,
                            onSelected: (_) {
                                    if (x == 'Bayar Tunda') {
                                      Navigator.pop(
                                        context,
                                        {'method': 'Bayar Tunda'},
                                      );
                                      return;
                                    }
                                    setDialog(() => method = x);
                                  },
                            selectedColor: goldSoft,
                            labelStyle: TextStyle(
                              color: method == x ? red : ink,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                            side: BorderSide(
                              color: method == x ? red : line,
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                  ),
                  if (method ==
                      'Tunai') ...[
                    const SizedBox(
                      height: 10,
                    ),
                    TextField(
                      controller:
                          cashController,
                      keyboardType:
                          TextInputType
                              .number,
                      onChanged: (_) =>
                          setDialog(
                        () {},
                      ),
                      decoration:
                          InputDecoration(
                        labelText: AppLocalizations.t('Uang diterima', 'Cash received'),
                      ),
                    ),
                    const SizedBox(
                      height: 8,
                    ),
                    Text(
                      change >= 0
                          ? AppLocalizations.t('Kembalian ', 'Change ') + '${rp(change)}'
                          : AppLocalizations.t('Uang kurang ', 'Short by ') + '${rp(-change)}',
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () =>
                      Navigator.pop(
                    context,
                  ),
                  child: Text(AppLocalizations.t('Batal', 'Cancel')),
                ),
                FilledButton(
                  onPressed: () {
                    final c =
                        int.tryParse(
                              cashController
                                  .text,
                            ) ??
                            0;

                    if (method ==
                            'Tunai' &&
                        c < total) {
                      ScaffoldMessenger
                              .of(context)
                          .showSnackBar(
                        SnackBar(
                          content: Text(AppLocalizations.t('Uang diterima belum cukup.', 'Cash received is not enough.'),
                          ),
                        ),
                      );
                      return;
                    }

                    Navigator.pop(
                      context,
                      {
                        'method': method,
                        'cash':
                            method ==
                                    'Tunai'
                                ? c
                                : total,
                        'change':
                            method ==
                                    'Tunai'
                                ? c - total
                                : 0,
                      },
                    );
                  },
                  child: Text(AppLocalizations.t('PROSES', 'PROCESS')),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null) return;

    if (result['method'] == 'Bayar Tunda') {
      await payLater();
      return;
    }

    try {
      final id = await DB.createSale(
        cashier: widget.cashier,
        customerName: customerNameController.text,
        customerPhone: customerPhoneController.text,
        customerType: customerType,
        items: cart,
        subtotal: subtotal,
        discount: discount,
        total: total,
        cash:
            result['cash'] as int,
        change:
            result['change'] as int,
        payment:
            result['method'] as String,
      );

    final tingPlayer = AudioPlayer();
    await tingPlayer.play(
      AssetSource('audio/transaction_success_ting_short.wav'),
    );
    Future.delayed(
      const Duration(milliseconds: 1200),
      () => tingPlayer.dispose(),
    );

    // Transaksi sudah berhasil tersimpan.
      // Quote tidak memengaruhi perhitungan transaksi.
      try {
        final quote = await QuoteService.nextQuote();
        if (mounted) {
          widget.onTransactionSuccess?.call(quote);
        }
      } catch (_) {
        // Jika quote gagal ditampilkan, transaksi tetap dianggap berhasil.
      }

      final db = await DB.database;

      final rows = await db.query(
        'sales',
        where: 'id=?',
        whereArgs: [id],
        limit: 1,
      );

      if (!mounted) return;

      setState(() {
        cart.clear();
        discount = 0;

        if (!saveCustomer) {
          customerNameController.clear();
          customerPhoneController.clear();
        }

        saveCustomer = false;
        customerType = 'Retail';
      });

      await load();

      if (rows.isNotEmpty) {
        final sale =
            SaleModel.fromMap(
          rows.first,
        );

        if (await printerAutoPrint()) {
          await printReceipt(sale);
        }

        await showDialog(
          context: context,
          builder: (_) =>
              AlertDialog(
                insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            title: Text(
              AppLocalizations.t('Transaksi Berhasil', 'Transaction Successful'),
            ),
            content: Text(
              '${sale.no}\n'
              'Total ${rp(sale.total)}',
            ),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.pop(
                  context,
                ),
                child:
                    Text(AppLocalizations.t('Tutup', 'Close')),
              ),
              FilledButton(
                onPressed: () async {
                  Navigator.pop(
                    context,
                  );

                  await printReceipt(
                    sale,
                  );
                },
                child:
                    Text(AppLocalizations.t('Cetak', 'Print')),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          duration:
              const Duration(
            seconds: 5,
          ),
          content: Text(
            AppLocalizations.t('Transaksi gagal diproses:\n$e', 'Transaction failed to process:\n$e'),
          ),
        ),
      );
    }
  }

  Future<void> showQris() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString('qris_image');
    final merchant = prefs.getString('qris_merchant') ?? '';

    if (path == null || path.isEmpty || !File(path).existsSync()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.t('QRIS belum diatur oleh Administrator.', 'QRIS has not been configured by the Administrator.')),
        ),
      );
      return;
    }

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(18),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(Icons.qr_code_2_rounded, color: red),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'QRIS Pembayaran',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                if (merchant.trim().isNotEmpty) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      merchant,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: inkMuted,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                Flexible(
                  child: InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 4,
                    child: Image.file(
                      File(path),
                      fit: BoxFit.contain,
                      width: double.infinity,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(AppLocalizations.t('Tutup', 'Close')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = products.where((p) {
      final categoryMatch =
          category == 'Semua' || p.category == category;
      final query = searchQuery.trim().toLowerCase();
      final searchMatch = query.isEmpty ||
          p.name.toLowerCase().contains(query);
      return categoryMatch && searchMatch;
    }).toList();

    return LayoutBuilder(
      builder: (context, c) {
        final tablet = c.maxWidth >= 700;
        final columns = tablet ? 4 : 2;

        final productGrid = Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 2, 4, 7),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: searchController,
                      onChanged: (value) {
                        setState(() => searchQuery = value);
                      },
                      decoration: InputDecoration(
                        hintText: AppLocalizations.t('Cari menu...', 'Search menu...'),
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: searchQuery.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  searchController.clear();
                                  setState(() => searchQuery = '');
                                },
                              ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  Text(
                    '${filtered.length} ${AppLocalizations.t('menu', 'items')}',
                    style: const TextStyle(color: inkMuted, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 2),
                itemCount: categories.length,
                separatorBuilder: (_, __) => Container(
                  width: 1,
                  height: 28,
                  color: Colors.black26,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                ),
                itemBuilder: (_, i) {
                  final x = categories[i];
                  final selected = category == x;
                  return InkWell(
                    
                    onTap: () => setState(() => category = x),
                    child: Container(
                      
                      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: selected ? red : Colors.transparent,
                        
                        
                        
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (selected) ...[
                            const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                            const SizedBox(width: 5),
                          ],
                          Text(
                              x == 'Semua' ? AppLocalizations.t('Semua', 'All') : x,
                            style: TextStyle(
                              color: selected ? Colors.white : Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              decoration: selected
                                  ? TextDecoration.none
                                  : TextDecoration.none,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: tablet ? 2.05 : 1.60,
                ),
                itemCount: filtered.length,
                itemBuilder: (_, i) {
                  final p = filtered[i];
                  return Card(
                    color: Colors.white,
                    elevation: 5,
                    shadowColor: gold.withValues(alpha: 0.38),
                    shape: RoundedRectangleBorder(
                      
                      side: BorderSide(
                        color: goldDeep,
                        width: 1.1,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => add(p),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [

                            Text(
                              p.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                color: Colors.black,
                                height: 1.0,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              rp(p.price),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                                color: Colors.red,
                                height: 1.0,
                              ),
                            ),
                            Builder(
                              builder: (_) {
                                final currentQty = cart
                                    .where((x) => x.product.id == p.id)
                                    .fold<int>(0, (sum, x) => sum + x.qty);

                                return Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    IconButton(
                                      onPressed: currentQty > 0
                                          ? () {
                                              final found = cart.firstWhere(
                                                (x) => x.product.id == p.id,
                                              );
                                              minus(found);
                                            }
                                          : null,
                                      icon: const Icon(
                                        Icons.remove_circle,
                                        color: Colors.red,
                                        size: 24,
                                      ),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    GestureDetector(
                                      onTap: () async {
                                        final c = TextEditingController(
                                          text: currentQty.toString(),
                                        );

                                        final qty = await showDialog<int>(
                                          context: context,
                                          builder: (_) => AlertDialog(
                                            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                                            title: Text(AppLocalizations.t('Jumlah', 'Quantity')),
                                            content: TextField(
                                              controller: c,
                                              keyboardType: TextInputType.number,
                                              autofocus: true,
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(context),
                                                child: Text(AppLocalizations.t('Batal', 'Cancel')),
                                              ),
                                              FilledButton(
                                                onPressed: () => Navigator.pop(
                                                  context,
                                                  int.tryParse(c.text),
                                                ),
                                                child: Text(AppLocalizations.t('OK', 'OK')),
                                              ),
                                            ],
                                          ),
                                        );

                                        if (qty != null && qty >= 0) {
                                          setState(() {
                                            final found = cart.where(
                                              (x) => x.product.id == p.id,
                                            );

                                            if (qty == 0) {
                                              cart.removeWhere(
                                                (x) => x.product.id == p.id,
                                              );
                                            } else if (found.isEmpty) {
                                              cart.add(CartLine(p, qty));
                                            } else {
                                              found.first.qty = qty;
                                            }
                                          });
                                        }
                                      },
                                      child: Text(
                                        '$currentQty',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () => add(p),
                                      icon: const Icon(
                                        Icons.add_circle,
                                        color: Colors.green,
                                        size: 24,
                                      ),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ],
                                );
                              },
                            ),
                            Text(
                              AppLocalizations.t('Stok', 'Stock') + ' ${p.stock}',
                              style: TextStyle(
                                color: p.stock <= 0 ? red : Colors.green.shade700,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );

        final cartPanel = Card(
          color: Colors.white,
          elevation: 8,
          shadowColor: gold.withValues(alpha: 0.48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: red.withValues(alpha: 0.45),
              width: 1.2,
            ),
          ),
          child: Column(
            children: [
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 10),
                leading: Icon(Icons.shopping_cart_rounded, color: red, size: 20),
                title: Text(AppLocalizations.t('Keranjang', 'Cart'), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: red)),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: gold.withValues(alpha: 0.18),
                              blurRadius: 7,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Autocomplete<String>(
                          optionsBuilder: (textEditingValue) {
                            if (textEditingValue.text.trim().isEmpty) {
                              return const Iterable<String>.empty();
                            }
                            return DB.customerSuggestions(
                              textEditingValue.text.trim(),
                            );
                          },
                          onSelected: (selection) {
                            customerNameController.text = selection;
                          },
                          fieldViewBuilder: (
                            context,
                            textEditingController,
                            focusNode,
                            onFieldSubmitted,
                          ) {
                            return TextField(
                              controller: textEditingController,
                              focusNode: focusNode,
                              textInputAction: TextInputAction.done,
                              onChanged: (v) {
                                customerNameController.text = v;
                              },
                              decoration: InputDecoration(
                                labelText: AppLocalizations.t('Nama Pelanggan', 'Customer Name'),
                                hintText: AppLocalizations.t('Pelanggan umum / nama pelanggan tetap', 'General customer / regular customer'),
                                prefixIcon: Icon(Icons.person_outline_rounded),
                              ),
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 2),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Row(
                        children: [
                          Text(
                            AppLocalizations.t('Simpan pelanggan', 'Save customer'),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '$totalItems ${AppLocalizations.t('item', 'items')}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                      value: saveCustomer,
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (value) async {
                        if (value == true) {
                          setState(() => saveCustomer = true);
                          await customerDialog();
                        } else {
                          setState(() => saveCustomer = false);
                        }
                      },
                    ),
                    const SizedBox(height: 2),
                    SizedBox(
                      height: 28,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: 3,
                        separatorBuilder: (_, __) => const SizedBox(width: 4),
                        itemBuilder: (_, i) {
                          const types = ['Retail', 'Online', 'Grosir/Reseller'];
                          final type = types[i];
                          final selected = customerType == type;
                          return Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: (selected ? red : navy).withValues(alpha: 0.18),
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: ChoiceChip(
                              label: Text(type),
                            selected: selected,
                            onSelected: (_) => setState(() => customerType = type),
                            selectedColor: redSoft,
                            labelStyle: TextStyle(
                              color: selected ? red : ink,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                            side: BorderSide(color: selected ? red : line),
                            visualDensity: VisualDensity.compact,
                          ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: cart.isEmpty
                    ? Center(child: Text(AppLocalizations.t('Belum ada item', 'No items yet')))
                    : ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: cart.length,
                        itemBuilder: (_, i) {
                          final line = cart[i];
                          return ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                            title: Text(
                              line.product.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                            subtitle: Text(rp(line.product.price), style: const TextStyle(fontSize: 11)),
                            leading: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                  onPressed: () => minus(line),
                                  icon: const Icon(Icons.remove_circle_outline, size: 21),
                                ),
                                GestureDetector(
                                  onTap: () async {
                                    final c = TextEditingController(
                                      text: line.qty.toString(),
                                    );

                                    final qty = await showDialog<int>(
                                      context: context,
                                      builder: (_) => AlertDialog(
                                        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                                        title: Text(AppLocalizations.t('Jumlah', 'Quantity')),
                                        content: TextField(
                                          controller: c,
                                          keyboardType: TextInputType.number,
                                          autofocus: true,
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context),
                                            child: Text(AppLocalizations.t('Batal', 'Cancel')),
                                          ),
                                          FilledButton(
                                            onPressed: () => Navigator.pop(
                                              context,
                                              int.tryParse(c.text),
                                            ),
                                            child: Text(AppLocalizations.t('OK', 'OK')),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (qty != null && qty > 0) {
                                      setState(() {
                                        line.qty = qty;
                                      });
                                    }
                                  },
                                  child: Text(
                                    '${line.qty}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                  onPressed: () => add(line.product),
                                  icon: const Icon(Icons.add_circle_outline, size: 21),
                                ),
                              ],
                            ),
                            trailing: Text(
                              rp(line.product.price * line.qty),
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                            ),
                          );
                        },
                      ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
                child: Column(
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(AppLocalizations.t('Subtotal', 'Subtotal')), Text(rp(subtotal))]),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(AppLocalizations.t('Diskon', 'Discount')), Text(rp(discount))]),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('TOTAL', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                        Text(rp(total), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: red)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: discountDialog,
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: red, width: 1.5),
                            ),
                            child: Text(AppLocalizations.t('Diskon', 'Discount')),
                          ),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          flex: 2,
                          child: FilledButton(
                            onPressed: cart.isEmpty ? null : payment,
                            style: FilledButton.styleFrom(
                              backgroundColor: red,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: const BorderSide(color: red, width: 1.5),
                              ),
                            ),
                            child: Text(AppLocalizations.t('BAYAR', 'PAY')),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

        if (tablet) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(
              children: [
                Expanded(flex: 7, child: productGrid),
                const SizedBox(width: 10),
                Expanded(flex: 3, child: cartPanel),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
          child: Column(
            children: [
              Expanded(flex: 7, child: productGrid),
              SizedBox(height: cart.isEmpty ? 250 : 305, child: cartPanel),
            ],
          ),
        );
      },
    );
  }
}

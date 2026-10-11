import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/app_localizations.dart';
import '../../data/database.dart';
import '../../models/models.dart';
class StockPage
    extends StatefulWidget {
  const StockPage({super.key});

  @override
  State<StockPage> createState() =>
      _StockPageState();
}
class _StockPageState
    extends State<StockPage> {
  List<Product> products = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final raw =
        await DB.products();

    if (!mounted) return;

    setState(() {
      products = raw
          .map(Product.fromMap)
          .toList();
    });
  }

  Future<void> add(
    Product p,
  ) async {
    final q =
        TextEditingController(text: '1');

    final note =
        TextEditingController();

    int qty = 1;

    await showDialog(
      context: context,
      builder: (_) =>
          StatefulBuilder(
        builder: (context, setDialogState) =>
            AlertDialog(
          title: Text(
            AppLocalizations.t('Stok Masuk • ', 'Stock In • ') + p.name,
          ),
          content: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip:
                        AppLocalizations.t('Kurangi jumlah', 'Decrease quantity'),
                    onPressed: qty > 1
                        ? () {
                            setDialogState(() {
                              qty--;
                              q.text =
                                  qty.toString();
                              q.selection =
                                  TextSelection
                                      .fromPosition(
                                TextPosition(
                                  offset:
                                      q.text.length,
                                ),
                              );
                            });
                          }
                        : null,
                    icon:
                        const Icon(
                      Icons
                          .remove_circle_outline,
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: q,
                      keyboardType:
                          TextInputType.number,
                      textAlign:
                          TextAlign.center,
                      decoration:
                          InputDecoration(
                        labelText:
                            AppLocalizations.t('Jumlah', 'Quantity'),
                      ),
                      onChanged: (value) {
                        final parsed =
                            int.tryParse(
                              value,
                            );

                        setDialogState(() {
                          if (parsed != null &&
                              parsed > 0) {
                            qty = parsed;
                          }
                        });
                      },
                    ),
                  ),
                  IconButton(
                    tooltip:
                        AppLocalizations.t('Tambah jumlah', 'Increase quantity'),
                    onPressed: () {
                      setDialogState(() {
                        qty++;
                        q.text =
                            qty.toString();
                        q.selection =
                            TextSelection
                                .fromPosition(
                          TextPosition(
                            offset:
                                q.text.length,
                          ),
                        );
                      });
                    },
                    icon:
                        const Icon(
                      Icons
                          .add_circle_outline,
                    ),
                  ),
                ],
              ),
              TextField(
                controller: note,
                decoration:
                    InputDecoration(
                  labelText:
                      AppLocalizations.t('Keterangan', 'Notes'),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(
                context,
              ),
              child:
                  Text(
                AppLocalizations.t('Batal', 'Cancel'),
              ),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  final parsed =
                      int.tryParse(
                    q.text.trim(),
                  );

                  if (parsed == null ||
                      parsed <= 0) {
                    return;
                  }

                  await DB.addStock(
                    p.id,
                    parsed,
                    note.text
                            .trim()
                            .isEmpty
                        ? 'Stok masuk'
                        : note.text
                            .trim(),
                  );

                  if (context
                      .mounted) {
                    Navigator.pop(
                      context,
                    );
                  }
                } catch (e) {
                  if (context
                      .mounted) {
                    ScaffoldMessenger
                            .of(context)
                        .showSnackBar(
                      SnackBar(
                        content: Text(
                          AppLocalizations.t('Gagal menambah stok: ', 'Failed to add stock: ') + e.toString(),
                        ),
                      ),
                    );
                  }
                }
              },
              child:
                  Text(
                AppLocalizations.t('Tambah', 'Add'),
              ),
            ),
          ],
        ),
      ),
    );

    q.dispose();
    note.dispose();

    await load();
  }


  Future<void> reduce(Product p) async {
    if (p.stock <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.t('Stok sudah nol.', 'Stock is already zero.'),
          ),
        ),
      );
      return;
    }

    final q = TextEditingController(text: '1');
    final qty = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          AppLocalizations.t('Kurangi Stok • ', 'Stock Out • ') + p.name,
        ),
        content: TextField(
          controller: q,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: AppLocalizations.t(
              'Jumlah (maks. ${p.stock})',
              'Quantity (max. ${p.stock})',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(AppLocalizations.t('Batal', 'Cancel')),
          ),
          FilledButton(
            onPressed: () {
              final parsed = int.tryParse(q.text.trim());
              if (parsed == null || parsed <= 0 || parsed > p.stock) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(
                    content: Text(
                      AppLocalizations.t(
                        'Masukkan jumlah 1 sampai ${p.stock}.',
                        'Enter a quantity from 1 to ${p.stock}.',
                      ),
                    ),
                  ),
                );
                return;
              }
              Navigator.pop(dialogContext, parsed);
            },
            child: Text(AppLocalizations.t('Kurangi', 'Reduce')),
          ),
        ],
      ),
    );
    q.dispose();

    if (qty == null) return;

    try {
      await DB.reduceStock(p.id, qty);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.t(
              'Stok berhasil dikurangi.',
              'Stock reduced successfully.',
            ),
          ),
        ),
      );
      await load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.t('Gagal mengurangi stok: ', 'Failed to reduce stock: ') +
                e.toString(),
          ),
        ),
      );
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title:
            Text(AppLocalizations.t('Stok', 'Stock'))
      ),
      body: ListView(
        padding:
            const EdgeInsets.all(10),
        children:
            products.map((p) {
          return Card(
            child: ListTile(
              leading:
                  const Icon(
                Icons.inventory_2,
                color: red,
              ),
              title: Text(p.name),
              subtitle: Text(
                '${p.category} • ${AppLocalizations.t('Saldo stok', 'Stock balance')}',
              ),
              trailing: Row(
                mainAxisSize:
                    MainAxisSize.min,
                children: [
                  Text(
                    '${p.stock}',
                    style:
                        const TextStyle(
                      fontWeight:
                          FontWeight
                              .bold,
                      fontSize: 18,
                    ),
                  ),
                  IconButton(
                    onPressed: () =>
                        add(p),
                    icon:
                        const Icon(
                      Icons.add_box,
                    ),
                    tooltip:
                        AppLocalizations.t('Stok masuk', 'Stock in'),
                  ),
                  IconButton(
                    onPressed: p.stock > 0 ? () => reduce(p) : null,
                    icon: const Icon(Icons.remove_circle_outline),
                    tooltip: AppLocalizations.t('Kurangi stok', 'Stock out'),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

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
            AppLocalizations.t('Stok Masuk • ', 'Stock In • ')
            '${p.name}',
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
                          AppLocalizations.t('Gagal menambah stok: ', 'Failed to add stock: ')
                          '$e',
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
                '${p.category} • '
                AppLocalizations.t('Saldo stok', 'Stock balance'),
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
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

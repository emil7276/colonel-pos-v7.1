import 'package:flutter/material.dart';
import '../../core/constants.dart';
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
        TextEditingController();

    final note =
        TextEditingController();

    await showDialog(
      context: context,
      builder: (_) =>
          AlertDialog(
        title: Text(
          'Stok Masuk • '
          '${p.name}',
        ),
        content: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            TextField(
              controller: q,
              keyboardType:
                  TextInputType
                      .number,
              decoration:
                  const InputDecoration(
                labelText:
                    'Jumlah',
              ),
            ),
            TextField(
              controller: note,
              decoration:
                  const InputDecoration(
                labelText:
                    'Keterangan',
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
                const Text(
              'Batal',
            ),
          ),
          FilledButton(
            onPressed: () async {
              try {
                final qty =
                    int.tryParse(
                          q.text,
                        ) ??
                        0;

                await DB.addStock(
                  p.id,
                  qty,
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
                        'Gagal menambah stok: '
                        '$e',
                      ),
                    ),
                  );
                }
              }
            },
            child:
                const Text(
              'Tambah',
            ),
          ),
        ],
      ),
    );

    await load();
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text('Stok'),
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
                'Saldo stok',
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
                        'Stok masuk',
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

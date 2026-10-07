import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/app_localizations.dart';
import '../../core/utils.dart';
import '../../data/database.dart';
import '../../models/models.dart';

class MenuPage extends StatefulWidget {
  const MenuPage({super.key});

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  List<Product> products = [];
  String filterCategory = 'Semua';

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
        products = raw.map(Product.fromMap).toList();
        if (!categories.contains(filterCategory)) filterCategory = 'Semua';
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.t('Gagal memuat menu: $e', 'Failed to load menu: $e'))));
    }
  }

  List<String> get categories {
    final result = <String>{'Semua'};
    result.addAll(products.map((p) => p.category.trim()).where((x) => x.isNotEmpty));
    return result.toList();
  }

  Future<String?> _newCategoryDialog(BuildContext context) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        title: Text(AppLocalizations.t('Kategori Baru', 'New Category')),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: AppLocalizations.t('Nama kategori', 'Category Name'),
            hintText: AppLocalizations.t('Contoh: Paket, Snack, Minuman', 'Example: Combo, Snack, Drinks'),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(AppLocalizations.t('Batal', 'Cancel'))),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(dialogContext, name);
            },
            child: Text(AppLocalizations.t('Gunakan', 'Use')),
          ),
        ],
      ),
    );
    controller.dispose();
    return value;
  }

  Future<void> edit([Product? p]) async {
    final nameController = TextEditingController(text: p?.name ?? '');
    final priceController = TextEditingController(text: p?.price.toString() ?? '');
    final stockController = TextEditingController(text: p?.stock.toString() ?? '0');
    final availableCategories = categories.where((x) => x != 'Semua').toList();
    String selectedCategory = p?.category ?? (availableCategories.isNotEmpty ? availableCategories.first : 'Ayam');
    if (!availableCategories.contains(selectedCategory)) availableCategories.add(selectedCategory);
    bool active = p?.active ?? true;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialog) {
          return AlertDialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            title: Text(p == null ? AppLocalizations.t('Tambah Menu', 'Add Menu') : AppLocalizations.t('Edit Menu', 'Edit Menu')),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(labelText: AppLocalizations.t('Nama menu', 'Menu Name')),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: availableCategories.contains(selectedCategory) ? selectedCategory : null,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: AppLocalizations.t('Kategori', 'Category')),
                    items: [
                      ...availableCategories.map((category) => DropdownMenuItem<String>(
                            value: category,
                            child: Text(category, overflow: TextOverflow.ellipsis),
                          )),
                      const DropdownMenuItem<String>(
                        value: '__new__',
                        child: Row(
                          children: [
                            Icon(Icons.add_circle_outline, color: red, size: 20),
                            SizedBox(width: 8),
                            Text(AppLocalizations.t('Buat kategori baru', 'Create new category'), style: TextStyle(color: red, fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                    ],
                    onChanged: (value) async {
                      if (value == '__new__') {
                        final created = await _newCategoryDialog(context);
                        if (created != null && created.trim().isNotEmpty) {
                          final name = created.trim();
                          if (!availableCategories.contains(name)) availableCategories.add(name);
                          setDialog(() => selectedCategory = name);
                        }
                      } else if (value != null) {
                        setDialog(() => selectedCategory = value);
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: priceController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: AppLocalizations.t('Harga', 'Price')),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: stockController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: AppLocalizations.t('Stok awal', 'Initial Stock')),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: active,
                    onChanged: (v) => setDialog(() => active = v),
                    title: Text(AppLocalizations.t('Aktif', 'Active')),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Batal')),
              FilledButton(
                onPressed: () async {
                  try {
                    await DB.saveProduct(
                      id: p?.id,
                      name: nameController.text.trim(),
                      category: selectedCategory.trim(),
                      price: int.tryParse(priceController.text) ?? 0,
                      stock: int.tryParse(stockController.text) ?? 0,
                      active: active,
                    );
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                  } catch (e) {
                    if (!dialogContext.mounted) return;
                    ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content: Text(AppLocalizations.t('Gagal menyimpan menu: $e', 'Failed to save menu: $e'))));
                  }
                },
                child: Text(AppLocalizations.t('Simpan', 'Save')),
              ),
            ],
          );
        },
      ),
    );

    nameController.dispose();
    priceController.dispose();
    stockController.dispose();
    await load();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = filterCategory == 'Semua'
        ? products
        : products.where((p) => p.category == filterCategory).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.t('Menu & Harga', 'Menu & Prices')),
        actions: [
          IconButton(onPressed: () => edit(), tooltip: AppLocalizations.t('Tambah menu', 'Add menu'), icon: const Icon(Icons.add_rounded)),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 50,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 7),
              itemBuilder: (_, i) {
                final category = categories[i];
                final selected = filterCategory == category;
                return InkWell(
                  borderRadius: BorderRadius.circular(13),
                  onTap: () => setState(() => filterCategory = category),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: selected ? red : Colors.white,
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: selected ? red : line),
                    ),
                    child: Text(
                      category == 'Semua'
                          ? AppLocalizations.t('Semua', 'All')
                          : category,
                      style: TextStyle(
                        color: selected ? Colors.white : ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: load,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 2, 12, 24),
                itemCount: filtered.length,
                itemBuilder: (_, i) {
                  final p = filtered[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                      child: Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(color: redSoft, borderRadius: BorderRadius.circular(13)),
                            child: const Icon(Icons.fastfood_rounded, color: red, size: 22),
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                                const SizedBox(height: 3),
                                Text('${p.category}  •  ${rp(p.price)}  •  ${AppLocalizations.t('Stok', 'Stock')} ${p.stock}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: inkMuted, fontSize: 14)),
                              ],
                            ),
                          ),
                          Switch(
                            value: p.active,
                            onChanged: (v) async {
                              try {
                                await DB.saveProduct(id: p.id, name: p.name, category: p.category, price: p.price, stock: p.stock, active: v);
                                await load();
                              } catch (e) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.t('Gagal: $e', 'Failed: $e'))));
                              }
                            },
                          ),
                          IconButton(onPressed: () => edit(p), tooltip: AppLocalizations.t('Edit', 'Edit'), icon: const Icon(Icons.edit_rounded)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: red,
        foregroundColor: Colors.white,
        onPressed: () => edit(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tambah Menu'),
      ),
    );
  }
}

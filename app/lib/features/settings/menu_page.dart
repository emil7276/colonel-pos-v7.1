import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import '../../core/constants.dart';
import '../../core/widgets.dart';
import '../../core/app_localizations.dart';
import '../../core/utils.dart';
import '../../core/trial_service.dart';
import '../auth/trial_expired_page.dart';
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

  Future<String?> _scanBarcodeCamera() async {
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Pindai barcode produk'),
        content: SizedBox(width: 360, height: 360, child: MobileScanner(onDetect: (capture) {
          if (capture.barcodes.isEmpty) return;
          final value = capture.barcodes.first.rawValue?.trim();
          if (value != null && value.isNotEmpty && dialogContext.mounted) Navigator.of(dialogContext).pop(value);
        })),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Batal'))],
      ),
    );
  }

  Future<void> edit([Product? p]) async {
    final nameController = TextEditingController(text: p?.name ?? '');
    final barcodeController = TextEditingController(text: p?.barcode ?? '');
    final priceController = TextEditingController(text: p?.price.toString() ?? '');
    final stockController = TextEditingController(text: p?.stock.toString() ?? '0');
    String imagePath = p?.imagePath ?? '';
    final imagePicker = ImagePicker();
    final availableCategories = categories.where((x) => x != 'Semua').toList();
    String selectedCategory = p?.category ?? (availableCategories.isNotEmpty ? availableCategories.first : 'Ayam');
    if (!availableCategories.contains(selectedCategory)) availableCategories.add(selectedCategory);
    bool active = p?.active ?? true;

    Future<void> pickProductImage(StateSetter setDialog, ImageSource source) async {
      try {
        final picked = await imagePicker.pickImage(source: source, imageQuality: 82, maxWidth: 1400, maxHeight: 1400);
        if (picked == null) return;
        final appDir = await getApplicationDocumentsDirectory();
        final imageDir = Directory(path.join(appDir.path, 'product_images'));
        if (!await imageDir.exists()) await imageDir.create(recursive: true);
        final ext = path.extension(picked.path).toLowerCase();
        if (!['.jpg', '.jpeg', '.png', '.webp'].contains(ext)) {
          throw Exception('Format foto harus JPG, PNG, atau WebP.');
        }
        final target = path.join(imageDir.path, 'product_${DateTime.now().microsecondsSinceEpoch}$ext');
        await File(picked.path).copy(target);
        setDialog(() => imagePath = target);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal memilih foto: $e')));
      }
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialog) {
          return AlertDialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            title: Text(p == null ? AppLocalizations.t('Tambah Menu', 'Add Menu') : AppLocalizations.t('Edit Menu', 'Edit Menu')),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity, padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(border: Border.all(color: boxBorder), borderRadius: BorderRadius.circular(12)),
                    child: Column(children: [
                      if (imagePath.isNotEmpty && File(imagePath).existsSync())
                        ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(imagePath), height: 130, width: double.infinity, fit: BoxFit.cover))
                      else
                        const SizedBox(height: 44, child: Center(child: Icon(Icons.add_photo_alternate_outlined, size: 32))),
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, runSpacing: 4, alignment: WrapAlignment.center, children: [
                        OutlinedButton.icon(onPressed: () => pickProductImage(setDialog, ImageSource.gallery), icon: const Icon(Icons.photo_library_outlined), label: const Text('Galeri')),
                        OutlinedButton.icon(onPressed: () => pickProductImage(setDialog, ImageSource.camera), icon: const Icon(Icons.photo_camera_outlined), label: const Text('Kamera')),
                        if (imagePath.isNotEmpty) TextButton.icon(onPressed: () => setDialog(() => imagePath = ''), icon: const Icon(Icons.delete_outline), label: const Text('Hapus foto')),
                      ]),
                    ]),
                  ),
                  const SizedBox(height: 10),
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
                      DropdownMenuItem<String>(
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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: barcodeController,
                          textInputAction: TextInputAction.done,
                          decoration: const InputDecoration(
                            labelText: 'Barcode / kode barang (opsional)',
                            hintText: 'Masukkan kode barang',
                            prefixIcon: Icon(Icons.qr_code_2),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: IconButton.filledTonal(
                          tooltip: 'Scan barcode dengan kamera',
                          icon: const Icon(Icons.photo_camera_outlined),
                          onPressed: () async {
                            final code = await _scanBarcodeCamera();
                            if (code != null && code.trim().isNotEmpty) {
                              setDialog(() => barcodeController.text = code.trim());
                            }
                          },
                        ),
                      ),
                    ],
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
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Batal')),
              FilledButton(
                onPressed: () async {
                  try {
                    // Menu baru adalah titik mulai trial pertama.
                    // Mengedit menu yang sudah ada tidak memulai trial.
                    if (p == null) {
                      final trial = await TrialService.status();

                      if (trial == null) {
                        if (!dialogContext.mounted) return;

                        final choice = await showDialog<String>(
                          context: dialogContext,
                          builder: (choiceContext) => AlertDialog(
                            title: const Text('Pilih cara melanjutkan'),
                            content: const Text(
                              'Coba Gratis untuk mulai masa percobaan, '
                              'atau pilih Berlangganan / Beli untuk aktivasi.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(choiceContext, 'buy'),
                                child: const Text('Berlangganan / Beli'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(choiceContext, 'trial'),
                                child: const Text('Coba Gratis'),
                              ),
                            ],
                          ),
                        );

                        if (choice == 'buy') {
                          if (!dialogContext.mounted) return;

                          Navigator.pop(dialogContext);
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const ActivationPage(),
                            ),
                          );
                          return;
                        }

                        if (choice != 'trial') return;
                      } else if (!trial.active) {
                        if (!dialogContext.mounted) return;
                        Navigator.pop(dialogContext);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Masa trial telah berakhir. Aktivasi diperlukan.',
                            ),
                          ),
                        );
                        return;
                      }
                    }

                    await DB.saveProduct(
                      id: p?.id,
                      name: nameController.text.trim(),
                      category: selectedCategory.trim(),
                      price: int.tryParse(priceController.text) ?? 0,
                      stock: int.tryParse(stockController.text) ?? 0,
                      active: active,
                      imagePath: imagePath,
                      barcode: barcodeController.text.trim(),
                    );

                    if (p == null) {
                      final trial = await TrialService.status();
                      if (trial == null) {
                        await TrialService.startIfNeeded();
                      }
                    }

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
    barcodeController.dispose();
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
        title: Row(
          children: [
            const CpLogo(size: 30, rounded: false),
            const SizedBox(width: 10),
            Expanded(child: Text(AppLocalizations.t('Menu & Harga', 'Menu & Prices'))),
          ],
        ),
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
                            decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(13)),
                            child: Icon(Icons.fastfood_rounded, color: Theme.of(context).colorScheme.primary, size: 22),
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
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        onPressed: () => edit(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tambah Menu'),
      ),
    );
  }
}

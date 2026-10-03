import 'package:flutter/material.dart';
import '../../core/constants.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
class QrisPage
    extends StatefulWidget {
  const QrisPage({super.key});

  @override
  State<QrisPage> createState() =>
      _QrisPageState();
}
class _QrisPageState
    extends State<QrisPage> {
  String? imagePath;

  final merchant =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final p =
        await SharedPreferences
            .getInstance();

    imagePath =
        p.getString('qris_image');

    merchant.text =
        p.getString(
              'qris_merchant',
            ) ??
            '';

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> pick() async {
    try {
      final picker =
          ImagePicker();

      final image =
          await picker.pickImage(
        source:
            ImageSource.gallery,
        imageQuality: 90,
      );

      if (image == null) {
        return;
      }

      final dir =
          await getApplicationDocumentsDirectory();

      final target = File(
        path.join(
          dir.path,
          'qris_image.jpg',
        ),
      );

      await File(image.path)
          .copy(target.path);

      final p =
          await SharedPreferences
              .getInstance();

      await p.setString(
        'qris_image',
        target.path,
      );

      if (!mounted) return;

      setState(
        () => imagePath =
            target.path,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Gagal upload QRIS: $e',
          ),
        ),
      );
    }
  }

  Future<void> save() async {
    try {
      final p =
          await SharedPreferences
              .getInstance();

      await p.setString(
        'qris_merchant',
        merchant.text.trim(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Data QRIS disimpan.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Gagal menyimpan QRIS: '
            '$e',
          ),
        ),
      );
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final file =
        imagePath == null
            ? null
            : File(imagePath!);

    return Scaffold(
      appBar: AppBar(
        title:
            const Text('QRIS'),
      ),
      body: ListView(
        padding:
            const EdgeInsets.all(16),
        children: [
          TextField(
            controller: merchant,
            decoration:
                const InputDecoration(
              labelText:
                  'Nama Merchant',
              border:
                  OutlineInputBorder(),
            ),
          ),
          const SizedBox(
            height: 15,
          ),
          if (file != null &&
              file.existsSync())
            Container(
              constraints:
                  const BoxConstraints(
                maxHeight: 350,
              ),
              child:
                  Image.file(file),
            )
          else
            const Card(
              child: Padding(
                padding:
                    EdgeInsets.all(30),
                child: Center(
                  child: Text(
                    'Belum ada '
                    'gambar QRIS.',
                  ),
                ),
              ),
            ),
          const SizedBox(
            height: 15,
          ),
          OutlinedButton.icon(
            onPressed: pick,
            icon: const Icon(
              Icons.upload,
            ),
            label: const Text(
              'UPLOAD / GANTI QRIS',
            ),
          ),
          const SizedBox(
            height: 8,
          ),
          FilledButton(
            onPressed: save,
            style:
                FilledButton.styleFrom(
              backgroundColor: red,
            ),
            child:
                const Text('SIMPAN'),
          ),
        ],
      ),
    );
  }
}

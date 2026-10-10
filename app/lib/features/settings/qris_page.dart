import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/app_localizations.dart';
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
            AppLocalizations.t(
              'Gagal upload QRIS: $e',
              'Failed to upload QRIS: $e',
            ),
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
        SnackBar(
          content: Text(
            AppLocalizations.t(
              'Data QRIS disimpan.',
              'QRIS data saved.',
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.t(
              'Gagal menyimpan QRIS: $e',
              'Failed to save QRIS: $e',
            ),
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
                InputDecoration(
              labelText:
                  AppLocalizations.t(
                'Nama Merchant',
                'Merchant Name',
              ),
              border:
                  const OutlineInputBorder(),
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
            Card(
              child: Padding(
                padding:
                    const EdgeInsets.all(30),
                child: Center(
                  child: Text(
                    AppLocalizations.t(
                      'Belum ada gambar QRIS.',
                      'No QRIS image yet.',
                    ),
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
            label: Text(
              AppLocalizations.t(
                'UPLOAD / GANTI QRIS',
                'UPLOAD / CHANGE QRIS',
              ),
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
                Text(
              AppLocalizations.t(
                'SIMPAN',
                'SAVE',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

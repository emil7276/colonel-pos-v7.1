import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
class StorePage
    extends StatefulWidget {
  const StorePage({super.key});

  @override
  State<StorePage> createState() =>
      _StorePageState();
}
class _StorePageState
    extends State<StorePage> {
  final name =
      TextEditingController();

  final address =
      TextEditingController();

  final phone =
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

    name.text =
        p.getString(
              'store_name',
            ) ??
            'COLONEL FRIED CHICKEN';

    address.text =
        p.getString(
              'store_address',
            ) ??
            '';

    phone.text =
        p.getString(
              'store_phone',
            ) ??
            '';

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> save() async {
    try {
      final p =
          await SharedPreferences
              .getInstance();

      await p.setString(
        'store_name',
        name.text.trim(),
      );

      await p.setString(
        'store_address',
        address.text.trim(),
      );

      await p.setString(
        'store_phone',
        phone.text.trim(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.t('Identitas toko disimpan.', 'Store identity saved.'),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.t('Gagal menyimpan: $e', 'Failed to save: $e'),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppLocalizations.t('Identitas Toko', 'Store Identity'),
        ),
      ),
      body: ListView(
        padding:
            const EdgeInsets.all(16),
        children: [
          TextField(
            controller: name,
            decoration:
                InputDecoration(
              labelText:
                  AppLocalizations.t('Nama Toko', 'Store Name'),
              border:
                  OutlineInputBorder(),
            ),
          ),
          const SizedBox(
            height: 12,
          ),
          TextField(
            controller: address,
            decoration:
                InputDecoration(
              labelText: AppLocalizations.t('Alamat', 'Address'),
              border:
                  OutlineInputBorder(),
            ),
          ),
          const SizedBox(
            height: 12,
          ),
          TextField(
            controller: phone,
            keyboardType:
                TextInputType.phone,
            decoration:
                InputDecoration(
              labelText:
                  AppLocalizations.t('Nomor HP', 'Phone Number'),
              border:
                  OutlineInputBorder(),
            ),
          ),
          const SizedBox(
            height: 18,
          ),
          FilledButton(
            onPressed: save,
            style:
                FilledButton.styleFrom(
              backgroundColor: red,
            ),
            child:
                Text(AppLocalizations.t('SIMPAN', 'SAVE')),
          ),
        ],
      ),
    );
  }
}

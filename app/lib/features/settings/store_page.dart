import 'package:flutter/material.dart';
import '../../core/constants.dart';
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
        const SnackBar(
          content: Text(
            'Identitas toko disimpan.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Gagal menyimpan: $e',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Identitas Toko',
        ),
      ),
      body: ListView(
        padding:
            const EdgeInsets.all(16),
        children: [
          TextField(
            controller: name,
            decoration:
                const InputDecoration(
              labelText:
                  'Nama Toko',
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
                const InputDecoration(
              labelText: 'Alamat',
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
                const InputDecoration(
              labelText:
                  'Nomor HP',
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
                const Text('SIMPAN'),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/license/license_service.dart';
import '../../core/widgets.dart';

class ActivationPage extends StatefulWidget {
  const ActivationPage({super.key});

  @override
  State<ActivationPage> createState() => _ActivationPageState();
}

class _ActivationPageState extends State<ActivationPage> {
  final _codeController = TextEditingController();

  bool _loading = false;
  String? _error;
  String? _success;

  static const String _message =
      'Saya ingin aktivasi CP Colonel P.O.S\n\n'
      'Nama :\n'
      'Nama Usaha :\n'
      'Kota :';

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _activate() async {
    final code = _codeController.text.trim();

    if (code.isEmpty) {
      setState(() {
        _error = 'Masukkan kode aktivasi.';
        _success = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _success = null;
    });

    final ok = await LicenseService.saveLicense(code);

    if (!mounted) return;

    setState(() {
      _loading = false;
      if (ok) {
        _success =
            'Aktivasi berhasil. Tutup lalu buka kembali aplikasi.';
        _codeController.clear();
      } else {
        _error = LicenseService.lastError.isEmpty
            ? 'Kode aktivasi tidak valid.'
            : LicenseService.lastError;
      }
    });
  }

  Future<void> _openContact(Uri uri) async {
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Aplikasi kontak tidak dapat dibuka.'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Aplikasi kontak tidak dapat dibuka.'),
          ),
        );
      }
    }
  }

  Uri get _whatsappUri => Uri.parse(
        'https://wa.me/62895368910401'
        '?text=${Uri.encodeComponent(_message)}',
      );

  Uri get _emailUri => Uri(
        scheme: 'mailto',
        path: 'cp.colonel.pos@gmail.com',
        queryParameters: {
          'subject': 'Aktivasi CP Colonel P.O.S',
          'body': _message,
        },
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Card(
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CpLogo(size: 92),
                      const SizedBox(height: 20),
                      Text(
                        'Aktivasi Diperlukan',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Aktifkan CP Colonel P.O.S untuk melanjutkan '
                        'ke aplikasi.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 22),
                      TextField(
                        controller: _codeController,
                        enabled: !_loading,
                        decoration: const InputDecoration(
                          labelText: 'Kode Aktivasi',
                          hintText: 'Masukkan kode dari Admin',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.key_outlined),
                        ),
                        autocorrect: false,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _activate(),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _loading ? null : _activate,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                            ),
                            child: _loading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('AKTIVASI'),
                          ),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      if (_success != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _success!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 22),
                      const Text(
                        'Belum punya kode aktivasi? Hubungi Admin:',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () => _openContact(_whatsappUri),
                          icon: const Icon(Icons.chat_outlined),
                          label: const Text('WhatsApp Admin'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _openContact(_emailUri),
                          icon: const Icon(Icons.email_outlined),
                          label: const Text('cp.colonel.pos@gmail.com'),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Satu lisensi hanya berlaku untuk satu perangkat.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

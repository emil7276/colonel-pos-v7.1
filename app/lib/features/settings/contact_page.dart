import 'package:flutter/material.dart';
import '../../core/app_localizations.dart';
import '../../core/constants.dart';
import '../../core/widgets.dart';
import '../../core/license/license_service.dart';

class ContactPage extends StatefulWidget {
  const ContactPage({super.key});

  @override
  State<ContactPage> createState() => _ContactPageState();
}

class _ContactPageState extends State<ContactPage> {
  final _codeController = TextEditingController();
  bool _loading = false;
  String? _message;
  bool _success = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _activate() async {
    final code = _codeController.text.trim();

    if (code.isEmpty || _loading) {
      setState(() {
        _message = AppLocalizations.t(
          'Masukkan kode aktivasi terlebih dahulu.',
          'Enter an activation code first.',
        );
        _success = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _message = null;
    });

    try {
      final ok = await LicenseService.saveLicense(code);
      if (!mounted) return;

      setState(() {
        _success = ok;
        _message = ok
            ? AppLocalizations.t(
                'Aktivasi berhasil. Silakan tutup aplikasi, lalu buka kembali untuk melanjutkan penggunaan Colonel POS.',
                'Activation successful. Please close and reopen the app to continue using Colonel POS.',
              )
            : LicenseService.lastError;

        if (ok) _codeController.clear();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _success = false;
        _message = AppLocalizations.t(
          'Aktivasi gagal. Silakan coba kembali.',
          'Activation failed. Please try again.',
        );
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const CpLogo(size: 30, rounded: false),
            const SizedBox(width: 10),
            Expanded(
              child: Text(AppLocalizations.t('Hubungi Kami', 'Contact Us')),
            ),
          ],
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.support_agent_rounded,
                    size: 64,
                    color: colors.primary,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'CP COLONEL POS',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    AppLocalizations.t(
                      'Untuk perpanjangan dan pengembangan layanan hubungi:',
                      'For service renewal and development, please contact:',
                    ),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  SelectableText(
                    'cp.colonel.pos@gmail.com',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Divider(),
                  const SizedBox(height: 12),
                  Text(
                    AppLocalizations.t(
                      'Aktivasi / Perpanjangan Lisensi',
                      'License Activation / Renewal',
                    ),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppLocalizations.t(
                      'Masukkan kode resmi yang kamu terima. Kode valid akan menggantikan lisensi tersimpan saat ini.',
                      'Enter the official code you received. A valid code will replace the currently stored license.',
                    ),
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _codeController,
                    enabled: !_loading,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.t(
                        'Kode aktivasi',
                        'Activation code',
                      ),
                      prefixIcon: const Icon(Icons.key_outlined),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: _loading ? null : _activate,
                    icon: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.verified_outlined),
                    label: Text(
                      _loading
                          ? AppLocalizations.t('Memeriksa...', 'Verifying...')
                          : AppLocalizations.t(
                              'Aktifkan Lisensi',
                              'Activate License',
                            ),
                    ),
                  ),
                  if (_message != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _message!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: _success ? colors.primary : colors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

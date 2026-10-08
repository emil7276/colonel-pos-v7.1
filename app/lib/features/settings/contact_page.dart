import 'package:flutter/material.dart';
import '../../core/app_localizations.dart';
import '../../core/constants.dart';

class ContactPage extends StatelessWidget {
  const ContactPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.t('Hubungi Kami', 'Contact Us'))),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.support_agent_rounded,
                    size: 64,
                    color: red,
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'CP COLONEL POS',
                    style: TextStyle(
                      fontSize: 24,
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
                    style: TextStyle(
                      color: inkMuted,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const SelectableText(
                    'cp.colonel.pos@gmail.com',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: red,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

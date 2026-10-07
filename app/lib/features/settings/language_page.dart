import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/language_service.dart';

class LanguagePage extends StatefulWidget {
  const LanguagePage({super.key});

  @override
  State<LanguagePage> createState() => _LanguagePageState();
}

class _LanguagePageState extends State<LanguagePage> {
  String _language = 'id';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    final language = await LanguageService.getLanguage();
    if (!mounted) return;
    setState(() {
      _language = language;
      _loading = false;
    });
  }

  Future<void> _selectLanguage(String language) async {
    await LanguageService.setLanguage(language);
    if (!mounted) return;
    setState(() => _language = language);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bahasa / Language'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: RadioListTile<String>(
                    value: 'id',
                    groupValue: _language,
                    onChanged: (value) {
                      if (value != null) _selectLanguage(value);
                    },
                    title: const Text('🇮🇩  Bahasa Indonesia'),
                    subtitle: const Text('Bahasa default aplikasi'),
                    activeColor: red,
                  ),
                ),
                Card(
                  child: RadioListTile<String>(
                    value: 'en',
                    groupValue: _language,
                    onChanged: (value) {
                      if (value != null) _selectLanguage(value);
                    },
                    title: const Text('🇬🇧  English'),
                    subtitle: const Text('Use English'),
                    activeColor: red,
                  ),
                ),
              ],
            ),
    );
  }
}

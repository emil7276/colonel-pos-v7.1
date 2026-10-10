import 'package:flutter/material.dart';
import '../../core/app_localizations.dart';

class AiAssistantPanel extends StatefulWidget {
  final String role;
  const AiAssistantPanel({super.key, required this.role});

  @override
  State<AiAssistantPanel> createState() => _AiAssistantPanelState();
}

class _AiAssistantPanelState extends State<AiAssistantPanel> {
  final _input = TextEditingController();
  String? _answer;

  bool get _en => AppLocalizations.isEnglish;
  bool get _admin => widget.role == 'Administrator';

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  String _reply(String raw) {
    final q = raw.toLowerCase().trim();
    if (q.isEmpty) {
      return _en ? 'Please type your question first.'
          : 'Tulis pertanyaanmu dulu, ya.';
    }

    final restricted = [
      'pengaturan pengguna', 'tambah pengguna', 'hapus pengguna',
      'hak akses', 'backup database', 'restore database',
      'aktivasi lisensi', 'pengaturan toko', 'pengeluaran',
      'laba bersih', 'user management', 'add user', 'delete user',
      'access rights', 'database backup', 'database restore',
      'license activation', 'business settings', 'expenses',
      'profit report',
    ];
    if (!_admin && restricted.any((s) => q.contains(s))) {
      return _en
          ? 'Sorry 😊 This feature requires Administrator permission. '
            'Please ask your Admin for permission first. Your access is '
            'limited to cashier functions to keep operations safe.'
          : 'Maaf ya 😊 Fitur yang kamu tanyakan memerlukan izin '
            'Administrator. Coba minta bantuan atau izin dulu ke Admin '
            'kamu, ya. Aksesmu disesuaikan dengan fungsi Kasir agar '
            'operasional tetap aman.';
    }

    if (['halo', 'hai', 'hello', 'hi ', 'selamat pagi',
        'selamat siang', 'selamat malam'].any(q.contains)) {
      return _en
          ? 'Hi! 👋 I can help with transactions, payments, returns, stock, '
            'and common POS issues. What happened?'
          : 'Halo! 👋 Saya bisa bantu soal transaksi, pembayaran, retur, '
            'stok, dan kendala umum POS. Ada kendala apa?';
    }

    if (['laci', 'uang fisik', 'selisih uang', 'cash drawer',
        'cash mismatch'].any(q.contains)) {
      return _en
          ? 'Let’s check step by step:\n'
            '1. Count the physical cash again.\n'
            '2. Check the report date and period.\n'
            '3. Review cash sales, change, returns, and cash movements.\n'
            '4. Compare the amounts again. Do not delete transactions just '
            'to force a match. If it still differs, note the amount and '
            'ask your Admin to verify the records.'
          : 'Kita cek pelan-pelan, ya:\n'
            '1. Hitung ulang uang fisik di laci.\n'
            '2. Pastikan tanggal dan periode laporan benar.\n'
            '3. Periksa penjualan tunai, uang kembalian, retur, serta '
            'uang masuk atau keluar dari laci.\n'
            '4. Cocokkan lagi jumlahnya. Jangan menghapus transaksi hanya '
            'agar angkanya sama. Jika masih selisih, catat nominalnya '
            'dan minta Admin memeriksa catatan transaksi.';
    }

    if (q.contains('qris') || q.contains('transfer')) {
      return _en
          ? 'Check the payment status with the payment provider first. '
            'Do not mark an unconfirmed payment as successful. If the '
            'status is unclear, ask your Admin to verify it.'
          : 'Periksa status pembayaran melalui penyedia pembayaran '
            'terlebih dahulu. Jangan tandai pembayaran yang belum '
            'terkonfirmasi sebagai berhasil. Jika belum jelas, minta '
            'Admin memeriksanya.';
    }

    if (q.contains('retur') || q.contains('return barang')) {
      return _en
          ? 'Check the original transaction and returned items, then '
            'follow your store’s return procedure. If the return option '
            'is unavailable or requires permission, ask your Admin.'
          : 'Periksa transaksi asal dan barang yang dikembalikan, lalu '
            'ikuti prosedur retur toko. Jika menu retur tidak tersedia '
            'atau memerlukan izin, hubungi Admin.';
    }

    if (q.contains('stok') || q.contains('stock') ||
        q.contains('persediaan')) {
      return _en
          ? 'Check the correct product and variant, then review recent '
            'sales and returns. If the stock still looks wrong, ask your '
            'Admin to verify inventory records before adjusting them.'
          : 'Pastikan produk dan variannya benar, lalu periksa penjualan '
            'serta retur terbaru. Jika stok tetap tidak sesuai, minta '
            'Admin memeriksa catatan persediaan sebelum mengubahnya.';
    }

    if (q.contains('login') || q.contains('password') ||
        q.contains('kata sandi')) {
      return _en
          ? 'Check your username and password. If you forgot your '
            'password or your account is blocked, contact your Admin. '
            'Never share your password.'
          : 'Periksa username dan kata sandi. Jika lupa kata sandi atau '
            'akun terkunci, hubungi Admin. Jangan membagikan kata sandi.';
    }

    if (q.contains('printer') || q.contains('struk') ||
        q.contains('cetak') || q.contains('print')) {
      return _en
          ? 'Check that the printer is powered on, connected, and selected '
            'correctly. If it still fails, ask your Admin to check the '
            'printer configuration.'
          : 'Pastikan printer menyala, terhubung, dan dipilih dengan benar. '
            'Jika masih gagal, minta Admin memeriksa pengaturan printer.';
    }

    // FAQ_SECURITY_AND_SUBSCRIPTION_V72
    if ([
      'aman', 'keamanan', 'keamanan data', 'data pribadi',
      'privasi', 'security', 'safe', 'secure', 'privacy',
      'personal data',
    ].any(q.contains)) {
      return _en
          ? 'Good question 😊 No application should be assumed to be 100% '
            'secure. Use a strong, unique password, do not share your login, '
            'lock your device, and give Administrator access only to '
            'trusted people. Keep backups where supported and use official '
            'support channels if you notice anything suspicious. I cannot '
            'confirm specific security protections without verified details.'
          : 'Pertanyaan bagus 😊 Tidak ada aplikasi yang bisa dianggap '
            '100% aman. Gunakan kata sandi yang kuat dan berbeda, jangan '
            'bagikan akun, kunci perangkat, dan berikan akses Administrator '
            'hanya kepada orang tepercaya. Simpan cadangan jika fitur '
            'tersebut tersedia, dan hubungi dukungan resmi jika menemukan '
            'hal mencurigakan. Saya belum bisa memastikan perlindungan '
            'keamanan tertentu tanpa informasi yang terverifikasi.';
    }

    if ([
      'langganan', 'berlangganan', 'biaya langganan',
      'harga langganan', 'paket langganan', 'cara berlangganan',
      'lisensi', 'aktivasi lisensi', 'subscription', 'subscribe',
      'subscription price', 'pricing', 'license', 'licence',
    ].any(q.contains)) {
      return _en
          ? 'For subscription or license details, please check the official '
            'Colonel POS information or contact the application provider '
            'or your Administrator. I do not have verified current pricing, '
            'plans, or activation instructions, so I do not want to guess. '
            'Please verify payment details through an official channel '
            'before paying.'
          : 'Untuk informasi langganan atau lisensi, silakan periksa '
            'informasi resmi Colonel POS atau hubungi penyedia aplikasi '
            'maupun Administrator kamu. Saya belum memiliki informasi '
            'terverifikasi tentang harga, paket, atau cara aktivasi saat '
            'ini, jadi saya tidak ingin menebak. Pastikan detail pembayaran '
            'melalui kanal resmi sebelum membayar.';
    }

    return _en
        ? 'I’m not sure about that yet, and I don’t want to give incorrect '
          'instructions. Please describe what happened and which step '
          'caused the issue, or ask your Admin for help.'
        : 'Saya belum yakin dengan jawaban untuk pertanyaan itu dan tidak '
          'ingin memberi petunjuk yang keliru. Coba jelaskan kendalanya '
          'dan langkah saat masalah terjadi, atau minta bantuan Admin.';
  }

  void _ask() {
    FocusScope.of(context).unfocus();
    setState(() => _answer = _reply(_input.text));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: SizedBox(
        height: 270,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.support_agent_rounded, color: colors.primary),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  AppLocalizations.t('Asisten Colonel POS',
                      'Colonel POS Assistant'),
                  style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800),
                )),
                Text(AppLocalizations.t('Offline', 'Offline')),
              ]),
              const SizedBox(height: 6),
              Text(
                AppLocalizations.t(
                  'Tanya soal fitur atau kendala saat berjualan.',
                  'Ask about features or issues while using the POS.',
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: TextField(
                  controller: _input,
                  minLines: 1,
                  maxLines: 2,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _ask(),
                  decoration: InputDecoration(
                    hintText: AppLocalizations.t(
                      'Min, kok uang di laci beda?',
                      'Why does my cash drawer differ?'),
                    isDense: true,
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.all(10),
                  ),
                )),
                const SizedBox(width: 6),
                IconButton.filled(
                  tooltip: AppLocalizations.t('Tanya', 'Ask'),
                  onPressed: _ask,
                  icon: const Icon(Icons.send_rounded),
                ),
              ]),
              const SizedBox(height: 8),
              Expanded(child: SingleChildScrollView(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colors.outlineVariant),
                  ),
                  child: Text(
                    _answer ?? AppLocalizations.t(
                      'Halo! Ada yang bisa saya bantu?',
                      'Hi! What can I help you with?'),
                    style: const TextStyle(fontSize: 12.5, height: 1.3),
                  ),
                ),
              )),
            ],
          ),
        ),
      ),
    );
  }
}

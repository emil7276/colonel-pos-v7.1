import 'package:flutter/material.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants.dart';
import '../../core/app_localizations.dart';
import '../../services/receipt_service.dart';

class PrinterPage extends StatefulWidget {
  const PrinterPage({super.key});

  @override
  State<PrinterPage> createState() => _PrinterPageState();
}

class _PrinterPageState extends State<PrinterPage> {
  static const _modeKey = 'printer_mode';
  static const _paperKey = 'printer_paper';
  static const _copiesKey = 'printer_copies';
  static const _autoKey = 'printer_auto_print';
  static const _macKey = 'printer_mac';
  static const _nameKey = 'printer_name';

  String mode = 'System';
  String paper = '58 mm';
  int copies = 1;
  bool autoPrint = false;
  bool saving = false;
  bool loadingBluetooth = false;
  bool connected = false;
  bool choosingPrinter = false;
  String? selectedMac;
  String? selectedName;
  List<BluetoothInfo> devices = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      mode = p.getString(_modeKey) ?? 'System';
      paper = p.getString(_paperKey) ?? '58 mm';
      copies = p.getInt(_copiesKey) ?? 1;
      autoPrint = p.getBool(_autoKey) ?? false;
      selectedMac = p.getString(_macKey);
      selectedName = p.getString(_nameKey);
    });
    if (mode == 'Bluetooth') await _loadBluetooth();
  }

  Future<void> _loadBluetooth() async {
    if (loadingBluetooth) return;
    setState(() => loadingBluetooth = true);
    try {
      final enabled = await PrintBluetoothThermal.bluetoothEnabled;
      if (!enabled) {
        if (mounted) _toast(AppLocalizations.t('Bluetooth HP belum aktif. Aktifkan Bluetooth terlebih dahulu.', 'Phone Bluetooth is not enabled. Please enable Bluetooth first.'));
        return;
      }
      devices = await PrintBluetoothThermal.pairedBluetooths;
      connected = await PrintBluetoothThermal.connectionStatus;
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) _toast(AppLocalizations.t('Gagal membaca perangkat Bluetooth: $e', 'Failed to read Bluetooth devices: $e'));
    } finally {
      if (mounted) setState(() => loadingBluetooth = false);
    }
  }

  Future<void> _choosePrinter() async {
    setState(() => choosingPrinter = true);
    try {
      final enabled = await PrintBluetoothThermal.bluetoothEnabled;
      if (!enabled) {
        _toast(AppLocalizations.t('Bluetooth HP belum aktif. Aktifkan Bluetooth terlebih dahulu.', 'Phone Bluetooth is not enabled. Please enable Bluetooth first.'));
        return;
      }

      final paired = await PrintBluetoothThermal.pairedBluetooths;
      if (!mounted) return;

      final device = await showModalBottomSheet<BluetoothInfo>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (_) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  AppLocalizations.t('Pilih Printer Bluetooth', 'Select Bluetooth Printer'),
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  AppLocalizations.t(
                    'Pilih perangkat printer thermal yang sudah dipasangkan di Android.',
                    'Select the thermal printer paired with Android.',
                  ),
                ),
              ),
              if (paired.isEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text(AppLocalizations.t('Belum ada perangkat Bluetooth yang dipasangkan.', 'No paired Bluetooth devices found.')),
                ),
              ...paired.map(
                (d) => ListTile(
                  leading: const Icon(Icons.bluetooth_rounded, color: red),
                  title: Text(
                    d.name.isEmpty ? AppLocalizations.t('Perangkat tanpa nama', 'Unnamed device') : d.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(d.macAdress),
                  trailing: selectedMac == d.macAdress
                      ? const Icon(Icons.check_circle_rounded, color: Colors.green)
                      : null,
                  onTap: () => Navigator.pop(context, d),
                ),
              ),
            ],
          ),
        ),
      );

      if (device != null) {
        await _connect(device);
      }
    } catch (e) {
      if (mounted) _toast(AppLocalizations.t('Gagal membaca perangkat Bluetooth: $e', 'Failed to read Bluetooth devices: $e'));
    } finally {
      if (mounted) setState(() => choosingPrinter = false);
    }
  }

  Future<void> _connect(BluetoothInfo device) async {
    try {
      setState(() => loadingBluetooth = true);
      final ok = await PrintBluetoothThermal.connect(macPrinterAddress: device.macAdress);
      if (!ok) throw Exception('Koneksi ditolak printer.');
      final p = await SharedPreferences.getInstance();
      await p.setString(_macKey, device.macAdress);
      await p.setString(_nameKey, device.name);
      await p.setString(_modeKey, 'Bluetooth');
      if (!mounted) return;
      setState(() {
        mode = 'Bluetooth';
        selectedMac = device.macAdress;
        selectedName = device.name;
        connected = true;
      });
      _toast(AppLocalizations.t('Printer ${device.name} terhubung.', 'Printer ${device.name} connected.'));
    } catch (e) {
      if (mounted) _toast(AppLocalizations.t('Tidak bisa terhubung: $e', 'Unable to connect: $e'));
    } finally {
      if (mounted) setState(() => loadingBluetooth = false);
    }
  }

  Future<void> _disconnect() async {
    try {
      await PrintBluetoothThermal.disconnect;
      if (!mounted) return;
      setState(() => connected = false);
      _toast(AppLocalizations.t('Printer diputuskan.', 'Printer disconnected.'));
    } catch (e) {
      if (mounted) _toast(AppLocalizations.t('Gagal memutuskan printer: $e', 'Failed to disconnect printer: $e'));
    }
  }

  Future<void> _save() async {
    setState(() => saving = true);
    final p = await SharedPreferences.getInstance();
    await p.setString(_modeKey, mode);
    await p.setString(_paperKey, paper);
    await p.setInt(_copiesKey, copies);
    await p.setBool(_autoKey, autoPrint);
    if (selectedMac != null) await p.setString(_macKey, selectedMac!);
    if (selectedName != null) await p.setString(_nameKey, selectedName!);
    if (!mounted) return;
    setState(() => saving = false);
    _toast(AppLocalizations.t('Pengaturan printer disimpan.', 'Printer settings saved.'));
  }

  Future<void> _testPrint() async {
    try {
      await _save();
      await testPrinterReceipt();
      if (!mounted) return;
      _toast(mode == 'Bluetooth' ? AppLocalizations.t('Test print dikirim ke printer.', 'Test print sent to printer.') : AppLocalizations.t('Dialog cetak dibuka.', 'Print dialog opened.'));
    } catch (e) {
      if (!mounted) return;
      _toast(AppLocalizations.t('Test print gagal: $e', 'Test print failed: $e'));
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pairHelp() async {
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        title: Text(AppLocalizations.t('Pasangkan Printer', 'Pair Printer')),
        content: Text(
          AppLocalizations.t(
            '1. Nyalakan printer Bluetooth.\n'
            '2. Buka Pengaturan HP > Bluetooth.\n'
            '3. Cari nama printer, lalu lakukan pairing.\n'
            '4. Kembali ke CP POS dan tekan Segarkan.\n\n'
            'Setelah printer muncul di daftar, tekan Hubungkan. CP POS akan menyimpan printer tersebut untuk cetak berikutnya.',
            '1. Turn on the Bluetooth printer.\n'
            '2. Open Phone Settings > Bluetooth.\n'
            '3. Find the printer name and pair it.\n'
            '4. Return to CP POS and tap Refresh.\n\n'
            'After the printer appears in the list, tap Connect. CP POS will save the printer for future printing.',
          ),
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(context), child: Text(AppLocalizations.t('Mengerti', 'Got it'))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.t('Printer', 'Printer'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _heroCard(),
          const SizedBox(height: 14),
          _sectionCard(
            title: AppLocalizations.t('Koneksi & Kertas', 'Connection & Paper'),
            icon: Icons.print_outlined,
            children: [
              DropdownButtonFormField<String>(
                value: mode,
                decoration: InputDecoration(labelText: AppLocalizations.t('Mode printer', 'Printer mode'), prefixIcon: const Icon(Icons.print_outlined)),
                items: [
                  DropdownMenuItem(value: 'System', child: Text(AppLocalizations.t('System Print', 'System Print'))),
                  DropdownMenuItem(value: 'Bluetooth', child: Text(AppLocalizations.t('Bluetooth Thermal', 'Bluetooth Thermal'))),
                  DropdownMenuItem(value: 'USB', child: Text(AppLocalizations.t('USB / System Print', 'USB / System Print'))),
                ],
                onChanged: (v) async {
                  setState(() => mode = v ?? 'System');
                  if (mode == 'Bluetooth') await _loadBluetooth();
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: paper,
                decoration: InputDecoration(labelText: AppLocalizations.t('Ukuran kertas', 'Paper size'), prefixIcon: const Icon(Icons.straighten_outlined)),
                items: [
                  DropdownMenuItem(value: '58 mm', child: Text(AppLocalizations.t('Thermal 58 mm', 'Thermal 58 mm'))),
                  DropdownMenuItem(value: '80 mm', child: Text(AppLocalizations.t('Thermal 80 mm', 'Thermal 80 mm'))),
                ],
                onChanged: (v) => setState(() => paper = v ?? '58 mm'),
              ),
              if (mode == 'Bluetooth') ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: Text(AppLocalizations.t('Printer Bluetooth', 'Bluetooth Printer'), style: const TextStyle(fontWeight: FontWeight.w800))),
                    IconButton(onPressed: loadingBluetooth ? null : _loadBluetooth, icon: const Icon(Icons.refresh_rounded), tooltip: AppLocalizations.t('Segarkan', 'Refresh')),
                  ],
                ),
                if (selectedName != null && selectedMac != null)
                  Card(
                    color: redSoft,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                      leading: const Icon(Icons.bluetooth_connected_rounded, color: red),
                      title: Text(selectedName!, style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text(selectedMac!),
                      trailing: connected
                          ? OutlinedButton(onPressed: _disconnect, child: Text(AppLocalizations.t('Putuskan', 'Disconnect')))
                          : FilledButton(onPressed: loadingBluetooth ? null : () => _connect(BluetoothInfo(name: selectedName!, macAdress: selectedMac!)), child: Text(AppLocalizations.t('Hubungkan', 'Connect'))),
                    ),
                  ),
                if (selectedName == null || selectedMac == null)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Text(AppLocalizations.t('Belum ada printer yang dipilih.', 'No printer selected.')),
                  ),
                OutlinedButton.icon(
                  onPressed: loadingBluetooth || choosingPrinter ? null : _choosePrinter,
                  icon: const Icon(Icons.bluetooth_searching_rounded),
                  label: Text(choosingPrinter ? AppLocalizations.t('MEMUAT PERANGKAT...', 'LOADING DEVICES...') : AppLocalizations.t('PILIH PRINTER LAIN', 'SELECT ANOTHER PRINTER')),
                ),
                const SizedBox(height: 4),
                OutlinedButton.icon(
                  onPressed: _pairHelp,
                  icon: const Icon(Icons.help_outline_rounded),
                  label: Text(AppLocalizations.t('CARA PASANG PRINTER', 'HOW TO PAIR PRINTER')),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          _sectionCard(
            title: AppLocalizations.t('Perilaku Cetak', 'Print Behavior'),
            icon: Icons.tune_outlined,
            children: [
              DropdownButtonFormField<int>(
                value: copies,
                decoration: InputDecoration(labelText: AppLocalizations.t('Jumlah salinan', 'Number of copies'), prefixIcon: const Icon(Icons.copy_outlined)),
                items: [
                  DropdownMenuItem(value: 1, child: Text(AppLocalizations.t('1 lembar', '1 copy'))),
                  DropdownMenuItem(value: 2, child: Text(AppLocalizations.t('2 lembar', '2 copies'))),
                ],
                onChanged: (v) => setState(() => copies = v ?? 1),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: autoPrint,
                onChanged: (v) => setState(() => autoPrint = v),
                title: Text(AppLocalizations.t('Cetak otomatis setelah transaksi', 'Print automatically after transaction')),
                subtitle: Text(AppLocalizations.t('Jika aktif, struk dikirim otomatis setelah transaksi berhasil.', 'When enabled, the receipt is sent automatically after a successful transaction.')),
                secondary: const Icon(Icons.print_outlined),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: saving ? null : _save,
            icon: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save_outlined),
            label: Text(saving ? AppLocalizations.t('MENYIMPAN...', 'SAVING...') : AppLocalizations.t('SIMPAN PENGATURAN', 'SAVE SETTINGS')),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(onPressed: _testPrint, icon: const Icon(Icons.print_outlined), label: Text(AppLocalizations.t('TEST PRINT', 'TEST PRINT'))),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, color: red),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      mode == 'Bluetooth'
                          ? AppLocalizations.t('Bluetooth CP POS menggunakan printer thermal ESC/POS yang sudah dipasangkan di Android. Setelah terhubung, alamat printer disimpan agar transaksi berikutnya dapat mencetak langsung.', 'CP POS Bluetooth uses an ESC/POS thermal printer paired with Android. After connecting, the printer address is saved so future transactions can print directly.')
                          : AppLocalizations.t('System Print tetap tersedia sebagai pilihan cadangan bila printer Bluetooth belum digunakan.', 'System Print remains available as a fallback when a Bluetooth printer is not being used.'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [red, darkRed], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 18, offset: Offset(0, 8))],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: .16), borderRadius: BorderRadius.circular(16)),
            child: const Icon(Icons.print_rounded, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('CP POS Printer', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
                SizedBox(height: 4),
                Text(
                  AppLocalizations.t(
                    'Printer thermal Bluetooth + System Print',
                    'Bluetooth thermal + System Print',
                  ),
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({required String title, required IconData icon, required List<Widget> children}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [Icon(icon, color: red), const SizedBox(width: 10), Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))]),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}

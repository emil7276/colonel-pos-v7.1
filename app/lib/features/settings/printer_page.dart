import 'package:flutter/material.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants.dart';
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
        if (mounted) _toast('Bluetooth HP belum aktif. Aktifkan Bluetooth terlebih dahulu.');
        return;
      }
      devices = await PrintBluetoothThermal.pairedBluetooths;
      connected = await PrintBluetoothThermal.connectionStatus;
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) _toast('Gagal membaca perangkat Bluetooth: $e');
    } finally {
      if (mounted) setState(() => loadingBluetooth = false);
    }
  }

  Future<void> _choosePrinter() async {
    setState(() => choosingPrinter = true);
    try {
      final enabled = await PrintBluetoothThermal.bluetoothEnabled;
      if (!enabled) {
        _toast('Bluetooth HP belum aktif. Aktifkan Bluetooth terlebih dahulu.');
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
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'Pilih Printer Bluetooth',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'Pilih perangkat printer thermal yang sudah dipasangkan di Android.',
                ),
              ),
              if (paired.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text('Belum ada perangkat Bluetooth yang dipasangkan.'),
                ),
              ...paired.map(
                (d) => ListTile(
                  leading: const Icon(Icons.bluetooth_rounded, color: red),
                  title: Text(
                    d.name.isEmpty ? 'Perangkat tanpa nama' : d.name,
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
      if (mounted) _toast('Gagal membaca perangkat Bluetooth: $e');
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
      _toast('Printer ${device.name} terhubung.');
    } catch (e) {
      if (mounted) _toast('Tidak bisa terhubung: $e');
    } finally {
      if (mounted) setState(() => loadingBluetooth = false);
    }
  }

  Future<void> _disconnect() async {
    try {
      await PrintBluetoothThermal.disconnect;
      if (!mounted) return;
      setState(() => connected = false);
      _toast('Printer diputuskan.');
    } catch (e) {
      if (mounted) _toast('Gagal memutuskan printer: $e');
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
    _toast('Pengaturan printer disimpan.');
  }

  Future<void> _testPrint() async {
    try {
      await _save();
      await testPrinterReceipt();
      if (!mounted) return;
      _toast(mode == 'Bluetooth' ? 'Test print dikirim ke printer.' : 'Dialog cetak dibuka.');
    } catch (e) {
      if (!mounted) return;
      _toast('Test print gagal: $e');
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
        title: const Text('Pasangkan Printer'),
        content: const Text(
          '1. Nyalakan printer Bluetooth.\n'
          '2. Buka Pengaturan HP > Bluetooth.\n'
          '3. Cari nama printer, lalu lakukan pairing.\n'
          '4. Kembali ke CP POS dan tekan Segarkan.\n\n'
          'Setelah printer muncul di daftar, tekan Hubungkan. CP POS akan menyimpan printer tersebut untuk cetak berikutnya.',
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Mengerti')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Printer')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _heroCard(),
          const SizedBox(height: 14),
          _sectionCard(
            title: 'Koneksi & Kertas',
            icon: Icons.print_outlined,
            children: [
              DropdownButtonFormField<String>(
                value: mode,
                decoration: const InputDecoration(labelText: 'Mode printer', prefixIcon: Icon(Icons.print_outlined)),
                items: const [
                  DropdownMenuItem(value: 'System', child: Text('System Print')),
                  DropdownMenuItem(value: 'Bluetooth', child: Text('Bluetooth Thermal')),
                  DropdownMenuItem(value: 'USB', child: Text('USB / System Print')),
                ],
                onChanged: (v) async {
                  setState(() => mode = v ?? 'System');
                  if (mode == 'Bluetooth') await _loadBluetooth();
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: paper,
                decoration: const InputDecoration(labelText: 'Ukuran kertas', prefixIcon: Icon(Icons.straighten_outlined)),
                items: const [
                  DropdownMenuItem(value: '58 mm', child: Text('Thermal 58 mm')),
                  DropdownMenuItem(value: '80 mm', child: Text('Thermal 80 mm')),
                ],
                onChanged: (v) => setState(() => paper = v ?? '58 mm'),
              ),
              if (mode == 'Bluetooth') ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Expanded(child: Text('Printer Bluetooth', style: TextStyle(fontWeight: FontWeight.w800))),
                    IconButton(onPressed: loadingBluetooth ? null : _loadBluetooth, icon: const Icon(Icons.refresh_rounded), tooltip: 'Segarkan'),
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
                          ? OutlinedButton(onPressed: _disconnect, child: const Text('Putuskan'))
                          : FilledButton(onPressed: loadingBluetooth ? null : () => _connect(BluetoothInfo(name: selectedName!, macAdress: selectedMac!)), child: const Text('Hubungkan')),
                    ),
                  ),
                if (selectedName == null || selectedMac == null)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Text('Belum ada printer yang dipilih.'),
                  ),
                OutlinedButton.icon(
                  onPressed: loadingBluetooth || choosingPrinter ? null : _choosePrinter,
                  icon: const Icon(Icons.bluetooth_searching_rounded),
                  label: Text(choosingPrinter ? 'MEMUAT PERANGKAT...' : 'PILIH PRINTER LAIN'),
                ),
                const SizedBox(height: 4),
                OutlinedButton.icon(
                  onPressed: _pairHelp,
                  icon: const Icon(Icons.help_outline_rounded),
                  label: const Text('CARA PASANG PRINTER'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          _sectionCard(
            title: 'Perilaku Cetak',
            icon: Icons.tune_outlined,
            children: [
              DropdownButtonFormField<int>(
                value: copies,
                decoration: const InputDecoration(labelText: 'Jumlah salinan', prefixIcon: Icon(Icons.copy_outlined)),
                items: const [
                  DropdownMenuItem(value: 1, child: Text('1 lembar')),
                  DropdownMenuItem(value: 2, child: Text('2 lembar')),
                ],
                onChanged: (v) => setState(() => copies = v ?? 1),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: autoPrint,
                onChanged: (v) => setState(() => autoPrint = v),
                title: const Text('Cetak otomatis setelah transaksi'),
                subtitle: const Text('Jika aktif, struk dikirim otomatis setelah transaksi berhasil.'),
                secondary: const Icon(Icons.print_outlined),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: saving ? null : _save,
            icon: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save_outlined),
            label: Text(saving ? 'MENYIMPAN...' : 'SIMPAN PENGATURAN'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(onPressed: _testPrint, icon: const Icon(Icons.print_outlined), label: const Text('TEST PRINT')),
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
                          ? 'Bluetooth CP POS menggunakan printer thermal ESC/POS yang sudah dipasangkan di Android. Setelah terhubung, alamat printer disimpan agar transaksi berikutnya dapat mencetak langsung.'
                          : 'System Print tetap tersedia sebagai pilihan cadangan bila printer Bluetooth belum digunakan.',
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
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('CP POS Printer', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
                SizedBox(height: 4),
                Text('Bluetooth thermal + System Print', style: TextStyle(color: Colors.white70)),
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

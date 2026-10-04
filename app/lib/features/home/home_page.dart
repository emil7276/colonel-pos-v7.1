import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/trial_service.dart';
import '../../core/license/license_service.dart';
import '../../core/widgets.dart';
import '../auth/login_page.dart';
import '../pos/pos_page.dart';
import '../reports/report_page.dart';
import '../settings/settings_page.dart';
import '../settings/menu_page.dart';
import '../settings/printer_page.dart';
import '../settings/finance_page.dart';
import 'dashboard_page.dart';

class HomePage extends StatefulWidget {
  final String username;
  final String role;

  const HomePage({super.key, required this.username, required this.role});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int index = 0;
  final posKey = GlobalKey<PosPageState>();

  String? _quote;
  Timer? _quoteTimer;
  TrialStatus? _trialStatus;
  LicenseInfo? _licenseInfo;

  void showQuote(String quote) {
    _quoteTimer?.cancel();
    if (!mounted) return;

    setState(() => _quote = quote);

    _quoteTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() => _quote = null);
      }
    });
  }

  void hideQuote() {
    _quoteTimer?.cancel();
    if (mounted) {
      setState(() => _quote = null);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadTrialStatus();
  }

  Future<void> _loadTrialStatus() async {
    final status = await TrialService.status();
    final license = await LicenseService.getLicense();
    if (mounted) {
      setState(() { _trialStatus = status; _licenseInfo = license; });
    }
  }

String _trialLabel() {
  final license = _licenseInfo;
  if (license != null && license.isActive) {
    final remaining = license.expiresAt.difference(DateTime.now());
    final days = (remaining.inHours / 24).ceil().clamp(1, 9999);
    String planLabel;
    switch (license.plan) {
      case "7D": planLabel = "7 HARI"; break;
      case "1M": planLabel = "1 BULAN"; break;
      case "3M": planLabel = "3 BULAN"; break;
      case "1Y": planLabel = "1 TAHUN"; break;
      default: planLabel = license.plan;
    }
    return "AKTIF • $planLabel • Sisa $days hari";
  }
  final status = _trialStatus;
  if (status == null) return "TRIAL";
  final remaining = status.expiresAt.difference(DateTime.now());
  final days = (remaining.inHours / 24).ceil().clamp(1, 7);
  return "TRIAL • Sisa $days hari";
}

  @override
  void dispose() {
    _quoteTimer?.cancel();
    super.dispose();
  }

  Future<void> logout() async {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  void quickAccess(String action) {
    switch (action) {
      case 'transaksi':
        selectPage(1);
        break;
      case 'laporan':
        selectPage(2);
        break;
      case 'produk':
        if (widget.role != 'Administrator') return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MenuPage()),
        );
        break;
      case 'printer':
        if (widget.role != 'Administrator') return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PrinterPage()),
        );
        break;
    }
  }

  void selectPage(int value) {
    setState(() => index = value);
    if (value == 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        posKey.currentState?.load();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardPage(
        username: widget.username,
        role: widget.role,
        onQuickAccess: quickAccess,
      ),
      PosPage(key: posKey, cashier: widget.username, onTransactionSuccess: showQuote),
      ReportPage(role: widget.role),
      if (widget.role == 'Administrator') SettingsPage(username: widget.username),
      if (widget.role == 'Administrator') const FinancePage(),
    ];
    final titles = [
      'Dashboard',
      'Transaksi',
      'Laporan',
      if (widget.role == 'Administrator') 'Pengaturan',
      if (widget.role == 'Administrator') 'Keuangan',
    ];

    return Scaffold(
      backgroundColor: navy,
      appBar: AppBar(
        toolbarHeight: 66,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        flexibleSpace: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color(0xFFD71920),
                    Color(0xFFB51218),
                    Color(0xFF650B10),
                  ],
                ),
              ),
            ),
            Positioned(
              left: -40,
              top: 16,
              child: Transform.rotate(
                angle: -0.45,
                child: Container(
                  width: 190,
                  height: 1,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.28),
                    boxShadow: [
                      BoxShadow(
                        color: red.withValues(alpha: 0.70),
                        blurRadius: 7,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              right: -30,
              top: 28,
              child: Transform.rotate(
                angle: -0.55,
                child: Container(
                  width: 170,
                  height: 1,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    boxShadow: [
                      BoxShadow(
                        color: red.withValues(alpha: 0.60),
                        blurRadius: 7,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        titleSpacing: 8,
        leadingWidth: 58,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12, top: 10, bottom: 10),
          child: CpLogo(size: 44),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titles[index], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            Text('${widget.username} • ${widget.role}', style: const TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w600)),
            if (_trialStatus != null || _licenseInfo != null)
              Text(
                _trialLabel(),
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Untuk berlangganan, hubungi cp.colonel.pos@gmail.com',
                      ),
                    ),
                  );
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 20),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Berlangganan Sekarang',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
          ],
        ),
        actions: [
          if (index == 1)
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.70),
                ),
                boxShadow: [
                  BoxShadow(
                    color: red.withValues(alpha: 0.55),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: TextButton.icon(
                onPressed: () => posKey.currentState?.showQris(),
                icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                label: const Text('QRIS'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          IconButton(
            tooltip: 'Logout',
            onPressed: logout,
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  pageBg,
                  pageBg,
                  pageBg,
                ],
              ),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: IndexedStack(
                    index: index,
                    children: pages,
                  ),
                ),
            if (_quote != null)
              Positioned(
                top: 8,
                left: 8,
                right: 8,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: -1.0, end: 0.0),
                  duration: const Duration(milliseconds: 420),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return Transform.translate(
                      offset: Offset(0, value * 100),
                      child: child,
                    );
                  },
                  child: Dismissible(
                    key: ValueKey(_quote),
                    direction: DismissDirection.vertical,
                    onDismissed: (_) => hideQuote(),
                    child: Material(
                      elevation: 7,
                      borderRadius: BorderRadius.circular(14),
                      color: red,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 13, 8, 13),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 1),
                              child: Icon(
                                Icons.format_quote_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                _quote!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  height: 1.35,
                                ),
                              ),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              onPressed: hideQuote,
                              icon: const Icon(
                                Icons.close_rounded,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: selectPage,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Opacity(
              opacity: 0.70,
              child: Image.asset(
                'assets/images/cp_pos_transaction.png',
                width: 28,
                height: 28,
              ),
            ),
            selectedIcon: Opacity(
              opacity: 0.70,
              child: Image.asset(
                'assets/images/cp_pos_transaction.png',
                width: 28,
                height: 28,
              ),
            ),
            label: 'Transaksi',
          ),
          const NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics_rounded),
            label: 'Laporan',
          ),
          if (widget.role == 'Administrator')
            const NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings_rounded),
              label: 'Admin',
            ),
          if (widget.role == 'Administrator')
            const NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: Icon(Icons.account_balance_wallet_rounded),
              label: 'Keuangan',
            ),
        ],
      ),
    );
  }
}

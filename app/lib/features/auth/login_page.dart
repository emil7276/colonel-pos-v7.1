import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/constants.dart';
import '../../core/widgets.dart';
import '../../core/theme/skin_controller.dart';
import '../../data/database.dart';
import '../home/home_page.dart';
import 'greeting_page.dart';
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() =>
      _LoginPageState();
}
class _LoginPageState extends State<LoginPage> {
  final user = TextEditingController();
  final pass = TextEditingController();
  final _secureStorage = const FlutterSecureStorage();
  bool rememberMe = false;
  bool _checkingRememberedLogin = true;

  @override
  void initState() {
    super.initState();
    _showGreetingOnce();
    _tryRememberedLogin();
  }

  Future<void> _showGreetingOnce() async {
    final prefs = await SharedPreferences.getInstance();
    final alreadyShown =
        prefs.getBool('cp_first_run_greeting_shown') ?? false;

    if (alreadyShown || !mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const GreetingPage(),
      ),
    );

    await prefs.setBool('cp_first_run_greeting_shown', true);
  }

  Future<void> _tryRememberedLogin() async {
    try {
      final savedRemember =
          await _secureStorage.read(key: 'cp_remember_me');
      final savedUser =
          await _secureStorage.read(key: 'cp_remember_user');
      final savedPass =
          await _secureStorage.read(key: 'cp_remember_pass');

      if (savedRemember == 'true' &&
          savedUser != null &&
          savedPass != null &&
          savedUser.isNotEmpty) {
        final u = await DB.login(savedUser, savedPass);

        if (u != null && mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => HomePage(
                username: u['username'] as String,
                role: u['role'] as String,
              ),
            ),
          );
          return;
        }

        // Kredensial sudah tidak valid.
        await _clearRememberedLogin();
      }
    } finally {
      if (mounted) {
        setState(() {
          _checkingRememberedLogin = false;
        });
      }
    }
  }

  Future<void> _saveRememberedLogin() async {
    if (rememberMe) {
      await _secureStorage.write(
        key: 'cp_remember_me',
        value: 'true',
      );
      await _secureStorage.write(
        key: 'cp_remember_user',
        value: user.text.trim(),
      );
      await _secureStorage.write(
        key: 'cp_remember_pass',
        value: pass.text,
      );
    } else {
      await _clearRememberedLogin();
    }
  }

  Future<void> _clearRememberedLogin() async {
    await _secureStorage.delete(key: 'cp_remember_me');
    await _secureStorage.delete(key: 'cp_remember_user');
    await _secureStorage.delete(key: 'cp_remember_pass');
  }

  Future<void> login() async {
    try {
      final u = await DB.login(
        user.text.trim(),
        pass.text,
      );

      if (!mounted) return;

      if (u == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Username atau password salah.',
            ),
          ),
        );
        return;
      }

      await _saveRememberedLogin();

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => HomePage(
            username: u['username'] as String,
            role: u['role'] as String,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Login gagal: $e',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingRememberedLogin) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final skin = SkinController.current;
    return Scaffold(
      backgroundColor: skin.background,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [skin.background, skin.surface],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 138,
                        height: 138,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              Color(0x332F8FE8),
                              Color(0x142F8FE8),
                              Color(0x002F8FE8),
                            ],
                          ),
                        ),
                      ),
                      Image.asset(
                        'assets/images/cp_logo_master.png',
                        width: 118,
                        height: 118,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'CP POS',
                    style: TextStyle(
                      color: skin.text,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'CP COLONEL POS V.7.2',
                    style: TextStyle(color: inkMuted, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 22),
                  Card(
                    color: skin.surface,
                    elevation: 0,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: skin.border),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Masuk ke sistem',
                              style: TextStyle(color: skin.text, fontSize: 20, fontWeight: FontWeight.w800),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: user,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelStyle: TextStyle(color: skin.mutedText),
                              prefixIconColor: skin.primaryDark,
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: skin.border)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: skin.primaryDark, width: 1.6)),
                              labelText: 'Username',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: pass,
                            obscureText: true,
                            decoration: InputDecoration(
                              labelStyle: TextStyle(color: skin.mutedText),
                              prefixIconColor: skin.primaryDark,
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: skin.border)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: skin.primaryDark, width: 1.6)),
                              labelText: 'Password',
                              prefixIcon: Icon(Icons.lock_outline),
                            ),
                            onSubmitted: (_) => login(),
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Akun bawaan\n'
                              'Administrator: admin / 1234\n'
                              'Kasir: kasir / 1234',
                              style: TextStyle(
                                color: skin.mutedText,
                                fontSize: 12,
                                height: 1.5,
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              Checkbox(
                                activeColor: skin.primaryDark,
                                checkColor: Colors.white,
                                value: rememberMe,
                                onChanged: (value) {
                                  setState(() {
                                    rememberMe = value ?? false;
                                  });
                                },
                              ),
                              const Text('Ingat saya'),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: skin.primaryDark,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: login,
                              icon: const Icon(Icons.login_rounded),
                              label: const Text('MASUK'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const CopyrightFooter(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants.dart';
import '../../core/widgets.dart';
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


  @override
  void initState() {
    super.initState();
    _showGreetingOnce();
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

      final prefs = await SharedPreferences.getInstance();

      await prefs.setBool('cp_logged_in', true);
      await prefs.setString(
        'cp_username',
        u['username'] as String,
      );
      await prefs.setString(
        'cp_role',
        u['role'] as String,
      );

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
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white, Colors.white],
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
                  const CpLogo(size: 118),
                  const SizedBox(height: 16),
                  const Text(
                    'CP POS',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Professional Point of Sale • V6.5',
                    style: TextStyle(color: inkMuted, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 22),
                  Card(
                    color: Colors.white,
                    elevation: 6,
                    shadowColor: red.withValues(alpha: 0.35),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: const BorderSide(color: red, width: 1.2),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        children: [
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Masuk ke sistem',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: user,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Username',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: pass,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Password',
                              prefixIcon: Icon(Icons.lock_outline),
                            ),
                            onSubmitted: (_) => login(),
                          ),

                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: red,
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

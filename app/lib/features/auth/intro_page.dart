import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/widgets.dart';
import '../home/home_page.dart';
import 'login_page.dart';

class IntroPage extends StatefulWidget {
  const IntroPage({super.key});

  @override
  State<IntroPage> createState() => _IntroPageState();
}

class _IntroPageState extends State<IntroPage>
    with SingleTickerProviderStateMixin {

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..forward();

    _goNext();
  }

  Future<void> _goNext() async {
    await Future.delayed(const Duration(seconds: 2));

    final prefs = await SharedPreferences.getInstance();

    final loggedIn =
        prefs.getBool('cp_logged_in') ?? false;

    if (!mounted) return;

    if (loggedIn) {
      final username =
          prefs.getString('cp_username') ?? '';

      final role =
          prefs.getString('cp_role') ?? 'Kasir';

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => HomePage(
            username: username,
            role: role,
          ),
        ),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const LoginPage(),
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FadeTransition(
          opacity: _controller,
          child: ScaleTransition(
            scale: Tween<double>(
              begin: .85,
              end: 1,
            ).animate(
              CurvedAnimation(
                parent: _controller,
                curve: Curves.easeOutCubic,
              ),
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CpLogo(size: 130),
                SizedBox(height: 18),
                Text(
                  'COLONEL POS',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Professional Point of Sale',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

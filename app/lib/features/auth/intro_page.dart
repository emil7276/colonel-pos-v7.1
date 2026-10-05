import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants.dart';
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
      duration: const Duration(milliseconds: 1400),
    )..forward();

    Timer(const Duration(seconds: 2), () async {
      final prefs = await SharedPreferences.getInstance();

      final loggedIn =
          prefs.getBool('cp_logged_in') ?? false;

      if (!mounted) return;

      if (loggedIn) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => HomePage(
              username:
                  prefs.getString('cp_username') ?? '',
              role:
                  prefs.getString('cp_role') ?? 'Kasir',
            ),
          ),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const LoginPage(),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBg,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final scale = 0.92 + (_controller.value * 0.08);

            return Opacity(
              opacity: _controller.value,
              child: Transform.scale(
                scale: scale,
                child: child,
              ),
            );
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              CpLogo(size: 140),
              SizedBox(height: 24),
              Text(
                'COLONEL POS',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Kasir Modern untuk UMKM Indonesia',
                style: TextStyle(
                  color: inkMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

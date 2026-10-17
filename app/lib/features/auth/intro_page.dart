import 'dart:async';
import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/widgets.dart';
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

    Timer(const Duration(seconds: 2), () {
      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const LoginPage(),
        ),
      );
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
      body: SizedBox.expand(
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF101C2D),
                Color(0xFF172D49),
                Color(0xFF071321),
              ],
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned(
                left: -120,
                right: -80,
                bottom: -100,
                height: 330,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        Color(0xAA1678D2),
                        Color(0x55104E91),
                        Color(0x00104E91),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(240),
                  ),
                ),
              ),
              Positioned(
                right: -150,
                top: 100,
                width: 300,
                height: 500,
                child: Transform.rotate(
                  angle: -0.45,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x001D6DBB),
                          Color(0x55216FC1),
                          Color(0x001D6DBB),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(180),
                    ),
                  ),
                ),
              ),
              Center(
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
                  child: Image.asset(
                    'assets/images/cp_logo.png',
                    width: 150,
                    height: 150,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

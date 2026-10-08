import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/widgets.dart';

class GreetingPage extends StatefulWidget {
  const GreetingPage({super.key});

  @override
  State<GreetingPage> createState() => _GreetingPageState();
}

class _GreetingPageState extends State<GreetingPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  late final Animation<double> _logoFade;
  late final Animation<double> _logoScale;
  late final Animation<double> _line1Fade;
  late final Animation<double> _line2Fade;
  late final Animation<double> _line3Fade;
  late final Animation<double> _buttonFade;
  late final Animation<double> _buttonScale;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2300),
    );

    _logoFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.00, 0.28, curve: Curves.easeOut),
    );

    _logoScale = Tween<double>(
      begin: 0.82,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.00, 0.32, curve: Curves.easeOutCubic),
      ),
    );

    _line1Fade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.22, 0.48, curve: Curves.easeOut),
    );

    _line2Fade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.34, 0.62, curve: Curves.easeOut),
    );

    _line3Fade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.46, 0.72, curve: Curves.easeOut),
    );

    _buttonFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.62, 0.92, curve: Curves.easeOut),
    );

    _buttonScale = Tween<double>(
      begin: 0.92,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.62, 0.94, curve: Curves.easeOutBack),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _fadeText({
    required Animation<double> animation,
    required String text,
    required TextStyle style,
  }) {
    return FadeTransition(
      opacity: animation,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: style,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 28,
              vertical: 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FadeTransition(
                  opacity: _logoFade,
                  child: ScaleTransition(
                    scale: _logoScale,
                    child: const CpLogo(size: 120),
                  ),
                ),

                const SizedBox(height: 22),

                _fadeText(
                  animation: _line1Fade,
                  text: 'selamat menggunakan',
                  style: const TextStyle(
                    color: Color(0xFF444444),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.6,
                  ),
                ),

                const SizedBox(height: 2),

                _fadeText(
                  animation: _line2Fade,
                  text: 'CP COLONEL P.O.S',
                  style: const TextStyle(
                    color: Color(0xFF8B1111),
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),

                const SizedBox(height: 2),

                _fadeText(
                  animation: _line3Fade,
                  text: 'sukses selalu untuk anda!',
                  style: const TextStyle(
                    color: Color(0xFF555555),
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.4,
                  ),
                ),

                const SizedBox(height: 30),

                FadeTransition(
                  opacity: _buttonFade,
                  child: ScaleTransition(
                    scale: _buttonScale,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFB5121B).withValues(
                              alpha: 0.16,
                            ),
                            blurRadius: 14,
                            spreadRadius: 0,
                          ),
                          BoxShadow(
                            color: const Color(0xFFB5121B).withValues(
                              alpha: 0.07,
                            ),
                            blurRadius: 22,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton(
                          onPressed: () => Navigator.pop(context),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFB5121B),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'MULAI MENGGUNAKAN',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
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
    );
  }
}

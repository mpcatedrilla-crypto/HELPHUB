import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;
  Timer? _navigationTimer;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Color(0xFF1872BE),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _animationController.forward();
    _navigationTimer = Timer(const Duration(milliseconds: 2400), _openLogin);
  }

  void _openLogin() {
    if (!mounted || _isNavigating) return;
    _isNavigating = true;
    _navigationTimer?.cancel();
    Navigator.of(context).pushReplacementNamed('/login');
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1872BE),
      body: Semantics(
        button: true,
        label: 'HelpHub. Tap to continue to login.',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _openLogin,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SizedBox.expand(
              child: Image.asset(
                'assets/images/landing.png',
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

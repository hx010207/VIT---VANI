/// PURPOSE: Animated launch splash screen displaying the official VaniGuard logo.
/// ROLE IN SYSTEM: First interface rendered upon application startup, providing clean brand presentation before navigation.
/// TALKS TO: app/lib/l10n/app_localizations.dart, app/lib/router.dart, app/lib/theme/quiet_vault_theme.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:vaniguard/l10n/app_localizations.dart';
import 'package:vaniguard/theme/quiet_vault_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;
  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeIn,
    );

    _animController.forward();

    _navigationTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    });
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizedAppTitle =
        AppLocalizations.of(context)?.appTitle ?? 'VaniGuard';

    return Scaffold(
      backgroundColor: QuietVaultColors.background,
      body: SafeArea(
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Centered brand logo sized appropriately and never stretched
                Image.asset(
                  'assets/branding/vaniguard_logo.png',
                  width: 140,
                  height: 140,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 24),
                // App name below it using existing text theme and localized string
                Text(
                  localizedAppTitle,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: QuietVaultColors.textPrimary,
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

/// PURPOSE: Primary authentication screen with phone/account login, biometric option, and VaniGuard branding.
/// ROLE IN SYSTEM: Gateway authentication screen presenting the VaniGuard logo above credential inputs before accessing the dashboard.
/// TALKS TO: app/lib/l10n/app_localizations.dart, app/lib/router.dart, app/lib/theme/quiet_vault_theme.dart, app/lib/widgets/accessible_button.dart
import 'package:flutter/material.dart';
import 'package:vaniguard/l10n/app_localizations.dart';
import 'package:vaniguard/theme/quiet_vault_theme.dart';
import 'package:vaniguard/widgets/accessible_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _accountController =
      TextEditingController(text: 'user_test_001');
  final TextEditingController _passwordController =
      TextEditingController(text: 'demo1234');
  bool _obscurePassword = true;

  @override
  void dispose() {
    _accountController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _performLogin() {
    Navigator.pushReplacementNamed(context, '/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final localizedAppTitle = l10n?.appTitle ?? 'VaniGuard';
    final localizedLoginTitle = l10n?.loginTitle ?? 'Secure Voice Banking';
    final localizedPhoneOrAccount =
        l10n?.phoneOrAccount ?? 'Phone Number or Account ID';
    final localizedPassword = l10n?.password ?? 'Password';
    final localizedLoginButton = l10n?.loginButton ?? 'Sign In';
    final localizedLoginButtonHint = l10n?.loginButtonHint ??
        'Submits credentials to authenticate your banking session';
    final localizedDemoButton = l10n?.demoLogin ?? 'Quick Demo Sign In';
    final localizedDemoButtonHint = l10n?.demoLoginHint ??
        'Instantly signs in with demo credentials for testing';

    return Scaffold(
      backgroundColor: QuietVaultColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              // Brand logo above the login form, sized appropriately and never stretched
              Center(
                child: Image.asset(
                  'assets/branding/vaniguard_logo.png',
                  width: 110,
                  height: 110,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 16),
              // App name below logo using existing text theme and localized string
              Center(
                child: Text(
                  localizedAppTitle,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                        color: QuietVaultColors.textPrimary,
                      ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  localizedLoginTitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: QuietVaultColors.textSecondary,
                        fontSize: 16,
                      ),
                ),
              ),
              const SizedBox(height: 36),

              // Account ID / Phone field
              Semantics(
                label: localizedPhoneOrAccount,
                child: TextField(
                  controller: _accountController,
                  decoration: InputDecoration(
                    labelText: localizedPhoneOrAccount,
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: QuietVaultColors.surface,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Password field
              Semantics(
                label: localizedPassword,
                child: TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: localizedPassword,
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: QuietVaultColors.surface,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Primary Login Button
              AccessibleButton(
                label: localizedLoginButton,
                semanticsHint: localizedLoginButtonHint,
                onPressed: _performLogin,
              ),
              const SizedBox(height: 16),

              // Quick Demo Sign In Button
              AccessibleButton(
                label: localizedDemoButton,
                semanticsHint: localizedDemoButtonHint,
                onPressed: _performLogin,
                isSecondary: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

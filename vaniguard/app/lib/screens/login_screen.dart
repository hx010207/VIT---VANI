/// PURPOSE: Primary authentication screen with phone/account login, biometric option, and VaniGuard branding.
/// ROLE IN SYSTEM: Gateway authentication screen presenting the VaniGuard logo above credential inputs before accessing the dashboard.
/// TALKS TO: app/lib/l10n/app_localizations.dart, app/lib/router.dart, app/lib/services/api_client.dart, app/lib/theme/quiet_vault_theme.dart, app/lib/widgets/accessible_button.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vaniguard/l10n/app_localizations.dart';
import 'package:vaniguard/services/api_client.dart';
import 'package:vaniguard/theme/quiet_vault_theme.dart';
import 'package:vaniguard/widgets/accessible_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _accountController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _statusMessage;

  @override
  void dispose() {
    _accountController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _autofillElder() {
    setState(() {
      _accountController.text = '+919876543210';
      _passwordController.text = 'Asha@Demo2026';
      _statusMessage = 'Elder demo credentials filled. Tap Sign In to proceed.';
    });
  }

  void _autofillGuardian() {
    setState(() {
      _accountController.text = '+919876543211';
      _passwordController.text = 'Priya@Demo2026';
      _statusMessage = 'Guardian demo credentials filled. Tap Sign In to proceed.';
    });
  }

  Future<void> _performLogin() async {
    final phone = _accountController.text.trim();
    final password = _passwordController.text.trim();

    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your phone number or account ID.'),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });

    try {
      final res = await ApiClient.sessionExchange(
        phone: phone,
        password: password.isNotEmpty ? password : null,
      );

      final prefs = await SharedPreferences.getInstance();
      if (res['user_id'] != null) {
        await prefs.setString('user_id', res['user_id'].toString());
      }
      if (res['phone'] != null) {
        await prefs.setString('phone', res['phone'].toString());
      }
      if (res['full_name'] != null) {
        await prefs.setString('full_name', res['full_name'].toString());
      }
      if (res['guardian_mode'] != null) {
        await prefs.setBool('guardian_mode', res['guardian_mode'] == true);
      }
      if (res['guardian_name'] != null) {
        await prefs.setString('guardian_name', res['guardian_name'].toString());
      }

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/dashboard');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Sign in failed: ${e.toString().contains("401") ? "Invalid credentials" : "Could not connect to server"}',
            ),
            backgroundColor: QuietVaultColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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
    final localizedDemoElder = l10n?.demoElder ?? 'Demo: Elder';
    final localizedDemoElderHint = l10n?.demoElderHint ??
        'Autofill credentials for Elder demo account';
    final localizedDemoGuardian = l10n?.demoGuardian ?? 'Demo: Guardian';
    final localizedDemoGuardianHint = l10n?.demoGuardianHint ??
        'Autofill credentials for Guardian demo account';

    return Scaffold(
      backgroundColor: QuietVaultColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              Center(
                child: Image.asset(
                  'assets/branding/vaniguard_logo.png',
                  width: 110,
                  height: 110,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 16),
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
              const SizedBox(height: 32),

              // Phone Number / Account ID field
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
              const SizedBox(height: 16),

              if (_statusMessage != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: QuietVaultColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: QuietVaultColors.primary.withOpacity(0.3)),
                  ),
                  child: Text(
                    _statusMessage!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: QuietVaultColors.ink,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Primary Login Button
              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              else
                AccessibleButton(
                  label: localizedLoginButton,
                  semanticsHint: localizedLoginButtonHint,
                  onPressed: _performLogin,
                ),
              const SizedBox(height: 20),

              // Divider between real auth and demo helper autofills
              const Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'Demo Autofill Options',
                      style: TextStyle(
                        fontSize: 14,
                        color: QuietVaultColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 16),

              // Demo Elder Autofill Button
              AccessibleButton(
                label: localizedDemoElder,
                semanticsHint: localizedDemoElderHint,
                onPressed: _autofillElder,
                isSecondary: true,
                icon: Icons.person_rounded,
              ),
              const SizedBox(height: 12),

              // Demo Guardian Autofill Button
              AccessibleButton(
                label: localizedDemoGuardian,
                semanticsHint: localizedDemoGuardianHint,
                onPressed: _autofillGuardian,
                isSecondary: true,
                icon: Icons.security_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }
}


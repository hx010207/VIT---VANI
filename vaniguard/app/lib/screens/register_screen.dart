/// PURPOSE: User registration and Guardian Mode onboarding screen.
/// ROLE IN SYSTEM: Allows new elder or regular users to create an account and configure guardian protection.
/// TALKS TO: app/lib/services/api_client.dart, app/lib/main.dart
import 'package:flutter/material.dart';
import 'package:vaniguard/l10n/app_localizations.dart';
import 'package:vaniguard/main.dart';
import 'package:vaniguard/services/api_client.dart';
import 'package:vaniguard/theme/quiet_vault_theme.dart';
import 'package:vaniguard/widgets/accessible_button.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController(text: '+91');
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _guardianPhoneController = TextEditingController(text: '+91');

  bool _guardianMode = false;
  String _relationship = 'daughter';
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _guardianPhoneController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    final fullName = _fullNameController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;

    if (fullName.isEmpty) {
      setState(() => _errorMessage = 'Please enter your full name');
      return;
    }
    if (phone.length < 10) {
      setState(() => _errorMessage = 'Please enter a valid phone number');
      return;
    }
    if (password.length < 6) {
      setState(() => _errorMessage = 'Password must be at least 6 characters');
      return;
    }
    if (password != confirm) {
      setState(() => _errorMessage = 'Passwords do not match');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ApiClient.register(
        phone: phone,
        password: password,
        fullName: fullName,
        guardianMode: _guardianMode,
        guardianPhone: _guardianMode ? _guardianPhoneController.text.trim() : null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account created successfully. Please sign in.'),
            backgroundColor: QuietVaultColors.success,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Registration failed: ${e.toString().contains("409") ? "Phone already registered" : "Please check your network and details"}';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final currentLang = Localizations.localeOf(context).languageCode;

    return Scaffold(
      backgroundColor: QuietVaultColors.background,
      appBar: AppBar(
        backgroundColor: QuietVaultColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: QuietVaultColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('EN', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  selected: currentLang == 'en',
                  onSelected: (selected) {
                    if (selected) VaniGuardApp.setLocale(context, const Locale('en'));
                  },
                  selectedColor: QuietVaultColors.primary,
                  backgroundColor: QuietVaultColors.surfaceAlt,
                  labelStyle: TextStyle(
                    color: currentLang == 'en' ? Colors.black : QuietVaultColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  label: const Text('HI', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  selected: currentLang == 'hi',
                  onSelected: (selected) {
                    if (selected) VaniGuardApp.setLocale(context, const Locale('hi'));
                  },
                  selectedColor: QuietVaultColors.primary,
                  backgroundColor: QuietVaultColors.surfaceAlt,
                  labelStyle: TextStyle(
                    color: currentLang == 'hi' ? Colors.black : QuietVaultColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Image.asset(
                  'assets/branding/vaniguard_logo.png',
                  width: 80,
                  height: 80,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  l10n?.registerTitle ?? 'Create Account',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: QuietVaultColors.textPrimary,
                      ),
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text(
                  l10n?.registerSubtitle ?? 'Join VaniGuard voice-protected banking',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: QuietVaultColors.textSecondary,
                      ),
                ),
              ),
              const SizedBox(height: 24),

              // Full Name
              TextField(
                controller: _fullNameController,
                decoration: InputDecoration(
                  labelText: l10n?.fullName ?? 'Full Name',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),

              // Phone Number
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: l10n?.phoneOrAccount ?? 'Phone Number (+91)',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),

              // Password
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: l10n?.password ?? 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),

              // Confirm Password
              TextField(
                controller: _confirmPasswordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: l10n?.confirmPassword ?? 'Confirm Password',
                  prefixIcon: const Icon(Icons.lock_clock_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),

              // Guardian Mode Toggle Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: QuietVaultColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _guardianMode
                        ? QuietVaultColors.primary.withOpacity(0.8)
                        : QuietVaultColors.surfaceAlt,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.shield_outlined, color: QuietVaultColors.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            l10n?.guardianModeOption ?? 'Enable Guardian Mode',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: QuietVaultColors.textPrimary,
                            ),
                          ),
                        ),
                        Switch(
                          value: _guardianMode,
                          activeColor: QuietVaultColors.primary,
                          onChanged: (val) => setState(() => _guardianMode = val),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n?.guardianModeDesc ??
                          'Designate a trusted family member to protect transfers with a 30-minute cooling window and alerts.',
                      style: const TextStyle(
                        fontSize: 13,
                        color: QuietVaultColors.textSecondary,
                        height: 1.3,
                      ),
                    ),
                    if (_guardianMode) ...[
                      const SizedBox(height: 16),
                      TextField(
                        controller: _guardianPhoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: l10n?.guardianPhone ?? 'Guardian Phone (+91)',
                          prefixIcon: const Icon(Icons.security_rounded),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n?.relationship ?? 'Relationship',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: QuietVaultColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          ChoiceChip(
                            label: Text(l10n?.daughter ?? 'Daughter'),
                            selected: _relationship == 'daughter',
                            onSelected: (s) {
                              if (s) setState(() => _relationship = 'daughter');
                            },
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: Text(l10n?.son ?? 'Son'),
                            selected: _relationship == 'son',
                            onSelected: (s) {
                              if (s) setState(() => _relationship = 'son');
                            },
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: Text(l10n?.caregiver ?? 'Caregiver'),
                            selected: _relationship == 'caregiver',
                            onSelected: (s) {
                              if (s) setState(() => _relationship = 'caregiver');
                            },
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: QuietVaultColors.danger.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: QuietVaultColors.danger.withOpacity(0.4)),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: QuietVaultColors.danger, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
              ],

              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else
                AccessibleButton(
                  label: l10n?.createAccountButton ?? 'Register',
                  semanticsHint: 'Registers your new account with VaniGuard',
                  onPressed: _handleRegister,
                ),
              const SizedBox(height: 16),

              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  l10n?.alreadyAccount ?? 'Already have an account? Sign In',
                  style: const TextStyle(
                    color: QuietVaultColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

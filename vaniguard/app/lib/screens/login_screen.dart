/// PURPOSE: Primary authentication screen with phone/account login, biometric option, and VaniGuard branding.
/// ROLE IN SYSTEM: Gateway authentication screen presenting the VaniGuard logo, credential inputs, language toggle, and biometrics.
/// TALKS TO: app/lib/l10n/app_localizations.dart, app/lib/router.dart, app/lib/services/api_client.dart, app/lib/services/biometric_service.dart, app/lib/theme/quiet_vault_theme.dart, app/lib/widgets/accessible_button.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vaniguard/l10n/app_localizations.dart';
import 'package:vaniguard/main.dart';
import 'package:vaniguard/services/api_client.dart';
import 'package:vaniguard/services/biometric_service.dart';
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
  bool _canUseBiometrics = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    final available = await BiometricService.isBiometricAvailable();
    final savedPhone = await BiometricService.getEnrolledPhone();
    if (mounted) {
      setState(() {
        _canUseBiometrics = available;
        if (savedPhone != null && _accountController.text.isEmpty) {
          _accountController.text = savedPhone;
        }
      });
    }
  }

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

      // Save credentials for biometrics if successful
      if (password.isNotEmpty) {
        await BiometricService.setEnrolled(phone, password, true);
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

  Future<void> _performBiometricLogin() async {
    final phone = _accountController.text.trim();
    if (phone.isEmpty) {
      setState(() => _statusMessage = 'Enter phone number first for biometric sign-in');
      return;
    }

    final authenticated = await BiometricService.authenticate(
      reason: 'Scan fingerprint to access VaniGuard account',
    );

    if (authenticated) {
      final savedPass = await BiometricService.getEnrolledPassword(phone);
      final password = savedPass ?? (phone.contains('9876543211') ? 'Priya@Demo2026' : 'Asha@Demo2026');
      _passwordController.text = password;
      await _performLogin();
    } else {
      if (mounted) {
        setState(() => _statusMessage = 'Biometric authentication cancelled or failed.');
      }
    }
  }

  void _showServerConfigModal() {
    final urlController = TextEditingController(text: ApiClient.baseUrl);
    String? testResult;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          backgroundColor: QuietVaultColors.surfaceAlt,
          title: const Text(
            'Server Configuration',
            style: TextStyle(color: QuietVaultColors.textPrimary, fontSize: 18),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Hosted Supabase HTTPS backend is preconfigured. Physical devices connect directly over Wi-Fi without cables.',
                  style: TextStyle(fontSize: 12, color: QuietVaultColors.textSecondary, height: 1.3),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: urlController,
                  style: const TextStyle(color: QuietVaultColors.textPrimary, fontSize: 14),
                  decoration: const InputDecoration(
                    labelText: 'API Base URL',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (testResult != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    testResult!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: testResult!.contains('Success') ? QuietVaultColors.success : QuietVaultColors.danger,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                final testUrl = urlController.text.trim();
                ApiClient.configure(baseUrl: testUrl);
                try {
                  final res = await ApiClient.healthCheck();
                  setModalState(() {
                    testResult = 'Success: ${res['status'] ?? 'Connected'}';
                  });
                } catch (e) {
                  setModalState(() {
                    testResult = 'Connection failed: $e';
                  });
                }
              },
              child: const Text('Test Connection'),
            ),
            TextButton(
              onPressed: () {
                ApiClient.configure(baseUrl: urlController.text.trim());
                ApiClient.saveConfig();
                Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final currentLang = Localizations.localeOf(context).languageCode;
    final localizedAppTitle = l10n?.appTitle ?? 'VaniGuard';
    final localizedLoginTitle = l10n?.loginTitle ?? 'Secure Voice Banking';
    final localizedPhoneOrAccount = l10n?.phoneOrAccount ?? 'Phone Number or Account ID';
    final localizedPassword = l10n?.password ?? 'Password';
    final localizedLoginButton = l10n?.loginButton ?? 'Sign In';
    final localizedLoginButtonHint = l10n?.loginButtonHint ?? 'Submits credentials to authenticate your banking session';
    final localizedDemoElder = l10n?.demoElder ?? 'Demo: Elder';
    final localizedDemoElderHint = l10n?.demoElderHint ?? 'Autofill credentials for Elder demo account';
    final localizedDemoGuardian = l10n?.demoGuardian ?? 'Demo: Guardian';
    final localizedDemoGuardianHint = l10n?.demoGuardianHint ?? 'Autofill credentials for Guardian demo account';

    return Scaffold(
      backgroundColor: QuietVaultColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Bar: Server Config on Left, Language Toggle on Right
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.tune_rounded, color: QuietVaultColors.textSecondary),
                    tooltip: l10n?.serverConfig ?? 'Server Configuration',
                    onPressed: _showServerConfigModal,
                  ),
                  Row(
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
                ],
              ),
              const SizedBox(height: 8),

              // Branding
              Center(
                child: Image.asset(
                  'assets/branding/vaniguard_logo.png',
                  width: 100,
                  height: 100,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 12),
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
              const SizedBox(height: 4),
              Center(
                child: Text(
                  localizedLoginTitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: QuietVaultColors.textSecondary,
                        fontSize: 15,
                      ),
                ),
              ),
              const SizedBox(height: 28),

              // Phone Number / Account ID field
              Semantics(
                label: localizedPhoneOrAccount,
                child: TextField(
                  controller: _accountController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: localizedPhoneOrAccount,
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

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
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
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
                      color: QuietVaultColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Primary Sign In Button
              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              else ...[
                AccessibleButton(
                  label: localizedLoginButton,
                  semanticsHint: localizedLoginButtonHint,
                  onPressed: _performLogin,
                ),
                if (_canUseBiometrics) ...[
                  const SizedBox(height: 10),
                  AccessibleButton(
                    label: l10n?.useBiometrics ?? 'Sign in with Biometrics',
                    semanticsHint: 'Authenticates with device fingerprint or face sensor',
                    onPressed: _performBiometricLogin,
                    isSecondary: true,
                    icon: Icons.fingerprint,
                  ),
                ],
              ],
              const SizedBox(height: 12),

              // New user register link
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/register'),
                  child: Text(
                    l10n?.newUserRegister ?? 'New user? Create account',
                    style: const TextStyle(
                      color: QuietVaultColors.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Divider between real auth and demo helper autofills
              const Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'Demo Autofill Options',
                      style: TextStyle(
                        fontSize: 13,
                        color: QuietVaultColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 14),

              // Demo Elder Autofill Button
              AccessibleButton(
                label: localizedDemoElder,
                semanticsHint: localizedDemoElderHint,
                onPressed: _autofillElder,
                isSecondary: true,
                icon: Icons.person_rounded,
              ),
              const SizedBox(height: 10),

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

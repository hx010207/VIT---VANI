/// PURPOSE: Flutter mobile application entrypoint and root widget initialization.
/// ROLE IN SYSTEM: Initializes MaterialApp, applies Quiet Vault theme, loads config, and mounts AppRouter.
/// TALKS TO: app/lib/router.dart, app/lib/theme/quiet_vault_theme.dart, app/lib/services/api_client.dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vaniguard/l10n/app_localizations.dart';
import 'package:vaniguard/theme/quiet_vault_theme.dart';
import 'package:vaniguard/router.dart';
import 'package:vaniguard/services/api_client.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiClient.loadConfig();
  runApp(const VaniGuardApp());
}

class VaniGuardApp extends StatefulWidget {
  const VaniGuardApp({super.key});

  static void setLocale(BuildContext context, Locale newLocale) {
    final state = context.findAncestorStateOfType<_VaniGuardAppState>();
    state?.switchLanguage(newLocale);
  }

  @override
  State<VaniGuardApp> createState() => _VaniGuardAppState();
}

class _VaniGuardAppState extends State<VaniGuardApp> {
  ThemeMode _themeMode = ThemeMode.system;
  Locale _locale = const Locale('hi');

  @override
  void initState() {
    super.initState();
    _loadSavedLocale();
  }

  Future<void> _loadSavedLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final lang = prefs.getString('app_language');
    if (lang != null && ['en', 'hi', 'te', 'ta'].contains(lang)) {
      if (mounted) {
        setState(() {
          _locale = Locale(lang);
        });
      }
    } else {
      final deviceLocale = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
      if (['en', 'hi', 'te', 'ta'].contains(deviceLocale)) {
        if (mounted) {
          setState(() {
            _locale = Locale(deviceLocale);
          });
        }
      }
    }
  }

  void toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
  }

  void switchLanguage(Locale newLocale) async {
    setState(() {
      _locale = newLocale;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_language', newLocale.languageCode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VaniGuard',
      debugShowCheckedModeBanner: false,
      theme: QuietVaultTheme.light(),
      darkTheme: QuietVaultTheme.dark(),
      themeMode: _themeMode,
      locale: _locale,
      supportedLocales: const [
        Locale('en', ''),
        Locale('hi', ''),
        Locale('te', ''),
        Locale('ta', ''),
      ],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      initialRoute: '/',
      onGenerateRoute: AppRouter.generateRoute,
    );
  }
}

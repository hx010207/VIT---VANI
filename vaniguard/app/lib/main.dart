/// PURPOSE: Flutter mobile application entrypoint and root widget initialization.
/// ROLE IN SYSTEM: Initializes MaterialApp, applies Quiet Vault theme, and mounts AppRouter.
/// TALKS TO: app/lib/router.dart, app/lib/theme/quiet_vault_theme.dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:vaniguard/l10n/app_localizations.dart';
import 'package:vaniguard/theme/quiet_vault_theme.dart';
import 'package:vaniguard/router.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const VaniGuardApp());
}

class VaniGuardApp extends StatefulWidget {
  const VaniGuardApp({super.key});

  @override
  State<VaniGuardApp> createState() => _VaniGuardAppState();
}

class _VaniGuardAppState extends State<VaniGuardApp> {
  ThemeMode _themeMode = ThemeMode.system;
  Locale _locale = const Locale('hi');

  void toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
  }

  void switchLanguage(Locale newLocale) {
    setState(() {
      _locale = newLocale;
    });
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

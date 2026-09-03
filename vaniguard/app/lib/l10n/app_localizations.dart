/// PURPOSE: In-app localization delegate and string resolution for English and Hindi.
/// ROLE IN SYSTEM: Provides localized UI strings to widgets adhering to the multilingual specification.
/// TALKS TO: app/lib/l10n/app_en.arb, app/lib/l10n/app_hi.arb, all UI screens
import 'package:flutter/widgets.dart';

class AppLocalizations {
  final Locale locale;
  AppLocalizations(this.locale);

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  static const Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'appTitle': 'VaniGuard',
      'loginTitle': 'Secure Voice Banking',
      'phoneOrAccount': 'Phone Number or Account ID',
      'password': 'Password',
      'loginButton': 'Sign In',
      'biometricLogin': 'Unlock with Biometrics',
      'demoLogin': 'Quick Demo Sign In',
      'savingsAccount': 'Primary Savings Account',
      'profile': 'User Profile',
      'voiceBanking': 'Voice Banking',
      'listening': 'Listening...',
    },
    'hi': {
      'appTitle': 'वानीगार्ड',
      'loginTitle': 'सुरक्षित आवाज बैंकिंग',
      'phoneOrAccount': 'फ़ोन नंबर या खाता आईडी',
      'password': 'पासवर्ड',
      'loginButton': 'साइन इन करें',
      'biometricLogin': 'बायोमेट्रिक्स से अनलॉक करें',
      'demoLogin': 'त्वरित डेमो साइन इन',
      'savingsAccount': 'प्राथमिक बचत खाता',
      'profile': 'उपयोगकर्ता प्रोफ़ाइल',
      'voiceBanking': 'आवाज से बैंकिंग',
      'listening': 'सुन रहे हैं...',
    },
  };

  String get appTitle => _localizedValues[locale.languageCode]?['appTitle'] ?? 'VaniGuard';
  String get loginTitle => _localizedValues[locale.languageCode]?['loginTitle'] ?? 'Secure Voice Banking';
  String get phoneOrAccount => _localizedValues[locale.languageCode]?['phoneOrAccount'] ?? 'Phone Number or Account ID';
  String get password => _localizedValues[locale.languageCode]?['password'] ?? 'Password';
  String get loginButton => _localizedValues[locale.languageCode]?['loginButton'] ?? 'Sign In';
  String get biometricLogin => _localizedValues[locale.languageCode]?['biometricLogin'] ?? 'Unlock with Biometrics';
  String get demoLogin => _localizedValues[locale.languageCode]?['demoLogin'] ?? 'Quick Demo Sign In';
  String get savingsAccount => _localizedValues[locale.languageCode]?['savingsAccount'] ?? 'Primary Savings Account';
  String get profile => _localizedValues[locale.languageCode]?['profile'] ?? 'User Profile';
  String get voiceBanking => _localizedValues[locale.languageCode]?['voiceBanking'] ?? 'Voice Banking';
  String get listening => _localizedValues[locale.languageCode]?['listening'] ?? 'Listening...';
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'hi'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async => AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

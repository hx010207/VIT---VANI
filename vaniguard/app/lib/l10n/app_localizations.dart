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
      'loginButtonHint': 'Submits credentials to authenticate your banking session',
      'biometricLogin': 'Unlock with Biometrics',
      'demoLogin': 'Quick Demo Sign In',
      'demoLoginHint': 'Instantly signs in with demo credentials for testing',
      'demoElder': 'Demo: Elder',
      'demoElderHint': 'Autofill credentials for Elder demo account',
      'demoGuardian': 'Demo: Guardian',
      'demoGuardianHint': 'Autofill credentials for Guardian demo account',
      'guardianAlertTitle': 'Guardian Alert: Action Required',
      'guardianAlertSubtitle': 'A transfer is currently held for elder safety. Tap to review.',
      'voiceNavTitle': 'Voice Navigation',
      'voiceNavHint': 'Tap to speak navigation or payment commands',
      'savingsAccount': 'Primary Savings Account',
      'profile': 'User Profile',
      'voiceBanking': 'Voice Banking',
      'listening': 'Listening...',
      'newUserRegister': 'New user? Create account',
      'registerTitle': 'Create Account',
      'registerSubtitle': 'Join VaniGuard voice-protected banking',
      'fullName': 'Full Name',
      'confirmPassword': 'Confirm Password',
      'guardianModeOption': 'Enable Guardian Mode',
      'guardianModeDesc': 'Designate a trusted family member to protect transfers with a 30-minute cooling window and alerts.',
      'guardianPhone': 'Guardian Phone (+91)',
      'relationship': 'Relationship',
      'son': 'Son',
      'daughter': 'Daughter',
      'caregiver': 'Caregiver',
      'createAccountButton': 'Register',
      'alreadyAccount': 'Already have an account? Sign In',
      'serverConfig': 'Server Configuration',
      'serverConfigHint': 'Change API base URL or test connectivity',
      'useBiometrics': 'Sign in with Biometrics',
      'usePassword': 'Use Password Instead',
      'testConnection': 'Test Connection',
      'payeesTitle': 'Beneficiaries & Payees',
      'searchPayees': 'Search payees by name or UPI',
      'verifiedPayee': 'Verified Payee',
      'unverifiedPayee': 'Unverified Payee',
      'qrScanTitle': 'Scan UPI QR Code',
      'billsTitle': 'Bill Payments',
      'electricity': 'Electricity Bill',
      'water': 'Water Bill',
      'gas': 'LPG Gas Cylinder',
      'mobileRecharge': 'Mobile Recharge',
      'payBill': 'Pay Bill',
      'activeCallWarning': 'Active Phone Call Detected',
      'activeCallDesc': 'For your security, transactions during active calls require extra verification.',
    },
    'hi': {
      'appTitle': 'वानीगार्ड',
      'loginTitle': 'सुरक्षित आवाज बैंकिंग',
      'phoneOrAccount': 'फ़ोन नंबर या खाता आईडी',
      'password': 'पासवर्ड',
      'loginButton': 'साइन इन करें',
      'loginButtonHint': 'अपने बैंकिंग सत्र को प्रमाणित करने के लिए विवरण प्रस्तुत करें',
      'biometricLogin': 'बायोमेट्रिक्स से अनलॉक करें',
      'demoLogin': 'त्वरित डेमो साइन इन',
      'demoLoginHint': 'परीक्षण के लिए डेमो विवरण के साथ तुरंत साइन इन करें',
      'demoElder': 'Demo: Elder',
      'demoElderHint': 'वरिष्ठ नागरिक डेमो खाते के विवरण स्वतः भरें',
      'demoGuardian': 'Demo: Guardian',
      'demoGuardianHint': 'संरक्षक डेमो खाते के विवरण स्वतः भरें',
      'guardianAlertTitle': 'गार्जियन अलर्ट: कार्रवाई आवश्यक',
      'guardianAlertSubtitle': 'वरिष्ठ नागरिक की सुरक्षा के लिए ट्रांसफर रोका गया है। समीक्षा के लिए टैप करें।',
      'voiceNavTitle': 'आवाज नेविगेशन',
      'voiceNavHint': 'नेविगेशन या भुगतान आदेश बोलने के लिए टैप करें',
      'savingsAccount': 'प्राथमिक बचत खाता',
      'profile': 'उपयोगकर्ता प्रोफ़ाइल',
      'voiceBanking': 'आवाज से बैंकिंग',
      'listening': 'सुन रहे हैं...',
      'newUserRegister': 'नए उपयोगकर्ता? खाता बनाएं',
      'registerTitle': 'खाता बनाएं',
      'registerSubtitle': 'वानीगार्ड सुरक्षित आवाज बैंकिंग से जुड़ें',
      'fullName': 'पूरा नाम',
      'confirmPassword': 'पासवर्ड की पुष्टि करें',
      'guardianModeOption': 'संरक्षक मोड सक्षम करें',
      'guardianModeDesc': '30 मिनट की कूलिंग विंडो और अलर्ट के साथ ट्रांसफर की सुरक्षा के लिए एक विश्वसनीय परिवार के सदस्य को नामित करें।',
      'guardianPhone': 'संरक्षक का फ़ोन (+91)',
      'relationship': 'संबंध',
      'son': 'बेटा',
      'daughter': 'बेटी',
      'caregiver': 'देखभालकर्ता',
      'createAccountButton': 'पंजीकरण करें',
      'alreadyAccount': 'पहले से खाता है? साइन इन करें',
      'serverConfig': 'सर्वर विन्यास',
      'serverConfigHint': 'एपीआई बेस यूआरएल बदलें या कनेक्टिविटी जांचें',
      'useBiometrics': 'बायोमेट्रिक्स से साइन इन करें',
      'usePassword': 'इसके बजाय पासवर्ड का उपयोग करें',
      'testConnection': 'कनेक्शन जांचें',
      'payeesTitle': 'लाभार्थी और प्राप्तकर्ता',
      'searchPayees': 'नाम या यूपीआई से खोजें',
      'verifiedPayee': 'सत्यापित प्राप्तकर्ता',
      'unverifiedPayee': 'असत्यापित प्राप्तकर्ता',
      'qrScanTitle': 'यूपीआई क्यूआर कोड स्कैन करें',
      'billsTitle': 'बिल भुगतान',
      'electricity': 'बिजली का बिल',
      'water': 'पानी का बिल',
      'gas': 'गैस सिलेंडर',
      'mobileRecharge': 'मोबाइल रिचार्ज',
      'payBill': 'बिल भरें',
      'activeCallWarning': 'सक्रिय फ़ोन कॉल का पता चला',
      'activeCallDesc': 'आपकी सुरक्षा के लिए, सक्रिय कॉल के दौरान लेनदेन के लिए अतिरिक्त सत्यापन आवश्यक है।',
    },
  };

  String get appTitle => _localizedValues[locale.languageCode]?['appTitle'] ?? 'VaniGuard';
  String get loginTitle => _localizedValues[locale.languageCode]?['loginTitle'] ?? 'Secure Voice Banking';
  String get phoneOrAccount => _localizedValues[locale.languageCode]?['phoneOrAccount'] ?? 'Phone Number or Account ID';
  String get password => _localizedValues[locale.languageCode]?['password'] ?? 'Password';
  String get loginButton => _localizedValues[locale.languageCode]?['loginButton'] ?? 'Sign In';
  String get loginButtonHint => _localizedValues[locale.languageCode]?['loginButtonHint'] ?? 'Submits credentials to authenticate your banking session';
  String get biometricLogin => _localizedValues[locale.languageCode]?['biometricLogin'] ?? 'Unlock with Biometrics';
  String get demoLogin => _localizedValues[locale.languageCode]?['demoLogin'] ?? 'Quick Demo Sign In';
  String get demoLoginHint => _localizedValues[locale.languageCode]?['demoLoginHint'] ?? 'Instantly signs in with demo credentials for testing';
  String get demoElder => _localizedValues[locale.languageCode]?['demoElder'] ?? 'Demo: Elder';
  String get demoElderHint => _localizedValues[locale.languageCode]?['demoElderHint'] ?? 'Autofill credentials for Elder demo account';
  String get demoGuardian => _localizedValues[locale.languageCode]?['demoGuardian'] ?? 'Demo: Guardian';
  String get demoGuardianHint => _localizedValues[locale.languageCode]?['demoGuardianHint'] ?? 'Autofill credentials for Guardian demo account';
  String get guardianAlertTitle => _localizedValues[locale.languageCode]?['guardianAlertTitle'] ?? 'Guardian Alert: Action Required';
  String get guardianAlertSubtitle => _localizedValues[locale.languageCode]?['guardianAlertSubtitle'] ?? 'A transfer is currently held for elder safety. Tap to review.';
  String get voiceNavTitle => _localizedValues[locale.languageCode]?['voiceNavTitle'] ?? 'Voice Navigation';
  String get voiceNavHint => _localizedValues[locale.languageCode]?['voiceNavHint'] ?? 'Tap to speak navigation or payment commands';
  String get savingsAccount => _localizedValues[locale.languageCode]?['savingsAccount'] ?? 'Primary Savings Account';
  String get profile => _localizedValues[locale.languageCode]?['profile'] ?? 'User Profile';
  String get voiceBanking => _localizedValues[locale.languageCode]?['voiceBanking'] ?? 'Voice Banking';
  String get listening => _localizedValues[locale.languageCode]?['listening'] ?? 'Listening...';
  String get newUserRegister => _localizedValues[locale.languageCode]?['newUserRegister'] ?? 'New user? Create account';
  String get registerTitle => _localizedValues[locale.languageCode]?['registerTitle'] ?? 'Create Account';
  String get registerSubtitle => _localizedValues[locale.languageCode]?['registerSubtitle'] ?? 'Join VaniGuard voice-protected banking';
  String get fullName => _localizedValues[locale.languageCode]?['fullName'] ?? 'Full Name';
  String get confirmPassword => _localizedValues[locale.languageCode]?['confirmPassword'] ?? 'Confirm Password';
  String get guardianModeOption => _localizedValues[locale.languageCode]?['guardianModeOption'] ?? 'Enable Guardian Mode';
  String get guardianModeDesc => _localizedValues[locale.languageCode]?['guardianModeDesc'] ?? 'Designate a trusted family member to protect transfers with a 30-minute cooling window and alerts.';
  String get guardianPhone => _localizedValues[locale.languageCode]?['guardianPhone'] ?? 'Guardian Phone (+91)';
  String get relationship => _localizedValues[locale.languageCode]?['relationship'] ?? 'Relationship';
  String get son => _localizedValues[locale.languageCode]?['son'] ?? 'Son';
  String get daughter => _localizedValues[locale.languageCode]?['daughter'] ?? 'Daughter';
  String get caregiver => _localizedValues[locale.languageCode]?['caregiver'] ?? 'Caregiver';
  String get createAccountButton => _localizedValues[locale.languageCode]?['createAccountButton'] ?? 'Register';
  String get alreadyAccount => _localizedValues[locale.languageCode]?['alreadyAccount'] ?? 'Already have an account? Sign In';
  String get serverConfig => _localizedValues[locale.languageCode]?['serverConfig'] ?? 'Server Configuration';
  String get serverConfigHint => _localizedValues[locale.languageCode]?['serverConfigHint'] ?? 'Change API base URL or test connectivity';
  String get useBiometrics => _localizedValues[locale.languageCode]?['useBiometrics'] ?? 'Sign in with Biometrics';
  String get usePassword => _localizedValues[locale.languageCode]?['usePassword'] ?? 'Use Password Instead';
  String get testConnection => _localizedValues[locale.languageCode]?['testConnection'] ?? 'Test Connection';
  String get payeesTitle => _localizedValues[locale.languageCode]?['payeesTitle'] ?? 'Beneficiaries & Payees';
  String get searchPayees => _localizedValues[locale.languageCode]?['searchPayees'] ?? 'Search payees by name or UPI';
  String get verifiedPayee => _localizedValues[locale.languageCode]?['verifiedPayee'] ?? 'Verified Payee';
  String get unverifiedPayee => _localizedValues[locale.languageCode]?['unverifiedPayee'] ?? 'Unverified Payee';
  String get qrScanTitle => _localizedValues[locale.languageCode]?['qrScanTitle'] ?? 'Scan UPI QR Code';
  String get billsTitle => _localizedValues[locale.languageCode]?['billsTitle'] ?? 'Bill Payments';
  String get electricity => _localizedValues[locale.languageCode]?['electricity'] ?? 'Electricity Bill';
  String get water => _localizedValues[locale.languageCode]?['water'] ?? 'Water Bill';
  String get gas => _localizedValues[locale.languageCode]?['gas'] ?? 'LPG Gas Cylinder';
  String get mobileRecharge => _localizedValues[locale.languageCode]?['mobileRecharge'] ?? 'Mobile Recharge';
  String get payBill => _localizedValues[locale.languageCode]?['payBill'] ?? 'Pay Bill';
  String get activeCallWarning => _localizedValues[locale.languageCode]?['activeCallWarning'] ?? 'Active Phone Call Detected';
  String get activeCallDesc => _localizedValues[locale.languageCode]?['activeCallDesc'] ?? 'For your security, transactions during active calls require extra verification.';
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

/// PURPOSE: In-app localization delegate and string resolution for English, Hindi, Telugu, and Tamil.
/// ROLE IN SYSTEM: Provides localized UI strings to widgets adhering to the multilingual specification.
/// TALKS TO: app/lib/l10n/app_en.arb, app/lib/l10n/app_hi.arb, app/lib/l10n/app_te.arb, app/lib/l10n/app_ta.arb, all UI screens
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
      'nfcTapTitle': 'NFC Tap & Pay',
      'nfcTapPrompt': 'Card read: {name}. Say the amount to pay.',
      'nfcUnrecognized': 'Unrecognized card',
      'nfcSuccess': 'Paid {amount} rupees to {name}.',
      'nfcHeld': 'Payment held for safety. Your guardian has been notified.',
      'programCardTitle': 'Program NFC Card',
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
      'voiceNavTitle': 'आवाज नेविгона',
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
      'nfcTapTitle': 'एनएफसी टैप और भुगतान',
      'nfcTapPrompt': 'कार्ड पढ़ा गया: {name}। भुगतान राशि बोलें।',
      'nfcUnrecognized': 'अपरिचित कार्ड',
      'nfcSuccess': '{name} को {amount} रुपये भुगतान किए गए।',
      'nfcHeld': 'सुरक्षा के लिए भुगतान रोका गया। आपके अभिभावक को सूचित कर दिया गया है।',
      'programCardTitle': 'एनएफसी कार्ड प्रोग्राम करें',
    },
    'te': {
      'appTitle': 'వాణిగార్డ్',
      'loginTitle': 'సురక్షిత వాయిస్ బ్యాంకింగ్',
      'phoneOrAccount': 'ఫోన్ నంబర్ లేదా ఖాతా ID',
      'password': 'పాస్‌వర్డ్',
      'loginButton': 'సైన్ ఇన్',
      'loginButtonHint': 'మీ బ్యాంకింగ్ సెషన్‌ను ధృవీకరించడానికి వివరాలను సమర్పించండి',
      'biometricLogin': 'బయోమెట్రిక్స్‌తో అన్‌లాక్ చేయండి',
      'demoLogin': 'త్వరిత డెమో సైన్ ఇన్',
      'demoLoginHint': 'పరీక్ష కోసం డెమో ఆధారాలతో వెంటనే సైన్ ఇన్ చేయండి',
      'demoElder': 'Demo: Elder',
      'demoElderHint': 'సీనియర్ సిటిజెన్ డెమో ఖాతా వివరాలను స్వయంచాలకంగా పూరించండి',
      'demoGuardian': 'Demo: Guardian',
      'demoGuardianHint': 'సంరక్షక డెమో ఖాతా వివరాలను స్వయంచాలకంగా పూరించండి',
      'guardianAlertTitle': 'గార్డియన్ అలర్ట్: చర్య అవసరం',
      'guardianAlertSubtitle': 'పెద్దల భద్రత కోసం బదిలీ నిలిపివేయబడింది. సమీక్షించడానికి నొక్కండి.',
      'voiceNavTitle': 'వాయిస్ నావిగేషన్',
      'voiceNavHint': 'నావిగేషన్ లేదా చెల్లింపు ఆదేశాలు మాట్లాడటానికి నొక్కండి',
      'savingsAccount': 'ప్రాథమిక పొదుపు ఖాతా',
      'profile': 'వినియోగదారు ప్రొఫైల్',
      'voiceBanking': 'వాయిస్ బ్యాంకింగ్',
      'listening': 'వింటున్నాము...',
      'newUserRegister': 'కొత్త వినియోగదారులా? ఖాతాను సృష్టించండి',
      'registerTitle': 'ఖాతాను సృష్టించండి',
      'registerSubtitle': 'వాణిగార్డ్ వాయిస్-రక్షిత బ్యాంకింగ్‌లో చేరండి',
      'fullName': 'పూర్తి పేరు',
      'confirmPassword': 'పాస్‌వర్డ్‌ను నిర్ధారించండి',
      'guardianModeOption': 'గార్డియన్ మోడ్‌ను ప్రారంభించండి',
      'guardianModeDesc': '30 నిమిషాల కూలింగ్ విండో మరియు హెచ్చరికలతో బదిలీలను రక్షించడానికి విశ్వసనీయ కుటుంబ సభ్యుడిని నియమించండి.',
      'guardianPhone': 'సంరక్షకుడి ఫోన్ (+91)',
      'relationship': 'సంబంధం',
      'son': 'కుమారుడు',
      'daughter': 'కుమార్తె',
      'caregiver': 'సంరక్షకుడు',
      'createAccountButton': 'నమోదు చేసుకోండి',
      'alreadyAccount': 'ఇప్పటికే ఖాతా ఉందా? సైన్ ఇన్ చేయండి',
      'serverConfig': 'సర్వర్ కాన్ఫిగరేషన్',
      'serverConfigHint': 'API బేస్ URL ను మార్చండి లేదా కనెక్టివిటీని పరీక్షించండి',
      'useBiometrics': 'బయోమెట్రిక్స్‌తో సైన్ ఇన్ చేయండి',
      'usePassword': 'బదులుగా పాస్‌వర్డ్‌ను ఉపయోగించండి',
      'testConnection': 'కనెక్షన్ పరీక్షించండి',
      'payeesTitle': 'లబ్ధిదారులు & చెల్లింపుదారులు',
      'searchPayees': 'పేరు లేదా UPI ద్వారా లబ్ధిదారులను శోధించండి',
      'verifiedPayee': 'ధృవీకరించబడిన లబ్ధిదారుడు',
      'unverifiedPayee': 'ధృవీకరించబడని లబ్ధిదారుడు',
      'qrScanTitle': 'UPI QR కోడ్‌ను స్కాన్ చేయండి',
      'billsTitle': 'బిల్లు చెల్లింపులు',
      'electricity': 'విద్యుత్ బిల్లు',
      'water': 'నీటి బిల్లు',
      'gas': 'గ్యాస్ సిలిండర్',
      'mobileRecharge': 'మొబైల్ రీఛార్జ్',
      'payBill': 'బిల్లు చెల్లించండి',
      'activeCallWarning': 'కాల్ యాక్టివ్‌గా ఉన్నట్లు గుర్తించబడింది',
      'activeCallDesc': 'మీ భద్రత కోసం, యాక్టివ్ కాల్స్ సమయంలో లావాదేవీలకు అదనపు ధృవీకరణ అవసరం.',
      'nfcTapTitle': 'NFC ట్యాప్ & పే',
      'nfcTapPrompt': 'కార్డు చదవబడింది: {name}. చెల్లించాల్సిన మొత్తాన్ని చెప్పండి.',
      'nfcUnrecognized': 'గుర్తించబడని కార్డు',
      'nfcSuccess': '{name} కి {amount} రూపాయలు చెల్లించబడ్డాయి.',
      'nfcHeld': 'భద్రత కోసం చెల్లింపు నిలిపివేయబడింది. మీ సంరక్షకుడికి సమాచారం అందించబడింది.',
      'programCardTitle': 'NFC కార్డు ప్రోగ్రామ్ చేయండి',
    },
    'ta': {
      'appTitle': 'வாணிகார்ட்',
      'loginTitle': 'பாதுகாப்பான குரல் வங்கி சேவை',
      'phoneOrAccount': 'தொலைபேசி எண் அல்லது கணக்கு எண்',
      'password': 'கடவுச்சொல்',
      'loginButton': 'உள்நுழைய',
      'loginButtonHint': 'உங்கள் வங்கி அமர்வை அங்கீகரிக்க விவரங்களைச் சமர்ப்பிக்கவும்',
      'biometricLogin': 'பயோமெட்ரிக்ஸ் மூலம் திறக்கவும்',
      'demoLogin': 'விரைவு டெமோ உள்நுழைவு',
      'demoLoginHint': 'சோதனைக்காக டெமோ விவரங்களுடன் உடனடியாக உள்நுழையவும்',
      'demoElder': 'Demo: Elder',
      'demoElderHint': 'மூத்த குடிமக்கள் டெமோ கணக்கு விவரங்களைத் தானாக நிரப்பவும்',
      'demoGuardian': 'Demo: Guardian',
      'demoGuardianHint': 'பாதுகாவலர் டெமோ கணக்கு விவரங்களைத் தானாக நிரப்பவும்',
      'guardianAlertTitle': 'பாதுகாவலர் எச்சரிக்கை: நடவடிக்கை தேவை',
      'guardianAlertSubtitle': 'பெரியவர்களின் பாதுகாப்பிற்காக பரிமாற்றம் நிறுத்தி வைக்கப்பட்டுள்ளது. பார்க்க தட்டவும்.',
      'voiceNavTitle': 'குரல் வழிசெலுத்தல்',
      'voiceNavHint': 'வழிசெலுத்தல் அல்லது கட்டணக் கட்டளைகளைப் பேச தட்டவும்',
      'savingsAccount': 'முதன்மை சேமிப்புக் கணக்கு',
      'profile': 'பயனர் சுயவிவரம்',
      'voiceBanking': 'குரல் வங்கி சேவை',
      'listening': 'கேட்கிறது...',
      'newUserRegister': 'புதிய பயனரா? கணக்கை உருவாக்கவும்',
      'registerTitle': 'கணக்கை உருவாக்கவும்',
      'registerSubtitle': 'வாணிகார்ட் குரல்-பாதுகாக்கப்பட்ட வங்கியில் இணையுங்கள்',
      'fullName': 'முழு பெயர்',
      'confirmPassword': 'கடவுச்சொல்லை உறுதிப்படுத்தவும்',
      'guardianModeOption': 'பாதுகாவலர் பயன்முறையை இயக்கவும்',
      'guardianModeDesc': '30 நிமிட காலக்கெடு மற்றும் எச்சரிக்கைகளுடன் பரிமாற்றங்களைப் பாதுகாக்க நம்பகமான குடும்ப உறுப்பினரை நியமிக்கவும்.',
      'guardianPhone': 'பாதுகாவலர் தொலைபேசி (+91)',
      'relationship': 'உறவுமுறை',
      'son': 'மகன்',
      'daughter': 'மகள்',
      'caregiver': 'பராமரிப்பாளர்',
      'createAccountButton': 'பதிவு செய்யவும்',
      'alreadyAccount': 'ஏற்கனவே கணக்கு உள்ளதா? உள்நுழையவும்',
      'serverConfig': 'சர்வர் உள்ளமைவு',
      'serverConfigHint': 'API தள URL-ஐ மாற்றவும் அல்லது இணைப்பைச் சோதிக்கவும்',
      'useBiometrics': 'பயோமெட்ரிக்ஸ் மூலம் உள்நுழையவும்',
      'usePassword': 'அதற்குப் பதிலாக கடவுச்சொல்லைப் பயன்படுத்தவும்',
      'testConnection': 'இணைப்பைச் சோதிக்கவும்',
      'payeesTitle': 'பயனாளிகள் மற்றும் பணம் பெறுபவர்கள்',
      'searchPayees': 'பெயர் அல்லது UPI மூலம் பயனாளிகளைத் தேடவும்',
      'verifiedPayee': 'சரிபார்க்கப்பட்ட பயனாளி',
      'unverifiedPayee': 'சரிபார்க்கப்படாத பயனாளி',
      'qrScanTitle': 'UPI QR குறியீட்டை ஸ்கேன் செய்யவும்',
      'billsTitle': 'கட்டணங்கள் செலுத்துதல்',
      'electricity': 'மின்சாரக் கட்டணம்',
      'water': 'குடிநீர்க் கட்டணம்',
      'gas': 'எரிவாயு சிலிண்டர்',
      'mobileRecharge': 'மொபைல் ரீசார்ஜ்',
      'payBill': 'கட்டணம் செலுத்தவும்',
      'activeCallWarning': 'செயலில் உள்ள அழைப்பு கண்டறியப்பட்டது',
      'activeCallDesc': 'உங்கள் பாதுகாப்பிற்காக, அழைப்பின் போது நடக்கும் பரிவர்த்தனைகளுக்கு கூடுதல் சரிபார்ப்பு தேவை.',
      'nfcTapTitle': 'NFC தட்டவும் & செலுத்தவும்',
      'nfcTapPrompt': 'அட்டை படிக்கப்பட்டது: {name}. செலுத்த வேண்டிய தொகையைக் கூறவும்.',
      'nfcUnrecognized': 'அடையாளம் தெரியாத அட்டை',
      'nfcSuccess': '{name} க்கு {amount} ரூபாய் செலுத்தப்பட்டது.',
      'nfcHeld': 'பாதுகாப்பிற்காக பணம் நிறுத்தி வைக்கப்பட்டது. உங்கள் பாதுகாவலருக்கு தெரிவிக்கப்பட்டுள்ளது.',
      'programCardTitle': 'NFC அட்டையை நிரல் செய்யவும்',
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
  String get nfcTapTitle => _localizedValues[locale.languageCode]?['nfcTapTitle'] ?? 'NFC Tap & Pay';
  String get nfcTapPrompt => _localizedValues[locale.languageCode]?['nfcTapPrompt'] ?? 'Card read: {name}. Say the amount to pay.';
  String get nfcUnrecognized => _localizedValues[locale.languageCode]?['nfcUnrecognized'] ?? 'Unrecognized card';
  String get nfcSuccess => _localizedValues[locale.languageCode]?['nfcSuccess'] ?? 'Paid {amount} rupees to {name}.';
  String get nfcHeld => _localizedValues[locale.languageCode]?['nfcHeld'] ?? 'Payment held for safety. Your guardian has been notified.';
  String get programCardTitle => _localizedValues[locale.languageCode]?['programCardTitle'] ?? 'Program NFC Card';
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'hi', 'te', 'ta'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async => AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

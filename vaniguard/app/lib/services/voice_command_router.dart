/// PURPOSE: Hands-free voice navigation router parsing spoken English, Hindi, Telugu, and Tamil intents for users.
/// ROLE IN SYSTEM: Maps speech transcripts to verified banking navigation routes, amounts, and TTS confirmations.
/// TALKS TO: app/lib/screens/banking_dashboard_screen.dart, app/lib/l10n/app_localizations.dart

enum NavigationIntent {
  pay,
  scanAndPay,
  payBill,
  checkBalance,
  recentTransactions,
  guardianInfo,
  ambiguous,
  unknown,
}

class VoiceCommandResult {
  final NavigationIntent intent;
  final String? route;
  final int? amountInr;
  final String? payeeName;
  final String? billerType;
  final String ttsAnnouncementEn;
  final String ttsAnnouncementHi;
  final String ttsAnnouncementTe;
  final String ttsAnnouncementTa;

  const VoiceCommandResult({
    required this.intent,
    this.route,
    this.amountInr,
    this.payeeName,
    this.billerType,
    required this.ttsAnnouncementEn,
    required this.ttsAnnouncementHi,
    this.ttsAnnouncementTe = '',
    this.ttsAnnouncementTa = '',
  });

  String getLocalizedAnnouncement(String langCode) {
    switch (langCode) {
      case 'hi':
        return ttsAnnouncementHi;
      case 'te':
        return ttsAnnouncementTe.isNotEmpty ? ttsAnnouncementTe : ttsAnnouncementEn;
      case 'ta':
        return ttsAnnouncementTa.isNotEmpty ? ttsAnnouncementTa : ttsAnnouncementEn;
      default:
        return ttsAnnouncementEn;
    }
  }
}

class VoiceCommandRouter {
  /// Maps Devanagari numerals to standard digits
  static String normalizeDevanagariDigits(String input) {
    const devanagari = ['०', '१', '२', '३', '४', '५', '६', '७', '८', '९'];
    var result = input;
    for (int i = 0; i < devanagari.length; i++) {
      result = result.replaceAll(devanagari[i], i.toString());
    }
    return result;
  }

  /// Maps Telugu numerals to standard digits
  static String normalizeTeluguDigits(String input) {
    const telugu = ['౦', '౧', '౨', '౩', '౪', '౫', '౬', '౭', '౮', '౯'];
    var result = input;
    for (int i = 0; i < telugu.length; i++) {
      result = result.replaceAll(telugu[i], i.toString());
    }
    return result;
  }

  /// Maps Tamil numerals to standard digits
  static String normalizeTamilDigits(String input) {
    const tamil = ['௦', '௧', '௨', '௩', '௪', '௫', '௬', '௭', '௮', '௯'];
    var result = input;
    for (int i = 0; i < tamil.length; i++) {
      result = result.replaceAll(tamil[i], i.toString());
    }
    return result;
  }

  /// Detects coercion keywords across English, Hindi, Telugu, and Tamil
  static bool detectCoercion(String transcript) {
    final lower = transcript.toLowerCase();
    const coercionKeywords = [
      'police', 'arrest', 'jail', 'urgent', 'investigation', 'customs', 'cbi',
      'court', 'don\'t tell', 'threat', 'emergency', 'block account',
      'तुरंत', 'पुलिस', 'जेल', 'गिरफ्तार', 'धमकी', 'जांच', 'किसी को मत बताना',
      'పోలీస్', 'అరెస్ట్', 'జైలు', 'అత్యవసరం', 'బెదిరింపు', 'ఎవరికీ చెప్పవద్దు',
      'போலீஸ்', 'கைது', 'சிறை', 'அவசரம்', 'மிரட்டல்', 'யாரிடமும் சொல்லாதே'
    ];
    for (final kw in coercionKeywords) {
      if (lower.contains(kw)) return true;
    }
    return false;
  }

  /// Parses spoken amount across English, Hindi, Telugu, and Tamil (1-9999)
  static int? parseAmount(String text) {
    var normalized = normalizeDevanagariDigits(text.toLowerCase());
    normalized = normalizeTeluguDigits(normalized);
    normalized = normalizeTamilDigits(normalized);

    // Multilingual spoken numeral maps
    final spokenMap = <String, int>{
      // English
      'one hundred': 100,
      'two hundred': 200,
      'three hundred': 300,
      'four hundred': 400,
      'five hundred': 500,
      'six hundred': 600,
      'seven hundred': 700,
      'eight hundred': 800,
      'nine hundred': 900,
      'one thousand': 1000,
      'two thousand': 2000,
      'five thousand': 5000,
      'hundred': 100,
      'thousand': 1000,

      // Hindi
      'ek sau': 100,
      'do sau': 200,
      'teen sau': 300,
      'chaar sau': 400,
      'paanch sau': 500,
      'chhe sau': 600,
      'saat sau': 700,
      'aath sau': 800,
      'nau sau': 900,
      'sau': 100,
      'ek hazaar': 1000,
      'do hazaar': 2000,
      'paanch hazaar': 5000,
      'das hazaar': 10000,
      'hazaar': 1000,

      // Telugu
      'వంద': 100,
      'రెండు వందలు': 200,
      'మూడు వందలు': 300,
      'నాలుగు వందలు': 400,
      'ఐదు వందలు': 500,
      'ఆరు వందలు': 600,
      'ఏడు వందలు': 700,
      'ఎనిమిది వందలు': 800,
      'తొమ్మిది వందలు': 900,
      'వెయ్యి': 1000,
      'రెండు వేలు': 2000,
      'ఐదు వేలు': 5000,
      'పది వేలు': 10000,
      'vanda': 100,
      'rendu vandalu': 200,
      'aidu vandalu': 500,
      'veyyi': 1000,
      'rendu velu': 2000,
      'aidu velu': 5000,

      // Tamil
      'நூறு': 100,
      'இருநூறு': 200,
      'முந்நூறு': 300,
      'நானூறு': 400,
      'ஐந்நூறு': 500,
      'அறுநூறு': 600,
      'எழுநூறு': 700,
      'எண்ணூறு': 800,
      'தொள்ளாயிரம்': 900,
      'ஆயிரம்': 1000,
      'இரண்டாயிரம்': 2000,
      'ஐந்தாயிரம்': 5000,
      'பத்தாயிரம்': 10000,
      'nooru': 100,
      'irunooru': 200,
      'ainnooru': 500,
      'aayiram': 1000,
      'irandaayiram': 2000,
      'ainthaayiram': 5000,
    };

    for (final entry in spokenMap.entries) {
      if (normalized.contains(entry.key)) {
        return entry.value;
      }
    }

    // Direct digit extraction
    final match = RegExp(r'\b\d+\b').firstMatch(normalized);
    if (match != null) {
      return int.tryParse(match.group(0)!);
    }

    return null;
  }

  /// Parses a spoken utterance and returns the target navigation result
  static VoiceCommandResult parse(String transcript) {
    final lower = transcript.toLowerCase().trim();

    if (lower.isEmpty) {
      return const VoiceCommandResult(
        intent: NavigationIntent.unknown,
        ttsAnnouncementEn: "Please say a command like check balance or pay bill.",
        ttsAnnouncementHi: "कृपया एक कमांड बोलें जैसे बैलेंस चेक करें या बिल भरें।",
        ttsAnnouncementTe: "దయచేసి బ్యాలెన్స్ తనిఖీ లేదా బిల్లు చెల్లించండి వంటి ఆదేశాన్ని చెప్పండి.",
        ttsAnnouncementTa: "தயவுசெய்து இருப்பு சரிபார்ப்பு அல்லது கட்டணம் செலுத்துதல் போன்ற கட்டளையைக் கூறவும்.",
      );
    }

    // 1. Check Balance
    if (lower.contains('check balance') ||
        lower.contains('what is my balance') ||
        lower.contains('my balance') ||
        lower.contains('balance kitna') ||
        lower.contains('balance check') ||
        lower.contains('balance batao') ||
        lower.contains('బ్యాలెన్స్') ||
        lower.contains('నిల్వ') ||
        lower.contains('balance entha') ||
        lower.contains('இருப்பு') ||
        lower.contains('பேலன்ஸ்') ||
        lower.contains('iruppu') ||
        lower.contains('बैलेंस') ||
        lower.contains('पैसे कितने')) {
      return const VoiceCommandResult(
        intent: NavigationIntent.checkBalance,
        ttsAnnouncementEn: "Your primary savings balance is fifty thousand rupees.",
        ttsAnnouncementHi: "आपके प्राथमिक बचत खाते में पचास हजार रुपये हैं।",
        ttsAnnouncementTe: "మీ ప్రాథమిక పొదుపు ఖాతా నిల్వ యాభై వేల రూపాయలు.",
        ttsAnnouncementTa: "உங்கள் முதன்மை சேமிப்புக் கணக்கு இருப்பு ஐம்பதாயிரம் ரூபாய்.",
      );
    }

    // 2. Recent Transactions / Activity
    if (lower.contains('recent transaction') ||
        lower.contains('recent activity') ||
        lower.contains('last transaction') ||
        lower.contains('transaction history') ||
        lower.contains('transactions batao') ||
        lower.contains('pichle transaction') ||
        lower.contains('లావాదేవీలు') ||
        lower.contains('ఇటీవలి') ||
        lower.contains('பரிவர்த்தனை') ||
        lower.contains('சமீபத்திய') ||
        lower.contains('हालिया लेनदेन') ||
        lower.contains('गतिविधि')) {
      return const VoiceCommandResult(
        intent: NavigationIntent.recentTransactions,
        route: '/dashboard',
        ttsAnnouncementEn: "Reading recent activity: Five hundred rupees sent to Rahul Sharma. Status completed.",
        ttsAnnouncementHi: "हालिया गतिविधि: राहुल शर्मा को पांच सौ रुपये भेजे गए। स्थिति पूरी हुई।",
        ttsAnnouncementTe: "ఇటీవలి లావాదేవీలు: రాహుల్ శర్మకు ఐదు వందల రూపాయలు పంపబడ్డాయి. పూర్తయింది.",
        ttsAnnouncementTa: "சமீபத்திய பரிவர்த்தனை: ராகுல் சர்மாவுக்கு ஐந்நூறு ரூபாய் அனுப்பப்பட்டது. முடிந்தது.",
      );
    }

    // 3. Scan and Pay (QR Scanner)
    if (lower.contains('scan and pay') ||
        lower.contains('scan qr') ||
        lower.contains('qr scan') ||
        lower.contains('scan code') ||
        lower.contains('qr code') ||
        lower.contains('స్కాన్') ||
        lower.contains('ஸ்கேன்') ||
        lower.contains('स्कैन')) {
      return const VoiceCommandResult(
        intent: NavigationIntent.scanAndPay,
        route: '/voice-session',
        ttsAnnouncementEn: "Opening QR scan and pay. Align the merchant QR code in view.",
        ttsAnnouncementHi: "क्यूआर स्कैन और पे खोल रहे हैं। व्यापारी का क्यूआर कोड कैमरे के सामने रखें।",
        ttsAnnouncementTe: "QR స్కాన్ & పే తెరుస్తున్నాము. వ్యాపారి QR కోడ్‌ను కెమెరా ముందు ఉంచండి.",
        ttsAnnouncementTa: "QR ஸ்கேன் & பே திறக்கப்படுகிறது. வணிகரின் QR குறியீட்டை கேமரா முன் வைக்கவும்.",
      );
    }

    // 4. Pay Bill (and specific utility billers)
    if (lower.contains('pay bill') ||
        lower.contains('bill payment') ||
        lower.contains('electricity') ||
        lower.contains('bijli') ||
        lower.contains('water bill') ||
        lower.contains('pani ka bill') ||
        lower.contains('gas bill') ||
        lower.contains('విద్యుత్') ||
        lower.contains('కరెంట్') ||
        lower.contains('నీటి బిల్లు') ||
        lower.contains('மின்சாரம்') ||
        lower.contains('குடிநீர்') ||
        lower.contains('கட்டணம்') ||
        lower.contains('బిల్లు') ||
        lower.contains('बिल')) {
      String? billerType;
      String enMsg = "Opening bill payments list.";
      String hiMsg = "बिल भुगतान सूची खोल रहे हैं।";
      String teMsg = "బిల్లు చెల్లింపుల జాబితా తెరుస్తున్నాము.";
      String taMsg = "கட்டணங்கள் பட்டியல் திறக்கப்படுகிறது.";

      if (lower.contains('electricity') ||
          lower.contains('bijli') ||
          lower.contains('बिजली') ||
          lower.contains('విద్యుత్') ||
          lower.contains('కరెంట్') ||
          lower.contains('மின்சார')) {
        billerType = 'Electricity';
        enMsg = "Opening BSES electricity bill payment.";
        hiMsg = "बीएसईएस बिजली बिल भुगतान खोल रहे हैं।";
        teMsg = "BSES విద్యుత్ బిల్లు చెల్లింపు తెరుస్తున్నాము.";
        taMsg = "BSES மின்சாரக் கட்டணம் திறக்கப்படுகிறது.";
      } else if (lower.contains('water') ||
          lower.contains('pani') ||
          lower.contains('पानी') ||
          lower.contains('నీటి') ||
          lower.contains('குடிநீர்')) {
        billerType = 'Water';
        enMsg = "Opening Delhi Jal Board water bill payment.";
        hiMsg = "दिल्ली जल बोर्ड पानी बिल भुगतान खोल रहे हैं।";
        teMsg = "ఢిల్లీ జల్ బోర్డ్ నీటి బిల్లు చెల్లింపు తెరుస్తున్నాము.";
        taMsg = "டெல்லி ஜல் போர்டு குடிநீர்க் கட்டணம் திறக்கப்படுகிறது.";
      } else if (lower.contains('gas') || lower.contains('గ్యాస్') || lower.contains('எரிவாயு') || lower.contains('गैस')) {
        billerType = 'Gas';
        enMsg = "Opening IGL piped gas bill payment.";
        hiMsg = "आईजीएल गैस बिल भुगतान खोल रहे हैं।";
        teMsg = "IGL గ్యాస్ బిల్లు చెల్లింపు తెరుస్తున్నాము.";
        taMsg = "IGL எரிவாயு கட்டணம் திறக்கப்படுகிறது.";
      }

      return VoiceCommandResult(
        intent: NavigationIntent.payBill,
        route: '/voice-session',
        billerType: billerType,
        ttsAnnouncementEn: enMsg,
        ttsAnnouncementHi: hiMsg,
        ttsAnnouncementTe: teMsg,
        ttsAnnouncementTa: taMsg,
      );
    }

    // 5. Pay / Transfer
    if (lower.contains('pay') ||
        lower.contains('transfer') ||
        lower.contains('send money') ||
        lower.contains('send') ||
        lower.contains('bhejo') ||
        lower.contains('भेजो') ||
        lower.contains('పంపు') ||
        lower.contains('అనుప్పు') ||
        lower.contains('அனுப்பு') ||
        lower.contains('చెల్లించు') ||
        lower.contains('సెండ్') ||
        lower.contains('డబ్బు') ||
        lower.contains('பணம்') ||
        lower.contains('ट्रांसफर')) {
      final amount = parseAmount(lower);
      String? payee;

      if (lower.contains('rahul') || lower.contains('राहुल') || lower.contains('రాహుల్') || lower.contains('ராகுல்')) {
        payee = 'Rahul Sharma';
      } else if (lower.contains('sunita') || lower.contains('सुनीता') || lower.contains('సునీత') || lower.contains('சுனிதா')) {
        payee = 'Sunita';
      } else if (lower.contains('priya') || lower.contains('प्रिया') || lower.contains('ప్రియ') || lower.contains('பிரியா')) {
        payee = 'Priya Sharma (Guardian)';
      } else if (lower.contains('apollo') || lower.contains('chemist') || lower.contains('దవై') || lower.contains('மருந்து')) {
        payee = 'Local Chemist & Grocer';
      }

      final amtStr = amount != null ? " $amount rupees" : "";
      final amtStrHi = amount != null ? " $amount रुपये" : "";
      final amtStrTe = amount != null ? " $amount రూపాయలు" : "";
      final amtStrTa = amount != null ? " $amount ரூபாய்" : "";
      final payeeStr = payee != null ? " to $payee" : "";
      final payeeStrHi = payee != null ? " $payee को" : "";
      final payeeStrTe = payee != null ? " $payee కి" : "";
      final payeeStrTa = payee != null ? " $payee க்கு" : "";

      return VoiceCommandResult(
        intent: NavigationIntent.pay,
        route: '/voice-session',
        amountInr: amount,
        payeeName: payee,
        ttsAnnouncementEn: "Opening secure voice transfer$amtStr$payeeStr.",
        ttsAnnouncementHi: "सुरक्षित आवाज ट्रांसफर खोल रहे हैं$payeeStrHi$amtStrHi।",
        ttsAnnouncementTe: "సురక్షిత వాయిస్ బదిలీ తెరుస్తున్నాము$payeeStrTe$amtStrTe.",
        ttsAnnouncementTa: "பாதுகாப்பான குரல் பரிமாற்றம் திறக்கப்படுகிறது$payeeStrTa$amtStrTa.",
      );
    }

    // 6. Guardian Info
    if (lower.contains('guardian') ||
        lower.contains('who is my guardian') ||
        lower.contains('guardian kaun') ||
        lower.contains('guardians') ||
        lower.contains('సంరక్షకుడు') ||
        lower.contains('గార్డియన్') ||
        lower.contains('பாதுகாவலர்') ||
        lower.contains('संरक्षक')) {
      return const VoiceCommandResult(
        intent: NavigationIntent.guardianInfo,
        ttsAnnouncementEn: "Your designated safety guardian is Priya Sharma.",
        ttsAnnouncementHi: "आपकी नामित सुरक्षा संरक्षक प्रिया शर्मा हैं।",
        ttsAnnouncementTe: "మీ నియమిత రక్షణ సంరక్షకురాలు ప్రియా శర్మ.",
        ttsAnnouncementTa: "உங்கள் நியமிக்கப்பட்ட பாதுகாப்பு பாதுகாவலர் பிரியா சர்மா.",
      );
    }

    // 7. Ambiguous prompt check
    if (lower.contains('money') || lower.contains('account') || lower.contains('पैसे') || lower.contains('ఖాతా') || lower.contains('கணக்கு')) {
      return const VoiceCommandResult(
        intent: NavigationIntent.ambiguous,
        ttsAnnouncementEn: "Did you mean check balance or pay someone? Please say check balance or transfer.",
        ttsAnnouncementHi: "क्या आप बैलेंस चेक करना चाहते हैं या पैसे भेजना चाहते हैं? कृपया स्पष्ट बोलें।",
        ttsAnnouncementTe: "మీరు బ్యాలెన్స్ తనిఖీ చేయాలనుకుంటున్నారా లేదా ఎవరికైనా చెల్లించాలనుకుంటున్నారా? దయచేసి స్పష్టంగా చెప్పండి.",
        ttsAnnouncementTa: "இருப்பைச் சரிபார்க்க வேண்டுமா அல்லது பணம் செலுத்த வேண்டுமா? தெளிவாகக் கூறவும்.",
      );
    }

    // Fallback unknown
    return const VoiceCommandResult(
      intent: NavigationIntent.unknown,
      ttsAnnouncementEn: "I didn't recognize that command. Try saying: Check balance, Recent transactions, Who is my guardian, or Pay electricity bill.",
      ttsAnnouncementHi: "मुझे वह कमांड समझ नहीं आया। यह बोलें: बैलेंस चेक करें, हालिया लेनदेन, मेरी संरक्षक कौन है, या बिजली का बिल भरें।",
      ttsAnnouncementTe: "ఆ ఆదేశం గుర్తించబడలేదు. ఇలా చెప్పండి: బ్యాలెన్స్ తనిఖీ చేయండి, ఇటీవల లావాదేవీలు, నా సంరక్షకుడు ఎవరు, లేదా విద్యుత్ బిల్లు చెల్లించండి.",
      ttsAnnouncementTa: "அந்த கட்டளை புரியவில்லை. இப்படி சொல்லுங்கள்: இருப்பு சரிபார்க்க, சமீபத்திய பரிவர்த்தனை, எனது பாதுகாவலர் யார், அல்லது மின்சார கட்டணம் செலுத்த.",
    );
  }
}

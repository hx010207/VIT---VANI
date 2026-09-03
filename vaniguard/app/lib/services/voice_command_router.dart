/// PURPOSE: Hands-free voice navigation router parsing spoken English and Hindi intents for visually impaired users.
/// ROLE IN SYSTEM: Maps speech transcripts to verified banking navigation routes, amounts, and TTS confirmations.
/// TALKS TO: app/lib/screens/banking_dashboard_screen.dart, app/lib/l10n/app_localizations.dart
import 'package:flutter/foundation.dart';

enum NavigationIntent {
  pay,
  scanAndPay,
  payBill,
  checkBalance,
  recentTransactions,
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

  const VoiceCommandResult({
    required this.intent,
    this.route,
    this.amountInr,
    this.payeeName,
    this.billerType,
    required this.ttsAnnouncementEn,
    required this.ttsAnnouncementHi,
  });
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

  /// Parses spoken amount in English or Hindi (e.g., "do sau" -> 200, "500", "ek hazaar" -> 1000)
  static int? parseAmount(String text) {
    final normalized = normalizeDevanagariDigits(text.toLowerCase());

    // Spoken Hindi word maps
    final spokenMap = {
      'do sau': 200,
      'teen sau': 300,
      'chaar sau': 400,
      'paanch sau': 500,
      'chhe sau': 600,
      'saat sau': 700,
      'aath sau': 800,
      'nau sau': 900,
      'ek sau': 100,
      'sau': 100,
      'ek hazaar': 1000,
      'do hazaar': 2000,
      'paanch hazaar': 5000,
      'das hazaar': 10000,
      'hazaar': 1000,
      'two hundred': 200,
      'three hundred': 300,
      'five hundred': 500,
      'one hundred': 100,
      'one thousand': 1000,
      'two thousand': 2000,
      'five thousand': 5000,
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
      );
    }

    // 1. Check Balance
    if (lower.contains('check balance') ||
        lower.contains('what is my balance') ||
        lower.contains('my balance') ||
        lower.contains('balance kitna') ||
        lower.contains('balance check') ||
        lower.contains('balance batao') ||
        lower.contains('बैलेंस') ||
        lower.contains('पैसे कितने')) {
      return const VoiceCommandResult(
        intent: NavigationIntent.checkBalance,
        ttsAnnouncementEn: "Your primary savings balance is fifty thousand rupees.",
        ttsAnnouncementHi: "आपके प्राथमिक बचत खाते में पचास हजार रुपये हैं।",
      );
    }

    // 2. Recent Transactions / Activity
    if (lower.contains('recent transaction') ||
        lower.contains('recent activity') ||
        lower.contains('last transaction') ||
        lower.contains('transaction history') ||
        lower.contains('transactions batao') ||
        lower.contains('pichle transaction') ||
        lower.contains('हालिया लेनदेन') ||
        lower.contains('गतिविधि')) {
      return const VoiceCommandResult(
        intent: NavigationIntent.recentTransactions,
        route: '/dashboard',
        ttsAnnouncementEn: "Reading recent activity: Five hundred rupees sent to Rahul Sharma. Status completed.",
        ttsAnnouncementHi: "हालिया गतिविधि: राहुल शर्मा को पांच सौ रुपये भेजे गए। स्थिति पूरी हुई।",
      );
    }

    // 3. Scan and Pay (QR Scanner)
    if (lower.contains('scan and pay') ||
        lower.contains('scan qr') ||
        lower.contains('qr scan') ||
        lower.contains('scan code') ||
        lower.contains('qr code') ||
        lower.contains('स्कैन')) {
      return const VoiceCommandResult(
        intent: NavigationIntent.scanAndPay,
        route: '/voice-session',
        ttsAnnouncementEn: "Opening QR scan and pay. Align the merchant QR code in view.",
        ttsAnnouncementHi: "क्यूआर स्कैन और पे खोल रहे हैं। व्यापारी का क्यूआर कोड कैमरे के सामने रखें।",
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
        lower.contains('बिल')) {
      String? billerType;
      String enMsg = "Opening bill payments list.";
      String hiMsg = "बिल भुगतान सूची खोल रहे हैं।";

      if (lower.contains('electricity') || lower.contains('bijli') || lower.contains('बिजली')) {
        billerType = 'Electricity';
        enMsg = "Opening BSES electricity bill payment.";
        hiMsg = "बीएसईएस बिजली बिल भुगतान खोल रहे हैं।";
      } else if (lower.contains('water') || lower.contains('pani') || lower.contains('पानी')) {
        billerType = 'Water';
        enMsg = "Opening Delhi Jal Board water bill payment.";
        hiMsg = "दिल्ली जल बोर्ड पानी बिल भुगतान खोल रहे हैं।";
      } else if (lower.contains('gas') || lower.contains('गैस')) {
        billerType = 'Gas';
        enMsg = "Opening IGL piped gas bill payment.";
        hiMsg = "आईजीएल गैस बिल भुगतान खोल रहे हैं।";
      }

      return VoiceCommandResult(
        intent: NavigationIntent.payBill,
        route: '/voice-session',
        billerType: billerType,
        ttsAnnouncementEn: enMsg,
        ttsAnnouncementHi: hiMsg,
      );
    }

    // 5. Pay / Transfer
    if (lower.contains('pay') ||
        lower.contains('transfer') ||
        lower.contains('send money') ||
        lower.contains('send') ||
        lower.contains('bhejo') ||
        lower.contains('भेजो') ||
        lower.contains('ट्रांसफर')) {
      final amount = parseAmount(lower);
      String? payee;

      if (lower.contains('rahul') || lower.contains('राहुल')) {
        payee = 'Rahul Sharma';
      } else if (lower.contains('sunita') || lower.contains('सुनीता')) {
        payee = 'Sunita';
      } else if (lower.contains('apollo') || lower.contains('chemist') || lower.contains('दवाई')) {
        payee = 'Local Chemist & Grocer';
      }

      final amtStr = amount != null ? " $amount rupees" : "";
      final amtStrHi = amount != null ? " $amount रुपये" : "";
      final payeeStr = payee != null ? " to $payee" : "";
      final payeeStrHi = payee != null ? " $payee को" : "";

      return VoiceCommandResult(
        intent: NavigationIntent.pay,
        route: '/voice-session',
        amountInr: amount,
        payeeName: payee,
        ttsAnnouncementEn: "Opening secure voice transfer$amtStr$payeeStr.",
        ttsAnnouncementHi: "सुरक्षित आवाज ट्रांसफर खोल रहे हैं$payeeStrHi$amtStrHi।",
      );
    }

    // 6. Ambiguous prompt check
    if (lower.contains('money') || lower.contains('account') || lower.contains('पैसे') || lower.contains('खाता')) {
      return const VoiceCommandResult(
        intent: NavigationIntent.ambiguous,
        ttsAnnouncementEn: "Did you mean check balance or pay someone? Please say check balance or transfer.",
        ttsAnnouncementHi: "क्या आप बैलेंस चेक करना चाहते हैं या पैसे भेजना चाहते हैं? कृपया स्पष्ट बोलें।",
      );
    }

    // Fallback unknown
    return const VoiceCommandResult(
      intent: NavigationIntent.unknown,
      ttsAnnouncementEn: "Unrecognized command. Say check balance, pay electricity bill, or transfer.",
      ttsAnnouncementHi: "कमांड पहचानी नहीं गई। बैलेंस चेक करें, बिजली का बिल, या पैसे भेजें बोलें।",
    );
  }
}

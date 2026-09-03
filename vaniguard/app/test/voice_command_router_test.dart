import 'package:flutter_test/flutter_test.dart';
import 'package:vaniguard/services/voice_command_router.dart';

void main() {
  group('VoiceCommandRouter Tests', () {
    test('Check balance in English and Hindi', () {
      final resEn = VoiceCommandRouter.parse('What is my balance');
      expect(resEn.intent, NavigationIntent.checkBalance);
      expect(resEn.ttsAnnouncementEn, contains('fifty thousand rupees'));

      final resHi = VoiceCommandRouter.parse('मेरा बैलेंस कितना है');
      expect(resHi.intent, NavigationIntent.checkBalance);
      expect(resHi.ttsAnnouncementHi, contains('पचास हजार'));
    });

    test('Pay electricity bill intent parsing', () {
      final resEn = VoiceCommandRouter.parse('pay electricity bill');
      expect(resEn.intent, NavigationIntent.payBill);
      expect(resEn.billerType, 'Electricity');

      final resHi = VoiceCommandRouter.parse('bijli ka bill bharna hai');
      expect(resHi.intent, NavigationIntent.payBill);
      expect(resHi.billerType, 'Electricity');
    });

    test('Scan and Pay QR intent', () {
      final res = VoiceCommandRouter.parse('scan and pay');
      expect(res.intent, NavigationIntent.scanAndPay);
      expect(res.route, '/voice-session');
    });

    test('Recent transactions intent', () {
      final res = VoiceCommandRouter.parse('show my recent transactions');
      expect(res.intent, NavigationIntent.recentTransactions);
      expect(res.ttsAnnouncementEn, contains('Rahul Sharma'));
    });

    test('Pay with amount and payee in English', () {
      final res = VoiceCommandRouter.parse('transfer 500 rupees to rahul');
      expect(res.intent, NavigationIntent.pay);
      expect(res.amountInr, 500);
      expect(res.payeeName, 'Rahul Sharma');
    });

    test('Pay with Hindi spoken numbers: do sau (200)', () {
      final res = VoiceCommandRouter.parse('rahul ko do sau bhejo');
      expect(res.intent, NavigationIntent.pay);
      expect(res.amountInr, 200);
      expect(res.payeeName, 'Rahul Sharma');
    });

    test('Devanagari numeral parsing: ५०० -> 500', () {
      final amt = VoiceCommandRouter.parseAmount('राहुल को ५०० रुपये');
      expect(amt, 500);
    });

    test('Ambiguous intent prompt', () {
      final res = VoiceCommandRouter.parse('money in account');
      expect(res.intent, NavigationIntent.ambiguous);
    });

    test('Unknown intent fallback', () {
      final res = VoiceCommandRouter.parse('play cricket commentary');
      expect(res.intent, NavigationIntent.unknown);
    });
  });
}

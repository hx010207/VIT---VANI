import 'package:flutter_test/flutter_test.dart';
import 'package:vaniguard/services/voice_command_router.dart';

void main() {
  group('VoiceCommandRouter Tests', () {
    test('Check balance in English, Hindi, Telugu, and Tamil', () {
      final resEn = VoiceCommandRouter.parse('What is my balance');
      expect(resEn.intent, NavigationIntent.checkBalance);
      expect(resEn.ttsAnnouncementEn, contains('fifty thousand rupees'));

      final resHi = VoiceCommandRouter.parse('मेरा बैलेंस कितना है');
      expect(resHi.intent, NavigationIntent.checkBalance);
      expect(resHi.ttsAnnouncementHi, contains('पचास हजार'));

      final resTe = VoiceCommandRouter.parse('నా ఖాతా బ్యాలెన్స్ ఎంత');
      expect(resTe.intent, NavigationIntent.checkBalance);
      expect(resTe.ttsAnnouncementTe, contains('యాభై వేల రూపాయలు'));

      final resTa = VoiceCommandRouter.parse('என் கணக்கு இருப்பு என்ன');
      expect(resTa.intent, NavigationIntent.checkBalance);
      expect(resTa.ttsAnnouncementTa, contains('ஐம்பதாயிரம் ரூபாய்'));
    });

    test('Pay electricity bill intent parsing across languages', () {
      final resEn = VoiceCommandRouter.parse('pay electricity bill');
      expect(resEn.intent, NavigationIntent.payBill);
      expect(resEn.billerType, 'Electricity');

      final resHi = VoiceCommandRouter.parse('bijli ka bill bharna hai');
      expect(resHi.intent, NavigationIntent.payBill);
      expect(resHi.billerType, 'Electricity');

      final resTe = VoiceCommandRouter.parse('కరెంట్ బిల్లు చెల్లించండి');
      expect(resTe.intent, NavigationIntent.payBill);
      expect(resTe.billerType, 'Electricity');

      final resTa = VoiceCommandRouter.parse('மின்சார கட்டணம் செலுத்த வேண்டும்');
      expect(resTa.intent, NavigationIntent.payBill);
      expect(resTa.billerType, 'Electricity');
    });

    test('Scan and Pay QR intent in all languages', () {
      final resEn = VoiceCommandRouter.parse('scan and pay');
      expect(resEn.intent, NavigationIntent.scanAndPay);
      expect(resEn.route, '/voice-session');

      final resHi = VoiceCommandRouter.parse('QR स्कैन करो');
      expect(resHi.intent, NavigationIntent.scanAndPay);

      final resTe = VoiceCommandRouter.parse('QR స్కాన్ చేయండి');
      expect(resTe.intent, NavigationIntent.scanAndPay);

      final resTa = VoiceCommandRouter.parse('QR ஸ்கேன் செய்யவும்');
      expect(resTa.intent, NavigationIntent.scanAndPay);
    });

    test('Recent transactions intent across languages', () {
      final resEn = VoiceCommandRouter.parse('show my recent transactions');
      expect(resEn.intent, NavigationIntent.recentTransactions);

      final resHi = VoiceCommandRouter.parse('हालिया लेनदेन बताओ');
      expect(resHi.intent, NavigationIntent.recentTransactions);

      final resTe = VoiceCommandRouter.parse('ఇటీవలి లావాదేవీలు చూపించు');
      expect(resTe.intent, NavigationIntent.recentTransactions);

      final resTa = VoiceCommandRouter.parse('சமீபத்திய பரிவர்த்தனை பட்டியல்');
      expect(resTa.intent, NavigationIntent.recentTransactions);
    });

    test('Who is my guardian intent across languages', () {
      final resEn = VoiceCommandRouter.parse('who is my guardian');
      expect(resEn.intent, NavigationIntent.guardianInfo);
      expect(resEn.ttsAnnouncementEn, contains('Priya Sharma'));

      final resHi = VoiceCommandRouter.parse('मेरी सुरक्षा संरक्षक कौन है');
      expect(resHi.intent, NavigationIntent.guardianInfo);
      expect(resHi.ttsAnnouncementHi, contains('प्रिया शर्मा'));

      final resTe = VoiceCommandRouter.parse('నా సంరక్షకుడు ఎవరు');
      expect(resTe.intent, NavigationIntent.guardianInfo);
      expect(resTe.ttsAnnouncementTe, contains('ప్రియా శర్మ'));

      final resTa = VoiceCommandRouter.parse('எனது பாதுகாவலர் யார்');
      expect(resTa.intent, NavigationIntent.guardianInfo);
      expect(resTa.ttsAnnouncementTa, contains('பிரியா சர்மா'));
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

    test('Ambiguous intent prompt across languages', () {
      final resEn = VoiceCommandRouter.parse('money in account');
      expect(resEn.intent, NavigationIntent.ambiguous);

      final resTe = VoiceCommandRouter.parse('నా ఖాతా');
      expect(resTe.intent, NavigationIntent.ambiguous);

      final resTa = VoiceCommandRouter.parse('என் கணக்கு');
      expect(resTa.intent, NavigationIntent.ambiguous);
    });

    test('Unknown intent fallback with helpful choices', () {
      final res = VoiceCommandRouter.parse('play cricket commentary');
      expect(res.intent, NavigationIntent.unknown);
      expect(res.ttsAnnouncementEn, contains('Check balance'));
      expect(res.ttsAnnouncementHi, contains('बैलेंस'));
      expect(res.ttsAnnouncementTe, contains('బ్యాలెన్స్'));
      expect(res.ttsAnnouncementTa, contains('இருப்பு'));
    });
  });
}

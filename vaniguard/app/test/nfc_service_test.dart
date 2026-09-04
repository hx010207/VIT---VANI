import 'package:flutter_test/flutter_test.dart';
import 'package:vaniguard/services/nfc_service.dart';

void main() {
  group('NfcService Payload and Tag Parsing Tests', () {
    test('Parses valid Payee Card payload', () {
      const raw =
          '{"v":1,"type":"vaniguard_pay","payee_id":"payee-rahul-001","label":"Rahul Sharma","amt":200000}';
      final payload = NfcCardPayload.fromRaw(raw);

      expect(payload, isNotNull);
      expect(payload!.type, 'vaniguard_pay');
      expect(payload.payeeId, 'payee-rahul-001');
      expect(payload.label, 'Rahul Sharma');
      expect(payload.amt, 200000);
    });

    test('Parses canonical payload without amt', () {
      const raw =
          '{"v":1,"type":"vaniguard_pay","payee_id":"payee-bses-002","label":"BSES Electricity"}';
      final payload = NfcCardPayload.fromRaw(raw);

      expect(payload, isNotNull);
      expect(payload!.payeeId, 'payee-bses-002');
      expect(payload.label, 'BSES Electricity');
      expect(payload.amt, isNull);
    });

    test('Unformatted / plain card returns null', () {
      const raw = 'Hello World - Unformatted NFC tag';
      final payload = NfcCardPayload.fromRaw(raw);
      expect(payload, isNull);
    });

    test('Non-vaniguard URL returns null', () {
      const raw = 'https://example.com/payment';
      final payload = NfcCardPayload.fromRaw(raw);
      expect(payload, isNull);
    });

    test('Malformed JSON returns null without crashing', () {
      const raw = '{"v":1,"type":"vaniguard_pay",broken_json}';
      final payload = NfcCardPayload.fromRaw(raw);
      expect(payload, isNull);
    });

    test('Canonical JSON output and round trip', () {
      const original = NfcCardPayload(
        v: 1,
        payeeId: 'payee-chemist-003',
        label: 'Apollo Pharmacy',
      );

      final canonical = original.toCanonicalJson();
      expect(canonical, contains('"type":"vaniguard_pay"'));
      expect(canonical, contains('"payee_id":"payee-chemist-003"'));

      final parsed = NfcCardPayload.fromRaw(canonical);
      expect(parsed, isNotNull);
      expect(parsed!.payeeId, 'payee-chemist-003');
      expect(parsed.label, 'Apollo Pharmacy');
    });
  });
}


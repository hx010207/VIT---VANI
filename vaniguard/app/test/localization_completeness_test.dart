import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Localization Parity and Completeness Tests', () {
    test('app_en.arb, app_hi.arb, app_te.arb, and app_ta.arb have 100% key parity', () {
      final enFile = File('lib/l10n/app_en.arb');
      final hiFile = File('lib/l10n/app_hi.arb');
      final teFile = File('lib/l10n/app_te.arb');
      final taFile = File('lib/l10n/app_ta.arb');

      expect(enFile.existsSync(), isTrue, reason: 'app_en.arb must exist');
      expect(hiFile.existsSync(), isTrue, reason: 'app_hi.arb must exist');
      expect(teFile.existsSync(), isTrue, reason: 'app_te.arb must exist');
      expect(taFile.existsSync(), isTrue, reason: 'app_ta.arb must exist');

      final en = jsonDecode(enFile.readAsStringSync()) as Map<String, dynamic>;
      final hi = jsonDecode(hiFile.readAsStringSync()) as Map<String, dynamic>;
      final te = jsonDecode(teFile.readAsStringSync()) as Map<String, dynamic>;
      final ta = jsonDecode(taFile.readAsStringSync()) as Map<String, dynamic>;

      final enKeys = en.keys.where((k) => !k.startsWith('@')).toSet();
      final hiKeys = hi.keys.where((k) => !k.startsWith('@')).toSet();
      final teKeys = te.keys.where((k) => !k.startsWith('@')).toSet();
      final taKeys = ta.keys.where((k) => !k.startsWith('@')).toSet();

      expect(enKeys.isNotEmpty, isTrue);

      final missingHi = enKeys.difference(hiKeys);
      final missingTe = enKeys.difference(teKeys);
      final missingTa = enKeys.difference(taKeys);

      expect(missingHi, isEmpty, reason: 'Hindi is missing keys: $missingHi');
      expect(missingTe, isEmpty, reason: 'Telugu is missing keys: $missingTe');
      expect(missingTa, isEmpty, reason: 'Tamil is missing keys: $missingTa');
    });
  });
}

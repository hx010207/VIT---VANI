import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';
import 'package:nfc_manager/ndef_record.dart';

/// Canonical audited payees from live Supabase
class AuditedNfcPayee {
  final String id;
  final String name;
  final String ref;
  final String category; // 'person' or 'biller'

  const AuditedNfcPayee({
    required this.id,
    required this.name,
    required this.ref,
    required this.category,
  });
}

const List<AuditedNfcPayee> auditedNfcPayees = [
  AuditedNfcPayee(
    id: '44444444-4444-4444-4444-444444444444',
    name: 'Rahul Sharma',
    ref: 'HDFC0001234',
    category: 'person',
  ),
  AuditedNfcPayee(
    id: '22222222-2222-2222-2222-222222222222',
    name: 'Priya Sharma (Guardian)',
    ref: 'priya@upi',
    category: 'person',
  ),
  AuditedNfcPayee(
    id: '21ec5e03-6c74-5328-a89a-4c7b9feb0e3b',
    name: 'BSES Rajdhani Electricity',
    ref: 'BSES-DL-98214',
    category: 'biller',
  ),
  AuditedNfcPayee(
    id: '2fb75ceb-909c-5fc5-9740-685305c52159',
    name: 'Delhi Jal Board Water',
    ref: 'DJB-WATER-4481',
    category: 'biller',
  ),
  AuditedNfcPayee(
    id: '6f753a58-20b2-51b8-a19c-44c4eb09632f',
    name: 'Indraprastha Gas Piped Gas',
    ref: 'IGL-PNG-88219',
    category: 'biller',
  ),
];

/// Canonical payload: {"v":1,"type":"vaniguard_pay","payee_id":"<uuid>","label":"<name>"}
/// Parser also accepts legacy amt payloads as optional.
class NfcCardPayload {
  final int v;
  final String type;
  final String payeeId;
  final String label;
  final int? amt; // optional legacy

  const NfcCardPayload({
    this.v = 1,
    this.type = 'vaniguard_pay',
    required this.payeeId,
    required this.label,
    this.amt,
  });

  Map<String, dynamic> toJson() => {
        'v': v,
        'type': type,
        'payee_id': payeeId,
        'label': label,
        if (amt != null) 'amt': amt,
      };

  static NfcCardPayload? fromRaw(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      if (decoded['type'] != 'vaniguard_pay') return null;
      final payeeId = decoded['payee_id']?.toString();
      final label = decoded['label']?.toString();
      if (payeeId == null || payeeId.trim().isEmpty || label == null || label.trim().isEmpty) {
        return null;
      }
      final v = decoded['v'] is int ? decoded['v'] as int : 1;
      final amt = decoded['amt'] is int
          ? decoded['amt'] as int
          : (decoded['amt'] != null ? int.tryParse(decoded['amt'].toString()) : null);
      return NfcCardPayload(
        v: v,
        type: 'vaniguard_pay',
        payeeId: payeeId.trim(),
        label: label.trim(),
        amt: amt,
      );
    } catch (_) {
      return null;
    }
  }

  String toCanonicalJson() {
    return jsonEncode({
      'v': 1,
      'type': 'vaniguard_pay',
      'payee_id': payeeId,
      'label': label,
    });
  }
}

class NfcService {
  /// Checks if NFC hardware is available and enabled
  static Future<bool> isAvailable() async {
    try {
      return await NfcManager.instance.isAvailable();
    } catch (e) {
      debugPrint('[NfcService] isAvailable error: $e');
      return false;
    }
  }

  /// Extracts string content from an NDEF record
  static String? extractStringFromRecord(NdefRecord record) {
    try {
      final payload = record.payload;
      if (payload.isEmpty) return null;

      // Check if standard NDEF text record
      if (record.typeNameFormat == TypeNameFormat.wellKnown &&
          record.type.length == 1 &&
          record.type[0] == 0x54) {
        final status = payload[0];
        final langLen = status & 0x3F;
        if (payload.length > 1 + langLen) {
          final textBytes = payload.sublist(1 + langLen);
          return utf8.decode(textBytes, allowMalformed: true);
        }
      }

      // Try UTF-8 fallback
      return utf8.decode(payload, allowMalformed: true);
    } catch (e) {
      debugPrint('[NfcService] Record decode error: $e');
      return null;
    }
  }

  /// Parses an NfcTag into an NfcCardPayload
  static NfcCardPayload? parseTag(NfcTag tag) {
    try {
      final ndef = NdefAndroid.from(tag);
      if (ndef == null) return null;
      final message = ndef.cachedNdefMessage;
      if (message == null || message.records.isEmpty) return null;

      for (final record in message.records) {
        final text = extractStringFromRecord(record);
        if (text != null && text.contains('vaniguard_pay')) {
          final payload = NfcCardPayload.fromRaw(text);
          if (payload != null) return payload;
        }
      }
      return null;
    } catch (e) {
      debugPrint('[NfcService] parseTag error: $e');
      return null;
    }
  }

  /// Writes an NfcCardPayload to an NDEF tag
  static Future<bool> writeTag(NfcTag tag, NfcCardPayload payload) async {
    try {
      final ndef = NdefAndroid.from(tag);
      if (ndef == null || !ndef.isWritable) {
        debugPrint('[NfcService] Tag is null or not writable');
        return false;
      }

      final jsonStr = payload.toCanonicalJson();
      final langBytes = ascii.encode('en');
      final textBytes = utf8.encode(jsonStr);

      final record = NdefRecord(
        typeNameFormat: TypeNameFormat.wellKnown,
        type: Uint8List.fromList([0x54]), // 'T'
        identifier: Uint8List(0),
        payload: Uint8List.fromList([
          langBytes.length,
          ...langBytes,
          ...textBytes,
        ]),
      );

      final message = NdefMessage(records: [record]);
      await ndef.writeNdefMessage(message);
      debugPrint('[NfcService] Wrote card payload: $jsonStr');
      return true;
    } catch (e) {
      debugPrint('[NfcService] writeTag error: $e');
      return false;
    }
  }
}

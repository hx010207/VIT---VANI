import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'nfc_service.dart';

typedef OnCardScannedCallback = void Function(NfcCardPayload payload);
typedef OnUnknownCardCallback = void Function();

class NfcBackgroundReader {
  static final NfcBackgroundReader _instance = NfcBackgroundReader._internal();
  factory NfcBackgroundReader() => _instance;
  NfcBackgroundReader._internal();

  bool _isListening = false;
  bool get isListening => _isListening;

  OnCardScannedCallback? onCardScanned;
  OnUnknownCardCallback? onUnknownCard;

  /// Start background NFC listening on Dashboard
  Future<void> startListening({
    required OnCardScannedCallback onCardScanned,
    required OnUnknownCardCallback onUnknownCard,
  }) async {
    this.onCardScanned = onCardScanned;
    this.onUnknownCard = onUnknownCard;

    if (_isListening) return;

    final available = await NfcService.isAvailable();
    if (!available) {
      debugPrint('[NfcBackgroundReader] NFC hardware not available or disabled');
      return;
    }

    try {
      _isListening = true;
      await NfcManager.instance.startSession(
        pollingOptions: {NfcPollingOption.iso14443, NfcPollingOption.iso15693},
        onDiscovered: (NfcTag tag) async {
          debugPrint('[NfcBackgroundReader] NFC Tag discovered');
          final payload = NfcService.parseTag(tag);
          if (payload != null) {
            debugPrint('[NfcBackgroundReader] Valid payload: ${payload.label} (${payload.payeeId})');
            this.onCardScanned?.call(payload);
          } else {
            debugPrint('[NfcBackgroundReader] Unrecognized or non-VaniGuard NFC tag');
            this.onUnknownCard?.call();
          }
        },
      );
      debugPrint('[NfcBackgroundReader] Session started successfully');
    } catch (e) {
      debugPrint('[NfcBackgroundReader] Failed to start NFC session: $e');
      _isListening = false;
    }
  }

  /// Stop NFC listening (e.g. on logout or screen dispose)
  Future<void> stopListening() async {
    if (!_isListening) return;
    try {
      await NfcManager.instance.stopSession();
      debugPrint('[NfcBackgroundReader] Session stopped');
    } catch (e) {
      debugPrint('[NfcBackgroundReader] Error stopping session: $e');
    } finally {
      _isListening = false;
    }
  }

  /// Simulate a card scan (for widget tests or devices without NFC tags)
  void simulateCardScan(NfcCardPayload payload) {
    debugPrint('[NfcBackgroundReader] Simulating card scan: ${payload.label}');
    onCardScanned?.call(payload);
  }

  /// Simulate an unknown card scan
  void simulateUnknownCard() {
    debugPrint('[NfcBackgroundReader] Simulating unknown card scan');
    onUnknownCard?.call();
  }
}

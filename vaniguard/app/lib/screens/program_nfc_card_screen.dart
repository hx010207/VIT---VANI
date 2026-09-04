import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nfc_manager/nfc_manager.dart';
import '../services/nfc_service.dart';
import '../services/nfc_background_reader.dart';
import '../theme/quiet_vault_theme.dart';

class ProgramNfcCardScreen extends StatefulWidget {
  const ProgramNfcCardScreen({super.key});

  @override
  State<ProgramNfcCardScreen> createState() => _ProgramNfcCardScreenState();
}

class _ProgramNfcCardScreenState extends State<ProgramNfcCardScreen> {
  late AuditedNfcPayee _selectedPayee;
  bool _isWriting = false;
  String _statusMessage = 'Select a payee and hold NFC card against the device.';
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    _selectedPayee = auditedNfcPayees.first;
  }

  @override
  void dispose() {
    if (_isWriting) {
      NfcManager.instance.stopSession();
    }
    super.dispose();
  }

  NfcCardPayload get _currentPayload => NfcCardPayload(
        payeeId: _selectedPayee.id,
        label: _selectedPayee.name,
      );

  Future<void> _startWriteSession() async {
    final available = await NfcService.isAvailable();
    if (!available) {
      setState(() {
        _statusMessage = 'NFC hardware not available or disabled on this device.';
        _isSuccess = false;
      });
      return;
    }

    setState(() {
      _isWriting = true;
      _isSuccess = false;
      _statusMessage = 'Hold NFC card near the back of the phone...';
    });

    try {
      await NfcManager.instance.startSession(
        pollingOptions: {NfcPollingOption.iso14443, NfcPollingOption.iso15693},
        onDiscovered: (NfcTag tag) async {
          final success = await NfcService.writeTag(tag, _currentPayload);
          if (mounted) {
            setState(() {
              _isWriting = false;
              _isSuccess = success;
              _statusMessage = success
                  ? 'Success! Card programmed for ${_selectedPayee.name}'
                  : 'Write failed. Tag may not be NDEF writable.';
            });
          }
          await NfcManager.instance.stopSession();
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isWriting = false;
          _isSuccess = false;
          _statusMessage = 'Error starting NFC session: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: QuietVaultColors.background,
      appBar: AppBar(
        backgroundColor: QuietVaultColors.background,
        elevation: 0,
        title: const Text(
          'Program NFC Card',
          style: TextStyle(
            color: QuietVaultColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: QuietVaultColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Instructions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: QuietVaultColors.darkSurfaceAlt,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: QuietVaultColors.amberAccent.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.nfc, color: QuietVaultColors.amberAccent, size: 28),
                  SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Program NFC Tap-and-Speak cards for quick, secure assisted payments.',
                      style: TextStyle(color: QuietVaultColors.textPrimary, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Select Payee
            const Text(
              'Select Payee',
              style: TextStyle(
                color: QuietVaultColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: QuietVaultColors.darkSurfaceAlt,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white24),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<AuditedNfcPayee>(
                  value: _selectedPayee,
                  isExpanded: true,
                  dropdownColor: QuietVaultColors.darkSurfaceAlt,
                  icon: const Icon(Icons.arrow_drop_down, color: QuietVaultColors.amberAccent),
                  items: auditedNfcPayees.map((payee) {
                    return DropdownMenuItem<AuditedNfcPayee>(
                      value: payee,
                      child: Text(
                        '${payee.name} (${payee.category})',
                        style: const TextStyle(color: QuietVaultColors.textPrimary, fontSize: 15),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedPayee = val;
                        _statusMessage = 'Ready to program for ${val.name}';
                        _isSuccess = false;
                      });
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Canonical JSON Payload Preview (Identity Only)
            const Text(
              'Payload Preview (Canonical Identity-Only)',
              style: TextStyle(
                color: QuietVaultColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white12),
              ),
              child: SelectableText(
                _currentPayload.toCanonicalJson(),
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  color: QuietVaultColors.amberAccent,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Write Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: QuietVaultColors.amberAccent,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _isWriting ? null : _startWriteSession,
                icon: _isWriting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                      )
                    : const Icon(Icons.nfc, size: 24),
                label: Text(
                  _isWriting ? 'Listening for tag...' : 'Hold Card to Write',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Simulate Card Scan button for tests/emulators
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: QuietVaultColors.amberAccent,
                  side: const BorderSide(color: QuietVaultColors.amberAccent),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  NfcBackgroundReader().simulateCardScan(_currentPayload);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Simulated NFC Tap: ${_selectedPayee.name}'),
                      backgroundColor: QuietVaultColors.darkSurfaceAlt,
                    ),
                  );
                },
                icon: const Icon(Icons.touch_app),
                label: const Text(
                  'Simulate Tap on Dashboard',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Status message
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _isSuccess
                    ? Colors.green.withValues(alpha: 0.15)
                    : QuietVaultColors.darkSurfaceAlt,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _isSuccess ? Colors.green : Colors.white12,
                ),
              ),
              child: Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _isSuccess ? Colors.greenAccent : QuietVaultColors.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 30),

            // Payee UUID Reference Table (for NFC Tools fallback)
            const Text(
              'Audited Live Payees Reference Table',
              style: TextStyle(
                color: QuietVaultColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Use with external NFC Tools app if programming physical cards directly:',
              style: TextStyle(color: QuietVaultColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            ...auditedNfcPayees.map((payee) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: QuietVaultColors.darkSurfaceAlt,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              payee.name,
                              style: const TextStyle(
                                color: QuietVaultColors.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              payee.id,
                              style: const TextStyle(
                                color: QuietVaultColors.amberAccent,
                                fontFamily: 'monospace',
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 18, color: QuietVaultColors.textSecondary),
                        tooltip: 'Copy UUID',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: payee.id));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Copied UUID for ${payee.name}'),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

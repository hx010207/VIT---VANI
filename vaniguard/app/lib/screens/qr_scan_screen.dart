/// PURPOSE: QR Code Scanner and Merchant / P2P UPI Payment screen.
/// ROLE IN SYSTEM: Scans camera QR or decodes vaniguard_receive payloads for phone-to-phone UPI transfers.
/// TALKS TO: app/lib/services/api_client.dart, app/lib/screens/transfer_held_screen.dart
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:vaniguard/l10n/app_localizations.dart';
import 'package:vaniguard/services/api_client.dart';
import 'package:vaniguard/theme/quiet_vault_theme.dart';
import 'package:vaniguard/widgets/accessible_button.dart';

class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );

  final TextEditingController _amountController = TextEditingController(text: '500');
  bool _isProcessing = false;
  bool _hasScanned = false;
  String? _detectedPayeeId;
  String? _detectedPayeeName;
  String? _detectedPayeeRef;
  String? _errorMessage;

  @override
  void dispose() {
    _scannerController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _processQrPayload(String rawValue) {
    if (_hasScanned) return;
    final trimmed = rawValue.trim();

    // 1. UPI URI format: upi://pay?pa=...&pn=...&am=...
    if (trimmed.startsWith('upi://pay')) {
      final uri = Uri.tryParse(trimmed);
      if (uri != null) {
        final pa = uri.queryParameters['pa'] ?? 'upi@bank';
        final pn = uri.queryParameters['pn'] ?? 'UPI Merchant';
        final am = uri.queryParameters['am'];
        setState(() {
          _hasScanned = true;
          _detectedPayeeId = pa;
          _detectedPayeeName = Uri.decodeComponent(pn);
          _detectedPayeeRef = pa;
          if (am != null && double.tryParse(am) != null) {
            _amountController.text = double.parse(am).toInt().toString();
          }
          _errorMessage = null;
        });
        return;
      }
    }

    // 2. VaniGuard JSON payload
    try {
      final data = jsonDecode(trimmed) as Map<String, dynamic>;
      if (data['type'] == 'vaniguard_receive' && data['account_id'] != null) {
        setState(() {
          _hasScanned = true;
          _detectedPayeeId = data['account_id'].toString();
          _detectedPayeeName = (data['name'] ?? 'Payee').toString();
          _detectedPayeeRef = (data['ref'] ?? data['phone'] ?? 'VaniGuard UPI').toString();
          if (data['amount'] != null) {
            _amountController.text = data['amount'].toString();
          }
          _errorMessage = null;
        });
        return;
      }
    } catch (_) {
      // Not JSON
    }

    // Invalid or unknown QR: toast Unrecognized QR with no crash
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Unrecognized QR'),
        backgroundColor: QuietVaultColors.danger,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _handlePayment() async {
    if (_detectedPayeeId == null) return;
    final inr = int.tryParse(_amountController.text.trim()) ?? 0;
    if (inr <= 0) {
      setState(() => _errorMessage = 'Please enter a valid amount');
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final accounts = await ApiClient.getAccounts();
      final sourceAcc = accounts.isNotEmpty ? accounts.first['id'].toString() : 'default_account';
      final idempotency = 'qr-transfer-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(9999)}';

      final res = await ApiClient.initiateTransfer(
        sourceAccountId: sourceAcc,
        payeeId: _detectedPayeeId!,
        amountPaise: inr * 100,
        idempotencyKey: idempotency,
        transcript: 'QR payment to $_detectedPayeeName for $inr rupees',
      );

      if (!mounted) return;

      if (res['state'] == 'HELD') {
        Navigator.pushReplacementNamed(context, '/transfer-held');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Paid INR $inr to $_detectedPayeeName successfully!'),
            backgroundColor: QuietVaultColors.success,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Payment failed: $e';
          _isProcessing = false;
        });
      }
    }
  }

  void _resetScanner() {
    setState(() {
      _hasScanned = false;
      _detectedPayeeId = null;
      _detectedPayeeName = null;
      _detectedPayeeRef = null;
      _errorMessage = null;
    });
  }

  void _showManualInputDialog() {
    final textCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Enter QR Payload', style: TextStyle(color: QuietVaultColors.textPrimary)),
        content: TextField(
          controller: textCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Paste QR JSON code here...',
            filled: true,
            fillColor: Color(0xFF2C2C2C),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: QuietVaultColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: QuietVaultColors.primary,
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _processQrPayload(textCtrl.text.trim());
            },
            child: const Text('Decode'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: QuietVaultColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(l10n?.qrScanTitle ?? 'Scan UPI QR Code'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: QuietVaultColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on, color: QuietVaultColors.amberAccent),
            tooltip: 'Simulate Rahul QR',
            onPressed: () {
              _processQrPayload(jsonEncode({
                'v': 1,
                'type': 'vaniguard_receive',
                'account_id': '44444444-4444-4444-4444-444444444444',
                'name': 'Rahul Sharma',
                'ref': 'rahul.sharma@okaxis',
              }));
            },
          ),
          IconButton(
            icon: const Icon(Icons.keyboard_alt_outlined, color: QuietVaultColors.textSecondary),
            tooltip: 'Manual QR Input',
            onPressed: _showManualInputDialog,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Scanner viewfinder or scanned status
              if (!_hasScanned)
                Container(
                  height: 280,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: QuietVaultColors.primary, width: 2),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      MobileScanner(
                        controller: _scannerController,
                        onDetect: (capture) {
                          for (final barcode in capture.barcodes) {
                            if (barcode.rawValue != null) {
                              _processQrPayload(barcode.rawValue!);
                              break;
                            }
                          }
                        },
                      ),
                      Positioned(
                        bottom: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.75),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Point camera at VaniGuard Receive QR',
                            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: QuietVaultColors.amberAccent, width: 2),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.check_circle, color: QuietVaultColors.success, size: 48),
                      const SizedBox(height: 12),
                      const Text(
                        'QR Code Detected',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: QuietVaultColors.textPrimary),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _detectedPayeeName ?? 'Payee',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: QuietVaultColors.amberAccent),
                      ),
                      Text(
                        _detectedPayeeRef ?? '',
                        style: const TextStyle(fontSize: 14, color: QuietVaultColors.textSecondary),
                      ),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        icon: const Icon(Icons.refresh, size: 18, color: QuietVaultColors.amberAccent),
                        label: const Text('Scan Another Code', style: TextStyle(color: QuietVaultColors.amberAccent)),
                        onPressed: _resetScanner,
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 20),

              // Quick action simulators for automated & manual verification
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  OutlinedButton(
                    onPressed: () {
                      _processQrPayload(jsonEncode({
                        'v': 1,
                        'type': 'vaniguard_receive',
                        'account_id': '44444444-4444-4444-4444-444444444444',
                        'name': 'Rahul Sharma',
                        'ref': 'rahul.sharma@okaxis',
                      }));
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: QuietVaultColors.amberAccent),
                    ),
                    child: const Text('Test Rahul QR', style: TextStyle(color: QuietVaultColors.amberAccent)),
                  ),
                  OutlinedButton(
                    onPressed: () {
                      _processQrPayload('https://random-website.example.com');
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: QuietVaultColors.textSecondary),
                    ),
                    child: const Text('Test Invalid QR', style: TextStyle(color: QuietVaultColors.textSecondary)),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              if (_hasScanned) ...[
                // Payment Form
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: QuietVaultColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: QuietVaultColors.primary.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Transfer Amount (INR):',
                        style: TextStyle(fontSize: 14, color: QuietVaultColors.textSecondary),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: QuietVaultColors.primary),
                        decoration: InputDecoration(
                          prefixText: 'INR ',
                          prefixStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: QuietVaultColors.primary),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          filled: true,
                          fillColor: const Color(0xFF2C2C2C),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: QuietVaultColors.danger, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ),

                if (_isProcessing)
                  const Center(child: CircularProgressIndicator())
                else
                  AccessibleButton(
                    label: 'Confirm & Transfer',
                    semanticsHint: 'Executes UPI transfer to scanned payee',
                    icon: Icons.check_circle_outline,
                    onPressed: _handlePayment,
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

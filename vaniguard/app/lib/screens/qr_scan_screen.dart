/// PURPOSE: QR Code Scanner and Merchant UPI Payment screen.
/// ROLE IN SYSTEM: Allows scanning or selecting merchant QR codes for contactless voice-verified UPI payments.
/// TALKS TO: app/lib/services/api_client.dart, app/lib/screens/banking_dashboard_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';
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
  final String _selectedMerchant = 'Rohan Medical Store';
  final String _merchantUpi = 'rohanmed@oksbi';
  final int _amountInr = 350;
  bool _isProcessing = false;

  Future<void> _handlePayment() async {
    setState(() => _isProcessing = true);
    try {
      final accounts = await ApiClient.getAccounts();
      final sourceAcc = accounts.isNotEmpty ? accounts.first['id'].toString() : 'default_account';
      final idempotency = 'qr-transfer-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(9999)}';

      final res = await ApiClient.initiateTransfer(
        sourceAccountId: sourceAcc,
        payeeId: '44444444-4444-4444-4444-444444444444',
        amountPaise: _amountInr * 100,
        idempotencyKey: idempotency,
        transcript: 'QR payment to $_selectedMerchant for $_amountInr rupees',
      );

      if (mounted) {
        if (res['state'] == 'HELD') {
          Navigator.pushReplacementNamed(context, '/transfer-held');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Paid ₹$_amountInr to $_selectedMerchant successfully!'),
              backgroundColor: QuietVaultColors.success,
            ),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment failed: $e'),
            backgroundColor: QuietVaultColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
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
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Simulated QR Viewfinder
              Container(
                height: 240,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: QuietVaultColors.primary, width: 2),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      Icons.qr_code_2_rounded,
                      size: 140,
                      color: QuietVaultColors.primary.withOpacity(0.7),
                    ),
                    Positioned(
                      bottom: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Align QR code inside viewfinder',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Scanned Merchant Card
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
                      'Detected Merchant QR:',
                      style: TextStyle(fontSize: 12, color: QuietVaultColors.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _selectedMerchant,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: QuietVaultColors.textPrimary,
                      ),
                    ),
                    Text(
                      'UPI ID: $_merchantUpi',
                      style: const TextStyle(fontSize: 13, color: QuietVaultColors.textSecondary),
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Payment Amount:',
                          style: TextStyle(fontSize: 14, color: QuietVaultColors.textSecondary),
                        ),
                        Text(
                          '₹$_amountInr',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: QuietVaultColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              if (_isProcessing)
                const Center(child: CircularProgressIndicator())
              else
                AccessibleButton(
                  label: 'Confirm & Pay ₹$_amountInr',
                  semanticsHint: 'Executes UPI QR payment',
                  icon: Icons.check_circle_outline,
                  onPressed: _handlePayment,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

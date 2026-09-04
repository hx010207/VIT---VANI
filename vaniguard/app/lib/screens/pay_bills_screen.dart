/// PURPOSE: Utility bill payment screen (Electricity, Water, LPG Gas, Mobile Recharge).
/// ROLE IN SYSTEM: Provides quick bill settlement with voice confirmation and account debiting.
/// TALKS TO: app/lib/services/api_client.dart, app/lib/screens/banking_dashboard_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:vaniguard/l10n/app_localizations.dart';
import 'package:vaniguard/services/api_client.dart';
import 'package:vaniguard/theme/quiet_vault_theme.dart';
import 'package:vaniguard/widgets/accessible_button.dart';

class PayBillsScreen extends StatefulWidget {
  const PayBillsScreen({super.key});

  @override
  State<PayBillsScreen> createState() => _PayBillsScreenState();
}

class _PayBillsScreenState extends State<PayBillsScreen> {
  final List<Map<String, dynamic>> _bills = [
    {
      'id': 'bill_elec',
      'title': 'BSES Rajdhani Power Ltd',
      'category': 'Electricity',
      'consumer_id': 'CA #102938475',
      'amount': 1250,
      'due_date': 'Due in 4 days',
      'icon': Icons.bolt_rounded,
    },
    {
      'id': 'bill_water',
      'title': 'Delhi Jal Board',
      'category': 'Water',
      'consumer_id': 'KNO #9847291',
      'amount': 420,
      'due_date': 'Due in 7 days',
      'icon': Icons.water_drop_rounded,
    },
    {
      'id': 'bill_gas',
      'title': 'Indane LPG Gas Cylinder',
      'category': 'LPG Gas',
      'consumer_id': 'Consumer #672910',
      'amount': 903,
      'due_date': 'Book refill',
      'icon': Icons.local_fire_department_rounded,
    },
    {
      'id': 'bill_mobile',
      'title': 'Airtel Prepaid Mobile',
      'category': 'Mobile Recharge',
      'consumer_id': '+91 98765 43210',
      'amount': 299,
      'due_date': 'Expiring tomorrow',
      'icon': Icons.phone_android_rounded,
    },
  ];

  bool _isPaying = false;

  Future<void> _payBill(Map<String, dynamic> bill) async {
    setState(() => _isPaying = true);
    try {
      final accounts = await ApiClient.getAccounts();
      final sourceAcc = accounts.isNotEmpty ? accounts.first['id'].toString() : 'default_account';
      final idempotency = 'bill-payment-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(9999)}';

      final res = await ApiClient.initiateTransfer(
        sourceAccountId: sourceAcc,
        payeeId: '44444444-4444-4444-4444-444444444444',
        amountPaise: (bill['amount'] as int) * 100,
        idempotencyKey: idempotency,
        transcript: 'Pay ${bill['category']} bill for ₹${bill['amount']}',
      );

      if (mounted) {
        if (res['state'] == 'HELD') {
          Navigator.pushNamed(context, '/transfer-held');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Paid ₹${bill['amount']} for ${bill['title']} successfully!'),
              backgroundColor: QuietVaultColors.success,
            ),
          );
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
        setState(() => _isPaying = false);
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
        title: Text(l10n?.billsTitle ?? 'Bill Payments'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: QuietVaultColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: _isPaying
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: _bills.length,
                itemBuilder: (context, index) {
                  final bill = _bills[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 14),
                    color: QuietVaultColors.surfaceAlt,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: QuietVaultColors.primary.withOpacity(0.2),
                                child: Icon(bill['icon'] as IconData, color: QuietVaultColors.primary),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      bill['title'] as String,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: QuietVaultColors.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      '${bill['category']} - ${bill['consumer_id']}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: QuietVaultColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '₹${bill['amount']}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: QuietVaultColors.primary,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                bill['due_date'] as String,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: QuietVaultColors.inkSecondary,
                                ),
                              ),
                              AccessibleButton(
                                label: l10n?.payBill ?? 'Pay Bill',
                                semanticsHint: 'Pay ${bill['title']}',
                                onPressed: () => _payBill(bill),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

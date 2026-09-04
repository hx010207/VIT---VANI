/// PURPOSE: Beneficiary and Payee directory screen with search, verification badges, and direct transfer modal.
/// ROLE IN SYSTEM: Allows account holders to search 100+ seeded contacts and initiate payments with Active Call Guard checks.
/// TALKS TO: app/lib/services/api_client.dart, app/lib/screens/transfer_held_screen.dart
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:vaniguard/l10n/app_localizations.dart';
import 'package:vaniguard/services/api_client.dart';
import 'package:vaniguard/theme/quiet_vault_theme.dart';
import 'package:vaniguard/widgets/accessible_button.dart';

class PayeesScreen extends StatefulWidget {
  const PayeesScreen({super.key});

  @override
  State<PayeesScreen> createState() => _PayeesScreenState();
}

class _PayeesScreenState extends State<PayeesScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _allPayees = [];
  List<dynamic> _filteredPayees = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Active Call Guard simulator flag
  bool _simulatedCallActive = false;

  @override
  void initState() {
    super.initState();
    _loadPayees();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPayees() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final payees = await ApiClient.getPayees();
      setState(() {
        _allPayees = payees;
        _filteredPayees = payees;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Could not load payees: $e';
        _isLoading = false;
      });
    }
  }

  void _filterPayees(String query) {
    final q = query.toLowerCase().trim();
    setState(() {
      if (q.isEmpty) {
        _filteredPayees = _allPayees;
      } else {
        _filteredPayees = _allPayees.where((p) {
          final name = (p['name'] ?? '').toString().toLowerCase();
          final ref = (p['account_ref'] ?? '').toString().toLowerCase();
          final nick = (p['nickname'] ?? '').toString().toLowerCase();
          return name.contains(q) || ref.contains(q) || nick.contains(q);
        }).toList();
      }
    });
  }

  void _showPayeeQrDialog(Map<String, dynamic> payee) {
    final name = (payee['name'] ?? 'Payee').toString();
    final payeeId = (payee['id'] ?? '44444444-4444-4444-4444-444444444444').toString();
    final ref = (payee['account_ref'] ?? payee['masked_account'] ?? 'UPI Payee').toString();

    final qrPayload = jsonEncode({
      'v': 1,
      'type': 'vaniguard_receive',
      'account_id': payeeId,
      'name': name,
      'ref': ref,
    });

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Receive QR Code',
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: QuietVaultColors.textPrimary,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Scan from phone B to pay $name instantly',
                style: const TextStyle(fontSize: 14, color: QuietVaultColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: QuietVaultColors.amberAccent.withOpacity(0.35),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: QrImageView(
                  data: qrPayload,
                  version: QrVersions.auto,
                  size: 220.0,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: QuietVaultColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                ref,
                style: const TextStyle(fontSize: 14, color: QuietVaultColors.amberAccent),
              ),
              const SizedBox(height: 20),
              AccessibleButton(
                label: 'Close',
                semanticsHint: 'Closes payee QR dialog',
                isSecondary: true,
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openTransferModal(Map<String, dynamic> payee) {
    final amountController = TextEditingController(text: '500');
    final noteController = TextEditingController();
    bool isSubmitting = false;
    String? modalError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: QuietVaultColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Pay ${payee['name'] ?? 'Payee'}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: QuietVaultColors.textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              Text(
                'UPI / A/C: ${payee['account_ref'] ?? payee['masked_account'] ?? ''}',
                style: const TextStyle(fontSize: 13, color: QuietVaultColors.textSecondary),
              ),
              const SizedBox(height: 16),

              if (_simulatedCallActive) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: QuietVaultColors.danger.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: QuietVaultColors.danger.withOpacity(0.5)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.phone_in_talk, color: QuietVaultColors.danger, size: 22),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Active Call Guard: Call in progress. Transactions require extra security review.',
                          style: TextStyle(fontSize: 12, color: QuietVaultColors.danger, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Amount (INR)',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: noteController,
                decoration: const InputDecoration(
                  labelText: 'Note / Voice Transcript (optional)',
                  hintText: 'e.g. For groceries or medicines',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              if (modalError != null) ...[
                Text(modalError!, style: const TextStyle(color: QuietVaultColors.danger, fontSize: 13)),
                const SizedBox(height: 12),
              ],

              if (isSubmitting)
                const Center(child: CircularProgressIndicator())
              else
                AccessibleButton(
                  label: 'Send Money',
                  semanticsHint: 'Executes transfer to this beneficiary',
                  icon: Icons.send_rounded,
                  onPressed: () async {
                    final inr = int.tryParse(amountController.text.trim()) ?? 0;
                    if (inr <= 0) {
                      setModalState(() => modalError = 'Please enter a valid amount');
                      return;
                    }

                    // Active Call Guard interception
                    if (_simulatedCallActive) {
                      final proceed = await showDialog<bool>(
                        context: ctx,
                        builder: (dCtx) => AlertDialog(
                          backgroundColor: QuietVaultColors.surfaceAlt,
                          title: const Text('Active Phone Call Detected', style: TextStyle(color: QuietVaultColors.textPrimary)),
                          content: const Text(
                            'You are currently on a phone call. Scammers frequently coerce victims to transfer funds during calls. Do you want to proceed under Guardian protection?',
                            style: TextStyle(color: QuietVaultColors.textSecondary, height: 1.3),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dCtx, false),
                              child: const Text('Cancel Payment'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(dCtx, true),
                              child: const Text('Proceed with Review'),
                            ),
                          ],
                        ),
                      );
                      if (proceed != true) return;
                    }

                    setModalState(() => isSubmitting = true);
                    try {
                      final accounts = await ApiClient.getAccounts();
                      final sourceAcc = accounts.isNotEmpty ? accounts.first['id'].toString() : 'default_account';
                      final idempotency = 'payee-transfer-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(9999)}';

                      final transfer = await ApiClient.initiateTransfer(
                        sourceAccountId: sourceAcc,
                        payeeId: payee['id'].toString(),
                        amountPaise: inr * 100,
                        idempotencyKey: idempotency,
                        transcript: noteController.text.isNotEmpty ? noteController.text : null,
                        secondVoiceDetected: _simulatedCallActive,
                        voiceStressScore: _simulatedCallActive ? 80 : 20,
                      );

                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                      }

                      if (transfer['state'] == 'HELD') {
                        if (mounted) {
                          Navigator.pushNamed(context, '/transfer-held');
                        }
                      } else {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Payment of ₹$inr to ${payee['name']} completed successfully!'),
                              backgroundColor: QuietVaultColors.success,
                            ),
                          );
                        }
                      }
                    } catch (e) {
                      setModalState(() {
                        isSubmitting = false;
                        modalError = 'Payment failed: $e';
                      });
                    }
                  },
                ),
            ],
          ),
        ),
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
        title: Text(l10n?.payeesTitle ?? 'Beneficiaries & Payees'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: QuietVaultColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // Demo QR action for phone-to-phone testing
          IconButton(
            icon: const Icon(Icons.qr_code_2, color: QuietVaultColors.amberAccent),
            tooltip: 'Show Demo QR (Rahul Sharma)',
            onPressed: () {
              final rahul = _allPayees.firstWhere(
                (p) => (p['name'] ?? '').toString().toLowerCase().contains('rahul'),
                orElse: () => {
                  'id': '44444444-4444-4444-4444-444444444444',
                  'name': 'Rahul Sharma',
                  'account_ref': 'rahul.sharma@okaxis',
                  'phone': '+919876543220',
                },
              );
              _showPayeeQrDialog(Map<String, dynamic>.from(rahul));
            },
          ),
          // Active call guard simulation toggle
          IconButton(
            icon: Icon(
              _simulatedCallActive ? Icons.phone_in_talk : Icons.phone_outlined,
              color: _simulatedCallActive ? QuietVaultColors.danger : QuietVaultColors.textSecondary,
            ),
            tooltip: 'Simulate Active Phone Call',
            onPressed: () {
              setState(() => _simulatedCallActive = !_simulatedCallActive);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_simulatedCallActive
                      ? 'Simulated active call ON (Active Call Guard will trigger on transfers)'
                      : 'Simulated active call OFF'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Active Call Banner if enabled
            if (_simulatedCallActive)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: QuietVaultColors.danger.withOpacity(0.2),
                child: const Row(
                  children: [
                    Icon(Icons.phone_in_talk, color: QuietVaultColors.danger, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Active Call Guard Active: Testing high-risk call protection',
                        style: TextStyle(color: QuietVaultColors.danger, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                onChanged: _filterPayees,
                decoration: InputDecoration(
                  hintText: l10n?.searchPayees ?? 'Search payees by name or UPI...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _filterPayees('');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),

            // Payees Count
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_filteredPayees.length} Contacts',
                    style: const TextStyle(fontSize: 13, color: QuietVaultColors.textSecondary, fontWeight: FontWeight.w600),
                  ),
                  if (_allPayees.isNotEmpty)
                    Text(
                      'Live Supabase Directory',
                      style: TextStyle(fontSize: 12, color: QuietVaultColors.primary.withOpacity(0.8)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // List of Payees
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(_errorMessage!, style: const TextStyle(color: QuietVaultColors.danger)),
                              const SizedBox(height: 12),
                              ElevatedButton(onPressed: _loadPayees, child: const Text('Retry')),
                            ],
                          ),
                        )
                      : _filteredPayees.isEmpty
                          ? const Center(
                              child: Text(
                                'No matching beneficiaries found',
                                style: TextStyle(color: QuietVaultColors.textSecondary),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _filteredPayees.length,
                              itemBuilder: (context, index) {
                                final p = _filteredPayees[index] as Map<String, dynamic>;
                                final isVerified = p['verified'] == true;
                                final name = p['name'] ?? 'Unknown Payee';
                                final ref = p['account_ref'] ?? p['masked_account'] ?? '';

                                return Card(
                                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                  color: QuietVaultColors.surfaceAlt,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: QuietVaultColors.primary.withOpacity(0.2),
                                      child: Text(
                                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                                        style: const TextStyle(
                                          color: QuietVaultColors.primary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    title: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: QuietVaultColors.textPrimary,
                                            ),
                                          ),
                                        ),
                                        if (isVerified)
                                          const Icon(Icons.verified, color: Colors.blueAccent, size: 16)
                                        else
                                          const Icon(Icons.shield_outlined, color: Colors.grey, size: 16),
                                      ],
                                    ),
                                    subtitle: Text(
                                      ref,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: QuietVaultColors.textSecondary,
                                      ),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.qr_code_2, color: QuietVaultColors.amberAccent, size: 26),
                                          tooltip: 'Show QR Code',
                                          onPressed: () => _showPayeeQrDialog(p),
                                        ),
                                        const SizedBox(width: 4),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: QuietVaultColors.primary,
                                            foregroundColor: Colors.black,
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          onPressed: () => _openTransferModal(p),
                                          child: const Text('Pay', style: TextStyle(fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

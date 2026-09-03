import 'package:flutter/material.dart';
import 'package:vaniguard/theme/quiet_vault_theme.dart';
import 'package:vaniguard/widgets/accessible_button.dart';

class TrustedContactPortalScreen extends StatefulWidget {
  const TrustedContactPortalScreen({super.key});

  @override
  State<TrustedContactPortalScreen> createState() => _TrustedContactPortalScreenState();
}

class _TrustedContactPortalScreenState extends State<TrustedContactPortalScreen> {
  bool _hasAttested = false;
  bool _resolved = false;
  String _resolutionAction = "";

  void _approveTransfer() {
    if (!_hasAttested) return;
    setState(() {
      _resolved = true;
      _resolutionAction = "APPROVED";
    });
  }

  void _denyTransfer() {
    setState(() {
      _resolved = true;
      _resolutionAction = "DENIED";
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_resolved) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Trusted Contact Resolution"),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  _resolutionAction == "APPROVED" ? Icons.check_circle_outline : Icons.cancel_outlined,
                  color: _resolutionAction == "APPROVED" ? QuietVaultColors.success : QuietVaultColors.danger,
                  size: 72,
                ),
                const SizedBox(height: 24),
                Text(
                  _resolutionAction == "APPROVED" ? "Transfer Authorized" : "Transfer Blocked",
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  _resolutionAction == "APPROVED"
                      ? "Your out-of-band voice attestation has been immutably logged with timestamp. The transfer is now settled."
                      : "You have denied this transfer due to potential coercion risk. The transaction is cancelled and funds remain safe.",
                  style: const TextStyle(fontSize: 18, height: 1.5, color: QuietVaultColors.inkSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 36),
                AccessibleButton(
                  label: "Done",
                  semanticsHint: "Dismiss confirmation and close",
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Trusted Contact Portal"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "Pending Safety Approvals",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                "As an authorized Trusted Contact, you are requested to verify transfers held under VaniGuard's Coercion Protection Protocol.",
                style: TextStyle(fontSize: 18, color: QuietVaultColors.inkSecondary),
              ),
              const SizedBox(height: 28),

              // Pending Transfer Card
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: isDark ? QuietVaultColors.darkSurfaceAlt : QuietVaultColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: QuietVaultColors.accent, width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text("Account Holder: Asha Sharma", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                    SizedBox(height: 12),
                    Text("Payee: Rahul Sharma", style: TextStyle(fontSize: 18)),
                    SizedBox(height: 6),
                    Text("Account: ...9921", style: TextStyle(fontSize: 18)),
                    SizedBox(height: 6),
                    Text("Transfer Amount: INR 10,000", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: QuietVaultColors.accent)),
                    SizedBox(height: 12),
                    Text(
                      "Data Protection Notice: Balances and full account numbers are never disclosed in trusted contact notifications.",
                      style: TextStyle(fontSize: 14, color: QuietVaultColors.inkSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Mandatory Attestation Checkbox
              Semantics(
                label: "Attestation checkbox. I confirm direct out-of-band voice contact with Asha Sharma.",
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? QuietVaultColors.darkSurfaceAlt : QuietVaultColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Checkbox(
                        value: _hasAttested,
                        activeColor: QuietVaultColors.primary,
                        onChanged: (val) {
                          setState(() {
                            _hasAttested = val ?? false;
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          "I attest that I have established direct voice contact out-of-band with the account holder to verify their safety and intent.",
                          style: TextStyle(fontSize: 16, height: 1.4, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Approve Button (requires attestation)
              AccessibleButton(
                label: "Approve Transfer",
                semanticsHint: "Authorizes the transfer following out-of-band voice verification",
                icon: Icons.check,
                onPressed: _hasAttested ? _approveTransfer : null,
              ),
              const SizedBox(height: 16),

              // Deny Button
              AccessibleButton(
                label: "Deny Transfer (Suspected Coercion)",
                semanticsHint: "Denies this transfer and cancels the transaction to safeguard funds",
                isDanger: true,
                icon: Icons.block,
                onPressed: _denyTransfer,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

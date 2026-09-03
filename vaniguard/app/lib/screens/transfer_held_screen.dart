/// PURPOSE: Protective intervention screen displayed when risk triggers CIRCUIT_BREAK.
/// ROLE IN SYSTEM: Displays mandated bilingual calm copy, cooling countdown, and cancellation button.
/// TALKS TO: app/lib/router.dart, app/lib/widgets/accessible_button.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:vaniguard/theme/quiet_vault_theme.dart';
import 'package:vaniguard/widgets/accessible_button.dart';

class TransferHeldScreen extends StatefulWidget {
  const TransferHeldScreen({super.key});

  @override
  State<TransferHeldScreen> createState() => _TransferHeldScreenState();
}

class _TransferHeldScreenState extends State<TransferHeldScreen> {
  int _remainingSeconds = 1800; // 30-minute cooling window
  Timer? _countdownTimer;
  bool _isCancelled = false;

  @override
  void initState() {
    super.initState();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  String _formatTime(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _cancelTransfer() {
    setState(() {
      _isCancelled = true;
      _countdownTimer?.cancel();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isCancelled) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Transfer Status"),
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
                const Icon(Icons.check_circle_outline, color: QuietVaultColors.success, size: 72),
                const SizedBox(height: 24),
                const Text(
                  "Transfer Cancelled",
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  "Nothing has left your account. The transaction has been safely removed and your balance is completely intact.",
                  style: TextStyle(fontSize: 20, height: 1.5, color: QuietVaultColors.inkSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 36),
                AccessibleButton(
                  label: "Return to Banking Home",
                  semanticsHint: "Navigates back to the main banking dashboard",
                  onPressed: () {
                    Navigator.pushNamedAndRemoveUntil(context, "/", (route) => false);
                  },
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Security Hold"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Mandated Circuit Break Reassurance Card
              Semantics(
                liveRegion: true,
                label: "Safety Notice: For your safety, we are holding this transfer for a moment. Take your time. Nothing has left your account. If you are being pressured by anyone on a call, we can help. You may also confirm this transfer with your trusted contact.",
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDark ? QuietVaultColors.darkSurfaceAlt : QuietVaultColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: QuietVaultColors.accent, width: 2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.shield_outlined, color: QuietVaultColors.accent, size: 32),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "Transfer Held for Safety",
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "For your safety, we are holding this transfer for a moment. Take your time. Nothing has left your account. If you are being pressured by anyone on a call, we can help. You may also confirm this transfer with your trusted contact.",
                        style: TextStyle(fontSize: 19, height: 1.5),
                      ),
                      const SizedBox(height: 12),
                      const Divider(),
                      const SizedBox(height: 12),
                      const Text(
                        "आपकी सुरक्षा के लिए, हम इस ट्रांसफर को एक क्षण के लिए रोक रहे हैं। जल्दी करने की आवश्यकता नहीं है। आपके खाते से अभी कुछ नहीं गया है। यदि कोई आपको कॉल पर दबाव डाल रहा है, तो हम सहायता कर सकते हैं। आप अपने विश्वसनीय संपर्क से भी इस ट्रांसफर की पुष्टि कर सकते हैं।",
                        style: TextStyle(fontSize: 18, height: 1.5, color: QuietVaultColors.inkSecondary),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Cooling Window Timer Card
              Semantics(
                label: "Cooling window remaining: ${_remainingSeconds ~/ 60} minutes",
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: isDark ? QuietVaultColors.darkSurfaceAlt : QuietVaultColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Safety Cooling Window",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        _formatTime(_remainingSeconds),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: QuietVaultColors.accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Transaction Summary Card (Data Minimization: Masked details, no balance)
              Semantics(
                label: "Held transfer details: Amount 10,000 rupees to payee Rahul Sharma, account ending in 9921",
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? QuietVaultColors.darkSurfaceAlt : QuietVaultColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        "Transfer Details",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                      SizedBox(height: 12),
                      Text("Payee: Rahul Sharma", style: TextStyle(fontSize: 18)),
                      SizedBox(height: 6),
                      Text("Account: ...9921", style: TextStyle(fontSize: 18)),
                      SizedBox(height: 6),
                      Text("Amount: INR 10,000", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Trusted Contact Status
              Semantics(
                label: "Trusted contact status: Notification sent to Priya Sharma. Waiting for out-of-band voice confirmation.",
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? QuietVaultColors.darkSurfaceAlt : QuietVaultColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.phone_in_talk, color: QuietVaultColors.primary, size: 28),
                      SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          "Trusted Contact (Priya Sharma) has been notified. She will confirm by phone with you directly.",
                          style: TextStyle(fontSize: 17, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 36),

              // Cancel Action (Immediate relief)
              AccessibleButton(
                label: "Cancel Transfer Now",
                semanticsHint: "Cancels this transfer immediately. Zero rupees will leave your account.",
                isDanger: true,
                icon: Icons.cancel,
                onPressed: _cancelTransfer,
              ),
              const SizedBox(height: 16),

              AccessibleButton(
                label: "View Security Signal Breakdown",
                semanticsHint: "Inspect transparent risk signals explaining this hold",
                isSecondary: true,
                onPressed: () {
                  Navigator.pushNamed(context, "/risk-monitor");
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

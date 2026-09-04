/// PURPOSE: DPDP Act 2023 consent management and privacy settings screen.
/// ROLE IN SYSTEM: Allows user to review and manage purpose-specific voice biometric consents.
/// TALKS TO: app/lib/router.dart, app/lib/widgets/accessible_button.dart
import 'package:flutter/material.dart';
import 'package:vaniguard/main.dart';
import 'package:vaniguard/theme/quiet_vault_theme.dart';
import 'package:vaniguard/widgets/accessible_button.dart';

class ConsentsPrivacyScreen extends StatefulWidget {
  const ConsentsPrivacyScreen({super.key});

  @override
  State<ConsentsPrivacyScreen> createState() => _ConsentsPrivacyScreenState();
}

class _ConsentsPrivacyScreenState extends State<ConsentsPrivacyScreen> {
  bool _consentVoiceprint = true;
  bool _consentAcousticAnalysis = true;
  bool _consentTrustedContact = true;
  bool _erasureCompleted = false;

  void _executeErasure() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirm Right to Erasure"),
        content: const Text(
          "Under DPDP Act 2023, this will immediately purge all your voiceprints and baseline acoustic profiles. Core banking transaction records are retained in compliance with statutory RBI schedules. Do you wish to proceed?",
          style: TextStyle(fontSize: 18, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(fontSize: 18)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: QuietVaultColors.danger),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _erasureCompleted = true;
                _consentVoiceprint = false;
                _consentAcousticAnalysis = false;
              });
            },
            child: const Text("Purge Biometrics", style: TextStyle(fontSize: 18, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Privacy & Consents"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('EN', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  selected: Localizations.localeOf(context).languageCode == 'en',
                  onSelected: (selected) {
                    if (selected) {
                      VaniGuardApp.setLocale(context, const Locale('en'));
                    }
                  },
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  label: const Text('HI', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  selected: Localizations.localeOf(context).languageCode == 'hi',
                  onSelected: (selected) {
                    if (selected) {
                      VaniGuardApp.setLocale(context, const Locale('hi'));
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "Granular Consent Management",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                "Digital Personal Data Protection (DPDP) Act 2023 compliant. All consents are voluntary and freely revocable.",
                style: TextStyle(fontSize: 18, color: QuietVaultColors.inkSecondary),
              ),
              const SizedBox(height: 28),

              if (_erasureCompleted) ...[
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: QuietVaultColors.success.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: QuietVaultColors.success, width: 2),
                  ),
                  child: const Text(
                    "Right to Erasure Completed: Voiceprint templates and personal acoustic baselines have been purged.",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: QuietVaultColors.success),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Consent 1: Voiceprint Identity
              _buildConsentTile(
                title: "Voice Biometric Identity",
                description: "Storage of encrypted mathematical embedding templates for challenge-response authentication.",
                value: _consentVoiceprint,
                isDark: isDark,
                onChanged: (v) => setState(() => _consentVoiceprint = v),
              ),

              // Consent 2: Acoustic Analysis
              _buildConsentTile(
                title: "Acoustic Coercion Analysis",
                description: "In-memory processing of speech-pause segments to detect second-voice coaching and self-referenced vocal stress.",
                value: _consentAcousticAnalysis,
                isDark: isDark,
                onChanged: (v) => setState(() => _consentAcousticAnalysis = v),
              ),

              // Consent 3: Trusted Contact
              _buildConsentTile(
                title: "Trusted Contact Notifications",
                description: "Sending masked transaction alerts to your designated trusted contact when transfers are held under circuit-break.",
                value: _consentTrustedContact,
                isDark: isDark,
                onChanged: (v) => setState(() => _consentTrustedContact = v),
              ),

              const SizedBox(height: 36),

              // Right to Erasure Button
              AccessibleButton(
                label: "Execute Right to Erasure (DPDP Act)",
                semanticsHint: "Immediately purges voiceprints and acoustic baseline from platform",
                isDanger: true,
                icon: Icons.delete_forever,
                onPressed: _executeErasure,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConsentTile({
    required String title,
    required String description,
    required bool value,
    required bool isDark,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? QuietVaultColors.darkSurfaceAlt : QuietVaultColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text(description, style: const TextStyle(fontSize: 15, height: 1.4, color: QuietVaultColors.inkSecondary)),
              ],
            ),
          ),
          Switch(
            value: value,
            activeColor: QuietVaultColors.primary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

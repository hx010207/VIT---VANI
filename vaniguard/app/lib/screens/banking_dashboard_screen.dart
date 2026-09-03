/// PURPOSE: Main banking dashboard display showing balance in paise and recent activity.
/// ROLE IN SYSTEM: Primary interface presenting account status and launching voice banking sessions.
/// TALKS TO: app/lib/router.dart, app/lib/widgets/accessible_button.dart
import 'package:flutter/material.dart';
import 'package:vaniguard/l10n/app_localizations.dart';
import 'package:vaniguard/theme/quiet_vault_theme.dart';
import 'package:vaniguard/widgets/accessible_button.dart';

class BankingDashboardScreen extends StatelessWidget {
  const BankingDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final localizedAppTitle =
        AppLocalizations.of(context)?.appTitle ?? "VaniGuard";

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/branding/vaniguard_logo.png',
              width: 32,
              height: 32,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 10),
            Text(localizedAppTitle),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.privacy_tip_outlined, size: 28),
            tooltip: "Privacy & Consents",
            onPressed: () => Navigator.pushNamed(context, "/consents"),
          ),
          IconButton(
            icon: const Icon(Icons.people_outline, size: 28),
            tooltip: "Trusted Contacts",
            onPressed: () => Navigator.pushNamed(context, "/trusted-contacts"),
          ),
        ],
      ),
      drawer: Drawer(
        backgroundColor: QuietVaultColors.background,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                color: QuietVaultColors.surface,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      // Drawer logo sized appropriately and never stretched
                      Image.asset(
                        'assets/branding/vaniguard_logo.png',
                        width: 44,
                        height: 44,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        localizedAppTitle,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: QuietVaultColors.textPrimary,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "User: user_test_001",
                    style: TextStyle(
                      fontSize: 14,
                      color: QuietVaultColors.textSecondary,
                    ),
                  ),
                  const Text(
                    "Savings A/C: ...4819",
                    style: TextStyle(
                      fontSize: 12,
                      color: QuietVaultColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.mic_outlined),
              title: Text(
                AppLocalizations.of(context)?.voiceBanking ?? "Voice Banking",
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, "/voice-session");
              },
            ),
            ListTile(
              leading: const Icon(Icons.people_outline),
              title: const Text("Trusted Contacts"),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, "/trusted-contacts");
              },
            ),
            ListTile(
              leading: const Icon(Icons.security_outlined),
              title: const Text("Risk Monitor"),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, "/risk-monitor");
              },
            ),
            ListTile(
              leading: const Icon(Icons.record_voice_over_outlined),
              title: const Text("Voice Enrollment"),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, "/voice-enroll");
              },
            ),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text("Privacy & Consents"),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, "/consents");
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout_outlined),
              title: const Text("Sign Out"),
              onTap: () {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  "/login",
                  (route) => false,
                );
              },
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Primary Account Balance Card (Touch target >= 64dp)
              Semantics(
                label: "Savings account ending in 4819. Current balance: 50,000 rupees.",
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: QuietVaultColors.primary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        "Primary Savings Account (...4819)",
                        style: TextStyle(fontSize: 16, color: QuietVaultColors.surfaceAlt),
                      ),
                      SizedBox(height: 12),
                      Text(
                        "INR 50,000",
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w700,
                          color: QuietVaultColors.surface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // Main Voice Action Button
              AccessibleButton(
                label: "Open Voice Banking Session",
                semanticsHint: "Starts interactive conversational banking session operable entirely by voice",
                icon: Icons.mic,
                onPressed: () {
                  Navigator.pushNamed(context, "/voice-session");
                },
              ),
              const SizedBox(height: 16),

              AccessibleButton(
                label: "Security & Coercion Monitor",
                semanticsHint: "Opens live transparent risk signals display",
                icon: Icons.security,
                isSecondary: true,
                onPressed: () {
                  Navigator.pushNamed(context, "/risk-monitor");
                },
              ),
              const SizedBox(height: 32),

              // Recent Activity Section
              const Text(
                "Recent Activity",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),

              _buildTransactionTile(
                title: "Electricity Board Bill",
                subtitle: "Yesterday, 3:15 PM",
                amount: "- INR 1,200",
                isDebit: true,
                isDark: isDark,
              ),
              _buildTransactionTile(
                title: "Pension Credit",
                subtitle: "3 days ago",
                amount: "+ INR 22,500",
                isDebit: false,
                isDark: isDark,
              ),
              _buildTransactionTile(
                title: "Son Rahul (Groceries)",
                subtitle: "Last week",
                amount: "- INR 500",
                isDebit: true,
                isDark: isDark,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionTile({
    required String title,
    required String subtitle,
    required String amount,
    required bool isDebit,
    required bool isDark,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? QuietVaultColors.darkSurfaceAlt : QuietVaultColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(fontSize: 14, color: QuietVaultColors.inkSecondary)),
            ],
          ),
          Text(
            amount,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDebit ? QuietVaultColors.danger : QuietVaultColors.success,
            ),
          ),
        ],
      ),
    );
  }
}

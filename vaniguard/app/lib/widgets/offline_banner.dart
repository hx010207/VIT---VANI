/// PURPOSE: Persistent banner widget alerting users when network connectivity is lost.
/// ROLE IN SYSTEM: Informs user that voice sessions require secure connectivity to proceed.
/// TALKS TO: app/lib/theme/quiet_vault_theme.dart, app/lib/screens/
import 'package:flutter/material.dart';
import 'package:vaniguard/theme/quiet_vault_theme.dart';

class OfflineBanner extends StatelessWidget {
  final bool isOffline;
  final String message;

  const OfflineBanner({
    super.key,
    required this.isOffline,
    this.message = "Offline: Banking actions will be securely queued and synced when connection returns.",
  });

  @override
  Widget build(BuildContext context) {
    if (!isOffline) return const SizedBox.shrink();

    return Semantics(
      liveRegion: true,
      label: "System notification: $message",
      child: Container(
        width: double.infinity,
        color: QuietVaultColors.accent,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.wifi_off, color: QuietVaultColors.ink, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: QuietVaultColors.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:vaniguard/theme/quiet_vault_theme.dart';

class AccessibleButton extends StatelessWidget {
  final String label;
  final String semanticsHint;
  final VoidCallback? onPressed;
  final bool isSecondary;
  final bool isDanger;
  final IconData? icon;

  const AccessibleButton({
    super.key,
    required this.label,
    required this.semanticsHint,
    required this.onPressed,
    this.isSecondary = false,
    this.isDanger = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    Color backgroundColor = QuietVaultColors.primary;
    Color foregroundColor = QuietVaultColors.surface;

    if (isDanger) {
      backgroundColor = QuietVaultColors.danger;
      foregroundColor = QuietVaultColors.surface;
    } else if (isSecondary) {
      backgroundColor = QuietVaultColors.surfaceAlt;
      foregroundColor = QuietVaultColors.ink;
    }

    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      hint: semanticsHint,
      child: FocusableActionDetector(
        child: Container(
          constraints: const BoxConstraints(
            minHeight: QuietVaultTheme.minTouchTarget,
            minWidth: QuietVaultTheme.minTouchTarget,
          ),
          child: ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: backgroundColor,
              foregroundColor: foregroundColor,
              minimumSize: const Size(double.infinity, QuietVaultTheme.minTouchTarget),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: isSecondary
                    ? const BorderSide(color: QuietVaultColors.inkSecondary, width: 1.5)
                    : BorderSide.none,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 24),
                  const SizedBox(width: 12),
                ],
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: foregroundColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// PURPOSE: Declarative route definitions and navigation management for the Flutter client.
/// ROLE IN SYSTEM: Maps URI routes to screens (dashboard, voice session, challenge, TC portal).
/// TALKS TO: app/lib/screens/, app/lib/main.dart
import 'package:flutter/material.dart';
import 'package:vaniguard/screens/banking_dashboard_screen.dart';
import 'package:vaniguard/screens/voice_session_screen.dart';
import 'package:vaniguard/screens/transfer_held_screen.dart';
import 'package:vaniguard/screens/voice_enrollment_screen.dart';
import 'package:vaniguard/screens/challenge_verification_screen.dart';
import 'package:vaniguard/screens/risk_monitor_screen.dart';
import 'package:vaniguard/screens/trusted_contact_portal_screen.dart';
import 'package:vaniguard/screens/consents_privacy_screen.dart';

class AppRouter {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case "/":
        return MaterialPageRoute(builder: (_) => const BankingDashboardScreen());
      case "/voice-session":
        return MaterialPageRoute(builder: (_) => const VoiceSessionScreen());
      case "/transfer-held":
        return MaterialPageRoute(builder: (_) => const TransferHeldScreen());
      case "/voice-enroll":
        return MaterialPageRoute(builder: (_) => const VoiceEnrollmentScreen());
      case "/challenge-verify":
        return MaterialPageRoute(builder: (_) => const ChallengeVerificationScreen());
      case "/risk-monitor":
        return MaterialPageRoute(builder: (_) => const RiskMonitorScreen());
      case "/trusted-contacts":
        return MaterialPageRoute(builder: (_) => const TrustedContactPortalScreen());
      case "/consents":
        return MaterialPageRoute(builder: (_) => const ConsentsPrivacyScreen());
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text("Route not found: ${settings.name}"),
            ),
          ),
        );
    }
  }
}

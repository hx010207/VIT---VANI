/// PURPOSE: Declarative route definitions and navigation management for the Flutter client.
/// ROLE IN SYSTEM: Maps URI routes to screens (dashboard, login, register, payees, QR, bills, voice session, challenge, TC portal).
/// TALKS TO: app/lib/screens/, app/lib/main.dart
import 'package:flutter/material.dart';
import 'package:vaniguard/screens/splash_screen.dart';
import 'package:vaniguard/screens/login_screen.dart';
import 'package:vaniguard/screens/register_screen.dart';
import 'package:vaniguard/screens/banking_dashboard_screen.dart';
import 'package:vaniguard/screens/voice_session_screen.dart';
import 'package:vaniguard/screens/transfer_held_screen.dart';
import 'package:vaniguard/screens/voice_enrollment_screen.dart';
import 'package:vaniguard/screens/challenge_verification_screen.dart';
import 'package:vaniguard/screens/risk_monitor_screen.dart';
import 'package:vaniguard/screens/trusted_contact_portal_screen.dart';
import 'package:vaniguard/screens/consents_privacy_screen.dart';
import 'package:vaniguard/screens/payees_screen.dart';
import 'package:vaniguard/screens/qr_scan_screen.dart';
import 'package:vaniguard/screens/pay_bills_screen.dart';
import 'package:vaniguard/screens/program_nfc_card_screen.dart';

class AppRouter {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case "/":
      case "/splash":
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      case "/login":
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case "/register":
        return MaterialPageRoute(builder: (_) => const RegisterScreen());
      case "/dashboard":
        return MaterialPageRoute(builder: (_) => const BankingDashboardScreen());
      case "/payees":
        return MaterialPageRoute(builder: (_) => const PayeesScreen());
      case "/qr-scan":
        return MaterialPageRoute(builder: (_) => const QrScanScreen());
      case "/pay-bills":
        return MaterialPageRoute(builder: (_) => const PayBillsScreen());
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
      case "/program-card":
        return MaterialPageRoute(builder: (_) => const ProgramNfcCardScreen());
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

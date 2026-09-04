/// PURPOSE: Device biometric authentication service (Fingerprint, Face Unlock).
/// ROLE IN SYSTEM: Interacts with Android local_auth to provide secure, one-touch sign-in.
/// TALKS TO: app/lib/screens/login_screen.dart, local_auth package
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();

  /// Check if the physical device has biometric sensors and hardware available
  static Future<bool> isBiometricAvailable() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isDeviceSupported = await _auth.isDeviceSupported();
      return canCheck && isDeviceSupported;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Get list of available biometric types (e.g. fingerprint, face, weak, strong)
  static Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } on PlatformException {
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Authenticate the user using system biometric prompt
  static Future<bool> authenticate({
    String reason = 'Verify your identity to access VaniGuard',
  }) async {
    try {
      final isAvailable = await isBiometricAvailable();
      if (!isAvailable) return false;

      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
          useErrorDialogs: true,
        ),
      );
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Check if user has enrolled biometrics in VaniGuard
  static Future<bool> isUserEnrolled(String phone) async {
    final prefs = await SharedPreferences.getInstance();
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    return prefs.getBool('bio_enrolled_$cleanPhone') ?? false;
  }

  /// Save biometric enrollment status and credentials securely for quick sign in
  static Future<void> setEnrolled(String phone, String password, bool enrolled) async {
    final prefs = await SharedPreferences.getInstance();
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    await prefs.setBool('bio_enrolled_$cleanPhone', enrolled);
    if (enrolled) {
      await prefs.setString('bio_phone', cleanPhone);
      await prefs.setString('bio_pass_$cleanPhone', password);
    } else {
      await prefs.remove('bio_pass_$cleanPhone');
    }
  }

  /// Get enrolled phone if any
  static Future<String?> getEnrolledPhone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('bio_phone');
  }

  /// Get saved password for enrolled phone
  static Future<String?> getEnrolledPassword(String phone) async {
    final prefs = await SharedPreferences.getInstance();
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    return prefs.getString('bio_pass_$cleanPhone');
  }
}

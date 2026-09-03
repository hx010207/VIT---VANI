/// PURPOSE: Main banking dashboard display showing live balance in paise, guardian alerts, and hands-free voice navigation.
/// ROLE IN SYSTEM: Primary interface presenting account status, receiving real-time WebSocket events, and launching voice banking.
/// TALKS TO: app/lib/router.dart, app/lib/services/api_client.dart, app/lib/services/voice_command_router.dart, app/lib/widgets/accessible_button.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:vaniguard/l10n/app_localizations.dart';
import 'package:vaniguard/services/api_client.dart';
import 'package:vaniguard/services/voice_command_router.dart';
import 'package:vaniguard/theme/quiet_vault_theme.dart';
import 'package:vaniguard/widgets/accessible_button.dart';

class BankingDashboardScreen extends StatefulWidget {
  const BankingDashboardScreen({super.key});

  @override
  State<BankingDashboardScreen> createState() => _BankingDashboardScreenState();
}

class _BankingDashboardScreenState extends State<BankingDashboardScreen> {
  String _userId = '';
  String _userName = 'Account Holder';
  String _userPhone = '';
  String _maskedAccount = '...4819';
  int _balancePaise = 5000000; // Default 50,000 INR
  bool _guardianMode = false;
  String? _guardianName;
  bool _isLoading = true;
  bool _hasPendingGuardianAlert = false;
  String? _pendingAlertMessage;

  WebSocketChannel? _eventsChannel;
  StreamSubscription? _eventsSubscription;
  final FlutterTts _flutterTts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _initTts();
    _loadUserData();
  }

  Future<void> _initTts() async {
    try {
      await _flutterTts.setSpeechRate(0.85);
      await _flutterTts.setLanguage("en-IN");
    } catch (_) {}
  }

  Future<void> _speak(String text) async {
    try {
      await _flutterTts.speak(text);
    } catch (_) {}
  }

  @override
  void dispose() {
    _eventsSubscription?.cancel();
    _eventsChannel?.sink.close();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userId = prefs.getString('user_id') ?? '';
      _userName = prefs.getString('full_name') ?? 'Account Holder';
      _userPhone = prefs.getString('phone') ?? '';
      _guardianMode = prefs.getBool('guardian_mode') ?? false;
      _guardianName = prefs.getString('guardian_name');
    });

    await _fetchAccounts();
    await _checkPendingAlerts();
    _subscribeToEvents();
  }

  Future<void> _fetchAccounts() async {
    try {
      final accounts = await ApiClient.getAccounts();
      if (accounts.isNotEmpty) {
        // Find matching account or use first
        Map<String, dynamic>? targetAccount;
        for (final acc in accounts) {
          if (acc['user_id'] == _userId || _userId.isEmpty) {
            targetAccount = acc as Map<String, dynamic>;
            break;
          }
        }
        targetAccount ??= accounts.first as Map<String, dynamic>;

        setState(() {
          _balancePaise = (targetAccount?['balance_paise'] as int?) ?? 5000000;
          _maskedAccount = (targetAccount?['account_number'] as String?) != null
              ? '...${targetAccount!['account_number'].toString().substring(targetAccount['account_number'].toString().length - 4)}'
              : '...4819';
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _checkPendingAlerts() async {
    try {
      final pending = await ApiClient.getTcPending(
        tcUserId: _userId.isNotEmpty ? _userId : null,
      );
      if (pending.isNotEmpty) {
        setState(() {
          _hasPendingGuardianAlert = true;
          _pendingAlertMessage =
              '${pending.length} transfer held under cooling window awaiting safety review.';
        });
      } else {
        setState(() {
          _hasPendingGuardianAlert = false;
          _pendingAlertMessage = null;
        });
      }
    } catch (_) {}
  }

  void _subscribeToEvents() {
    try {
      _eventsChannel = ApiClient.connectEvents(
        userId: _userId.isNotEmpty ? _userId : null,
      );
      _eventsSubscription = _eventsChannel?.stream.listen((message) {
        try {
          final data = jsonDecode(message.toString()) as Map<String, dynamic>;
          final eventType = data['type'] as String?;

          if (eventType == 'transfer_completed' ||
              eventType == 'transfer_cancelled') {
            // Immediate real-time balance refetch
            _fetchAccounts();
            _checkPendingAlerts();
          } else if (eventType == 'circuit_break_alert' ||
              eventType == 'transfer_held') {
            setState(() {
              _hasPendingGuardianAlert = true;
              _pendingAlertMessage =
                  'New safety hold triggered. Immediate guardian review required.';
            });
            _speak('Guardian alert: A transfer is held for safety review.');
          }
        } catch (_) {}
      });
    } catch (_) {}
  }

  void _openVoiceNavigationDialog() {
    final textController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: QuietVaultColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
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
                children: [
                  const Icon(Icons.mic, size: 28, color: QuietVaultColors.primary),
                  const SizedBox(width: 12),
                  Text(
                    'Voice Navigation',
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: QuietVaultColors.textPrimary,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Speak or type a command: "Check balance", "Pay electricity bill", "Send 500 to Rahul", or "Scan QR".',
                style: TextStyle(fontSize: 15, color: QuietVaultColors.textSecondary),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: textController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'e.g. Check balance / पैसे भेजो',
                  prefixIcon: const Icon(Icons.record_voice_over),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: QuietVaultColors.surfaceAlt,
                ),
                onSubmitted: (query) {
                  Navigator.pop(ctx);
                  _executeVoiceCommand(query);
                },
              ),
              const SizedBox(height: 16),
              AccessibleButton(
                label: 'Execute Command',
                semanticsHint: 'Executes the voice command query',
                icon: Icons.play_arrow_rounded,
                onPressed: () {
                  Navigator.pop(ctx);
                  _executeVoiceCommand(textController.text);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _executeVoiceCommand(String query) async {
    final result = VoiceCommandRouter.parse(query);
    await _speak(result.ttsAnnouncementEn);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.ttsAnnouncementEn),
        duration: const Duration(seconds: 4),
        backgroundColor: QuietVaultColors.surface,
      ),
    );

    if (result.route != null) {
      Navigator.pushNamed(context, result.route!);
    }
  }

  String _formatPaise(int paise) {
    final inr = paise / 100;
    if (inr == inr.roundToDouble()) {
      return 'INR ${inr.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}';
    }
    return 'INR ${inr.toStringAsFixed(2)}';
  }

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
                      Image.asset(
                        'assets/branding/vaniguard_logo.png',
                        width: 44,
                        height: 44,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          localizedAppTitle,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: QuietVaultColors.textPrimary,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _userName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: QuietVaultColors.textPrimary,
                    ),
                  ),
                  Text(
                    _userPhone.isNotEmpty ? _userPhone : "Savings A/C: $_maskedAccount",
                    style: const TextStyle(
                      fontSize: 13,
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
              title: const Text("Trusted Contacts & Guardian"),
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
              onTap: () async {
                await ApiClient.logout();
                final prefs = await SharedPreferences.getInstance();
                await prefs.clear();
                if (context.mounted) {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    "/login",
                    (route) => false,
                  );
                }
              },
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: QuietVaultColors.primary,
        foregroundColor: QuietVaultColors.surface,
        icon: const Icon(Icons.mic, size: 28),
        label: const Text(
          "Voice Nav",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        onPressed: _openVoiceNavigationDialog,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await _fetchAccounts();
            await _checkPendingAlerts();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Guardian Alert Card (Visible when transfer held under safety review)
                if (_hasPendingGuardianAlert) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: QuietVaultColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.amber.shade700, width: 2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.shield_outlined, color: Colors.amber.shade800, size: 28),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                "Guardian Alert: Action Required",
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.amber.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _pendingAlertMessage ??
                              "A transfer is currently held for elder safety. Tap to review.",
                          style: const TextStyle(
                            fontSize: 14,
                            color: QuietVaultColors.ink,
                          ),
                        ),
                        const SizedBox(height: 12),
                        AccessibleButton(
                          label: "Review Held Transfer",
                          semanticsHint: "Navigates to trusted contact portal to review and approve or cancel transfer",
                          onPressed: () {
                            Navigator.pushNamed(context, "/trusted-contacts");
                          },
                        ),
                      ],
                    ),
                  ),
                ],

                // Guardian Protection Badge
                if (_guardianMode) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: QuietVaultColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: QuietVaultColors.primary.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.verified_user, color: QuietVaultColors.primary, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Guardian Protection Active${_guardianName != null ? ' (Guardian: $_guardianName)' : ''}",
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: QuietVaultColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Primary Account Balance Card (Touch target >= 64dp)
                Semantics(
                  label: "Savings account ending in $_maskedAccount. Current balance: ${_formatPaise(_balancePaise)}.",
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: QuietVaultColors.primary,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Primary Savings Account ($_maskedAccount)",
                          style: const TextStyle(fontSize: 16, color: QuietVaultColors.surfaceAlt),
                        ),
                        const SizedBox(height: 12),
                        _isLoading
                            ? const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: QuietVaultColors.surface,
                                    strokeWidth: 2.5,
                                  ),
                                ),
                              )
                            : Text(
                                _formatPaise(_balancePaise),
                                style: const TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w700,
                                  color: QuietVaultColors.surface,
                                ),
                              ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

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


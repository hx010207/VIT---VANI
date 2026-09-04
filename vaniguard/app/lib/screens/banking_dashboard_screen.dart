/// PURPOSE: Main banking dashboard display showing live balance in paise, guardian alerts, and hands-free voice navigation.
/// ROLE IN SYSTEM: Primary interface presenting account status, receiving real-time WebSocket events, launching voice banking, and routing to Payees, QR, and Bills.
/// TALKS TO: app/lib/router.dart, app/lib/services/api_client.dart, app/lib/services/voice_command_router.dart, app/lib/widgets/accessible_button.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:vaniguard/l10n/app_localizations.dart';
import 'package:vaniguard/main.dart';
import 'package:vaniguard/services/api_client.dart';
import 'package:vaniguard/services/voice_command_router.dart';
import 'package:vaniguard/services/nfc_service.dart';
import 'package:vaniguard/services/nfc_background_reader.dart';
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
  String _accountId = '';
  String _maskedAccount = '...4821';
  int _balancePaise = 5000000; // Default 50,000 INR
  bool _guardianMode = false;
  String? _guardianName;
  bool _isLoading = true;
  bool _hasPendingGuardianAlert = false;
  String? _pendingAlertMessage;

  // Real recent ledger transactions
  List<Map<String, dynamic>> _recentTransactions = [];

  // Active Call Guard simulation state
  bool _simulatedCallActive = false;

  // Speech to text listener state
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isSpeechListening = false;
  String _spokenWords = '';

  WebSocketChannel? _eventsChannel;
  StreamSubscription? _eventsSubscription;
  final FlutterTts _flutterTts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _initTts();
    _loadUserData();
    _startNfcListening();
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
    NfcBackgroundReader().stopListening();
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
    await _fetchRecentTransactions();
    await _checkPendingAlerts();
    _subscribeToEvents();
  }

  Future<void> _fetchAccounts() async {
    try {
      final accounts = await ApiClient.getAccounts();
      if (accounts.isNotEmpty) {
        Map<String, dynamic>? targetAccount;
        for (final acc in accounts) {
          if (acc['user_id'] == _userId || _userId.isEmpty) {
            targetAccount = acc as Map<String, dynamic>;
            break;
          }
        }
        targetAccount ??= accounts.first as Map<String, dynamic>;

        setState(() {
          _accountId = (targetAccount?['id'] ?? '').toString();
          _balancePaise = (targetAccount?['balance_paise'] as num?)?.toInt() ?? 5000000;
          _maskedAccount = (targetAccount?['account_number_masked'] as String?) ??
              ((targetAccount?['account_number'] as String?) != null
                  ? '...${targetAccount!['account_number'].toString().substring(targetAccount['account_number'].toString().length - 4)}'
                  : '...4821');
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchRecentTransactions() async {
    try {
      final txs = await ApiClient.getRecentTransactions(limit: 5);
      if (mounted) {
        setState(() {
          _recentTransactions = txs;
        });
      }
    } catch (_) {}
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
            _fetchAccounts();
            _fetchRecentTransactions();
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

  Future<void> _openVoiceNavigationDialog() async {
    final recorder = AudioRecorder();
    bool hasPermission = false;
    try {
      hasPermission = await recorder.hasPermission();
    } catch (_) {
      hasPermission = false;
    }

    if (!hasPermission) {
      if (!mounted) return;
      final retry = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.mic_off, color: QuietVaultColors.amberAccent, size: 28),
              SizedBox(width: 10),
              Text('Microphone Access', style: TextStyle(color: Colors.white, fontSize: 18)),
            ],
          ),
          content: const Text(
            'VaniGuard requires microphone access for hands-free voice navigation. Please grant microphone permission to speak banking commands.',
            style: TextStyle(color: Colors.white70, fontSize: 15),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Type Command', style: TextStyle(color: QuietVaultColors.amberAccent)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: QuietVaultColors.amberAccent),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Grant Permission', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );

      if (retry == true) {
        try {
          hasPermission = await recorder.hasPermission();
        } catch (_) {}
      }

      if (!hasPermission) {
        _showTextFallbackVoiceDialog();
        return;
      }
    }

    bool hasSpeech = false;
    try {
      hasSpeech = await _speech.initialize(
        onError: (_) {},
        onStatus: (_) {},
      );
    } catch (_) {
      hasSpeech = false;
    }

    if (!hasSpeech) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Speech recognition service unavailable on this device. Using text mode.'),
            backgroundColor: Color(0xFF2C2C2C),
            duration: Duration(seconds: 3),
          ),
        );
      }
      _showTextFallbackVoiceDialog();
      return;
    }

    _spokenWords = '';
    _isSpeechListening = true;

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: QuietVaultColors.amberAccent.withOpacity(0.2),
                          border: Border.all(color: QuietVaultColors.amberAccent, width: 2.5),
                        ),
                        child: const Icon(Icons.mic, size: 40, color: QuietVaultColors.amberAccent),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Listening for Command...',
                    style: Theme.of(modalCtx).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: QuietVaultColors.textPrimary,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Say: "Check balance", "Pay electricity bill", "Send money to Rahul", or "Recent transactions"',
                    style: TextStyle(fontSize: 14, color: QuietVaultColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C2C2C),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: QuietVaultColors.amberAccent.withOpacity(0.4)),
                    ),
                    child: Text(
                      _spokenWords.isNotEmpty
                          ? '"$_spokenWords"'
                          : 'Speak now into microphone...',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: _spokenWords.isNotEmpty ? QuietVaultColors.amberAccent : Colors.white60,
                        fontStyle: _spokenWords.isNotEmpty ? FontStyle.normal : FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_spokenWords.isNotEmpty)
                    AccessibleButton(
                      label: 'Execute Spoken Command',
                      semanticsHint: 'Executes the recognized voice command',
                      icon: Icons.play_arrow_rounded,
                      onPressed: () {
                        _speech.stop();
                        Navigator.pop(modalCtx);
                        _executeVoiceCommand(_spokenWords);
                      },
                    ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    icon: const Icon(Icons.keyboard_alt_outlined, color: QuietVaultColors.textSecondary),
                    label: const Text(
                      'Type Command Instead',
                      style: TextStyle(color: QuietVaultColors.textSecondary, fontSize: 15),
                    ),
                    onPressed: () {
                      _speech.stop();
                      Navigator.pop(modalCtx);
                      _showTextFallbackVoiceDialog();
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    ).then((_) {
      if (_isSpeechListening) {
        _speech.stop();
        _isSpeechListening = false;
      }
    });

    try {
      final langCode = Localizations.localeOf(context).languageCode;
      final lang = langCode == 'hi'
          ? 'hi_IN'
          : (langCode == 'te' ? 'te_IN' : (langCode == 'ta' ? 'ta_IN' : 'en_IN'));
      await _speech.listen(
        onResult: (result) {
          if (mounted) {
            setState(() {
              _spokenWords = result.recognizedWords;
            });
            if (result.finalResult && result.recognizedWords.trim().isNotEmpty) {
              _speech.stop();
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              }
              _executeVoiceCommand(result.recognizedWords);
            }
          }
        },
        localeId: lang,
        listenFor: const Duration(seconds: 15),
        pauseFor: const Duration(milliseconds: 1500),
      );
    } catch (_) {}
  }

  void _showTextFallbackVoiceDialog() {
    final textController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
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
                  const Icon(Icons.keyboard_alt_outlined, size: 28, color: QuietVaultColors.amberAccent),
                  const SizedBox(width: 12),
                  Text(
                    'Type Voice Command',
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: QuietVaultColors.textPrimary,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Enter command: "Check balance", "Pay electricity bill", "Send money to Rahul", or "Recent transactions"',
                style: TextStyle(fontSize: 15, color: QuietVaultColors.textSecondary),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: textController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'e.g. Check balance / पैसे भेजो',
                  prefixIcon: const Icon(Icons.edit),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: const Color(0xFF2C2C2C),
                ),
                onSubmitted: (query) {
                  Navigator.pop(ctx);
                  _executeVoiceCommand(query);
                },
              ),
              const SizedBox(height: 16),
              AccessibleButton(
                label: 'Execute Command',
                semanticsHint: 'Executes the typed command',
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

  void _showMyQrDialog() {
    final receivePayload = jsonEncode({
      'v': 1,
      'type': 'vaniguard_receive',
      'account_id': _accountId.isNotEmpty ? _accountId : _userId,
      'name': _userName,
      'phone': _userPhone,
    });

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'My Receive QR Code',
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: QuietVaultColors.textPrimary,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Scan this code from any phone to transfer money to $_userName',
                style: const TextStyle(fontSize: 14, color: QuietVaultColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: QuietVaultColors.amberAccent.withOpacity(0.35),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: QrImageView(
                  data: receivePayload,
                  version: QrVersions.auto,
                  size: 220.0,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _userName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: QuietVaultColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Account: $_maskedAccount | VaniGuard UPI',
                style: const TextStyle(fontSize: 14, color: QuietVaultColors.amberAccent),
              ),
              const SizedBox(height: 24),
              AccessibleButton(
                label: 'Close',
                semanticsHint: 'Closes receive QR code',
                isSecondary: true,
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
        );
      },
    );
  }

  void _startNfcListening() {
    NfcBackgroundReader().startListening(
      onCardScanned: (payload) {
        if (!mounted) return;
        _handleNfcCardScanned(payload);
      },
      onUnknownCard: () {
        if (!mounted) return;
        _handleUnknownNfcCard();
      },
    );
  }

  void _handleUnknownNfcCard() async {
    final l10n = AppLocalizations.of(context);
    final msg = l10n?.nfcUnrecognized ?? 'Unrecognized card';
    await _speak(msg);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.redAccent.shade700,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _handleNfcCardScanned(NfcCardPayload payload) async {
    final prompt = 'Card read: ${payload.label}. Say the amount to pay.';
    await _speak(prompt);
    if (!mounted) return;
    _showNfcTapAndPayModal(payload);
  }

  void _showNfcTapAndPayModal(NfcCardPayload payload) {
    int? parsedAmount = payload.amt;
    final amountController = TextEditingController(
      text: parsedAmount != null ? (parsedAmount ~/ 100).toString() : '',
    );
    bool isListeningVoice = false;
    String liveVoiceTranscript = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final l10n = AppLocalizations.of(modalCtx);

            Future<void> startListeningAmount() async {
              final lang = Localizations.localeOf(context).languageCode;
              setModalState(() {
                isListeningVoice = true;
                liveVoiceTranscript = 'Listening for amount...';
              });

              final available = await _speech.initialize();
              if (!available) {
                setModalState(() {
                  isListeningVoice = false;
                  liveVoiceTranscript = 'Speech input not available';
                });
                return;
              }

              await _speech.listen(
                onResult: (result) {
                  setModalState(() {
                    liveVoiceTranscript = result.recognizedWords;
                    final amt = VoiceCommandRouter.parseAmount(result.recognizedWords);
                    if (amt != null) {
                      parsedAmount = amt * 100;
                      amountController.text = amt.toString();
                    }
                  });
                },
                localeId: lang == 'hi' ? 'hi-IN' : (lang == 'te' ? 'te-IN' : (lang == 'ta' ? 'ta-IN' : 'en-IN')),
                listenFor: const Duration(seconds: 10),
                pauseFor: const Duration(seconds: 2),
              );
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.nfc, color: QuietVaultColors.amberAccent, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l10n?.nfcTapTitle ?? 'NFC Tap & Pay',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: QuietVaultColors.textPrimary,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.green),
                        ),
                        child: const Text(
                          'CARD VERIFIED',
                          style: TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C2C2C),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'PAYEE (CARD LOCKED)',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: QuietVaultColors.textSecondary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          payload.label,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'ID: ${payload.payeeId}',
                          style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: QuietVaultColors.amberAccent),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Card read: ${payload.label}. Say the amount to pay.',
                    style: const TextStyle(fontSize: 14, color: QuietVaultColors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: amountController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: QuietVaultColors.amberAccent,
                          ),
                          decoration: InputDecoration(
                            prefixText: 'INR ',
                            prefixStyle: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: QuietVaultColors.amberAccent,
                            ),
                            hintText: '0',
                            hintStyle: const TextStyle(color: Colors.white24, fontSize: 32),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: const Color(0xFF2A2A2A),
                          ),
                          onChanged: (val) {
                            final entered = int.tryParse(val.trim());
                            if (entered != null) {
                              parsedAmount = entered * 100;
                            } else {
                              parsedAmount = null;
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton.filled(
                        style: IconButton.styleFrom(
                          backgroundColor: isListeningVoice ? Colors.redAccent : QuietVaultColors.amberAccent,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.all(16),
                        ),
                        icon: Icon(isListeningVoice ? Icons.mic : Icons.mic_none, size: 28),
                        tooltip: 'Say Amount',
                        onPressed: startListeningAmount,
                      ),
                    ],
                  ),
                  if (liveVoiceTranscript.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Spoken: "$liveVoiceTranscript"',
                      style: const TextStyle(color: QuietVaultColors.amberAccent, fontSize: 13, fontStyle: FontStyle.italic),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white30),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () {
                            _speech.stop();
                            Navigator.pop(modalCtx);
                          },
                          child: const Text('Cancel', style: TextStyle(color: Colors.white70, fontSize: 16)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: QuietVaultColors.amberAccent,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () async {
                            _speech.stop();
                            final amountInRupees = int.tryParse(amountController.text.trim());
                            if (amountInRupees == null || amountInRupees <= 0) {
                              ScaffoldMessenger.of(modalCtx).showSnackBar(
                                const SnackBar(content: Text('Please speak or enter an amount to pay.')),
                              );
                              return;
                            }

                            Navigator.pop(modalCtx);
                            await _processNfcPayment(payload, amountInRupees, liveVoiceTranscript);
                          },
                          child: const Text('Confirm & Pay', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _processNfcPayment(
    NfcCardPayload payload,
    int amountInRupees,
    String spokenVoice,
  ) async {
    final amountPaise = amountInRupees * 100;
    final isCoercive = _simulatedCallActive || VoiceCommandRouter.detectCoercion(spokenVoice);

    try {
      final idempotency = 'nfc-transfer-${DateTime.now().millisecondsSinceEpoch}';
      final res = await ApiClient.initiateTransfer(
        sourceAccountId: _accountId.isNotEmpty ? _accountId : _userId,
        payeeId: payload.payeeId,
        amountPaise: amountPaise,
        idempotencyKey: idempotency,
        transcript: spokenVoice.isNotEmpty
            ? spokenVoice
            : (isCoercive ? 'police urgent transfer' : 'NFC payment to ${payload.label}'),
      );

      final state = res['state']?.toString() ?? 'COMPLETED';
      final riskBand = res['risk_band']?.toString() ?? 'PROCEED';

      if (state == 'HELD' || riskBand == 'CIRCUIT_BREAK' || riskBand == 'PAUSE_COOLDOWN') {
        const holdTts = 'Payment held for safety. Your guardian has been notified.';
        await _speak(holdTts);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(holdTts, style: TextStyle(fontWeight: FontWeight.bold)),
              backgroundColor: Colors.redAccent.shade700,
              duration: const Duration(seconds: 5),
            ),
          );
          Navigator.pushNamed(context, '/transfer-held');
        }
      } else {
        final completionTts = 'Paid $amountInRupees rupees to ${payload.label}.';
        await _speak(completionTts);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(completionTts, style: const TextStyle(fontWeight: FontWeight.bold)),
              backgroundColor: Colors.green.shade800,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }

      await _fetchAccounts();
      await _fetchRecentTransactions();
    } catch (e) {
      debugPrint('[NFC Payment] Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment error: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _executeVoiceCommand(String query) async {
    if (query.trim().isEmpty) return;
    final result = VoiceCommandRouter.parse(query);
    final langCode = Localizations.localeOf(context).languageCode;

    String announcement = result.getLocalizedAnnouncement(langCode);

    if (result.intent == NavigationIntent.checkBalance) {
      final inrFormatted = _formatPaise(_balancePaise);
      if (langCode == 'hi') {
        announcement = "आपके खाते का वर्तमान बैलेंस $inrFormatted है।";
      } else if (langCode == 'te') {
        announcement = "మీ ఖాతా ప్రస్తుత నిల్వ $inrFormatted.";
      } else if (langCode == 'ta') {
        announcement = "உங்கள் கணக்கின் தற்போதைய இருப்பு $inrFormatted.";
      } else {
        announcement = "Your account balance is $inrFormatted.";
      }
    } else if (result.intent == NavigationIntent.recentTransactions) {
      if (_recentTransactions.isNotEmpty) {
        final first = _recentTransactions.first;
        final amt = _formatPaise((first['amount_paise'] as num?)?.toInt() ?? 0);
        final payee = (first['payee_name'] ?? 'Payee').toString();
        if (langCode == 'hi') {
          announcement = "हालिया लेनदेन: $payee को $amt। स्थिति: ${first['state']}।";
        } else if (langCode == 'te') {
          announcement = "ఇటీవలి లావాదేవీ: $payee కి $amt. స్థితి: ${first['state']}.";
        } else if (langCode == 'ta') {
          announcement = "சமீபத்திய பரிவர்த்தனை: $payee க்கு $amt. நிலை: ${first['state']}.";
        } else {
          announcement = "Recent transaction: $amt to $payee. Status: ${first['state']}.";
        }
      } else {
        announcement = result.getLocalizedAnnouncement(langCode);
      }
    } else if (result.intent == NavigationIntent.guardianInfo) {
      final gName = _guardianName ?? 'Priya Sharma';
      if (langCode == 'hi') {
        announcement = "आपकी नामित सुरक्षा संरक्षक $gName हैं।";
      } else if (langCode == 'te') {
        announcement = "మీ నియమిత రక్షణ సంరక్షకురాలు $gName.";
      } else if (langCode == 'ta') {
        announcement = "உங்கள் நியமிக்கப்பட்ட பாதுகாப்பு பாதுகாவலர் $gName.";
      } else {
        announcement = "Your designated safety guardian is $gName.";
      }
    }

    await _speak(announcement);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(announcement, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        duration: const Duration(seconds: 4),
        backgroundColor: const Color(0xFF2C2C2C),
      ),
    );

    if (result.intent == NavigationIntent.payBill) {
      Navigator.pushNamed(context, '/pay-bills');
    } else if (result.intent == NavigationIntent.scanAndPay) {
      Navigator.pushNamed(context, '/qr-scan');
    } else if (result.intent == NavigationIntent.pay) {
      Navigator.pushNamed(context, '/payees');
    } else if (result.route != null && result.route != '/dashboard') {
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

  Widget _buildQuickActionCard({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Material(
      color: isDark ? QuietVaultColors.darkSurfaceAlt : QuietVaultColors.surfaceAlt,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: QuietVaultColors.primary, size: 28),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: QuietVaultColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    final currentLang = Localizations.localeOf(context).languageCode;
    final localizedAppTitle = l10n?.appTitle ?? "VaniGuard";

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/branding/vaniguard_logo.png',
              width: 30,
              height: 30,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 8),
            Text(localizedAppTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // Active call guard simulation button
          IconButton(
            icon: Icon(
              _simulatedCallActive ? Icons.phone_in_talk : Icons.phone_outlined,
              color: _simulatedCallActive ? QuietVaultColors.danger : QuietVaultColors.textSecondary,
            ),
            tooltip: "Simulate Active Call",
            onPressed: () {
              setState(() => _simulatedCallActive = !_simulatedCallActive);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_simulatedCallActive
                      ? 'Simulated active call ON (Active Call Guard active)'
                      : 'Simulated active call OFF'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
          // Language toggle
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10.0),
            child: Row(
              children: [
                ...[
                  {'code': 'en', 'label': 'EN'},
                  {'code': 'hi', 'label': 'HI'},
                  {'code': 'te', 'label': 'TE'},
                  {'code': 'ta', 'label': 'TA'},
                ].map((lang) {
                  final isSel = currentLang == lang['code'];
                  return Padding(
                    padding: const EdgeInsets.only(right: 4.0),
                    child: GestureDetector(
                      onTap: () => VaniGuardApp.setLocale(context, Locale(lang['code']!)),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: isSel ? QuietVaultColors.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          lang['label']!,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isSel ? Colors.black : QuietVaultColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.privacy_tip_outlined, size: 24),
            tooltip: "Privacy & Consents",
            onPressed: () => Navigator.pushNamed(context, "/consents"),
          ),
          const SizedBox(width: 4),
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
                        width: 40,
                        height: 40,
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
                  const SizedBox(height: 10),
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
              leading: const Icon(Icons.send_rounded),
              title: const Text("Beneficiaries & Payees"),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, "/payees");
              },
            ),
            ListTile(
              leading: const Icon(Icons.qr_code_scanner_rounded),
              title: const Text("Scan UPI QR"),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, "/qr-scan");
              },
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long_rounded),
              title: const Text("Bill Payments"),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, "/pay-bills");
              },
            ),
            ListTile(
              leading: const Icon(Icons.mic_outlined),
              title: Text(
                l10n?.voiceBanking ?? "Voice Banking",
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
        backgroundColor: QuietVaultColors.amberAccent,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.mic, size: 26, color: Colors.black),
        label: const Text(
          "Voice Nav",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
        ),
        onPressed: _openVoiceNavigationDialog,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await _fetchAccounts();
            await _fetchRecentTransactions();
            await _checkPendingAlerts();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Active Call Warning Banner
                if (_simulatedCallActive) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: QuietVaultColors.danger.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: QuietVaultColors.danger.withOpacity(0.5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.phone_in_talk, color: QuietVaultColors.danger, size: 24),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            "Active Phone Call: Active Call Guard is protecting your payments.",
                            style: TextStyle(fontSize: 13, color: QuietVaultColors.danger, fontWeight: FontWeight.w600),
                          ),
                        ),
                        TextButton(
                          onPressed: () => setState(() => _simulatedCallActive = false),
                          child: const Text("End Call", style: TextStyle(color: QuietVaultColors.danger, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ],

                // Guardian Alert Card (Visible when transfer held under safety review)
                if (_hasPendingGuardianAlert) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 18),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C2C2C),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: QuietVaultColors.amberAccent, width: 2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.shield_outlined, color: QuietVaultColors.amberAccent, size: 26),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                "Guardian Alert: Action Required",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: QuietVaultColors.amberAccent,
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
                            color: QuietVaultColors.textPrimary,
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
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF242424),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: QuietVaultColors.amberAccent.withOpacity(0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.verified_user, color: QuietVaultColors.amberAccent, size: 18),
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

                // Primary Account Balance Card
                Semantics(
                  label: "Savings account ending in $_maskedAccount. Current balance: ${_formatPaise(_balancePaise)}.",
                  child: Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: const Color(0xFF242424),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: QuietVaultColors.amberAccent.withOpacity(0.4), width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Primary Savings Account ($_maskedAccount)",
                          style: const TextStyle(fontSize: 15, color: QuietVaultColors.textSecondary),
                        ),
                        const SizedBox(height: 10),
                        _isLoading
                            ? const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: QuietVaultColors.amberAccent,
                                    strokeWidth: 2.5,
                                  ),
                                ),
                              )
                            : Text(
                                _formatPaise(_balancePaise),
                                style: const TextStyle(
                                  fontSize: 34,
                                  fontWeight: FontWeight.w700,
                                  color: QuietVaultColors.amberAccent,
                                ),
                              ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Quick Actions: 4 Accessible Actions (Send Money, Scan QR, My QR, Pay Bills)
                Row(
                  children: [
                    Expanded(
                      child: _buildQuickActionCard(
                        icon: Icons.send_rounded,
                        label: "Send Money",
                        onTap: () => Navigator.pushNamed(context, "/payees"),
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildQuickActionCard(
                        icon: Icons.qr_code_scanner_rounded,
                        label: "Scan QR",
                        onTap: () => Navigator.pushNamed(context, "/qr-scan"),
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildQuickActionCard(
                        icon: Icons.qr_code_2_rounded,
                        label: "My QR",
                        onTap: _showMyQrDialog,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildQuickActionCard(
                        icon: Icons.receipt_long_rounded,
                        label: "Pay Bills",
                        onTap: () => Navigator.pushNamed(context, "/pay-bills"),
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Main Voice Action Button
                AccessibleButton(
                  label: "Open Voice Banking Session",
                  semanticsHint: "Starts interactive conversational banking session operable entirely by voice",
                  icon: Icons.mic,
                  onPressed: () {
                    Navigator.pushNamed(context, "/voice-session");
                  },
                ),
                const SizedBox(height: 12),

                AccessibleButton(
                  label: "Security & Coercion Monitor",
                  semanticsHint: "Opens live transparent risk signals display",
                  icon: Icons.security,
                  isSecondary: true,
                  onPressed: () {
                    Navigator.pushNamed(context, "/risk-monitor");
                  },
                ),
                const SizedBox(height: 26),

                // Recent Activity Section
                const Text(
                  "Recent Activity",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: QuietVaultColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),

                if (_recentTransactions.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF242424) : QuietVaultColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: const Center(
                      child: Text(
                        "No recent transactions yet. Spoken or QR payments will appear here in real time.",
                        style: TextStyle(fontSize: 14, color: QuietVaultColors.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else
                  ..._recentTransactions.map((tx) {
                    final amountPaise = (tx['amount_paise'] as num?)?.toInt() ?? 0;
                    final state = (tx['state'] ?? 'COMPLETED').toString();
                    final payee = (tx['payee_name'] ?? 'Verified Payee').toString();
                    final dateStr = (tx['created_at'] ?? '').toString();
                    String timeLabel = 'Recent';
                    if (dateStr.isNotEmpty) {
                      try {
                        final dt = DateTime.parse(dateStr).toLocal();
                        timeLabel = '${dt.day}/${dt.month} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
                      } catch (_) {}
                    }
                    return _buildTransactionTile(
                      title: payee,
                      subtitle: timeLabel,
                      amount: '- ${_formatPaise(amountPaise)}',
                      isDebit: true,
                      isDark: isDark,
                      status: state,
                    );
                  }),

                // Generous bottom spacing so Floating Action Button NEVER clips the last card on any screen size (down to 360dp width)
                const SizedBox(height: 120),
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
    String? status,
  }) {
    Color statusColor = QuietVaultColors.success;
    if (status == 'HELD') {
      statusColor = QuietVaultColors.amberAccent;
    } else if (status == 'CANCELLED') {
      statusColor = QuietVaultColors.danger;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF242424) : QuietVaultColors.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: QuietVaultColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 13, color: QuietVaultColors.textSecondary),
                    ),
                    if (status != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: statusColor.withOpacity(0.5)),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: isDebit ? const Color(0xFFFF5252) : QuietVaultColors.success,
            ),
          ),
        ],
      ),
    );
  }
}

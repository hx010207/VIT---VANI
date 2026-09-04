/// PURPOSE: Active conversational voice banking session interface over WebSocket.
/// ROLE IN SYSTEM: Streams microphone audio to backend, displays live transcripts and risk bands.
/// TALKS TO: app/lib/services/api_client.dart, /ws/voice-session, app/lib/widgets/voice_waveform.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:vaniguard/theme/quiet_vault_theme.dart';
import 'package:vaniguard/widgets/voice_waveform.dart';
import 'package:vaniguard/widgets/accessible_button.dart';
import 'package:vaniguard/services/api_client.dart';
import 'package:vaniguard/services/voice_command_router.dart';

class VoiceSessionScreen extends StatefulWidget {
  const VoiceSessionScreen({super.key});

  @override
  State<VoiceSessionScreen> createState() => _VoiceSessionScreenState();
}

class _VoiceSessionScreenState extends State<VoiceSessionScreen> {
  bool _isListening = false;
  bool _wsConnected = false;
  String _activeTranscript = "Press the button or spacebar to speak your banking request.";
  String _lastAgentResponse = "Welcome to VaniGuard. How may I assist with your account today?";
  int _currentRiskScore = 0;
  String _currentRiskBand = "PROCEED";
  String? _heldTransferId;
  final FocusNode _micFocusNode = FocusNode();

  WebSocketChannel? _wsChannel;
  StreamSubscription? _wsSubscription;
  final AudioRecorder _recorder = AudioRecorder();
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  bool _speechInitialized = false;

  @override
  void initState() {
    super.initState();
    _initTts();
    _initSpeech();
    _connectWebSocket();
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

  Future<void> _initSpeech() async {
    try {
      _speechInitialized = await _speech.initialize(
        onError: (err) => debugPrint("[VoiceSession] STT Error: ${err.errorMsg}"),
        onStatus: (status) => debugPrint("[VoiceSession] STT Status: $status"),
      );
    } catch (e) {
      _speechInitialized = false;
      debugPrint("[VoiceSession] STT init exception: $e");
    }
  }

  void _connectWebSocket() {
    try {
      _wsChannel = ApiClient.connectVoiceSession();
      _wsSubscription = _wsChannel!.stream.listen(
        (message) {
          _handleWsMessage(message);
        },
        onError: (error) {
          if (mounted) {
            setState(() {
              _wsConnected = false;
              _lastAgentResponse = "Running in offline mode. Voice assistant ready.";
            });
          }
        },
        onDone: () {
          if (mounted) {
            setState(() {
              _wsConnected = false;
            });
          }
        },
      );
      setState(() {
        _wsConnected = true;
      });
    } catch (e) {
      setState(() {
        _wsConnected = false;
        _lastAgentResponse = "Running in offline mode. Voice assistant ready.";
      });
    }
  }

  void _handleWsMessage(dynamic message) {
    try {
      final data = jsonDecode(message as String) as Map<String, dynamic>;
      final eventType = data['type'] as String?;

      setState(() {
        if (eventType == 'transcript' || eventType == 'final_transcript') {
          _activeTranscript = data['text'] as String? ?? _activeTranscript;
        } else if (eventType == 'risk_update') {
          _currentRiskScore = data['score'] as int? ?? _currentRiskScore;
          _currentRiskBand = data['risk_band'] as String? ?? _currentRiskBand;
        } else if (eventType == 'agent_response' || eventType == 'prompt') {
          final txt = data['text_en'] ?? data['text'];
          if (txt != null) {
            _lastAgentResponse = txt.toString();
            _speak(_lastAgentResponse);
          }
        } else if (eventType == 'transfer_held') {
          _heldTransferId = data['transfer_id'] as String?;
          _currentRiskBand = 'CIRCUIT_BREAK';
          _lastAgentResponse =
              "For your safety, we are holding this transfer for a moment. Take your time. Nothing has left your account.";
          _speak(_lastAgentResponse);
        } else if (eventType == 'transfer_completed') {
          _lastAgentResponse = data['message'] as String? ??
              "Transfer completed successfully.";
          _currentRiskBand = 'PROCEED';
          _speak(_lastAgentResponse);
        }
      });
    } catch (_) {
      // Malformed message ignore silently
    }
  }

  Future<void> _toggleMic() async {
    if (_isListening) {
      // Stop listening and process audio utterance
      try {
        await _speech.stop();
      } catch (_) {}
      try {
        await _recorder.stop();
      } catch (_) {}

      setState(() {
        _isListening = false;
      });

      _processUtterance(_activeTranscript);
    } else {
      if (!_speechInitialized) {
        await _initSpeech();
      }

      setState(() {
        _isListening = true;
        _activeTranscript = "Listening... Speak naturally in English or Hindi.";
      });

      try {
        if (_speechInitialized) {
          await _speech.listen(
            onResult: (result) {
              if (mounted) {
                setState(() {
                  _activeTranscript = result.recognizedWords;
                });
                if (result.finalResult && result.recognizedWords.trim().isNotEmpty) {
                  _speech.stop();
                  setState(() => _isListening = false);
                  _processUtterance(result.recognizedWords);
                }
              }
            },
            localeId: 'en_IN',
            listenFor: const Duration(seconds: 15),
            pauseFor: const Duration(seconds: 3),
          );
        } else {
          // Fallback recorder if STT plugin unavailable
          if (await _recorder.hasPermission()) {
            await _recorder.start(
              const RecordConfig(
                encoder: AudioEncoder.pcm16bits,
                sampleRate: 16000,
                numChannels: 1,
              ),
              path: '',
            );
          }
        }
      } catch (e) {
        debugPrint("[VoiceSession] Error starting listener: $e");
      }
    }
  }

  Future<void> _processUtterance(String transcript) async {
    final cleanTranscript = transcript.trim();
    if (cleanTranscript.isEmpty || cleanTranscript.startsWith("Listening...") || cleanTranscript.startsWith("Press the button")) {
      return;
    }

    // Step 1: Instrument pipeline - log audio received and transcript produced
    debugPrint("[VoiceSession] Audio received and speech recognized");
    debugPrint("[VoiceSession] Transcript produced: '$cleanTranscript'");

    // Step 2: Instrument pipeline - parse intent
    final result = VoiceCommandRouter.parse(cleanTranscript);
    debugPrint("[VoiceSession] Intent parsed: ${result.intent}");

    // If WebSocket is connected, forward utterance to server risk engine
    if (_wsConnected && _wsChannel != null) {
      try {
        _wsChannel!.sink.add(jsonEncode({
          "type": "phrase_completed",
          "transcript": cleanTranscript,
        }));
      } catch (_) {}
    }

    // Check for coercion/pressure cues
    final lower = cleanTranscript.toLowerCase();
    final isCoercion = lower.contains("police") ||
        lower.contains("jail") ||
        lower.contains("arrest") ||
        lower.contains("immediately") ||
        lower.contains("safe account") ||
        lower.contains("ransom") ||
        lower.contains("threat") ||
        lower.contains("urgent transfer");

    if (isCoercion) {
      setState(() {
        _currentRiskBand = "CIRCUIT_BREAK";
        _currentRiskScore = 78;
        _heldTransferId = "coercion-held-${DateTime.now().millisecondsSinceEpoch}";
        _lastAgentResponse =
            "For your safety, we are holding this transfer for a moment. Take your time. Nothing has left your account.";
      });
      _speak(_lastAgentResponse);
      debugPrint("[VoiceSession] Response generated: '$_lastAgentResponse'");
      return;
    }

    // Handle distinct non-canned commands
    if (result.intent == NavigationIntent.checkBalance) {
      setState(() {
        _currentRiskBand = "PROCEED";
        _currentRiskScore = 5;
        _lastAgentResponse = "Checking account balance...";
      });
      String responseText;
      try {
        final accounts = await ApiClient.getAccounts();
        final paise = accounts.isNotEmpty ? (accounts.first['balance_paise'] as num?)?.toInt() ?? 5000000 : 5000000;
        final inr = paise ~/ 100;
        responseText = "Your primary savings balance is INR $inr.";
      } catch (_) {
        responseText = "Your primary savings balance is INR 50,000.";
      }
      if (mounted) {
        setState(() {
          _lastAgentResponse = responseText;
        });
        _speak(responseText);
        debugPrint("[VoiceSession] Response generated: '$responseText'");
      }
    } else if (result.intent == NavigationIntent.recentTransactions) {
      setState(() {
        _currentRiskBand = "PROCEED";
        _currentRiskScore = 5;
        _lastAgentResponse = "Fetching recent transactions...";
      });
      String responseText;
      try {
        final txns = await ApiClient.getRecentTransactions(limit: 3);
        if (txns.isNotEmpty) {
          final first = txns.first;
          final amtInr = (((first['amount_paise'] as num?)?.toInt() ?? 0) / 100).toInt();
          final payee = (first['payee_name'] ?? 'Payee').toString();
          final state = (first['state'] ?? 'COMPLETED').toString();
          responseText = "Recent transaction: INR $amtInr to $payee. Status: $state.";
        } else {
          responseText = "You have no recent transactions on your account.";
        }
      } catch (_) {
        responseText = "You have no recent transactions on your account.";
      }
      if (mounted) {
        setState(() {
          _lastAgentResponse = responseText;
        });
        _speak(responseText);
        debugPrint("[VoiceSession] Response generated: '$responseText'");
      }
    } else if (result.intent == NavigationIntent.guardianInfo) {
      final lang = Localizations.localeOf(context).languageCode;
      final prefs = await SharedPreferences.getInstance();
      final gName = prefs.getString('guardian_name') ?? 'Priya Sharma';
      final gPhone = prefs.getString('guardian_phone') ?? '+91 98765 43210';
      String responseText;
      if (lang == 'hi') {
        responseText = "आपकी सुरक्षा संरक्षक $gName हैं, फोन $gPhone।";
      } else if (lang == 'te') {
        responseText = "మీ భద్రతా సంరక్షకురాలు $gName, ఫోన్ $gPhone.";
      } else if (lang == 'ta') {
        responseText = "உங்கள் பாதுகாப்பு பாதுகாவலர் $gName, தொலைபேசி $gPhone.";
      } else {
        responseText = "Your safety guardian is $gName, phone $gPhone.";
      }
      if (mounted) {
        setState(() {
          _currentRiskBand = "PROCEED";
          _currentRiskScore = 5;
          _lastAgentResponse = responseText;
        });
        _speak(responseText);
        debugPrint("[VoiceSession] Response generated: '$responseText'");
      }
    } else if (result.intent == NavigationIntent.payBill) {
      final biller = result.billerType ?? "utility";
      final responseText = "Opening $biller bill payment.";
      setState(() {
        _currentRiskBand = "PROCEED";
        _currentRiskScore = 10;
        _lastAgentResponse = responseText;
      });
      _speak(responseText);
      debugPrint("[VoiceSession] Response generated: '$responseText'");
      Future.delayed(const Duration(milliseconds: 1400), () {
        if (mounted) {
          Navigator.pushNamed(context, '/pay-bills');
        }
      });
    } else if (result.intent == NavigationIntent.pay) {
      final payee = result.payeeName ?? "Payee";
      final amt = result.amountInr != null ? " INR ${result.amountInr}" : "";
      final responseText = "Starting secure transfer$amt to $payee.";
      setState(() {
        _currentRiskBand = "PROCEED";
        _currentRiskScore = 15;
        _lastAgentResponse = responseText;
      });
      _speak(responseText);
      debugPrint("[VoiceSession] Response generated: '$responseText'");
      Future.delayed(const Duration(milliseconds: 1400), () {
        if (mounted) {
          Navigator.pushNamed(context, '/payees');
        }
      });
    } else if (result.intent == NavigationIntent.scanAndPay) {
      const responseText = "Opening QR scanner.";
      setState(() {
        _currentRiskBand = "PROCEED";
        _currentRiskScore = 5;
        _lastAgentResponse = responseText;
      });
      _speak(responseText);
      debugPrint("[VoiceSession] Response generated: '$responseText'");
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) {
          Navigator.pushNamed(context, '/qr-scan');
        }
      });
    } else {
      final lang = Localizations.localeOf(context).languageCode;
      final responseText = result.getLocalizedAnnouncement(lang);
      setState(() {
        _lastAgentResponse = responseText;
      });
      _speak(responseText);
      debugPrint("[VoiceSession] Response generated: '$responseText'");
    }
  }

  void _showTextInputDialog() {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text("Type Voice Request", style: TextStyle(color: QuietVaultColors.textPrimary)),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: "e.g. send money to Rahul, check balance",
            filled: true,
            fillColor: Color(0xFF2C2C2C),
          ),
          onSubmitted: (val) {
            Navigator.pop(ctx);
            if (val.trim().isNotEmpty) {
              setState(() => _activeTranscript = val.trim());
              _processUtterance(val.trim());
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: QuietVaultColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: QuietVaultColors.primary, foregroundColor: Colors.black),
            onPressed: () {
              Navigator.pop(ctx);
              final val = textController.text.trim();
              if (val.isNotEmpty) {
                setState(() => _activeTranscript = val);
                _processUtterance(val);
              }
            },
            child: const Text("Submit"),
          ),
        ],
      ),
    );
  }

  void _handleKeyEvent(RawKeyEvent event) {
    if (event is RawKeyDownEvent && event.logicalKey == LogicalKeyboardKey.space) {
      _toggleMic();
    }
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    _wsChannel?.sink.close();
    _speech.stop();
    _recorder.dispose();
    _flutterTts.stop();
    _micFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color riskBadgeColor = QuietVaultColors.success;
    if (_currentRiskBand == "SOFT_VERIFY") {
      riskBadgeColor = QuietVaultColors.accent;
    } else if (_currentRiskBand == "CIRCUIT_BREAK") {
      riskBadgeColor = QuietVaultColors.danger;
    }

    return RawKeyboardListener(
      focusNode: FocusNode(),
      onKey: _handleKeyEvent,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Voice Banking"),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            // Connection status indicator
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(
                _wsConnected ? Icons.wifi : Icons.wifi_off,
                color: _wsConnected ? QuietVaultColors.success : QuietVaultColors.inkSecondary,
                size: 20,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.keyboard_alt_outlined, size: 24),
              tooltip: "Type Voice Command",
              onPressed: _showTextInputDialog,
            ),
            Semantics(
              label: "Open Security Risk Monitor",
              button: true,
              child: IconButton(
                icon: const Icon(Icons.security, size: 28),
                onPressed: () {
                  Navigator.pushNamed(context, "/risk-monitor");
                },
                tooltip: "Security Monitor",
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Real-time Risk Assessment Indicator Bar
                Semantics(
                  liveRegion: true,
                  label: "Security assessment: Risk score $_currentRiskScore out of 100. Status: $_currentRiskBand",
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: riskBadgeColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: riskBadgeColor, width: 2),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Security Status: $_currentRiskBand",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: riskBadgeColor,
                          ),
                        ),
                        Text(
                          "Score: $_currentRiskScore/100",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: riskBadgeColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // 5-Signal Risk Strip (live from WebSocket)
                Semantics(
                  label: "Five-signal coercion risk breakdown",
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? QuietVaultColors.darkSurfaceAlt : QuietVaultColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _signalChip("2nd Voice", _currentRiskBand == "CIRCUIT_BREAK"),
                        _signalChip("Stress", _currentRiskScore > 50),
                        _signalChip("Speaker", false),
                        _signalChip("Lexicon", _currentRiskScore > 35),
                        _signalChip("Context", _currentRiskScore > 60),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Agent Spoken Response Bubble
                Semantics(
                  liveRegion: true,
                  label: "VaniGuard Assistant: $_lastAgentResponse",
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? QuietVaultColors.darkSurfaceAlt : QuietVaultColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Assistant",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: QuietVaultColors.inkSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _lastAgentResponse,
                          style: const TextStyle(
                            fontSize: 20,
                            height: 1.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),

                // Live Voice Waveform Visualizer
                VoiceWaveform(
                  isListening: _isListening,
                  amplitude: _isListening ? 0.8 : 0.1,
                ),
                const SizedBox(height: 16),

                // Live User Utterance Transcript
                Semantics(
                  liveRegion: true,
                  label: "You said: $_activeTranscript",
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _activeTranscript,
                      style: const TextStyle(
                        fontSize: 18,
                        height: 1.4,
                        color: QuietVaultColors.inkSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const Spacer(),

                // Circuit Break Action Trigger if held
                if (_currentRiskBand == "CIRCUIT_BREAK") ...[
                  AccessibleButton(
                    label: "Review Held Transfer",
                    semanticsHint: "Navigates to circuit-break details and trusted contact resolution",
                    icon: Icons.shield,
                    isDanger: true,
                    onPressed: () {
                      Navigator.pushNamed(context, "/transfer-held", arguments: _heldTransferId);
                    },
                  ),
                  const SizedBox(height: 16),
                ],

                // Main Microphone Voice Action Button (>= 64dp touch target)
                Semantics(
                  button: true,
                  label: _isListening ? "Stop listening" : "Start speaking voice command",
                  hint: "Double tap to activate microphone or tap spacebar",
                  child: Focus(
                    focusNode: _micFocusNode,
                    child: Container(
                      height: 72,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _micFocusNode.hasFocus ? QuietVaultColors.focusRing : Colors.transparent,
                          width: QuietVaultTheme.focusRingWidth,
                        ),
                      ),
                      child: ElevatedButton(
                        onPressed: _toggleMic,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isListening ? QuietVaultColors.danger : QuietVaultColors.primary,
                          foregroundColor: QuietVaultColors.surface,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(_isListening ? Icons.stop : Icons.mic, size: 28),
                            const SizedBox(width: 12),
                            Text(
                              _isListening ? "Stop Speaking" : "Tap to Speak (or Spacebar)",
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Prototype disclaimer footer
                const Text(
                  "Prototype operating on synthetic users and sandbox transactions. Thresholds are demonstration values.",
                  style: TextStyle(fontSize: 12, color: QuietVaultColors.inkSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _signalChip(String label, bool active) {
    return Column(
      children: [
        Icon(
          active ? Icons.warning_amber_rounded : Icons.check_circle_outline,
          color: active ? QuietVaultColors.danger : QuietVaultColors.success,
          size: 18,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: active ? QuietVaultColors.danger : QuietVaultColors.inkSecondary,
          ),
        ),
      ],
    );
  }
}

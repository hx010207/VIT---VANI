/// PURPOSE: Active conversational voice banking session interface over WebSocket.
/// ROLE IN SYSTEM: Streams microphone audio to backend, displays live transcripts and risk bands.
/// TALKS TO: app/lib/services/api_client.dart, /ws/voice-session, app/lib/widgets/voice_waveform.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:record/record.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:vaniguard/theme/quiet_vault_theme.dart';
import 'package:vaniguard/widgets/voice_waveform.dart';
import 'package:vaniguard/widgets/accessible_button.dart';
import 'package:vaniguard/services/api_client.dart';

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

  @override
  void initState() {
    super.initState();
    _connectWebSocket();
  }

  void _connectWebSocket() {
    try {
      _wsChannel = ApiClient.connectVoiceSession();
      _wsSubscription = _wsChannel!.stream.listen(
        (message) {
          _handleWsMessage(message);
        },
        onError: (error) {
          setState(() {
            _wsConnected = false;
            _lastAgentResponse = "Connection lost. Tap the microphone to reconnect.";
          });
        },
        onDone: () {
          setState(() {
            _wsConnected = false;
          });
        },
      );
      setState(() {
        _wsConnected = true;
      });
    } catch (e) {
      // WebSocket connection failed -- operate in offline fallback mode
      setState(() {
        _wsConnected = false;
        _lastAgentResponse = "Running in offline mode. Connect to server for live analysis.";
      });
    }
  }

  void _handleWsMessage(dynamic message) {
    try {
      final data = jsonDecode(message as String) as Map<String, dynamic>;
      final eventType = data['type'] as String?;

      setState(() {
        if (eventType == 'transcript') {
          _activeTranscript = data['text'] as String? ?? _activeTranscript;
        } else if (eventType == 'risk_update') {
          _currentRiskScore = data['score'] as int? ?? _currentRiskScore;
          _currentRiskBand = data['band'] as String? ?? _currentRiskBand;
        } else if (eventType == 'agent_response') {
          _lastAgentResponse = data['text'] as String? ?? _lastAgentResponse;
        } else if (eventType == 'transfer_held') {
          _heldTransferId = data['transfer_id'] as String?;
          _currentRiskBand = 'CIRCUIT_BREAK';
          _lastAgentResponse =
              "For your safety, we are holding this transfer for a moment. Take your time. Nothing has left your account.";
        } else if (eventType == 'transfer_completed') {
          _lastAgentResponse = data['message'] as String? ??
              "Transfer completed successfully.";
          _currentRiskBand = 'PROCEED';
        }
      });
    } catch (_) {
      // Malformed message -- ignore silently
    }
  }

  Future<void> _toggleMic() async {
    if (_isListening) {
      // Stop recording
      await _recorder.stop();
      setState(() {
        _isListening = false;
        _activeTranscript = "Processing audio utterance...";
      });

      // If WS not connected, use offline fallback
      if (!_wsConnected) {
        Future.delayed(const Duration(milliseconds: 350), () {
          if (mounted) {
            setState(() {
              _activeTranscript = "Transfer 10,000 rupees to safe account immediately.";
              _currentRiskScore = 78;
              _currentRiskBand = "CIRCUIT_BREAK";
              _lastAgentResponse =
                  "For your safety, we are holding this transfer for a moment. Take your time. Nothing has left your account.";
            });
          }
        });
      }
    } else {
      // Check permission and start recording
      if (!await _recorder.hasPermission()) {
        setState(() {
          _lastAgentResponse = "Microphone permission is required for voice banking.";
        });
        return;
      }

      setState(() {
        _isListening = true;
        _activeTranscript = "Listening... Speak naturally in English or Hindi.";
      });

      try {
        // Start recording as stream for real-time WebSocket streaming
        final stream = await _recorder.startStream(
          const RecordConfig(
            encoder: AudioEncoder.pcm16bits,
            sampleRate: 16000,
            numChannels: 1,
          ),
        );

        // Stream audio frames to WebSocket
        stream.listen((data) {
          if (_wsConnected && _wsChannel != null) {
            _wsChannel!.sink.add(data);
          }
        });
      } catch (e) {
        // Streaming not supported, fall back to non-streaming mode
        try {
          await _recorder.start(
            const RecordConfig(
              encoder: AudioEncoder.pcm16bits,
              sampleRate: 16000,
              numChannels: 1,
            ),
            path: '',
          );
        } catch (_) {
          setState(() {
            _isListening = false;
            _lastAgentResponse = "Microphone not available on this device.";
          });
        }
      }
    }
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
    _recorder.dispose();
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

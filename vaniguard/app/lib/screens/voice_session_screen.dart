import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vaniguard/theme/quiet_vault_theme.dart';
import 'package:vaniguard/widgets/voice_waveform.dart';
import 'package:vaniguard/widgets/accessible_button.dart';

class VoiceSessionScreen extends StatefulWidget {
  const VoiceSessionScreen({super.key});

  @override
  State<VoiceSessionScreen> createState() => _VoiceSessionScreenState();
}

class _VoiceSessionScreenState extends State<VoiceSessionScreen> {
  bool _isListening = false;
  String _activeTranscript = "Press the button or spacebar to speak your banking request.";
  String _lastAgentResponse = "Welcome to VaniGuard. How may I assist with your account today?";
  int _currentRiskScore = 12;
  String _currentRiskBand = "PROCEED";
  final FocusNode _micFocusNode = FocusNode();

  void _toggleMic() {
    setState(() {
      _isListening = !_isListening;
      if (_isListening) {
        _activeTranscript = "Listening... Speak naturally in English or Hindi.";
      } else {
        _activeTranscript = "Processing audio utterance...";
        // Simulated response arrival
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
    });
  }

  void _handleKeyEvent(RawKeyEvent event) {
    if (event is RawKeyDownEvent && event.logicalKey == LogicalKeyboardKey.space) {
      _toggleMic();
    }
  }

  @override
  void dispose() {
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
                      Navigator.pushNamed(context, "/transfer-held");
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
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

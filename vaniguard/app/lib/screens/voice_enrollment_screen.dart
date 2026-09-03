import 'package:flutter/material.dart';
import 'package:vaniguard/theme/quiet_vault_theme.dart';
import 'package:vaniguard/widgets/accessible_button.dart';
import 'package:vaniguard/widgets/voice_waveform.dart';

class VoiceEnrollmentScreen extends StatefulWidget {
  const VoiceEnrollmentScreen({super.key});

  @override
  State<VoiceEnrollmentScreen> createState() => _VoiceEnrollmentScreenState();
}

class _VoiceEnrollmentScreenState extends State<VoiceEnrollmentScreen> {
  int _currentPhraseIndex = 0;
  bool _isRecording = false;
  final List<bool> _phraseAccepted = [false, false, false];
  final List<double> _phraseSnr = [0.0, 0.0, 0.0];
  final List<double> _phraseDuration = [0.0, 0.0, 0.0];

  final List<Map<String, String>> _phrases = [
    {
      "en": "My voice is my secure key for all my banking transactions.",
      "hi": "मेरी आवाज मेरे बैंकिंग लेनदेन की सुरक्षित चाबी है।"
    },
    {
      "en": "I authorize VaniGuard to protect my personal account.",
      "hi": "मैं वानीगार्ड को अपने व्यक्तिगत खाते की सुरक्षा के लिए अधिकृत करता हूँ।"
    },
    {
      "en": "Today is a safe day for my verified digital transfers.",
      "hi": "आज मेरे डिजिटल ट्रांसफर के लिए एक सुरक्षित दिन है।"
    }
  ];

  void _recordPhrase() {
    setState(() {
      _isRecording = true;
    });

    // Simulate 3.5s clean recording session meeting quality threshold
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) {
        setState(() {
          _isRecording = false;
          _phraseAccepted[_currentPhraseIndex] = true;
          _phraseSnr[_currentPhraseIndex] = 18.5;
          _phraseDuration[_currentPhraseIndex] = 3.6;
          if (_currentPhraseIndex < 2) {
            _currentPhraseIndex++;
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allComplete = _phraseAccepted.every((a) => a);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Voice Enrollment"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Progress Indicator
              Semantics(
                label: "Enrollment progress: Phrase ${_currentPhraseIndex + 1} of 3",
                child: Row(
                  children: List.generate(3, (index) {
                    final isDone = _phraseAccepted[index];
                    final isCurrent = index == _currentPhraseIndex;
                    return Expanded(
                      child: Container(
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: isDone
                              ? QuietVaultColors.success
                              : (isCurrent ? QuietVaultColors.primary : QuietVaultColors.surfaceAlt),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 24),

              // Title and Instruction
              const Text(
                "Create Voiceprint Identity",
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                "Please read each phrase clearly. Only the mathematical voiceprint embedding is saved; raw audio is never permanently stored.",
                style: TextStyle(fontSize: 18, color: QuietVaultColors.inkSecondary),
              ),
              const SizedBox(height: 32),

              // Active Phrase Display Card
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDark ? QuietVaultColors.darkSurfaceAlt : QuietVaultColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Phrase ${_currentPhraseIndex + 1} of 3",
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: QuietVaultColors.inkSecondary),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _phrases[_currentPhraseIndex]["en"]!,
                        style: const TextStyle(fontSize: 22, height: 1.4, fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _phrases[_currentPhraseIndex]["hi"]!,
                        style: const TextStyle(fontSize: 20, height: 1.4, color: QuietVaultColors.inkSecondary),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      VoiceWaveform(
                        isListening: _isRecording,
                        amplitude: _isRecording ? 0.75 : 0.05,
                      ),
                      if (_phraseAccepted[_currentPhraseIndex]) ...[
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.check_circle, color: QuietVaultColors.success, size: 24),
                            SizedBox(width: 8),
                            Text("Quality Verified (SNR 18.5 dB, 3.6s clean speech)", style: TextStyle(fontSize: 16, color: QuietVaultColors.success)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Action Buttons
              if (allComplete) ...[
                AccessibleButton(
                  label: "Complete Enrollment",
                  semanticsHint: "Voice enrollment verified. Proceed to dashboard.",
                  icon: Icons.check,
                  onPressed: () {
                    Navigator.pushNamedAndRemoveUntil(context, "/", (route) => false);
                  },
                ),
              ] else ...[
                AccessibleButton(
                  label: _isRecording ? "Listening..." : "Record Phrase ${_currentPhraseIndex + 1}",
                  semanticsHint: "Reads phrase into microphone",
                  icon: _isRecording ? Icons.mic : Icons.mic_none,
                  onPressed: _isRecording ? null : _recordPhrase,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

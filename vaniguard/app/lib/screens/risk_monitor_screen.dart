/// PURPOSE: Real-time explainability monitor visualizing the 5 coercion risk signals.
/// ROLE IN SYSTEM: Displays score contributions, active decision band, and evidence summaries.
/// TALKS TO: app/lib/theme/quiet_vault_theme.dart, app/lib/screens/voice_session_screen.dart
import 'package:flutter/material.dart';
import 'package:vaniguard/theme/quiet_vault_theme.dart';
import 'package:vaniguard/widgets/accessible_button.dart';

class RiskMonitorScreen extends StatefulWidget {
  const RiskMonitorScreen({super.key});

  @override
  State<RiskMonitorScreen> createState() => _RiskMonitorScreenState();
}

class _RiskMonitorScreenState extends State<RiskMonitorScreen> {
  int _totalScore = 18;
  String _riskBand = "PROCEED";

  // 5 Transparent Signals
  int _secondVoiceScore = 0;       // Max 35
  int _vocalStressScore = 0;       // Max 20
  int _speakerMismatchScore = 0;   // Max 30
  int _scamScriptScore = 8;        // Max 25
  int _contextualAnomalyScore = 10;// Max 20

  String _secondVoiceEvidence = "No secondary vocal presence detected in pause segments";
  String _vocalStressEvidence = "Pitch variance and jitter within personal baseline envelope";
  String _speakerMismatchEvidence = "Enrolled speaker verified (cosine similarity: 0.88 >= 0.68)";
  String _scamScriptEvidence = "No critical scam script markers detected";
  String _contextualEvidence = "Transfer amount within normal 90-day activity profile";

  void _simulateScamCoercionEscalation() {
    setState(() {
      _secondVoiceScore = 35;
      _secondVoiceEvidence = "Secondary coach detected in pause intervals: distinct F0 195Hz (delta 60Hz)";
      _vocalStressScore = 16;
      _vocalStressEvidence = "Pitch variance elevated 1.8x, jitter elevated 1.5x vs personal baseline";
      _speakerMismatchScore = 0;
      _speakerMismatchEvidence = "Enrolled speaker voice confirmed (similarity 0.82)";
      _scamScriptScore = 25;
      _scamScriptEvidence = "Matched scam markers across [authority, urgency, secrecy]: 'cbi', 'immediately', 'safe account'";
      _contextualAnomalyScore = 14;
      _contextualEvidence = "Amount exceeds 90-day maximum, transaction velocity high";

      _totalScore = _secondVoiceScore + _vocalStressScore + _speakerMismatchScore + _scamScriptScore + _contextualAnomalyScore;
      if (_totalScore > 100) _totalScore = 100;
      _riskBand = "CIRCUIT_BREAK";
    });
  }

  void _resetToNominal() {
    setState(() {
      _secondVoiceScore = 0;
      _secondVoiceEvidence = "No secondary vocal presence detected in pause segments";
      _vocalStressScore = 4;
      _vocalStressEvidence = "Pitch variance and jitter within personal baseline envelope";
      _speakerMismatchScore = 0;
      _speakerMismatchEvidence = "Enrolled speaker verified (cosine similarity: 0.88 >= 0.68)";
      _scamScriptScore = 0;
      _scamScriptEvidence = "No critical scam script markers detected";
      _contextualAnomalyScore = 6;
      _contextualEvidence = "Transfer amount within normal 90-day activity profile";

      _totalScore = 10;
      _riskBand = "PROCEED";
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color bandColor = QuietVaultColors.success;
    if (_riskBand == "SOFT_VERIFY") {
      bandColor = QuietVaultColors.accent;
    } else if (_riskBand == "CIRCUIT_BREAK") {
      bandColor = QuietVaultColors.danger;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Security Signal Monitor"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Total Risk Meter Card
              Semantics(
                liveRegion: true,
                label: "Total Coercion Risk Score: $_totalScore out of 100. Decision band: $_riskBand",
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDark ? QuietVaultColors.darkSurfaceAlt : QuietVaultColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: bandColor, width: 2.5),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Coercion Risk Score", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: bandColor,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _riskBand,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: QuietVaultColors.surface),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        "$_totalScore / 100",
                        style: TextStyle(fontSize: 48, fontWeight: FontWeight.w700, color: bandColor),
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: _totalScore / 100.0,
                          minHeight: 12,
                          backgroundColor: Colors.grey.withOpacity(0.2),
                          valueColor: AlwaysStoppedAnimation<Color>(bandColor),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),

              const Text(
                "Transparent Signal Breakdown",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                "All stress signals are self-referenced to the user's personal baseline. Zero demographic or age stereotyping.",
                style: TextStyle(fontSize: 16, color: QuietVaultColors.inkSecondary),
              ),
              const SizedBox(height: 20),

              // Signal 1: Second Voice Detection (35 pts)
              _buildSignalCard(
                title: "1. Second Voice Coaching Detection",
                score: _secondVoiceScore,
                maxScore: 35,
                evidence: _secondVoiceEvidence,
                isDark: isDark,
              ),

              // Signal 2: Vocal Stress Index (20 pts)
              _buildSignalCard(
                title: "2. Vocal Stress Index (Self-Referenced)",
                score: _vocalStressScore,
                maxScore: 20,
                evidence: _vocalStressEvidence,
                isDark: isDark,
              ),

              // Signal 3: Speaker Verification Mismatch (30 pts)
              _buildSignalCard(
                title: "3. Speaker Verification Identity",
                score: _speakerMismatchScore,
                maxScore: 30,
                evidence: _speakerMismatchEvidence,
                isDark: isDark,
              ),

              // Signal 4: Coercion Script Markers (25 pts)
              _buildSignalCard(
                title: "4. Coercion Script Lexicon Matcher",
                score: _scamScriptScore,
                maxScore: 25,
                evidence: _scamScriptEvidence,
                isDark: isDark,
              ),

              // Signal 5: Contextual Anomaly (20 pts)
              _buildSignalCard(
                title: "5. Contextual & Behavioral Anomaly",
                score: _contextualAnomalyScore,
                maxScore: 20,
                evidence: _contextualEvidence,
                isDark: isDark,
              ),

              const SizedBox(height: 28),

              // Real-Time Simulator Action Buttons
              AccessibleButton(
                label: "Simulate Scam Coercion Attack",
                semanticsHint: "Simulates incoming coercion audio triggering Circuit-Break hold",
                isDanger: true,
                icon: Icons.warning_amber_rounded,
                onPressed: _simulateScamCoercionEscalation,
              ),
              const SizedBox(height: 12),
              AccessibleButton(
                label: "Reset to Clean Normal State",
                semanticsHint: "Resets all risk signals to clean baseline status",
                isSecondary: true,
                onPressed: _resetToNominal,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSignalCard({
    required String title,
    required int score,
    required int maxScore,
    required String evidence,
    required bool isDark,
  }) {
    final bool hasRisk = score > 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? QuietVaultColors.darkSurfaceAlt : QuietVaultColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: hasRisk ? Border.all(color: QuietVaultColors.accent, width: 1.5) : Border.none,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              ),
              Text(
                "$score / $maxScore pts",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: hasRisk ? QuietVaultColors.accent : QuietVaultColors.inkSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(evidence, style: const TextStyle(fontSize: 16, height: 1.4, color: QuietVaultColors.inkSecondary)),
        ],
      ),
    );
  }
}

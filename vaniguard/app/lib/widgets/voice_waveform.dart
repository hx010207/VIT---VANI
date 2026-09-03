/// PURPOSE: Real-time animated acoustic waveform visualizer widget.
/// ROLE IN SYSTEM: Renders visual feedback during microphone capture and voice session streaming.
/// TALKS TO: app/lib/theme/quiet_vault_theme.dart, app/lib/screens/voice_session_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:vaniguard/theme/quiet_vault_theme.dart';

class VoiceWaveform extends StatefulWidget {
  final bool isListening;
  final double amplitude;
  final Color? color;

  const VoiceWaveform({
    super.key,
    required this.isListening,
    this.amplitude = 0.5,
    this.color,
  });

  @override
  State<VoiceWaveform> createState() => _VoiceWaveformState();
}

class _VoiceWaveformState extends State<VoiceWaveform>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Respect user's reduced-motion preference
    final bool reduceMotion = MediaQuery.of(context).disableAnimations;
    final Color barColor = widget.color ??
        (Theme.of(context).brightness == Brightness.dark
            ? QuietVaultColors.darkPrimary
            : QuietVaultColors.primary);

    return Semantics(
      label: widget.isListening
          ? "Microphone active. Live audio waveform responding to voice."
          : "Microphone paused. Audio waveform inactive.",
      child: Container(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(24, (index) {
                double heightFactor = 0.15;
                if (widget.isListening && !reduceMotion) {
                  final phase = (index * 0.25) + (_controller.value * 2 * pi);
                  final wave = (sin(phase) + 1.0) / 2.0;
                  heightFactor = 0.2 + (wave * widget.amplitude * 0.75);
                } else if (widget.isListening && reduceMotion) {
                  heightFactor = 0.45;
                }

                return Container(
                  width: 4,
                  height: 64 * heightFactor,
                  margin: const EdgeInsets.symmetric(horizontal: 2.5),
                  decoration: BoxDecoration(
                    color: barColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }),
            );
          },
        ),
      ),
    );
  }
}

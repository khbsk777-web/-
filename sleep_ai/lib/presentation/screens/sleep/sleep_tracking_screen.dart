import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../viewmodels/sleep_viewmodel.dart';

class SleepTrackingScreen extends ConsumerWidget {
  const SleepTrackingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sleepViewModelProvider);
    final vm = ref.read(sleepViewModelProvider.notifier);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: AppColors.sleepGradient,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // App bar
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    Text(
                      '睡眠記録',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const Spacer(),
                    if (state.isRecording)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.error.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border:
                              Border.all(color: AppColors.error.withOpacity(0.5)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.error,
                              ),
                            ).animate(
                              onPlay: (c) => c.repeat(),
                            ).fade(duration: 800.ms),
                            const SizedBox(width: 6),
                            const Text(
                              'REC',
                              style: TextStyle(
                                  color: AppColors.error,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Main circle button
                    GestureDetector(
                      onTap: () async {
                        if (state.isRecording) {
                          await vm.stopSleep();
                        } else {
                          await vm.startSleep();
                        }
                      },
                      child: _SleepButton(
                        isRecording: state.isRecording,
                        isSnoring: state.isSnoring,
                        decibel: state.currentDecibel,
                      ),
                    ),

                    const SizedBox(height: 40),

                    if (state.isRecording && state.activeSession != null) ...[
                      _ElapsedTimer(
                          startTime: state.activeSession!.startTime),
                      const SizedBox(height: 8),
                      Text(
                        '就寝: ${DateFormat('HH:mm').format(state.activeSession!.startTime)}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ] else
                      Text(
                        'タップして睡眠を開始',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(color: AppColors.textSecondary),
                      ),

                    const SizedBox(height: 60),

                    // Snore stats
                    if (state.isRecording)
                      _SnoreStatsRow(state: state),
                  ],
                ),
              ),

              // Decibel meter
              if (state.isRecording) _DecibelMeter(db: state.currentDecibel),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _SleepButton extends StatelessWidget {
  final bool isRecording;
  final bool isSnoring;
  final double decibel;

  const _SleepButton({
    required this.isRecording,
    required this.isSnoring,
    required this.decibel,
  });

  @override
  Widget build(BuildContext context) {
    final pulseScale = isSnoring ? 1.05 + (decibel / 1000) : 1.0;

    return AnimatedScale(
      scale: pulseScale,
      duration: const Duration(milliseconds: 200),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer glow
          Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  (isRecording ? AppColors.primary : AppColors.surfaceElevated)
                      .withOpacity(0.3),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          // Main button
          Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isRecording
                    ? [AppColors.error, AppColors.accent]
                    : AppColors.primaryGradient,
              ),
              boxShadow: [
                BoxShadow(
                  color: (isRecording ? AppColors.error : AppColors.primary)
                      .withOpacity(0.4),
                  blurRadius: 40,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: Icon(
              isRecording ? Icons.stop_rounded : Icons.bedtime_rounded,
              color: Colors.white,
              size: 72,
            ),
          ),
        ],
      ),
    );
  }
}

class _ElapsedTimer extends StatefulWidget {
  final DateTime startTime;
  const _ElapsedTimer({required this.startTime});

  @override
  State<_ElapsedTimer> createState() => _ElapsedTimerState();
}

class _ElapsedTimerState extends State<_ElapsedTimer> {
  late final Stream<Duration> _stream;

  @override
  void initState() {
    super.initState();
    _stream = Stream.periodic(const Duration(seconds: 1), (_) {
      return DateTime.now().difference(widget.startTime);
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: _stream,
      builder: (context, snap) {
        final d = snap.data ?? Duration.zero;
        final h = d.inHours.toString().padLeft(2, '0');
        final m = (d.inMinutes % 60).toString().padLeft(2, '0');
        final s = (d.inSeconds % 60).toString().padLeft(2, '0');
        return Text(
          '$h:$m:$s',
          style: Theme.of(context).textTheme.displayMedium?.copyWith(
                fontFeatures: [const FontFeature.tabularFigures()],
              ),
        );
      },
    );
  }
}

class _SnoreStatsRow extends StatelessWidget {
  final SleepState state;
  const _SnoreStatsRow({required this.state});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _StatChip(
          icon: Icons.mic_rounded,
          label: 'いびき',
          value: '${state.currentSnoreEvents.length}回',
          color: state.isSnoring ? AppColors.accent : AppColors.textSecondary,
        ),
        const SizedBox(width: 24),
        _StatChip(
          icon: Icons.timer_rounded,
          label: '総時間',
          value: _formatSnoreTime(state.currentSnoreEvents
              .fold(0, (s, e) => s + (e.durationSeconds ?? 0))),
          color: AppColors.textSecondary,
        ),
      ],
    );
  }

  String _formatSnoreTime(int seconds) {
    if (seconds < 60) return '${seconds}秒';
    return '${seconds ~/ 60}分${seconds % 60}秒';
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                color: color, fontSize: 18, fontWeight: FontWeight.w700)),
        Text(label,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 12)),
      ],
    );
  }
}

class _DecibelMeter extends StatelessWidget {
  final double db;
  const _DecibelMeter({required this.db});

  @override
  Widget build(BuildContext context) {
    final normalized = (db.clamp(30.0, 80.0) - 30.0) / 50.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('音量',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 12)),
              Text('${db.toStringAsFixed(1)} dB',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: normalized,
              backgroundColor: AppColors.surfaceElevated,
              valueColor: AlwaysStoppedAnimation(
                db >= 45 ? AppColors.accent : AppColors.primary,
              ),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/sleep_session.dart';
import '../../data/models/snore_event.dart';
import '../../data/repositories/sleep_repository.dart';
import '../../services/audio/snore_detector.dart';
import '../../services/background/background_service.dart';

class SleepState {
  final SleepSession? activeSession;
  final List<SnoreEvent> currentSnoreEvents;
  final double currentDecibel;
  final bool isRecording;
  final bool isSnoring;
  final String? error;

  const SleepState({
    this.activeSession,
    this.currentSnoreEvents = const [],
    this.currentDecibel = 0,
    this.isRecording = false,
    this.isSnoring = false,
    this.error,
  });

  SleepState copyWith({
    SleepSession? activeSession,
    List<SnoreEvent>? currentSnoreEvents,
    double? currentDecibel,
    bool? isRecording,
    bool? isSnoring,
    String? error,
    bool clearSession = false,
  }) =>
      SleepState(
        activeSession: clearSession ? null : (activeSession ?? this.activeSession),
        currentSnoreEvents: currentSnoreEvents ?? this.currentSnoreEvents,
        currentDecibel: currentDecibel ?? this.currentDecibel,
        isRecording: isRecording ?? this.isRecording,
        isSnoring: isSnoring ?? this.isSnoring,
        error: error,
      );
}

final sleepViewModelProvider =
    StateNotifierProvider<SleepViewModel, SleepState>((ref) {
  return SleepViewModel(SleepRepository(), SnoreDetector());
});

class SleepViewModel extends StateNotifier<SleepState> {
  final SleepRepository _repo;
  final SnoreDetector _detector;
  StreamSubscription? _snoreSubscription;
  StreamSubscription? _decibelSubscription;

  SleepViewModel(this._repo, this._detector) : super(const SleepState()) {
    _checkActiveSession();
  }

  Future<void> _checkActiveSession() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final session = await _repo.getActiveSession(uid);
    if (session != null) {
      state = state.copyWith(activeSession: session, isRecording: true);
      await _resumeDetection(session.id);
    }
  }

  Future<void> startSleep() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final hasPermission = await _detector.requestPermission();
    if (!hasPermission) {
      state = state.copyWith(error: 'マイクの許可が必要です');
      return;
    }

    final session = SleepSession(
      id: const Uuid().v4(),
      userId: uid,
      startTime: DateTime.now(),
      isActive: true,
      createdAt: DateTime.now(),
    );

    final saved = await _repo.createSession(session);
    await _startDetection(saved.id);
    await BackgroundServiceManager.startService();

    state = state.copyWith(activeSession: saved, isRecording: true);
  }

  Future<void> stopSleep() async {
    final session = state.activeSession;
    if (session == null) return;

    final recordingPath = await _detector.stopListening();
    _snoreSubscription?.cancel();
    _decibelSubscription?.cancel();

    await BackgroundServiceManager.stopService();

    final endTime = DateTime.now();
    final totalMinutes =
        endTime.difference(session.startTime).inMinutes;
    final snoreCount = state.currentSnoreEvents.length;
    final snoreTotalSeconds = state.currentSnoreEvents
        .fold(0, (sum, e) => sum + (e.durationSeconds ?? 0));

    final sleepScore = _calcSleepScore(totalMinutes, snoreCount);
    final recoveryScore = _calcRecoveryScore(totalMinutes, snoreTotalSeconds);

    final updated = session.copyWith(
      endTime: endTime,
      totalMinutes: totalMinutes,
      isActive: false,
      snoreCount: snoreCount,
      snoreTotalMinutes: snoreTotalSeconds ~/ 60,
      sleepScore: sleepScore,
      recoveryScore: recoveryScore,
      recordingPaths: recordingPath != null ? [recordingPath] : [],
      updatedAt: DateTime.now(),
    );

    await _repo.updateSession(updated);
    state = state.copyWith(
      activeSession: updated,
      isRecording: false,
      isSnoring: false,
    );
  }

  Future<void> _startDetection(String sessionId) async {
    await _detector.startListening(sessionId);
    _listenToDetector(sessionId);
  }

  Future<void> _resumeDetection(String sessionId) async {
    await _detector.startListening(sessionId);
    _listenToDetector(sessionId);
  }

  void _listenToDetector(String sessionId) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    _decibelSubscription = _detector.decibelStream.listen((db) {
      state = state.copyWith(currentDecibel: db);
    });

    _snoreSubscription = _detector.snoreStream.listen((event) async {
      if (event.isStarted) {
        state = state.copyWith(isSnoring: true);
      } else {
        state = state.copyWith(isSnoring: false);
        final snoreEvent = SnoreEvent(
          id: const Uuid().v4(),
          sessionId: sessionId,
          userId: uid,
          startTime: event.startTime!,
          endTime: event.endTime,
          durationSeconds: event.durationSeconds,
          maxDecibel: event.maxDecibel,
          avgDecibel: event.avgDecibel,
          recordingPath: event.recordingPath,
          createdAt: DateTime.now(),
        );
        await _repo.saveSnoreEvent(snoreEvent);
        state = state.copyWith(
          currentSnoreEvents: [...state.currentSnoreEvents, snoreEvent],
        );
      }
    });
  }

  double _calcSleepScore(int totalMinutes, int snoreCount) {
    double score = 100;
    // 理想睡眠時間との差
    final diff = (totalMinutes - 480).abs();
    score -= (diff / 60) * 5;
    // いびき減点
    score -= snoreCount * 2.0;
    return score.clamp(0, 100);
  }

  double _calcRecoveryScore(int totalMinutes, int snoreTotalSeconds) {
    double score = 100;
    if (totalMinutes < 360) score -= 20;
    if (totalMinutes < 300) score -= 20;
    score -= (snoreTotalSeconds / 60) * 0.5;
    return score.clamp(0, 100);
  }

  @override
  void dispose() {
    _snoreSubscription?.cancel();
    _decibelSubscription?.cancel();
    _detector.dispose();
    super.dispose();
  }
}

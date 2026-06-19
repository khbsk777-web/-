import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/sleep_session.dart';
import '../../data/models/ai_report.dart';
import '../../data/models/health_snapshot.dart';
import '../../data/repositories/sleep_repository.dart';
import '../../services/health/health_service.dart';
import '../../infrastructure/openai/openai_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';

class DashboardState {
  final List<SleepSession> recentSessions;
  final AiReport? latestReport;
  final HealthSnapshot? healthSnapshot;
  final bool isLoading;
  final String? error;

  const DashboardState({
    this.recentSessions = const [],
    this.latestReport,
    this.healthSnapshot,
    this.isLoading = false,
    this.error,
  });

  SleepSession? get lastSession =>
      recentSessions.isNotEmpty ? recentSessions.first : null;

  DashboardState copyWith({
    List<SleepSession>? recentSessions,
    AiReport? latestReport,
    HealthSnapshot? healthSnapshot,
    bool? isLoading,
    String? error,
  }) =>
      DashboardState(
        recentSessions: recentSessions ?? this.recentSessions,
        latestReport: latestReport ?? this.latestReport,
        healthSnapshot: healthSnapshot ?? this.healthSnapshot,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

final dashboardViewModelProvider =
    StateNotifierProvider<DashboardViewModel, DashboardState>((ref) {
  return DashboardViewModel(SleepRepository(), HealthService());
});

class DashboardViewModel extends StateNotifier<DashboardState> {
  final SleepRepository _sleepRepo;
  final HealthService _healthService;

  DashboardViewModel(this._sleepRepo, this._healthService)
      : super(const DashboardState()) {
    load();
  }

  Future<void> load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    state = state.copyWith(isLoading: true);
    try {
      final now = DateTime.now();
      final from = now.subtract(const Duration(days: 30));

      final sessions = await _sleepRepo.getSessions(
        userId: uid,
        from: from,
        to: now,
      );

      final latestReport = await _sleepRepo.getLatestReport(uid);
      final health = await _healthService.fetchTodaySnapshot(uid);

      state = state.copyWith(
        recentSessions: sessions,
        latestReport: latestReport,
        healthSnapshot: health,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> generateAiReport() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final lastSession = state.lastSession;
    if (lastSession == null) return;

    final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString(AppConstants.keyOpenAIKey);
    if (apiKey == null || apiKey.isEmpty) return;

    final snoreEvents = await _sleepRepo.getSnoreEvents(lastSession.id);
    final openAI = OpenAIService(apiKey);

    final result = await openAI.analyzeSleep(
      session: lastSession,
      snoreEvents: snoreEvents,
      healthSnapshot: state.healthSnapshot,
    );

    if (result != null) {
      final report = AiReport(
        id: '',
        userId: uid,
        sessionId: lastSession.id,
        date: DateTime.now(),
        summary: result.summary,
        insights: result.insights,
        recommendations: result.recommendations,
        sleepQualityScore: result.sleepQualityScore,
        rawResponse: result.rawResponse,
        createdAt: DateTime.now(),
      );
      await _sleepRepo.saveAiReport(report);
      state = state.copyWith(latestReport: report);
    }
  }
}

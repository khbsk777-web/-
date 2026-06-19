import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../data/models/sleep_session.dart';
import '../../data/models/health_snapshot.dart';
import '../../data/models/snore_event.dart';
import '../../core/constants/app_constants.dart';

class OpenAIService {
  late final Dio _dio;

  OpenAIService(String apiKey) {
    _dio = Dio(BaseOptions(
      baseUrl: AppConstants.openAIBaseUrl,
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
    ));
  }

  Future<SleepAnalysisResult?> analyzeSleep({
    required SleepSession session,
    required List<SnoreEvent> snoreEvents,
    HealthSnapshot? healthSnapshot,
  }) async {
    try {
      final prompt = _buildPrompt(session, snoreEvents, healthSnapshot);

      final response = await _dio.post(
        '/chat/completions',
        data: {
          'model': AppConstants.openAIModel,
          'messages': [
            {
              'role': 'system',
              'content': '''あなたは睡眠専門のAIアシスタントです。
ユーザーの睡眠データを分析し、日本語で具体的なアドバイスを提供してください。
回答はJSON形式で以下の構造にしてください:
{
  "summary": "睡眠全体のサマリー（1-2文）",
  "insights": ["具体的な気づき1", "気づき2", "気づき3"],
  "recommendations": ["推奨アクション1", "推奨アクション2"],
  "sleepQualityScore": 85
}''',
            },
            {
              'role': 'user',
              'content': prompt,
            },
          ],
          'temperature': 0.7,
          'max_tokens': 1000,
          'response_format': {'type': 'json_object'},
        },
      );

      final content = response.data['choices'][0]['message']['content'] as String;
      return _parseResponse(content);
    } on DioException catch (e) {
      debugPrint('OpenAI API error: ${e.message}');
      return null;
    }
  }

  String _buildPrompt(
    SleepSession session,
    List<SnoreEvent> snoreEvents,
    HealthSnapshot? health,
  ) {
    final buf = StringBuffer();
    buf.writeln('【昨日の睡眠データ】');

    if (session.totalMinutes != null) {
      final h = session.totalMinutes! ~/ 60;
      final m = session.totalMinutes! % 60;
      buf.writeln('睡眠時間: ${h}時間${m}分');
    }

    buf.writeln('就寝時刻: ${_formatTime(session.startTime)}');
    if (session.endTime != null) {
      buf.writeln('起床時刻: ${_formatTime(session.endTime!)}');
    }

    buf.writeln('\n【いびきデータ】');
    buf.writeln('いびき回数: ${snoreEvents.length}回');
    if (snoreEvents.isNotEmpty) {
      final totalSnoreSeconds =
          snoreEvents.fold(0, (sum, e) => sum + (e.durationSeconds ?? 0));
      buf.writeln(
          'いびき総時間: ${totalSnoreSeconds ~/ 60}分${totalSnoreSeconds % 60}秒');
      final maxDb = snoreEvents
          .map((e) => e.maxDecibel ?? 0.0)
          .reduce((a, b) => a > b ? a : b);
      buf.writeln('最大いびき音量: ${maxDb.toStringAsFixed(1)}dB');

      final hours = snoreEvents.map((e) => e.startTime.hour).toList();
      if (hours.isNotEmpty) {
        final hourCounts = <int, int>{};
        for (final h in hours) {
          hourCounts[h] = (hourCounts[h] ?? 0) + 1;
        }
        final peakHour = hourCounts.entries
            .reduce((a, b) => a.value > b.value ? a : b)
            .key;
        buf.writeln('いびきが多い時間帯: ${peakHour}時台');
      }
    }

    if (health != null) {
      buf.writeln('\n【健康データ】');
      if (health.steps != null) buf.writeln('歩数: ${health.steps}歩');
      if (health.heartRateAvg != null) {
        buf.writeln(
            '平均心拍数: ${health.heartRateAvg!.toStringAsFixed(0)}bpm');
      }
      if (health.activeCalories != null) {
        buf.writeln(
            '消費カロリー: ${health.activeCalories!.toStringAsFixed(0)}kcal');
      }
      if (health.exerciseMinutes != null) {
        buf.writeln('運動時間: ${health.exerciseMinutes}分');
      }
    }

    buf.writeln(
        '\n上記データを分析して、睡眠の質改善のためのアドバイスをJSON形式で回答してください。');
    return buf.toString();
  }

  String _formatTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  SleepAnalysisResult? _parseResponse(String content) {
    try {
      final decoded = jsonDecode(content) as Map<String, dynamic>;
      return SleepAnalysisResult(
        summary: decoded['summary'] as String? ?? '',
        insights: (decoded['insights'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        recommendations: (decoded['recommendations'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        sleepQualityScore:
            (decoded['sleepQualityScore'] as num?)?.toDouble(),
        rawResponse: content,
      );
    } catch (e) {
      debugPrint('Parse error: $e');
      return null;
    }
  }
}

class SleepAnalysisResult {
  final String summary;
  final List<String> insights;
  final List<String> recommendations;
  final double? sleepQualityScore;
  final String? rawResponse;

  SleepAnalysisResult({
    required this.summary,
    required this.insights,
    required this.recommendations,
    this.sleepQualityScore,
    this.rawResponse,
  });
}

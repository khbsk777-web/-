import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'ai_report.freezed.dart';
part 'ai_report.g.dart';

@freezed
class AiReport with _$AiReport {
  const factory AiReport({
    required String id,
    required String userId,
    required String sessionId,
    required DateTime date,
    required String summary,
    required List<String> insights,
    required List<String> recommendations,
    double? sleepQualityScore,
    String? rawResponse,
    DateTime? createdAt,
  }) = _AiReport;

  factory AiReport.fromJson(Map<String, dynamic> json) =>
      _$AiReportFromJson(json);

  factory AiReport.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AiReport.fromJson({
      'id': doc.id,
      ...data,
      'date': (data['date'] as Timestamp).toDate().toIso8601String(),
      'createdAt': data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate().toIso8601String()
          : null,
    });
  }

  Map<String, dynamic> toFirestore() {
    final json = toJson();
    return {
      ...json,
      'date': Timestamp.fromDate(date),
      'createdAt': FieldValue.serverTimestamp(),
    }..remove('id');
  }
}

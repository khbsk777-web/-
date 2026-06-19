import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'sleep_session.freezed.dart';
part 'sleep_session.g.dart';

@freezed
class SleepSession with _$SleepSession {
  const factory SleepSession({
    required String id,
    required String userId,
    required DateTime startTime,
    DateTime? endTime,
    int? totalMinutes,
    double? sleepScore,
    double? recoveryScore,
    int? snoreCount,
    int? snoreTotalMinutes,
    List<String>? recordingPaths,
    String? aiReport,
    Map<String, dynamic>? healthData,
    @Default(false) bool isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _SleepSession;

  factory SleepSession.fromJson(Map<String, dynamic> json) =>
      _$SleepSessionFromJson(json);

  factory SleepSession.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SleepSession.fromJson({
      'id': doc.id,
      ...data,
      'startTime': (data['startTime'] as Timestamp).toDate().toIso8601String(),
      'endTime': data['endTime'] != null
          ? (data['endTime'] as Timestamp).toDate().toIso8601String()
          : null,
      'createdAt': data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate().toIso8601String()
          : null,
      'updatedAt': data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate().toIso8601String()
          : null,
    });
  }

  Map<String, dynamic> toFirestore() {
    final json = toJson();
    return {
      ...json,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': endTime != null ? Timestamp.fromDate(endTime!) : null,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }..remove('id');
  }
}

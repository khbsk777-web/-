import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'snore_event.freezed.dart';
part 'snore_event.g.dart';

@freezed
class SnoreEvent with _$SnoreEvent {
  const factory SnoreEvent({
    required String id,
    required String sessionId,
    required String userId,
    required DateTime startTime,
    DateTime? endTime,
    int? durationSeconds,
    double? maxDecibel,
    double? avgDecibel,
    String? recordingPath,
    DateTime? createdAt,
  }) = _SnoreEvent;

  factory SnoreEvent.fromJson(Map<String, dynamic> json) =>
      _$SnoreEventFromJson(json);

  factory SnoreEvent.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SnoreEvent.fromJson({
      'id': doc.id,
      ...data,
      'startTime': (data['startTime'] as Timestamp).toDate().toIso8601String(),
      'endTime': data['endTime'] != null
          ? (data['endTime'] as Timestamp).toDate().toIso8601String()
          : null,
      'createdAt': data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate().toIso8601String()
          : null,
    });
  }

  Map<String, dynamic> toFirestore() {
    final json = toJson();
    return {
      ...json,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': endTime != null ? Timestamp.fromDate(endTime!) : null,
      'createdAt': FieldValue.serverTimestamp(),
    }..remove('id');
  }
}

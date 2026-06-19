import 'package:freezed_annotation/freezed_annotation.dart';

part 'health_snapshot.freezed.dart';
part 'health_snapshot.g.dart';

@freezed
class HealthSnapshot with _$HealthSnapshot {
  const factory HealthSnapshot({
    required String id,
    required String userId,
    required DateTime date,
    int? steps,
    double? heartRateAvg,
    double? heartRateMin,
    double? heartRateMax,
    double? activeCalories,
    int? exerciseMinutes,
    double? sleepMinutesFromHealth,
    DateTime? createdAt,
  }) = _HealthSnapshot;

  factory HealthSnapshot.fromJson(Map<String, dynamic> json) =>
      _$HealthSnapshotFromJson(json);
}

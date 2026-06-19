import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import '../../data/models/health_snapshot.dart';
import 'package:uuid/uuid.dart';

class HealthService {
  final _health = Health();

  static const _appleTypes = [
    HealthDataType.STEPS,
    HealthDataType.HEART_RATE,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.EXERCISE_TIME,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_IN_BED,
  ];

  static const _androidTypes = [
    HealthDataType.STEPS,
    HealthDataType.HEART_RATE,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.SLEEP_ASLEEP,
  ];

  List<HealthDataType> get _types =>
      Platform.isIOS ? _appleTypes : _androidTypes;

  Future<bool> requestPermissions() async {
    try {
      await _health.configure();
      final permissions = _types.map((_) => HealthDataAccess.READ).toList();
      return await _health.requestAuthorization(_types, permissions: permissions);
    } catch (e) {
      debugPrint('Health permission error: $e');
      return false;
    }
  }

  Future<HealthSnapshot?> fetchTodaySnapshot(String userId) async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);

      final data = await _health.getHealthDataFromTypes(
        startTime: startOfDay,
        endTime: now,
        types: _types,
      );

      final deduped = _health.removeDuplicates(data);

      int steps = 0;
      double heartRateSum = 0;
      double heartRateMin = double.infinity;
      double heartRateMax = 0;
      int heartRateCount = 0;
      double activeCalories = 0;
      int exerciseMinutes = 0;
      double sleepMinutes = 0;

      for (final point in deduped) {
        final value = point.value as NumericHealthValue;
        switch (point.type) {
          case HealthDataType.STEPS:
            steps += value.numericValue.toInt();
          case HealthDataType.HEART_RATE:
            heartRateSum += value.numericValue;
            if (value.numericValue < heartRateMin) heartRateMin = value.numericValue.toDouble();
            if (value.numericValue > heartRateMax) heartRateMax = value.numericValue.toDouble();
            heartRateCount++;
          case HealthDataType.ACTIVE_ENERGY_BURNED:
            activeCalories += value.numericValue;
          case HealthDataType.EXERCISE_TIME:
            exerciseMinutes += value.numericValue.toInt();
          case HealthDataType.SLEEP_ASLEEP:
            sleepMinutes += value.numericValue;
          default:
            break;
        }
      }

      return HealthSnapshot(
        id: const Uuid().v4(),
        userId: userId,
        date: startOfDay,
        steps: steps,
        heartRateAvg: heartRateCount > 0 ? heartRateSum / heartRateCount : null,
        heartRateMin: heartRateMin != double.infinity ? heartRateMin : null,
        heartRateMax: heartRateMax > 0 ? heartRateMax : null,
        activeCalories: activeCalories,
        exerciseMinutes: exerciseMinutes,
        sleepMinutesFromHealth: sleepMinutes,
        createdAt: DateTime.now(),
      );
    } catch (e) {
      debugPrint('Health fetch error: $e');
      return null;
    }
  }
}

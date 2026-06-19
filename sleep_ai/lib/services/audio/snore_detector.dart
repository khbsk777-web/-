import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:noise_meter/noise_meter.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_constants.dart';

enum SnoreDetectionState { idle, listening, snoring }

class SnoreDetector {
  final _recorder = AudioRecorder();
  final _noiseMeter = NoiseMeter();
  StreamSubscription<NoiseReading>? _noiseSubscription;

  final _snoreController = StreamController<SnoreDetectionEvent>.broadcast();
  Stream<SnoreDetectionEvent> get snoreStream => _snoreController.stream;

  final _decibelController = StreamController<double>.broadcast();
  Stream<double> get decibelStream => _decibelController.stream;

  SnoreDetectionState _state = SnoreDetectionState.idle;
  DateTime? _snoreStartTime;
  double _maxDb = 0;
  double _sumDb = 0;
  int _dbCount = 0;
  Timer? _snoreTimer;
  String? _currentRecordingPath;
  bool _isRecording = false;

  Future<bool> requestPermission() async {
    return await _recorder.hasPermission();
  }

  Future<void> startListening(String sessionId) async {
    if (_isRecording) return;
    _isRecording = true;

    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/snore_${sessionId}_${const Uuid().v4()}.m4a';
    _currentRecordingPath = path;

    await _recorder.start(
      RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: AppConstants.sampleRate,
      ),
      path: path,
    );

    _noiseSubscription = _noiseMeter.noise.listen(
      _onNoiseReading,
      onError: (e) => debugPrint('Noise meter error: $e'),
    );
  }

  void _onNoiseReading(NoiseReading reading) {
    final db = reading.meanDecibel;
    _decibelController.add(db);

    if (db >= AppConstants.snoreThresholdDb) {
      _sumDb += db;
      _dbCount++;
      if (db > _maxDb) _maxDb = db;

      if (_state != SnoreDetectionState.snoring) {
        _snoreTimer?.cancel();
        _snoreTimer = Timer(
          const Duration(milliseconds: AppConstants.minSnoreDurationMs),
          () {
            _state = SnoreDetectionState.snoring;
            _snoreStartTime = DateTime.now();
            _snoreController.add(SnoreDetectionEvent.started(_snoreStartTime!));
          },
        );
        _state = SnoreDetectionState.listening;
      }
    } else {
      if (_state == SnoreDetectionState.snoring) {
        final endTime = DateTime.now();
        final duration = endTime.difference(_snoreStartTime!).inSeconds;
        final avgDb = _dbCount > 0 ? _sumDb / _dbCount : 0.0;
        _snoreController.add(SnoreDetectionEvent.stopped(
          startTime: _snoreStartTime!,
          endTime: endTime,
          durationSeconds: duration,
          maxDecibel: _maxDb,
          avgDecibel: avgDb,
          recordingPath: _currentRecordingPath,
        ));
        _resetSnoreState();
      }
      _snoreTimer?.cancel();
      _state = SnoreDetectionState.idle;
    }
  }

  void _resetSnoreState() {
    _snoreStartTime = null;
    _maxDb = 0;
    _sumDb = 0;
    _dbCount = 0;
  }

  Future<String?> stopListening() async {
    _noiseSubscription?.cancel();
    _snoreTimer?.cancel();

    if (_state == SnoreDetectionState.snoring && _snoreStartTime != null) {
      final endTime = DateTime.now();
      _snoreController.add(SnoreDetectionEvent.stopped(
        startTime: _snoreStartTime!,
        endTime: endTime,
        durationSeconds: endTime.difference(_snoreStartTime!).inSeconds,
        maxDecibel: _maxDb,
        avgDecibel: _dbCount > 0 ? _sumDb / _dbCount : 0,
        recordingPath: _currentRecordingPath,
      ));
    }

    _state = SnoreDetectionState.idle;
    _isRecording = false;

    try {
      final path = await _recorder.stop();
      return path;
    } catch (e) {
      debugPrint('Stop recording error: $e');
      return null;
    }
  }

  void dispose() {
    _noiseSubscription?.cancel();
    _snoreTimer?.cancel();
    _snoreController.close();
    _decibelController.close();
    _recorder.dispose();
  }
}

class SnoreDetectionEvent {
  final bool isStarted;
  final DateTime? startTime;
  final DateTime? endTime;
  final int? durationSeconds;
  final double? maxDecibel;
  final double? avgDecibel;
  final String? recordingPath;

  SnoreDetectionEvent.started(DateTime time)
      : isStarted = true,
        startTime = time,
        endTime = null,
        durationSeconds = null,
        maxDecibel = null,
        avgDecibel = null,
        recordingPath = null;

  SnoreDetectionEvent.stopped({
    required this.startTime,
    required this.endTime,
    required this.durationSeconds,
    required this.maxDecibel,
    required this.avgDecibel,
    this.recordingPath,
  })  : isStarted = false;
}

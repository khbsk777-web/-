import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../models/sleep_session.dart';
import '../models/snore_event.dart';
import '../models/ai_report.dart';
import '../../core/constants/app_constants.dart';

class SleepRepository {
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  // ── Sessions ──────────────────────────────────────────────

  Future<SleepSession> createSession(SleepSession session) async {
    final doc = await _firestore
        .collection(AppConstants.sleepSessionsCollection)
        .add(session.toFirestore());
    return session.copyWith(id: doc.id);
  }

  Future<void> updateSession(SleepSession session) async {
    await _firestore
        .collection(AppConstants.sleepSessionsCollection)
        .doc(session.id)
        .update(session.toFirestore());
  }

  Future<SleepSession?> getActiveSession(String userId) async {
    final snap = await _firestore
        .collection(AppConstants.sleepSessionsCollection)
        .where('userId', isEqualTo: userId)
        .where('isActive', isEqualTo: true)
        .orderBy('startTime', descending: true)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;
    return SleepSession.fromFirestore(snap.docs.first);
  }

  Future<List<SleepSession>> getSessions({
    required String userId,
    required DateTime from,
    required DateTime to,
  }) async {
    final snap = await _firestore
        .collection(AppConstants.sleepSessionsCollection)
        .where('userId', isEqualTo: userId)
        .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(to))
        .orderBy('startTime', descending: true)
        .get();

    return snap.docs.map(SleepSession.fromFirestore).toList();
  }

  Stream<SleepSession?> watchActiveSession(String userId) {
    return _firestore
        .collection(AppConstants.sleepSessionsCollection)
        .where('userId', isEqualTo: userId)
        .where('isActive', isEqualTo: true)
        .orderBy('startTime', descending: true)
        .limit(1)
        .snapshots()
        .map((snap) =>
            snap.docs.isEmpty ? null : SleepSession.fromFirestore(snap.docs.first));
  }

  // ── Snore Events ───────────────────────────────────────────

  Future<void> saveSnoreEvent(SnoreEvent event) async {
    await _firestore
        .collection(AppConstants.snoreEventsCollection)
        .add(event.toFirestore());
  }

  Future<List<SnoreEvent>> getSnoreEvents(String sessionId) async {
    final snap = await _firestore
        .collection(AppConstants.snoreEventsCollection)
        .where('sessionId', isEqualTo: sessionId)
        .orderBy('startTime')
        .get();

    return snap.docs.map(SnoreEvent.fromFirestore).toList();
  }

  // ── AI Reports ─────────────────────────────────────────────

  Future<void> saveAiReport(AiReport report) async {
    await _firestore
        .collection(AppConstants.aiReportsCollection)
        .add(report.toFirestore());
  }

  Future<AiReport?> getLatestReport(String userId) async {
    final snap = await _firestore
        .collection(AppConstants.aiReportsCollection)
        .where('userId', isEqualTo: userId)
        .orderBy('date', descending: true)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;
    return AiReport.fromFirestore(snap.docs.first);
  }

  Future<List<AiReport>> getReports({
    required String userId,
    required DateTime from,
    required DateTime to,
  }) async {
    final snap = await _firestore
        .collection(AppConstants.aiReportsCollection)
        .where('userId', isEqualTo: userId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(to))
        .orderBy('date', descending: true)
        .get();

    return snap.docs.map(AiReport.fromFirestore).toList();
  }

  // ── Storage ─────────────────────────────────────────────────

  Future<String?> uploadRecording(String localPath, String userId) async {
    try {
      final file = File(localPath);
      final fileName = localPath.split('/').last;
      final ref = _storage.ref('recordings/$userId/$fileName');
      await ref.putFile(file);
      return await ref.getDownloadURL();
    } catch (e) {
      return null;
    }
  }
}

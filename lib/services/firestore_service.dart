// lib/services/firestore_service.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/notice_model.dart';
import '../models/user_model.dart';

class FirestoreService {
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  // ══════════════════════════════════════════════════════════════════════════
  // USERS
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> saveStudent(UserModel user) =>
      _db.collection('users').doc(user.uid).set(user.toMap());

  Future<void> updateStudent(String uid, Map<String, dynamic> data) =>
      _db.collection('users').doc(uid).update(data);

  Future<void> deactivateStudent(String uid) =>
      _db.collection('users').doc(uid).update({'isActive': false});

  Future<void> reactivateStudent(String uid) =>
      _db.collection('users').doc(uid).update({'isActive': true});

  Future<UserModel?> getUserById(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromDoc(doc);
  }

  Stream<List<UserModel>> getAllStudents() => _db
      .collection('users')
      .where('role', whereNotIn: ['admin'])
      .where('isActive', isEqualTo: true)
      .snapshots()
      .map((s) => s.docs.map(UserModel.fromDoc).toList()
        ..sort((a, b) => a.name.compareTo(b.name)));

  Future<List<UserModel>> getAllStudentsOnce() async {
    // Get all active users first
    final snap = await _db
        .collection('users')
        .where('isActive', isEqualTo: true)
        .get();
    
    // Filter out admins manually (more reliable than whereNotIn)
    final students = snap.docs
        .map(UserModel.fromDoc)
        .where((user) => user.role != 'admin')
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    
    return students;
  }

  Stream<List<UserModel>> getStudentsByDept(String dept) => _db
      .collection('users')
      .where('department', isEqualTo: dept)
      .where('isActive', isEqualTo: true)
      .snapshots()
      .map((s) => s.docs.map(UserModel.fromDoc).toList()
        ..sort((a, b) => a.name.compareTo(b.name)));

  Stream<List<UserModel>> getStudentsByYear(String year) => _db
      .collection('users')
      .where('year', isEqualTo: year)
      .where('isActive', isEqualTo: true)
      .snapshots()
      .map((s) => s.docs.map(UserModel.fromDoc).toList()
        ..sort((a, b) => a.name.compareTo(b.name)));

  Stream<List<UserModel>> getStudentsByDeptAndYear(String dept, String year) =>
      _db
          .collection('users')
          .where('department', isEqualTo: dept)
          .where('year', isEqualTo: year)
          .where('isActive', isEqualTo: true)
          .snapshots()
          .map((s) => s.docs.map(UserModel.fromDoc).toList()
            ..sort((a, b) => a.name.compareTo(b.name)));

  Future<Map<String, int>> getStudentStats() async {
    final snap = await _db
        .collection('users')
        .where('role', whereNotIn: ['admin'])
        .where('isActive', isEqualTo: true)
        .get();
    final students = snap.docs.map(UserModel.fromDoc).toList();
    final Map<String, int> stats = {
      'total': students.length,
      'IT': 0,
      'CS': 0,
      'AIDS': 0,
      'EXTC': 0,
      'MECH': 0,
      'CHEMICAL': 0,
      'FE': 0,
      'SE': 0,
      'TE': 0,
      'BE': 0,
      'committee': 0,
    };
    for (final s in students) {
      stats[s.department] = (stats[s.department] ?? 0) + 1;
      stats[s.year] = (stats[s.year] ?? 0) + 1;
      if (s.role == 'committee') stats['committee'] = stats['committee']! + 1;
    }
    return stats;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // NOTICES
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> addNotice(NoticeModel n) =>
      _db.collection('notices').add(n.toMap());

  Future<void> updateNotice(String id, NoticeModel n) =>
      _db.collection('notices').doc(id).update(n.toMap());

  Future<void> deleteNotice(String id) =>
      _db.collection('notices').doc(id).delete();

  Future<void> markNoticeRead(String noticeId, String uid) async {
    try {
      await _db.collection('notices').doc(noticeId).update({
        'readBy': FieldValue.arrayUnion([uid]),
      });
    } catch (e) {
      // If document doesn't have readBy field, create it
      await _db.collection('notices').doc(noticeId).set({
        'readBy': [uid],
      }, SetOptions(merge: true));
    }
  }

  Future<void> acknowledgeNotice(String noticeId, String uid) =>
      _db.collection('notices').doc(noticeId).update({
        'acknowledgedBy': FieldValue.arrayUnion([uid]),
        'readBy': FieldValue.arrayUnion([uid]),
      });

  Future<void> sendNudge(String noticeId, List<String> unreadUids) async {
    final batch = _db.batch();
    for (final uid in unreadUids) {
      final ref = _db.collection('nudges').doc();
      batch.set(ref, {
        'noticeId': noticeId,
        'targetUid': uid,
        'createdAt': FieldValue.serverTimestamp(),
        'seen': false,
      });
    }
    await batch.commit();
  }

  /// Stream of unseen nudges for a student
  Stream<int> nudgeCount(String uid) => _db
      .collection('nudges')
      .where('targetUid', isEqualTo: uid)
      .where('seen', isEqualTo: false)
      .snapshots()
      .map((s) => s.docs.length);

  Future<void> markNudgesSeen(String uid) async {
    final snap = await _db
        .collection('nudges')
        .where('targetUid', isEqualTo: uid)
        .where('seen', isEqualTo: false)
        .get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'seen': true});
    }
    await batch.commit();
  }

  /// Admin — all notices (no expiry filter, includes expired for admin view)
  Stream<List<NoticeModel>> getAllNotices() => _db
      .collection('notices')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(NoticeModel.fromDoc).toList());

  /// Student — notices filtered to profile AND not expired.
  Stream<List<NoticeModel>> getFilteredNotices(UserModel user) => _db
      .collection('notices')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) {
        final all = s.docs.map(NoticeModel.fromDoc).toList();
        // Auto-delete notices that are 7 days past their expiry
        for (final n in all) {
          if (n.expiresAt != null) {
            final cutoff = n.expiresAt!.add(const Duration(days: 7));
            if (DateTime.now().isAfter(cutoff)) {
              _db.collection('notices').doc(n.id).delete();
            }
          }
        }
        return all.where((n) {
          if (n.isExpired) return false;
          return _isVisible(n, user);
        }).toList();
      });

  bool _isVisible(NoticeModel n, UserModel user) {
    switch (n.visibility) {
      case 'all':
        return true;
      case 'multi':
        final deptMatch = n.targetDepartments.isEmpty ||
            n.targetDepartments.contains(user.department);
        final yearMatch = n.targetYears.isEmpty ||
            n.targetYears.contains(user.year);
        return deptMatch || yearMatch;
      case 'department':
        return n.targetDepartment == user.department;
      case 'year':
        return n.targetYear == user.year;
      case 'committee':
        return user.committee != null && n.targetCommittee == user.committee;
      case 'specific':
        return n.targetStudentUids.contains(user.uid);
      default:
        return false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ANNOUNCEMENTS
  // ══════════════════════════════════════════════════════════════════════════

  Stream<List<Map<String, dynamic>>> getPinnedAnnouncements() => _db
      .collection('announcements')
      .where('isPinned', isEqualTo: true)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());

  Future<void> addAnnouncement(String text, {bool pinned = true}) =>
      _db.collection('announcements').add({
        'text': text,
        'isPinned': pinned,
        'createdAt': FieldValue.serverTimestamp(),
      });

  Future<void> deleteAnnouncement(String id) =>
      _db.collection('announcements').doc(id).delete();

  // ══════════════════════════════════════════════════════════════════════════
  // EVENTS
  // ══════════════════════════════════════════════════════════════════════════

  Stream<List<Map<String, dynamic>>> getUpcomingEvents() => _db
      .collection('events')
      .where('eventDate',
          isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime.now()))
      .orderBy('eventDate')
      .limit(20)
      .snapshots()
      .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());

  Future<String?> uploadEventPdf(dynamic pdfData, String fileName) async {
    try {
      final safeFileName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final storageRef = _storage
          .ref()
          .child('event_pdfs')
          .child('${DateTime.now().millisecondsSinceEpoch}_$safeFileName');

      if (pdfData is Uint8List) {
        await storageRef.putData(
            pdfData,
            SettableMetadata(
              contentType: 'application/pdf',
            ));
      } else if (pdfData is File) {
        await storageRef.putFile(
            pdfData,
            SettableMetadata(
              contentType: 'application/pdf',
            ));
      } else {
        return null;
      }

      final downloadUrl = await storageRef.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      return null;
    }
  }

  Future<void> addEvent(Map<String, dynamic> event) =>
      _db.collection('events').add({
        ...event,
        'rsvpCount': 0,
        'rsvpUsers': [],
        'createdAt': FieldValue.serverTimestamp(),
      });

  Future<void> updateEvent(String id, Map<String, dynamic> data) =>
      _db.collection('events').doc(id).update(data);

  Future<void> rsvpEvent(String eventId, String userId) =>
      _db.collection('events').doc(eventId).update({
        'rsvpUsers': FieldValue.arrayUnion([userId]),
        'rsvpCount': FieldValue.increment(1),
      });

  Future<void> cancelRsvp(String eventId, String userId) =>
      _db.collection('events').doc(eventId).update({
        'rsvpUsers': FieldValue.arrayRemove([userId]),
        'rsvpCount': FieldValue.increment(-1),
      });

  Future<void> deleteEvent(String id) =>
      _db.collection('events').doc(id).delete();
}
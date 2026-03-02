// lib/services/firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/notice_model.dart';
import '../models/user_model.dart';

class FirestoreService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  // ══════════════════════════════════════════════════════════════════════════
  // NOTICE OPERATIONS
  // ══════════════════════════════════════════════════════════════════════════

  /// Add a new notice (admin only)
  Future<void> addNotice(NoticeModel notice) async {
    await _db.collection('notices').add(notice.toMap());
  }

  /// Update existing notice (admin only)
  Future<void> updateNotice(String id, NoticeModel notice) async {
    await _db.collection('notices').doc(id).update(notice.toMap());
  }

  /// Delete notice (admin only)
  Future<void> deleteNotice(String id) async {
    await _db.collection('notices').doc(id).delete();
  }

  /// Get ALL notices stream (admin dashboard)
  Stream<List<NoticeModel>> getAllNotices() {
    return _db
      .collection('notices')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map(NoticeModel.fromDoc).toList());
  }

  /// Get filtered notices for a student
  /// Logic: show notices where visibility == 'all'
  ///        OR (visibility == 'department' AND targetDepartment == user.department)
  ///        OR (visibility == 'committee' AND targetCommittee == user.committee)
  ///
  /// NOTE: Firestore doesn't support OR queries well, so we fetch all and filter client-side.
  Stream<List<NoticeModel>> getFilteredNotices(UserModel user) {
    return _db
      .collection('notices')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snap) {
        return snap.docs
          .map(NoticeModel.fromDoc)
          .where((n) => _isVisible(n, user))
          .toList();
      });
  }

  bool _isVisible(NoticeModel n, UserModel user) {
    if (n.visibility == 'all') return true;
    if (n.visibility == 'department' && n.targetDepartment == user.department) return true;
    if (n.visibility == 'committee' &&
        user.committee != null &&
        n.targetCommittee == user.committee) return true;
    return false;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // USER / STUDENT OPERATIONS (Admin)
  // ══════════════════════════════════════════════════════════════════════════

  /// Add student record to Firestore (called after admin creates auth account)
  Future<void> addStudentRecord(UserModel user) async {
    await _db.collection('users').doc(user.uid).set(user.toMap());
  }

  /// Update student role/dept/committee
  Future<void> updateStudent(String uid, Map<String, dynamic> data) async {
    await _db.collection('users').doc(uid).update(data);
  }

  /// Get all students stream
  Stream<List<UserModel>> getAllStudents() {
    return _db
      .collection('users')
      .where('role', whereNotIn: ['admin'])
      .snapshots()
      .map((snap) => snap.docs.map(UserModel.fromDoc).toList());
  }

  /// Delete a student record
  Future<void> deleteStudent(String uid) async {
    await _db.collection('users').doc(uid).delete();
  }
}
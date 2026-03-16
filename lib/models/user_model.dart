import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String name;
  final String role; // 'student' | 'committee' | 'admin'
  final String department;
  final String year;
  final String? committee;
  final String? rollNumber;
  final String? phone;
  final bool isActive;
  final DateTime createdAt;

  const UserModel({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    required this.department,
    required this.year,
    this.committee,
    this.rollNumber,
    this.phone,
    required this.isActive,
    required this.createdAt,
  });

  bool get isAdmin     => role == 'admin';
  bool get isCommittee => role == 'committee';

  factory UserModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid:        doc.id,
      email:      d['email'] ?? '',
      name:       d['name']  ?? '',
      role:       d['role']  ?? 'student',
      department: d['department'] ?? '',
      year:       d['year'] ?? '',
      committee:  d['committee'],
      rollNumber: d['rollNumber'],
      phone:      d['phone'],
      isActive:   d['isActive'] ?? true,
      createdAt:  d['createdAt'] != null
        ? (d['createdAt'] as Timestamp).toDate()
        : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'uid':        uid,
    'email':      email,
    'name':       name,
    'role':       role,
    'department': department,
    'year':       year,
    'committee':  committee,
    'rollNumber': rollNumber,
    'phone':      phone,
    'isActive':   isActive,
    'createdAt':  Timestamp.fromDate(createdAt),
  };
}
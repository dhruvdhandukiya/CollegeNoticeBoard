// lib/models/user_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String name;
  final String role;       // 'student' | 'committee' | 'admin'
  final String department; // 'IT' | 'CS' | 'EXTC' | 'MECH'
  final String? committee; // 'CSI' | 'NSS' | 'Cultural' | 'Sports'

  UserModel({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    required this.department,
    this.committee,
  });

  factory UserModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      email: data['email'] ?? '',
      name: data['name'] ?? '',
      role: data['role'] ?? 'student',
      department: data['department'] ?? '',
      committee: data['committee'],
    );
  }

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'email': email,
    'name': name,
    'role': role,
    'department': department,
    'committee': committee,
  };
}
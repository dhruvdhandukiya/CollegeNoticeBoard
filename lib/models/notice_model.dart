// lib/models/notice_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class NoticeModel {
  final String id;
  final String title;
  final String description;
  final String category;
  final String visibility; // 'all' | 'department' | 'committee'
  final String? targetDepartment;
  final String? targetCommittee;
  final bool isImportant;
  final DateTime createdAt;

  NoticeModel({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.visibility,
    this.targetDepartment,
    this.targetCommittee,
    required this.isImportant,
    required this.createdAt,
  });

  factory NoticeModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NoticeModel(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      category: data['category'] ?? 'General',
      visibility: data['visibility'] ?? 'all',
      targetDepartment: data['targetDepartment'],
      targetCommittee: data['targetCommittee'],
      isImportant: data['isImportant'] ?? false,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
    'title': title,
    'description': description,
    'category': category,
    'visibility': visibility,
    'targetDepartment': targetDepartment,
    'targetCommittee': targetCommittee,
    'isImportant': isImportant,
    'createdAt': Timestamp.fromDate(createdAt),
  };
}

// ─────────────────────────────────────────────────────────────────────────────


import 'package:cloud_firestore/cloud_firestore.dart';

enum NoticePriority { low, medium, high, urgent }

extension NoticePriorityX on NoticePriority {
  String get label {
    switch (this) {
      case NoticePriority.low:    return 'Low';
      case NoticePriority.medium: return 'Medium';
      case NoticePriority.high:   return 'High';
      case NoticePriority.urgent: return 'Urgent';
    }
  }
  String get value {
    switch (this) {
      case NoticePriority.low:    return 'low';
      case NoticePriority.medium: return 'medium';
      case NoticePriority.high:   return 'high';
      case NoticePriority.urgent: return 'urgent';
    }
  }
  static NoticePriority fromString(String? v) {
    switch (v) {
      case 'urgent': return NoticePriority.urgent;
      case 'high':   return NoticePriority.high;
      case 'low':    return NoticePriority.low;
      default:       return NoticePriority.medium;
    }
  }
}

class NoticeModel {
  final String id;
  final String title;
  final String description;
  final String category;
  final String visibility;

  final String? targetDepartment;
  final String? targetYear;
  final String? targetCommittee;
  
  // Multi-select fields (for 'multi' visibility)
  final List<String> targetDepartments; 
  final List<String> targetYears;        
  
  final List<String> targetStudentUids; 

  final bool isImportant;
  final bool isPinned;
  final NoticePriority priority;

  final DateTime? expiresAt;
  final List<String> readBy;
  final bool requiresAcknowledgement;
  final List<String> acknowledgedBy;
  final DateTime createdAt;

  const NoticeModel({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.visibility,
    this.targetDepartment,
    this.targetYear,
    this.targetCommittee,
    this.targetDepartments = const [],
    this.targetYears = const [],
    this.targetStudentUids = const [],
    required this.isImportant,
    this.isPinned = false,
    this.priority = NoticePriority.medium,
    this.expiresAt,
    this.readBy = const [],
    this.requiresAcknowledgement = false,
    this.acknowledgedBy = const [],
    required this.createdAt,
  });

  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);

  bool get expiringSoon {
    if (expiresAt == null || isExpired) return false;
    return expiresAt!.difference(DateTime.now()).inHours <= 24;
  }

  bool isReadBy(String uid) => readBy.contains(uid);
  bool isAcknowledgedBy(String uid) => acknowledgedBy.contains(uid);

  factory NoticeModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return NoticeModel(
      id:               doc.id,
      title:            d['title'] ?? '',
      description:      d['description'] ?? '',
      category:         d['category'] ?? 'General',
      visibility:       d['visibility'] ?? 'all',
      targetDepartment: d['targetDepartment'],
      targetYear:       d['targetYear'],
      targetCommittee:  d['targetCommittee'],
      targetDepartments: List<String>.from(d['targetDepartments'] ?? []),
      targetYears:       List<String>.from(d['targetYears'] ?? []),
      targetStudentUids: List<String>.from(d['targetStudentUids'] ?? []),
      isImportant:      d['isImportant'] ?? false,
      isPinned:         d['isPinned'] ?? false,
      priority:         NoticePriorityX.fromString(d['priority']),
      expiresAt:        d['expiresAt'] != null
          ? (d['expiresAt'] as Timestamp).toDate() : null,
      readBy:           List<String>.from(d['readBy'] ?? []),
      requiresAcknowledgement: d['requiresAcknowledgement'] ?? false,
      acknowledgedBy:   List<String>.from(d['acknowledgedBy'] ?? []),
      createdAt:        d['createdAt'] != null
          ? (d['createdAt'] as Timestamp).toDate() : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'title':                   title,
    'description':             description,
    'category':                category,
    'visibility':              visibility,
    'targetDepartment':        targetDepartment,
    'targetYear':              targetYear,
    'targetCommittee':         targetCommittee,
    'targetDepartments':       targetDepartments,
    'targetYears':             targetYears,
    'targetStudentUids':       targetStudentUids,
    'isImportant':             isImportant,
    'isPinned':                isPinned,
    'priority':                priority.value,
    'expiresAt':               expiresAt != null
        ? Timestamp.fromDate(expiresAt!) : null,
    'readBy':                  readBy,
    'requiresAcknowledgement': requiresAcknowledgement,
    'acknowledgedBy':          acknowledgedBy,
    'createdAt':               Timestamp.fromDate(createdAt),
  };
}
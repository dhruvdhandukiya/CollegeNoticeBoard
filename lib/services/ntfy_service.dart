// lib/services/ntfy_service.dart

import 'dart:convert';
import 'dart:html' as html;
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/user_model.dart';
import '../models/notice_model.dart';

class NtfyService {
  static final NtfyService _instance = NtfyService._internal();
  factory NtfyService() => _instance;
  NtfyService._internal();

  static const String _baseUrl = 'https://ntfy.sh';
  
  final FlutterLocalNotificationsPlugin _localNotifications = 
      FlutterLocalNotificationsPlugin();
  
  bool _initialized = false;
  
  // Store active EventSource connections (for web)
  List<html.EventSource> _activeSubscriptions = [];

  /// Initialize ntfy service
  Future<void> init() async {
    if (_initialized) return;
    
    // Initialize local notifications only for mobile
    if (!kIsWeb) {
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const DarwinInitializationSettings iosSettings =
          DarwinInitializationSettings();
      const InitializationSettings settings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );
      await _localNotifications.initialize(settings);
    } else {
      // For Web: Request Browser Permission
      if (html.Notification.supported && html.Notification.permission != 'granted') {
        await html.Notification.requestPermission();
      }
    }
    
    _initialized = true;
    print('✅ ntfy service initialized');
  }

  /// Subscribe a student to relevant topics
  Future<void> subscribeStudent(UserModel user) async {
    if (!_initialized) await init();
    
    final topics = _getTopicsForStudent(user);
    
    for (final topic in topics) {
      await _subscribeToTopic(topic);
    }
  }

  /// Subscribe to a single topic
  Future<void> _subscribeToTopic(String topic) async {
    try {
      print('📡 Subscribing to topic: $topic');
      
      if (kIsWeb) {
        // Web: Use EventSource API
        final eventSource = html.EventSource('$_baseUrl/$topic/sse');
        
        eventSource.onMessage.listen((event) {
          final data = event.data as String?;
          if (data != null && data.isNotEmpty) {
            _parseAndShowNotification(data);
          }
        });
        
        eventSource.onError.listen((error) {
          print('❌ EventSource error for $topic: $error');
        });
        
        _activeSubscriptions.add(eventSource);
      } else {
        // Mobile: Use HTTP polling
        _listenForMessages(topic);
      }
      
      print('✅ Subscribed to topic: $topic');
    } catch (e) {
      print('❌ Failed to subscribe to $topic: $e');
    }
  }

  /// Parse and show notification from SSE data
  void _parseAndShowNotification(String data) {
    final lines = data.split('\n');
    String? title;
    String? message;
    
    for (final line in lines) {
      if (line.startsWith('data:')) {
        final content = line.substring(5).trim();
        try {
          final json = jsonDecode(content);
          title = json['title'];
          message = json['message'];
        } catch (_) {
          message = content;
        }
      }
    }
    
    _showLocalNotification(
      NtfyMessage(
        title: title ?? 'College Noticeboard',
        message: message ?? '',
      )
    );
  }

  /// Listen for messages on a topic (mobile)
  Future<void> _listenForMessages(String topic) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/$topic/json'),
        headers: {'Accept': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          for (var msg in data) {
            _showLocalNotification(NtfyMessage(
              title: msg['title'],
              message: msg['message'],
            ));
          }
        }
      }
    } catch (e) {
      print('❌ Error listening to $topic: $e');
    }
    
    // Reconnect after delay
    await Future.delayed(const Duration(seconds: 30));
    _listenForMessages(topic);
  }

  /// Generate topics for a student
  List<String> _getTopicsForStudent(UserModel user) {
    final topics = <String>[];
    
    topics.add('college_${user.department}_${user.year}');
    topics.add('college_dept_${user.department}');
    topics.add('college_year_${user.year}');
    topics.add('college_all');
    
    if (user.committee != null && user.committee!.isNotEmpty) {
      topics.add('college_committee_${user.committee}');
    }
    
    return topics;
  }

  /// Send notification for a notice
  Future<void> sendNoticeNotification(NoticeModel notice) async {
    final topics = _getTopicsForNotice(notice);
    
    if (topics.isEmpty) {
      print('⚠️ No topics to send notification for notice: ${notice.title}');
      return;
    }
    
    for (final topic in topics) {
      try {
        final response = await http.post(
          Uri.parse('$_baseUrl/$topic'),
          headers: {
            'Title': notice.isImportant ? '🔴 URGENT: ${notice.title} 🔴' : '📢 ${notice.title} 📢',
            'Priority': _getPriorityLevel(notice.priority).toString(),
            'Tags': _getTags(notice).join(','),
            'Click': 'https://collegenoticeboard-49628.web.app',
            'Actions': 'view, Open App, https://collegenoticeboard-49628.web.app',
          },
          body: '${notice.description}\n\n${_getTags(notice).map((t) => '#$t').join(' ')}\nView more at: https://collegenoticeboard-49628.web.app',
        );
        
        if (response.statusCode == 200) {
          print('✅ Notification sent to topic: $topic');
        } else {
          print('❌ Failed to send to $topic: ${response.statusCode}');
        }
      } catch (e) {
        print('❌ Error sending to $topic: $e');
      }
    }
  }

  /// Determine topics for notice
  List<String> _getTopicsForNotice(NoticeModel notice) {
    final topics = <String>[];
    
    switch (notice.visibility) {
      case 'all':
        topics.add('college_all');
        break;
        
      case 'multi':
        if (notice.targetDepartments.isNotEmpty && notice.targetYears.isNotEmpty) {
          for (final dept in notice.targetDepartments) {
            for (final year in notice.targetYears) {
              topics.add('college_${dept}_${year}');
            }
          }
        } else {
          for (final dept in notice.targetDepartments) {
            topics.add('college_dept_$dept');
          }
          for (final year in notice.targetYears) {
            topics.add('college_year_$year');
          }
        }
        break;
        
      case 'department':
        if (notice.targetDepartment != null) {
          topics.add('college_dept_${notice.targetDepartment}');
        }
        break;
        
      case 'year':
        if (notice.targetYear != null) {
          topics.add('college_year_${notice.targetYear}');
        }
        break;
        
      case 'committee':
        if (notice.targetCommittee != null) {
          topics.add('college_committee_${notice.targetCommittee}');
        }
        break;
    }
    
    return topics.toSet().toList();
  }

  /// Convert priority to ntfy priority level
  int _getPriorityLevel(NoticePriority priority) {
    switch (priority) {
      case NoticePriority.urgent: return 5;
      case NoticePriority.high:   return 4;
      case NoticePriority.medium: return 3;
      case NoticePriority.low:    return 2;
    }
  }

  /// Get tags for notification
  List<String> _getTags(NoticeModel notice) {
    final tags = <String>[];
    if (notice.isImportant) tags.add('warning');
    if (notice.isPinned) tags.add('pin');
    tags.add(notice.category.toLowerCase());
    return tags;
  }

  /// Show local notification
  void _showLocalNotification(NtfyMessage message) {
    print('🔔 Showing notification: ${message.title} - ${message.message}');
    
    if (kIsWeb) {
      // For web, use browser notification
      if (html.Notification.supported) {
        html.Notification(message.title ?? 'College Noticeboard',
          body: message.message,
          icon: 'favicon.png',
        );
      } else {
        print('⚠️ Web notifications not supported in this browser');
      }
    } else {
      // For mobile, use flutter_local_notifications
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'college_notices',
        'College Notices',
        channelDescription: 'Notifications for new college notices',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );
      
      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();
      
      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );
      
      _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        message.title ?? 'College Noticeboard',
        message.message,
        details,
      );
    }
  }

  /// Unsubscribe from all topics
  Future<void> unsubscribeAll() async {
    for (final eventSource in _activeSubscriptions) {
      try {
        eventSource.close();
      } catch (e) {
        print('❌ Error closing subscription: $e');
      }
    }
    _activeSubscriptions.clear();
    print('✅ Unsubscribed from all topics');
  }
}

/// Message class
class NtfyMessage {
  final String? title;
  final String message;
  final int? priority;
  final List<String> tags;
  
  NtfyMessage({
    this.title,
    required this.message,
    this.priority,
    this.tags = const [],
  });
}
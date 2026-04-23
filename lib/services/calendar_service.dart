import 'dart:js' as js;
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/notice_model.dart';

class CalendarService {
  static final CalendarService _instance = CalendarService._internal();
  factory CalendarService() => _instance;
  CalendarService._internal();
  static const _webClientId =
      '174103157478-fh80l432rsdqj5ph3dpvgpt686umpenb.apps.googleusercontent.com';
  String? _accessToken;
  DateTime? _tokenExpiry;

  bool get isAuthorized {
    if (!kIsWeb) return false;
    if (_accessToken == null) return false;
    if (_tokenExpiry == null) return false;
    return DateTime.now().isBefore(_tokenExpiry!);
  }

  Future<bool> checkSilentAuth() async {
    // GIS does not support silent auth — user must tap once per session
    return isAuthorized;
  }

  /// Opens Google OAuth popup via GIS JS library.
  /// Returns true when access token is successfully obtained.
  Future<bool> requestAuthorization(BuildContext context) async {
    if (!kIsWeb) {
      debugPrint('Calendar: not on web, skipping');
      return false;
    }

    debugPrint('📅 Calendar: requesting token via GIS...');
    final completer = Completer<bool>();

    try {
      // Call the JS function defined in index.html
      js.context.callMethod('requestCalendarToken', [
        _webClientId,
        js.allowInterop((dynamic result) {
          final r = result?.toString() ?? 'null';
          debugPrint('📅 GIS callback result: $r');

          if (r == 'ok') {
            // Token stored in window.gCalToken by JS
            // Read it back
            final token = js.context.callMethod('getCalendarToken') as String?;
            if (token != null && token.isNotEmpty) {
              _accessToken = token;
              _tokenExpiry = DateTime.now().add(const Duration(hours: 1));
              debugPrint('✅ Calendar: got token (${token.substring(0, 20)}...)');
              completer.complete(true);
            } else {
              debugPrint('❌ Calendar: JS said ok but token is null/empty');
              completer.complete(false);
            }
          } else {
            debugPrint('❌ Calendar: GIS returned: $r');
            completer.complete(false);
          }
        }),
      ]);
    } catch (e) {
      debugPrint('❌ Calendar JS interop error: $e');
      // JS function not available yet — GIS script might still be loading
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Google services still loading. Wait 2 seconds and try again.'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ));
      }
      return false;
    }

    // Wait up to 3 minutes for user to complete OAuth in popup
    try {
      return await completer.future.timeout(const Duration(minutes: 3),
          onTimeout: () {
        debugPrint('❌ Calendar: OAuth timed out');
        return false;
      });
    } catch (e) {
      debugPrint('❌ Calendar: completer error $e');
      return false;
    }
  }

  Future<void> signOut() async {
    _accessToken = null;
    _tokenExpiry = null;
    if (kIsWeb) {
      try {
        js.context.callMethod('clearCalendarToken');
      } catch (_) {}
    }
  }

  // ── Calendar API calls (direct REST, no googleapis package needed) ─────────

  Future<CalendarResult> addNoticeToCalendar(NoticeModel notice) async {
    final token = _getToken();
    if (token == null) {
      return const CalendarResult(
          success: false,
          message: 'Tap 📅 to connect Google Calendar first.');
    }

    try {
      final body = _buildNoticeEvent(notice);
      final response = await _insertEvent(token, body);
      return _handleResponse(response);
    } catch (e) {
      debugPrint('❌ Calendar addNotice error: $e');
      return CalendarResult(success: false, message: 'Error: $e');
    }
  }

  Future<CalendarResult> addEventToCalendar({
    required String title,
    required String description,
    required String venue,
    required DateTime eventDate,
    int durationHours = 2,
  }) async {
    final token = _getToken();
    if (token == null) {
      return const CalendarResult(
          success: false, message: 'Not connected to Google Calendar.');
    }

    try {
      final body = {
        'summary':     '[College Event] $title',
        'description': '$description\n\nVenue: $venue',
        'location':    venue,
        'start': {
          'dateTime': eventDate.toUtc().toIso8601String(),
          'timeZone': 'UTC',
        },
        'end': {
          'dateTime': eventDate
              .add(Duration(hours: durationHours))
              .toUtc()
              .toIso8601String(),
          'timeZone': 'UTC',
        },
        'reminders': {
          'useDefault': false,
          'overrides': [
            {'method': 'popup', 'minutes': 60},
            {'method': 'popup', 'minutes': 1440},
          ],
        },
      };

      final response = await _insertEvent(token, body);
      return _handleResponse(response);
    } catch (e) {
      return CalendarResult(success: false, message: 'Error: $e');
    }
  }

  // ── Private ────────────────────────────────────────────────────────────────

  String? _getToken() {
    if (!isAuthorized) {
      _accessToken = null;
      _tokenExpiry = null;
      return null;
    }
    return _accessToken;
  }

  Map<String, dynamic> _buildNoticeEvent(NoticeModel notice) {
    final now   = DateTime.now().toUtc();
    final today = DateTime.now();

    return {
      'summary': '[College] ${notice.title}',
      'description':
          '${notice.description}\n\n'
          'Category: ${notice.category}\n'
          'Priority: ${notice.priority.label}'
          '${notice.expiresAt != null ? '\nDeadline: ${_fmt(notice.expiresAt!)}' : ''}',
      'colorId': _colorId(notice.priority),
      'start': notice.expiresAt != null
          ? {'dateTime': now.toIso8601String(), 'timeZone': 'UTC'}
          : {
              'date':
                  '${today.year}-${_p(today.month)}-${_p(today.day)}'
            },
      'end': notice.expiresAt != null
          ? {
              'dateTime': notice.expiresAt!.toUtc().toIso8601String(),
              'timeZone': 'UTC'
            }
          : {
              'date':
                  '${today.year}-${_p(today.month)}-${_p(today.day + 1)}'
            },
      'reminders': {
        'useDefault': false,
        'overrides': [
          {
            'method': 'popup',
            'minutes': _reminderMinutes(notice.priority),
          },
        ],
      },
    };
  }

  Future<http.Response> _insertEvent(
      String token, Map<String, dynamic> body) async {
    debugPrint('📅 POST calendar event: ${body['summary']}');
    final response = await http.post(
      Uri.parse(
          'https://www.googleapis.com/calendar/v3/calendars/primary/events'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type':  'application/json',
      },
      body: jsonEncode(body),
    );
    debugPrint('📅 Calendar API status: ${response.statusCode}');
    debugPrint('📅 Calendar API body: ${response.body}');
    return response;
  }

  CalendarResult _handleResponse(http.Response response) {
    if (response.statusCode == 200 || response.statusCode == 201) {
      return const CalendarResult(
          success: true, message: '✅ Added to your Google Calendar!');
    }

    if (response.statusCode == 401) {
      // Token expired
      _accessToken = null;
      _tokenExpiry = null;
      return const CalendarResult(
          success: false,
          message: 'Session expired. Tap 📅 to reconnect.');
    }

    try {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final msg = (decoded['error'] as Map?)?['message'] as String?
          ?? 'HTTP ${response.statusCode}';
      return CalendarResult(success: false, message: 'Calendar error: $msg');
    } catch (_) {
      return CalendarResult(
          success: false,
          message: 'Calendar error: HTTP ${response.statusCode}');
    }
  }

  int _reminderMinutes(NoticePriority p) {
    switch (p) {
      case NoticePriority.urgent: return 30;
      case NoticePriority.high:   return 60;
      case NoticePriority.medium: return 120;
      case NoticePriority.low:    return 1440;
    }
  }

  String _colorId(NoticePriority p) {
    switch (p) {
      case NoticePriority.urgent: return '11';
      case NoticePriority.high:   return '6';
      case NoticePriority.medium: return '9';
      case NoticePriority.low:    return '10';
    }
  }

  String _fmt(DateTime d) =>
      '${_p(d.day)}/${_p(d.month)}/${d.year} ${_p(d.hour)}:${_p(d.minute)}';

  String _p(int n) => n.toString().padLeft(2, '0');
}

class CalendarResult {
  final bool success;
  final String message;
  const CalendarResult({required this.success, required this.message});
}
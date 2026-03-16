import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:googleapis/calendar/v3.dart' as gcal;
import '../models/notice_model.dart';

class CalendarService {
  static final CalendarService _instance = CalendarService._internal();
  factory CalendarService() => _instance;
  CalendarService._internal();

  // Request only calendar event write scope
  static final _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      gcal.CalendarApi.calendarEventsScope,
    ],
  );

  bool _authorized = false;
  bool get isAuthorized => _authorized;

  /// Call this after student logs into the app.
  /// Shows Google sign-in once; after that it's silent.
  Future<bool> requestAuthorization(BuildContext context) async {
    try {
      // Try silent sign-in first (already authorized before)
      GoogleSignInAccount? account = await _googleSignIn.signInSilently();

      // If silent fails, show the full Google sign-in UI
      account ??= await _googleSignIn.signIn();

      if (account == null) {
        // User dismissed the sign-in
        _authorized = false;
        return false;
      }

      _authorized = true;
      return true;
    } catch (e) {
      debugPrint('CalendarService.requestAuthorization error: $e');
      _authorized = false;
      return false;
    }
  }

  /// Silently check if already authorized (no UI shown)
  Future<bool> checkSilentAuth() async {
    try {
      final account = await _googleSignIn.signInSilently();
      _authorized = account != null;
      return _authorized;
    } catch (_) {
      _authorized = false;
      return false;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _authorized = false;
  }

  /// Add a notice as a Google Calendar event.
  /// If expiresAt is set → it's a timed event (deadline).
  /// Otherwise → all-day event on today.
  Future<CalendarResult> addNoticeToCalendar(NoticeModel notice) async {
    try {
      final client = await _googleSignIn.authenticatedClient();
      if (client == null) {
        return CalendarResult(
            success: false, message: 'Not signed in to Google.');
      }

      final calApi = gcal.CalendarApi(client);

      // Build start/end times
      gcal.EventDateTime start;
      gcal.EventDateTime end;

      if (notice.expiresAt != null) {
        // Timed event: start = now, end = expiresAt
        start = gcal.EventDateTime(
          dateTime: DateTime.now().toUtc(),
          timeZone: 'UTC',
        );
        end = gcal.EventDateTime(
          dateTime: notice.expiresAt!.toUtc(),
          timeZone: 'UTC',
        );
      } else {
        // All-day event on today
        final today = DateTime.now();
        start = gcal.EventDateTime(
          date: DateTime(today.year, today.month, today.day),
        );
        end = gcal.EventDateTime(
          date: DateTime(today.year, today.month, today.day + 1),
        );
      }

      // Build reminder based on priority
      final reminderMinutes = _reminderMinutes(notice.priority);
      final reminders = gcal.EventReminders(
        useDefault: false,
        overrides: [
          gcal.EventReminder(
              method: 'popup', minutes: reminderMinutes),
          gcal.EventReminder(
              method: 'email', minutes: reminderMinutes),
        ],
      );

      final event = gcal.Event(
        summary:     '[College] ${notice.title}',
        description: '${notice.description}'
            '\n\n'
            'Category: ${notice.category}'
            '\nPriority: ${notice.priority.label}'
            '${notice.expiresAt != null ? '\nDeadline: ${_fmt(notice.expiresAt!)}' : ''}',
        colorId:     _colorId(notice.priority),
        start:       start,
        end:         end,
        reminders:   reminders,
      );

      await calApi.events.insert(event, 'primary');
      return CalendarResult(
          success: true,
          message: 'Added to your Google Calendar.');
    } on gcal.DetailedApiRequestError catch (e) {
      return CalendarResult(
          success: false,
          message: 'Calendar error: ${e.message}');
    } catch (e) {
      return CalendarResult(
          success: false,
          message: 'Failed to add to calendar: $e');
    }
  }

  /// Add a college event to Google Calendar.
  Future<CalendarResult> addEventToCalendar({
    required String title,
    required String description,
    required String venue,
    required DateTime eventDate,
    int durationHours = 2,
  }) async {
    try {
      final client = await _googleSignIn.authenticatedClient();
      if (client == null) {
        return CalendarResult(
            success: false, message: 'Not signed in to Google.');
      }

      final calApi = gcal.CalendarApi(client);

      final event = gcal.Event(
        summary:     '[College Event] $title',
        description: '$description\n\nVenue: $venue',
        location:    venue,
        start: gcal.EventDateTime(
          dateTime: eventDate.toUtc(),
          timeZone: 'UTC'),
        end: gcal.EventDateTime(
          dateTime: eventDate
              .add(Duration(hours: durationHours)).toUtc(),
          timeZone: 'UTC'),
        reminders: gcal.EventReminders(
          useDefault: false,
          overrides: [
            gcal.EventReminder(method: 'popup',  minutes: 60),
            gcal.EventReminder(method: 'popup',  minutes: 1440), // 1 day
            gcal.EventReminder(method: 'email',  minutes: 1440),
          ],
        ),
      );

      await calApi.events.insert(event, 'primary');
      return CalendarResult(success: true,
          message: 'Event added to your Google Calendar.');
    } catch (e) {
      return CalendarResult(
          success: false,
          message: 'Failed: $e');
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Minutes before deadline to remind, based on priority
  int _reminderMinutes(NoticePriority p) {
    switch (p) {
      case NoticePriority.urgent: return 30;
      case NoticePriority.high:   return 60;
      case NoticePriority.medium: return 120;
      case NoticePriority.low:    return 1440; // 1 day
    }
  }

  /// Google Calendar color IDs (1–11)
  String _colorId(NoticePriority p) {
    switch (p) {
      case NoticePriority.urgent: return '11'; // Tomato red
      case NoticePriority.high:   return '6';  // Tangerine orange
      case NoticePriority.medium: return '9';  // Blueberry
      case NoticePriority.low:    return '10'; // Sage green
    }
  }

  String _fmt(DateTime d) =>
      '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
}

/// Result wrapper for calendar operations
class CalendarResult {
  final bool success;
  final String message;
  const CalendarResult({required this.success, required this.message});
}
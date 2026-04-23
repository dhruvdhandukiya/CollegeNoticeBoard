// lib/screens/student/event_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/firestore_service.dart';
import '../../utils/app_theme.dart';
import '../../services/calendar_service.dart';

class EventDetailScreen extends StatefulWidget {
  final Map<String, dynamic> event;
  final String userId;

  const EventDetailScreen({
    super.key,
    required this.event,
    required this.userId,
  });

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  late CalendarService _calendar;
  bool _isRsvping = false;

  @override
  void initState() {
    super.initState();
    _calendar = CalendarService();
  }

  Future<void> _handleRsvp() async {
    setState(() => _isRsvping = true);
    try {
      final fs = context.read<FirestoreService>();
      await fs.rsvpEvent(widget.event['id'], widget.userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You are now going to this event!'),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isRsvping = false);
    }
  }

  Future<void> _cancelRsvp() async {
    setState(() => _isRsvping = true);
    try {
      final fs = context.read<FirestoreService>();
      await fs.cancelRsvp(widget.event['id'], widget.userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('RSVP cancelled.'),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isRsvping = false);
    }
  }

  Future<void> _addToCalendar() async {
    if (!_calendar.isAuthorized) {
      final authorized = await _calendar.requestAuthorization(context);
      if (!authorized) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please sign in to Google to add to calendar'),
            backgroundColor: AppTheme.danger,
          ),
        );
        return;
      }
    }

    final result = await _calendar.addEventToCalendar(
      title: widget.event['title'] ?? '',
      description: widget.event['description'] ?? '',
      venue: widget.event['venue'] ?? '',
      eventDate: (widget.event['eventDate'] as dynamic).toDate(),
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: result.success ? AppTheme.success : AppTheme.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final date = (widget.event['eventDate'] as dynamic).toDate();
    final rsvpUsers = List<String>.from(widget.event['rsvpUsers'] ?? []);
    final hasRsvpd = rsvpUsers.contains(widget.userId);

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Event Details'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date & Time card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_today_rounded,
                      color: AppTheme.accent),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('EEEE, MMMM dd, yyyy').format(date),
                    style: AppTheme.body.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.access_time_rounded,
                      color: AppTheme.accent),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('hh:mm a').format(date),
                    style: AppTheme.body.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Title
            Text(
              widget.event['title'] ?? '',
              style: AppTheme.heading1,
            ),
            const SizedBox(height: 12),

            // Venue
            Row(
              children: [
                const Icon(Icons.location_on_outlined,
                    size: 18, color: AppTheme.textMuted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.event['venue'] ?? 'No venue specified',
                    style: AppTheme.body,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Organizer
            if (widget.event['organizer'] != null &&
                (widget.event['organizer'] as String).isNotEmpty)
              Row(
                children: [
                  const Icon(Icons.groups_outlined,
                      size: 18, color: AppTheme.textMuted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.event['organizer'],
                      style: AppTheme.body,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 8),

            // Category
            Row(
              children: [
                const Icon(Icons.category_outlined,
                    size: 18, color: AppTheme.textMuted),
                const SizedBox(width: 8),
                Text(
                  widget.event['category'] ?? 'General',
                  style: AppTheme.body,
                ),
              ],
            ),
            const SizedBox(height: 24),

            const Divider(),
            const SizedBox(height: 16),

            // Description
            Text('Description', style: AppTheme.heading3),
            const SizedBox(height: 8),
            Text(
              widget.event['description'] ?? 'No description provided',
              style: AppTheme.body.copyWith(height: 1.6),
            ),
            const SizedBox(height: 24),

            const Divider(),
            const SizedBox(height: 16),

            // RSVP Section
            Text('RSVP Information', style: AppTheme.heading3),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.success.withOpacity(0.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.success.withOpacity(0.25),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.success.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.people_alt_rounded,
                            color: AppTheme.success),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${rsvpUsers.length} ${rsvpUsers.length == 1 ? 'person' : 'people'} going',
                            style: AppTheme.heading2.copyWith(
                              color: AppTheme.success,
                              fontSize: 18,
                            ),
                          ),
                          if (hasRsvpd)
                            Text(
                              'You are going! ✅',
                              style: AppTheme.bodyMuted.copyWith(
                                color: AppTheme.success,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (!hasRsvpd)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isRsvping ? null : _handleRsvp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isRsvping
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('RSVP to this Event'),
                      ),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _isRsvping ? null : _cancelRsvp,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppTheme.danger),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isRsvping
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Cancel RSVP'),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Add to Calendar button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _addToCalendar,
                icon: const Icon(Icons.calendar_today_rounded, size: 18),
                label: const Text('Add to Google Calendar'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1565C0),
                  side: const BorderSide(color: Color(0xFF1565C0)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
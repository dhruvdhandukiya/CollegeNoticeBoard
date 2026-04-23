// lib/screens/admin/event_detail_screen.dart

import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/firestore_service.dart';
import '../../utils/app_theme.dart';
import 'add_event_screen.dart';

class EventDetailScreen extends StatelessWidget {
  final Map<String, dynamic> event;
  final String userId;

  const EventDetailScreen({
    super.key,
    required this.event,
    required this.userId,
  });

  void _openPdf(String url) {
    html.window.open(url, '_blank');
  }

  @override
  Widget build(BuildContext context) {
    final date = (event['eventDate'] as dynamic).toDate();
    final rsvpUsers = List<String>.from(event['rsvpUsers'] ?? []);
    final hasRsvpd = rsvpUsers.contains(userId);
    final pdfUrl = event['pdfUrl'];

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Event Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddEventScreen(existing: event),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date & Time box
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
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
                    style: AppTheme.body.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.access_time_rounded,
                      color: AppTheme.accent),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('hh:mm a').format(date),
                    style: AppTheme.body.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Title
            Text(
              event['title'] ?? '',
              style: AppTheme.heading1,
            ),
            const SizedBox(height: 12),

            // Venue
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on_outlined,
                    size: 18, color: AppTheme.textMuted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    event['venue'] ?? 'No venue specified',
                    style: AppTheme.body,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Organizer
            if (event['organizer'] != null &&
                (event['organizer'] as String).isNotEmpty)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.groups_outlined,
                      size: 18, color: AppTheme.textMuted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      event['organizer'],
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
                  event['category'] ?? 'General',
                  style: AppTheme.body,
                ),
              ],
            ),
            const SizedBox(height: 20),

            const Divider(),
            const SizedBox(height: 16),

            // Description
            Text(
              'Description',
              style: AppTheme.heading3,
            ),
            const SizedBox(height: 8),
            Text(
              event['description'] ?? 'No description provided',
              style: AppTheme.body.copyWith(height: 1.6),
            ),
            const SizedBox(height: 20),

            // PDF Attachment
            if (pdfUrl != null && pdfUrl.isNotEmpty) ...[
              const Divider(),
              const SizedBox(height: 16),
              Text(
                'Attachment',
                style: AppTheme.heading3,
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () => _openPdf(pdfUrl),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.danger.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppTheme.danger.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.picture_as_pdf_rounded,
                          color: AppTheme.danger),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          event['pdfName'] ?? 'Event PDF',
                          style: AppTheme.body.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Icon(Icons.open_in_new_rounded,
                          size: 16, color: AppTheme.textMuted),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),

            // RSVP Section
            Text(
              'RSVP Information',
              style: AppTheme.heading3,
            ),
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
              child: Row(
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
            ),
            
            const SizedBox(height: 20),
            
            // Edit button at bottom
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddEventScreen(existing: event),
                    ),
                  );
                },
                icon: const Icon(Icons.edit_rounded, size: 18),
                label: const Text('Edit Event'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primary,
                  side: const BorderSide(color: AppTheme.primary),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/calendar_service.dart';
import '../../utils/app_theme.dart';

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
  bool _loadingPdf = false;
  String? _localPdfPath;

  late Map<String, dynamic> _event;
  bool get _hasRsvpd =>
      ((_event['rsvpUsers'] as List?) ?? []).contains(widget.userId);

  @override
  void initState() {
    super.initState();
    _event = Map.from(widget.event);
  }

  Future<void> _downloadAndOpenPdf() async {
    final url = _event['pdfUrl'] as String?;
    if (url == null) return;

    if (_localPdfPath != null) {
      _openPdf(); return;
    }

    setState(() => _loadingPdf = true);
    try {
      final response = await http.get(Uri.parse(url));
      final dir  = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/${_event['pdfName'] ?? 'event.pdf'}');
      await file.writeAsBytes(response.bodyBytes);
      setState(() { _localPdfPath = file.path; _loadingPdf = false; });
      _openPdf();
    } catch (e) {
      setState(() => _loadingPdf = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Could not load PDF. Check your connection.'),
          backgroundColor: AppTheme.danger,
          behavior: SnackBarBehavior.floating));
      }
    }
  }

  void _openPdf() {
    if (_localPdfPath == null) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _PdfViewerScreen(
        path:  _localPdfPath!,
        title: _event['title'] ?? 'Event PDF',
      ),
    ));
  }

  Future<void> _toggleRsvp() async {
    final fs  = context.read<FirestoreService>();
    final id  = _event['id'] as String;
    final uid = widget.userId;
    if (_hasRsvpd) {
      await fs.cancelRsvp(id, uid);
      setState(() {
        (_event['rsvpUsers'] as List?)?.remove(uid);
        _event['rsvpCount'] = (_event['rsvpCount'] as int? ?? 1) - 1;
      });
    } else {
      await fs.rsvpEvent(id, uid);
      setState(() {
        if (_event['rsvpUsers'] == null) _event['rsvpUsers'] = [];
        (_event['rsvpUsers'] as List).add(uid);
        _event['rsvpCount'] = (_event['rsvpCount'] as int? ?? 0) + 1;
      });
    }
  }

  Future<void> _addToCalendar() async {
    final cal      = CalendarService();
    final eventDate = (_event['eventDate'] as dynamic).toDate() as DateTime;
    if (!cal.isAuthorized) {
      await cal.requestAuthorization(context);
    }
    if (!cal.isAuthorized || !mounted) return;
    final result = await cal.addEventToCalendar(
      title:       _event['title'] ?? '',
      description: _event['description'] ?? '',
      venue:       _event['venue'] ?? '',
      eventDate:   eventDate,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result.message),
        backgroundColor:
            result.success ? AppTheme.success : AppTheme.danger,
        behavior: SnackBarBehavior.floating));
    }
  }

  @override
  Widget build(BuildContext context) {
    final eventDate =
        (_event['eventDate'] as dynamic).toDate() as DateTime;
    final hasPdf    = _event['pdfUrl'] != null;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: CustomScrollView(
        slivers: [
          // ── App bar with date hero ─────────────────────────────────────
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            backgroundColor: AppTheme.primary,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0D1B6E), Color(0xFF283593)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight)),
                child: SafeArea(child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 48, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _catBadge(_event['category'] ?? 'Event'),
                      const SizedBox(height: 8),
                      Text(_event['title'] ?? '',
                          style: AppTheme.heading2.copyWith(
                              color: Colors.white)),
                    ],
                  ),
                )),
              ),
            ),
          ),

          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ── Info row ───────────────────────────────────────────
                Row(children: [
                  // Date block
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14)),
                    child: Column(children: [
                      Text(DateFormat('dd').format(eventDate),
                          style: AppTheme.heading1.copyWith(
                              color: AppTheme.accent, fontSize: 26)),
                      Text(DateFormat('MMM yyyy').format(eventDate),
                          style: AppTheme.label.copyWith(
                              color: AppTheme.accent, fontSize: 11)),
                      Text(DateFormat('hh:mm a').format(eventDate),
                          style: AppTheme.bodyMuted.copyWith(fontSize: 11)),
                    ]),
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _infoRow(Icons.location_on_outlined,
                          _event['venue'] ?? '—'),
                      const SizedBox(height: 8),
                      _infoRow(Icons.groups_outlined,
                          _event['organizer'] ?? '—'),
                      const SizedBox(height: 8),
                      _infoRow(Icons.people_outline_rounded,
                          '${_event['rsvpCount'] ?? 0} going'),
                    ],
                  )),
                ]),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 16),

                // ── Description ────────────────────────────────────────
                if ((_event['description'] ?? '').isNotEmpty) ...[
                  Text('About this Event', style: AppTheme.heading3),
                  const SizedBox(height: 8),
                  Text(_event['description'],
                      style: AppTheme.body.copyWith(
                          height: 1.8, fontSize: 14.5)),
                  const SizedBox(height: 20),
                ],

                // ── PDF ────────────────────────────────────────────────
                if (hasPdf) ...[
                  Text('Attachments', style: AppTheme.heading3),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: _downloadAndOpenPdf,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: const Color(0xFFDDE3F0))),
                      child: Row(children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.danger.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10)),
                          child: const Icon(
                              Icons.picture_as_pdf_rounded,
                              color: AppTheme.danger, size: 24)),
                        const SizedBox(width: 12),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _event['pdfName'] ?? 'Event Document.pdf',
                              style: AppTheme.body.copyWith(
                                  fontWeight: FontWeight.w600)),
                            Text('Tap to view',
                                style: AppTheme.bodyMuted.copyWith(
                                    fontSize: 12)),
                          ],
                        )),
                        if (_loadingPdf)
                          const SizedBox(width: 20, height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2))
                        else
                          const Icon(Icons.open_in_new_rounded,
                              color: AppTheme.textMuted, size: 18),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // ── Actions ────────────────────────────────────────────
                Text('Actions', style: AppTheme.heading3),
                const SizedBox(height: 12),

                // RSVP button
                ElevatedButton.icon(
                  onPressed: _toggleRsvp,
                  icon: Icon(_hasRsvpd
                      ? Icons.cancel_outlined : Icons.how_to_reg_rounded),
                  label: Text(_hasRsvpd
                      ? 'Cancel RSVP' : 'RSVP — I\'m Going'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _hasRsvpd
                        ? AppTheme.danger : AppTheme.success,
                    minimumSize: const Size(double.infinity, 52)),
                ),
                const SizedBox(height: 10),

                // Google Calendar button
                OutlinedButton.icon(
                  onPressed: _addToCalendar,
                  icon: const Icon(Icons.calendar_today_rounded,
                      size: 17),
                  label: const Text('Add to Google Calendar'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1565C0),
                    side: const BorderSide(color: Color(0xFF1565C0)),
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14))),
                ),
                const SizedBox(height: 24),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _catBadge(String cat) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.15),
      borderRadius: BorderRadius.circular(20)),
    child: Text(cat, style: AppTheme.label.copyWith(
        color: Colors.white, fontSize: 11)),
  );

  Widget _infoRow(IconData icon, String text) => Row(children: [
    Icon(icon, size: 16, color: AppTheme.textMuted),
    const SizedBox(width: 6),
    Expanded(child: Text(text,
        style: AppTheme.body.copyWith(fontSize: 13),
        maxLines: 2,
        overflow: TextOverflow.ellipsis)),
  ]);
}

// ── In-App PDF Viewer ─────────────────────────────────────────────────────────
class _PdfViewerScreen extends StatefulWidget {
  final String path;
  final String title;
  const _PdfViewerScreen({required this.path, required this.title});
  @override
  State<_PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<_PdfViewerScreen> {
  int _currentPage = 0;
  int _totalPages  = 0;
  bool _ready      = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(widget.title,
            style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_ready)
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              child: Text(
                '${_currentPage + 1} / $_totalPages',
                style: const TextStyle(
                    color: Colors.white70, fontSize: 13)),
            ),
        ],
      ),
      body: PDFView(
        filePath:     widget.path,
        enableSwipe:  true,
        swipeHorizontal: false,
        autoSpacing: true,
        pageFling:   true,
        fitPolicy:   FitPolicy.BOTH,
        onRender: (pages) => setState(() {
          _totalPages = pages ?? 0;
          _ready      = true;
        }),
        onPageChanged: (page, _) =>
            setState(() => _currentPage = page ?? 0),
        onError: (e) => ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('PDF error: $e'))),
      ),
    );
  }
}
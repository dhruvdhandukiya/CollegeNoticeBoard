// lib/screens/student/student_home_screen.dart
// v5.1 — fixed overlapping, no NestedScrollView, proper fixed header

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/notice_model.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';
import '../../services/auth_service.dart';
import '../../services/calendar_service.dart';
import '../../utils/app_theme.dart';
import '../login_screen.dart';
import 'event_detail_screen.dart';

class StudentHomeScreen extends StatefulWidget {
  final UserModel user;
  const StudentHomeScreen({super.key, required this.user});
  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  bool _urgentShown = false;
  final _calendar = CalendarService();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initCalendar());
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _initCalendar() async {
    final ok = await _calendar.checkSilentAuth();
    if (!ok && mounted) {
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) _showCalendarPrompt();
    }
  }

  void _showCalendarPrompt() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 24, 24, 24 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.calendar_today_rounded,
              color: Color(0xFF1565C0), size: 40),
          const SizedBox(height: 14),
          Text('Connect Google Calendar',
              style: AppTheme.heading2, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            'Allow the app to automatically add notices and events '
            'to your Google Calendar with reminders.',
            style: AppTheme.bodyMuted, textAlign: TextAlign.center),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              await _calendar.requestAuthorization(context);
            },
            icon: const Icon(Icons.login_rounded),
            label: const Text('Connect with Google'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Skip for now', style: AppTheme.bodyMuted)),
        ]),
      ),
    );
  }

  Future<void> _signOut() async {
    await context.read<AuthService>().signOut();
    if (!mounted) return;
    Navigator.pushReplacement(context,
        MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  void _maybeShowUrgent(List<NoticeModel> notices) {
    if (_urgentShown) return;
    final urgent = notices.where((n) =>
        n.priority == NoticePriority.urgent &&
        !n.isReadBy(widget.user.uid)).toList();
    if (urgent.isEmpty) return;
    _urgentShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showUrgentDialog(urgent.first);
    });
  }

  void _showUrgentDialog(NoticeModel n) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      builder: (_) => WillPopScope(
        onWillPop: () async => false,
        child: Dialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                    color: AppTheme.danger,
                    borderRadius: BorderRadius.circular(8)),
                child: const Text('URGENT NOTICE',
                    style: TextStyle(color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 11, letterSpacing: 1)),
              ),
              const SizedBox(height: 16),
              Text(n.title, style: AppTheme.heading2,
                  textAlign: TextAlign.center),
              const SizedBox(height: 10),
              Text(n.description, style: AppTheme.body,
                  textAlign: TextAlign.center,
                  maxLines: 5, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  context.read<FirestoreService>()
                      .markNoticeRead(n.id, widget.user.uid);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.danger,
                    minimumSize: const Size(double.infinity, 46)),
                child: const Text('Acknowledged'),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final u  = widget.user;
    final fs = context.read<FirestoreService>();
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      // A plain Column: header (fixed height) + Expanded tab content.
      // No NestedScrollView, no SliverAppBar — zero overlap possible.
      body: Column(children: [
        // ── HEADER ────────────────────────────────────────────────────
        Container(
          color: AppTheme.primary,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Status bar inset
            SizedBox(height: topPadding),
            // Greeting row
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 8, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Hi, ${u.name.split(' ').first} 👋',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 5),
                      Wrap(spacing: 5, children: [
                        _headerChip(u.department,
                            AppTheme.deptColor(u.department)),
                        _headerChip(u.year,
                            AppTheme.yearColor(u.year)),
                        if (u.committee != null)
                          _headerChip('⭐ ${u.committee}',
                              AppTheme.purple),
                      ]),
                    ],
                  )),
                  // Nudge bell
                  StreamBuilder<int>(
                    stream: fs.nudgeCount(u.uid),
                    builder: (_, snap) {
                      final count = snap.data ?? 0;
                      return Stack(clipBehavior: Clip.none, children: [
                        IconButton(
                          icon: const Icon(Icons.notifications_outlined,
                              color: Colors.white, size: 23),
                          onPressed: () {
                            _tabs.animateTo(2);
                            fs.markNudgesSeen(u.uid);
                          }),
                        if (count > 0)
                          Positioned(top: 6, right: 6,
                            child: Container(
                              width: 16, height: 16,
                              decoration: const BoxDecoration(
                                  color: AppTheme.accent,
                                  shape: BoxShape.circle),
                              child: Center(child: Text(
                                count > 9 ? '9+' : '$count',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800))))),
                      ]);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout_rounded,
                        color: Colors.white, size: 22),
                    onPressed: _signOut),
                ],
              ),
            ),
            const SizedBox(height: 6),
            // Tab bar
            TabBar(
              controller: _tabs,
              indicatorColor: AppTheme.accent,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white54,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelPadding: const EdgeInsets.symmetric(
                  horizontal: 14),
              labelStyle: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 12),
              unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w500, fontSize: 12),
              tabs: const [
                Tab(height: 40,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.campaign_rounded, size: 14),
                      SizedBox(width: 5),
                      Text('Notices'),
                    ])),
                Tab(height: 40,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.event_rounded, size: 14),
                      SizedBox(width: 5),
                      Text('Events'),
                    ])),
                Tab(height: 40,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.pending_actions_rounded, size: 14),
                      SizedBox(width: 5),
                      Text('Pending'),
                    ])),
                Tab(height: 40,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.person_rounded, size: 14),
                      SizedBox(width: 5),
                      Text('Profile'),
                    ])),
              ],
            ),
          ]),
        ),

        // ── TAB CONTENT ───────────────────────────────────────────────
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _NoticesFeed(user: u,
                  onUrgent: _maybeShowUrgent,
                  calendar: _calendar),
              _EventsFeed(user: u),
              _PendingTab(user: u),
              _ProfileTab(user: u, onSignOut: _signOut),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _headerChip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
        color: color.withOpacity(0.28),
        borderRadius: BorderRadius.circular(20)),
    child: Text(label, style: const TextStyle(
        color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
  );
}

// ── Notices Feed ──────────────────────────────────────────────────────────────
class _NoticesFeed extends StatefulWidget {
  final UserModel user;
  final void Function(List<NoticeModel>) onUrgent;
  final CalendarService calendar;
  const _NoticesFeed({
    required this.user, required this.onUrgent, required this.calendar});
  @override
  State<_NoticesFeed> createState() => _NoticesFeedState();
}

class _NoticesFeedState extends State<_NoticesFeed> {
  String _filter = 'All';

  @override
  Widget build(BuildContext context) {
    final u  = widget.user;
    final fs = context.read<FirestoreService>();

    return Column(children: [
      SizedBox(
        height: 46,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          children: [
            for (final f in [
              'All', 'Urgent', 'Important',
              u.department, u.year,
              if (u.committee != null) u.committee!,
            ]) ...[
              _FilterChip(label: f, selected: _filter == f,
                  onTap: () => setState(() => _filter = f)),
              const SizedBox(width: 6),
            ],
          ],
        ),
      ),
      Expanded(child: StreamBuilder<List<NoticeModel>>(
        stream: fs.getFilteredNotices(u),
        builder: (_, snap) {
          if (!snap.hasData) return const Center(
              child: CircularProgressIndicator());

          var notices = List<NoticeModel>.from(snap.data!);
          widget.onUrgent(notices);

          switch (_filter) {
            case 'Urgent':
              notices = notices.where((n) =>
                  n.priority == NoticePriority.urgent).toList();
              break;
            case 'Important':
              notices = notices.where((n) => n.isImportant).toList();
              break;
            default:
              if (_filter == u.department) {
                notices = notices.where((n) =>
                    n.visibility == 'department' &&
                    n.targetDepartment == u.department).toList();
              } else if (_filter == u.year) {
                notices = notices.where((n) =>
                    n.visibility == 'year' &&
                    n.targetYear == u.year).toList();
              } else if (u.committee != null &&
                  _filter == u.committee) {
                notices = notices.where((n) =>
                    n.visibility == 'committee' &&
                    n.targetCommittee == u.committee).toList();
              }
          }

          notices.sort((a, b) {
            if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
            final pd = b.priority.index - a.priority.index;
            if (pd != 0) return pd;
            return b.createdAt.compareTo(a.createdAt);
          });

          if (notices.isEmpty) return Center(child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inbox_rounded, size: 52,
                  color: AppTheme.textMuted.withOpacity(0.2)),
              const SizedBox(height: 12),
              Text('No notices here', style: AppTheme.bodyMuted),
            ],
          ));

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
            itemCount: notices.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (_, i) => _NoticeCard(
                notice: notices[i], user: u,
                calendar: widget.calendar),
          );
        },
      )),
    ]);
  }
}

// ── Notice Card ───────────────────────────────────────────────────────────────
class _NoticeCard extends StatelessWidget {
  final NoticeModel notice;
  final UserModel user;
  final CalendarService calendar;
  const _NoticeCard({
    required this.notice, required this.user, required this.calendar});

  Color get _pColor {
    switch (notice.priority) {
      case NoticePriority.urgent: return AppTheme.danger;
      case NoticePriority.high:   return const Color(0xFFF57C00);
      case NoticePriority.medium: return AppTheme.primary;
      case NoticePriority.low:    return AppTheme.success;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (!notice.isReadBy(user.uid)) {
          context.read<FirestoreService>()
              .markNoticeRead(notice.id, user.uid);
        }
        _showDetail(context);
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: notice.priority == NoticePriority.urgent
                ? AppTheme.danger.withOpacity(0.35)
                : const Color(0xFFECEFF9),
            width: notice.priority == NoticePriority.urgent ? 1.5 : 1)),
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            Container(
              width: 5,
              decoration: BoxDecoration(
                color: _pColor,
                borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(14))),
            ),
            Expanded(child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    if (notice.isPinned) ...[
                      const Padding(
                        padding: EdgeInsets.only(top: 1.5),
                        child: Icon(Icons.push_pin_rounded,
                            size: 12, color: AppTheme.accent)),
                      const SizedBox(width: 3),
                    ],
                    Expanded(child: Text(notice.title,
                        style: AppTheme.heading3.copyWith(fontSize: 13),
                        maxLines: 2, overflow: TextOverflow.ellipsis)),
                    if (notice.isImportant) ...[
                      const SizedBox(width: 4),
                      _badge('IMPORTANT', AppTheme.danger),
                    ],
                    if (notice.requiresAcknowledgement &&
                        !notice.isAcknowledgedBy(user.uid)) ...[
                      const SizedBox(width: 4),
                      _badge('ACK', AppTheme.accent),
                    ],
                  ]),
                  const SizedBox(height: 4),
                  Text(notice.description, style: AppTheme.bodyMuted,
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  Row(children: [
                    _miniTag(notice.category, AppTheme.primary),
                    const SizedBox(width: 4),
                    _miniTag(notice.priority.label, _pColor),
                    if (notice.expiringSoon) ...[
                      const SizedBox(width: 4),
                      _miniTag('⏱ ${_timeLeft(notice.expiresAt!)}',
                          const Color(0xFFF57C00)),
                    ],
                    const Spacer(),
                    GestureDetector(
                      onTap: () => _addToCalendar(context),
                      child: const Padding(
                        padding: EdgeInsets.all(3),
                        child: Icon(Icons.calendar_today_rounded,
                            size: 15, color: Color(0xFF1565C0)))),
                    const SizedBox(width: 5),
                    Icon(
                      notice.isReadBy(user.uid)
                          ? Icons.done_all_rounded : Icons.done_rounded,
                      size: 15,
                      color: notice.isReadBy(user.uid)
                          ? AppTheme.success : AppTheme.textMuted),
                  ]),
                ],
              ),
            )),
          ]),
        ),
      ),
    );
  }

  String _timeLeft(DateTime exp) {
    final diff = exp.difference(DateTime.now());
    if (diff.inHours > 0) return '${diff.inHours}h left';
    return '${diff.inMinutes}m left';
  }

  Future<void> _addToCalendar(BuildContext context) async {
    if (!calendar.isAuthorized) {
      await calendar.requestAuthorization(context);
    }
    if (!calendar.isAuthorized) return;
    final result = await calendar.addNoticeToCalendar(notice);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result.message),
        backgroundColor:
            result.success ? AppTheme.success : AppTheme.danger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10))));
    }
  }

  Widget _badge(String t, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
    decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(4)),
    child: Text(t, style: AppTheme.label.copyWith(
        color: Colors.white, fontSize: 8)));

  Widget _miniTag(String t, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
        color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(5)),
    child: Text(t, style: AppTheme.label.copyWith(color: c, fontSize: 10)));

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.65, maxChildSize: 0.95,
        builder: (_, ctrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: ListView(controller: ctrl,
            padding: const EdgeInsets.all(24),
            children: [
              Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: const Color(0xFFDDE3F0),
                    borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              Text(notice.title, style: AppTheme.heading1),
              const SizedBox(height: 10),
              Wrap(spacing: 6, runSpacing: 6, children: [
                _miniTag(notice.category, AppTheme.primary),
                _miniTag(notice.priority.label, _pColor),
                if (notice.expiresAt != null)
                  _miniTag(
                    'Expires ${DateFormat('MMM dd, hh:mm a').format(notice.expiresAt!)}',
                    const Color(0xFFF57C00)),
              ]),
              const Divider(height: 28),
              Text(notice.description,
                  style: AppTheme.body.copyWith(fontSize: 15, height: 1.8)),
              const SizedBox(height: 20),
              Row(children: [
                const Icon(Icons.done_all_rounded, size: 15,
                    color: AppTheme.success),
                const SizedBox(width: 6),
                Text('${notice.readBy.length} student'
                    '${notice.readBy.length == 1 ? '' : 's'} read this',
                    style: AppTheme.bodyMuted.copyWith(fontSize: 12)),
              ]),
              if (notice.requiresAcknowledgement &&
                  !notice.isAcknowledgedBy(user.uid)) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.accent.withOpacity(0.3))),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Action Required',
                          style: AppTheme.heading3.copyWith(
                              color: AppTheme.accent)),
                      const SizedBox(height: 4),
                      Text(
                        'This notice requires your acknowledgement. '
                        'Tap below to confirm you have read and understood it.',
                        style: AppTheme.bodyMuted.copyWith(fontSize: 12)),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        onPressed: () async {
                          await context.read<FirestoreService>()
                              .acknowledgeNotice(notice.id, user.uid);
                          if (context.mounted) Navigator.pop(context);
                        },
                        icon: const Icon(Icons.verified_rounded, size: 18),
                        label: const Text('I Acknowledge This Notice'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accent,
                          minimumSize: const Size(double.infinity, 46)),
                      ),
                    ],
                  ),
                ),
              ],
              if (notice.requiresAcknowledgement &&
                  notice.isAcknowledgedBy(user.uid)) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.success.withOpacity(0.25))),
                  child: Row(children: [
                    const Icon(Icons.verified_rounded,
                        color: AppTheme.success, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text('You have acknowledged this notice.',
                        style: AppTheme.body.copyWith(
                            color: AppTheme.success,
                            fontWeight: FontWeight.w600))),
                  ]),
                ),
              ],
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => _addToCalendar(context),
                icon: const Icon(Icons.calendar_today_rounded, size: 16),
                label: const Text('Add to Calendar'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1565C0),
                  side: const BorderSide(color: Color(0xFF1565C0)),
                  minimumSize: const Size(double.infinity, 46),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close')),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Events Feed ───────────────────────────────────────────────────────────────
class _EventsFeed extends StatelessWidget {
  final UserModel user;
  const _EventsFeed({required this.user});

  @override
  Widget build(BuildContext context) {
    final fs = context.read<FirestoreService>();
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: fs.getUpcomingEvents(),
      builder: (_, snap) {
        if (!snap.hasData) return const Center(
            child: CircularProgressIndicator());
        final events = snap.data!;
        if (events.isEmpty) return Center(child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy_rounded, size: 52,
                color: AppTheme.textMuted.withOpacity(0.2)),
            const SizedBox(height: 12),
            Text('No upcoming events', style: AppTheme.bodyMuted),
          ],
        ));
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: events.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final e     = events[i];
            final date  = (e['eventDate'] as dynamic).toDate() as DateTime;
            final rsvpd = (e['rsvpUsers'] as List? ?? []).contains(user.uid);
            final hasPdf = e['pdfUrl'] != null;
            return GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => EventDetailScreen(
                      event: e, userId: user.uid))),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                          width: 46, height: 46,
                          decoration: BoxDecoration(
                            color: AppTheme.accent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12)),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(DateFormat('dd').format(date),
                                  style: AppTheme.heading3.copyWith(
                                      color: AppTheme.accent)),
                              Text(DateFormat('MMM').format(date),
                                  style: AppTheme.label.copyWith(
                                      color: AppTheme.accent, fontSize: 9)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(e['title'] ?? '', style: AppTheme.heading3),
                            if ((e['venue'] ?? '').isNotEmpty)
                              Text(e['venue'], style: AppTheme.bodyMuted),
                            if ((e['organizer'] ?? '').isNotEmpty)
                              Text(e['organizer'],
                                  style: AppTheme.bodyMuted.copyWith(
                                      fontSize: 11)),
                          ],
                        )),
                        const Icon(Icons.chevron_right_rounded,
                            color: AppTheme.textMuted),
                      ]),
                      const SizedBox(height: 10),
                      Row(children: [
                        Text('${e['rsvpCount'] ?? 0} going',
                            style: AppTheme.body.copyWith(
                                color: AppTheme.success,
                                fontWeight: FontWeight.w600)),
                        if (hasPdf) ...[
                          const SizedBox(width: 8),
                          _miniTag('📎 PDF', AppTheme.danger),
                        ],
                        const Spacer(),
                        rsvpd
                            ? _miniTag('✅ Going', AppTheme.success)
                            : Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 5),
                                decoration: BoxDecoration(
                                  color: AppTheme.accent,
                                  borderRadius: BorderRadius.circular(8)),
                                child: const Text('RSVP',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12))),
                      ]),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _miniTag(String t, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
        color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(5)),
    child: Text(t, style: AppTheme.label.copyWith(color: c, fontSize: 10)));
}

// ── Pending Tab ───────────────────────────────────────────────────────────────
class _PendingTab extends StatelessWidget {
  final UserModel user;
  const _PendingTab({required this.user});

  @override
  Widget build(BuildContext context) {
    final fs = context.read<FirestoreService>();
    return StreamBuilder<List<NoticeModel>>(
      stream: fs.getFilteredNotices(user),
      builder: (_, snap) {
        if (!snap.hasData) return const Center(
            child: CircularProgressIndicator());
        final pending = snap.data!.where((n) =>
            n.requiresAcknowledgement &&
            !n.isAcknowledgedBy(user.uid)).toList();

        if (pending.isEmpty) return Center(child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline_rounded,
                size: 56, color: AppTheme.success),
            const SizedBox(height: 16),
            Text('All caught up!',
                style: AppTheme.heading2.copyWith(color: AppTheme.success)),
            const SizedBox(height: 8),
            Text('No pending acknowledgements.',
                style: AppTheme.bodyMuted),
          ],
        ));

        return Column(children: [
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.accent.withOpacity(0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.accent.withOpacity(0.3))),
            child: Row(children: [
              const Icon(Icons.pending_actions_rounded,
                  color: AppTheme.accent, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(
                '${pending.length} notice'
                '${pending.length == 1 ? '' : 's'} '
                'require your acknowledgement.',
                style: AppTheme.body.copyWith(fontWeight: FontWeight.w600))),
            ]),
          ),
          Expanded(child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            itemCount: pending.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final n = pending[i];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(n.title, style: AppTheme.heading3),
                      const SizedBox(height: 6),
                      Text(n.description, style: AppTheme.bodyMuted,
                          maxLines: 3, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () async {
                          await fs.acknowledgeNotice(n.id, user.uid);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Notice acknowledged!'),
                                backgroundColor: AppTheme.success,
                                behavior: SnackBarBehavior.floating));
                          }
                        },
                        icon: const Icon(Icons.verified_rounded, size: 16),
                        label: const Text('I Acknowledge This'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accent,
                          minimumSize: const Size(double.infinity, 44)),
                      ),
                    ],
                  ),
                ),
              );
            },
          )),
        ]);
      },
    );
  }
}

// ── Profile Tab ───────────────────────────────────────────────────────────────
class _ProfileTab extends StatelessWidget {
  final UserModel user;
  final VoidCallback onSignOut;
  const _ProfileTab({required this.user, required this.onSignOut});

  @override
  Widget build(BuildContext context) {
    final u = user;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Center(child: Column(children: [
          Container(
            width: 74, height: 74,
            decoration: BoxDecoration(
                color: AppTheme.deptColor(u.department),
                borderRadius: BorderRadius.circular(22)),
            child: Center(child: Text(
              u.name.split(' ').map((w) => w[0]).take(2).join(),
              style: const TextStyle(color: Colors.white,
                  fontWeight: FontWeight.w800, fontSize: 26))),
          ),
          const SizedBox(height: 12),
          Text(u.name, style: AppTheme.heading2),
          Text(u.email, style: AppTheme.bodyMuted),
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: [
            _chip(u.department, AppTheme.deptColor(u.department)),
            _chip(u.year, AppTheme.yearColor(u.year)),
            if (u.committee != null)
              _chip('⭐ ${u.committee}', AppTheme.purple),
          ]),
        ])),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 12),
        _row('Roll Number', u.rollNumber ?? '—'),
        _row('Phone', u.phone ?? '—'),
        _row('Department', AppTheme.deptFullName(u.department)),
        _row('Year', '${u.year} Engineering'),
        _row('Role', u.role == 'committee' ? 'Committee Member' : 'Student'),
        const SizedBox(height: 28),
        OutlinedButton.icon(
          onPressed: onSignOut,
          icon: const Icon(Icons.logout_rounded, color: AppTheme.danger),
          label: const Text('Sign Out'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.danger,
            side: const BorderSide(color: AppTheme.danger),
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14))),
        ),
      ],
    );
  }

  Widget _row(String l, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(children: [
      Text(l, style: AppTheme.bodyMuted),
      const Spacer(),
      Text(v, style: AppTheme.body.copyWith(fontWeight: FontWeight.w600)),
    ]),
  );

  Widget _chip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20)),
    child: Text(label,
        style: AppTheme.label.copyWith(color: color, fontSize: 11)));
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip(
      {required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? AppTheme.primary : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected ? AppTheme.primary : const Color(0xFFDDE3F0),
          width: 1.5)),
      child: Text(label, style: AppTheme.label.copyWith(
        color: selected ? Colors.white : AppTheme.textMuted,
        fontWeight: FontWeight.w600)),
    ),
  );
}
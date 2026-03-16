// lib/screens/admin/admin_dashboard_screen.dart
// Seed Database option removed. Read receipt count shown on each notice.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/notice_model.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';
import '../../services/auth_service.dart';
import '../../utils/app_theme.dart';
import '../login_screen.dart';
import 'add_student_screen.dart';
import 'add_notice_screen.dart';
import 'add_event_screen.dart';
import 'notice_analytics_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});
  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  String _deptFilter = 'All';
  String _yearFilter = 'All';
  final _searchCtrl  = TextEditingController();
  String _searchQuery = '';

  static const _depts = ['All','IT','CS','EXTC','MECH','AIDS','CHEMICAL'];
  static const _years = ['All','FE','SE','TE','BE'];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _tabs.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _signOut() async {
    await context.read<AuthService>().signOut();
    if (!mounted) return;
    Navigator.pushReplacement(context,
        MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  void _showStats() async {
    final stats = await context.read<FirestoreService>().getStudentStats();
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Student Statistics', style: AppTheme.heading2),
            const SizedBox(height: 16),
            _statRow('Total Students', stats['total'] ?? 0),
            const Divider(),
            Text('By Department', style: AppTheme.heading3),
            for (final d in ['IT','CS','EXTC','MECH','AIDS','CHEMICAL'])
              _statRow(d, stats[d] ?? 0, color: AppTheme.deptColor(d)),
            const Divider(),
            Text('By Year', style: AppTheme.heading3),
            for (final y in ['FE','SE','TE','BE'])
              _statRow(y, stats[y] ?? 0, color: AppTheme.yearColor(y)),
            const Divider(),
            _statRow('Committee Members', stats['committee'] ?? 0,
                color: AppTheme.purple),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _statRow(String label, int count, {Color? color}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(children: [
      if (color != null) ...[
        Container(width: 10, height: 10,
            decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 8),
      ],
      Text(label, style: AppTheme.body),
      const Spacer(),
      Text(count.toString(),
          style: AppTheme.heading3.copyWith(
              color: color ?? AppTheme.primary)),
    ]),
  );

  Stream<List<UserModel>> get _studentsStream {
    final fs = context.read<FirestoreService>();
    if (_deptFilter == 'All' && _yearFilter == 'All')
      return fs.getAllStudents();
    if (_deptFilter != 'All' && _yearFilter == 'All')
      return fs.getStudentsByDept(_deptFilter);
    if (_deptFilter == 'All' && _yearFilter != 'All')
      return fs.getStudentsByYear(_yearFilter);
    return fs.getStudentsByDeptAndYear(_deptFilter, _yearFilter);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded, color: Colors.white),
            tooltip: 'Statistics',
            onPressed: _showStats),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
            onSelected: (v) {
              if (v == 'signout') _signOut();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'signout',
                  child: Text('Sign Out')),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(
              fontWeight: FontWeight.w700, fontSize: 12),
          tabs: const [
            Tab(text: 'Students'),
            Tab(text: 'Notices'),
            Tab(text: 'Events'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (_tabs.index == 0) {
            Navigator.push(context, MaterialPageRoute(
                builder: (_) => const AddStudentScreen()));
          } else if (_tabs.index == 1) {
            Navigator.push(context, MaterialPageRoute(
                builder: (_) => const AddNoticeScreen()));
          } else {
            Navigator.push(context, MaterialPageRoute(
                builder: (_) => const AddEventScreen()));
          }
        },
        backgroundColor: AppTheme.accent,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          _tabs.index == 0 ? 'Add Student'
          : _tabs.index == 1 ? 'Add Notice'
          : 'Add Event',
          style: const TextStyle(color: Colors.white,
              fontWeight: FontWeight.w700)),
      ),
      body: TabBarView(controller: _tabs, children: [
        _StudentsTab(stream: _studentsStream,
          deptFilter: _deptFilter, yearFilter: _yearFilter,
          searchQuery: _searchQuery, searchCtrl: _searchCtrl,
          onDeptFilter: (v) => setState(() => _deptFilter = v),
          onYearFilter: (v) => setState(() => _yearFilter = v),
          onSearch: (v) => setState(() => _searchQuery = v),
          depts: _depts, years: _years),
        const _NoticesTab(),
        const _EventsTab(),
      ]),
    );
  }
}

// ── Students Tab ──────────────────────────────────────────────────────────────
class _StudentsTab extends StatelessWidget {
  final Stream<List<UserModel>> stream;
  final String deptFilter, yearFilter, searchQuery;
  final TextEditingController searchCtrl;
  final ValueChanged<String> onDeptFilter, onYearFilter, onSearch;
  final List<String> depts, years;

  const _StudentsTab({
    required this.stream,
    required this.deptFilter, required this.yearFilter,
    required this.searchQuery, required this.searchCtrl,
    required this.onDeptFilter, required this.onYearFilter,
    required this.onSearch,
    required this.depts, required this.years});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Search
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
        child: TextField(
          controller: searchCtrl,
          onChanged: onSearch,
          decoration: const InputDecoration(
            hintText: 'Search name, email, roll number…',
            prefixIcon: Icon(Icons.search_rounded,
                color: AppTheme.textMuted),
            isDense: true),
        ),
      ),
      // Dept chips
      SizedBox(height: 42,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 6),
          children: depts.map((d) {
            final sel = deptFilter == d;
            return GestureDetector(
              onTap: () => onDeptFilter(d),
              child: Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: sel
                      ? (d == 'All' ? AppTheme.primary
                          : AppTheme.deptColor(d))
                      : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: sel
                        ? (d == 'All' ? AppTheme.primary
                            : AppTheme.deptColor(d))
                        : const Color(0xFFDDE3F0))),
                child: Text(d, style: AppTheme.label.copyWith(
                  color: sel ? Colors.white : AppTheme.textMuted,
                  fontWeight: FontWeight.w700)),
              ),
            );
          }).toList()),
      ),
      // Year chips
      SizedBox(height: 42,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 6),
          children: years.map((y) {
            final sel = yearFilter == y;
            return GestureDetector(
              onTap: () => onYearFilter(y),
              child: Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: sel
                      ? (y == 'All' ? AppTheme.primary
                          : AppTheme.yearColor(y))
                      : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: sel
                        ? (y == 'All' ? AppTheme.primary
                            : AppTheme.yearColor(y))
                        : const Color(0xFFDDE3F0))),
                child: Text(y, style: AppTheme.label.copyWith(
                  color: sel ? Colors.white : AppTheme.textMuted,
                  fontWeight: FontWeight.w700)),
              ),
            );
          }).toList()),
      ),
      Expanded(child: StreamBuilder<List<UserModel>>(
        stream: stream,
        builder: (ctx, snap) {
          if (!snap.hasData) return const Center(
              child: CircularProgressIndicator());
          var students = snap.data!;
          if (searchQuery.isNotEmpty) {
            final q = searchQuery.toLowerCase();
            students = students.where((s) =>
                s.name.toLowerCase().contains(q) ||
                s.email.toLowerCase().contains(q) ||
                (s.rollNumber?.toLowerCase().contains(q) ?? false)
            ).toList();
          }
          if (students.isEmpty) return Center(
              child: Text('No students found',
                  style: AppTheme.bodyMuted));
          return Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 4),
              child: Row(children: [
                Text('${students.length} student'
                    '${students.length == 1 ? '' : 's'}',
                    style: AppTheme.bodyMuted.copyWith(fontSize: 12)),
              ]),
            ),
            Expanded(child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
              itemCount: students.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (_, i) =>
                  _StudentCard(student: students[i]),
            )),
          ]);
        },
      )),
    ]);
  }
}

class _StudentCard extends StatelessWidget {
  final UserModel student;
  const _StudentCard({required this.student});
  @override
  Widget build(BuildContext context) {
    final s = student;
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 6),
        leading: Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: AppTheme.deptColor(s.department),
            borderRadius: BorderRadius.circular(12)),
          child: Center(child: Text(
            s.name.split(' ').map((w) => w[0]).take(2).join(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 14))),
        ),
        title: Text(s.name, style: AppTheme.body.copyWith(
            fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${s.rollNumber ?? s.email}  ·  '
          '${s.department} ${s.year}'
          '${s.committee != null ? '  ·  ${s.committee}' : ''}',
          style: AppTheme.bodyMuted.copyWith(fontSize: 11)),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded,
              color: AppTheme.textMuted),
          onSelected: (v) async {
            final fs = context.read<FirestoreService>();
            if (v == 'deactivate') {
              await fs.deactivateStudent(s.uid);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${s.name} deactivated'),
                    backgroundColor: AppTheme.danger,
                    behavior: SnackBarBehavior.floating));
              }
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'deactivate',
                child: Text('Deactivate')),
          ],
        ),
      ),
    );
  }
}

// ── Notices Tab ───────────────────────────────────────────────────────────────
class _NoticesTab extends StatelessWidget {
  const _NoticesTab();
  @override
  Widget build(BuildContext context) {
    final fs = context.read<FirestoreService>();
    return StreamBuilder<List<NoticeModel>>(
      stream: fs.getAllNotices(),
      builder: (_, snap) {
        if (!snap.hasData) return const Center(
            child: CircularProgressIndicator());
        final notices = snap.data!;
        if (notices.isEmpty) return Center(
            child: Text('No notices yet',
                style: AppTheme.bodyMuted));
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
          itemCount: notices.length,
          separatorBuilder: (_, __) => const SizedBox(height: 6),
          itemBuilder: (_, i) =>
              _AdminNoticeCard(notice: notices[i]),
        );
      },
    );
  }
}

class _AdminNoticeCard extends StatelessWidget {
  final NoticeModel notice;
  const _AdminNoticeCard({required this.notice});

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
    final fs = context.read<FirestoreService>();
    final expired = notice.isExpired;
    return Opacity(
      opacity: expired ? 0.55 : 1.0,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(child: Text(notice.title,
                    style: AppTheme.heading3.copyWith(
                      decoration: expired
                          ? TextDecoration.lineThrough : null))),
                if (expired)
                  _tag('EXPIRED', AppTheme.textMuted),
              ]),
              const SizedBox(height: 6),
              Text(notice.description,
                  style: AppTheme.bodyMuted,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 4, children: [
                _tag(notice.category, AppTheme.primary),
                _tag(notice.priority.label, _pColor),
                _tag(_visLabel(notice), const Color(0xFF1565C0)),
                if (notice.isImportant) _tag('IMPORTANT', AppTheme.danger),
                if (notice.isPinned) _tag('PINNED', AppTheme.accent),
                if (notice.expiresAt != null && !expired)
                  _tag('Expires ${DateFormat('MMM dd').format(notice.expiresAt!)}',
                      const Color(0xFFF57C00)),
                // Read receipt count
                _tag('👁 ${notice.readBy.length} read',
                    AppTheme.success),
              ]),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) =>
                            NoticeAnalyticsScreen(notice: notice))),
                    icon: const Icon(Icons.bar_chart_rounded, size: 15),
                    label: const Text('Analytics'),
                    style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF00695C))),
                  TextButton.icon(
                    onPressed: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) =>
                            AddNoticeScreen(existing: notice))),
                    icon: const Icon(Icons.edit_rounded, size: 15),
                    label: const Text('Edit'),
                    style: TextButton.styleFrom(
                        foregroundColor: AppTheme.primary)),
                  const SizedBox(width: 4),
                  TextButton.icon(
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Delete Notice'),
                          content: Text(
                              'Delete "${notice.title}"?'),
                          actions: [
                            TextButton(
                                onPressed: () =>
                                    Navigator.pop(context, false),
                                child: const Text('Cancel')),
                            TextButton(
                                onPressed: () =>
                                    Navigator.pop(context, true),
                                child: const Text('Delete',
                                    style: TextStyle(
                                        color: AppTheme.danger))),
                          ],
                        ),
                      );
                      if (ok == true) {
                        await fs.deleteNotice(notice.id);
                      }
                    },
                    icon: const Icon(Icons.delete_outline_rounded,
                        size: 15),
                    label: const Text('Delete'),
                    style: TextButton.styleFrom(
                        foregroundColor: AppTheme.danger)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _visLabel(NoticeModel n) {
    switch (n.visibility) {
      case 'all':        return 'All Students';
      case 'department': return '${n.targetDepartment} Only';
      case 'year':       return '${n.targetYear} Only';
      case 'committee':  return '${n.targetCommittee} Committee';
      case 'specific':   return '${n.targetStudentUids.length} Students';
      default:           return n.visibility;
    }
  }

  Widget _tag(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(5)),
    child: Text(text, style: AppTheme.label.copyWith(
        color: color, fontSize: 10)),
  );
}

// ── Events Tab ────────────────────────────────────────────────────────────────
class _EventsTab extends StatelessWidget {
  const _EventsTab();
  @override
  Widget build(BuildContext context) {
    final fs = context.read<FirestoreService>();
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: fs.getUpcomingEvents(),
      builder: (_, snap) {
        if (!snap.hasData) return const Center(
            child: CircularProgressIndicator());
        final events = snap.data!;
        if (events.isEmpty) return Center(
            child: Text('No events yet',
                style: AppTheme.bodyMuted));
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
          itemCount: events.length,
          separatorBuilder: (_, __) => const SizedBox(height: 6),
          itemBuilder: (_, i) {
            final e = events[i];
            final date = (e['eventDate'] as dynamic).toDate();
            return Card(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                leading: Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(DateFormat('dd').format(date),
                          style: AppTheme.heading3.copyWith(
                              color: AppTheme.accent, fontSize: 15)),
                      Text(DateFormat('MMM').format(date),
                          style: AppTheme.label.copyWith(
                              color: AppTheme.accent, fontSize: 9)),
                    ],
                  ),
                ),
                title: Text(e['title'] ?? '',
                    style: AppTheme.body.copyWith(
                        fontWeight: FontWeight.w600)),
                subtitle: Text(
                  '${e['venue'] ?? ''}  ·  '
                  '${e['rsvpCount'] ?? 0} RSVP',
                  style: AppTheme.bodyMuted.copyWith(fontSize: 11)),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline_rounded,
                      color: AppTheme.danger),
                  onPressed: () => fs.deleteEvent(e['id']),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/notice_model.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';
import '../../utils/app_theme.dart';

class NoticeAnalyticsScreen extends StatefulWidget {
  final NoticeModel notice;
  const NoticeAnalyticsScreen({super.key, required this.notice});
  @override
  State<NoticeAnalyticsScreen> createState() => _NoticeAnalyticsScreenState();
}

class _NoticeAnalyticsScreenState extends State<NoticeAnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<UserModel> _recipients = [];
  bool _loading = true;
  bool _sendingNudge = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _loadRecipients();
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _loadRecipients() async {
    final fs = context.read<FirestoreService>();
    List<UserModel> students;

    switch (widget.notice.visibility) {
      case 'all':
        students = await fs.getAllStudentsOnce();
        break;
      case 'department':
        students = (await fs.getAllStudentsOnce())
            .where((s) =>
                s.department == widget.notice.targetDepartment).toList();
        break;
      case 'year':
        students = (await fs.getAllStudentsOnce())
            .where((s) => s.year == widget.notice.targetYear).toList();
        break;
      case 'committee':
        students = (await fs.getAllStudentsOnce())
            .where((s) =>
                s.committee == widget.notice.targetCommittee).toList();
        break;
      case 'specific':
        final all = await fs.getAllStudentsOnce();
        students = all
            .where((s) =>
                widget.notice.targetStudentUids.contains(s.uid)).toList();
        break;
      default:
        students = [];
    }

    setState(() { _recipients = students; _loading = false; });
  }

  List<UserModel> get _read =>
      _recipients.where((s) => widget.notice.isReadBy(s.uid)).toList();

  List<UserModel> get _unread =>
      _recipients.where((s) => !widget.notice.isReadBy(s.uid)).toList();

  List<UserModel> get _acknowledged =>
      _recipients.where((s) =>
          widget.notice.isAcknowledgedBy(s.uid)).toList();

  List<UserModel> get _notAcknowledged =>
      _recipients.where((s) =>
          !widget.notice.isAcknowledgedBy(s.uid)).toList();

  double get _readPct => _recipients.isEmpty
      ? 0 : _read.length / _recipients.length;

  double get _ackPct => _recipients.isEmpty
      ? 0 : _acknowledged.length / _recipients.length;

  Future<void> _sendNudge() async {
    final targets = widget.notice.requiresAcknowledgement
        ? _notAcknowledged : _unread;
    if (targets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Everyone has already read this notice!'),
        backgroundColor: AppTheme.success,
        behavior: SnackBarBehavior.floating));
      return;
    }

    setState(() => _sendingNudge = true);
    final fs   = context.read<FirestoreService>();
    final uids = targets.map((s) => s.uid).toList();
    await fs.sendNudge(widget.notice.id, uids);
    setState(() => _sendingNudge = false);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
          'Nudge sent to ${targets.length} student'
          '${targets.length == 1 ? '' : 's'}!'),
      backgroundColor: AppTheme.success,
      behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.notice;
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(title: const Text('Notice Analytics')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [

              // ── Stats cards ────────────────────────────────────────────
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(n.title,
                        style: AppTheme.heading3,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 16),
                    Row(children: [
                      _StatCard(
                        label: 'Recipients',
                        value: _recipients.length.toString(),
                        icon: Icons.people_outline_rounded,
                        color: AppTheme.primary),
                      const SizedBox(width: 10),
                      _StatCard(
                        label: 'Opened',
                        value: '${(_readPct * 100).toStringAsFixed(0)}%',
                        sub: '${_read.length} of ${_recipients.length}',
                        icon: Icons.visibility_rounded,
                        color: const Color(0xFF1565C0)),
                      if (n.requiresAcknowledgement) ...[
                        const SizedBox(width: 10),
                        _StatCard(
                          label: 'Confirmed',
                          value: '${(_ackPct * 100).toStringAsFixed(0)}%',
                          sub: '${_acknowledged.length} of ${_recipients.length}',
                          icon: Icons.verified_rounded,
                          color: AppTheme.success),
                      ],
                    ]),
                    const SizedBox(height: 16),
                    // Progress bar
                    Column(children: [
                      Row(children: [
                        Text('Read rate', style: AppTheme.bodyMuted.copyWith(fontSize: 12)),
                        const Spacer(),
                        Text('${(_readPct * 100).toStringAsFixed(0)}%',
                            style: AppTheme.label.copyWith(
                                color: const Color(0xFF1565C0))),
                      ]),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _readPct,
                          backgroundColor: const Color(0xFFE3EAF8),
                          color: const Color(0xFF1565C0),
                          minHeight: 8)),
                      if (n.requiresAcknowledgement) ...[
                        const SizedBox(height: 10),
                        Row(children: [
                          Text('Acknowledgement rate',
                              style: AppTheme.bodyMuted.copyWith(fontSize: 12)),
                          const Spacer(),
                          Text('${(_ackPct * 100).toStringAsFixed(0)}%',
                              style: AppTheme.label.copyWith(
                                  color: AppTheme.success)),
                        ]),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: _ackPct,
                            backgroundColor: const Color(0xFFE0F2F1),
                            color: AppTheme.success,
                            minHeight: 8)),
                      ],
                    ]),
                    const SizedBox(height: 16),
                    // Nudge button
                    OutlinedButton.icon(
                      onPressed: _sendingNudge ? null : _sendNudge,
                      icon: _sendingNudge
                          ? const SizedBox(width: 16, height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2))
                          : const Icon(Icons.notifications_active_rounded,
                              size: 18),
                      label: Text(_sendingNudge ? 'Sending…'
                          : n.requiresAcknowledgement
                              ? 'Nudge unconfirmed (${_notAcknowledged.length})'
                              : 'Nudge unread (${_unread.length})'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.accent,
                        side: const BorderSide(color: AppTheme.accent),
                        minimumSize: const Size(double.infinity, 46),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12))),
                    ),
                  ],
                ),
              ),

              // ── Tabs: Read | Not Read ──────────────────────────────────
              Container(
                color: Colors.white,
                child: TabBar(
                  controller: _tabs,
                  indicatorColor: AppTheme.primary,
                  labelColor: AppTheme.primary,
                  unselectedLabelColor: AppTheme.textMuted,
                  tabs: [
                    Tab(text: 'Read (${_read.length})'),
                    Tab(text: 'Not Read (${_unread.length})'),
                  ],
                ),
              ),

              Expanded(child: TabBarView(
                controller: _tabs,
                children: [
                  _StudentList(students: _read, acknowledged: true,
                      notice: n),
                  _StudentList(students: _unread, acknowledged: false,
                      notice: n),
                ],
              )),
            ]),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final String? sub;
  final IconData icon;
  final Color color;
  const _StatCard({
    required this.label, required this.value,
    this.sub, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withOpacity(0.06),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withOpacity(0.2))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 18, color: color),
      const SizedBox(height: 6),
      Text(value, style: AppTheme.heading2.copyWith(
          color: color, fontSize: 20)),
      if (sub != null)
        Text(sub!, style: AppTheme.bodyMuted.copyWith(fontSize: 10)),
      Text(label, style: AppTheme.bodyMuted.copyWith(fontSize: 11)),
    ]),
  ));
}

class _StudentList extends StatelessWidget {
  final List<UserModel> students;
  final bool acknowledged;
  final NoticeModel notice;
  const _StudentList({
    required this.students,
    required this.acknowledged,
    required this.notice});

  @override
  Widget build(BuildContext context) {
    if (students.isEmpty) return Center(child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          acknowledged
              ? Icons.done_all_rounded : Icons.mark_email_unread_outlined,
          size: 48,
          color: AppTheme.textMuted.withOpacity(0.3)),
        const SizedBox(height: 12),
        Text(
          acknowledged ? 'Everyone has read this!' : 'All students have read this.',
          style: AppTheme.bodyMuted),
      ],
    ));

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: students.length,
      itemBuilder: (_, i) {
        final s = students[i];
        final ackd = notice.isAcknowledgedBy(s.uid);
        return ListTile(
          leading: Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: AppTheme.deptColor(s.department),
              borderRadius: BorderRadius.circular(10)),
            child: Center(child: Text(
              s.name.split(' ').map((w) => w[0]).take(2).join(),
              style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w800,
                fontSize: 12))),
          ),
          title: Text(s.name, style: AppTheme.body.copyWith(
              fontWeight: FontWeight.w600)),
          subtitle: Text(
            '${s.department} ${s.year}'
            '${s.rollNumber != null ? '  ·  ${s.rollNumber}' : ''}',
            style: AppTheme.bodyMuted.copyWith(fontSize: 11)),
          trailing: notice.requiresAcknowledgement
              ? Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: ackd
                        ? AppTheme.success.withOpacity(0.1)
                        : AppTheme.danger.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6)),
                  child: Text(
                    ackd ? '✓ Confirmed' : 'Pending',
                    style: AppTheme.label.copyWith(
                      color: ackd ? AppTheme.success : AppTheme.danger,
                      fontSize: 10)))
              : Icon(Icons.done_all_rounded,
                  size: 16,
                  color: acknowledged ? AppTheme.success : AppTheme.textMuted),
        );
      },
    );
  }
}
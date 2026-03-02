// lib/screens/student/student_home_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/notice_model.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';
import '../../services/auth_service.dart';
import '../../utils/app_theme.dart';
import '../splash_screen.dart';

class StudentHomeScreen extends StatefulWidget {
  final UserModel user;
  const StudentHomeScreen({super.key, required this.user});
  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  String _filter = 'All';

  Future<void> _signOut() async {
    await context.read<AuthService>().signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context,
      MaterialPageRoute(builder: (_) => const RoleSelectScreen()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final fs = context.read<FirestoreService>();
    final u = widget.user;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: CustomScrollView(
        slivers: [
          // ── Header ──────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            backgroundColor: AppTheme.primary,
            actions: [
              IconButton(
                icon: const Icon(Icons.logout_rounded, color: Colors.white),
                onPressed: _signOut,
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0D1B6E), Color(0xFF1A237E)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(20, 80, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Hello, ${u.name.split(' ').first} 👋',
                      style: AppTheme.heading2.copyWith(color: Colors.white)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _InfoChip(u.department,
                          AppTheme.deptColor(u.department)),
                        const SizedBox(width: 8),
                        _InfoChip(u.role == 'committee'
                          ? '⭐ ${u.committee ?? 'Committee'}' : '👤 Student',
                          u.role == 'committee'
                            ? AppTheme.colorEXTC : Colors.white30),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Filter Chips ─────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['All', 'Important', 'General',
                    u.department, if (u.committee != null) u.committee!]
                      .map((f) {
                        final sel = _filter == f;
                        return GestureDetector(
                          onTap: () => setState(() => _filter = f),
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: sel ? AppTheme.primary : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: sel ? AppTheme.primary
                                  : const Color(0xFFDDE3F0),
                                width: 1.5,
                              ),
                            ),
                            child: Text(f,
                              style: AppTheme.label.copyWith(
                                color: sel ? Colors.white : AppTheme.textMuted,
                                fontWeight: FontWeight.w600,
                              )),
                          ),
                        );
                      }).toList(),
                ),
              ),
            ),
          ),

          // ── Notices List ──────────────────────────────────────────────────
          StreamBuilder<List<NoticeModel>>(
            stream: fs.getFilteredNotices(u),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()));
              }

              var notices = snap.data ?? [];

              // Apply client-side filter chip
              if (_filter == 'Important') {
                notices = notices.where((n) => n.isImportant).toList();
              } else if (_filter != 'All' && _filter != 'General') {
                notices = notices.where((n) =>
                  n.targetDepartment == _filter ||
                  n.targetCommittee == _filter).toList();
              } else if (_filter == 'General') {
                notices = notices.where((n) => n.visibility == 'all').toList();
              }

              if (notices.isEmpty) {
                return const SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox_rounded, size: 60,
                          color: Color(0xFFCDD1E0)),
                        SizedBox(height: 12),
                        Text('No notices here yet.',
                          style: TextStyle(color: AppTheme.textMuted)),
                      ],
                    ),
                  ),
                );
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 4),
                    child: _StudentNoticeCard(notice: notices[i]),
                  ),
                  childCount: notices.length,
                ),
              );
            },
          ),

          const SliverPadding(padding: EdgeInsets.only(bottom: 20)),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final Color color;
  const _InfoChip(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24, width: 1),
      ),
      child: Text(label,
        style: AppTheme.label.copyWith(color: Colors.white, fontSize: 12)),
    );
  }
}

// ── Student Notice Card ───────────────────────────────────────────────────────
class _StudentNoticeCard extends StatelessWidget {
  final NoticeModel notice;
  const _StudentNoticeCard({required this.notice});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showDetail(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left accent bar
                  Container(
                    width: 4, height: 56,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.visibilityColor(notice.visibility),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(notice.title,
                                style: AppTheme.heading3,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis),
                            ),
                            if (notice.isImportant)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppTheme.important,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text('IMPORTANT',
                                  style: AppTheme.label.copyWith(
                                    color: Colors.white, fontSize: 10)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(notice.description,
                          style: AppTheme.bodyMuted,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _SmallBadge(notice.category, AppTheme.primary),
                  const SizedBox(width: 6),
                  _SmallBadge(
                    notice.visibility == 'all' ? '🌐 General'
                      : notice.visibility == 'department'
                        ? '🏛️ ${notice.targetDepartment}'
                        : '👥 ${notice.targetCommittee}',
                    AppTheme.visibilityColor(notice.visibility),
                  ),
                  const Spacer(),
                  Text(
                    DateFormat('MMM dd').format(notice.createdAt),
                    style: AppTheme.bodyMuted.copyWith(fontSize: 12)),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward_ios_rounded,
                    size: 12, color: AppTheme.textMuted),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NoticeDetailSheet(notice: notice),
    );
  }
}

class _SmallBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _SmallBadge(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
        style: AppTheme.label.copyWith(color: color, fontSize: 11)),
    );
  }
}

// ── Notice Detail Bottom Sheet ────────────────────────────────────────────────
class _NoticeDetailSheet extends StatelessWidget {
  final NoticeModel notice;
  const _NoticeDetailSheet({required this.notice});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: ListView(
          controller: ctrl,
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFDDE3F0),
                  borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            if (notice.isImportant)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppTheme.important.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppTheme.important.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.priority_high_rounded,
                      color: AppTheme.important, size: 18),
                    const SizedBox(width: 8),
                    Text('This is an important notice',
                      style: AppTheme.body.copyWith(
                        color: AppTheme.important,
                        fontWeight: FontWeight.w600,
                      )),
                  ],
                ),
              ),
            Text(notice.title, style: AppTheme.heading2),
            const SizedBox(height: 12),
            Row(
              children: [
                _SmallBadge(notice.category, AppTheme.primary),
                const SizedBox(width: 8),
                Text(
                  DateFormat('MMMM dd, yyyy').format(notice.createdAt),
                  style: AppTheme.bodyMuted.copyWith(fontSize: 13)),
              ],
            ),
            const Divider(height: 32, color: Color(0xFFECEFF9)),
            Text(notice.description,
              style: AppTheme.body.copyWith(
                height: 1.7, fontSize: 15, color: AppTheme.textDark)),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }
}
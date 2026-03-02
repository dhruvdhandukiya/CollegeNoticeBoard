// lib/screens/admin/admin_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/notice_model.dart';
import '../../services/firestore_service.dart';
import '../../services/auth_service.dart';
import '../../utils/app_theme.dart';
import 'add_notice_screen.dart';
import 'add_student_screen.dart';
import '../splash_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});
  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _signOut() async {
    await context.read<AuthService>().signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context,
      MaterialPageRoute(builder: (_) => const RoleSelectScreen()), (_) => false);
  }

  Future<void> _deleteNotice(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Notice?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await context.read<FirestoreService>().deleteNotice(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notice deleted'),
            backgroundColor: AppTheme.danger));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fs = context.read<FirestoreService>();

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        leading: Padding(
          padding: const EdgeInsets.all(10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.school_rounded, size: 22, color: Colors.white),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sign Out',
            onPressed: _signOut,
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: AppTheme.accent,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.campaign_rounded, size: 18), text: 'Notices'),
            Tab(icon: Icon(Icons.people_alt_rounded, size: 18), text: 'Students'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          // ── NOTICES TAB ──────────────────────────────────────────────────
          StreamBuilder<List<NoticeModel>>(
            stream: fs.getAllNotices(),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final notices = snap.data ?? [];
              if (notices.isEmpty) {
                return _EmptyState(
                  icon: Icons.campaign_outlined,
                  message: 'No notices yet.\nTap + to create one.',
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: notices.length,
                separatorBuilder: (_, __) => const SizedBox(height: 0),
                itemBuilder: (_, i) => _AdminNoticeCard(
                  notice: notices[i],
                  onEdit: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) =>
                      AddNoticeScreen(existing: notices[i]))),
                  onDelete: () => _deleteNotice(notices[i].id),
                ),
              );
            },
          ),

          // ── STUDENTS TAB ─────────────────────────────────────────────────
          const _StudentsTab(),
        ],
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _tabs,
        builder: (_, __) {
          final isNoticesTab = _tabs.index == 0;
          return FloatingActionButton.extended(
            onPressed: () {
              if (isNoticesTab) {
                Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AddNoticeScreen()));
              } else {
                Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AddStudentScreen()));
              }
            },
            backgroundColor: AppTheme.accent,
            icon: const Icon(Icons.add_rounded, color: Colors.white),
            label: Text(
              isNoticesTab ? 'Add Notice' : 'Add Student',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          );
        },
      ),
    );
  }
}

// ── Admin Notice Card ─────────────────────────────────────────────────────────
class _AdminNoticeCard extends StatelessWidget {
  final NoticeModel notice;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AdminNoticeCard({
    required this.notice, required this.onEdit, required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(notice.title,
                    style: AppTheme.heading3,
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                ),
                if (notice.isImportant) ...[
                  const SizedBox(width: 8),
                  _Badge('IMPORTANT', AppTheme.important),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _Badge(notice.category, AppTheme.primary),
                const SizedBox(width: 8),
                _VisibilityBadge(notice),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              DateFormat('MMM dd, yyyy').format(notice.createdAt),
              style: AppTheme.bodyMuted.copyWith(fontSize: 12),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Edit'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    side: const BorderSide(color: AppTheme.primary),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded, size: 16),
                  label: const Text('Delete'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.danger,
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Text(label,
        style: AppTheme.label.copyWith(color: color, fontSize: 11)),
    );
  }
}

class _VisibilityBadge extends StatelessWidget {
  final NoticeModel notice;
  const _VisibilityBadge(this.notice);

  @override
  Widget build(BuildContext context) {
    String label;
    Color color;
    if (notice.visibility == 'all') {
      label = '🌐 All'; color = AppTheme.success;
    } else if (notice.visibility == 'department') {
      label = '🏛️ ${notice.targetDepartment}'; color = AppTheme.colorIT;
    } else {
      label = '👥 ${notice.targetCommittee}'; color = AppTheme.colorEXTC;
    }
    return _Badge(label, color);
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: AppTheme.textMuted.withOpacity(0.4)),
          const SizedBox(height: 16),
          Text(message, style: AppTheme.bodyMuted, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ── Students Tab ──────────────────────────────────────────────────────────────
class _StudentsTab extends StatelessWidget {
  const _StudentsTab();

  @override
  Widget build(BuildContext context) {
    final fs = context.read<FirestoreService>();
    return StreamBuilder(
      stream: fs.getAllStudents(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final students = snap.data ?? [];
        if (students.isEmpty) {
          return const _EmptyState(
            icon: Icons.person_outline_rounded,
            message: 'No students added yet.\nTap + to add one.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: students.length,
          separatorBuilder: (_, __) => const SizedBox(height: 0),
          itemBuilder: (_, i) {
            final s = students[i];
            return Card(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
                leading: CircleAvatar(
                  backgroundColor: AppTheme.deptColor(s.department),
                  child: Text(s.name.isNotEmpty ? s.name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700)),
                ),
                title: Text(s.name, style: AppTheme.heading3),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _Badge(s.department, AppTheme.deptColor(s.department)),
                        const SizedBox(width: 6),
                        _Badge(s.role, s.role == 'committee'
                          ? AppTheme.colorEXTC : AppTheme.textMuted),
                        if (s.committee != null) ...[
                          const SizedBox(width: 6),
                          _Badge(s.committee!, AppTheme.colorCS),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(s.email, style: AppTheme.bodyMuted.copyWith(fontSize: 12)),
                  ],
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline_rounded,
                    color: AppTheme.danger),
                  onPressed: () async {
                    await fs.deleteStudent(s.uid);
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}
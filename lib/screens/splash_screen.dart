import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../utils/app_theme.dart';
import 'admin/admin_login_screen.dart';
import 'student/student_login_screen.dart';
import 'student/student_home_screen.dart';
import 'admin/admin_dashboard_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();
    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final auth = context.read<AuthService>();
    final user = auth.currentUser;

    if (user == null) {
      Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => const RoleSelectScreen()),
      );
      return;
    }

    final userModel = await auth.getCurrentUserModel();
    if (userModel == null) {
      Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => const RoleSelectScreen()),
      );
      return;
    }

    if (userModel.role == 'admin') {
      Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => StudentHomeScreen(user: userModel)),
      );
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primary,
      body: FadeTransition(
        opacity: _fade,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 90, height: 90,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white24, width: 1.5),
                ),
                child: const Icon(Icons.school_rounded, size: 48, color: Colors.white),
              ),
              const SizedBox(height: 24),
              Text(
                'College Noticeboard',
                style: AppTheme.heading2.copyWith(color: Colors.white, fontSize: 26),
              ),
              const SizedBox(height: 8),
              Text(
                'Stay informed. Stay ahead.',
                style: AppTheme.bodyMuted.copyWith(color: Colors.white54, fontSize: 14),
              ),
              const SizedBox(height: 48),
              const SizedBox(
                width: 28, height: 28,
                child: CircularProgressIndicator(
                  color: Colors.white54, strokeWidth: 2.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Role Select Screen ────────────────────────────────────────────────────────
class RoleSelectScreen extends StatelessWidget {
  const RoleSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.school_rounded, size: 36, color: AppTheme.primary),
              ),
              const SizedBox(height: 24),
              Text('Welcome to\nCollege Noticeboard', style: AppTheme.heading1),
              const SizedBox(height: 10),
              Text('Choose how you want to sign in', style: AppTheme.bodyMuted),
              const SizedBox(height: 48),
              _RoleCard(
                icon: Icons.person_outline_rounded,
                title: 'Student Login',
                subtitle: 'View notices for your dept & committees',
                color: AppTheme.primary,
                onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const StudentLoginScreen())),
              ),
              const SizedBox(height: 16),
              _RoleCard(
                icon: Icons.admin_panel_settings_outlined,
                title: 'Admin Login',
                subtitle: 'Manage notices, students & roles',
                color: AppTheme.accent,
                onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AdminLoginScreen())),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon, required this.title,
    required this.subtitle, required this.color, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFECEFF9), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.08),
              blurRadius: 20, offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTheme.heading3),
                  const SizedBox(height: 4),
                  Text(subtitle, style: AppTheme.bodyMuted),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 16, color: color),
          ],
        ),
      ),
    );
  }
}



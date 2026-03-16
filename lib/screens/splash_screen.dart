import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../utils/app_theme.dart';
import 'login_screen.dart';
import 'admin/admin_dashboard_screen.dart';
import 'student/student_home_screen.dart';

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
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    final auth = context.read<AuthService>();
    final user = await auth.getCurrentUser();
    if (!mounted) return;
    if (user == null) {
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => const LoginScreen()));
    } else if (user.isAdmin) {
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => const AdminDashboardScreen()));
    } else {
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => StudentHomeScreen(user: user)));
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

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
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(Icons.campaign_rounded,
                    color: Colors.white, size: 44),
              ),
              const SizedBox(height: 20),
              Text('Noticeboard',
                  style: AppTheme.heading1.copyWith(color: Colors.white)),
              const SizedBox(height: 8),
              Text('Stay informed, stay ahead',
                  style: AppTheme.bodyMuted.copyWith(
                      color: Colors.white54)),
              const SizedBox(height: 60),
              const SizedBox(
                width: 24, height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white54, strokeWidth: 2.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
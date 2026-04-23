import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../utils/app_theme.dart';
import 'admin/admin_dashboard_screen.dart';
import 'student/student_home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey    = GlobalKey<FormState>();
  final _emailCtrl  = TextEditingController();
  final _passCtrl   = TextEditingController();
  bool _obscure     = true;
  bool _loading     = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      final user = await context.read<AuthService>().signIn(
        _emailCtrl.text.trim().toLowerCase(),
        _passCtrl.text.trim(),
      );
      if (!mounted) return;
      if (user == null) {
        setState(() => _error = 'Account not found. Contact your admin.');
        return;
      }
      if (user.isAdmin) {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const AdminDashboardScreen()));
      } else {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => StudentHomeScreen(user: user)));
      }
    } catch (e) {
      setState(() => _error = _friendly(e.toString()));
      debugPrint('Login error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendly(String raw) {
    if (raw.contains('user-not-found') ||
        raw.contains('wrong-password') ||
        raw.contains('invalid-credential'))
      return 'Incorrect email or password.';
    if (raw.contains('invalid-email'))
      return 'Please enter a valid email address.';
    if (raw.contains('too-many-requests'))
      return 'Too many attempts. Try again later.';
    if (raw.contains('network') || raw.contains('Network'))
      return 'No internet connection. Check your network.';
    if (raw.contains('user-disabled'))
      return 'Your account has been disabled. Contact admin.';
    if (raw.contains('No profile found'))
      return raw;
    if (raw.contains('weak-password'))
      return 'Password must be at least 6 characters.';
    return 'Login failed. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 64),

                // Icon
                Container(
                  width: 60, height: 60,
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.campaign_rounded,
                      color: Colors.white, size: 32),
                ),
                const SizedBox(height: 28),

                Text('Welcome back', style: AppTheme.heading1),
                const SizedBox(height: 6),
                Text('Sign in to access the noticeboard',
                    style: AppTheme.bodyMuted),
                const SizedBox(height: 40),

                // Email
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Email address',
                    prefixIcon: Icon(Icons.email_outlined,
                        color: AppTheme.textMuted),
                  ),
                  validator: (v) =>
                      (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                ),
                const SizedBox(height: 14),

                // Password
                TextFormField(
                  controller: _passCtrl,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _login(),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline_rounded,
                        color: AppTheme.textMuted),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: AppTheme.textMuted),
                      onPressed: () =>
                          setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) => (v == null || v.length < 6)
                      ? 'Minimum 6 characters' : null,
                ),

                // Error
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.danger.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppTheme.danger.withOpacity(0.25)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.error_outline_rounded,
                          color: AppTheme.danger, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_error!,
                          style: AppTheme.body.copyWith(
                              color: AppTheme.danger, fontSize: 13))),
                    ]),
                  ),
                ],

                const SizedBox(height: 28),

                ElevatedButton(
                  onPressed: _loading ? null : _login,
                  child: _loading
                      ? const SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5))
                      : const Text('Sign In'),
                ),

                const SizedBox(height: 28),
                Center(
                  child: Text(
                    'Your credentials are assigned by the college.\nContact admin if you cannot log in.',
                    textAlign: TextAlign.center,
                    style: AppTheme.bodyMuted.copyWith(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
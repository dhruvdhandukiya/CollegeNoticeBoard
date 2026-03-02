// lib/screens/admin/admin_login_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../utils/app_theme.dart';
import 'admin_dashboard_screen.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});
  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
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
      final auth = context.read<AuthService>();
      final user = await auth.signIn(_emailCtrl.text.trim(), _passCtrl.text.trim());

      if (user == null || user.role != 'admin') {
        await auth.signOut();
        setState(() { _error = 'Access denied. Admin credentials required.'; });
        return;
      }

      if (!mounted) return;
      Navigator.pushReplacement(context,
        MaterialPageRoute(builder: (_) => const AdminDashboardScreen()));
    } catch (e) {
      setState(() {
        _error = e.toString().contains('wrong-password') || e.toString().contains('user-not-found')
          ? 'Invalid email or password.'
          : 'Login failed. Please try again.';
      });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // ── Header Banner ─────────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(28, 60, 28, 40),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0D1B6E), Color(0xFF1A237E)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(40),
                    bottomRight: Radius.circular(40),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.arrow_back_ios_new_rounded,
                          size: 18, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.accent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.admin_panel_settings_rounded,
                        size: 32, color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    Text('Admin Portal',
                      style: AppTheme.heading1.copyWith(color: Colors.white, fontSize: 30)),
                    const SizedBox(height: 6),
                    Text('Restricted access. Admins only.',
                      style: AppTheme.bodyMuted.copyWith(color: Colors.white60)),
                  ],
                ),
              ),

              // ── Form ──────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.all(28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      Text('Sign in to continue', style: AppTheme.heading3),
                      const SizedBox(height: 24),

                      // Email
                      TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Admin Email',
                          prefixIcon: Icon(Icons.email_outlined, color: AppTheme.textMuted),
                        ),
                        validator: (v) =>
                          v == null || v.isEmpty ? 'Email is required' : null,
                      ),
                      const SizedBox(height: 16),

                      // Password
                      TextFormField(
                        controller: _passCtrl,
                        obscureText: _obscure,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline_rounded,
                            color: AppTheme.textMuted),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscure ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                              color: AppTheme.textMuted,
                            ),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                        ),
                        validator: (v) =>
                          v == null || v.length < 6 ? 'Minimum 6 characters' : null,
                      ),

                      // Error
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.danger.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppTheme.danger.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded,
                                color: AppTheme.danger, size: 18),
                              const SizedBox(width: 8),
                              Expanded(child: Text(_error!,
                                style: AppTheme.body.copyWith(
                                  color: AppTheme.danger, fontSize: 13))),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 32),

                      // Login Button
                      ElevatedButton(
                        onPressed: _loading ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accent,
                          minimumSize: const Size(double.infinity, 56),
                        ),
                        child: _loading
                          ? const SizedBox(
                              width: 22, height: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5))
                          : const Text('Login as Admin',
                              style: TextStyle(fontSize: 16,
                                fontWeight: FontWeight.w700)),
                      ),

                      const SizedBox(height: 24),
                      Center(
                        child: Text(
                          '🔒 This portal is for authorized faculty only',
                          style: AppTheme.bodyMuted.copyWith(fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
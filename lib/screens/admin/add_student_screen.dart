// lib/screens/admin/add_student_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';
import '../../utils/app_theme.dart';

class AddStudentScreen extends StatefulWidget {
  const AddStudentScreen({super.key});
  @override
  State<AddStudentScreen> createState() => _AddStudentScreenState();
}

class _AddStudentScreenState extends State<AddStudentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl  = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();

  String _department = 'IT';
  String _role = 'student';
  String? _committee;
  bool _loading = false;
  bool _obscure = true;

  static const _departments = ['IT', 'CS', 'EXTC', 'MECH'];
  static const _committees  = ['CSI', 'NSS', 'Cultural', 'Sports', 'IEEE'];
  static const _roles = ['student', 'committee'];

  @override
  void dispose() {
    _nameCtrl.dispose(); _emailCtrl.dispose(); _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_role == 'committee' && _committee == null) {
      _showError('Please select a committee for this student');
      return;
    }

    setState(() => _loading = true);
    try {
      // 1. Create Firebase Auth account for student
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
      );

      // 2. Store student profile in Firestore
      final user = UserModel(
        uid: cred.user!.uid,
        email: _emailCtrl.text.trim(),
        name: _nameCtrl.text.trim(),
        role: _role,
        department: _department,
        committee: _role == 'committee' ? _committee : null,
      );
      await context.read<FirestoreService>().addStudentRecord(user);

      // 3. Sign back in as admin (creating user logs in as the new user in Firebase)
      // NOTE: In production, use Firebase Admin SDK / Cloud Functions for this.
      // For now, just navigate back after creation.

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_nameCtrl.text.trim()} added successfully!'),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } on FirebaseAuthException catch (e) {
      _showError(_authError(e.code));
    } catch (e) {
      _showError('Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _authError(String code) {
    switch (code) {
      case 'email-already-in-use': return 'This email is already registered.';
      case 'invalid-email': return 'Invalid email format.';
      case 'weak-password': return 'Password must be at least 6 characters.';
      default: return 'Failed to create account. Try again.';
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppTheme.danger));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(title: const Text('Add Student')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Info Banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.primary.withOpacity(0.2), width: 1.5),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                    color: AppTheme.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'A login account will be created for this student.',
                      style: AppTheme.body.copyWith(
                        color: AppTheme.primary, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Personal Info ─────────────────────────────────────────────
            _sectionLabel('👤 Student Information'),
            const SizedBox(height: 12),

            TextFormField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Full Name *',
                prefixIcon: Icon(Icons.person_outline_rounded,
                  color: AppTheme.textMuted),
              ),
              validator: (v) => v == null || v.isEmpty ? 'Name is required' : null,
            ),
            const SizedBox(height: 14),

            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'College Email *',
                hintText: 'student@college.edu',
                prefixIcon: Icon(Icons.email_outlined, color: AppTheme.textMuted),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Email is required';
                if (!v.contains('@')) return 'Enter a valid email';
                return null;
              },
            ),
            const SizedBox(height: 14),

            TextFormField(
              controller: _passCtrl,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: 'Temporary Password *',
                hintText: 'Minimum 6 characters',
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
            const SizedBox(height: 28),

            // ── Department & Role ─────────────────────────────────────────
            _sectionLabel('🏛️ Department & Role'),
            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              value: _department,
              decoration: const InputDecoration(
                labelText: 'Department *',
                prefixIcon: Icon(Icons.apartment_rounded,
                  color: AppTheme.textMuted),
              ),
              items: _departments.map((d) => DropdownMenuItem(
                value: d,
                child: Row(
                  children: [
                    Container(
                      width: 10, height: 10,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.deptColor(d),
                        shape: BoxShape.circle,
                      ),
                    ),
                    Text(d),
                  ],
                ),
              )).toList(),
              onChanged: (v) => setState(() => _department = v!),
            ),
            const SizedBox(height: 14),

            // Role selection as segmented buttons
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFDDE3F0), width: 1.5),
              ),
              child: Row(
                children: _roles.map((r) {
                  final selected = _role == r;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _role = r;
                        if (r == 'student') _committee = null;
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: selected ? AppTheme.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          r == 'student' ? '👤 Student' : '⭐ Committee',
                          textAlign: TextAlign.center,
                          style: AppTheme.body.copyWith(
                            color: selected ? Colors.white : AppTheme.textMuted,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            // Committee dropdown — only shown if role == committee
            if (_role == 'committee') ...[
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: _committee,
                decoration: const InputDecoration(
                  labelText: 'Committee *',
                  prefixIcon: Icon(Icons.groups_rounded, color: AppTheme.textMuted),
                ),
                items: _committees.map((c) => DropdownMenuItem(
                  value: c, child: Text(c),
                )).toList(),
                onChanged: (v) => setState(() => _committee = v),
              ),
            ],

            const SizedBox(height: 36),

            // ── Submit ────────────────────────────────────────────────────
            ElevatedButton.icon(
              onPressed: _loading ? null : _submit,
              icon: _loading
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.person_add_alt_1_rounded),
              label: Text(_loading ? 'Creating...' : 'Add Student'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(text, style: AppTheme.heading3.copyWith(fontSize: 15));
  }
}
// lib/screens/admin/add_student_screen.dart
// A student can be a regular student AND also be part of a committee.
// Role is always 'student' but committee field is separately optional.

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
  final _formKey   = GlobalKey<FormState>();
  final _nameCtrl  = TextEditingController();
  final _rollCtrl  = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();

  String  _department    = 'IT';
  String  _year          = 'FE';
  // isCommitteeMember is a separate toggle — independent of role
  bool    _isCommittee   = false;
  String? _committee;
  bool    _loading       = false;
  bool    _obscurePass   = true;

  static const _departments = ['IT', 'CS', 'EXTC', 'MECH', 'AIDS', 'CHEMICAL'];
  static const _committees  = [
    'CSI', 'NSS', 'IETE', 'Students Council',
    'Codecell', 'CodeTantra', 'CodeStorm',
  ];
  static const _years = ['FE', 'SE', 'TE', 'BE'];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _rollCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  // Auto-generate email when name changes
  void _onNameChanged(String name) {
    if (name.trim().isEmpty) return;
    final parts = name.trim().toLowerCase().split(RegExp(r'\s+'));
    final email = parts.length >= 2
        ? '${parts.first}.${parts.last}@college.edu'
        : '${parts.first}@college.edu';
    _emailCtrl.text = email;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isCommittee && _committee == null) {
      _snack('Please select a committee', AppTheme.danger);
      return;
    }

    setState(() => _loading = true);
    final email    = _emailCtrl.text.trim();
    final password = _passCtrl.text.trim();
    final name     = _nameCtrl.text.trim();

    try {
      // 1. Create Firebase Auth account
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email, password: password);

      // 2. Role: if committee member → role = 'committee', else 'student'
      final role = _isCommittee ? 'committee' : 'student';

      // 3. Save to Firestore
      final user = UserModel(
        uid:        cred.user!.uid,
        email:      email,
        name:       name,
        role:       role,
        department: _department,
        year:       _year,
        committee:  _isCommittee ? _committee : null,
        rollNumber: _rollCtrl.text.trim().isEmpty
            ? null : _rollCtrl.text.trim(),
        phone:      _phoneCtrl.text.trim().isEmpty
            ? null : _phoneCtrl.text.trim(),
        isActive:   true,
        createdAt:  DateTime.now(),
      );
      await context.read<FirestoreService>().saveStudent(user);

      if (!mounted) return;
      // Show credentials dialog — admin shares manually
      _showCredentialsDialog(name, email, password);
    } on FirebaseAuthException catch (e) {
      _snack(_authError(e.code), AppTheme.danger);
    } catch (e) {
      _snack('Error: $e', AppTheme.danger);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showCredentialsDialog(String name, String email, String password) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          const Icon(Icons.check_circle_rounded, color: AppTheme.success),
          const SizedBox(width: 10),
          const Expanded(child: Text('Student Created!')),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$name has been added successfully.',
                style: AppTheme.body),
            const SizedBox(height: 16),
            Text('Share these credentials with the student:',
                style: AppTheme.bodyMuted.copyWith(fontSize: 13)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFDDE3F0))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText('Email: $email',
                      style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 13)),
                  const SizedBox(height: 4),
                  SelectableText('Password: $password',
                      style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primary)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // close dialog
              Navigator.pop(context); // back to dashboard
            },
            style: ElevatedButton.styleFrom(
                minimumSize: const Size(100, 40)),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  String _authError(String code) {
    switch (code) {
      case 'email-already-in-use': return 'This email is already registered.';
      case 'invalid-email':        return 'Invalid email format.';
      case 'weak-password':        return 'Password is too weak.';
      default:                     return 'Auth error: $code';
    }
  }

  void _snack(String msg, Color color) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));

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

            // ── Personal Info ─────────────────────────────────────────
            _label('Personal Information'),
            const SizedBox(height: 10),
            TextFormField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Full Name *',
                prefixIcon: Icon(Icons.person_outline_rounded,
                    color: AppTheme.textMuted)),
              onChanged: _onNameChanged,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email *',
                prefixIcon: Icon(Icons.email_outlined,
                    color: AppTheme.textMuted),
                helperText: 'Auto-filled from name — you can edit'),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                if (!v.contains('@')) return 'Enter a valid email';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _passCtrl,
              obscureText: _obscurePass,
              decoration: InputDecoration(
                labelText: 'Password *',
                prefixIcon: const Icon(Icons.lock_outline_rounded,
                    color: AppTheme.textMuted),
                helperText: 'Set the initial login password',
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePass
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: AppTheme.textMuted),
                  onPressed: () =>
                      setState(() => _obscurePass = !_obscurePass)),
              ),
              validator: (v) => (v == null || v.length < 6)
                  ? 'Minimum 6 characters' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _rollCtrl,
              decoration: const InputDecoration(
                labelText: 'Roll Number',
                prefixIcon: Icon(Icons.badge_outlined,
                    color: AppTheme.textMuted),
                hintText: 'e.g. IT2024001'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                prefixIcon: Icon(Icons.phone_outlined,
                    color: AppTheme.textMuted),
                hintText: '+919876543210'),
            ),
            const SizedBox(height: 24),

            // ── Academic Info ─────────────────────────────────────────
            _label('Academic Information'),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _department,
              decoration: const InputDecoration(
                labelText: 'Department *',
                prefixIcon: Icon(Icons.apartment_rounded,
                    color: AppTheme.textMuted)),
              items: _departments.map((d) => DropdownMenuItem(
                value: d,
                child: Row(children: [
                  Container(
                    width: 10, height: 10,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                        color: AppTheme.deptColor(d),
                        shape: BoxShape.circle)),
                  Text('$d — ${AppTheme.deptFullName(d)}',
                      style: AppTheme.body.copyWith(fontSize: 13)),
                ]),
              )).toList(),
              onChanged: (v) => setState(() => _department = v!),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _year,
              decoration: const InputDecoration(
                labelText: 'Year *',
                prefixIcon: Icon(Icons.school_rounded,
                    color: AppTheme.textMuted)),
              items: _years.map((y) => DropdownMenuItem(
                value: y,
                child: Row(children: [
                  Container(
                    width: 10, height: 10,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                        color: AppTheme.yearColor(y),
                        shape: BoxShape.circle)),
                  Text('$y Engineering', style: AppTheme.body),
                ]),
              )).toList(),
              onChanged: (v) => setState(() => _year = v!),
            ),
            const SizedBox(height: 24),

            // ── Committee Membership ──────────────────────────────────
            // This is a separate toggle — a student is ALWAYS a student,
            // but they can ALSO be a committee member at the same time.
            _label('Committee Membership'),
            const SizedBox(height: 6),
            Text(
              'A student can belong to a committee without changing their student role.',
              style: AppTheme.bodyMuted.copyWith(fontSize: 12)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isCommittee
                      ? AppTheme.purple.withOpacity(0.5)
                      : const Color(0xFFECEFF9),
                  width: _isCommittee ? 1.5 : 1)),
              child: Row(children: [
                Icon(Icons.groups_rounded,
                    color: _isCommittee
                        ? AppTheme.purple : AppTheme.textMuted,
                    size: 22),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Part of a Committee?',
                        style: AppTheme.body.copyWith(
                            fontWeight: FontWeight.w600)),
                    Text(
                      _isCommittee
                          ? 'Will receive committee notices too'
                          : 'Toggle on if student holds a committee role',
                      style: AppTheme.bodyMuted.copyWith(fontSize: 12)),
                  ],
                )),
                Switch(
                  value: _isCommittee,
                  onChanged: (v) => setState(() {
                    _isCommittee = v;
                    if (!v) _committee = null;
                  }),
                  activeColor: AppTheme.purple),
              ]),
            ),

            // Committee dropdown — shown only when toggle is ON
            if (_isCommittee) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _committee,
                decoration: const InputDecoration(
                  labelText: 'Select Committee *',
                  prefixIcon: Icon(Icons.star_outline_rounded,
                      color: AppTheme.purple)),
                items: _committees.map((c) => DropdownMenuItem(
                  value: c,
                  child: Row(children: [
                    const Icon(Icons.circle, size: 8,
                        color: AppTheme.purple),
                    const SizedBox(width: 8),
                    Text(c, style: AppTheme.body),
                  ]),
                )).toList(),
                onChanged: (v) => setState(() => _committee = v),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.purple.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppTheme.purple.withOpacity(0.2))),
                child: Row(children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 15, color: AppTheme.purple),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    'This student will see both department/year notices '
                    'AND notices addressed to the ${_committee ?? 'selected'} committee.',
                    style: AppTheme.bodyMuted.copyWith(fontSize: 11))),
                ]),
              ),
            ],

            const SizedBox(height: 32),

            // ── Submit ────────────────────────────────────────────────
            ElevatedButton.icon(
              onPressed: _loading ? null : _submit,
              icon: _loading
                  ? const SizedBox(width: 18, height: 18,
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

  Widget _label(String text) =>
      Text(text, style: AppTheme.heading3.copyWith(fontSize: 14));
}
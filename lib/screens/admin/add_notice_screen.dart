// lib/screens/admin/add_notice_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/notice_model.dart';
import '../../services/firestore_service.dart';
import '../../utils/app_theme.dart';

class AddNoticeScreen extends StatefulWidget {
  final NoticeModel? existing; // If provided, we're editing

  const AddNoticeScreen({super.key, this.existing});

  @override
  State<AddNoticeScreen> createState() => _AddNoticeScreenState();
}

class _AddNoticeScreenState extends State<AddNoticeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  String _category = 'General';
  String _visibility = 'all';
  String? _targetDepartment;
  String? _targetCommittee;
  bool _isImportant = false;
  bool _loading = false;

  static const _categories = [
    'General', 'Academics', 'Event', 'Sports',
    'Financial Aid', 'Placement', 'Holiday', 'Internal',
  ];
  static const _departments = ['IT', 'CS', 'EXTC', 'MECH'];
  static const _committees  = ['CSI', 'NSS', 'Cultural', 'Sports', 'IEEE'];

  @override
  void initState() {
    super.initState();
    // Pre-fill if editing
    if (widget.existing != null) {
      final n = widget.existing!;
      _titleCtrl.text      = n.title;
      _descCtrl.text       = n.description;
      _category            = n.category;
      _visibility          = n.visibility;
      _targetDepartment    = n.targetDepartment;
      _targetCommittee     = n.targetCommittee;
      _isImportant         = n.isImportant;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate visibility targets
    if (_visibility == 'department' && _targetDepartment == null) {
      _showError('Please select a department');
      return;
    }
    if (_visibility == 'committee' && _targetCommittee == null) {
      _showError('Please select a committee');
      return;
    }

    setState(() => _loading = true);
    try {
      final fs = context.read<FirestoreService>();
      final notice = NoticeModel(
        id: widget.existing?.id ?? const Uuid().v4(),
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        category: _category,
        visibility: _visibility,
        targetDepartment: _visibility == 'department' ? _targetDepartment : null,
        targetCommittee: _visibility == 'committee' ? _targetCommittee : null,
        isImportant: _isImportant,
        createdAt: DateTime.now(),
      );

      if (widget.existing != null) {
        await fs.updateNotice(notice.id, notice);
      } else {
        await fs.addNotice(notice);
      }

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.existing != null
            ? 'Notice updated successfully!' : 'Notice published successfully!'),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      _showError('Failed to save notice: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppTheme.danger));
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Notice' : 'Add Notice'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ── Section Header ─────────────────────────────────────────────
            _sectionHeader('📋 Notice Content'),
            const SizedBox(height: 12),

            // Title
            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Notice Title *',
                hintText: 'e.g. CSI Meeting on Friday',
                prefixIcon: Icon(Icons.title_rounded, color: AppTheme.textMuted),
              ),
              validator: (v) => v == null || v.isEmpty ? 'Title is required' : null,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),

            // Description
            TextFormField(
              controller: _descCtrl,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Description *',
                hintText: 'Write detailed notice content here...',
                alignLabelWithHint: true,
                prefixIcon: Padding(
                  padding: EdgeInsets.only(bottom: 64),
                  child: Icon(Icons.description_outlined, color: AppTheme.textMuted),
                ),
              ),
              validator: (v) =>
                v == null || v.length < 10 ? 'Add at least 10 characters' : null,
            ),
            const SizedBox(height: 24),

            // ── Category ──────────────────────────────────────────────────
            _sectionHeader('🏷️ Category'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: _categories.map((cat) {
                final selected = _category == cat;
                return ChoiceChip(
                  label: Text(cat),
                  selected: selected,
                  onSelected: (_) => setState(() => _category = cat),
                  selectedColor: AppTheme.primary,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : AppTheme.textDark,
                    fontWeight: FontWeight.w600, fontSize: 13,
                  ),
                  backgroundColor: Colors.white,
                  side: BorderSide(
                    color: selected ? AppTheme.primary : const Color(0xFFDDE3F0),
                    width: 1.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // ── Visibility ────────────────────────────────────────────────
            _sectionHeader('👁️ Visibility / Audience'),
            const SizedBox(height: 12),

            _VisibilityOption(
              value: 'all',
              groupValue: _visibility,
              icon: Icons.public_rounded,
              label: 'All Students',
              subtitle: 'Everyone can see this notice',
              color: AppTheme.success,
              onChanged: (v) => setState(() { _visibility = v!; }),
            ),
            _VisibilityOption(
              value: 'department',
              groupValue: _visibility,
              icon: Icons.account_balance_rounded,
              label: 'Specific Department',
              subtitle: 'Only chosen dept students',
              color: AppTheme.colorIT,
              onChanged: (v) => setState(() { _visibility = v!; }),
            ),
            _VisibilityOption(
              value: 'committee',
              groupValue: _visibility,
              icon: Icons.group_rounded,
              label: 'Specific Committee',
              subtitle: 'Only committee members',
              color: AppTheme.colorEXTC,
              onChanged: (v) => setState(() { _visibility = v!; }),
            ),

            // Department dropdown
            if (_visibility == 'department') ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _targetDepartment,
                decoration: const InputDecoration(
                  labelText: 'Select Department *',
                  prefixIcon: Icon(Icons.apartment_rounded, color: AppTheme.textMuted),
                ),
                items: _departments.map((d) => DropdownMenuItem(
                  value: d,
                  child: Text(d, style: AppTheme.body),
                )).toList(),
                onChanged: (v) => setState(() => _targetDepartment = v),
              ),
            ],

            // Committee dropdown
            if (_visibility == 'committee') ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _targetCommittee,
                decoration: const InputDecoration(
                  labelText: 'Select Committee *',
                  prefixIcon: Icon(Icons.groups_rounded, color: AppTheme.textMuted),
                ),
                items: _committees.map((c) => DropdownMenuItem(
                  value: c,
                  child: Text(c, style: AppTheme.body),
                )).toList(),
                onChanged: (v) => setState(() => _targetCommittee = v),
              ),
            ],

            const SizedBox(height: 24),

            // ── Important Toggle ───────────────────────────────────────────
            _sectionHeader('⚠️ Priority'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _isImportant
                    ? AppTheme.important.withOpacity(0.5)
                    : const Color(0xFFECEFF9),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.important.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.priority_high_rounded,
                      color: AppTheme.important, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Mark as Important',
                          style: AppTheme.heading3.copyWith(fontSize: 15)),
                        Text('Shows a red IMPORTANT badge on the notice',
                          style: AppTheme.bodyMuted.copyWith(fontSize: 12)),
                      ],
                    ),
                  ),
                  Switch(
                    value: _isImportant,
                    onChanged: (v) => setState(() => _isImportant = v),
                    activeColor: AppTheme.important,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 36),

            // ── Publish Button ─────────────────────────────────────────────
            ElevatedButton.icon(
              onPressed: _loading ? null : _submit,
              icon: _loading
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.send_rounded),
              label: Text(
                _loading ? 'Saving...'
                  : isEditing ? 'Update Notice' : 'Publish Notice'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String text) {
    return Text(text, style: AppTheme.heading3.copyWith(fontSize: 15));
  }
}

// ── Visibility Option Widget ──────────────────────────────────────────────────
class _VisibilityOption extends StatelessWidget {
  final String value;
  final String groupValue;
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final ValueChanged<String?> onChanged;

  const _VisibilityOption({
    required this.value, required this.groupValue, required this.icon,
    required this.label, required this.subtitle, required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : const Color(0xFFDDE3F0),
            width: selected ? 2 : 1.5,
          ),
        ),
        child: Row(
          children: [
            Radio<String>(
              value: value,
              groupValue: groupValue,
              onChanged: onChanged,
              activeColor: color,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            const SizedBox(width: 8),
            Icon(icon, color: selected ? color : AppTheme.textMuted, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppTheme.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: selected ? color : AppTheme.textDark,
                  )),
                  Text(subtitle, style: AppTheme.bodyMuted.copyWith(fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
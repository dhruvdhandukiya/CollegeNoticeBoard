import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/notice_model.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';
import '../../utils/app_theme.dart';
import '../../services/ntfy_service.dart';

class AddNoticeScreen extends StatefulWidget {
  final NoticeModel? existing;
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

  final Set<String> _selectedDepts = {};
  final Set<String> _selectedYears = {};
  String? _targetCommittee;

  bool _isImportant = false;
  bool _isPinned = false;
  NoticePriority _priority = NoticePriority.medium;
  String _expiryOption = 'none';
  DateTime? _customExpiry;

  // Specific students
  final List<String> _selectedUids = [];
  List<UserModel> _allStudents = [];
  bool _studentsLoaded = false;
  bool _loadingStudents = false;

  bool _submitting = false;

  static const _categories = [
    'General',
    'Academics',
    'Event',
    'Sports',
    'Placement',
    'Financial Aid',
    'Holiday',
    'Internal',
    'Exam',
  ];
  static const _departments = ['IT', 'CS', 'EXTC', 'MECH', 'AIDS', 'CHEMICAL'];
  static const _years = ['FE', 'SE', 'TE', 'BE'];
  static const _committees = [
    'CSI',
    'NSS',
    'IETE',
    'Students Council',
    'Codecell',
    'CodeTantra',
    'CodeStorm',
  ];
  static const _expiryOptions = {
    'none': 'No Expiry',
    '12h': '12 Hours',
    '24h': '24 Hours',
    '3d': '3 Days',
    '7d': '7 Days',
    'custom': 'Custom',
  };

  @override
  void initState() {
    super.initState();
    final n = widget.existing;
    if (n != null) {
      _titleCtrl.text = n.title;
      _descCtrl.text = n.description;
      _category = n.category;
      _visibility = n.visibility;
      _targetCommittee = n.targetCommittee;
      _isImportant = n.isImportant;
      _isPinned = n.isPinned;
      _priority = n.priority;
      _selectedUids.addAll(n.targetStudentUids);
      if (n.targetDepartment != null) _selectedDepts.add(n.targetDepartment!);
      if (n.targetYear != null) _selectedYears.add(n.targetYear!);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  DateTime? get _computedExpiry {
    switch (_expiryOption) {
      case '12h':
        return DateTime.now().add(const Duration(hours: 12));
      case '24h':
        return DateTime.now().add(const Duration(hours: 24));
      case '3d':
        return DateTime.now().add(const Duration(days: 3));
      case '7d':
        return DateTime.now().add(const Duration(days: 7));
      case 'custom':
        return _customExpiry;
      default:
        return null;
    }
  }

  Future<void> _loadStudents() async {
    if (_studentsLoaded) return;
    setState(() => _loadingStudents = true);
    try {
      _allStudents =
          await context.read<FirestoreService>().getAllStudentsOnce();
    } catch (e) {
      debugPrint('Error loading students: $e');
    }
    setState(() {
      _loadingStudents = false;
      _studentsLoaded = true;
    });
  }

  Future<void> _pickCustomDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time =
        await showTimePicker(context: context, initialTime: TimeOfDay.now());
    setState(() {
      _customExpiry = time == null
          ? date
          : DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  void _snack(String msg, {bool error = true}) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: error ? AppTheme.danger : AppTheme.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));

  bool get _multiValid {
    if (_visibility != 'multi') return true;
    return _selectedDepts.isNotEmpty || _selectedYears.isNotEmpty;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_visibility == 'committee' && _targetCommittee == null) {
      _snack('Select a target committee');
      return;
    }
    if (_visibility == 'specific' && _selectedUids.isEmpty) {
      _snack('Select at least one student');
      return;
    }
    if (!_multiValid) {
      _snack('Select at least one department or year');
      return;
    }
    if (_expiryOption == 'custom' && _customExpiry == null) {
      _snack('Pick a custom expiry date');
      return;
    }

    setState(() => _submitting = true);
    try {
      final notice = NoticeModel(
        id: widget.existing?.id ?? '',
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        category: _category,
        visibility: _visibility,
        targetDepartment:
            _selectedDepts.isNotEmpty ? _selectedDepts.first : null,
        targetYear: _selectedYears.isNotEmpty ? _selectedYears.first : null,
        targetCommittee: _visibility == 'committee' ? _targetCommittee : null,
        targetDepartments: _selectedDepts.toList(),
        targetYears: _selectedYears.toList(),
        targetStudentUids:
            _visibility == 'specific' ? List.from(_selectedUids) : [],
        isImportant: _isImportant,
        isPinned: _isPinned,
        priority: _priority,
        expiresAt: _computedExpiry,
        createdAt: DateTime.now(),
      );

      final fs = context.read<FirestoreService>();

      if (widget.existing != null) {
        await fs.updateNotice(notice.id, notice);
        _snack('Notice updated!', error: false);
      } else {
        await fs.addNotice(notice);
        _snack('Notice published!', error: false);

        // ✅ Send ntfy notification to targeted students
        final ntfy = context.read<NtfyService>();
        await ntfy.sendNoticeNotification(notice);
        print('📬 Notification sent for notice: ${notice.title}');
      }

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      _snack('Failed: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: Text(widget.existing != null ? 'Edit Notice' : 'New Notice'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ── Content ───────────────────────────────────────────────────
            _label('Notice Content'),
            const SizedBox(height: 10),
            TextFormField(
              controller: _titleCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Title *'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descCtrl,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                  labelText: 'Description *', alignLabelWithHint: true),
              validator: (v) => (v == null || v.trim().length < 5)
                  ? 'Add a description'
                  : null,
            ),
            const SizedBox(height: 22),

            // ── Category ──────────────────────────────────────────────────
            _label('Category'),
            const SizedBox(height: 10),
            Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _categories.map((cat) {
                  final sel = _category == cat;
                  return ChoiceChip(
                    label: Text(cat),
                    selected: sel,
                    onSelected: (_) => setState(() => _category = cat),
                    selectedColor: AppTheme.primary,
                    labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: sel ? Colors.white : AppTheme.textDark),
                    backgroundColor: Colors.white,
                    side: BorderSide(
                        color:
                            sel ? AppTheme.primary : const Color(0xFFDDE3F0)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  );
                }).toList()),
            const SizedBox(height: 22),

            // ── Priority ──────────────────────────────────────────────────
            _label('Priority'),
            const SizedBox(height: 10),
            Row(
              children: NoticePriority.values.map((p) {
                final sel = _priority == p;
                final col = _priorityColor(p);
                return Expanded(
                    child: GestureDetector(
                  onTap: () => setState(() => _priority = p),
                  child: Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                        color: sel ? col : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: sel ? col : const Color(0xFFDDE3F0),
                            width: 1.5)),
                    child: Text(p.label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: sel ? Colors.white : AppTheme.textDark)),
                  ),
                ));
              }).toList(),
            ),
            const SizedBox(height: 22),

            // ── Visibility ────────────────────────────────────────────────
            _label('Who sees this?'),
            const SizedBox(height: 10),
            _visOption('all', Icons.public_rounded, 'All Students',
                'Every logged-in student'),
            _visOption('multi', Icons.tune_rounded, 'Filter by Dept + Year',
                'Pick multiple departments and/or years'),
            _visOption('committee', Icons.groups_rounded, 'By Committee',
                'Committee members only'),
            _visOption('specific', Icons.person_search_rounded,
                'Specific Students', 'Handpick individual recipients'),

            // ── Multi-select: depts + years ───────────────────────────────
            if (_visibility == 'multi') ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(14),
                    border:
                        Border.all(color: AppTheme.primary.withOpacity(0.2))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Departments
                    Text('Select Departments (optional):',
                        style: AppTheme.body.copyWith(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 8),
                    Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _departments.map((d) {
                          final sel = _selectedDepts.contains(d);
                          return FilterChip(
                            label: Text(d),
                            selected: sel,
                            onSelected: (v) => setState(() => v
                                ? _selectedDepts.add(d)
                                : _selectedDepts.remove(d)),
                            selectedColor: AppTheme.deptColor(d),
                            checkmarkColor: Colors.white,
                            labelStyle: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: sel ? Colors.white : AppTheme.textDark),
                            backgroundColor: Colors.white,
                            side: BorderSide(
                                color: sel
                                    ? AppTheme.deptColor(d)
                                    : const Color(0xFFDDE3F0)),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          );
                        }).toList()),
                    const SizedBox(height: 14),
                    // Years
                    Text('Select Years (optional):',
                        style: AppTheme.body.copyWith(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 8),
                    Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _years.map((y) {
                          final sel = _selectedYears.contains(y);
                          return FilterChip(
                            label: Text('$y Engineering'),
                            selected: sel,
                            onSelected: (v) => setState(() => v
                                ? _selectedYears.add(y)
                                : _selectedYears.remove(y)),
                            selectedColor: AppTheme.yearColor(y),
                            checkmarkColor: Colors.white,
                            labelStyle: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: sel ? Colors.white : AppTheme.textDark),
                            backgroundColor: Colors.white,
                            side: BorderSide(
                                color: sel
                                    ? AppTheme.yearColor(y)
                                    : const Color(0xFFDDE3F0)),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          );
                        }).toList()),
                    // Preview of selection
                    if (_selectedDepts.isNotEmpty ||
                        _selectedYears.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: AppTheme.success.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8)),
                        child: Row(children: [
                          const Icon(Icons.people_rounded,
                              size: 15, color: AppTheme.success),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text(_buildAudiencePreview(),
                                  style: AppTheme.body.copyWith(
                                      color: AppTheme.success,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600))),
                        ]),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            // ── Committee dropdown ─────────────────────────────────────────
            if (_visibility == 'committee') ...[
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _targetCommittee,
                decoration:
                    const InputDecoration(labelText: 'Select Committee'),
                items: _committees
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _targetCommittee = v),
              ),
            ],

            // ── Specific students picker ───────────────────────────────────
            if (_visibility == 'specific') ...[
              const SizedBox(height: 12),
              _StudentPickerWidget(
                allStudents: _allStudents,
                selectedUids: _selectedUids,
                loading: _loadingStudents,
                onOpen: _loadStudents,
                onChanged: (uids) => setState(() {
                  _selectedUids.clear();
                  _selectedUids.addAll(uids);
                }),
              ),
            ],
            const SizedBox(height: 22),

            // ── Expiry ────────────────────────────────────────────────────
            _label('Auto-Expiry'),
            const SizedBox(height: 6),
            Text('Notice will be automatically hidden after this duration.',
                style: AppTheme.bodyMuted.copyWith(fontSize: 12)),
            const SizedBox(height: 10),
            Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _expiryOptions.entries.map((e) {
                  final sel = _expiryOption == e.key;
                  return ChoiceChip(
                    label: Text(e.value),
                    selected: sel,
                    onSelected: (_) {
                      setState(() => _expiryOption = e.key);
                      if (e.key == 'custom') _pickCustomDate();
                    },
                    selectedColor: AppTheme.accent,
                    labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: sel ? Colors.white : AppTheme.textDark),
                    backgroundColor: Colors.white,
                    side: BorderSide(
                        color: sel ? AppTheme.accent : const Color(0xFFDDE3F0)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  );
                }).toList()),
            if (_expiryOption == 'custom' && _customExpiry != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: AppTheme.accent.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: AppTheme.accent.withOpacity(0.3))),
                child: Row(children: [
                  const Icon(Icons.schedule_rounded,
                      color: AppTheme.accent, size: 16),
                  const SizedBox(width: 8),
                  Text(
                      'Expires: '
                      '${_customExpiry!.day}/${_customExpiry!.month}/${_customExpiry!.year} '
                      'at ${_customExpiry!.hour.toString().padLeft(2, '0')}:'
                      '${_customExpiry!.minute.toString().padLeft(2, '0')}',
                      style: AppTheme.body.copyWith(
                          color: AppTheme.accent, fontWeight: FontWeight.w600)),
                ]),
              ),
            ],
            const SizedBox(height: 22),

            // ── Options ───────────────────────────────────────────────────
            _label('Options'),
            const SizedBox(height: 10),
            _toggle(
              icon: Icons.priority_high_rounded,
              color: AppTheme.danger,
              title: 'Mark as Important',
              subtitle: 'Shows a red badge on the notice card',
              value: _isImportant,
              onChange: (v) => setState(() => _isImportant = v),
            ),
            const SizedBox(height: 8),
            _toggle(
              icon: Icons.push_pin_rounded,
              color: AppTheme.accent,
              title: 'Pin to Top',
              subtitle: 'Appears first in every eligible student\'s feed',
              value: _isPinned,
              onChange: (v) => setState(() => _isPinned = v),
            ),
            const SizedBox(height: 8),

            ElevatedButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.send_rounded),
              label: Text(_submitting
                  ? 'Publishing...'
                  : widget.existing != null
                      ? 'Update Notice'
                      : 'Publish Notice'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _buildAudiencePreview() {
    final parts = <String>[];
    if (_selectedDepts.isNotEmpty) {
      parts.add('Depts: ${_selectedDepts.join(', ')}');
    }
    if (_selectedYears.isNotEmpty) {
      parts.add('Years: ${_selectedYears.join(', ')}');
    }
    return 'Sending to: ${parts.join('  •  ')}';
  }

  Color _priorityColor(NoticePriority p) {
    switch (p) {
      case NoticePriority.low:
        return AppTheme.success;
      case NoticePriority.medium:
        return AppTheme.primary;
      case NoticePriority.high:
        return const Color(0xFFF57C00);
      case NoticePriority.urgent:
        return AppTheme.danger;
    }
  }

  Widget _label(String text) =>
      Text(text, style: AppTheme.heading3.copyWith(fontSize: 13));

  Widget _visOption(String val, IconData icon, String title, String sub) {
    final sel = _visibility == val;
    return GestureDetector(
      onTap: () => setState(() {
        _visibility = val;
        _targetCommittee = null;
        _selectedUids.clear();
        if (val != 'multi') {
          _selectedDepts.clear();
          _selectedYears.clear();
        }
      }),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
            color: sel ? AppTheme.primary.withOpacity(0.06) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: sel ? AppTheme.primary : const Color(0xFFDDE3F0),
                width: sel ? 2 : 1.5)),
        child: Row(children: [
          Radio<String>(
            value: val,
            groupValue: _visibility,
            onChanged: (v) => setState(() => _visibility = v!),
            activeColor: AppTheme.primary,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          const SizedBox(width: 6),
          Icon(icon,
              size: 20, color: sel ? AppTheme.primary : AppTheme.textMuted),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: AppTheme.body.copyWith(
                      fontWeight: FontWeight.w600,
                      color: sel ? AppTheme.primary : AppTheme.textDark)),
              Text(sub, style: AppTheme.bodyMuted.copyWith(fontSize: 12)),
            ],
          )),
        ]),
      ),
    );
  }

  Widget _toggle({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChange,
  }) =>
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: value ? color.withOpacity(0.05) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: value ? color.withOpacity(0.4) : const Color(0xFFECEFF9),
                width: 1.5)),
        child: Row(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: AppTheme.body.copyWith(fontWeight: FontWeight.w600)),
              Text(subtitle, style: AppTheme.bodyMuted.copyWith(fontSize: 12)),
            ],
          )),
          Switch(value: value, onChanged: onChange, activeColor: color),
        ]),
      );
}

// ── Student Picker — FIXED ────────────────────────────────────────────────────
// Previous bug: was calling Firestore with compound queries that require
// composite indexes. Fixed by loading all students once and filtering locally.
class _StudentPickerWidget extends StatefulWidget {
  final List<UserModel> allStudents;
  final List<String> selectedUids;
  final bool loading;
  final VoidCallback onOpen;
  final ValueChanged<List<String>> onChanged;

  const _StudentPickerWidget({
    required this.allStudents,
    required this.selectedUids,
    required this.loading,
    required this.onOpen,
    required this.onChanged,
  });
  @override
  State<_StudentPickerWidget> createState() => _StudentPickerWidgetState();
}

class _StudentPickerWidgetState extends State<_StudentPickerWidget> {
  final _searchCtrl = TextEditingController();
  String _q = '';
  late Set<String> _local;

  @override
  void initState() {
    super.initState();
    _local = Set.from(widget.selectedUids);
    // Load students immediately when picker opens
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.onOpen());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // CLIENT-SIDE filter — no Firestore query, no index needed, no errors
  List<UserModel> get _filtered {
    if (_q.isEmpty) return widget.allStudents;
    final lq = _q.toLowerCase().trim();
    return widget.allStudents
        .where((s) =>
            s.name.toLowerCase().contains(lq) ||
            s.department.toLowerCase().contains(lq) ||
            s.year.toLowerCase().contains(lq) ||
            (s.rollNumber?.toLowerCase().contains(lq) ?? false) ||
            s.email.toLowerCase().contains(lq))
        .toList();
  }

  void _bulkSelectDept(String dept) {
    final uids =
        widget.allStudents.where((s) => s.department == dept).map((s) => s.uid);
    setState(() => _local.addAll(uids));
    widget.onChanged(_local.toList());
  }

  void _bulkSelectYear(String year) {
    final uids =
        widget.allStudents.where((s) => s.year == year).map((s) => s.uid);
    setState(() => _local.addAll(uids));
    widget.onChanged(_local.toList());
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFDDE3F0), width: 1.5)),
      child: Column(children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
          child: Row(children: [
            Text('Select Recipients',
                style: AppTheme.heading3.copyWith(fontSize: 13)),
            const Spacer(),
            if (_local.isNotEmpty)
              GestureDetector(
                  onTap: () {
                    setState(() => _local.clear());
                    widget.onChanged([]);
                  },
                  child: Text('Clear (${_local.length})',
                      style: AppTheme.body.copyWith(
                          color: AppTheme.danger,
                          fontSize: 12,
                          fontWeight: FontWeight.w600))),
          ]),
        ),

        // Search — pure client-side, no Firestore
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _q = v),
            decoration: InputDecoration(
              hintText: 'Search by name, roll number, dept, year…',
              prefixIcon: const Icon(Icons.search_rounded, size: 18),
              suffixIcon: _q.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 16),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _q = '');
                      })
                  : null,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              isDense: true,
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Quick bulk select by dept
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Quick add by dept:',
                  style: AppTheme.bodyMuted.copyWith(fontSize: 11)),
              const SizedBox(height: 4),
              Wrap(spacing: 6, children: [
                for (final d in [
                  'IT',
                  'CS',
                  'EXTC',
                  'MECH',
                  'AIDS',
                  'CHEMICAL'
                ])
                  ActionChip(
                      label: Text(d, style: const TextStyle(fontSize: 11)),
                      backgroundColor: AppTheme.deptColor(d).withOpacity(0.12),
                      side: BorderSide.none,
                      onPressed: () => _bulkSelectDept(d),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 0)),
              ]),
              const SizedBox(height: 4),
              Text('Quick add by year:',
                  style: AppTheme.bodyMuted.copyWith(fontSize: 11)),
              const SizedBox(height: 4),
              Wrap(spacing: 6, children: [
                for (final y in ['FE', 'SE', 'TE', 'BE'])
                  ActionChip(
                      label: Text(y, style: const TextStyle(fontSize: 11)),
                      backgroundColor: AppTheme.yearColor(y).withOpacity(0.12),
                      side: BorderSide.none,
                      onPressed: () => _bulkSelectYear(y),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 0)),
              ]),
            ],
          ),
        ),
        const SizedBox(height: 6),
        const Divider(height: 1),

        // Student list
        if (widget.loading)
          const Padding(
              padding: EdgeInsets.all(20), child: CircularProgressIndicator())
        else if (widget.allStudents.isEmpty)
          const Padding(
              padding: EdgeInsets.all(20),
              child: Text('No students found. Add students first.',
                  textAlign: TextAlign.center))
        else
          SizedBox(
            height: 220,
            child: _filtered.isEmpty
                ? Center(
                    child: Text('No students match "$_q"',
                        style: AppTheme.bodyMuted))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) {
                      final s = _filtered[i];
                      final sel = _local.contains(s.uid);
                      return CheckboxListTile(
                        dense: true,
                        value: sel,
                        activeColor: AppTheme.primary,
                        onChanged: (v) {
                          setState(() {
                            v! ? _local.add(s.uid) : _local.remove(s.uid);
                          });
                          widget.onChanged(_local.toList());
                        },
                        title: Text(s.name,
                            style: AppTheme.body
                                .copyWith(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                            '${s.rollNumber ?? s.email}  ·  ${s.department} ${s.year}',
                            style: AppTheme.bodyMuted.copyWith(fontSize: 11)),
                        secondary: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                                color: AppTheme.deptColor(s.department),
                                borderRadius: BorderRadius.circular(9)),
                            child: Center(
                                child: Text(
                                    s.name
                                        .split(' ')
                                        .map((w) => w[0])
                                        .take(2)
                                        .join(),
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 11)))),
                      );
                    },
                  ),
          ),
      ]),
    );
  }
}

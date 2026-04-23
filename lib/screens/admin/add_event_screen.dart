import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/firestore_service.dart';
import '../../utils/app_theme.dart';

class AddEventScreen extends StatefulWidget {
  final Map<String, dynamic>? existing;
  const AddEventScreen({super.key, this.existing});
  @override
  State<AddEventScreen> createState() => _AddEventScreenState();
}

class _AddEventScreenState extends State<AddEventScreen> {
  final _formKey       = GlobalKey<FormState>();
  final _titleCtrl     = TextEditingController();
  final _venueCtrl     = TextEditingController();
  final _organizerCtrl = TextEditingController();
  final _descCtrl      = TextEditingController();

  DateTime? _eventDate;
  TimeOfDay? _eventTime;
  String _category = 'Technical';
  bool _submitting = false;

  static const _categories = [
    'Technical', 'Cultural', 'Sports',
    'Workshop', 'Seminar', 'Academic', 'Other',
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _titleCtrl.text     = e['title'] ?? '';
      _venueCtrl.text     = e['venue'] ?? '';
      _organizerCtrl.text = e['organizer'] ?? '';
      _descCtrl.text      = e['description'] ?? '';
      _category           = e['category'] ?? 'Technical';
      if (e['eventDate'] != null) {
        _eventDate = (e['eventDate'] as dynamic).toDate();
        _eventTime = TimeOfDay(
            hour: _eventDate!.hour, minute: _eventDate!.minute);
      }
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _venueCtrl.dispose();
    _organizerCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _eventDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d != null) setState(() => _eventDate = d);
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: _eventTime ?? TimeOfDay.now(),
    );
    if (t != null) setState(() => _eventTime = t);
  }

  DateTime? get _fullEventDate {
    if (_eventDate == null) return null;
    final t = _eventTime ?? const TimeOfDay(hour: 10, minute: 0);
    return DateTime(
        _eventDate!.year, _eventDate!.month, _eventDate!.day,
        t.hour, t.minute);
  }

  void _snack(String msg, {bool error = true}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppTheme.danger : AppTheme.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_fullEventDate == null) {
      _snack('Pick a date and time for the event'); 
      return;
    }
    
    setState(() => _submitting = true);
    
    try {
      final fs = context.read<FirestoreService>();

      final data = {
        'title':     _titleCtrl.text.trim(),
        'venue':     _venueCtrl.text.trim(),
        'organizer': _organizerCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'category':  _category,
        'eventDate': _fullEventDate,
      };

      if (widget.existing != null) {
        await fs.updateEvent(widget.existing!['id'], data);
      } else {
        await fs.addEvent(data);
      }

      if (!mounted) return;
      Navigator.pop(context);
      _snack(widget.existing != null
          ? 'Event updated!' : 'Event created!', error: false);
    } catch (e) {
      _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: Text(widget.existing != null ? 'Edit Event' : 'New Event'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _label('Event Details'),
            const SizedBox(height: 10),
            
            // Title
            TextFormField(
              controller: _titleCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Event Title *'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            
            // Venue
            TextFormField(
              controller: _venueCtrl,
              decoration: const InputDecoration(
                labelText: 'Venue *',
                prefixIcon: Icon(Icons.location_on_outlined,
                    color: AppTheme.textMuted)),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            
            // Organizer
            TextFormField(
              controller: _organizerCtrl,
              decoration: const InputDecoration(
                labelText: 'Organizer',
                prefixIcon: Icon(Icons.groups_outlined,
                    color: AppTheme.textMuted)),
            ),
            const SizedBox(height: 12),
            
            // Description
            TextFormField(
              controller: _descCtrl,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Description',
                alignLabelWithHint: true),
            ),
            const SizedBox(height: 22),

            // Category
            _label('Category'),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8,
              children: _categories.map((cat) {
                final sel = _category == cat;
                return ChoiceChip(
                  label: Text(cat),
                  selected: sel,
                  onSelected: (_) => setState(() => _category = cat),
                  selectedColor: AppTheme.accent,
                  labelStyle: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600,
                    color: sel ? Colors.white : AppTheme.textDark),
                  backgroundColor: Colors.white,
                  side: BorderSide(
                    color: sel ? AppTheme.accent : const Color(0xFFDDE3F0)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                );
              }).toList()),
            const SizedBox(height: 22),

            // Date & Time
            _label('Date & Time *'),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _dateTile(
                icon: Icons.calendar_today_rounded,
                label: _eventDate != null
                    ? DateFormat('dd MMM yyyy').format(_eventDate!)
                    : 'Pick Date',
                onTap: _pickDate,
                filled: _eventDate != null,
              )),
              const SizedBox(width: 10),
              Expanded(child: _dateTile(
                icon: Icons.access_time_rounded,
                label: _eventTime != null
                    ? _eventTime!.format(context)
                    : 'Pick Time',
                onTap: _pickTime,
                filled: _eventTime != null,
              )),
            ]),
            const SizedBox(height: 32),

            // Submit Button
            ElevatedButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.check_rounded),
              label: Text(_submitting ? 'Saving…'
                  : widget.existing != null
                      ? 'Update Event' : 'Create Event'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  minimumSize: const Size(double.infinity, 48)),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) =>
      Text(text, style: AppTheme.heading3.copyWith(fontSize: 13));

  Widget _dateTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool filled,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: filled
              ? AppTheme.accent.withOpacity(0.07) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: filled ? AppTheme.accent : const Color(0xFFDDE3F0),
            width: filled ? 2 : 1.5)),
        child: Row(children: [
          Icon(icon, size: 18,
              color: filled ? AppTheme.accent : AppTheme.textMuted),
          const SizedBox(width: 8),
          Expanded(child: Text(label,
              style: AppTheme.body.copyWith(
                color: filled ? AppTheme.textDark : AppTheme.textMuted,
                fontWeight: filled ? FontWeight.w600 : FontWeight.normal))),
        ]),
      ),
    );
  }
}
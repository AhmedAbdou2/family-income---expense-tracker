import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../core/l10n/l10n.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../domain/entities.dart';
import 'providers.dart';

/// Add / edit a pet reminder. Adult only (the router redirects children and
/// RLS returns zero rows for them anyway).
class PetReminderFormScreen extends ConsumerStatefulWidget {
  const PetReminderFormScreen({
    super.key,
    required this.petId,
    this.reminderId,
  });

  final String petId;
  final String? reminderId;

  @override
  ConsumerState<PetReminderFormScreen> createState() =>
      _PetReminderFormScreenState();
}

class _PetReminderFormScreenState
    extends ConsumerState<PetReminderFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();

  PetReminderKind _kind = PetReminderKind.vaccine;
  DateTime _dueDate = DateTime.now();
  int? _repeatMonths = 12;
  bool _loading = false;
  bool _saving = false;
  String? _loadError;

  bool get _isEdit => widget.reminderId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() => _loading = true);
    try {
      final reminders = await ref.read(
        petRemindersProvider(widget.petId).future,
      );
      final matches =
          reminders.where((reminder) => reminder.id == widget.reminderId);
      if (matches.isEmpty) {
        setState(() {
          _loading = false;
          _loadError = 'invalid_reminder';
        });
        return;
      }
      final reminder = matches.first;
      setState(() {
        _titleController.text = reminder.title;
        _kind = reminder.kind;
        _dueDate = reminder.dueDate;
        _repeatMonths = reminder.repeatMonths;
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = error.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final repository = ref.read(petRemindersRepositoryProvider);
      if (_isEdit) {
        await repository.updateReminder(
          id: widget.reminderId!,
          title: _titleController.text,
          kind: _kind,
          dueDate: _dueDate,
          repeatMonths: _repeatMonths,
        );
      } else {
        await repository.createReminder(
          petId: widget.petId,
          title: _titleController.text,
          kind: _kind,
          dueDate: _dueDate,
          repeatMonths: _repeatMonths,
        );
      }
      ref.invalidate(petRemindersProvider(widget.petId));
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.pet_reminder_saved)));
      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorMessage(context, error))));
      }
    }
  }

  Future<void> _delete() async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.pet_reminder_delete_confirm_title),
        content: Text(dialogContext.l10n.pet_reminder_delete_confirm_body),
        actions: [
          TextButton(
            style: AppButtons.inline,
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(dialogContext.l10n.cancel),
          ),
          FilledButton(
            style: AppButtons.inline,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(dialogContext.l10n.delete_action),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref
          .read(petRemindersRepositoryProvider)
          .deleteReminder(id: widget.reminderId!);
      ref.invalidate(petRemindersProvider(widget.petId));
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.pet_reminder_deleted)));
      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorMessage(context, error))));
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEdit ? l10n.pet_reminder_edit_title : l10n.pet_reminder_new_title,
        ),
        actions: [
          if (_isEdit)
            IconButton(
              tooltip: l10n.delete_action,
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: _saving ? null : _delete,
            ),
        ],
      ),
      body: _loading
          ? const LoadingView()
          : _loadError != null
              ? ErrorView(error: StateError(_loadError!))
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding:
                        const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 32),
                    children: [
                      TextFormField(
                        controller: _titleController,
                        autofocus: !_isEdit,
                        maxLength: 60,
                        decoration: InputDecoration(
                          labelText: l10n.pet_reminder_title_label,
                          hintText: l10n.pet_reminder_title_hint,
                          counterText: '',
                        ),
                        validator: (value) {
                          final text = (value ?? '').trim();
                          if (text.isEmpty) return l10n.error_invalid_name;
                          if (text.length > 60) return l10n.error_invalid_name;
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      SegmentedButton<PetReminderKind>(
                        segments: [
                          ButtonSegment(
                            value: PetReminderKind.vaccine,
                            label: Text(l10n.pet_reminder_kind_vaccine),
                            icon: const Icon(Icons.vaccines_outlined),
                          ),
                          ButtonSegment(
                            value: PetReminderKind.vet,
                            label: Text(l10n.pet_reminder_kind_vet),
                            icon: const Icon(Icons.local_hospital_outlined),
                          ),
                          ButtonSegment(
                            value: PetReminderKind.other,
                            label: Text(l10n.pet_reminder_kind_other),
                            icon: const Icon(Icons.more_horiz_rounded),
                          ),
                        ],
                        selected: {_kind},
                        onSelectionChanged: (selection) =>
                            setState(() => _kind = selection.first),
                      ),
                      const SizedBox(height: 8),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.event_outlined),
                        title: Text(l10n.pet_reminder_due_label),
                        subtitle: Text(
                          DateFormat.yMMMd(locale).format(_dueDate),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: _saving ? null : _pickDate,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.repeat_rounded),
                        title: Text(l10n.pet_reminder_repeat_label),
                        subtitle: Text(_repeatLabel(l10n)),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: _saving ? null : _pickRepeat,
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: const Icon(Icons.check_rounded),
                        label: Text(l10n.save),
                      ),
                    ],
                  ),
                ),
    );
  }

  String _repeatLabel(AppLocalizations l10n) {
    final months = _repeatMonths;
    if (months == null) return l10n.pet_reminder_repeat_none;
    if (months == 12) return l10n.pet_reminder_repeat_yearly;
    return l10n.pet_reminder_repeat_months(months);
  }

  Future<void> _pickRepeat() async {
    const options = <int?>[null, 1, 3, 6, 12];
    // A string is returned, not an int?: `null` from a dialog means "user
    // backed out", so "does not repeat" needs its own token.
    final picked = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(dialogContext.l10n.pet_reminder_repeat_label),
        children: [
          for (final months in options)
            SimpleDialogOption(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(months?.toString() ?? 'none'),
              child: Text(
                months == null
                    ? dialogContext.l10n.pet_reminder_repeat_none
                    : months == 12
                        ? dialogContext.l10n.pet_reminder_repeat_yearly
                        : dialogContext.l10n.pet_reminder_repeat_months(months),
              ),
            ),
        ],
      ),
    );
    if (!mounted || picked == null) return;
    setState(() => _repeatMonths = picked == 'none' ? null : int.parse(picked));
  }
}
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../core/l10n/l10n.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../household/presentation/providers.dart';
import '../domain/entities.dart';
import 'pet_visuals.dart';
import 'providers.dart';

/// Add/edit a pet (name, type, optional birth date + notes). Archive is
/// available on edit, mirroring vehicles.
class PetFormScreen extends ConsumerStatefulWidget {
  const PetFormScreen({super.key, this.petId});

  final String? petId;

  @override
  ConsumerState<PetFormScreen> createState() => _PetFormScreenState();
}

class _PetFormScreenState extends ConsumerState<PetFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _notesController = TextEditingController();

  PetType _type = PetType.other;
  DateTime? _birthDate;
  bool _isActive = true;
  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  bool get _isEdit => widget.petId != null;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    if (widget.petId == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final pet = await ref.read(petsRepositoryProvider).getPet(
            id: widget.petId!,
          );
      if (pet == null) throw StateError('missing pet');
      if (!mounted) return;
      setState(() {
        _nameController.text = pet.name;
        _notesController.text = pet.notes ?? '';
        _type = pet.type;
        _birthDate = pet.birthDate;
        _isActive = pet.isActive;
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
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.pets_title)),
        body: const LoadingView(),
      );
    }
    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.pet_edit)),
        body: ErrorView(error: StateError(_loadError!)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? l10n.pet_edit : l10n.pet_add),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.save),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 32),
          children: [
            TextFormField(
              controller: _nameController,
              autofocus: !_isEdit,
              maxLength: 40,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: l10n.pet_name,
                hintText: l10n.pet_name_hint,
                counterText: '',
              ),
              validator: (value) =>
                  (value == null || value.trim().isEmpty)
                      ? l10n.field_required
                      : null,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<PetType>(
              initialValue: _type,
              decoration: InputDecoration(labelText: l10n.pet_type),
              items: [
                for (final type in PetType.values)
                  DropdownMenuItem(
                    value: type,
                    child: Text(petTypeLabel(context, type)),
                  ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _type = value);
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.cake_outlined),
              title: Text(l10n.pet_birth_date),
              subtitle: Text(
                _birthDate == null
                    ? '—'
                    : DateFormat.yMMMd(locale).format(_birthDate!),
              ),
              trailing: _birthDate == null
                  ? const Icon(Icons.chevron_right_rounded)
                  : IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () => setState(() => _birthDate = null),
                    ),
              onTap: _pickBirthDate,
            ),
            const Divider(height: 1),
            TextFormField(
              controller: _notesController,
              maxLength: 200,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: l10n.pet_notes,
                counterText: '',
              ),
            ),
            if (_isEdit) ...[
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.pet_archive),
                subtitle: Text(
                  _isActive ? l10n.recurring_active : l10n.pet_archived,
                ),
                value: !_isActive,
                onChanged: (archived) => setState(() => _isActive = !archived),
              ),
            ],
            const SizedBox(height: 8),
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

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 1, now.month, now.day),
      firstDate: DateTime(1990),
      lastDate: now,
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final membership = ref.read(membershipProvider).value;
    if (membership == null) return;

    setState(() => _saving = true);
    try {
      final repository = ref.read(petsRepositoryProvider);
      if (_isEdit) {
        await repository.updatePet(
          id: widget.petId!,
          name: _nameController.text,
          type: _type,
          isActive: _isActive,
          birthDate: _birthDate,
          notes: _notesController.text,
        );
      } else {
        await repository.createPet(
          householdId: membership.household.id,
          name: _nameController.text,
          type: _type,
          birthDate: _birthDate,
          notes: _notesController.text,
        );
      }
      ref.invalidate(petsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.pet_saved)));
      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorMessage(context, error))));
      }
    }
  }
}

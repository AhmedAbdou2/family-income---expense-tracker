import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../core/l10n/l10n.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../household/presentation/providers.dart';
import 'providers.dart';

/// Add/edit a maintenance reminder: due by date and/or odometer, with an
/// optional repeat interval that re-arms it after completion.
class MaintenanceFormScreen extends ConsumerStatefulWidget {
  const MaintenanceFormScreen({
    super.key,
    required this.vehicleId,
    this.itemId,
  });

  final String vehicleId;
  final String? itemId;

  @override
  ConsumerState<MaintenanceFormScreen> createState() =>
      _MaintenanceFormScreenState();
}

class _MaintenanceFormScreenState extends ConsumerState<MaintenanceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _dueOdometerController = TextEditingController();
  final _intervalDaysController = TextEditingController();
  final _intervalKmController = TextEditingController();

  DateTime? _dueDate;
  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  bool get _isEdit => widget.itemId != null;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    if (widget.itemId == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final item = await ref
          .read(maintenanceRepositoryProvider)
          .getMaintenance(id: widget.itemId!);
      if (item == null) throw StateError('missing item');
      if (!mounted) return;
      setState(() {
        _nameController.text = item.name;
        _dueDate = item.dueDate;
        _dueOdometerController.text =
            item.dueOdometerKm?.toStringAsFixed(0) ?? '';
        _intervalDaysController.text = item.intervalDays?.toString() ?? '';
        _intervalKmController.text = item.intervalKm?.toStringAsFixed(0) ?? '';
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
    _dueOdometerController.dispose();
    _intervalDaysController.dispose();
    _intervalKmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.maintenance_add)),
        body: const LoadingView(),
      );
    }
    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.maintenance_edit)),
        body: ErrorView(error: StateError(_loadError!)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? l10n.maintenance_edit : l10n.maintenance_add),
        actions: [
          if (_isEdit)
            IconButton(
              tooltip: l10n.maintenance_delete,
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: _saving ? null : _delete,
            ),
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
              maxLength: 60,
              decoration: InputDecoration(
                labelText: l10n.maintenance_name,
                hintText: l10n.maintenance_name_hint,
                counterText: '',
              ),
              validator: (value) =>
                  (value == null || value.trim().isEmpty)
                      ? l10n.field_required
                      : null,
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today_outlined),
              title: Text(l10n.maintenance_due_date),
              subtitle: Text(
                _dueDate == null
                    ? '—'
                    : DateFormat.yMMMd(locale).format(_dueDate!),
              ),
              trailing: _dueDate == null
                  ? const Icon(Icons.chevron_right_rounded)
                  : IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () => setState(() => _dueDate = null),
                    ),
              onTap: _pickDate,
            ),
            const Divider(height: 1),
            TextFormField(
              controller: _dueOdometerController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration:
                  InputDecoration(labelText: l10n.maintenance_due_odometer),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.maintenance_interval_hint,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _intervalDaysController,
              keyboardType: TextInputType.number,
              decoration:
                  InputDecoration(labelText: l10n.maintenance_interval_days),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _intervalKmController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration:
                  InputDecoration(labelText: l10n.maintenance_interval_km),
            ),
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

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final dueOdometer = double.tryParse(
      _dueOdometerController.text.trim().replaceAll(',', ''),
    );
    if (_dueDate == null && dueOdometer == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.maintenance_need_one_due)));
      return;
    }

    final intervalDays = int.tryParse(_intervalDaysController.text.trim());
    final intervalKm = double.tryParse(
      _intervalKmController.text.trim().replaceAll(',', ''),
    );

    final membership = ref.read(membershipProvider).value;
    if (membership == null) return;

    setState(() => _saving = true);
    try {
      final repository = ref.read(maintenanceRepositoryProvider);
      if (_isEdit) {
        await repository.updateMaintenance(
          id: widget.itemId!,
          name: _nameController.text,
          dueDate: _dueDate,
          dueOdometerKm: dueOdometer,
          intervalDays: intervalDays,
          intervalKm: intervalKm,
        );
      } else {
        await repository.createMaintenance(
          householdId: membership.household.id,
          vehicleId: widget.vehicleId,
          name: _nameController.text,
          dueDate: _dueDate,
          dueOdometerKm: dueOdometer,
          intervalDays: intervalDays,
          intervalKm: intervalKm,
        );
      }
      ref
        ..invalidate(maintenanceProvider(widget.vehicleId))
        ..invalidate(maintenanceProvider(null));
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.maintenance_saved)));
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.maintenance_delete_confirm_title),
        content: Text(dialogContext.l10n.maintenance_delete_confirm_body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(dialogContext.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(dialogContext.l10n.delete_action),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref
          .read(maintenanceRepositoryProvider)
          .deleteMaintenance(id: widget.itemId!);
      ref
        ..invalidate(maintenanceProvider(widget.vehicleId))
        ..invalidate(maintenanceProvider(null));
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorMessage(context, error))));
      }
    }
  }
}

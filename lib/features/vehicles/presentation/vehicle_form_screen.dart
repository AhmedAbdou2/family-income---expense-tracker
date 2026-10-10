import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../household/presentation/providers.dart';
import '../domain/entities.dart';
import 'providers.dart';
import 'vehicle_visuals.dart';

/// Add/edit a vehicle. On edit the odometer is normally moved by fuel logs
/// (the RPC takes `greatest`), so this field is for corrections.
class VehicleFormScreen extends ConsumerStatefulWidget {
  const VehicleFormScreen({super.key, this.vehicleId});

  final String? vehicleId;

  @override
  ConsumerState<VehicleFormScreen> createState() => _VehicleFormScreenState();
}

class _VehicleFormScreenState extends ConsumerState<VehicleFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _plateController = TextEditingController();
  final _odometerController = TextEditingController();

  FuelType _fuelType = FuelType.petrol;
  bool _isActive = true;
  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  bool get _isEdit => widget.vehicleId != null;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    if (widget.vehicleId == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final vehicle = await ref
          .read(vehiclesRepositoryProvider)
          .getVehicle(id: widget.vehicleId!);
      if (vehicle == null) throw StateError('missing vehicle');
      if (!mounted) return;
      setState(() {
        _nameController.text = vehicle.name;
        _plateController.text = vehicle.plate ?? '';
        _odometerController.text = vehicle.currentOdometerKm.toStringAsFixed(0);
        _fuelType = vehicle.fuelType;
        _isActive = vehicle.isActive;
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
    _plateController.dispose();
    _odometerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.vehicles_title)),
        body: const LoadingView(),
      );
    }
    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.vehicle_edit)),
        body: ErrorView(error: StateError(_loadError!)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? l10n.vehicle_edit : l10n.vehicle_add),
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
              maxLength: 60,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: l10n.vehicle_name,
                hintText: l10n.vehicle_name_hint,
                counterText: '',
              ),
              validator: (value) =>
                  (value == null || value.trim().isEmpty)
                      ? l10n.field_required
                      : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _plateController,
              maxLength: 20,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: l10n.vehicle_plate,
                hintText: l10n.vehicle_plate_hint,
                counterText: '',
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<FuelType>(
              initialValue: _fuelType,
              decoration: InputDecoration(labelText: l10n.vehicle_fuel_type),
              items: [
                for (final type in FuelType.values)
                  DropdownMenuItem(
                    value: type,
                    child: Text(fuelTypeLabel(context, type)),
                  ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _fuelType = value);
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _odometerController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: l10n.vehicle_odometer,
                hintText: l10n.vehicle_odometer_hint,
              ),
              validator: (_) {
                final raw = _odometerController.text.trim().replaceAll(',', '');
                if (raw.isEmpty) return l10n.field_required;
                final value = double.tryParse(raw);
                if (value == null || value < 0) return l10n.amount_invalid;
                return null;
              },
            ),
            if (_isEdit) ...[
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.vehicle_archive),
                subtitle: Text(
                  _isActive ? l10n.recurring_active : l10n.vehicle_archived,
                ),
                value: !_isActive,
                onChanged: (archived) =>
                    setState(() => _isActive = !archived),
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

  Future<void> _save() async {
    final l10n = context.l10n;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final membership = ref.read(membershipProvider).value;
    if (membership == null) return;
    final odometer =
        double.tryParse(_odometerController.text.trim().replaceAll(',', '')) ??
            0;

    setState(() => _saving = true);
    try {
      final repository = ref.read(vehiclesRepositoryProvider);
      if (_isEdit) {
        await repository.updateVehicle(
          id: widget.vehicleId!,
          name: _nameController.text,
          plate: _plateController.text,
          fuelType: _fuelType,
          currentOdometerKm: odometer,
          isActive: _isActive,
        );
      } else {
        await repository.createVehicle(
          householdId: membership.household.id,
          name: _nameController.text,
          plate: _plateController.text,
          fuelType: _fuelType,
          currentOdometerKm: odometer,
        );
      }
      ref.invalidate(vehiclesProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.vehicle_saved)));
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

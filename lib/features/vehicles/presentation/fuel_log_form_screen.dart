import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../core/l10n/l10n.dart';
import '../../../core/utils/currency.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../household/presentation/providers.dart';
import '../../transactions/presentation/providers.dart';
import '../domain/entities.dart';
import 'providers.dart';

/// Record one fill-up (or charge). The RPC validates the odometer, writes
/// the linked fuel expense and bumps the vehicle odometer.
class FuelLogFormScreen extends ConsumerStatefulWidget {
  const FuelLogFormScreen({super.key, required this.vehicleId});

  final String vehicleId;

  @override
  ConsumerState<FuelLogFormScreen> createState() => _FuelLogFormScreenState();
}

class _FuelLogFormScreenState extends ConsumerState<FuelLogFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _odometerController = TextEditingController();
  final _litersController = TextEditingController();
  final _costController = TextEditingController();

  DateTime _date = DateTime.now();
  bool _isFull = false;
  bool _saving = false;
  bool _prefilled = false;

  @override
  void dispose() {
    _odometerController.dispose();
    _litersController.dispose();
    _costController.dispose();
    super.dispose();
  }

  Vehicle? _findVehicle() {
    final list = ref.watch(vehiclesProvider).value ?? const <Vehicle>[];
    for (final vehicle in list) {
      if (vehicle.id == widget.vehicleId) return vehicle;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final vehicle = _findVehicle();
    final currency = ref.watch(membershipProvider).value?.household.currency;
    final locale = Localizations.localeOf(context).toString();
    final currencyLabel = Currency.label(currency, locale: locale);

    if (vehicle == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.fuel_log_add)),
        body: const LoadingView(),
      );
    }

    if (!_prefilled) {
      _prefilled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _odometerController.text.isEmpty) {
          _odometerController.text =
              vehicle.currentOdometerKm.toStringAsFixed(0);
        }
      });
    }

    final isElectric = vehicle.fuelType == FuelType.electric;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.fuel_log_add),
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
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today_outlined),
              title: Text(l10n.date),
              subtitle: Text(
                DateFormat.yMMMd(Localizations.localeOf(context).toString())
                    .format(_date),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: _pickDate,
            ),
            const Divider(height: 1),
            TextFormField(
              controller: _odometerController,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: l10n.fuel_log_odometer),
              validator: (_) {
                final value = double.tryParse(
                  _odometerController.text.trim().replaceAll(',', ''),
                );
                if (value == null || value < 0) return l10n.amount_invalid;
                return null;
              },
            ),
            const SizedBox(height: 12),
            if (isElectric)
              Padding(
                padding: const EdgeInsetsDirectional.only(bottom: 12),
                child: Text(
                  l10n.fuel_log_electric_hint,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              TextFormField(
                controller: _litersController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: l10n.fuel_log_liters),
                validator: (_) {
                  final value = double.tryParse(
                    _litersController.text.trim().replaceAll(',', ''),
                  );
                  if (value == null || value <= 0) return l10n.amount_invalid;
                  return null;
                },
              ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _costController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: l10n.fuel_log_cost,
                suffixText: currencyLabel.isEmpty ? null : currencyLabel,
              ),
              validator: (_) {
                int? minor;
                try {
                  minor = Money.decimalStringToMinorUnits(
                    _costController.text.trim(),
                  );
                } on FormatException {
                  return l10n.amount_invalid;
                }
                if (minor <= 0) return l10n.amount_zero;
                return null;
              },
            ),
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.fuel_log_full_tank),
              value: _isFull,
              onChanged: (value) => setState(() => _isFull = value),
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
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final vehicle = _findVehicle();
    if (vehicle == null) return;

    final isElectric = vehicle.fuelType == FuelType.electric;
    final odometer =
        double.tryParse(_odometerController.text.trim().replaceAll(',', '')) ??
            0;
    final liters = isElectric
        ? 0.0
        : (double.tryParse(_litersController.text.trim().replaceAll(',', '')) ??
            0);
    final costMinor =
        Money.decimalStringToMinorUnits(_costController.text.trim());

    setState(() => _saving = true);
    try {
      await ref.read(fuelRepositoryProvider).addFuelLog(
            vehicleId: vehicle.id,
            date: _date,
            odometerKm: odometer,
            liters: liters,
            totalCostMinorUnits: costMinor,
            isFull: _isFull,
          );
      ref
        ..invalidate(fuelLogsProvider(vehicle.id))
        ..invalidate(fuelLogsProvider(null))
        ..invalidate(vehiclesProvider)
        ..invalidate(monthTransactionsProvider)
        ..invalidate(dashboardMonthTransactionsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.fuel_log_saved)));
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

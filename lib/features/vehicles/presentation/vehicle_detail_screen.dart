import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../core/l10n/l10n.dart';
import '../../../core/settings/settings_controller.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../household/presentation/providers.dart';
import '../../transactions/presentation/providers.dart';
import '../domain/entities.dart';
import '../domain/fuel_stats.dart';
import '../domain/maintenance_status.dart';
import 'providers.dart';
import 'vehicle_visuals.dart';

/// One vehicle: header, economy figures, its fuel log and maintenance
/// reminders. Adults only (RLS hides the data from children).
class VehicleDetailScreen extends ConsumerStatefulWidget {
  const VehicleDetailScreen({super.key, required this.vehicleId});

  final String vehicleId;

  @override
  ConsumerState<VehicleDetailScreen> createState() =>
      _VehicleDetailScreenState();
}

class _VehicleDetailScreenState extends ConsumerState<VehicleDetailScreen> {
  Vehicle? _findVehicle(List<Vehicle> list) {
    for (final vehicle in list) {
      if (vehicle.id == widget.vehicleId) return vehicle;
    }
    return null;
  }

  void _invalidateSpending() {
    ref
      ..invalidate(fuelLogsProvider(widget.vehicleId))
      ..invalidate(fuelLogsProvider(null))
      ..invalidate(vehiclesProvider)
      ..invalidate(monthTransactionsProvider)
      ..invalidate(dashboardMonthTransactionsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toString();
    final arabicDigits = ref.watch(settingsProvider).arabicDigits;
    final currency = ref.watch(membershipProvider).value?.household.currency;
    final vehicles = ref.watch(vehiclesProvider);

    if (vehicles.isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.vehicles_title)),
        body: const LoadingView(),
      );
    }
    if (vehicles.hasError) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.vehicles_title)),
        body: ErrorView(
          error: vehicles.error!,
          onRetry: () => ref.invalidate(vehiclesProvider),
        ),
      );
    }

    final vehicle = _findVehicle(vehicles.value ?? const <Vehicle>[]);
    if (vehicle == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.vehicles_title)),
        body: ErrorView(error: StateError(l10n.error_invalid_vehicle)),
      );
    }

    final fuelLogs = ref.watch(fuelLogsProvider(widget.vehicleId));
    final maintenance = ref.watch(maintenanceProvider(widget.vehicleId));

    return Scaffold(
      appBar: AppBar(
        title: Text(vehicle.name),
        actions: [
          IconButton(
            tooltip: l10n.vehicle_edit,
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.push('/vehicles/edit/${vehicle.id}'),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'toggle') _toggleArchive(vehicle);
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'toggle',
                child: Text(
                  vehicle.isActive ? l10n.vehicle_archive : l10n.vehicle_restore,
                ),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsetsDirectional.only(bottom: 96),
        children: [
          _VehicleHeaderCard(vehicle: vehicle),
          _SectionHeader(title: l10n.fuel_stats_title),
          fuelLogs.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Padding(
              padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
              child: ErrorBanner(error: error),
            ),
            data: (logs) => Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 8),
              child: _EconomyCard(
                stats: FuelStats.compute(logs),
                arabicDigits: arabicDigits,
                currency: currency,
              ),
            ),
          ),
          _SectionHeader(
            title: l10n.fuel_logs_title,
            action: FilledButton.tonalIcon(
              style: AppButtons.inline,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(l10n.fuel_log_add),
              onPressed: () =>
                  context.push('/vehicles/${vehicle.id}/fuel/new'),
            ),
          ),
          fuelLogs.when(
            loading: () => const SizedBox.shrink(),
            error: (error, _) => const SizedBox.shrink(),
            data: (logs) {
              if (logs.isEmpty) {
                return Padding(
                  padding: const EdgeInsetsDirectional.symmetric(horizontal: 20),
                  child: Text(
                    l10n.fuel_logs_empty,
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                );
              }
              return Column(
                children: [
                  for (final log in logs)
                    _FuelLogTile(
                      log: log,
                      arabicDigits: arabicDigits,
                      currency: currency,
                      locale: locale,
                      onDelete: () => _deleteFuelLog(log),
                    ),
                ],
              );
            },
          ),
          _SectionHeader(
            title: l10n.maintenance_title,
            action: FilledButton.tonalIcon(
              style: AppButtons.inline,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(l10n.maintenance_add),
              onPressed: () =>
                  context.push('/vehicles/${vehicle.id}/maintenance/new'),
            ),
          ),
          maintenance.when(
            loading: () => const SizedBox.shrink(),
            error: (error, _) => const SizedBox.shrink(),
            data: (items) {
              if (items.isEmpty) {
                return Padding(
                  padding: const EdgeInsetsDirectional.symmetric(horizontal: 20),
                  child: Text(
                    l10n.maintenance_empty,
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                );
              }
              return Column(
                children: [
                  for (final item in items)
                    _MaintenanceTile(
                      item: item,
                      status: MaintenanceReminder.status(
                        item,
                        today: DateTime.now(),
                        currentOdometerKm: vehicle.currentOdometerKm,
                      ),
                      locale: locale,
                      arabicDigits: arabicDigits,
                      onComplete: () => _completeMaintenance(item),
                      onEdit: () => context.push(
                        '/vehicles/${vehicle.id}/maintenance/edit/${item.id}',
                      ),
                      onDelete: () => _deleteMaintenance(item),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: const ValueKey('add-fuel-fab'),
        icon: const Icon(Icons.local_gas_station_rounded),
        label: Text(l10n.fuel_log_add),
        onPressed: () => context.push('/vehicles/${vehicle.id}/fuel/new'),
      ),
    );
  }

  Future<void> _toggleArchive(Vehicle vehicle) async {
    final l10n = context.l10n;
    if (vehicle.isActive) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(dialogContext.l10n.vehicle_archive_confirm_title),
          content: Text(dialogContext.l10n.vehicle_archive_confirm_body),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(dialogContext.l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(dialogContext.l10n.vehicle_archive),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    try {
      await ref.read(vehiclesRepositoryProvider).updateVehicle(
            id: vehicle.id,
            name: vehicle.name,
            plate: vehicle.plate,
            fuelType: vehicle.fuelType,
            currentOdometerKm: vehicle.currentOdometerKm,
            isActive: !vehicle.isActive,
          );
      ref.invalidate(vehiclesProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.vehicle_saved)));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorMessage(context, error))));
      }
    }
  }

  Future<void> _deleteFuelLog(FuelLog log) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.fuel_log_delete_confirm_title),
        content: Text(dialogContext.l10n.fuel_log_delete_confirm_body),
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
      await ref.read(fuelRepositoryProvider).deleteFuelLog(logId: log.id);
      _invalidateSpending();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.fuel_log_deleted)));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorMessage(context, error))));
      }
    }
  }

  Future<void> _completeMaintenance(MaintenanceItem item) async {
    final l10n = context.l10n;
    final costController = TextEditingController();
    final noteController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.maintenance_complete_title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(item.name),
            const SizedBox(height: 12),
            TextField(
              controller: costController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: dialogContext.l10n.maintenance_complete_cost,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: noteController,
              maxLength: 200,
              decoration: InputDecoration(
                labelText: dialogContext.l10n.note,
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(dialogContext.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(dialogContext.l10n.maintenance_complete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      costController.dispose();
      noteController.dispose();
      return;
    }

    int? amountMinor;
    final rawCost = costController.text.trim();
    if (rawCost.isNotEmpty) {
      try {
        amountMinor = Money.decimalStringToMinorUnits(rawCost);
      } on FormatException {
        amountMinor = null;
      }
    }

    try {
      await ref.read(maintenanceRepositoryProvider).completeMaintenance(
            itemId: item.id,
            amountMinorUnits: amountMinor,
            note: noteController.text,
          );
      ref
        ..invalidate(maintenanceProvider(widget.vehicleId))
        ..invalidate(maintenanceProvider(null));
      if (amountMinor != null && amountMinor > 0) {
        ref
          ..invalidate(monthTransactionsProvider)
          ..invalidate(dashboardMonthTransactionsProvider);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.maintenance_completed)));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorMessage(context, error))));
      }
    } finally {
      costController.dispose();
      noteController.dispose();
    }
  }

  Future<void> _deleteMaintenance(MaintenanceItem item) async {
    final l10n = context.l10n;
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
          .deleteMaintenance(id: item.id);
      ref
        ..invalidate(maintenanceProvider(widget.vehicleId))
        ..invalidate(maintenanceProvider(null));
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.maintenance_saved)));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorMessage(context, error))));
      }
    }
  }
}

class _VehicleHeaderCard extends StatelessWidget {
  const _VehicleHeaderCard({required this.vehicle});

  final Vehicle vehicle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final parts = <String>[
      fuelTypeLabel(context, vehicle.fuelType),
      l10n.vehicle_odometer_value(vehicle.currentOdometerKm.toStringAsFixed(0)),
      if (vehicle.plate != null && vehicle.plate!.isNotEmpty) vehicle.plate!,
    ];

    return Card(
      margin: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: scheme.primaryContainer,
          child: Icon(
            fuelTypeIcon(vehicle.fuelType),
            color: scheme.onPrimaryContainer,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                vehicle.name,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            if (!vehicle.isActive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  l10n.vehicle_archived,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
          ],
        ),
        subtitle: Text(parts.join('  •  ')),
      ),
    );
  }
}

class _EconomyCard extends StatelessWidget {
  const _EconomyCard({
    required this.stats,
    required this.arabicDigits,
    required this.currency,
  });

  final FuelStats stats;
  final bool arabicDigits;
  final String? currency;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;

    if (!stats.hasData) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          l10n.fuel_stats_no_data,
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
      );
    }

    String digits(String text) =>
        arabicDigits ? Money.toArabicIndic(text) : text;

    return Row(
      children: [
        Expanded(
          child: _StatBox(
            title: l10n.fuel_stats_l_per_100km,
            value: stats.litersPer100Km == null
                ? '—'
                : digits(stats.litersPer100Km!.toStringAsFixed(1)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatBox(
            title: l10n.fuel_stats_cost_per_km,
            value: stats.costPerKmMinor == null
                ? '—'
                : Money.format(
                    minorUnits: stats.costPerKmMinor!.round(),
                    arabicDigits: arabicDigits,
                    currencyCode: currency,
                  ),
          ),
        ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _FuelLogTile extends StatelessWidget {
  const _FuelLogTile({
    required this.log,
    required this.arabicDigits,
    required this.currency,
    required this.locale,
    required this.onDelete,
  });

  final FuelLog log;
  final bool arabicDigits;
  final String? currency;
  final String locale;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    String digits(String text) =>
        arabicDigits ? Money.toArabicIndic(text) : text;

    final details = <String>[
      '${digits(log.odometerKm.toStringAsFixed(0))} km',
      if (log.liters > 0) '${digits(log.liters.toStringAsFixed(1))} L',
      if (log.isFull) l10n.fuel_log_full_badge,
    ];

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: scheme.primaryContainer,
        child: Icon(Icons.local_gas_station_rounded,
            color: scheme.onPrimaryContainer, size: 20),
      ),
      title: Text(DateFormat.yMMMd(locale).format(log.date)),
      subtitle: Text(details.join('  •  ')),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            Money.format(
              minorUnits: log.totalCostMinorUnits,
              arabicDigits: arabicDigits,
              currencyCode: currency,
            ),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          IconButton(
            tooltip: l10n.fuel_log_delete,
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _MaintenanceTile extends StatelessWidget {
  const _MaintenanceTile({
    required this.item,
    required this.status,
    required this.locale,
    required this.arabicDigits,
    required this.onComplete,
    required this.onEdit,
    required this.onDelete,
  });

  final MaintenanceItem item;
  final MaintenanceStatus status;
  final String locale;
  final bool arabicDigits;
  final VoidCallback onComplete;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    String digits(String text) =>
        arabicDigits ? Money.toArabicIndic(text) : text;

    final (statusText, statusColor) = switch (status) {
      MaintenanceStatus.overdue => (l10n.maintenance_status_overdue, scheme.errorContainer),
      MaintenanceStatus.dueSoon => (l10n.maintenance_status_due_soon, scheme.tertiaryContainer),
      MaintenanceStatus.ok => (null, null),
    };

    final dueParts = <String>[
      if (item.dueDate != null)
        l10n.maintenance_due_date_line(
          DateFormat.yMMMd(locale).format(item.dueDate!),
        ),
      if (item.dueOdometerKm != null)
        l10n.maintenance_due_odo_line(
          digits(item.dueOdometerKm!.toStringAsFixed(0)),
        ),
    ];

    return ListTile(
      leading: Icon(
        Icons.build_outlined,
        color: status == MaintenanceStatus.overdue ? scheme.error : null,
      ),
      title: Text(item.name),
      subtitle: Text(
        dueParts.isEmpty ? l10n.maintenance_title : dueParts.join('  •  '),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (statusText != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(statusText, style: const TextStyle(fontSize: 12)),
            ),
          IconButton(
            tooltip: l10n.maintenance_complete,
            icon: const Icon(Icons.check_circle_outline_rounded),
            onPressed: onComplete,
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') onEdit();
              if (value == 'delete') onDelete();
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'edit', child: Text(l10n.maintenance_edit)),
              PopupMenuItem(value: 'delete', child: Text(l10n.maintenance_delete)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 20, end: 12, top: 20, bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../household/domain/entities.dart';
import '../../household/presentation/providers.dart';
import '../domain/entities.dart';
import 'providers.dart';
import 'vehicle_visuals.dart';

/// Vehicle list (owner/adult only - a child's RLS returns nothing, so the
/// add controls are hidden too).
class VehiclesScreen extends ConsumerWidget {
  const VehiclesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final membership = ref.watch(membershipProvider).value;
    final canManage = switch (membership?.role) {
      MemberRole.owner || MemberRole.adult => true,
      _ => false,
    };
    final vehicles = ref.watch(vehiclesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.vehicles_title)),
      body: vehicles.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(vehiclesProvider),
        ),
        data: (list) {
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.directions_car_outlined,
              title: l10n.vehicles_empty_title,
              body: l10n.vehicles_empty_body,
            );
          }
          final active = list.where((vehicle) => vehicle.isActive).toList();
          final archived = list.where((vehicle) => !vehicle.isActive).toList();
          return ListView(
            padding: const EdgeInsetsDirectional.only(bottom: 96),
            children: [
              for (final vehicle in active)
                _VehicleTile(vehicle: vehicle),
              if (archived.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    start: 20, end: 20, top: 20, bottom: 6,
                  ),
                  child: Text(
                    l10n.vehicle_archived,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ),
                for (final vehicle in archived)
                  Opacity(
                    opacity: 0.6,
                    child: _VehicleTile(vehicle: vehicle),
                  ),
              ],
            ],
          );
        },
      ),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              heroTag: const ValueKey('add-vehicle-fab'),
              icon: const Icon(Icons.add_rounded),
              label: Text(l10n.vehicle_add),
              onPressed: () => context.push('/vehicles/new'),
            )
          : null,
    );
  }
}

class _VehicleTile extends StatelessWidget {
  const _VehicleTile({required this.vehicle});

  final Vehicle vehicle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final subtitleParts = <String>[
      fuelTypeLabel(context, vehicle.fuelType),
      l10n.vehicle_odometer_value(vehicle.currentOdometerKm.toStringAsFixed(0)),
      if (vehicle.plate != null && vehicle.plate!.isNotEmpty) vehicle.plate!,
    ];

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: scheme.primaryContainer,
        child: Icon(fuelTypeIcon(vehicle.fuelType), color: scheme.onPrimaryContainer),
      ),
      title: Text(vehicle.name),
      subtitle: Text(subtitleParts.join('  •  ')),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => context.push('/vehicles/${vehicle.id}'),
    );
  }
}

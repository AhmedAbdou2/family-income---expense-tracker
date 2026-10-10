import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../household/domain/entities.dart';
import '../../household/presentation/home_shell.dart';
import '../../household/presentation/providers.dart';
import '../domain/entities.dart';
import 'pet_visuals.dart';
import 'providers.dart';

/// Pet list (owner/adult only - a child's RLS returns nothing, so the add
/// control is hidden too).
class PetsScreen extends ConsumerWidget {
  const PetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final membership = ref.watch(membershipProvider).value;
    final canManage = switch (membership?.role) {
      MemberRole.owner || MemberRole.adult => true,
      _ => false,
    };
    final pets = ref.watch(petsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: ShellScope.maybeOf(context) == null
            ? null
            : const ShellMenuButton(),
        title: Text(l10n.pets_title),
        actions: [
          if (canManage)
            IconButton(
              tooltip: l10n.pet_add,
              icon: const Icon(Icons.add_rounded),
              onPressed: () => context.push('/pets/new'),
            ),
        ],
      ),
      body: pets.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(petsProvider),
        ),
        data: (list) {
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.pets_outlined,
              title: l10n.pets_empty_title,
              body: l10n.pets_empty_body,
            );
          }
          final active = list.where((pet) => pet.isActive).toList();
          final archived = list.where((pet) => !pet.isActive).toList();
          return ListView(
            padding: const EdgeInsetsDirectional.only(bottom: 96),
            children: [
              for (final pet in active) _PetTile(pet: pet),
              if (archived.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    start: 20, end: 20, top: 20, bottom: 6,
                  ),
                  child: Text(
                    l10n.pet_archived,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ),
                for (final pet in archived)
                  Opacity(
                    opacity: 0.6,
                    child: _PetTile(pet: pet),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _PetTile extends StatelessWidget {
  const _PetTile({required this.pet});

  final Pet pet;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final parts = <String>[
      petTypeLabel(context, pet.type),
      if (pet.notes != null && pet.notes!.isNotEmpty) pet.notes!,
    ];

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: scheme.primaryContainer,
        child: Icon(petTypeIcon(pet.type), color: scheme.onPrimaryContainer),
      ),
      title: Text(pet.name),
      subtitle: parts.isEmpty ? null : Text(parts.join('  •  ')),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => context.push('/pets/${pet.id}'),
    );
  }
}

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
import '../../categories/presentation/category_visuals.dart';
import '../../categories/presentation/providers.dart';
import '../../household/presentation/providers.dart';
import '../../members/domain/entities.dart';
import '../../members/presentation/providers.dart';
import '../../transactions/domain/entities.dart';
import '../../transactions/presentation/providers.dart';
import '../../transactions/presentation/transaction_delete.dart';
import '../domain/entities.dart';
import 'pet_visuals.dart';
import 'providers.dart';

/// One pet: header, this month's spend and expense list. Adults only (RLS
/// hides the data from children).
class PetDetailScreen extends ConsumerStatefulWidget {
  const PetDetailScreen({super.key, required this.petId});

  final String petId;

  @override
  ConsumerState<PetDetailScreen> createState() => _PetDetailScreenState();
}

class _PetDetailScreenState extends ConsumerState<PetDetailScreen> {
  Pet? _findPet(List<Pet> list) {
    for (final pet in list) {
      if (pet.id == widget.petId) return pet;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toString();
    final arabicDigits = ref.watch(settingsProvider).arabicDigits;
    final currency = ref.watch(membershipProvider).value?.household.currency;
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final pets = ref.watch(petsProvider);

    if (pets.isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.pets_title)),
        body: const LoadingView(),
      );
    }
    if (pets.hasError) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.pets_title)),
        body: ErrorView(
          error: pets.error!,
          onRetry: () => ref.invalidate(petsProvider),
        ),
      );
    }

    final pet = _findPet(pets.value ?? const <Pet>[]);
    if (pet == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.pets_title)),
        body: ErrorView(error: StateError(l10n.error_invalid_pet)),
      );
    }

    final transactions = ref.watch(petMonthTransactionsProvider(pet.id));

    return Scaffold(
      appBar: AppBar(
        title: Text(pet.name),
        actions: [
          IconButton(
            tooltip: l10n.pet_edit,
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.push('/pets/edit/${pet.id}'),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'toggle') _toggleArchive(pet);
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'toggle',
                child: Text(pet.isActive ? l10n.pet_archive : l10n.pet_restore),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsetsDirectional.only(bottom: 96),
        children: [
          _PetHeaderCard(pet: pet),
          _SectionHeader(
            title: l10n.pet_expenses_title,
            action: FilledButton.tonalIcon(
              style: AppButtons.inline,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(l10n.pet_add_expense),
              onPressed: () =>
                  context.push('/transactions/new?petId=${pet.id}'),
            ),
          ),
          transactions.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Padding(
              padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
              child: ErrorBanner(error: error),
            ),
            data: (list) {
              var total = 0;
              for (final transaction in list) {
                if (transaction.type == TransactionType.expense) {
                  total += transaction.amountMinorUnits;
                }
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        l10n.pet_monthly_total(
                          Money.format(
                            minorUnits: total,
                            arabicDigits: arabicDigits,
                            currencyCode: currency,
                          ),
                        ),
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  if (list.isEmpty)
                    Padding(
                      padding:
                          const EdgeInsetsDirectional.symmetric(horizontal: 20),
                      child: Text(
                        l10n.pet_expenses_empty,
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    )
                  else
                    for (final transaction in list)
                      _PetExpenseTile(
                        transaction: transaction,
                        categoryName: () {
                          final matches = categories
                              .where((c) => c.id == transaction.categoryId);
                          if (matches.isEmpty) return l10n.category;
                          return matches.first.localizedName(
                            Localizations.localeOf(context).languageCode,
                          );
                        }(),
                        icon: () {
                          final matches = categories
                              .where((c) => c.id == transaction.categoryId);
                          return matches.isEmpty
                              ? Icons.receipt_long_outlined
                              : iconFor(matches.first.icon);
                        }(),
                        colorHex: () {
                          final matches = categories
                              .where((c) => c.id == transaction.categoryId);
                          return matches.isEmpty
                              ? '#78909C'
                              : matches.first.color;
                        }(),
                        amountLabel: Money.format(
                          minorUnits: transaction.amountMinorUnits,
                          arabicDigits: arabicDigits,
                          currencyCode: currency,
                        ),
                        date: DateFormat.yMMMd(locale).format(transaction.date),
                      ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _toggleArchive(Pet pet) async {
    final l10n = context.l10n;
    if (pet.isActive) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(dialogContext.l10n.pet_archive_confirm_title),
          content: Text(dialogContext.l10n.pet_archive_confirm_body),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(dialogContext.l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(dialogContext.l10n.pet_archive),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    try {
      await ref.read(petsRepositoryProvider).updatePet(
            id: pet.id,
            name: pet.name,
            type: pet.type,
            isActive: !pet.isActive,
            birthDate: pet.birthDate,
            notes: pet.notes,
          );
      ref.invalidate(petsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.pet_saved)));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorMessage(context, error))));
      }
    }
  }
}

class _PetHeaderCard extends StatelessWidget {
  const _PetHeaderCard({required this.pet});

  final Pet pet;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toString();
    final parts = <String>[
      petTypeLabel(context, pet.type),
      if (pet.birthDate != null)
        DateFormat.yMMMd(locale).format(pet.birthDate!),
      if (pet.notes != null && pet.notes!.isNotEmpty) pet.notes!,
    ];

    return Card(
      margin: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: scheme.primaryContainer,
          child: Icon(petTypeIcon(pet.type), color: scheme.onPrimaryContainer),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                pet.name,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            if (!pet.isActive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  l10n.pet_archived,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
          ],
        ),
        subtitle: parts.isEmpty ? null : Text(parts.join('  •  ')),
      ),
    );
  }
}

class _PetExpenseTile extends ConsumerWidget {
  const _PetExpenseTile({
    required this.transaction,
    required this.categoryName,
    required this.icon,
    required this.colorHex,
    required this.amountLabel,
    required this.date,
  });

  final Transaction transaction;
  final String categoryName;
  final IconData icon;
  final String colorHex;
  final String amountLabel;
  final String date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isExpense = transaction.type == TransactionType.expense;
    final color = colorFromHex(colorHex);
    return Dismissible(
      key: Key('pet_${transaction.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        await _confirmAndDelete(context, ref);
        return false;
      },
      background: Container(
        color: Theme.of(context).colorScheme.errorContainer,
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsetsDirectional.only(end: 16),
        child: Icon(Icons.delete_outline_rounded,
            color: Theme.of(context).colorScheme.onErrorContainer),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.18),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(categoryName),
        subtitle: Text(date),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${isExpense ? '-' : '+'} $amountLabel',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: isExpense
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.primary,
              ),
            ),
            IconButton(
              tooltip: context.l10n.delete_action,
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () => _confirmAndDelete(context, ref),
            ),
          ],
        ),
        onTap: () => context.push('/transactions/edit/${transaction.id}'),
      ),
    );
  }

  Future<void> _confirmAndDelete(BuildContext context, WidgetRef ref) async {
    final members = ref.read(membersProvider).value ?? const <Member>[];
    var personName = context.l10n.person;
    for (final member in members) {
      if (member.id == transaction.memberId) {
        personName = member.name;
        break;
      }
    }
    final fuelLinked = await isFuelLinkedTransaction(ref, transaction.id);
    if (!context.mounted) return;
    final result = await showTransactionDeleteDialog(
      context,
      categoryName: categoryName,
      personLabel: personName,
      dateLabel: date,
      amountLabel:
          '${transaction.type == TransactionType.expense ? '-' : '+'} $amountLabel',
      isExpense: transaction.type == TransactionType.expense,
      fromFixed: transaction.recurringRuleId != null,
      fuelLinked: fuelLinked,
      vehicleLinked: transaction.vehicleId != null,
    );
    if (result == null || !result.confirmed || !context.mounted) return;
    final l10n = context.l10n;
    try {
      await deleteTransactionCascade(
        ref: ref,
        transaction: transaction,
        pauseRule: result.pauseRule,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.transaction_deleted)),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage(context, error))),
        );
      }
    }
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

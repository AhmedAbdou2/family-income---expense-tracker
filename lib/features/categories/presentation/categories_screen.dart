import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../household/domain/entities.dart';
import '../../household/presentation/providers.dart';
import '../domain/entities.dart';
import 'category_visuals.dart';
import 'providers.dart';

String groupLabel(BuildContext context, CategoryGroup group) {
  final l10n = context.l10n;
  return switch (group) {
    CategoryGroup.general => l10n.group_general,
    CategoryGroup.car => l10n.group_car,
    CategoryGroup.fixed => l10n.group_fixed,
    CategoryGroup.pet => l10n.group_pet,
    CategoryGroup.income => l10n.group_income,
  };
}

/// Manage categories (owner/adult only - children get a read-only list;
/// the app hides the add/edit controls because RLS would deny the writes
/// anyway).
class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  bool _canManage(MemberRole role) =>
      role == MemberRole.owner || role == MemberRole.adult;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final membership = ref.watch(membershipProvider).value;
    final categories = ref.watch(categoriesProvider);
    final canManage = membership != null && _canManage(membership.role);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.categories_title)),
      body: categories.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(categoriesProvider),
        ),
        data: (list) {
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.category_outlined,
              title: l10n.categories_title,
              body: l10n.category_add,
            );
          }
          return ListView(
            padding: const EdgeInsetsDirectional.only(bottom: 96),
            children: [
              for (final group in CategoryGroup.values)
                if (list.any((category) => category.group == group)) ...[
                  _GroupHeader(title: groupLabel(context, group)),
                  for (final category in list
                      .where((category) => category.group == group))
                    _CategoryTile(category: category, canManage: canManage),
                ],
            ],
          );
        },
      ),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              // Unique tag: must never match the shell's quick-add FAB,
              // or the two would fly into each other across routes.
              heroTag: const ValueKey('add-category-fab'),
              icon: const Icon(Icons.add_rounded),
              label: Text(l10n.category_add),
              onPressed: () => showCategoryEditor(context, ref),
            )
          : null,
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 20, end: 20, top: 20, bottom: 6),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}

class _CategoryTile extends ConsumerWidget {
  const _CategoryTile({required this.category, required this.canManage});

  final Category category;
  final bool canManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final languageCode = Localizations.localeOf(context).languageCode;
    final l10n = context.l10n;

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: colorFromHex(category.color).withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(iconFor(category.icon), color: colorFromHex(category.color)),
      ),
      title: Text(category.localizedName(languageCode)),
      subtitle: Text(category.nameEn == category.nameAr
          ? category.nameEn
          : '${category.nameEn} • ${category.nameAr}'),
      trailing: canManage
          ? PopupMenuButton<String>(
              onSelected: (action) async {
                if (action == 'edit') {
                  await showCategoryEditor(context, ref, existing: category);
                } else if (action == 'delete') {
                  await _delete(context, ref);
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(value: 'edit', child: Text(l10n.category_edit)),
                PopupMenuItem(value: 'delete', child: Text(l10n.delete_action)),
              ],
            )
          : null,
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.category_delete_confirm_title),
        content: Text(dialogContext.l10n.category_delete_confirm_body),
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
    if (confirmed != true || !context.mounted) return;
    try {
      await ref
          .read(categoriesRepositoryProvider)
          .deleteCategory(categoryId: category.id);
      ref.invalidate(categoriesProvider);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage(context, error))),
        );
      }
    }
  }
}

/// Create/edit dialog. [existing] != null switches to edit mode (the
/// group is fixed after creation).
Future<void> showCategoryEditor(
  BuildContext context,
  WidgetRef ref, {
  Category? existing,
}) async {
  final nameEn = TextEditingController(text: existing?.nameEn ?? '');
  final nameAr = TextEditingController(text: existing?.nameAr ?? '');
  var group = existing?.group ?? CategoryGroup.general;
  var icon = existing?.icon ?? 'category';
  var color = existing?.color ?? '#78909C';

  final saved = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setState) => AlertDialog(
        title: Text(
          existing == null
              ? dialogContext.l10n.category_add
              : dialogContext.l10n.category_edit,
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameEn,
                maxLength: 60,
                decoration: InputDecoration(
                  labelText: dialogContext.l10n.category_name_en,
                  counterText: '',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: nameAr,
                maxLength: 60,
                textDirection: TextDirection.rtl,
                decoration: InputDecoration(
                  labelText: dialogContext.l10n.category_name_ar,
                  counterText: '',
                ),
              ),
              if (existing == null) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<CategoryGroup>(
                  initialValue: group,
                  decoration: InputDecoration(
                    labelText: dialogContext.l10n.category_group,
                  ),
                  items: [
                    for (final value in CategoryGroup.values)
                      DropdownMenuItem(
                        value: value,
                        child: Text(groupLabel(dialogContext, value)),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => group = value);
                  },
                ),
              ],
              const SizedBox(height: 12),
              Text(
                dialogContext.l10n.category_icon,
                style: Theme.of(dialogContext).textTheme.labelLarge,
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final entry in kCategoryIcons.entries)
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => setState(() => icon = entry.key),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: icon == entry.key
                              ? Theme.of(dialogContext).colorScheme.primaryContainer
                              : Theme.of(dialogContext)
                                  .colorScheme
                                  .surfaceContainerHighest,
                        ),
                        child: Icon(
                          entry.value,
                          size: 20,
                          color: icon == entry.key
                              ? Theme.of(dialogContext)
                                  .colorScheme
                                  .onPrimaryContainer
                              : Theme.of(dialogContext).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                dialogContext.l10n.category_color,
                style: Theme.of(dialogContext).textTheme.labelLarge,
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final hex in kCategoryColors)
                    InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: () => setState(() => color = hex),
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colorFromHex(hex),
                          border: color == hex
                              ? Border.all(
                                  color: Theme.of(dialogContext)
                                      .colorScheme
                                      .onSurface,
                                  width: 3,
                                )
                              : null,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(dialogContext.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(dialogContext.l10n.save),
          ),
        ],
      ),
    ),
  );

  if (saved != true || !context.mounted) return;
  final en = nameEn.text.trim();
  final ar = nameAr.text.trim();
  if (en.isEmpty || ar.isEmpty) return;

  try {
    final repository = ref.read(categoriesRepositoryProvider);
    if (existing == null) {
      final membership = ref.read(membershipProvider).value;
      if (membership == null) return;
      await repository.createCategory(
        householdId: membership.household.id,
        group: group,
        nameEn: en,
        nameAr: ar,
        icon: icon,
        color: color,
      );
    } else {
      await repository.updateCategory(
        categoryId: existing.id,
        nameEn: en,
        nameAr: ar,
        icon: icon,
        color: color,
      );
    }
    ref.invalidate(categoriesProvider);
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage(context, error))),
      );
    }
  }
}

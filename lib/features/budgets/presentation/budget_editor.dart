import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/error_view.dart';
import '../../categories/domain/entities.dart';
import '../../categories/presentation/providers.dart';
import '../domain/entities.dart';
import 'providers.dart';

/// Which kind of limit the editor is setting.
enum BudgetEditorMode { category, overall }

/// Opens the create/edit dialog for a limit. Returns true when a limit was
/// saved (so the caller can show a confirmation).
Future<bool> showBudgetEditor(
  BuildContext context, {
  required String householdId,
  required BudgetEditorMode mode,
  Budget? existing,
}) async {
  final saved = await showDialog<bool>(
    context: context,
    builder: (_) => _BudgetEditorDialog(
      householdId: householdId,
      mode: mode,
      existing: existing,
    ),
  );
  return saved ?? false;
}

/// "Delete this limit?" confirmation shared by every delete entry point.
Future<bool> confirmDeleteBudget(BuildContext context) async {
  final l10n = context.l10n;
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.budget_delete_confirm_title),
      content: Text(l10n.budget_delete_confirm_body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(l10n.delete_action),
        ),
      ],
    ),
  );
  return result ?? false;
}

class _BudgetEditorDialog extends ConsumerStatefulWidget {
  const _BudgetEditorDialog({
    required this.householdId,
    required this.mode,
    this.existing,
  });

  final String householdId;
  final BudgetEditorMode mode;
  final Budget? existing;

  @override
  ConsumerState<_BudgetEditorDialog> createState() =>
      _BudgetEditorDialogState();
}

class _BudgetEditorDialogState extends ConsumerState<_BudgetEditorDialog> {
  late final TextEditingController _amount = TextEditingController(
    text: widget.existing == null
        ? ''
        : Money.minorUnitsToDecimalString(widget.existing!.amountMinorUnits),
  );
  String? _categoryId;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _categoryId = widget.existing?.categoryId;
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final text = _amount.text.trim();
    int? minorUnits;
    try {
      minorUnits = Money.decimalStringToMinorUnits(text);
    } on FormatException {
      minorUnits = null;
    }
    if (minorUnits == null || minorUnits <= 0) {
      setState(() => _error = l10n.error_invalid_value);
      return;
    }
    if (widget.mode == BudgetEditorMode.category && _categoryId == null) {
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    final repository = ref.read(budgetsRepositoryProvider);
    try {
      if (widget.mode == BudgetEditorMode.overall) {
        await repository.setOverallBudget(
          householdId: widget.householdId,
          amountMinorUnits: minorUnits,
        );
      } else {
        await repository.setCategoryBudget(
          householdId: widget.householdId,
          categoryId: _categoryId!,
          amountMinorUnits: minorUnits,
        );
      }
      ref.invalidate(budgetsProvider);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = errorMessage(context, error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final languageCode = Localizations.localeOf(context).languageCode;
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final budgets = ref.watch(budgetsProvider).value ?? const [];
    final budgeted = <String>{
      for (final budget in budgets)
        if (budget.categoryId != null) budget.categoryId!,
    };
    final eligible = [
      for (final category in categories)
        if (category.group != CategoryGroup.income &&
            (!budgeted.contains(category.id) ||
                category.id == widget.existing?.categoryId))
          category,
    ];

    final isOverall = widget.mode == BudgetEditorMode.overall;
    final title = widget.existing != null
        ? l10n.budget_edit
        : (isOverall ? l10n.budget_add_overall : l10n.budget_add);

    return AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!isOverall) ...[
              DropdownButtonFormField<String>(
                initialValue: _categoryId,
                decoration: InputDecoration(labelText: l10n.category),
                items: [
                  for (final category in eligible)
                    DropdownMenuItem(
                      value: category.id,
                      child: Text(
                        category.localizedName(languageCode),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged:
                    _saving ? null : (value) => setState(() => _categoryId = value),
              ),
              const SizedBox(height: 14),
            ] else
              Padding(
                padding: const EdgeInsetsDirectional.only(bottom: 14),
                child: Text(
                  l10n.budget_overall_hint,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            TextField(
              controller: _amount,
              enabled: !_saving,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: InputDecoration(
                labelText: l10n.budget_amount_label,
                hintText: l10n.budget_amount_hint,
              ),
              onSubmitted: (_) => _save(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(l10n.save),
        ),
      ],
    );
  }
}

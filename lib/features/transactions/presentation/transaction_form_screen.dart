import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/settings/preferences.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../categories/domain/entities.dart';
import '../../categories/presentation/category_visuals.dart';
import '../../categories/presentation/categories_screen.dart';
import '../../categories/presentation/providers.dart';
import '../../household/presentation/providers.dart';
import '../../members/domain/entities.dart';
import '../../members/presentation/providers.dart';
import '../../pets/domain/entities.dart';
import '../../pets/presentation/pet_visuals.dart';
import '../../pets/presentation/providers.dart';
import '../../recurring/domain/entities.dart';
import '../../recurring/presentation/providers.dart';
import '../domain/entities.dart';
import 'providers.dart';

/// Full add/edit form. Reached from quick-add's "More options" and by
/// tapping a row in the list (`/transactions/edit/:id`).
class TransactionFormScreen extends ConsumerStatefulWidget {
  const TransactionFormScreen({super.key, this.transactionId, this.initialPetId});

  final String? transactionId;

  /// Pre-selects a pet (the pet detail screen's "Add expense" action).
  final String? initialPetId;

  @override
  ConsumerState<TransactionFormScreen> createState() =>
      _TransactionFormScreenState();
}

class _TransactionFormScreenState
    extends ConsumerState<TransactionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  TransactionType _type = TransactionType.expense;
  String? _categoryId;
  String? _memberId;
  String? _petId;
  DateTime _date = DateTime.now();
  Transaction? _existing;
  bool _loading = true;
  bool _saving = false;
  String? _saveError;

  bool get _isEdit => widget.transactionId != null;

  @override
  void initState() {
    super.initState();
    _petId = widget.initialPetId;
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    if (widget.transactionId == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final transaction = await ref
          .read(transactionsRepositoryProvider)
          .getTransaction(id: widget.transactionId!);
      if (transaction == null) throw StateError('missing transaction');
      if (!mounted) return;
      setState(() {
        _existing = transaction;
        _type = transaction.type;
        _amountController.text =
            Money.minorUnitsToDecimalString(transaction.amountMinorUnits);
        _categoryId = transaction.categoryId;
        _memberId = transaction.memberId;
        _petId = transaction.petId;
        _date = transaction.date;
        _noteController.text = transaction.note ?? '';
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() => _loading = false);
        _saveError = error.toString();
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final categories = ref.watch(categoriesProvider).value ?? const <Category>[];
    final members = ref.watch(membersProvider).value ?? const <Member>[];
    final pets = ref.watch(petsProvider).value ?? const <Pet>[];
    final membership = ref.watch(membershipProvider).value;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.nav_transactions)),
        body: const LoadingView(),
      );
    }

    if (_saveError != null && _existing == null && _isEdit) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.transaction_edit_title)),
        body: ErrorView(error: StateError(_saveError!)),
      );
    }

    // Keep selections valid when the type toggles (income shows only the
    // income group, expenses the other three).
    final visibleCategories =
        categories.where((category) => _inType(category, _type)).toList();
    if (_categoryId != null &&
        !visibleCategories.any((category) => category.id == _categoryId)) {
      _categoryId = null;
    }
    if (_memberId != null && !members.any((member) => member.id == _memberId)) {
      _memberId = null;
    }
    if (_petId != null && !pets.any((pet) => pet.id == _petId)) {
      _petId = null;
    }

    final categoryMatches =
        visibleCategories.where((c) => c.id == _categoryId);
    final category = categoryMatches.isEmpty ? null : categoryMatches.first;
    final memberMatches = members.where((m) => m.id == _memberId);
    final member = memberMatches.isEmpty ? null : memberMatches.first;
    final petMatches = pets.where((p) => p.id == _petId);
    final pet = petMatches.isEmpty ? null : petMatches.first;
    final languageCode = Localizations.localeOf(context).languageCode;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEdit ? l10n.transaction_edit_title : l10n.transaction_new_title,
        ),
        actions: [
          if (_isEdit)
            IconButton(
              tooltip: l10n.transaction_delete,
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: _saving ? null : () => _delete(),
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
            SegmentedButton<TransactionType>(
              segments: [
                ButtonSegment(
                  value: TransactionType.expense,
                  label: Text(l10n.type_expense),
                  icon: const Icon(Icons.arrow_upward_rounded),
                ),
                ButtonSegment(
                  value: TransactionType.income,
                  label: Text(l10n.type_income),
                  icon: const Icon(Icons.arrow_downward_rounded),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (selection) =>
                  setState(() => _type = selection.first),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountController,
              autofocus: !_isEdit,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: l10n.amount,
                prefixText: _type == TransactionType.expense ? '- ' : '+ ',
                suffixText: membership?.household.currency,
              ),
              validator: (_) {
                final raw = _amountController.text.trim();
                int? minor;
                try {
                  minor = Money.decimalStringToMinorUnits(raw);
                } on FormatException {
                  return l10n.amount_invalid;
                }
                if (minor <= 0) return l10n.amount_zero;
                return null;
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                category == null
                    ? Icons.category_outlined
                    : iconFor(category.icon),
                color: category == null ? null : colorFromHex(category.color),
              ),
              title: Text(category?.localizedName(languageCode) ??
                  l10n.select_category),
              subtitle: category == null ? null : Text(groupLabel(context, category.group)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _pickCategory(visibleCategories),
            ),
            const Divider(height: 1),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.person_outline_rounded),
              title:
                  Text(member?.name ?? l10n.select_person),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _pickMember(members),
            ),
            const Divider(height: 1),
            if (_type == TransactionType.expense && pets.isNotEmpty) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  pet == null ? Icons.pets_rounded : petTypeIcon(pet.type),
                ),
                title: Text(pet?.name ?? l10n.transaction_none),
                subtitle: Text(l10n.transaction_pet),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _pickPet(pets),
              ),
              const Divider(height: 1),
            ],
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
              controller: _noteController,
              maxLength: 200,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: l10n.note,
                counterText: '',
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.check_rounded),
              label: Text(l10n.save),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _saving ? null : _makeFixed,
              icon: const Icon(Icons.event_repeat_rounded),
              label: Text(l10n.transaction_pin_fixed),
            ),
          ],
        ),
      ),
    );
  }

  bool _inType(Category category, TransactionType type) =>
      type == TransactionType.income
          ? category.group == CategoryGroup.income
          : category.group != CategoryGroup.income;

  Future<void> _pickCategory(List<Category> categories) async {
    final selected = await showDialog<Category>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(dialogContext.l10n.category),
        children: [
          for (final category in categories)
            SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop(category),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: colorFromHex(category.color)
                          .withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      iconFor(category.icon),
                      size: 18,
                      color: colorFromHex(category.color),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(category.localizedName(
                    Localizations.localeOf(dialogContext).languageCode,
                  )),
                ],
              ),
            ),
        ],
      ),
    );
    if (selected != null) setState(() => _categoryId = selected.id);
  }

  Future<void> _pickMember(List<Member> members) async {
    final selected = await showDialog<Member>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(dialogContext.l10n.person),
        children: [
          for (final member in members)
            SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop(member),
              child: Text(member.name),
            ),
        ],
      ),
    );
    if (selected != null) setState(() => _memberId = selected.id);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickPet(List<Pet> pets) async {
    final selected = await showDialog<Pet?>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(dialogContext.l10n.transaction_pet),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(dialogContext.l10n.transaction_none),
          ),
          for (final pet in pets)
            SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop(pet),
              child: Text(pet.name),
            ),
        ],
      ),
    );
    setState(() => _petId = selected?.id);
  }

  Future<void> _makeFixed() async {
    final l10n = context.l10n;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_categoryId == null || _memberId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.transaction_pin_fixed_confirm_title)),
      );
      return;
    }
    final membership = ref.read(membershipProvider).value;
    if (membership == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.transaction_pin_fixed_confirm_title),
        content: Text(dialogContext.l10n.transaction_pin_fixed_confirm_body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(dialogContext.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(dialogContext.l10n.transaction_pin_fixed),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final amountMinor =
        Money.decimalStringToMinorUnits(_amountController.text.trim());
    setState(() => _saving = true);
    try {
      await ref.read(recurringRulesRepositoryProvider).createRule(
            householdId: membership.household.id,
            categoryId: _categoryId!,
            memberId: _memberId!,
            amountMinorUnits: amountMinor,
            frequency: RecurrenceFrequency.monthly,
            dayOfMonth: _date.day,
            startDate: _date,
            name: _noteController.text,
            petId: _petId,
          );
      ref.invalidate(recurringRulesProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.transaction_pinned_fixed)),
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorMessage(context, error))));
      }
    }
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_categoryId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.select_category)));
      return;
    }
    if (_memberId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.select_person)));
      return;
    }

    final membership = ref.read(membershipProvider).value;
    if (membership == null) return;
    final amountMinor =
        Money.decimalStringToMinorUnits(_amountController.text.trim());

    setState(() => _saving = true);
    try {
      final repository = ref.read(transactionsRepositoryProvider);
      if (_isEdit) {
        await repository.updateTransaction(
          id: widget.transactionId!,
          type: _type,
          amountMinorUnits: amountMinor,
          categoryId: _categoryId!,
          memberId: _memberId!,
          date: _date,
          note: _noteController.text,
          petId: _petId,
        );
      } else {
        await repository.createTransaction(
          householdId: membership.household.id,
          type: _type,
          amountMinorUnits: amountMinor,
          categoryId: _categoryId!,
          memberId: _memberId!,
          date: _date,
          note: _noteController.text,
          petId: _petId,
        );
      }
      ref
        ..invalidate(monthTransactionsProvider)
        ..invalidate(dashboardMonthTransactionsProvider);
      await ref.read(preferencesProvider).setQuickAddDefaults(
            type: _type.dbValue,
            categoryId: _categoryId!,
            memberId: _memberId!,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.transaction_saved)));
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
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.transaction_delete_confirm_title),
        content: Text(dialogContext.l10n.transaction_delete_confirm_body),
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
          .read(transactionsRepositoryProvider)
          .deleteTransaction(id: widget.transactionId!);
      ref
        ..invalidate(monthTransactionsProvider)
        ..invalidate(dashboardMonthTransactionsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.transaction_deleted)));
      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorMessage(context, error))));
      }
    }
  }
}

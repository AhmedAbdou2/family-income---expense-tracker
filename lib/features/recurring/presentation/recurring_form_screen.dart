import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../core/l10n/l10n.dart';
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
import '../../transactions/domain/entities.dart';
import '../../transactions/presentation/providers.dart';
import '../../vehicles/domain/entities.dart';
import '../../vehicles/presentation/providers.dart';
import '../domain/entities.dart';
import 'providers.dart';
import 'recurring_visuals.dart';

/// Add/edit a recurring fixed commitment. `type` is derived from the
/// chosen category's group, never stored twice.
class RecurringFormScreen extends ConsumerStatefulWidget {
  const RecurringFormScreen({super.key, this.ruleId});

  final String? ruleId;

  @override
  ConsumerState<RecurringFormScreen> createState() =>
      _RecurringFormScreenState();
}

class _RecurringFormScreenState extends ConsumerState<RecurringFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _nameController = TextEditingController();
  final _dayController = TextEditingController();

  TransactionType _type = TransactionType.expense;
  String? _categoryId;
  String? _memberId;
  String? _vehicleId;
  String? _petId;
  RecurrenceFrequency _frequency = RecurrenceFrequency.monthly;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isActive = true;
  RecurringRule? _existing;
  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  bool get _isEdit => widget.ruleId != null;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    if (widget.ruleId == null) {
      setState(() {
        _startDate = DateTime.now();
        _loading = false;
      });
      return;
    }
    try {
      final rule = await ref
          .read(recurringRulesRepositoryProvider)
          .getRule(id: widget.ruleId!);
      if (rule == null) throw StateError('missing rule');
      if (!mounted) return;
      final categories = await ref.read(categoriesProvider.future);
      Category? category;
      for (final item in categories) {
        if (item.id == rule.categoryId) {
          category = item;
          break;
        }
      }
      if (!mounted) return;
      setState(() {
        _existing = rule;
        _categoryId = rule.categoryId;
        _memberId = rule.memberId;
        _vehicleId = rule.vehicleId;
        _petId = rule.petId;
        _amountController.text =
            Money.minorUnitsToDecimalString(rule.amountMinorUnits);
        _nameController.text = rule.name ?? '';
        _frequency = rule.frequency;
        _dayController.text = rule.dayOfMonth?.toString() ?? '';
        _startDate = rule.startDate ?? rule.nextDue;
        _endDate = rule.endDate;
        _isActive = rule.isActive;
        _type = category?.group == CategoryGroup.income
            ? TransactionType.income
            : TransactionType.expense;
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
    _amountController.dispose();
    _nameController.dispose();
    _dayController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final currency = ref.watch(membershipProvider).value?.household.currency;
    final categories = ref.watch(categoriesProvider).value ?? const <Category>[];
    final members = ref.watch(membersProvider).value ?? const <Member>[];
    final vehicles = ref.watch(vehiclesProvider).value ?? const <Vehicle>[];
    final pets = ref.watch(petsProvider).value ?? const <Pet>[];

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.recurring_add)),
        body: const LoadingView(),
      );
    }
    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.recurring_edit)),
        body: ErrorView(error: StateError(_loadError!)),
      );
    }

    final visibleCategories =
        categories.where((category) => _inType(category, _type)).toList();
    if (_categoryId != null &&
        !visibleCategories.any((category) => category.id == _categoryId)) {
      _categoryId = null;
    }
    if (_memberId != null && !members.any((member) => member.id == _memberId)) {
      _memberId = null;
    }
    if (_vehicleId != null &&
        !vehicles.any((vehicle) => vehicle.id == _vehicleId)) {
      _vehicleId = null;
    }
    if (_petId != null && !pets.any((pet) => pet.id == _petId)) {
      _petId = null;
    }

    final languageCode = Localizations.localeOf(context).languageCode;
    Category? category;
    for (final item in visibleCategories) {
      if (item.id == _categoryId) {
        category = item;
        break;
      }
    }
    Member? member;
    for (final item in members) {
      if (item.id == _memberId) {
        member = item;
        break;
      }
    }
    Vehicle? vehicle;
    for (final item in vehicles) {
      if (item.id == _vehicleId) {
        vehicle = item;
        break;
      }
    }
    Pet? pet;
    for (final item in pets) {
      if (item.id == _petId) {
        pet = item;
        break;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? l10n.recurring_edit : l10n.recurring_add),
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
              controller: _nameController,
              maxLength: 40,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: l10n.recurring_name,
                hintText: l10n.recurring_name_hint,
                counterText: '',
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: l10n.recurring_amount,
                suffixText: currency,
              ),
              validator: (_) {
                int? minor;
                try {
                  minor = Money.decimalStringToMinorUnits(
                    _amountController.text.trim(),
                  );
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
                category == null ? Icons.category_outlined : iconFor(category.icon),
                color: category == null ? null : colorFromHex(category.color),
              ),
              title: Text(category?.localizedName(languageCode) ??
                  l10n.select_category),
              subtitle:
                  category == null ? null : Text(groupLabel(context, category.group)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _pickCategory(visibleCategories),
            ),
            const Divider(height: 1),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.person_outline_rounded),
              title: Text(member?.name ?? l10n.select_person),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _pickMember(members),
            ),
            const Divider(height: 1),
            if (_type == TransactionType.expense && vehicles.isNotEmpty) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.directions_car_rounded),
                title: Text(vehicle?.name ?? l10n.recurring_link_none),
                subtitle: Text(l10n.recurring_link_vehicle),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _pickVehicle(vehicles),
              ),
              const Divider(height: 1),
            ],
            if (_type == TransactionType.expense && pets.isNotEmpty) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  pet == null ? Icons.pets_rounded : petTypeIcon(pet.type),
                ),
                title: Text(pet?.name ?? l10n.recurring_link_none),
                subtitle: Text(l10n.recurring_link_pet),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _pickPet(pets),
              ),
              const Divider(height: 1),
            ],
            DropdownButtonFormField<RecurrenceFrequency>(
              initialValue: _frequency,
              decoration: InputDecoration(labelText: l10n.recurring_frequency),
              items: [
                for (final frequency in RecurrenceFrequency.values)
                  DropdownMenuItem(
                    value: frequency,
                    child: Text(frequencyLabel(context, frequency)),
                  ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _frequency = value);
              },
            ),
            if (_frequency == RecurrenceFrequency.monthly) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _dayController,
                keyboardType: TextInputType.number,
                decoration:
                    InputDecoration(labelText: l10n.recurring_day_of_month),
                validator: (_) {
                  final raw = _dayController.text.trim();
                  if (raw.isEmpty) return null;
                  final day = int.tryParse(raw);
                  if (day == null || day < 1 || day > 31) {
                    return l10n.amount_invalid;
                  }
                  return null;
                },
              ),
            ],
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined),
              title: Text(l10n.recurring_start_date),
              subtitle: Text(
                _startDate == null
                    ? '—'
                    : DateFormat.yMMMd(locale).format(_startDate!),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _pickDate(isStart: true),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_busy_outlined),
              title: Text(l10n.recurring_end_date),
              subtitle: Text(
                _endDate == null
                    ? '—'
                    : DateFormat.yMMMd(locale).format(_endDate!),
              ),
              trailing: _endDate == null
                  ? const Icon(Icons.chevron_right_rounded)
                  : IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () => setState(() => _endDate = null),
                    ),
              onTap: () => _pickDate(isStart: false),
            ),
            if (_isEdit) ...[
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.recurring_active),
                subtitle: _isActive ? null : Text(l10n.recurring_inactive_hint),
                value: _isActive,
                onChanged: (value) => setState(() => _isActive = value),
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
                  Icon(iconFor(category.icon), color: colorFromHex(category.color)),
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

  Future<void> _pickVehicle(List<Vehicle> vehicles) async {
    final selected = await showDialog<Vehicle?>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(dialogContext.l10n.recurring_link_vehicle),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(dialogContext.l10n.recurring_link_none),
          ),
          for (final vehicle in vehicles)
            SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop(vehicle),
              child: Text(vehicle.name),
            ),
        ],
      ),
    );
    setState(() => _vehicleId = selected?.id);
  }

  Future<void> _pickPet(List<Pet> pets) async {
    final selected = await showDialog<Pet?>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(dialogContext.l10n.recurring_link_pet),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(dialogContext.l10n.recurring_link_none),
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

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (isStart ? _startDate : _endDate) ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
      } else {
        _endDate = picked;
      }
    });
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final membership = ref.read(membershipProvider).value;
    if (membership == null) return;
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
    final amountMinor =
        Money.decimalStringToMinorUnits(_amountController.text.trim());
    final dayOfMonth = _frequency == RecurrenceFrequency.monthly
        ? int.tryParse(_dayController.text.trim())
        : null;

    setState(() => _saving = true);
    try {
      final repository = ref.read(recurringRulesRepositoryProvider);
      if (_isEdit) {
        await repository.updateRule(
          id: widget.ruleId!,
          categoryId: _categoryId!,
          memberId: _memberId!,
          amountMinorUnits: amountMinor,
          frequency: _frequency,
          nextDue: _existing?.nextDue ?? DateTime.now(),
          isActive: _isActive,
          dayOfMonth: dayOfMonth,
          name: _nameController.text,
          startDate: _startDate,
          endDate: _endDate,
          vehicleId: _vehicleId,
          petId: _petId,
        );
      } else {
        await repository.createRule(
          householdId: membership.household.id,
          categoryId: _categoryId!,
          memberId: _memberId!,
          amountMinorUnits: amountMinor,
          frequency: _frequency,
          dayOfMonth: dayOfMonth,
          name: _nameController.text,
          startDate: _startDate,
          endDate: _endDate,
          vehicleId: _vehicleId,
          petId: _petId,
        );
      }
      // Post anything already due right away (idempotent).
      final created = await repository.generateDue();
      ref
        ..invalidate(recurringRulesProvider)
        ..invalidate(monthTransactionsProvider)
        ..invalidate(dashboardMonthTransactionsProvider);
      if (!mounted) return;
      if (created > 0) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.recurring_generated(created))));
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.recurring_saved)));
      }
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

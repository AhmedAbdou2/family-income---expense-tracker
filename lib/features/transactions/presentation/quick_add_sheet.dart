import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/settings/preferences.dart';
import '../../../core/settings/settings_controller.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/error_view.dart';
import '../../auth/presentation/providers.dart';
import '../../categories/domain/entities.dart';
import '../../categories/presentation/category_visuals.dart';
import '../../categories/presentation/providers.dart';
import '../../household/domain/entities.dart';
import '../../household/presentation/providers.dart';
import '../../members/domain/entities.dart';
import '../../members/presentation/providers.dart';
import '../domain/entities.dart';
import 'providers.dart';
import 'quick_add_amount_controller.dart';

/// Opens the keypad-first quick-add sheet. Pops with:
///   'saved' - a transaction was written
///   'more'  - user wants the full form (caller navigates)
///   null    - dismissed
Future<String?> showQuickAddSheet(BuildContext context) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => const _QuickAddSheet(),
    );

class _QuickAddSheet extends ConsumerStatefulWidget {
  const _QuickAddSheet();

  @override
  ConsumerState<_QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends ConsumerState<_QuickAddSheet> {
  final _amount = QuickAddAmountController();
  final _noteController = TextEditingController();

  TransactionType _type = TransactionType.expense;
  String? _categoryId;
  String? _memberId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(preferencesProvider);
    _type = prefs.quickAddType == TransactionType.income.dbValue
        ? TransactionType.income
        : TransactionType.expense;
    _categoryId = prefs.quickAddCategoryId;
    _memberId = prefs.quickAddMemberId;
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  bool _inType(Category category) =>
      _type == TransactionType.income
          ? category.group == CategoryGroup.income
          : category.group != CategoryGroup.income;

  /// Last-used category when it still fits the type; else the seeded
  /// "Other"; else the first visible one.
  Category? _resolveCategory(List<Category> categories) {
    final visible = categories.where(_inType).toList();
    if (visible.isEmpty) return null;
    for (final category in visible) {
      if (category.id == _categoryId) return category;
    }
    for (final category in visible) {
      if (category.nameEn == 'Other') return category;
    }
    return visible.first;
  }

  /// Last-used person when visible (a child's RLS list only holds their
  /// own row); else the first active one.
  Member? _resolveMember(List<Member> members) {
    for (final member in members) {
      if (member.id == _memberId) return member;
    }
    final active = members.where((member) => member.isActive).toList();
    return active.isEmpty ? (members.isEmpty ? null : members.first) : active.first;
  }

  /// A child may only ever record their own person - no chips, no choice.
  Member? _ownPerson(List<Member> members, String? me) {
    if (me == null) return null;
    for (final member in members) {
      if (member.userId == me) return member;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final categories = ref.watch(categoriesProvider).value ?? const <Category>[];
    final members = ref.watch(membersProvider).value ?? const <Member>[];
    final arabicDigits = ref.watch(settingsProvider).arabicDigits;
    final membership = ref.watch(membershipProvider).value;
    final currency = membership?.household.currency;
    final scheme = Theme.of(context).colorScheme;
    final isChild = membership?.role == MemberRole.child;

    final category = _resolveCategory(categories);
    final member =
        isChild ? _ownPerson(members, ref.watch(authStateProvider).value) : _resolveMember(members);
    final visibleCategories = categories.where(_inType).toList();
    final canSave = _amount.canSave && category != null && member != null;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.quick_add_title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),

          // Big amount readout.
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              currency == null || currency.isEmpty
                  ? _display(arabicDigits)
                  : '${_display(arabicDigits)} $currency',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          const SizedBox(height: 12),

          SegmentedButton<TransactionType>(
            showSelectedIcon: false,
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
            ),
            segments: [
              ButtonSegment(
                value: TransactionType.expense,
                label: Text(l10n.type_expense),
              ),
              ButtonSegment(
                value: TransactionType.income,
                label: Text(l10n.type_income),
              ),
            ],
            selected: {_type},
            onSelectionChanged: (selection) =>
                setState(() => _type = selection.first),
          ),
          const SizedBox(height: 12),

          // Category chips (last-used resolves as the default; only a
          // conscious tap overrides).
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final item in visibleCategories)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: ChoiceChip(
                      avatar: Icon(
                        iconFor(item.icon),
                        size: 16,
                        color: colorFromHex(item.color),
                      ),
                      label: Text(item.localizedName(
                        Localizations.localeOf(context).languageCode,
                      )),
                      selected: category?.id == item.id,
                      onSelected: (_) => setState(() => _categoryId = item.id),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Person chips. A child never picks: their spend is always
          // recorded as their own person (or is blocked when this login
          // has no person linked yet).
          if (isChild && member == null)
            Text(
              l10n.quick_add_no_person,
              style: TextStyle(color: scheme.error),
            )
          else if (!isChild)
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final item in members)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 8),
                      child: ChoiceChip(
                        avatar: const Icon(Icons.person_outline, size: 16),
                        label: Text(item.name),
                        selected: member?.id == item.id,
                        onSelected: (_) => setState(() => _memberId = item.id),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 8),

          TextField(
            controller: _noteController,
            maxLength: 200,
            decoration: InputDecoration(
              labelText: l10n.note,
              counterText: '',
            ),
          ),
          const SizedBox(height: 4),

          // Keypad.
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 2.4,
            children: [
              for (final key in const [
                '1', '2', '3', '4', '5', '6', '7', '8', '9', '.', '0',
              ])
                _KeyCap(
                  label: key,
                  arabicDigits: arabicDigits,
                  onTap: () => setState(() {
                    key == '.' ? _amount.inputDecimal() : _amount.inputDigit(key);
                  }),
                ),
              _KeyCap(
                label: '⌫',
                arabicDigits: false,
                onTap: () => setState(_amount.backspace),
              ),
            ],
          ),
          const SizedBox(height: 12),

          FilledButton(
            onPressed: canSave && !_saving ? _save : null,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.save),
          ),
          TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop('more'),
            child: Text(l10n.quick_add_more),
          ),
        ],
      ),
    );
  }

  String _display(bool arabicDigits) {
    final text = _amount.display;
    return arabicDigits ? Money.toArabicIndic(text) : text;
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final membership = ref.read(membershipProvider).value;
    if (membership == null) return;
    final categories = ref.read(categoriesProvider).value ?? const <Category>[];
    final members = ref.read(membersProvider).value ?? const <Member>[];
    final category = _resolveCategory(categories);
    final isChild = membership.role == MemberRole.child;
    final member = isChild
        ? _ownPerson(members, ref.read(authStateProvider).value)
        : _resolveMember(members);
    if (category == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.select_category)));
      return;
    }
    if (member == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isChild ? l10n.quick_add_no_person : l10n.select_person),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(transactionsRepositoryProvider).createTransaction(
            householdId: membership.household.id,
            type: _type,
            amountMinorUnits: _amount.minorUnits!,
            categoryId: category.id,
            memberId: member.id,
            date: DateTime.now(),
            note: _noteController.text,
          );
      ref
        ..invalidate(monthTransactionsProvider)
        ..invalidate(dashboardMonthTransactionsProvider);
      await ref.read(preferencesProvider).setQuickAddDefaults(
            type: _type.dbValue,
            categoryId: category.id,
            memberId: member.id,
          );
      if (!mounted) return;
      Navigator.of(context).pop('saved');
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage(context, error))),
        );
      }
    }
  }
}

class _KeyCap extends StatelessWidget {
  const _KeyCap({
    required this.label,
    required this.arabicDigits,
    required this.onTap,
  });

  final String label;
  final bool arabicDigits;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = arabicDigits ? Money.toArabicIndic(label) : label;
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Center(
          child: Text(
            text,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

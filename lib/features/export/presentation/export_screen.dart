import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/config/supabase_providers.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/settings/settings_controller.dart';
import '../../../core/utils/currency.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../categories/domain/entities.dart';
import '../../categories/presentation/providers.dart';
import '../../household/presentation/providers.dart';
import '../../members/domain/entities.dart';
import '../../members/presentation/providers.dart';
import '../../pets/domain/entities.dart';
import '../../pets/presentation/providers.dart';
import '../../transactions/domain/entities.dart';
import '../../vehicles/domain/entities.dart';
import '../../vehicles/presentation/providers.dart';
import '../data/export_repository_impl.dart';
import '../domain/csv_export.dart';
import '../domain/export_filter.dart';
import '../domain/export_repository.dart';
import '../domain/month_summary.dart';
import 'pdf_summary.dart';

final exportRepositoryProvider = Provider<ExportRepository>(
  (ref) => ExportRepositoryImpl(ref.watch(supabaseClientProvider)),
);

/// Cairo font bytes used by the Arabic PDF (registered in pubspec.yaml as a
/// font family - also readable from the asset bundle by path).
const String cairoRegularAsset = 'assets/fonts/Cairo-Regular.ttf';
const String cairoBoldAsset = 'assets/fonts/Cairo-Bold.ttf';

/// PDF export is wired on. The sample in docs/phase4b was reviewed and
/// approved; the machine checks (Cairo embedding, contextual forms, RTL
/// layout) still guard the output.
const bool pdfExportEnabled = true;

/// Adult-only export screen: pick a window + filters, then download the
/// rows as CSV (Excel-safe) or a one-page PDF summary.
class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key});

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  ExportFilter _filter = ExportFilter.thisMonth();
  bool _busy = false;
  String? _lastResult;

  Future<void> _pickDate({required bool isFrom}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _filter.from : _filter.to,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      _filter = isFrom
          ? _filter.copyWith(from: picked)
          : _filter.copyWith(to: picked);
      _lastResult = null;
    });
  }

  Future<void> _pickMember(List<Member> members) async {
    final picked = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(dialogContext.l10n.export_person),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.of(dialogContext).pop('__all__'),
            child: Text(dialogContext.l10n.export_all_people),
          ),
          for (final member in members)
            SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop(member.id),
              child: Text(member.name),
            ),
        ],
      ),
    );
    if (picked == null) return;
    setState(() {
      _filter = picked == '__all__'
          ? _filter.copyWith(clearMember: true)
          : _filter.copyWith(memberId: picked);
      _lastResult = null;
    });
  }

  Future<void> _pickCategory(List<Category> categories) async {
    final languageCode = Localizations.localeOf(context).languageCode;
    final picked = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(dialogContext.l10n.export_category),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.of(dialogContext).pop('__all__'),
            child: Text(dialogContext.l10n.export_all_categories),
          ),
          for (final category in categories)
            SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop(category.id),
              child: Text(category.localizedName(languageCode)),
            ),
        ],
      ),
    );
    if (picked == null) return;
    setState(() {
      _filter = picked == '__all__'
          ? _filter.copyWith(clearCategory: true)
          : _filter.copyWith(categoryId: picked);
      _lastResult = null;
    });
  }

  Future<void> _exportCsv() async {
    final membership = ref.read(membershipProvider).value;
    if (membership == null) return;
    await _run(() async {
      final rows = await _fetch();
      if (rows.isEmpty) {
        setState(() => _lastResult = context.l10n.export_empty);
        return;
      }
      final document = buildCsv(
        csvRowsFor(
          transactions: rows,
          categoryNames: _categoryNames(),
          memberNames: _memberNames(),
          currency: membership.household.currency,
          vehicleNames: _vehicleNames(),
          petNames: _petNames(),
        ),
      );
      final saved = await _save(
        fileName: 'transactions_${_stamp(_filter.from)}_'
            '${_stamp(_filter.to)}.csv',
        mime: 'text/csv',
        bytes: Uint8List.fromList(utf8.encode(document)),
      );
      if (saved) {
        setState(
          () => _lastResult = context.l10n.export_csv_done(rows.length),
        );
      }
    });
  }

  Future<void> _exportPdf() async {
    final l10n = context.l10n;
    final membership = ref.read(membershipProvider).value;
    if (membership == null) return;
    final locale = Localizations.localeOf(context);
    final isArabic = locale.languageCode == 'ar';
    final settings = ref.read(settingsProvider);

    await _run(() async {
      final rows = await _fetch();
      final summary = MonthSummary.fromTransactions(
        rows,
        categoryNames: _categoryNames(),
        memberNames: _memberNames(),
      );
      final chosen = rows.isEmpty ? _filter.from : _filter.to;
      final period = buildPeriodText(
        from: _filter.from,
        to: _filter.to,
        locale: locale.toString(),
        arabicDigits: settings.arabicDigits,
      );
      final bytes = await buildMonthSummaryPdf(
        labels: PdfSummaryLabels(
          title: l10n.export_pdf_title,
          householdLabel: l10n.export_household,
          periodLabel: l10n.export_period,
          incomeLabel: l10n.dashboard_income,
          expensesLabel: l10n.dashboard_expenses,
          balanceLabel: l10n.dashboard_balance,
          byCategoryLabel: l10n.report_by_category,
          byPersonLabel: l10n.report_by_person,
          emptyLabel: l10n.export_empty,
          footer: l10n.export_pdf_footer,
        ),
        householdName: membership.household.name,
        periodText: period,
        summary: summary,
        currencyCode: Currency.label(
          membership.household.currency,
          locale: locale.toString(),
        ),
        rtl: isArabic,
        arabicDigits: settings.arabicDigits,
        // Always embedded: a household on the English UI may still have Arabic
        // category or person names, which the Latin core fonts cannot render.
        regularFont: await _font(cairoRegularAsset),
        boldFont: await _font(cairoBoldAsset),
      );
      final saved = await _save(
        fileName: 'summary_${_stamp(_filter.from)}_${_stamp(chosen)}.pdf',
        mime: 'application/pdf',
        bytes: bytes,
      );
      if (saved) setState(() => _lastResult = l10n.export_pdf_done);
    });
  }

  Future<Uint8List> _font(String path) async {
    final data = await rootBundle.load(path);
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }

  /// Writes the bytes through the platform's save dialog. Returns false
  /// when the user cancelled (not an error).
  Future<bool> _save({
    required String fileName,
    required String mime,
    required Uint8List bytes,
  }) async {
    final saved = await FilePicker.saveFile(
      fileName: fileName,
      bytes: bytes,
      mimeType: mime,
    );
    return saved != null;
  }

  Future<List<Transaction>> _fetch() async {
    final membership = ref.read(membershipProvider).value;
    if (membership == null) return const <Transaction>[];
    final rows = await ref.read(exportRepositoryProvider).fetchForExport(
          householdId: membership.household.id,
          from: _filter.from,
          to: _filter.to,
        );
    return _filter.apply(rows);
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _lastResult = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage(context, error))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Map<String, String> _categoryNames() {
    final languageCode = Localizations.localeOf(context).languageCode;
    final categories = ref.read(categoriesProvider).value ?? const <Category>[];
    return {
      for (final category in categories)
        category.id: category.localizedName(languageCode),
    };
  }

  Map<String, String> _memberNames() => {
        for (final member
            in ref.read(membersProvider).value ?? const <Member>[])
          member.id: member.name,
      };

  Map<String, String> _vehicleNames() => {
        for (final vehicle
            in ref.read(vehiclesProvider).value ?? const <Vehicle>[])
          vehicle.id: vehicle.name,
      };

  Map<String, String> _petNames() => {
        for (final pet in ref.read(petsProvider).value ?? const <Pet>[])
          pet.id: pet.name,
      };

  String _stamp(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}'
      '${day.month.toString().padLeft(2, '0')}'
      '${day.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final members = ref.watch(membersProvider).value ?? const <Member>[];
    final categories = ref.watch(categoriesProvider).value ?? const <Category>[];
    final isLoading = ref.watch(membershipProvider).isLoading;
    final dayFormat = DateFormat.yMMMd(locale);

    final selectedMember = members.where((m) => m.id == _filter.memberId);
    final selectedCategory =
        categories.where((c) => c.id == _filter.categoryId);

    if (isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.export_title)),
        body: const LoadingView(),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.export_title)),
      body: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 32),
        children: [
          Text(
            l10n.export_intro,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          SegmentedButton<ExportTypeFilter>(
            segments: [
              ButtonSegment(
                value: ExportTypeFilter.all,
                label: Text(l10n.export_type_all),
              ),
              ButtonSegment(
                value: ExportTypeFilter.expenses,
                label: Text(l10n.type_expense),
              ),
              ButtonSegment(
                value: ExportTypeFilter.income,
                label: Text(l10n.type_income),
              ),
            ],
            selected: {_filter.type},
            onSelectionChanged: (selection) => setState(() {
              _filter = _filter.copyWith(type: selection.first);
              _lastResult = null;
            }),
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_outlined),
            title: Text(l10n.export_from),
            subtitle: Text(dayFormat.format(_filter.from)),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: _busy ? null : () => _pickDate(isFrom: true),
          ),
          const Divider(height: 1),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_available_outlined),
            title: Text(l10n.export_to),
            subtitle: Text(dayFormat.format(_filter.to)),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: _busy ? null : () => _pickDate(isFrom: false),
          ),
          const Divider(height: 1),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.person_outline_rounded),
            title: Text(l10n.export_person),
            subtitle: Text(
              selectedMember.isEmpty
                  ? l10n.export_all_people
                  : selectedMember.first.name,
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: _busy ? null : () => _pickMember(members),
          ),
          const Divider(height: 1),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.category_outlined),
            title: Text(l10n.export_category),
            subtitle: Text(
              selectedCategory.isEmpty
                  ? l10n.export_all_categories
                  : selectedCategory.first
                      .localizedName(Localizations.localeOf(context).languageCode),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: _busy ? null : () => _pickCategory(categories),
          ),
          if (!_filter.isValid) ...[
            const SizedBox(height: 12),
            ErrorBanner(
              error: const AppException(AppErrorCode.invalidValue),
            ),
          ],
          const SizedBox(height: 16),
          if (_busy) const LinearProgressIndicator(minHeight: 2),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _busy || !_filter.isValid ? null : _exportCsv,
            icon: const Icon(Icons.table_view_outlined),
            label: Text(l10n.export_csv_action),
          ),
          const SizedBox(height: 8),
          if (pdfExportEnabled)
            OutlinedButton.icon(
              onPressed: _busy || !_filter.isValid ? null : _exportPdf,
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: Text(l10n.export_pdf_action),
            ),
          if (_lastResult != null) ...[
            const SizedBox(height: 16),
            Text(
              _lastResult!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            l10n.export_hint,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (_filter.isValid) ...[
            const SizedBox(height: 8),
            Text(
              l10n.export_range_note(
                dayFormat.format(_filter.from),
                dayFormat.format(_filter.to),
              ),
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

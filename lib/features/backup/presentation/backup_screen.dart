import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/widgets/error_view.dart';
import '../../household/presentation/providers.dart';
import '../data/backup_service.dart';
import '../domain/backup_archive.dart';
import '../domain/backup_tables.dart';
import 'providers.dart';

/// Owner-only full household backup.
///
/// Reads every table (paged past PostgREST's ~1000-row cap), optionally
/// downloads every receipt object and packs a single ZIP the owner saves
/// themselves. The archive is a readable copy, NOT a restore, and it is not
/// encrypted - both stated on screen and in `docs/backup.md`.
class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  bool _busy = false;
  double? _progress;
  String? _lastResult;
  int _missing = 0;
  bool _dataOnlyLast = false;

  // Progress bookkeeping: tables + receipts make up the total work.
  int _tablesDone = 0;
  int _receiptsDone = 0;
  int _receiptsTotal = 0;

  void _updateProgress() {
    final total = backupTables.length + _receiptsTotal;
    final done = _tablesDone + _receiptsDone;
    if (!mounted) return;
    setState(() => _progress = total == 0 ? null : done / total);
  }

  Future<void> _run({required bool includeReceipts}) async {
    final l10n = context.l10n;
    final membership = ref.read(membershipProvider).value;
    if (membership == null) return;
    final householdId = membership.household.id;

    // Warn before a big download; refuse is handled by the disabled button.
    if (includeReceipts) {
      final estimate =
          ref.read(backupEstimateProvider(householdId)).value;
      if (estimate != null && estimate.status == BackupSizeStatus.warn) {
        final proceed = await _confirmLarge(estimate.receiptBytes);
        if (proceed != true) return;
      }
    }

    setState(() {
      _busy = true;
      _progress = 0;
      _lastResult = null;
      _missing = 0;
      _dataOnlyLast = false;
      _tablesDone = 0;
      _receiptsDone = 0;
      _receiptsTotal = ref.read(backupEstimateProvider(householdId)).value?.receiptCount ?? 0;
    });

    try {
      final outcome = await ref.read(backupServiceProvider).run(
            householdId: householdId,
            includeReceipts: includeReceipts,
            onTableProgress: (done, _) {
              _tablesDone = done;
              _updateProgress();
            },
            onReceiptProgress: (done, _) {
              _receiptsDone = done;
              _updateProgress();
            },
          );
      // Saving can throw too (e.g. the platform dialog) - the catch below
      // keeps the tab alive either way.
      final saved = await FilePicker.saveFile(
        fileName: outcome.fileName,
        bytes: outcome.zipBytes,
        mimeType: 'application/zip',
      );
      if (saved != null && mounted) {
        setState(() {
          _lastResult = l10n.backup_done;
          _missing = outcome.receiptsMissing;
          _dataOnlyLast = !includeReceipts;
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage(context, error))),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _progress = null;
        });
      }
    }
  }

  Future<bool?> _confirmLarge(int bytes) {
    final l10n = context.l10n;
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.backup_warn_title),
        content: Text(l10n.backup_warn_body(formatByteSize(bytes))),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.backup_warn_confirm),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final membership = ref.watch(membershipProvider).value;
    final householdId = membership?.household.id;

    final estimate = householdId == null
        ? null
        : ref.watch(backupEstimateProvider(householdId));
    final refuse = estimate?.value?.status == BackupSizeStatus.refuse;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.backup_title)),
      body: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 32),
        children: [
          Text(
            l10n.backup_intro,
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),

          // Unencrypted warning, stated plainly and up front.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: scheme.errorContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lock_open_outlined, color: scheme.onErrorContainer),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.backup_unencrypted_title,
                        style: TextStyle(
                          color: scheme.onErrorContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.backup_unencrypted_body,
                        style: TextStyle(color: scheme.onErrorContainer),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          _BackupSection(
            title: l10n.backup_included_title,
            body: l10n.backup_included_body,
          ),
          _BackupSection(
            title: l10n.backup_excluded_title,
            body: l10n.backup_excluded_body,
          ),
          const SizedBox(height: 8),

          // Receipt payload size.
          if (householdId != null) ...[
            _estimateLine(estimate),
            const SizedBox(height: 8),
          ],

          if (_busy) ...[
            LinearProgressIndicator(value: _progress, minHeight: 3),
            const SizedBox(height: 8),
            Text(
              l10n.backup_working,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
          ],

          FilledButton.icon(
            onPressed: _busy || refuse ? null : () => _run(includeReceipts: true),
            icon: const Icon(Icons.download_outlined),
            label: Text(l10n.backup_download_action),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _busy ? null : () => _run(includeReceipts: false),
            icon: const Icon(Icons.description_outlined),
            label: Text(l10n.backup_download_data_only_action),
          ),

          if (refuse) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: scheme.errorContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: scheme.onErrorContainer),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.backup_refuse_body(
                        formatByteSize(estimate!.value!.receiptBytes),
                      ),
                      style: TextStyle(color: scheme.onErrorContainer),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (_lastResult != null) ...[
            const SizedBox(height: 16),
            Text(
              _lastResult!,
              style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w600),
            ),
            if (_missing > 0) ...[
              const SizedBox(height: 6),
              Text(
                l10n.backup_missing_receipts(_missing),
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ],
            if (_dataOnlyLast) ...[
              const SizedBox(height: 6),
              Text(
                l10n.backup_data_only_note,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _estimateLine(AsyncValue<BackupEstimate>? estimate) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final style = TextStyle(fontSize: 13, color: scheme.onSurfaceVariant);

    if (estimate == null || estimate.isLoading) {
      return Text(l10n.backup_estimate_loading, style: style);
    }
    if (estimate.hasError) {
      return Row(
        children: [
          Expanded(
            child: Text(
              errorMessage(context, estimate.error!),
              style: style,
            ),
          ),
          TextButton(
            onPressed: () {
              final householdId = ref.read(membershipProvider).value?.household.id;
              if (householdId != null) {
                ref.invalidate(backupEstimateProvider(householdId));
              }
            },
            child: Text(l10n.retry),
          ),
        ],
      );
    }
    final value = estimate.value!;
    return Text(
      '${l10n.backup_receipts_count(value.receiptCount)} · '
      '${l10n.backup_receipts_size(formatByteSize(value.receiptBytes))}',
      style: style,
    );
  }
}

/// A titled paragraph used for the included/excluded lists.
class _BackupSection extends StatelessWidget {
  const _BackupSection({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleSmall),
          const SizedBox(height: 2),
          Text(
            body,
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

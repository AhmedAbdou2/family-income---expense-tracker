import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/error_view.dart';
import '../../household/domain/entities.dart';
import '../../household/presentation/providers.dart';
import '../domain/entities.dart';
import 'providers.dart';
import 'receipt_picker.dart';
import 'receipt_viewer.dart';

/// The receipts block of a transaction: list + add + remove.
///
/// Only rendered for an existing transaction (a receipt needs a
/// transaction id to live under), and only for owner/adult logins - a
/// child's RLS returns an empty list and the read-only rows simply stay
/// empty, while the add button is hidden by [showActions].
class ReceiptSection extends ConsumerStatefulWidget {
  const ReceiptSection({
    super.key,
    required this.transactionId,
    this.openPickerOnStart = false,
  });

  final String transactionId;

  /// True right after a NEW transaction was saved: the picker opens by
  /// itself so "save then attach" is a single flow.
  final bool openPickerOnStart;

  @override
  ConsumerState<ReceiptSection> createState() => _ReceiptSectionState();
}

class _ReceiptSectionState extends ConsumerState<ReceiptSection> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.openPickerOnStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _add());
    }
  }

  /// The handler-side permission check, where no rebuild is expected.
  ///
  /// In [build] the role is read with `ref.watch` instead: membership arrives
  /// from an async provider, so a one-shot read could paint the write buttons
  /// before the role is known and then never correct itself.
  bool get _mayWrite =>
      ref.read(membershipProvider).value?.role != MemberRole.child;

  Future<void> _add() async {
    if (_busy || !_mayWrite) return;
    final l10n = context.l10n;
    final current = ref.read(transactionReceiptsProvider(widget.transactionId));
    final loaded = current.value ?? const <Receipt>[];
    if (loaded.length >= maxReceiptsPerTransaction) {
      _snack(l10n.receipt_limit_hint(maxReceiptsPerTransaction));
      return;
    }

    final source = await showModalBottomSheet<ReceiptSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  sheetContext.l10n.receipt_add,
                  style: Theme.of(sheetContext).textTheme.titleMedium,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(sheetContext.l10n.receipt_add_camera),
              onTap: () =>
                  Navigator.of(sheetContext).pop(ReceiptSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(sheetContext.l10n.receipt_add_gallery),
              onTap: () =>
                  Navigator.of(sheetContext).pop(ReceiptSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.attach_file_rounded),
              title: Text(sheetContext.l10n.receipt_add_document),
              onTap: () =>
                  Navigator.of(sheetContext).pop(ReceiptSource.document),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final upload = await pickReceiptUpload(source);
      if (upload == null) return;
      await ref.read(receiptsRepositoryProvider).uploadReceipt(
            transactionId: widget.transactionId,
            upload: upload,
          );
      ref.invalidate(transactionReceiptsProvider(widget.transactionId));
      _snack(l10n.receipt_uploaded);
    } catch (error) {
      if (mounted) _snack(errorMessage(context, error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(Receipt receipt) async {
    if (_busy) return;
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.receipt_delete_confirm_title),
        content: Text(dialogContext.l10n.receipt_delete_confirm_body),
        actions: [
          TextButton(
            style: AppButtons.inline,
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(dialogContext.l10n.cancel),
          ),
          FilledButton(
            style: AppButtons.inline,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(dialogContext.l10n.delete_action),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(receiptsRepositoryProvider).deleteReceipt(
            receipt: receipt,
          );
      ref.invalidate(transactionReceiptsProvider(widget.transactionId));
      _snack(l10n.receipt_deleted);
    } catch (error) {
      if (mounted) _snack(errorMessage(context, error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final receipts = ref.watch(transactionReceiptsProvider(widget.transactionId));
    // Watched, not read: the role arrives asynchronously.
    final canWrite = ref.watch(membershipProvider).value?.role !=
        MemberRole.child;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.receipt_section_title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (receipts.hasValue)
              Text(
                l10n.receipt_count(
                  receipts.requireValue.length,
                  maxReceiptsPerTransaction,
                ),
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            if (canWrite)
              IconButton(
                onPressed: _busy ? null : _add,
                icon: const Icon(Icons.add_a_photo_outlined),
                tooltip: l10n.receipt_add,
              ),
          ],
        ),
        if (_busy) const LinearProgressIndicator(minHeight: 2),
        ...receipts.when(
          loading: () => const <Widget>[SizedBox(height: 8)],
          error: (error, _) => [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                errorMessage(context, error),
                style: TextStyle(color: scheme.error),
              ),
            ),
          ],
          data: (list) {
            if (list.isEmpty) {
              return [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    l10n.receipt_empty,
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ),
              ];
            }
            return list
                .map(
                  (receipt) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: ReceiptThumbnail(receipt: receipt),
                    title: Text(
                      receipt.isPdf
                          ? l10n.receipt_pdf_label
                          : receipt.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(receiptSizeLabel(receipt.sizeBytes)),
                    onTap: _busy
                        ? null
                        : () => showReceiptViewer(context, ref, receipt),
                    trailing: canWrite
                        ? IconButton(
                            onPressed: _busy ? null : () => _remove(receipt),
                            icon: const Icon(Icons.delete_outline_rounded),
                            tooltip: l10n.delete_action,
                          )
                        : null,
                  ),
                )
                .toList();
          },
        ),
        if (canWrite)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              l10n.receipt_limit_hint(maxReceiptsPerTransaction),
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ),
      ],
    );
  }
}
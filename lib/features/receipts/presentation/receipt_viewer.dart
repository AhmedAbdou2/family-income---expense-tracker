import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/error_view.dart';
import '../domain/entities.dart';
import 'providers.dart';

/// Opens a receipt: photos are shown inline (private bucket -> signed URL),
/// PDFs are handed to the platform's viewer.
Future<void> showReceiptViewer(
  BuildContext context,
  WidgetRef ref,
  Receipt receipt,
) async {
  final url = await ref.read(
    receiptSignedUrlProvider(receipt.storagePath).future,
  );
  if (!context.mounted) return;

  if (receipt.isPdf) {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.receipt_view_title),
        content: Text(receipt.fileName),
        actions: [
          TextButton(
            style: AppButtons.inline,
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(dialogContext.l10n.close),
          ),
          FilledButton(
            style: AppButtons.inline,
            onPressed: () async {
              final uri = Uri.parse(url);
              final opened = await launchUrl(
                uri,
                mode: LaunchMode.externalApplication,
              );
              if (!opened && dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
            },
            child: Text(dialogContext.l10n.receipt_open_file),
          ),
        ],
      ),
    );
    return;
  }

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    dialogContext.l10n.receipt_view_title,
                    style: Theme.of(dialogContext).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  icon: const Icon(Icons.close_rounded),
                  tooltip: dialogContext.l10n.close,
                ),
              ],
            ),
          ),
          Flexible(
            child: InteractiveViewer(
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (context, _, _) =>
                    Text(context.l10n.receipt_load_failed),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    ),
  );
}

/// Small square preview used in the receipt list.
class ReceiptThumbnail extends ConsumerWidget {
  const ReceiptThumbnail({super.key, required this.receipt, this.size = 48});

  final Receipt receipt;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    if (!receipt.isImage) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Icon(Icons.picture_as_pdf_rounded, color: scheme.onSurfaceVariant),
      );
    }
    final url = ref.watch(receiptSignedUrlProvider(receipt.storagePath));
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: size,
        height: size,
        child: url.when(
          data: (value) => Image.network(value, fit: BoxFit.cover),
          loading: () => Container(color: scheme.surfaceContainerHighest),
          error: (error, _) => Container(
            color: scheme.surfaceContainerHighest,
            alignment: Alignment.center,
            child: Icon(Icons.broken_image_outlined, color: scheme.error),
          ),
        ),
      ),
    );
  }
}

/// Human label for a receipt's size, e.g. "1.4 MB".
String receiptSizeLabel(int bytes) {
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  if (bytes >= 1024) return '${(bytes / 1024).round()} KB';
  return '$bytes B';
}

/// Shown when a signed URL could not be minted.
String receiptErrorMessage(BuildContext context, Object error) =>
    errorMessage(context, error);

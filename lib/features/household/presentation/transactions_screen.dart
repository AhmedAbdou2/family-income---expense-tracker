import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/widgets/empty_state.dart';

/// Phase 1 placeholder: the full transactions list with filters arrives in
/// Phase 2.
class TransactionsScreen extends ConsumerWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.nav_transactions)),
      body: EmptyState(
        icon: Icons.receipt_long_outlined,
        title: l10n.empty_transactions_title,
        body: l10n.empty_transactions_body,
      ),
    );
  }
}

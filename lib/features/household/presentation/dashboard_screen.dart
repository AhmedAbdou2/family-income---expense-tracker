import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import 'providers.dart';

/// Phase 1 placeholder: real dashboard (income/expense/balance/top
/// categories) arrives in Phase 2.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final membership = ref.watch(membershipProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          membership.value?.household.name ?? l10n.nav_dashboard,
        ),
      ),
      body: membership.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(membershipProvider),
        ),
        data: (_) => EmptyState(
          icon: Icons.pie_chart_outline_rounded,
          title: l10n.empty_dashboard_title,
          body: l10n.empty_dashboard_body,
        ),
      ),
    );
  }
}

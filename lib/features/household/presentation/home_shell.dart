import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n.dart';

/// Adaptive navigation: bottom [NavigationBar] on phones/tablets, side
/// [NavigationRail] on wide (web/desktop) layouts.
class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  void _selectBranch(int index) {
    shell.goBranch(index, initialLocation: index == shell.currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // (icon, selectedIcon, label)
    final destinations = <(IconData, IconData, String)>[
      (Icons.dashboard_outlined, Icons.dashboard_rounded, l10n.nav_dashboard),
      (Icons.receipt_long_outlined, Icons.receipt_long_rounded, l10n.nav_transactions),
      (Icons.settings_outlined, Icons.settings_rounded, l10n.nav_settings),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 840;
        if (wide) {
          final extended = constraints.maxWidth >= 1200;
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: shell.currentIndex,
                  onDestinationSelected: _selectBranch,
                  extended: extended,
                  labelType: extended
                      ? NavigationRailLabelType.none
                      : NavigationRailLabelType.all,
                  leading: Padding(
                    padding: const EdgeInsetsDirectional.only(bottom: 16),
                    child: Icon(
                      Icons.account_balance_wallet_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  destinations: [
                    for (final (icon, activeIcon, label) in destinations)
                      NavigationRailDestination(
                        icon: Icon(icon),
                        selectedIcon: Icon(activeIcon),
                        label: Text(label),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1, thickness: 1),
                Expanded(child: shell),
              ],
            ),
          );
        }

        return Scaffold(
          body: shell,
          bottomNavigationBar: NavigationBar(
            selectedIndex: shell.currentIndex,
            onDestinationSelected: _selectBranch,
            destinations: [
              for (final (icon, activeIcon, label) in destinations)
                NavigationDestination(
                  icon: Icon(icon),
                  selectedIcon: Icon(activeIcon),
                  label: label,
                ),
            ],
          ),
        );
      },
    );
  }
}

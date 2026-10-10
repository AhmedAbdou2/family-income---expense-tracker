import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n.dart';
import '../../auth/presentation/providers.dart';
import '../../members/domain/entities.dart';
import '../../members/presentation/providers.dart';
import '../../transactions/presentation/quick_add_sheet.dart';
import '../domain/entities.dart';
import 'providers.dart';

/// Gives descendants access to the shell's [ScaffoldState] so a branch
/// screen can open the navigation drawer from its own AppBar.
class ShellScope extends InheritedWidget {
  const ShellScope({super.key, required this.openDrawer, required super.child});

  final VoidCallback openDrawer;

  static ShellScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShellScope>();

  @override
  bool updateShouldNotify(ShellScope oldWidget) => false;
}

/// Menu button placed as a branch screen's AppBar `leading`. Renders
/// nothing usable when there is no drawer (e.g. a detail route shown on
/// its own) - callers should only add it when [ShellScope.maybeOf] exists.
class ShellMenuButton extends StatelessWidget {
  const ShellMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: MaterialLocalizations.of(context).openAppDrawerTooltip,
      icon: const Icon(Icons.menu_rounded),
      onPressed: () => ShellScope.maybeOf(context)?.openDrawer(),
    );
  }
}

class _Destination {
  const _Destination({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.adultOnly = false,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool adultOnly;
}

/// Adaptive navigation shared by phones, tablets and web/desktop.
///
/// Branch order (fixed - see `app_router.dart`): 0 dashboard, 1
/// transactions, 2 people, 3 fixed, 4 settings, 5 vehicles, 6 pets.
/// The bottom bar shows only the first four (adult) / three (child);
/// every other destination lives in the drawer / rail.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  void _selectBranch(int index) {
    widget.shell.goBranch(
      index,
      initialLocation: index == widget.shell.currentIndex,
    );
  }

  Future<void> _quickAdd(BuildContext context) async {
    final result = await showQuickAddSheet(context);
    if (!context.mounted || result == null) return;
    if (result == 'saved') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.transaction_saved)),
      );
    } else if (result == 'more') {
      context.push('/transactions/new');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final role = ref.watch(membershipProvider).value?.role;
    final canManage = role == MemberRole.owner || role == MemberRole.adult;

    final all = <_Destination>[
      _Destination(
        icon: Icons.dashboard_outlined,
        activeIcon: Icons.dashboard_rounded,
        label: l10n.nav_dashboard,
      ),
      _Destination(
        icon: Icons.receipt_long_outlined,
        activeIcon: Icons.receipt_long_rounded,
        label: l10n.nav_transactions,
      ),
      _Destination(
        icon: Icons.people_outline,
        activeIcon: Icons.people_rounded,
        label: l10n.nav_people,
      ),
      _Destination(
        icon: Icons.event_repeat_outlined,
        activeIcon: Icons.event_repeat_rounded,
        label: l10n.nav_fixed,
        adultOnly: true,
      ),
      _Destination(
        icon: Icons.settings_outlined,
        activeIcon: Icons.settings_rounded,
        label: l10n.nav_settings,
      ),
      _Destination(
        icon: Icons.directions_car_outlined,
        activeIcon: Icons.directions_car_rounded,
        label: l10n.nav_vehicles,
        adultOnly: true,
      ),
      _Destination(
        icon: Icons.pets_outlined,
        activeIcon: Icons.pets_rounded,
        label: l10n.nav_pets,
        adultOnly: true,
      ),
    ];
    final allowedIndexes = <int>[
      for (var i = 0; i < all.length; i++)
        if (canManage || !all[i].adultOnly) i,
    ];
    final bottomIndexes = allowedIndexes.where((i) => i <= 3).toList();

    final currentIndex = widget.shell.currentIndex;
    final bottomSelected = bottomIndexes.indexOf(currentIndex);
    final railSelected = allowedIndexes.indexOf(currentIndex);
    final safeBottomSelected = bottomSelected < 0 ? 0 : bottomSelected;
    final safeRailSelected = railSelected < 0 ? 0 : railSelected;

    void openDrawer() => _scaffoldKey.currentState?.openDrawer();

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 840;

        final fab = FloatingActionButton(
          heroTag: const ValueKey('quick-add-fab'),
          tooltip: l10n.quick_add_title,
          onPressed: () => _quickAdd(context),
          child: const Icon(Icons.add_rounded),
        );

        if (wide) {
          final extended = constraints.maxWidth >= 1200;
          return Scaffold(
            floatingActionButton: fab,
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: safeRailSelected,
                  onDestinationSelected: (position) =>
                      _selectBranch(allowedIndexes[position]),
                  extended: extended,
                  labelType: extended
                      ? NavigationRailLabelType.none
                      : NavigationRailLabelType.all,
                  leading: Padding(
                    padding: const EdgeInsetsDirectional.only(bottom: 12),
                    child: _AccountButton(extended: extended),
                  ),
                  destinations: [
                    for (final index in allowedIndexes)
                      NavigationRailDestination(
                        icon: Icon(all[index].icon),
                        selectedIcon: Icon(all[index].activeIcon),
                        label: Text(all[index].label),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1, thickness: 1),
                Expanded(child: shellBody(context, openDrawer)),
              ],
            ),
          );
        }

        return Scaffold(
          key: _scaffoldKey,
          floatingActionButton: fab,
          drawer: _AppDrawer(
            all: all,
            allowedIndexes: allowedIndexes,
            currentIndex: currentIndex,
            onSelect: _selectBranch,
          ),
          body: shellBody(context, openDrawer),
          bottomNavigationBar: NavigationBar(
            selectedIndex: safeBottomSelected,
            onDestinationSelected: (position) =>
                _selectBranch(bottomIndexes[position]),
            destinations: [
              for (final index in bottomIndexes)
                NavigationDestination(
                  icon: Icon(all[index].icon),
                  selectedIcon: Icon(all[index].activeIcon),
                  label: all[index].label,
                ),
            ],
          ),
        );
      },
    );
  }

  Widget shellBody(BuildContext context, VoidCallback openDrawer) {
    return ShellScope(openDrawer: openDrawer, child: widget.shell);
  }
}

class _AccountButton extends ConsumerWidget {
  const _AccountButton({required this.extended});

  final bool extended;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final name = _ownName(ref) ?? context.l10n.account_fallback;
    final avatar = CircleAvatar(
      backgroundColor: scheme.primaryContainer,
      child: Text(
        name.isEmpty ? '?' : name.characters.first.toUpperCase(),
        style: TextStyle(
          color: scheme.onPrimaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    return Tooltip(
      message: name,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/profile/me'),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: extended
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    avatar,
                    const SizedBox(width: 10),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 200),
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                )
              : avatar,
        ),
      ),
    );
  }
}

class _AppDrawer extends ConsumerWidget {
  const _AppDrawer({
    required this.all,
    required this.allowedIndexes,
    required this.currentIndex,
    required this.onSelect,
  });

  final List<_Destination> all;
  final List<int> allowedIndexes;
  final int currentIndex;
  final void Function(int) onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final name = _ownName(ref) ?? l10n.account_fallback;
    final selectedPosition = allowedIndexes.contains(currentIndex)
        ? allowedIndexes.indexOf(currentIndex)
        : null;

    return NavigationDrawer(
      onDestinationSelected: (position) {
        Navigator.of(context).pop();
        onSelect(allowedIndexes[position]);
      },
      selectedIndex: selectedPosition,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 8),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              Navigator.of(context).pop();
              context.push('/profile/me');
            },
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: scheme.primaryContainer,
                  child: Text(
                    name.isEmpty ? '?' : name.characters.first.toUpperCase(),
                    style: TextStyle(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ),
        const Divider(),
        for (final index in allowedIndexes)
          NavigationDrawerDestination(
            icon: Icon(all[index].icon),
            selectedIcon: Icon(all[index].activeIcon),
            label: Text(all[index].label),
          ),
      ],
    );
  }
}

/// The signed-in login's own person name, when it is linked and visible.
String? _ownName(WidgetRef ref) {
  final userId = ref.watch(authStateProvider).value;
  final members = ref.watch(membersProvider).value ?? const <Member>[];
  if (userId == null) return null;
  for (final member in members) {
    if (member.isLinked && member.userId == userId) return member.name;
  }
  return members.isEmpty ? null : members.first.name;
}

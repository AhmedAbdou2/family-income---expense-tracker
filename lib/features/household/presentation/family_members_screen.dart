import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../auth/presentation/providers.dart';
import '../../members/domain/entities.dart';
import '../../members/presentation/providers.dart';
import '../domain/entities.dart';
import 'home_shell.dart';
import 'providers.dart';
import 'role_badge.dart';

/// One unified "Family members" list: a row per person with a role badge
/// (owner / adult / child when linked to a login, "No login" otherwise).
/// Owner/adult manage people and invites from here; children see only their
/// own row. Merges the old People tab and Household-members screen.
class FamilyMembersScreen extends ConsumerWidget {
  const FamilyMembersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final membership = ref.watch(membershipProvider).value;
    final role = membership?.role;
    final canManage =
        role == MemberRole.owner || role == MemberRole.adult;
    final members = ref.watch(membersProvider);

    return Scaffold(
      appBar: AppBar(
        leading: ShellScope.maybeOf(context) == null
            ? null
            : const ShellMenuButton(),
        title: Text(l10n.members_title),
        // Actions live in the app bar, not a FAB: the shell owns the only
        // FAB (quick-add) and two default-tagged FABs in one Navigator
        // subtree trip the duplicate-hero assertion on transitions.
        actions: [
          if (canManage)
            IconButton(
              tooltip: l10n.family_add_member,
              icon: const Icon(Icons.person_add_alt_1_outlined),
              onPressed: () => addFamilyMember(context, ref),
            ),
        ],
      ),
      body: members.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(membersProvider),
        ),
        data: (list) {
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.people_outline_rounded,
              title: l10n.member_empty_title,
              body: l10n.member_empty_body,
            );
          }
          return _FamilyList(members: list, canManage: canManage);
        },
      ),
    );
  }
}

class _FamilyList extends ConsumerWidget {
  const _FamilyList({required this.members, required this.canManage});

  final List<Member> members;
  final bool canManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final membership = ref.watch(membershipProvider).value;
    final isOwner = membership?.role == MemberRole.owner;
    final me = ref.watch(authStateProvider).value;
    final logins = ref.watch(householdLoginsProvider).value ?? const [];
    final ownerCount =
        logins.where((login) => login.role == MemberRole.owner).length;
    final rolesByUser = {
      for (final login in logins) login.userId: login.role,
    };

    final rows = <_FamilyRow>[
      for (final member in members)
        _FamilyRow(
          member: member,
          name: member.name,
          userId: member.userId,
          isActive: member.isActive,
          role: member.userId == null
              ? null
              : member.userId == me
                  ? membership?.role ?? rolesByUser[member.userId]
                  : rolesByUser[member.userId],
        ),
      // Legacy logins with no linked person would otherwise be invisible
      // (and un-removable). Only managers see them; children see just
      // their own linked person.
      if (canManage)
        for (final login in logins)
          if (login.personId == null)
            _FamilyRow(
              name: login.personName ?? l10n.login_no_person,
              userId: login.userId,
              isActive: true,
              role: login.role,
            ),
    ];

    return ListView.separated(
      padding: const EdgeInsetsDirectional.only(bottom: 96),
      itemCount: rows.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final row = rows[index];
        final isMe = row.userId != null && row.userId == me;
        final isLinked = row.userId != null;
        final isPerson = row.member != null;
        return _FamilyTile(
          row: row,
          isMe: isMe,
          isOwner: isOwner,
          ownerCount: ownerCount,
          actions: _Actions(
            rename: isPerson && (isOwner || isMe),
            changeRole: isLinked && isOwner && !isMe,
            removeLogin: isLinked && isOwner && !isMe,
            connectLogin: isPerson && !isLinked && canManage,
            archive: isPerson && canManage,
            delete: isPerson && !isLinked && canManage,
            leave: isMe,
          ),
        );
      },
    );
  }
}

/// A row in the unified list - either a person or a legacy person-less login.
class _FamilyRow {
  const _FamilyRow({
    required this.name,
    required this.userId,
    required this.isActive,
    required this.role,
    this.member,
  });

  final Member? member;
  final String name;
  final String? userId;
  final bool isActive;
  final MemberRole? role;
}

class _Actions {
  const _Actions({
    required this.rename,
    required this.changeRole,
    required this.removeLogin,
    required this.connectLogin,
    required this.archive,
    required this.delete,
    required this.leave,
  });

  final bool rename;
  final bool changeRole;
  final bool removeLogin;
  final bool connectLogin;
  final bool archive;
  final bool delete;
  final bool leave;

  bool get any =>
      rename || changeRole || removeLogin || connectLogin || archive ||
      delete || leave;
}

class _FamilyTile extends ConsumerWidget {
  const _FamilyTile({
    required this.row,
    required this.isMe,
    required this.isOwner,
    required this.ownerCount,
    required this.actions,
  });

  final _FamilyRow row;
  final bool isMe;
  final bool isOwner;
  final int ownerCount;
  final _Actions actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final member = row.member;
    final canLeave = !(isOwner && row.userId != null && ownerCount <= 1);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: scheme.primaryContainer,
        child: Text(
          row.name.isEmpty ? '?' : row.name.characters.first.toUpperCase(),
          style: TextStyle(color: scheme.onPrimaryContainer),
        ),
      ),
      title: Text(row.name),
      subtitle: Padding(
        padding: const EdgeInsetsDirectional.only(top: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            RoleBadge(role: row.role, dense: true),
            if (!row.isActive) ...[
              const SizedBox(width: 6),
              Text(
                l10n.member_inactive,
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
      onTap: member == null ? null : () => context.push('/profile/${member.id}'),
      trailing: !actions.any
          ? null
          : PopupMenuButton<String>(
              onSelected: (action) => _handle(context, ref, action, canLeave),
              itemBuilder: (context) => [
                if (actions.rename)
                  PopupMenuItem(value: 'rename', child: Text(l10n.member_rename)),
                if (actions.changeRole)
                  PopupMenuItem(
                    value: 'role',
                    child: Text(l10n.login_change_role),
                  ),
                if (actions.removeLogin)
                  PopupMenuItem(
                    value: 'remove',
                    child: Text(
                      l10n.login_remove,
                      style: TextStyle(color: scheme.error),
                    ),
                  ),
                if (actions.connectLogin)
                  PopupMenuItem(
                    value: 'connect',
                    child: Text(l10n.family_create_invite),
                  ),
                if (actions.archive)
                  PopupMenuItem(
                    value: 'archive',
                    child: Text(
                      row.isActive ? l10n.member_archive : l10n.member_restore,
                    ),
                  ),
                if (actions.delete)
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(l10n.member_delete),
                  ),
                if (actions.leave)
                  PopupMenuItem(
                    value: 'leave',
                    enabled: canLeave,
                    child: Text(
                      l10n.leave_household,
                      style: TextStyle(
                        color: canLeave ? scheme.error : scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Future<void> _handle(
    BuildContext context,
    WidgetRef ref,
    String action,
    bool canLeave,
  ) async {
    switch (action) {
      case 'rename':
        await _rename(context, ref);
      case 'role':
        await _changeRole(context, ref);
      case 'remove':
        await _removeLogin(context, ref);
      case 'connect':
        await _connectLogin(context, ref);
      case 'archive':
        await _setActive(context, ref);
      case 'delete':
        await _delete(context, ref);
      case 'leave':
        if (canLeave) await _leave(context, ref);
    }
  }

  void _invalidate(WidgetRef ref) {
    ref
      ..invalidate(membersProvider)
      ..invalidate(householdLoginsProvider);
  }

  Future<void> _rename(BuildContext context, WidgetRef ref) async {
    final member = row.member;
    if (member == null) return;
    final name = await _promptName(context, initial: member.name);
    if (name == null || !context.mounted) return;
    try {
      await ref
          .read(membersRepositoryProvider)
          .renameMember(memberId: member.id, name: name);
      _invalidate(ref);
    } catch (error) {
      if (context.mounted) _showError(context, error);
    }
  }

  Future<void> _changeRole(BuildContext context, WidgetRef ref) async {
    final userId = row.userId;
    final membership = ref.read(membershipProvider).value;
    if (userId == null || membership == null) return;
    final chosen = await showRolePicker(context, current: row.role);
    if (chosen == null || chosen == row.role || !context.mounted) return;
    try {
      await ref.read(householdRepositoryProvider).updateHouseholdRole(
            householdId: membership.household.id,
            userId: userId,
            role: chosen,
          );
      _invalidate(ref);
      ref.invalidate(membershipProvider);
    } catch (error) {
      if (context.mounted) _showError(context, error);
    }
  }

  Future<void> _removeLogin(BuildContext context, WidgetRef ref) async {
    final userId = row.userId;
    final membership = ref.read(membershipProvider).value;
    if (userId == null || membership == null) return;
    final confirmed = await _confirm(
      context,
      title: context.l10n.login_remove_confirm_title,
      body: context.l10n.login_remove_confirm_body,
      actionLabel: context.l10n.login_remove,
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(householdRepositoryProvider).removeHouseholdLogin(
            householdId: membership.household.id,
            userId: userId,
          );
      _invalidate(ref);
    } catch (error) {
      if (context.mounted) _showError(context, error);
    }
  }

  Future<void> _connectLogin(BuildContext context, WidgetRef ref) async {
    final member = row.member;
    final membership = ref.read(membershipProvider).value;
    if (member == null || membership == null) return;
    final role = await showRolePicker(context);
    if (role == null || !context.mounted) return;
    await createInviteAndShowCode(
      context,
      ref,
      householdId: membership.household.id,
      role: role,
      memberId: member.id,
      hint: context.l10n.member_connect_hint(member.name),
    );
  }

  Future<void> _setActive(BuildContext context, WidgetRef ref) async {
    final member = row.member;
    if (member == null) return;
    try {
      await ref.read(membersRepositoryProvider).setMemberActive(
            memberId: member.id,
            isActive: !member.isActive,
          );
      ref.invalidate(membersProvider);
    } catch (error) {
      if (context.mounted) _showError(context, error);
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final member = row.member;
    if (member == null) return;
    final confirmed = await _confirm(
      context,
      title: context.l10n.member_delete_confirm_title,
      body: context.l10n.member_delete_confirm_body,
      actionLabel: context.l10n.delete_action,
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(membersRepositoryProvider).deleteMember(memberId: member.id);
      _invalidate(ref);
    } catch (error) {
      if (context.mounted) _showError(context, error);
    }
  }

  Future<void> _leave(BuildContext context, WidgetRef ref) async {
    final confirmed = await _confirm(
      context,
      title: context.l10n.leave_confirm_title,
      body: context.l10n.leave_confirm_body,
      actionLabel: context.l10n.leave_household,
    );
    if (confirmed != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(householdRepositoryProvider).leaveHousehold();
      ref
        ..invalidate(membershipProvider)
        ..invalidate(householdLoginsProvider)
        ..invalidate(linkedMemberProvider)
        ..invalidate(membersProvider)
        ..invalidate(invitesProvider);
    } catch (error) {
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(errorMessage(context, error))),
        );
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Shared dialogs / flows (also used by the app-bar actions)
// ---------------------------------------------------------------------------

Future<String?> _promptName(BuildContext context, {String? initial}) async {
  final controller = TextEditingController(text: initial);
  final name = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(dialogContext.l10n.member_name),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLength: 40,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          labelText: dialogContext.l10n.member_name,
          hintText: dialogContext.l10n.member_name_hint,
          counterText: '',
        ),
        onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(dialogContext.l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(controller.text),
          child: Text(dialogContext.l10n.save),
        ),
      ],
    ),
  );
  if (name == null || name.trim().isEmpty) return null;
  return name;
}

void _showError(BuildContext context, Object error) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(errorMessage(context, error))),
  );
}

Future<bool?> _confirm(
  BuildContext context, {
  required String title,
  required String body,
  required String actionLabel,
}) {
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(dialogContext.l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(actionLabel),
        ),
      ],
    ),
  );
}

/// Role picker.
///
/// - Changing an existing role offers owner/adult/child.
/// - Creating an invite offers only adult/child: no invite can ever carry
///   the owner role (the `invites` CHECK and `create_invite` enforce it too).
Future<MemberRole?> showRolePicker(
  BuildContext context, {
  MemberRole? current,
}) async {
  final title = current == null
      ? context.l10n.invite_as
      : context.l10n.login_change_role;

  if (current == null) {
    return showDialog<MemberRole>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final role in const [MemberRole.adult, MemberRole.child])
              ListTile(
                leading: Icon(_roleIcon(role)),
                title: Text(roleLabel(dialogContext, role)),
                onTap: () => Navigator.of(dialogContext).pop(role),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(dialogContext.l10n.cancel),
          ),
        ],
      ),
    );
  }

  var selected = current;
  return showDialog<MemberRole>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AlertDialog(
        title: Text(title),
        content: RadioGroup<MemberRole>(
          groupValue: selected,
          onChanged: (value) {
            if (value == null) return;
            setDialogState(() => selected = value);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final role in MemberRole.values)
                RadioListTile<MemberRole>(
                  value: role,
                  title: Text(roleLabel(dialogContext, role)),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(dialogContext.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(selected),
            child: Text(dialogContext.l10n.save),
          ),
        ],
      ),
    ),
  );
}

IconData _roleIcon(MemberRole role) => switch (role) {
      MemberRole.owner => Icons.shield_outlined,
      MemberRole.adult => Icons.person_outline,
      MemberRole.child => Icons.child_care_outlined,
    };

/// What the merged "Add family member" dialog collected.
class AddMemberRequest {
  const AddMemberRequest({
    required this.name,
    required this.withLogin,
    required this.role,
  });

  /// Trimmed, non-empty person name.
  final String name;

  /// false = create just the person; true = also create a person-bound invite.
  final bool withLogin;

  /// Role for the invite (only meaningful when [withLogin] is true).
  final MemberRole role;
}

/// The one "add" entry point: collects a name, whether the person should get
/// a login, and (for a login) the invite role, then creates the person and -
/// when a login was requested - a person-bound invite.
///
/// - no login: creates the person only, exactly like the old "Add person";
/// - with login: creates the person (unlinked), then binds an invite to it
///   through `create_invite`'s `p_member_id` (migration 11). `accept_invite`
///   links the joiner to that very person - so "a child login always has a
///   person" holds without any new rule, and the invite can only ever carry
///   the adult/child role (the `invites` CHECK + `create_invite` enforce it).
Future<void> addFamilyMember(BuildContext context, WidgetRef ref) async {
  final membership = ref.read(membershipProvider).value;
  if (membership == null) return;

  final request = await showAddMemberDialog(context);
  if (request == null || !context.mounted) return;

  final householdId = membership.household.id;
  try {
    final member = await ref.read(membersRepositoryProvider).createMember(
          householdId: householdId,
          name: request.name,
        );
    ref.invalidate(membersProvider);
    if (!request.withLogin || !context.mounted) return;

    await createInviteAndShowCode(
      context,
      ref,
      householdId: householdId,
      role: request.role,
      memberId: member.id,
      hint: context.l10n.member_connect_hint(member.name),
    );
  } catch (error) {
    if (context.mounted) _showError(context, error);
  }
}

/// The merged "Add family member" dialog.
///
/// Collects a name, whether the person should get a login, and (only for the
/// login path - a person without a login has no role) the invite role. The
/// role choice is always limited to adult/child: the `invites` CHECK and
/// `create_invite` both forbid inviting an owner.
Future<AddMemberRequest?> showAddMemberDialog(BuildContext context) async {
  final controller = TextEditingController();
  var withLogin = false;
  var role = MemberRole.adult;
  return showDialog<AddMemberRequest>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setLocal) {
        final l10n = context.l10n;
        final name = controller.text.trim();
        return AlertDialog(
          title: Text(l10n.family_add_member),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  maxLength: 40,
                  textInputAction: TextInputAction.done,
                  onChanged: (_) => setLocal(() {}),
                  decoration: InputDecoration(
                    labelText: l10n.member_name,
                    hintText: l10n.member_name_hint,
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.family_add_login_label,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                RadioGroup<bool>(
                  groupValue: withLogin,
                  onChanged: (value) {
                    if (value == null) return;
                    setLocal(() => withLogin = value);
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RadioListTile<bool>(
                        value: false,
                        contentPadding: EdgeInsets.zero,
                        title: Text(l10n.role_no_login),
                        subtitle: Text(l10n.family_add_no_login_hint),
                      ),
                      RadioListTile<bool>(
                        value: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(l10n.create_invite_action),
                        subtitle: Text(l10n.family_add_with_login_hint),
                      ),
                    ],
                  ),
                ),
                if (withLogin) ...[
                  const SizedBox(height: 8),
                  Text(
                    l10n.invite_as,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  RadioGroup<MemberRole>(
                    groupValue: role,
                    onChanged: (value) {
                      if (value == null) return;
                      setLocal(() => role = value);
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final option in const [
                          MemberRole.adult,
                          MemberRole.child,
                        ])
                          RadioListTile<MemberRole>(
                            value: option,
                            contentPadding: EdgeInsets.zero,
                            title: Text(roleLabel(context, option)),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: name.isEmpty
                  ? null
                  : () => Navigator.of(dialogContext).pop(
                        AddMemberRequest(
                          name: name,
                          withLogin: withLogin,
                          role: role,
                        ),
                      ),
              child: Text(l10n.family_add_action),
            ),
          ],
        );
      },
    ),
  );
}

/// Creates an invite via `create_invite` and shows the code with copy/share.
Future<void> createInviteAndShowCode(
  BuildContext context,
  WidgetRef ref, {
  required String householdId,
  required MemberRole role,
  required String hint,
  String? memberId,
}) async {
  try {
    final code = await ref.read(householdRepositoryProvider).createInvite(
          householdId: householdId,
          role: role,
          memberId: memberId,
        );
    ref.invalidate(invitesProvider);
    if (!context.mounted) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.invite_created_title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: Theme.of(dialogContext).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                code,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 4,
                  color:
                      Theme.of(dialogContext).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(hint, textAlign: TextAlign.center),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              navigator.pop();
              messenger.showSnackBar(
                SnackBar(content: Text(l10n.copied)),
              );
            },
            child: Text(dialogContext.l10n.copy_code),
          ),
          FilledButton(
            onPressed: () => navigator.pop(),
            child: Text(dialogContext.l10n.close),
          ),
        ],
      ),
    );
  } catch (error) {
    if (context.mounted) _showError(context, error);
  }
}

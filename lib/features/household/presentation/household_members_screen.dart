import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../auth/presentation/providers.dart';
import '../../members/presentation/providers.dart';
import '../domain/entities.dart';
import 'providers.dart';

/// Owner-only list of the household's *logins* (not persons): shows each
/// account's role and linked person - never any email, `household_users`
/// has no email column. Owners can rename the linked person, change roles
/// and remove accounts, all through migration-12 RPCs.
class HouseholdMembersScreen extends ConsumerWidget {
  const HouseholdMembersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final membership = ref.watch(membershipProvider);

    return membership.when(
      loading: () => const Scaffold(body: LoadingView()),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: Text(l10n.household_members_title)),
        body: ErrorView(error: error),
      ),
      data: (current) {
        if (current == null || current.role != MemberRole.owner) {
          return Scaffold(
            appBar: AppBar(title: Text(l10n.household_members_title)),
            body: const ErrorView(error: AppException(AppErrorCode.forbidden)),
          );
        }
        return _OwnerBody(householdId: current.household.id);
      },
    );
  }
}

class _OwnerBody extends ConsumerWidget {
  const _OwnerBody({required this.householdId});

  final String householdId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final logins = ref.watch(householdLoginsProvider);
    final me = ref.watch(authStateProvider).value;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.household_members_title)),
      body: logins.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(householdLoginsProvider),
        ),
        data: (list) => ListView.separated(
          padding: const EdgeInsetsDirectional.only(bottom: 24),
          itemCount: list.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) => _LoginTile(
            login: list[index],
            isSelf: list[index].userId == me,
          ),
        ),
      ),
    );
  }
}

class _LoginTile extends ConsumerWidget {
  const _LoginTile({required this.login, required this.isSelf});

  final HouseholdLogin login;
  final bool isSelf;

  String _roleLabel(BuildContext context, MemberRole role) => switch (role) {
        MemberRole.owner => context.l10n.role_owner,
        MemberRole.adult => context.l10n.role_adult,
        MemberRole.child => context.l10n.role_child,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final title = login.personName ?? l10n.login_no_person;
    final subtitle = _roleLabel(context, login.role);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: scheme.primaryContainer,
        child: Text(
          title.isEmpty ? '?' : title.characters.first.toUpperCase(),
          style: TextStyle(color: scheme.onPrimaryContainer),
        ),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      // Self row has no actions: the RPCs refuse changing your own role
      // and removing yourself (use Leave household instead).
      trailing: isSelf
          ? null
          : PopupMenuButton<String>(
              onSelected: (action) => _handle(context, ref, action),
              itemBuilder: (context) => [
                if (login.hasPerson)
                  PopupMenuItem(
                    value: 'rename',
                    child: Text(l10n.member_rename),
                  ),
                PopupMenuItem(
                  value: 'role',
                  child: Text(l10n.login_change_role),
                ),
                PopupMenuItem(
                  value: 'remove',
                  child: Text(
                    l10n.login_remove,
                    style: TextStyle(color: scheme.error),
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
  ) async {
    switch (action) {
      case 'rename':
        await _renamePerson(context, ref);
      case 'role':
        await _changeRole(context, ref);
      case 'remove':
        await _remove(context, ref);
    }
  }

  Future<void> _renamePerson(BuildContext context, WidgetRef ref) async {
    final personId = login.personId;
    if (personId == null) return;
    final controller = TextEditingController(text: login.personName);
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.member_rename),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 40,
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
    if (name == null || Validators.displayName(name) != null) return;
    if (!context.mounted) return;
    try {
      await ref
          .read(membersRepositoryProvider)
          .renameMember(memberId: personId, name: name);
      ref.invalidate(householdLoginsProvider);
      ref.invalidate(membersProvider);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage(context, error))),
        );
      }
    }
  }

  Future<void> _changeRole(BuildContext context, WidgetRef ref) async {
    var selected = login.role;
    final chosen = await showDialog<MemberRole>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(dialogContext.l10n.login_change_role),
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
                    // A child role needs a linked person: offering it for a
                    // person-less login would only fail with
                    // child_requires_member.
                    enabled: role != MemberRole.child || login.hasPerson,
                    title: Text(
                      switch (role) {
                        MemberRole.owner => dialogContext.l10n.role_owner,
                        MemberRole.adult => dialogContext.l10n.role_adult,
                        MemberRole.child => dialogContext.l10n.role_child,
                      },
                    ),
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
    if (chosen == null || chosen == login.role || !context.mounted) return;
    final membership = ref.read(membershipProvider).value;
    if (membership == null) return;
    try {
      await ref.read(householdRepositoryProvider).updateHouseholdRole(
            householdId: membership.household.id,
            userId: login.userId,
            role: chosen,
          );
      ref.invalidate(householdLoginsProvider);
      ref.invalidate(membersProvider);
      ref.invalidate(membershipProvider);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage(context, error))),
        );
      }
    }
  }

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.login_remove_confirm_title),
        content: Text(dialogContext.l10n.login_remove_confirm_body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(dialogContext.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(dialogContext.l10n.login_remove),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final membership = ref.read(membershipProvider).value;
    if (membership == null) return;
    try {
      await ref.read(householdRepositoryProvider).removeHouseholdLogin(
            householdId: membership.household.id,
            userId: login.userId,
          );
      ref.invalidate(householdLoginsProvider);
      ref.invalidate(membersProvider);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage(context, error))),
        );
      }
    }
  }
}

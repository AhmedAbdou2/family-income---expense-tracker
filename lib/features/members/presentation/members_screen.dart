import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../auth/presentation/providers.dart';
import '../../household/domain/entities.dart';
import '../../household/presentation/providers.dart';
import '../domain/entities.dart';
import 'providers.dart';

/// People tab: lists the household's persons. Children (RLS narrows the
/// list to their own row) get a read-only view; owner/adult may add,
/// rename, deactivate and delete.
class MembersScreen extends ConsumerWidget {
  const MembersScreen({super.key});

  bool _canManage(MemberRole role) =>
      role == MemberRole.owner || role == MemberRole.adult;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final membership = ref.watch(membershipProvider).value;
    final members = ref.watch(membersProvider);
    final canManage = membership != null && _canManage(membership.role);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.members_title)),
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
          return ListView.separated(
            padding: const EdgeInsetsDirectional.only(bottom: 96),
            itemCount: list.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) =>
                _MemberTile(member: list[index], canManage: canManage),
          );
        },
      ),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.person_add_alt_1_outlined),
              label: Text(l10n.member_add),
              onPressed: () => _addMember(context, ref),
            )
          : null,
    );
  }

  Future<void> _addMember(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.member_add),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 60,
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
    if (name == null || name.trim().isEmpty || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final membership = ref.read(membershipProvider).value;
    if (membership == null) return;
    try {
      await ref.read(membersRepositoryProvider).createMember(
            householdId: membership.household.id,
            name: name,
          );
      ref.invalidate(membersProvider);
    } catch (error) {
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(errorMessage(context, error))),
        );
      }
    }
  }
}

class _MemberTile extends ConsumerWidget {
  const _MemberTile({required this.member, required this.canManage});

  final Member member;
  final bool canManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final me = ref.watch(authStateProvider).value;

    final String? badge;
    if (member.isLinked && member.userId == me) {
      badge = l10n.member_you;
    } else if (member.isLinked) {
      badge = l10n.member_linked_badge;
    } else if (!member.isActive) {
      badge = l10n.member_inactive;
    } else {
      badge = null;
    }

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: scheme.primaryContainer,
        child: Text(
          member.name.isEmpty ? '?' : member.name.characters.first.toUpperCase(),
          style: TextStyle(color: scheme.onPrimaryContainer),
        ),
      ),
      title: Text(member.name),
      subtitle: badge == null ? null : Text(badge),
      trailing: canManage
          ? PopupMenuButton<String>(
              onSelected: (action) => _handle(context, ref, action),
              itemBuilder: (context) => [
                PopupMenuItem(value: 'rename', child: Text(l10n.member_rename)),
                PopupMenuItem(
                  value: 'toggle',
                  child: Text(
                    member.isActive ? l10n.member_inactive : l10n.member_active,
                  ),
                ),
                PopupMenuItem(value: 'delete', child: Text(l10n.member_delete)),
              ],
            )
          : null,
    );
  }

  Future<void> _handle(
    BuildContext context,
    WidgetRef ref,
    String action,
  ) async {
    switch (action) {
      case 'rename':
        await _rename(context, ref);
      case 'toggle':
        try {
          await ref.read(membersRepositoryProvider).setMemberActive(
                memberId: member.id,
                isActive: !member.isActive,
              );
          ref.invalidate(membersProvider);
        } catch (error) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(errorMessage(context, error))),
            );
          }
        }
      case 'delete':
        await _delete(context, ref);
    }
  }

  Future<void> _rename(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: member.name);
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.member_rename),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 60,
          decoration: InputDecoration(
            labelText: dialogContext.l10n.member_name,
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
    if (name == null || name.trim().isEmpty || !context.mounted) return;
    try {
      await ref
          .read(membersRepositoryProvider)
          .renameMember(memberId: member.id, name: name);
      ref.invalidate(membersProvider);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage(context, error))),
        );
      }
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.member_delete_confirm_title),
        content: Text(dialogContext.l10n.member_delete_confirm_body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(dialogContext.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(dialogContext.l10n.delete_action),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(membersRepositoryProvider).deleteMember(memberId: member.id);
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

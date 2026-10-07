import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/settings/settings_controller.dart';
import '../../../core/widgets/error_view.dart';
import '../../auth/presentation/providers.dart';
import '../../household/domain/entities.dart';
import '../../household/presentation/providers.dart';
import '../../members/presentation/providers.dart';

String _roleLabel(BuildContext context, MemberRole role) => switch (role) {
      MemberRole.owner => context.l10n.role_owner,
      MemberRole.adult => context.l10n.role_adult,
      MemberRole.child => context.l10n.role_child,
    };

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings = ref.watch(settingsProvider);
    final scheme = Theme.of(context).colorScheme;
    // Invites and category management are adult/owner capabilities; the
    // RPCs reject children anyway, so don't even show the controls.
    final isAdult = switch (ref.watch(membershipProvider).value?.role) {
      MemberRole.owner || MemberRole.adult => true,
      _ => false,
    };

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings_title)),
      body: ListView(
        padding: const EdgeInsetsDirectional.only(bottom: 32),
        children: [
          // ----------------------------------------------------------------
          // Language
          // ----------------------------------------------------------------
          _SectionHeader(title: l10n.language_section),
          Card(
            child: RadioGroup<String>(
              groupValue: settings.locale?.languageCode ?? 'system',
              onChanged: (value) {
                final controller = ref.read(settingsProvider.notifier);
                switch (value) {
                  case 'en':
                    controller.setLocale(const Locale('en'));
                  case 'ar':
                    controller.setLocale(const Locale('ar'));
                  default:
                    controller.setLocale(null);
                }
              },
              child: Column(
                children: [
                  RadioListTile<String>(
                    title: Text(l10n.language_system),
                    value: 'system',
                  ),
                  RadioListTile<String>(
                    title: Text(l10n.language_english),
                    value: 'en',
                  ),
                  RadioListTile<String>(
                    title: Text(l10n.language_arabic),
                    value: 'ar',
                  ),
                ],
              ),
            ),
          ),

          // ----------------------------------------------------------------
          // Theme
          // ----------------------------------------------------------------
          _SectionHeader(title: l10n.theme_section),
          Card(
            child: RadioGroup<ThemeMode>(
              groupValue: settings.themeMode,
              onChanged: (mode) =>
                  ref.read(settingsProvider.notifier).setThemeMode(mode ?? ThemeMode.system),
              child: Column(
                children: [
                  RadioListTile<ThemeMode>(
                    title: Text(l10n.theme_system),
                    value: ThemeMode.system,
                  ),
                  RadioListTile<ThemeMode>(
                    title: Text(l10n.theme_light),
                    value: ThemeMode.light,
                  ),
                  RadioListTile<ThemeMode>(
                    title: Text(l10n.theme_dark),
                    value: ThemeMode.dark,
                  ),
                ],
              ),
            ),
          ),

          // ----------------------------------------------------------------
          // Numbers
          // ----------------------------------------------------------------
          _SectionHeader(title: l10n.digits_section),
          Card(
            child: SwitchListTile(
              title: Text(l10n.arabic_digits_title),
              subtitle: Text(l10n.arabic_digits_subtitle),
              value: settings.arabicDigits,
              onChanged: (value) =>
                  ref.read(settingsProvider.notifier).setArabicDigits(value),
            ),
          ),

          // ----------------------------------------------------------------
          // Household
          // ----------------------------------------------------------------
          _SectionHeader(title: l10n.household_section),
          const _HouseholdCard(),

          if (isAdult) ...[
            // ------------------------------------------------------------
            // Category management
            // ------------------------------------------------------------
            _SectionHeader(title: l10n.manage_categories),
            Card(
              child: ListTile(
                leading: Icon(Icons.category_outlined, color: scheme.primary),
                title: Text(l10n.manage_categories),
                subtitle: Text(l10n.categories_title),
                onTap: () => context.push('/categories'),
              ),
            ),

            // ------------------------------------------------------------
            // Invite codes
            // ------------------------------------------------------------
            _SectionHeader(title: l10n.invites_section),
            Padding(
              padding:
                  const EdgeInsetsDirectional.only(start: 16, end: 16, bottom: 8),
              child: Text(
                l10n.invite_code_hint_share,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
              child: FilledButton.tonalIcon(
                icon: const Icon(Icons.add_rounded),
                label: Text(l10n.create_invite_action),
                onPressed: () => _createInvite(context, ref),
              ),
            ),
            const SizedBox(height: 12),
            const _InvitesList(),
          ],

          // ----------------------------------------------------------------
          // Sign out
          // ----------------------------------------------------------------
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: Icon(Icons.logout_rounded, color: scheme.error),
              title: Text(
                l10n.sign_out,
                style: TextStyle(color: scheme.error, fontWeight: FontWeight.w600),
              ),
              onTap: () => _confirmSignOut(context, ref),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createInvite(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final membership = ref.read(membershipProvider).value;
    if (membership == null) return;

    final role = await showDialog<MemberRole>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.invite_as),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(dialogContext.l10n.role_adult),
              onTap: () => Navigator.of(dialogContext).pop(MemberRole.adult),
            ),
            ListTile(
              leading: const Icon(Icons.child_care_outlined),
              title: Text(dialogContext.l10n.role_child),
              onTap: () => Navigator.of(dialogContext).pop(MemberRole.child),
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
    if (role == null || !context.mounted) return;

    // Optional: bind the invite to an existing person so that accepting it
    // links the login to that members row (member-bound invite). Absent
    // link, the login joins with no person of its own - that's what
    // 'Join only' means.
    String? memberId;
    final members = await ref.read(membersProvider.future);
    if (!context.mounted) return;
    final unlinked =
        members.where((member) => member.isActive && !member.isLinked).toList();
    if (unlinked.isNotEmpty) {
      final choice = await showDialog<Object?>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(dialogContext.l10n.invite_link_title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                dialogContext.l10n.invite_link_hint,
                style: Theme.of(dialogContext)
                    .textTheme
                    .bodySmall
                    ?.copyWith(
                        color: Theme.of(dialogContext)
                            .colorScheme
                            .onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.person_off_outlined),
                title: Text(dialogContext.l10n.invite_link_none),
                onTap: () => Navigator.of(dialogContext).pop('none'),
              ),
              for (final member in unlinked)
                ListTile(
                  leading: const Icon(Icons.person_add_alt_outlined),
                  title: Text(member.name),
                  onTap: () => Navigator.of(dialogContext).pop(member.id),
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
      if (!context.mounted || choice == null) return;
      memberId = choice == 'none' ? null : choice as String;
    }

    try {
      final code = await ref.read(householdRepositoryProvider).createInvite(
            householdId: membership.household.id,
            role: role,
            memberId: memberId,
          );
      ref.invalidate(invitesProvider);
      if (!context.mounted) return;

      final navigator = Navigator.of(context);
      final messenger = ScaffoldMessenger.of(context);
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
                    color: Theme.of(dialogContext).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                dialogContext.l10n.invite_code_hint_share,
                textAlign: TextAlign.center,
              ),
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
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorMessage(context, error))));
      }
    }
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.sign_out_confirm_title),
        content: Text(dialogContext.l10n.sign_out_confirm_body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(dialogContext.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(dialogContext.l10n.sign_out),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(authRepositoryProvider).signOut();
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage(context, error))),
        );
      }
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 20, end: 20, top: 24, bottom: 10),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.primary,
              letterSpacing: 0.3,
            ),
      ),
    );
  }
}

class _HouseholdCard extends ConsumerWidget {
  const _HouseholdCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final membership = ref.watch(membershipProvider);

    return Card(
      child: membership.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, _) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ErrorBanner(error: error),
              TextButton(
                onPressed: () => ref.invalidate(membershipProvider),
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
        data: (m) {
          if (m == null) {
            return ListTile(title: Text(l10n.error_not_member));
          }
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Icon(
                Icons.home_rounded,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            title: Text(
              m.household.name,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              '${l10n.household_currency_line(m.household.currency)}  •  '
              '${l10n.your_role(_roleLabel(context, m.role))}',
            ),
          );
        },
      ),
    );
  }
}

class _InvitesList extends ConsumerWidget {
  const _InvitesList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final invites = ref.watch(invitesProvider);

    return invites.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Padding(
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ErrorBanner(error: error),
            TextButton(
              onPressed: () => ref.invalidate(invitesProvider),
              child: Text(l10n.retry),
            ),
          ],
        ),
      ),
      data: (list) {
        if (list.isEmpty) {
          return Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 20),
            child: Text(
              l10n.invites_empty,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
          child: Column(
            children: [for (final invite in list) _InviteTile(invite: invite)],
          ),
        );
      },
    );
  }
}

class _InviteTile extends StatelessWidget {
  const _InviteTile({required this.invite});

  final Invite invite;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;

    final String statusText;
    final Color statusColor;
    if (invite.isUsed) {
      statusText = l10n.invite_status_used;
      statusColor = scheme.surfaceContainerHighest;
    } else if (invite.isExpired) {
      statusText = l10n.invite_status_active;
      statusColor = scheme.errorContainer;
    } else {
      statusText = l10n.invite_status_active;
      statusColor = scheme.primaryContainer;
    }

    final subtitle = invite.expiresAt == null
        ? _roleLabel(context, invite.role)
        : '${_roleLabel(context, invite.role)}  •  '
            '${l10n.invite_expires_on(
              DateFormat.yMMMd(Localizations.localeOf(context).toString())
                  .format(invite.expiresAt!.toLocal()),
            )}';

    return Card(
      margin: const EdgeInsetsDirectional.only(bottom: 8),
      child: ListTile(
        leading: Icon(Icons.qr_code_2_outlined, color: scheme.primary),
        title: Text(
          invite.code,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontWeight: FontWeight.w700,
            letterSpacing: 3,
          ),
        ),
        subtitle: Text(subtitle),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                statusText,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
            ),
            if (invite.isActive) ...[
              const SizedBox(width: 4),
              IconButton(
                tooltip: l10n.copy_code,
                icon: const Icon(Icons.copy_rounded),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: invite.code));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.copied)),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

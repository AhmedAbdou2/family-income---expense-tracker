import 'package:flutter/material.dart';

import '../../../core/l10n/l10n.dart';
import '../domain/entities.dart';

/// Localized label for a [MemberRole] (owner / adult / child).
String roleLabel(BuildContext context, MemberRole role) => switch (role) {
      MemberRole.owner => context.l10n.role_owner,
      MemberRole.adult => context.l10n.role_adult,
      MemberRole.child => context.l10n.role_child,
    };

/// A small pill that shows a person's role: owner / adult / child when the
/// person is linked to a login, or "No login" when it isn't.
///
/// The same widget is used by the Family members list, the profile header
/// and the navigation account header so the role always reads identically.
/// It always pairs text with an icon and a tonal color - never color alone.
class RoleBadge extends StatelessWidget {
  const RoleBadge({super.key, this.role, this.dense = false});

  /// The login role, or null when the person has no linked login.
  final MemberRole? role;

  /// Compact sizing for list subtitles and the extended rail.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final (String label, IconData icon, Color background, Color foreground) =
        switch (role) {
      MemberRole.owner => (
          context.l10n.role_owner,
          Icons.shield_outlined,
          scheme.primaryContainer,
          scheme.onPrimaryContainer,
        ),
      MemberRole.adult => (
          context.l10n.role_adult,
          Icons.person_outline,
          scheme.tertiaryContainer,
          scheme.onTertiaryContainer,
        ),
      MemberRole.child => (
          context.l10n.role_child,
          Icons.child_care_outlined,
          scheme.secondaryContainer,
          scheme.onSecondaryContainer,
        ),
      null => (
          context.l10n.role_no_login,
          Icons.person_off_outlined,
          scheme.surfaceContainerHighest,
          scheme.onSurfaceVariant,
        ),
    };

    return Container(
      padding: EdgeInsetsDirectional.symmetric(
        horizontal: dense ? 8 : 10,
        vertical: dense ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: dense ? 14 : 16, color: foreground),
          SizedBox(width: dense ? 4 : 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: dense ? 11 : 12,
                fontWeight: FontWeight.w600,
                color: foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

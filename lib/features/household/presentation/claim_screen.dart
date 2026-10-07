import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/utils/form_messages.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/error_view.dart';
import '../../auth/presentation/providers.dart';
import '../../members/presentation/providers.dart';
import '../presentation/providers.dart';

/// First screen for logins created before migration 12: they belong to a
/// household but have no linked person. They pick the name their family
/// will see (`claim_member`), after which the router lets them into the
/// shell. Sign-out is offered as an escape hatch.
class ClaimScreen extends ConsumerStatefulWidget {
  const ClaimScreen({super.key});

  @override
  ConsumerState<ClaimScreen> createState() => _ClaimScreenState();
}

class _ClaimScreenState extends ConsumerState<ClaimScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _submitting = false;
  Object? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref
          .read(householdRepositoryProvider)
          .claimMember(displayName: _nameController.text);
      if (!mounted) return;
      ref.invalidate(linkedMemberProvider);
      ref.invalidate(membersProvider);
      ref.invalidate(membershipProvider);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _signOut() async {
    setState(() => _submitting = true);
    try {
      await ref.read(authRepositoryProvider).signOut();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.claim_title)),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.claim_body, style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 20),
                if (_error != null) ...[
                  ErrorBanner(error: _error!),
                  const SizedBox(height: 20),
                ],
                Form(
                  key: _formKey,
                  child: TextFormField(
                    controller: _nameController,
                    enabled: !_submitting,
                    textInputAction: TextInputAction.done,
                    maxLength: 40,
                    decoration: InputDecoration(
                      labelText: l10n.member_name,
                      hintText: l10n.member_name_hint,
                      counterText: '',
                    ),
                    validator: (value) =>
                        fieldError(context, Validators.displayName(value)),
                    onFieldSubmitted: (_) => _submit(),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.claim_action),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _submitting ? null : _signOut,
                  child: Text(l10n.sign_out),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

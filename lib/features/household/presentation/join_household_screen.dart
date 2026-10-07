import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/utils/form_messages.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/error_view.dart';
import '../../members/presentation/providers.dart';
import '../presentation/providers.dart';

/// Join a household with an invite code. Two steps:
///   1. the 6-char code (format-checked client-side),
///   2. the joiner's own display name (required only by join-only invites;
///      person-bound invites ignore it - the hint says so).
/// The single `accept_invite` call happens at the end of step 2, so an
/// invalid code never consumes anything.
class JoinHouseholdScreen extends ConsumerStatefulWidget {
  const JoinHouseholdScreen({super.key});

  @override
  ConsumerState<JoinHouseholdScreen> createState() => _JoinHouseholdScreenState();
}

class _JoinHouseholdScreenState extends ConsumerState<JoinHouseholdScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  int _step = 1;
  bool _submitting = false;
  Object? _error;

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _next() {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    setState(() {
      _error = null;
      _step = 2;
    });
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(householdRepositoryProvider).acceptInvite(
            code: _codeController.text,
            displayName: _nameController.text,
          );
      if (!mounted) return;
      ref.invalidate(membershipProvider);
      ref.invalidate(invitesProvider);
      ref.invalidate(linkedMemberProvider);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PopScope(
      canPop: _step == 1,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && mounted) setState(() => _step = 1);
      },
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.join_household_action)),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error != null) ...[
                    ErrorBanner(error: _error!),
                    const SizedBox(height: 20),
                  ],
                  Form(
                    key: _formKey,
                    child: _step == 1
                        ? TextFormField(
                            controller: _codeController,
                            enabled: !_submitting,
                            textCapitalization: TextCapitalization.characters,
                            textInputAction: TextInputAction.done,
                            maxLength: 6,
                            autofillHints: const [AutofillHints.oneTimeCode],
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp('[A-Za-z0-9]'),
                              ),
                              UpperCaseFormatter(),
                            ],
                            decoration: InputDecoration(
                              labelText: l10n.invite_code,
                              hintText: l10n.invite_code_hint,
                              counterText: '',
                            ),
                            validator: (value) =>
                                fieldError(context, Validators.inviteCode(value)),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextFormField(
                                controller: _nameController,
                                enabled: !_submitting,
                                textInputAction: TextInputAction.done,
                                maxLength: 40,
                                decoration: InputDecoration(
                                  labelText: l10n.member_name,
                                  hintText: l10n.member_name_hint,
                                  helperText: l10n.join_name_hint,
                                  counterText: '',
                                ),
                                validator: (value) =>
                                    fieldError(context, Validators.displayName(value)),
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _submitting
                        ? null
                        : (_step == 1 ? _next : _submit),
                    child: _submitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_step == 1 ? l10n.next : l10n.join_household_action),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) =>
      newValue.copyWith(text: newValue.text.toUpperCase());
}

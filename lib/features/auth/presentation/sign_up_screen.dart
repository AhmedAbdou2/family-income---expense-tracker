import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/utils/form_messages.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/error_view.dart';
import '../domain/auth_repository.dart';
import 'providers.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _submitting = false;
  bool _confirmationSent = false;
  Object? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
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
      final outcome = await ref.read(authRepositoryProvider).signUp(
            email: _emailController.text,
            password: _passwordController.text,
          );
      if (!mounted) return;
      if (outcome == SignUpOutcome.confirmationEmailSent) {
        setState(() => _confirmationSent = true);
      }
      // When signed in directly, the router redirect takes over.
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.sign_up_title)),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: _confirmationSent ? _buildConfirmation(context) : _buildForm(context),
          ),
        ),
      ),
    );
  }

  Widget _buildConfirmation(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.mark_email_read_outlined, size: 56, color: scheme.primary),
        const SizedBox(height: 16),
        Text(
          l10n.sign_up_email_sent,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => context.go('/sign-in'),
          child: Text(l10n.back_to_sign_in),
        ),
      ],
    );
  }

  Widget _buildForm(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_error != null) ...[
          ErrorBanner(error: _error!),
          const SizedBox(height: 20),
        ],
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _emailController,
                enabled: !_submitting,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                decoration: InputDecoration(labelText: l10n.email),
                validator: (value) =>
                    fieldError(context, Validators.email(value)),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                enabled: !_submitting,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                decoration: InputDecoration(
                  labelText: l10n.password,
                  helperText: l10n.password_too_short,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                validator: (value) =>
                    fieldError(context, Validators.password(value)),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmController,
                enabled: !_submitting,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                onFieldSubmitted: (_) => _submit(),
                decoration: InputDecoration(labelText: l10n.confirm_password),
                validator: (value) => fieldError(
                  context,
                  Validators.confirmPassword(
                    value,
                    _passwordController.text,
                  ),
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
                    : Text(l10n.sign_up_action),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                l10n.have_account_prompt,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            TextButton(
              onPressed: _submitting ? null : () => context.go('/sign-in'),
              child: Text(l10n.sign_in_action),
            ),
          ],
        ),
      ],
    );
  }
}

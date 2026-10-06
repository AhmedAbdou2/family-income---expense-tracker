import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/utils/form_messages.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/error_view.dart';
import '../presentation/providers.dart';

/// Common currencies for households in the region. Currency is stored as an
/// ISO-like 3-letter code (households.currency) - labels are the codes
/// themselves, which are identical in both languages.
const List<String> kSupportedCurrencies = [
  'SAR',
  'AED',
  'EGP',
  'KWD',
  'QAR',
  'OMR',
  'BHD',
  'JOD',
  'IQD',
  'YER',
  'SDG',
  'MAD',
  'TND',
  'DZD',
  'LBP',
  'SYP',
  'TRY',
  'USD',
  'EUR',
  'GBP',
];

class CreateHouseholdScreen extends ConsumerStatefulWidget {
  const CreateHouseholdScreen({super.key});

  @override
  ConsumerState<CreateHouseholdScreen> createState() =>
      _CreateHouseholdScreenState();
}

class _CreateHouseholdScreenState extends ConsumerState<CreateHouseholdScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String _currency = 'SAR';
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
      await ref.read(householdRepositoryProvider).createHousehold(
            name: _nameController.text,
            currency: _currency,
          );
      if (!mounted) return;
      // Membership is now non-null: the router redirect sends us to '/'.
      ref.invalidate(membershipProvider);
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
      appBar: AppBar(title: Text(l10n.create_household_action)),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _nameController,
                        enabled: !_submitting,
                        textInputAction: TextInputAction.done,
                        maxLength: 80,
                        decoration: InputDecoration(
                          labelText: l10n.household_name,
                          hintText: l10n.household_name_hint,
                          counterText: '',
                        ),
                        validator: (value) => fieldError(
                          context,
                          Validators.required(value, max: 80),
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _currency,
                        decoration: InputDecoration(labelText: l10n.currency),
                        items: [
                          for (final code in kSupportedCurrencies)
                            DropdownMenuItem(value: code, child: Text(code)),
                        ],
                        onChanged: _submitting
                            ? null
                            : (value) => setState(() => _currency = value ?? 'SAR'),
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _submitting ? null : _submit,
                        child: _submitting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(l10n.create_household_action),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

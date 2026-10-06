import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

/// Full-screen loading state with the localized default message.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(message ?? context.l10n.loading),
        ],
      ),
    );
  }
}

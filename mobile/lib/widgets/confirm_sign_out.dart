import 'package:flutter/material.dart';

import '../state/auth_state.dart';

/// Requires two explicit confirmations before ending the signed-in session.
Future<void> confirmSignOut(BuildContext context, AuthState authState) async {
  final firstConfirmation = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Sign out?'),
      content: const Text('You will need to sign in again to use your account.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Stay signed in')),
        FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Continue')),
      ],
    ),
  );
  if (firstConfirmation != true || !context.mounted) return;

  final secondConfirmation = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Confirm sign out'),
      content: const Text('Are you sure you want to sign out now?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Sign out'),
        ),
      ],
    ),
  );
  if (secondConfirmation == true && context.mounted) await authState.logout();
}

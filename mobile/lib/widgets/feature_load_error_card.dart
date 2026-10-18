import 'package:flutter/material.dart';

import '../api/api_exceptions.dart';

/// Keep server diagnostics out of student-facing error messages.
class FeatureLoadErrorCard extends StatelessWidget {
  final Object error;
  final String feature;
  final Future<void> Function()? onRetry;
  final VoidCallback onSupport;
  final bool showingSavedData;

  const FeatureLoadErrorCard({
    super.key,
    required this.error,
    required this.feature,
    required this.onRetry,
    required this.onSupport,
    this.showingSavedData = false,
  });

  @override
  Widget build(BuildContext context) {
    final apiError = error is ApiException ? error as ApiException : null;
    final message = apiError?.isSecurityChallenge == true
        ? 'Quiz LAB’s server is blocking this request. Please contact support.'
        : apiError?.statusCode == 404
        ? '$feature is unavailable right now. Please contact support.'
        : apiError?.message ?? 'Check your connection and try again.';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            const Icon(Icons.cloud_off_rounded, size: 30),
            const SizedBox(height: 10),
            Text(
              'Could not load ${feature.toLowerCase()}',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            if (showingSavedData) ...[
              const SizedBox(height: 8),
              const Text(
                'Showing your last loaded data.',
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              alignment: WrapAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try again'),
                ),
                TextButton(
                  onPressed: onSupport,
                  child: const Text('Contact support'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

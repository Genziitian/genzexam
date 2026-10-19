import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/pro_access_guard.dart';
import '../screens/student/pro_membership_card.dart';

/// Offline downloads are a Pro feature. Returns true when the download may
/// go ahead; otherwise shows the Pro prompt and returns false. When Pro status
/// cannot be checked (offline), it lets the request run and report its own error.
Future<bool> ensureProForDownload(
  BuildContext context,
  ApiClient client,
  int userId,
) async {
  final access = await ProAccessGuard.refresh(client, userId);
  if (access == null || access == ProAccess.active) return true;
  if (context.mounted) await showProDownloadPrompt(context, client);
  return false;
}

Future<void> showProDownloadPrompt(BuildContext context, ApiClient client) {
  return showDialog<void>(
    context: context,
    builder: (dialog) => Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFFE08A), Color(0xFFF59E0B)],
                ),
              ),
              child: const Icon(
                Icons.download_for_offline_rounded,
                size: 38,
                color: Color(0xFF5B3A00),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Download offline',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Download offline is only available for Pro users.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14.5,
                height: 1.45,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      foregroundColor: const Color(0xFF334155),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () => Navigator.pop(dialog),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(dialog);
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              ProMembershipScreen(apiClient: client),
                        ),
                      );
                    },
                    child: const Text('Get Pro'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

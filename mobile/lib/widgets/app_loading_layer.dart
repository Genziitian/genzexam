import 'package:flutter/material.dart';

import '../state/app_activity.dart';

/// Above every route and dialog; does not replace the screen or its navigation.
class AppLoadingLayer extends StatelessWidget {
  final Widget child;
  const AppLoadingLayer({super.key, required this.child});

  @override
  Widget build(
    BuildContext context,
  ) => ValueListenableBuilder<ActivitySnapshot?>(
    valueListenable: AppActivity.current,
    child: child,
    builder: (context, activity, child) => Stack(
      children: [
        ExcludeSemantics(excluding: activity?.blocking == true, child: child!),
        if (activity != null && activity.blocking) ...[
          const Positioned.fill(
            child: ModalBarrier(dismissible: false, color: Color(0x99020617)),
          ),
          Positioned.fill(
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Semantics(
                    liveRegion: true,
                    scopesRoute: true,
                    explicitChildNodes: true,
                    namesRoute: true,
                    label: activity.label,
                    child: Material(
                      color: Colors.white,
                      elevation: 24,
                      borderRadius: BorderRadius.circular(24),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 360),
                        child: Padding(
                          padding: const EdgeInsets.all(28),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircularProgressIndicator(
                                color: Color(0xFF3A3FD8),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                activity.label,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0E1330),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                activity.slow
                                    ? 'This is taking longer than usual. We are still waiting for it to finish.'
                                    : 'Please wait while we finish this step.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF606989),
                                ),
                              ),
                              if (activity.count > 1)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    '${activity.count} tasks in progress',
                                  ),
                                ),
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: AppActivity.minimize,
                                child: const Text('Keep browsing'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
        if (activity != null && !activity.blocking)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: SafeArea(
              child: IgnorePointer(
                child: Semantics(
                  liveRegion: true,
                  child: Material(
                    color: Colors.white,
                    elevation: 8,
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF3A3FD8),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              activity.label +
                                  (activity.slow ? ' — still working…' : ''),
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF0E1330),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

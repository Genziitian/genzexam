import 'package:flutter/material.dart';

import '../state/app_activity.dart';

/// Screens own their read/loading indicators. Only blocking work uses the
/// shared loader; its opaque backdrop covers any indicator below it.
class AppLoadingLayer extends StatelessWidget {
  final Widget child;
  const AppLoadingLayer({super.key, required this.child});

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<ActivitySnapshot?>(
        valueListenable: AppActivity.current,
        child: child,
        builder: (context, activity, child) => Stack(
          children: [
            ExcludeSemantics(
              excluding: activity?.blocking == true,
              child: child!,
            ),
            if (activity?.blocking == true)
              Positioned.fill(
                child: ModalBarrier(
                  dismissible: false,
                  color: Theme.of(context).scaffoldBackgroundColor,
                ),
              ),
            if (activity?.blocking == true)
              Positioned.fill(
                child: IgnorePointer(
                  child: Center(
                    child: Semantics(
                      label: activity!.label,
                      liveRegion: true,
                      child: const SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: Color(0xFF3A3FD8),
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

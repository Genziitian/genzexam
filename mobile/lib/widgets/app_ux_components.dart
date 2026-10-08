import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Centralized UX & Polish Utilities for Quiz Lab Mobile:
/// 1. AppHaptics: Subtle, tactile haptic feedback for buttons, tabs, and actions.
/// 2. AppKeyboardDismiss: Wrapper to dismiss on-screen keyboard when tapping outside inputs.
/// 3. AppShimmer: Lightweight shimmer skeleton loader without third-party dependencies.
/// 4. AppErrorCard: Premium network failure card with retry action.

// ============================================================================
// 1. HAPTIC FEEDBACK UTILITIES
// ============================================================================
class AppHaptics {
  /// Subtle impact on standard button clicks, card taps, option selections.
  static void light() {
    HapticFeedback.lightImpact();
  }

  /// Click feel on tab bar switches, filter chips, radio choices.
  static void selection() {
    HapticFeedback.selectionClick();
  }

  /// Medium impact on major milestones: exam submission, checkout, sign out.
  static void medium() {
    HapticFeedback.mediumImpact();
  }

  /// Heavy impact on errors or destructive warnings.
  static void heavy() {
    HapticFeedback.heavyImpact();
  }
}

// ============================================================================
// 2. KEYBOARD DISMISSAL WRAPPER
// ============================================================================
class AppKeyboardDismiss extends StatelessWidget {
  final Widget child;

  const AppKeyboardDismiss({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        final currentFocus = FocusScope.of(context);
        if (!currentFocus.hasPrimaryFocus && currentFocus.focusedChild != null) {
          currentFocus.unfocus();
        }
      },
      behavior: HitTestBehavior.translucent,
      child: child,
    );
  }
}

// ============================================================================
// 3. SHIMMER & SKELETON LOADERS
// ============================================================================
class AppShimmer extends StatefulWidget {
  final double? width;
  final double? height;
  final double borderRadius;
  final EdgeInsetsGeometry? margin;
  final Color baseColor;
  final Color highlightColor;

  const AppShimmer({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 8,
    this.margin,
    this.baseColor = const Color(0xFFE2E8F0),
    this.highlightColor = const Color(0xFFF8FAFC),
  });

  @override
  State<AppShimmer> createState() => _AppShimmerState();
}

class _AppShimmerState extends State<AppShimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.height,
      margin: widget.margin,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              gradient: LinearGradient(
                begin: Alignment(-1.5 + (_controller.value * 3.0), -0.3),
                end: Alignment(-0.5 + (_controller.value * 3.0), 0.3),
                colors: [
                  widget.baseColor,
                  widget.highlightColor,
                  widget.baseColor,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Pre-composed Shimmer Skeleton Cards matching real app layout components.
class AppShimmerCard {
  /// Skeleton for Storefront Paper Card
  static Widget paper() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              AppShimmer(width: 60, height: 20, borderRadius: 6),
              AppShimmer(width: 80, height: 16, borderRadius: 4),
            ],
          ),
          const SizedBox(height: 10),
          const AppShimmer(width: double.infinity, height: 18, borderRadius: 4),
          const SizedBox(height: 6),
          const AppShimmer(width: 200, height: 14, borderRadius: 4),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              AppShimmer(width: 120, height: 14, borderRadius: 4),
              AppShimmer(width: 76, height: 28, borderRadius: 6),
            ],
          ),
        ],
      ),
    );
  }

  /// Skeleton for a list of papers or exam items
  static Widget list({int count = 4}) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: count,
      itemBuilder: (_, __) => paper(),
    );
  }

  /// Skeleton for Home Dashboard
  static Widget dashboard() {
    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        // Weekly Goal Skeleton
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              AppShimmer(width: 140, height: 16, borderRadius: 4),
              SizedBox(height: 10),
              AppShimmer(width: double.infinity, height: 10, borderRadius: 5),
              SizedBox(height: 10),
              AppShimmer(width: 180, height: 12, borderRadius: 4),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Stat Cards Skeleton
        Row(
          children: const [
            Expanded(child: AppShimmer(height: 72, borderRadius: 12)),
            SizedBox(width: 10),
            Expanded(child: AppShimmer(height: 72, borderRadius: 12)),
            SizedBox(width: 10),
            Expanded(child: AppShimmer(height: 72, borderRadius: 12)),
          ],
        ),
        const SizedBox(height: 16),
        // Action Card Skeleton
        const AppShimmer(height: 80, borderRadius: 14),
        const SizedBox(height: 16),
        // Item Skeletons
        paper(),
        paper(),
      ],
    );
  }

  /// Skeleton for Support Discussions
  static Widget discussions({int count = 4}) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: count,
      itemBuilder: (_, __) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                AppShimmer(width: 80, height: 18, borderRadius: 6),
                AppShimmer(width: 60, height: 14, borderRadius: 4),
              ],
            ),
            SizedBox(height: 10),
            AppShimmer(width: double.infinity, height: 16, borderRadius: 4),
            SizedBox(height: 6),
            AppShimmer(width: 180, height: 14, borderRadius: 4),
            SizedBox(height: 12),
            AppShimmer(width: 100, height: 14, borderRadius: 4),
          ],
        ),
      ),
    );
  }

  /// Skeleton for Manager Sales Metrics
  static Widget managerWorkspace() {
    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        // Headline card
        const AppShimmer(height: 150, borderRadius: 18),
        const SizedBox(height: 16),
        // Metric boxes
        Row(
          children: const [
            Expanded(child: AppShimmer(height: 80, borderRadius: 12)),
            SizedBox(width: 12),
            Expanded(child: AppShimmer(height: 80, borderRadius: 12)),
          ],
        ),
        const SizedBox(height: 18),
        // Order list skeletons
        paper(),
        paper(),
        paper(),
      ],
    );
  }
}

// ============================================================================
// 4. PREMIUM ERROR STATE CARD WITH RETRY ACTION
// ============================================================================
class AppErrorCard extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onRetry;
  final IconData icon;

  const AppErrorCard({
    super.key,
    this.title = 'Unable to Load Data',
    required this.message,
    required this.onRetry,
    this.icon = Icons.cloud_off_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: const Color(0xFFDC2626), size: 28),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  AppHaptics.light();
                  onRetry();
                },
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try Again', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

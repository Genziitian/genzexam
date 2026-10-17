import 'dart:async';

import 'package:flutter/foundation.dart';

class ActivitySnapshot {
  final String label;
  final bool blocking;
  final bool slow;
  final int count;

  const ActivitySnapshot(this.label, this.blocking, this.slow, this.count);
}

class _Activity {
  final String label;
  bool blocking;
  bool ready = false;
  bool slow = false;
  Timer? showTimer;
  Timer? slowTimer;

  _Activity(this.label, this.blocking);
}

/// One shared view of real work, including overlapping requests and retries.
class AppActivity {
  static final current = ValueNotifier<ActivitySnapshot?>(null);
  static final _tasks = <int, _Activity>{};
  static int _sequence = 0;
  static bool _scheduled = false;

  static VoidCallback begin(String label, {bool blocking = true}) {
    final id = ++_sequence;
    final task = _Activity(label, blocking);
    _tasks[id] = task;
    task.showTimer = Timer(const Duration(milliseconds: 180), () {
      task.ready = true;
      _publish();
    });
    task.slowTimer = Timer(const Duration(seconds: 12), () {
      task.slow = true;
      _publish();
    });
    var finished = false;
    return () {
      if (finished) return;
      finished = true;
      task.showTimer?.cancel();
      task.slowTimer?.cancel();
      _tasks.remove(id);
      _publish();
    };
  }

  static Future<T> run<T>(
    String label,
    Future<T> Function() action, {
    bool blocking = true,
  }) async {
    final finish = begin(label, blocking: blocking);
    try {
      return await action();
    } finally {
      finish();
    }
  }

  static void minimize() {
    for (final task in _tasks.values) {
      task.blocking = false;
    }
    _publish();
  }

  static void _publish() {
    if (_scheduled) return;
    _scheduled = true;
    scheduleMicrotask(() {
      _scheduled = false;
      final ready = _tasks.values.where((task) => task.ready).toList();
      if (ready.isEmpty) {
        current.value = null;
        return;
      }
      final blocking = ready.where((task) => task.blocking).toList();
      final task = blocking.isEmpty ? ready.last : blocking.last;
      current.value = ActivitySnapshot(
        task.label,
        blocking.isNotEmpty,
        task.slow,
        ready.length,
      );
    });
  }

  static VoidCallback request(
    String path,
    String method, {
    Map<String, dynamic>? extra,
  }) {
    final read = method == 'GET' || method == 'HEAD';
    final background =
        extra?['loadingBlocking'] == false ||
        RegExp(r'/(answers|events|state|heartbeat|seen|notifications)(/|$)')
            .hasMatch(path) ||
        path.endsWith('/auth/google/handoff');
    var label = read ? 'Loading…' : 'Saving changes…';
    if (path.contains('/auth/')) {
      label = read
          ? 'Checking your account…'
          : path.contains('logout')
          ? 'Signing out…'
          : path.contains('login') || path.contains('google')
          ? 'Signing in…'
          : 'Updating your account…';
    } else if (path.contains('uploaded-papers')) {
      label = read
          ? 'Loading your uploads…'
          : 'Uploading and preparing your paper…';
    } else if (path.contains('/submit')) {
      label = 'Submitting your answers…';
    } else if (path.endsWith('/attempts')) {
      label = 'Starting your paper…';
    } else if (path.contains('download')) {
      label = 'Downloading your paper…';
    } else if (path.contains('orders') || path.contains('razorpay')) {
      label = 'Preparing secure checkout…';
    } else if (path.contains('profile')) {
      label = read ? 'Loading your profile…' : 'Saving your profile…';
    } else if (path.contains('dashboard')) {
      label = 'Loading your dashboard…';
    } else if (path.contains('leaderboard')) {
      label = 'Loading rankings…';
    } else if (path.contains('courses') || path.contains('quizzes')) {
      label = read ? 'Loading papers and courses…' : 'Updating your paper…';
    } else if (method == 'DELETE') {
      label = 'Deleting…';
    }
    return begin(
      extra?['loadingLabel'] as String? ?? label,
      blocking: extra?['loadingBlocking'] as bool? ?? (!read && !background),
    );
  }
}

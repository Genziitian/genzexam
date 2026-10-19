import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_client.dart';

enum ProAccess {
  /// Pro is confirmed and has not run out.
  active,

  /// Pro has ended. Downloads stay locked until the member renews.
  expired,

  /// Nothing trustworthy is stored (first run after an update, a long time
  /// offline, or a clock that moved backwards). The app must go online once.
  unverified,
}

/// Decides whether downloaded papers may be opened, online or offline.
///
/// The last server-confirmed membership is kept in secure storage. Offline, the
/// app trusts it only until the stored end date, never longer than
/// [maxOfflineTrust] since the last online check, and never after the device
/// clock has been wound back.
class ProAccessGuard {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const Duration maxOfflineTrust = Duration(days: 7);
  static const Duration _clockSlack = Duration(minutes: 10);

  static String _key(int userId) => 'pro_access_$userId';

  static Future<Map<String, dynamic>?> _read(int userId) async {
    try {
      final raw = await _storage.read(key: _key(userId));
      return raw == null ? null : jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<void> _write(int userId, Map<String, dynamic> value) =>
      _storage.write(key: _key(userId), value: jsonEncode(value));

  /// Asks the server for the current membership and stores the answer.
  /// Returns null when the server could not be reached.
  static Future<ProAccess?> refresh(ApiClient client, int userId) async {
    try {
      final response = await client.get<Map<String, dynamic>>('/membership');
      final data = response.data;
      if (data == null) return null;
      final isPro = data['is_pro'] == true;
      final sub = data['subscription'] is Map
          ? Map<String, dynamic>.from(data['subscription'] as Map)
          : const <String, dynamic>{};
      final until = DateTime.tryParse(
        sub['current_period_ends_at']?.toString() ?? '',
      );
      final now = DateTime.now().millisecondsSinceEpoch;
      await _write(userId, {
        'is_pro': isPro,
        'until': until?.millisecondsSinceEpoch,
        'verified_at': now,
        'last_seen': now,
      });
      return isPro ? ProAccess.active : ProAccess.expired;
    } catch (_) {
      return null;
    }
  }

  /// Judges access from what is stored on the device (no network).
  static Future<ProAccess> cached(int userId) async {
    final saved = await _read(userId);
    if (saved == null) return ProAccess.unverified;
    final now = DateTime.now().millisecondsSinceEpoch;
    final lastSeen = (saved['last_seen'] as num?)?.toInt() ?? 0;
    final verifiedAt = (saved['verified_at'] as num?)?.toInt() ?? 0;
    // A clock moved backwards could revive an ended membership.
    if (now < lastSeen - _clockSlack.inMilliseconds) {
      return ProAccess.unverified;
    }
    await _write(userId, {
      ...saved,
      'last_seen': now > lastSeen ? now : lastSeen,
    });
    if (saved['is_pro'] != true) return ProAccess.expired;
    final until = (saved['until'] as num?)?.toInt();
    if (until != null && now > until) return ProAccess.expired;
    if (now - verifiedAt > maxOfflineTrust.inMilliseconds) {
      return ProAccess.unverified;
    }
    return ProAccess.active;
  }

  /// Online answers win; offline falls back to the stored state.
  static Future<ProAccess> check(ApiClient client, int userId) async {
    final live = await refresh(
      client,
      userId,
    ).timeout(const Duration(seconds: 6), onTimeout: () => null);
    return live ?? await cached(userId);
  }
}

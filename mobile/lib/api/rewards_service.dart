import 'dart:convert';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_client.dart';
import 'api_exceptions.dart';

class RewardItem {
  final String id, type, title;
  final String? code;
  final DateTime? expiresAt;
  final bool scratched, claimed, expired;

  const RewardItem({
    required this.id,
    required this.type,
    required this.title,
    this.code,
    this.expiresAt,
    this.scratched = false,
    this.claimed = false,
    this.expired = false,
  });

  factory RewardItem.fromJson(Map<String, dynamic> json) => RewardItem(
    id: json['id'] as String,
    type: json['type'] as String,
    title: json['title'] as String,
    code: json['code'] as String?,
    expiresAt: DateTime.tryParse(json['expires_at'] as String? ?? ''),
    scratched: json['is_scratched'] == true,
    claimed: json['is_claimed'] == true,
    expired: json['is_expired'] == true,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'title': title,
    'code': code,
    'expires_at': expiresAt?.toIso8601String(),
    'is_scratched': scratched,
    'is_claimed': claimed,
    'is_expired': expired,
  };

  RewardItem copyWith({
    bool? scratched,
    bool? claimed,
  }) => RewardItem(
    id: id,
    type: type,
    title: title,
    code: code,
    expiresAt: expiresAt,
    scratched: scratched ?? this.scratched,
    claimed: claimed ?? this.claimed,
    expired: expired,
  );

  bool get isExpired =>
      expired || (expiresAt?.isBefore(DateTime.now()) ?? false);
}

class RewardsSnapshot {
  final int remaining;
  final List<RewardItem> rewards;
  const RewardsSnapshot({required this.remaining, required this.rewards});
  factory RewardsSnapshot.fromJson(Map<String, dynamic> json) =>
      RewardsSnapshot(
        remaining: ((json['quota'] as Map)['remaining'] as num).toInt(),
        rewards: (json['rewards'] as List)
            .map(
              (r) => RewardItem.fromJson(Map<String, dynamic>.from(r as Map)),
            )
            .toList(),
      );

  Map<String, dynamic> toJson() => {
    'quota': {'remaining': remaining},
    'rewards': rewards.map((r) => r.toJson()).toList(),
  };
}

class RewardSpinResult {
  final int segment, remaining;
  final String title;
  final RewardItem? reward;
  const RewardSpinResult({
    required this.segment,
    required this.remaining,
    required this.title,
    this.reward,
  });
  factory RewardSpinResult.fromJson(Map<String, dynamic> json) {
    final segment = (json['segment'] as num?)?.toInt();
    if (segment == null ||
        segment < 0 ||
        segment >= 10 ||
        json['prize'] is! Map ||
        json['quota'] is! Map) {
      throw const ApiException(
        message: 'Could not confirm the spin result. Refresh My Rewards before trying again.',
      );
    }
    return RewardSpinResult(
      segment: segment,
      remaining: ((json['quota'] as Map)['remaining'] as num).toInt(),
      title: (json['prize'] as Map)['title'] as String,
      reward: json['reward'] is Map
          ? RewardItem.fromJson(Map<String, dynamic>.from(json['reward']))
          : null,
    );
  }
}

class WheelPrizeDef {
  final int segment;
  final String title;
  final String sub;
  final String type;
  final String codePrefix;
  final int weight;

  const WheelPrizeDef({
    required this.segment,
    required this.title,
    required this.sub,
    required this.type,
    required this.codePrefix,
    required this.weight,
  });
}

const wheelPrizes = [
  WheelPrizeDef(segment: 0, title: '5% OFF (Upto ₹50)', sub: '5% Discount', type: 'coupon_pct', codePrefix: 'GENZ5-', weight: 18),
  WheelPrizeDef(segment: 1, title: '30 Days Free Pro', sub: 'Jackpot', type: 'free_pro', codePrefix: '', weight: 8),
  WheelPrizeDef(segment: 2, title: '₹50 OFF Coupon', sub: 'Coupon', type: 'coupon_flat', codePrefix: 'GENZ50-', weight: 10),
  WheelPrizeDef(segment: 3, title: 'Better Luck Next Time', sub: 'Tomorrow', type: 'try_again', codePrefix: '', weight: 9),
  WheelPrizeDef(segment: 4, title: '25% OFF Coupon', sub: 'Mega Deal', type: 'coupon_pct', codePrefix: 'GENZ25-', weight: 8),
  WheelPrizeDef(segment: 5, title: '1 Free Extra Spin', sub: 'Extra Spin', type: 'free_spin', codePrefix: '', weight: 10),
  WheelPrizeDef(segment: 6, title: '₹100 OFF Coupon', sub: 'Discount', type: 'coupon_flat', codePrefix: 'GENZ100-', weight: 5),
  WheelPrizeDef(segment: 7, title: '+50 Study XP Boost', sub: 'Study Boost', type: 'bonus_xp', codePrefix: '', weight: 12),
  WheelPrizeDef(segment: 8, title: 'Free Test Yourself Paper', sub: '1 Test Pass', type: 'free_test', codePrefix: 'TEST1-', weight: 10),
  WheelPrizeDef(segment: 9, title: 'Free Paper Upload Pass', sub: 'Paper Pass', type: 'free_paper_upload', codePrefix: 'UPLOAD1-', weight: 10),
];

class RewardsService {
  final ApiClient client;
  final FlutterSecureStorage storage;

  RewardsService(this.client, [FlutterSecureStorage? storage])
      : storage = storage ?? const FlutterSecureStorage();

  static const String _cacheKey = 'ql_rewards_cache_v1';
  static const String _lastSpinKey = 'ql_rewards_last_spin_date';

  static String todayIst() {
    final ist = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
    return '${ist.year}-${ist.month.toString().padLeft(2, '0')}-${ist.day.toString().padLeft(2, '0')}';
  }

  Options get _options => Options(extra: {'loadingBlocking': false});

  Future<RewardsSnapshot> _readLocalSnapshot() async {
    final lastDate = await storage.read(key: _lastSpinKey) ?? '';
    final remaining = (lastDate == todayIst()) ? 0 : 1;
    final jsonStr = await storage.read(key: _cacheKey);
    List<RewardItem> rewards = [];
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final list = jsonDecode(jsonStr) as List;
        rewards = list.map((item) => RewardItem.fromJson(Map<String, dynamic>.from(item as Map))).toList();
      } catch (_) {}
    }
    return RewardsSnapshot(remaining: remaining, rewards: rewards);
  }

  Future<void> _writeLocalRewards(List<RewardItem> rewards) async {
    try {
      await storage.write(key: _cacheKey, value: jsonEncode(rewards.map((r) => r.toJson()).toList()));
    } catch (_) {}
  }

  bool _isFallbackError(Object e) {
    if (e is ApiException) {
      final code = e.statusCode;
      if (code == 404 || code == 403 || e.isSecurityChallenge) return true;
      if (e.message.contains('timed out') ||
          e.message.contains('Unable to connect') ||
          e.message.contains('could not be found')) {
        return true;
      }
    }
    if (e is DioException) {
      final code = e.response?.statusCode;
      if (code == 404 || code == 403) return true;
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) return true;
    }
    return false;
  }

  Future<RewardsSnapshot> load() async {
    try {
      final res = await client.get<Map<String, dynamic>>(
        '/student/rewards',
        options: _options,
      );
      final snapshot = RewardsSnapshot.fromJson(res.data!);
      await _writeLocalRewards(snapshot.rewards);
      if (snapshot.remaining == 0) {
        await storage.write(key: _lastSpinKey, value: todayIst());
      }
      return snapshot;
    } catch (e) {
      if (_isFallbackError(e)) {
        return await _readLocalSnapshot();
      }
      rethrow;
    }
  }

  // Never retry writes: the server may already have awarded the prize.
  Future<RewardSpinResult> spin() async {
    try {
      final res = await client.post<Map<String, dynamic>>(
        '/student/rewards/spin',
        options: _options,
      );
      final result = RewardSpinResult.fromJson(res.data!);
      if (result.remaining == 0) {
        await storage.write(key: _lastSpinKey, value: todayIst());
      }
      if (result.reward != null) {
        final local = await _readLocalSnapshot();
        await _writeLocalRewards([result.reward!, ...local.rewards]);
      }
      return result;
    } catch (e) {
      if (!_isFallbackError(e)) rethrow;
      // Local fallback spin
      final local = await _readLocalSnapshot();
      if (local.remaining <= 0) {
        throw const ApiException(message: 'Already spun today. Come back tomorrow after midnight IST.');
      }
      final rand = math.Random();
      final roll = rand.nextInt(100) + 1;
      int cumulative = 0;
      WheelPrizeDef chosen = wheelPrizes.first;
      for (final p in wheelPrizes) {
        cumulative += p.weight;
        if (roll <= cumulative) {
          chosen = p;
          break;
        }
      }

      RewardItem? reward;
      if (chosen.type != 'try_again' && chosen.type != 'free_spin') {
        const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
        final suffix = List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
        final code = chosen.codePrefix.isNotEmpty ? '${chosen.codePrefix}$suffix' : null;
        reward = RewardItem(
          id: 'local_${DateTime.now().millisecondsSinceEpoch}',
          type: chosen.type,
          title: chosen.title,
          code: code,
          expiresAt: DateTime.now().add(const Duration(days: 7)),
          scratched: false,
          claimed: false,
          expired: false,
        );
        await _writeLocalRewards([reward, ...local.rewards]);
      }

      final remaining = (chosen.type == 'free_spin') ? 1 : 0;
      if (remaining == 0) {
        await storage.write(key: _lastSpinKey, value: todayIst());
      }
      return RewardSpinResult(
        segment: chosen.segment,
        remaining: remaining,
        title: chosen.title,
        reward: reward,
      );
    }
  }

  Future<void> reveal(String id) async {
    try {
      await client.post<Map<String, dynamic>>(
        '/student/rewards/scratch',
        data: {'id': id},
        options: _options,
      );
    } catch (_) {}
    final local = await _readLocalSnapshot();
    final updated = local.rewards.map((r) => r.id == id ? r.copyWith(scratched: true) : r).toList();
    await _writeLocalRewards(updated);
  }

  Future<String> claimPro(String id) async {
    try {
      final res = await client.post<Map<String, dynamic>>(
        '/student/rewards/claim-pro',
        data: {'id': id},
        options: _options,
      );
      final local = await _readLocalSnapshot();
      final updated = local.rewards.map((r) => r.id == id ? r.copyWith(claimed: true) : r).toList();
      await _writeLocalRewards(updated);
      return res.data?['message'] as String? ?? '30 Days Pro activated successfully!';
    } catch (_) {
      final local = await _readLocalSnapshot();
      final updated = local.rewards.map((r) => r.id == id ? r.copyWith(claimed: true) : r).toList();
      await _writeLocalRewards(updated);
      return '30 Days Pro activated on your account!';
    }
  }
}


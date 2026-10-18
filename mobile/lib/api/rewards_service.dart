import 'package:dio/dio.dart';

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

  RewardItem copyWith({bool? scratched, bool? claimed}) => RewardItem(
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
  WheelPrizeDef(
    segment: 0,
    title: '5% OFF (Upto ₹50)',
    sub: '5% Discount',
    type: 'coupon_pct',
    codePrefix: 'GENZ5-',
    weight: 18,
  ),
  WheelPrizeDef(
    segment: 1,
    title: '30 Days Free Pro',
    sub: 'Jackpot',
    type: 'free_pro',
    codePrefix: '',
    weight: 8,
  ),
  WheelPrizeDef(
    segment: 2,
    title: '₹50 OFF Coupon',
    sub: 'Coupon',
    type: 'coupon_flat',
    codePrefix: 'GENZ50-',
    weight: 10,
  ),
  WheelPrizeDef(
    segment: 3,
    title: 'Better Luck Next Time',
    sub: 'Tomorrow',
    type: 'try_again',
    codePrefix: '',
    weight: 9,
  ),
  WheelPrizeDef(
    segment: 4,
    title: '25% OFF Coupon',
    sub: 'Mega Deal',
    type: 'coupon_pct',
    codePrefix: 'GENZ25-',
    weight: 8,
  ),
  WheelPrizeDef(
    segment: 5,
    title: '1 Free Extra Spin',
    sub: 'Extra Spin',
    type: 'free_spin',
    codePrefix: '',
    weight: 10,
  ),
  WheelPrizeDef(
    segment: 6,
    title: '₹100 OFF Coupon',
    sub: 'Discount',
    type: 'coupon_flat',
    codePrefix: 'GENZ100-',
    weight: 5,
  ),
  WheelPrizeDef(
    segment: 7,
    title: '+50 Study XP Boost',
    sub: 'Study Boost',
    type: 'bonus_xp',
    codePrefix: '',
    weight: 12,
  ),
  WheelPrizeDef(
    segment: 8,
    title: 'Free Test Yourself Paper',
    sub: '1 Test Pass',
    type: 'free_test',
    codePrefix: 'TEST1-',
    weight: 10,
  ),
  WheelPrizeDef(
    segment: 9,
    title: 'Free Paper Upload Pass',
    sub: 'Paper Pass',
    type: 'free_paper_upload',
    codePrefix: 'UPLOAD1-',
    weight: 10,
  ),
];

class RewardsService {
  final ApiClient client;

  RewardsService(this.client);

  Options get _options => Options(extra: {'loadingBlocking': false});

  Future<RewardsSnapshot> load() async {
    try {
      final res = await client.get<Map<String, dynamic>>(
        '/student/rewards',
        options: _options,
      );
      return RewardsSnapshot.fromJson(res.data!);
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        throw const ApiException(
          message: 'Daily Rewards is unavailable on the server. Please try again later.',
          statusCode: 404,
        );
      }
      rethrow;
    }
  }

  // Never retry writes or invent local prizes: the server owns every award.
  Future<RewardSpinResult> spin() async {
    final res = await client.post<Map<String, dynamic>>(
      '/student/rewards/spin',
      options: _options,
    );
    return RewardSpinResult.fromJson(res.data!);
  }

  Future<void> reveal(String id) async {
    await client.post<Map<String, dynamic>>(
      '/student/rewards/scratch',
      data: {'id': id},
      options: _options,
    );
  }

  Future<String> claimPro(String id) async {
    final res = await client.post<Map<String, dynamic>>(
      '/student/rewards/claim-pro',
      data: {'id': id},
      options: _options,
    );
    return res.data?['message'] as String? ??
        '30 Days Pro activated successfully!';
  }
}

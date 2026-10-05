/// Leaderboard models matching backend/app/Http/Controllers/LeaderboardController.php
class LeaderboardData {
  final List<GlobalLeaderboardEntry> leaderboard;
  final int? myRank;
  final UserRankMe me;

  const LeaderboardData({
    required this.leaderboard,
    this.myRank,
    required this.me,
  });

  factory LeaderboardData.fromJson(Map<String, dynamic> json) {
    return LeaderboardData(
      leaderboard: (json['leaderboard'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map((e) => GlobalLeaderboardEntry.fromJson(e))
          .toList(),
      myRank: (json['my_rank'] as num?)?.toInt(),
      me: UserRankMe.fromJson(json['me'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'leaderboard': leaderboard.map((e) => e.toJson()).toList(),
      'my_rank': myRank,
      'me': me.toJson(),
    };
  }
}

class GlobalLeaderboardEntry {
  final int rank;
  final int userId;
  final String name;
  final String? avatar;
  final int xp;
  final int level;

  const GlobalLeaderboardEntry({
    required this.rank,
    required this.userId,
    required this.name,
    this.avatar,
    required this.xp,
    required this.level,
  });

  factory GlobalLeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return GlobalLeaderboardEntry(
      rank: (json['rank'] as num).toInt(),
      userId: (json['user_id'] as num).toInt(),
      name: (json['name'] ?? '') as String,
      avatar: json['avatar'] as String?,
      xp: (json['xp'] as num?)?.toInt() ?? 0,
      level: (json['level'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'rank': rank,
      'user_id': userId,
      'name': name,
      'avatar': avatar,
      'xp': xp,
      'level': level,
    };
  }
}

class UserRankMe {
  final int xp;
  final int level;

  const UserRankMe({
    required this.xp,
    required this.level,
  });

  factory UserRankMe.fromJson(Map<String, dynamic> json) {
    return UserRankMe(
      xp: (json['xp'] as num?)?.toInt() ?? 0,
      level: (json['level'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'xp': xp,
      'level': level,
    };
  }
}

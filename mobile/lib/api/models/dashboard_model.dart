/// Complete dashboard model matching backend/app/Http/Controllers/DashboardController.php.
class DashboardData {
  final GreetingInfo greeting;
  final StreakInfo streak;
  final MetricWidget accuracy;
  final MetricWidget hoursThisWeek;
  final RankWidget rank;
  final List<PerformanceDataPoint> performance;
  final TodaysChallenge? todaysChallenge;
  final int activeNow;
  final List<CommunityFeedItem> communityFeed;

  const DashboardData({
    required this.greeting,
    required this.streak,
    required this.accuracy,
    required this.hoursThisWeek,
    required this.rank,
    required this.performance,
    this.todaysChallenge,
    required this.activeNow,
    required this.communityFeed,
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    return DashboardData(
      greeting: GreetingInfo.fromJson(json['greeting'] as Map<String, dynamic>),
      streak: StreakInfo.fromJson(json['streak'] as Map<String, dynamic>),
      accuracy: MetricWidget.fromJson(json['accuracy'] as Map<String, dynamic>),
      hoursThisWeek: MetricWidget.fromJson(json['hours_this_week'] as Map<String, dynamic>),
      rank: RankWidget.fromJson(json['rank'] as Map<String, dynamic>),
      performance: (json['performance'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map((p) => PerformanceDataPoint.fromJson(p))
          .toList(),
      todaysChallenge: json['todays_challenge'] != null
          ? TodaysChallenge.fromJson(json['todays_challenge'] as Map<String, dynamic>)
          : null,
      activeNow: (json['active_now'] as num?)?.toInt() ?? 0,
      communityFeed: (json['community_feed'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map((c) => CommunityFeedItem.fromJson(c))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'greeting': greeting.toJson(),
      'streak': streak.toJson(),
      'accuracy': accuracy.toJson(),
      'hours_this_week': hoursThisWeek.toJson(),
      'rank': rank.toJson(),
      'performance': performance.map((p) => p.toJson()).toList(),
      'todays_challenge': todaysChallenge?.toJson(),
      'active_now': activeNow,
      'community_feed': communityFeed.map((c) => c.toJson()).toList(),
    };
  }
}

class GreetingInfo {
  final String timeOfDay;
  final String weekday;
  final String date;

  const GreetingInfo({
    required this.timeOfDay,
    required this.weekday,
    required this.date,
  });

  factory GreetingInfo.fromJson(Map<String, dynamic> json) {
    return GreetingInfo(
      timeOfDay: (json['time_of_day'] ?? '') as String,
      weekday: (json['weekday'] ?? '') as String,
      date: (json['date'] ?? '') as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'time_of_day': timeOfDay,
      'weekday': weekday,
      'date': date,
    };
  }
}

class StreakInfo {
  final int days;
  final List<int> history;

  const StreakInfo({
    required this.days,
    required this.history,
  });

  factory StreakInfo.fromJson(Map<String, dynamic> json) {
    return StreakInfo(
      days: (json['days'] as num?)?.toInt() ?? 0,
      history: (json['history'] as List? ?? [])
          .map((h) => (h as num).toInt())
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'days': days,
      'history': history,
    };
  }
}

class MetricWidget {
  final double value;
  final double delta;
  final List<double> history;

  const MetricWidget({
    required this.value,
    required this.delta,
    required this.history,
  });

  factory MetricWidget.fromJson(Map<String, dynamic> json) {
    return MetricWidget(
      value: (json['value'] as num?)?.toDouble() ?? 0.0,
      delta: (json['delta'] as num?)?.toDouble() ?? 0.0,
      history: (json['history'] as List? ?? [])
          .map((h) => (h as num).toDouble())
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'value': value,
      'delta': delta,
      'history': history,
    };
  }
}

class RankWidget {
  final int? current;
  final int? previous;
  final int? movedUp;
  final int totalRanked;

  const RankWidget({
    this.current,
    this.previous,
    this.movedUp,
    required this.totalRanked,
  });

  factory RankWidget.fromJson(Map<String, dynamic> json) {
    return RankWidget(
      current: (json['current'] as num?)?.toInt(),
      previous: (json['previous'] as num?)?.toInt(),
      movedUp: (json['moved_up'] as num?)?.toInt(),
      totalRanked: (json['total_ranked'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'current': current,
      'previous': previous,
      'moved_up': movedUp,
      'total_ranked': totalRanked,
    };
  }
}

class PerformanceDataPoint {
  final String label;
  final double accuracy;
  final double speed;
  final double score;
  final int attempts;

  const PerformanceDataPoint({
    required this.label,
    required this.accuracy,
    required this.speed,
    required this.score,
    required this.attempts,
  });

  factory PerformanceDataPoint.fromJson(Map<String, dynamic> json) {
    return PerformanceDataPoint(
      label: (json['label'] ?? '') as String,
      accuracy: (json['accuracy'] as num?)?.toDouble() ?? 0.0,
      speed: (json['speed'] as num?)?.toDouble() ?? 0.0,
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      attempts: (json['attempts'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'accuracy': accuracy,
      'speed': speed,
      'score': score,
      'attempts': attempts,
    };
  }
}

class TodaysChallenge {
  final int quizId;
  final String title;
  final String courseName;
  final String courseSlug;
  final String? icon;
  final int timeLimitMinutes;
  final int xp;

  const TodaysChallenge({
    required this.quizId,
    required this.title,
    required this.courseName,
    required this.courseSlug,
    this.icon,
    required this.timeLimitMinutes,
    required this.xp,
  });

  factory TodaysChallenge.fromJson(Map<String, dynamic> json) {
    return TodaysChallenge(
      quizId: (json['quiz_id'] as num).toInt(),
      title: (json['title'] ?? '') as String,
      courseName: (json['course_name'] ?? '') as String,
      courseSlug: (json['course_slug'] ?? '') as String,
      icon: json['icon'] as String?,
      timeLimitMinutes: (json['time_limit_minutes'] as num?)?.toInt() ?? 0,
      xp: (json['xp'] as num?)?.toInt() ?? 200,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'quiz_id': quizId,
      'title': title,
      'course_name': courseName,
      'course_slug': courseSlug,
      'icon': icon,
      'time_limit_minutes': timeLimitMinutes,
      'xp': xp,
    };
  }
}

class CommunityFeedItem {
  final String name;
  final String courseName;
  final String quizTitle;
  final double percentage;
  final DateTime? submittedAt;
  final int xp;

  const CommunityFeedItem({
    required this.name,
    required this.courseName,
    required this.quizTitle,
    required this.percentage,
    this.submittedAt,
    required this.xp,
  });

  factory CommunityFeedItem.fromJson(Map<String, dynamic> json) {
    return CommunityFeedItem(
      name: (json['name'] ?? '') as String,
      courseName: (json['course_name'] ?? '') as String,
      quizTitle: (json['quiz_title'] ?? '') as String,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
      submittedAt: json['submitted_at'] != null
          ? DateTime.tryParse(json['submitted_at'].toString())
          : null,
      xp: (json['xp'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'course_name': courseName,
      'quiz_title': quizTitle,
      'percentage': percentage,
      'submitted_at': submittedAt?.toIso8601String(),
      'xp': xp,
    };
  }
}

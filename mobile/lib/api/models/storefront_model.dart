class StorefrontPaper {
  final int id;
  final String title;
  final String? description;
  final String? section;
  final int? year;
  final int? timeLimitMinutes;
  final int questionCount;
  final int pricePaise;
  final int? accessDays;
  final StorefrontPaperWeek? week;
  final StorefrontPaperCourse? course;

  const StorefrontPaper({
    required this.id,
    required this.title,
    this.description,
    this.section,
    this.year,
    this.timeLimitMinutes,
    required this.questionCount,
    required this.pricePaise,
    this.accessDays,
    this.week,
    this.course,
  });

  bool get isFree => pricePaise <= 0;
  int get priceRupees => (pricePaise / 100).round();

  factory StorefrontPaper.fromJson(Map<String, dynamic> json) {
    return StorefrontPaper(
      id: json['id'] as int,
      title: json['title'] as String? ?? 'Untitled Paper',
      description: json['description'] as String?,
      section: json['section'] as String?,
      year: json['year'] as int?,
      timeLimitMinutes: json['time_limit_minutes'] as int?,
      questionCount: json['question_count'] as int? ?? 0,
      pricePaise: json['price_paise'] as int? ?? 0,
      accessDays: json['access_days'] as int?,
      week: json['week'] != null ? StorefrontPaperWeek.fromJson(json['week']) : null,
      course: json['course'] != null ? StorefrontPaperCourse.fromJson(json['course']) : null,
    );
  }
}

class StorefrontPaperWeek {
  final int number;
  final String? title;

  const StorefrontPaperWeek({required this.number, this.title});

  factory StorefrontPaperWeek.fromJson(Map<String, dynamic> json) {
    return StorefrontPaperWeek(
      number: json['number'] as int? ?? 0,
      title: json['title'] as String?,
    );
  }
}

class StorefrontPaperCourse {
  final String name;
  final String slug;
  final String? level;
  final String? icon;

  const StorefrontPaperCourse({
    required this.name,
    required this.slug,
    this.level,
    this.icon,
  });

  factory StorefrontPaperCourse.fromJson(Map<String, dynamic> json) {
    return StorefrontPaperCourse(
      name: json['name'] as String? ?? 'General Course',
      slug: json['slug'] as String? ?? '',
      level: json['level'] as String?,
      icon: json['icon'] as String?,
    );
  }
}

class MyPaperItem extends StorefrontPaper {
  final String? source;
  final bool purchased;
  final bool hasAccess;
  final bool available;
  final int attemptCount;
  final bool inProgress;
  final int? lastAttemptId;
  final double? lastScore;
  final double? lastTotalMarks;
  final String? lastSubmittedAt;

  const MyPaperItem({
    required super.id,
    required super.title,
    super.description,
    super.section,
    super.year,
    super.timeLimitMinutes,
    required super.questionCount,
    required super.pricePaise,
    super.accessDays,
    super.week,
    super.course,
    this.source,
    required this.purchased,
    required this.hasAccess,
    required this.available,
    required this.attemptCount,
    required this.inProgress,
    this.lastAttemptId,
    this.lastScore,
    this.lastTotalMarks,
    this.lastSubmittedAt,
  });

  factory MyPaperItem.fromJson(Map<String, dynamic> json) {
    return MyPaperItem(
      id: json['id'] as int,
      title: json['title'] as String? ?? 'Untitled Paper',
      description: json['description'] as String?,
      section: json['section'] as String?,
      year: json['year'] as int?,
      timeLimitMinutes: json['time_limit_minutes'] as int?,
      questionCount: json['question_count'] as int? ?? 0,
      pricePaise: json['price_paise'] as int? ?? 0,
      accessDays: json['access_days'] as int?,
      week: json['week'] != null ? StorefrontPaperWeek.fromJson(json['week']) : null,
      course: json['course'] != null ? StorefrontPaperCourse.fromJson(json['course']) : null,
      source: json['source'] as String?,
      purchased: json['purchased'] as bool? ?? false,
      // Missing means usable, as on the website (only an explicit false blocks access).
      hasAccess: json['has_access'] as bool? ?? true,
      available: json['available'] as bool? ?? true,
      attemptCount: (json['attempt_count'] as num?)?.toInt() ?? 0,
      inProgress: json['in_progress'] as bool? ?? false,
      lastAttemptId: json['last_attempt_id'] as int?,
      // The API may send decimals as strings ("10.00").
      lastScore: json['last_score'] != null ? double.tryParse(json['last_score'].toString()) : null,
      lastTotalMarks: json['last_total_marks'] != null ? double.tryParse(json['last_total_marks'].toString()) : null,
      lastSubmittedAt: json['last_submitted_at'] as String?,
    );
  }
}

class StorefrontOrderResponse {
  final int orderId;
  final String razorpayOrderId;
  final int amountPaise;
  final String keyId;
  final String paperTitle;

  const StorefrontOrderResponse({
    required this.orderId,
    required this.razorpayOrderId,
    required this.amountPaise,
    required this.keyId,
    required this.paperTitle,
  });

  factory StorefrontOrderResponse.fromJson(Map<String, dynamic> json) {
    return StorefrontOrderResponse(
      orderId: json['order_id'] as int,
      razorpayOrderId: json['razorpay_order_id'] as String,
      amountPaise: json['amount_paise'] as int,
      keyId: json['key_id'] as String? ?? '',
      paperTitle: json['paper_title'] as String? ?? 'Quiz Paper',
    );
  }
}

/// Course models matching backend/app/Http/Controllers/CourseController.php and Course.php
class CourseModel {
  final int id;
  final String name;
  final String slug;
  final String? level;
  final String? description;
  final String? icon;
  final bool hasIde;
  final bool? hasIdeProblems;
  final List<WeekModel>? weeks;

  const CourseModel({
    required this.id,
    required this.name,
    required this.slug,
    this.level,
    this.description,
    this.icon,
    required this.hasIde,
    this.hasIdeProblems,
    this.weeks,
  });

  factory CourseModel.fromJson(Map<String, dynamic> json) {
    return CourseModel(
      id: (json['id'] as num).toInt(),
      name: (json['name'] ?? '') as String,
      slug: (json['slug'] ?? '') as String,
      level: json['level'] as String?,
      description: json['description'] as String?,
      icon: json['icon'] as String?,
      hasIde: json['has_ide'] == true,
      hasIdeProblems: json['has_ide_problems'] as bool?,
      weeks: (json['weeks'] as List?)
          ?.whereType<Map<String, dynamic>>()
          .map((w) => WeekModel.fromJson(w))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'level': level,
      'description': description,
      'icon': icon,
      'has_ide': hasIde,
      'has_ide_problems': hasIdeProblems,
      'weeks': weeks?.map((w) => w.toJson()).toList(),
    };
  }
}

class WeekModel {
  final int id;
  final int weekNumber;
  final String title;

  const WeekModel({
    required this.id,
    required this.weekNumber,
    required this.title,
  });

  factory WeekModel.fromJson(Map<String, dynamic> json) {
    return WeekModel(
      id: (json['id'] as num).toInt(),
      weekNumber: (json['week_number'] as num?)?.toInt() ?? 0,
      title: (json['title'] ?? '') as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'week_number': weekNumber,
      'title': title,
    };
  }
}

class CourseQuizListItem {
  final int id;
  final String title;
  final String? description;
  final int timeLimitMinutes;
  final int questionCount;
  final String section;
  final int? weekNumber;
  final int? year;
  final bool userHasAttempted;
  final int attemptCount;
  final DateTime? lastSubmittedAt;

  const CourseQuizListItem({
    required this.id,
    required this.title,
    this.description,
    required this.timeLimitMinutes,
    required this.questionCount,
    required this.section,
    this.weekNumber,
    this.year,
    required this.userHasAttempted,
    required this.attemptCount,
    this.lastSubmittedAt,
  });

  factory CourseQuizListItem.fromJson(Map<String, dynamic> json) {
    return CourseQuizListItem(
      id: (json['id'] as num).toInt(),
      title: (json['title'] ?? '') as String,
      description: json['description'] as String?,
      timeLimitMinutes: (json['time_limit_minutes'] as num?)?.toInt() ?? 0,
      questionCount: (json['question_count'] as num?)?.toInt() ?? 0,
      section: (json['section'] ?? '') as String,
      weekNumber: (json['week_number'] as num?)?.toInt(),
      year: (json['year'] as num?)?.toInt(),
      userHasAttempted: json['user_has_attempted'] == true,
      attemptCount: (json['attempt_count'] as num?)?.toInt() ?? 0,
      lastSubmittedAt: json['last_submitted_at'] != null
          ? DateTime.tryParse(json['last_submitted_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'time_limit_minutes': timeLimitMinutes,
      'question_count': questionCount,
      'section': section,
      'week_number': weekNumber,
      'year': year,
      'user_has_attempted': userHasAttempted,
      'attempt_count': attemptCount,
      'last_submitted_at': lastSubmittedAt?.toIso8601String(),
    };
  }
}

/// Returned by GET /api/courses/{slug}/weeks/{weekNumber}/quizzes
class WeekQuizzesResponse {
  final List<CourseQuizListItem> practice;
  final List<CourseQuizListItem> graded;

  const WeekQuizzesResponse({
    required this.practice,
    required this.graded,
  });

  factory WeekQuizzesResponse.fromJson(Map<String, dynamic> json) {
    return WeekQuizzesResponse(
      practice: (json['practice'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map((q) => CourseQuizListItem.fromJson(q))
          .toList(),
      graded: (json['graded'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map((q) => CourseQuizListItem.fromJson(q))
          .toList(),
    );
  }
}

/// Returned by GET /api/courses/{slug}/practice
class CoursePracticeResponse {
  final CourseModel course;
  final List<CourseQuizListItem> practice;
  final List<CourseQuizListItem> graded;

  const CoursePracticeResponse({
    required this.course,
    required this.practice,
    required this.graded,
  });

  factory CoursePracticeResponse.fromJson(Map<String, dynamic> json) {
    return CoursePracticeResponse(
      course: CourseModel.fromJson(json['course'] as Map<String, dynamic>),
      practice: (json['practice'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map((q) => CourseQuizListItem.fromJson(q))
          .toList(),
      graded: (json['graded'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map((q) => CourseQuizListItem.fromJson(q))
          .toList(),
    );
  }
}

/// Returned by GET /api/courses/{slug}/exam-prep
class CourseExamPrepResponse {
  final List<CourseQuizListItem> quiz1;
  final List<CourseQuizListItem> quiz2;
  final List<CourseQuizListItem> endterm;
  final List<CourseQuizListItem> mockTest;

  const CourseExamPrepResponse({
    required this.quiz1,
    required this.quiz2,
    required this.endterm,
    required this.mockTest,
  });

  factory CourseExamPrepResponse.fromJson(Map<String, dynamic> json) {
    return CourseExamPrepResponse(
      quiz1: (json['quiz1'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map((q) => CourseQuizListItem.fromJson(q))
          .toList(),
      quiz2: (json['quiz2'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map((q) => CourseQuizListItem.fromJson(q))
          .toList(),
      endterm: (json['endterm'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map((q) => CourseQuizListItem.fromJson(q))
          .toList(),
      mockTest: (json['mock_test'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map((q) => CourseQuizListItem.fromJson(q))
          .toList(),
    );
  }
}

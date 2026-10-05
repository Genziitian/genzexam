import 'auth_model.dart';

/// Full quiz detail structure matching backend/app/Http/Controllers/QuizController.php show()
class QuizDetail {
  final int id;
  final String title;
  final String? description;
  final String section;
  final int timeLimitMinutes;
  final QuizCourseRef? course;
  final List<QuestionModel> questions;

  const QuizDetail({
    required this.id,
    required this.title,
    this.description,
    required this.section,
    required this.timeLimitMinutes,
    this.course,
    required this.questions,
  });

  factory QuizDetail.fromJson(Map<String, dynamic> json) {
    return QuizDetail(
      id: (json['id'] as num).toInt(),
      title: (json['title'] ?? '') as String,
      description: json['description'] as String?,
      section: (json['section'] ?? '') as String,
      timeLimitMinutes: (json['time_limit_minutes'] as num?)?.toInt() ?? 0,
      course: json['course'] is Map<String, dynamic>
          ? QuizCourseRef.fromJson(json['course'] as Map<String, dynamic>)
          : null,
      questions: (json['questions'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map((q) => QuestionModel.fromJson(q))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'section': section,
      'time_limit_minutes': timeLimitMinutes,
      'course': course?.toJson(),
      'questions': questions.map((q) => q.toJson()).toList(),
    };
  }
}

class QuizCourseRef {
  final int? id;
  final String? name;
  final String? slug;

  const QuizCourseRef({this.id, this.name, this.slug});

  factory QuizCourseRef.fromJson(Map<String, dynamic> json) {
    return QuizCourseRef(
      id: (json['id'] as num?)?.toInt(),
      name: json['name'] as String?,
      slug: json['slug'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
    };
  }
}

class QuestionModel {
  final int id;
  final String type; // 'mcq_single', 'mcq_multi', 'true_false', 'numerical', 'short_answer', 'comprehension'
  final String stem;
  final String? stemImage;
  final String? stemCode;
  final String? stemCodeLanguage;
  final dynamic stemTable;
  final double marks;
  final String? difficulty;
  final int position;
  final List<QuestionOptionModel> options;

  const QuestionModel({
    required this.id,
    required this.type,
    required this.stem,
    this.stemImage,
    this.stemCode,
    this.stemCodeLanguage,
    this.stemTable,
    required this.marks,
    this.difficulty,
    required this.position,
    required this.options,
  });

  factory QuestionModel.fromJson(Map<String, dynamic> json) {
    return QuestionModel(
      id: (json['id'] as num).toInt(),
      type: (json['type'] ?? '') as String,
      stem: (json['stem'] ?? '') as String,
      stemImage: json['stem_image'] as String?,
      stemCode: json['stem_code'] as String?,
      stemCodeLanguage: json['stem_code_language'] as String?,
      stemTable: json['stem_table'],
      marks: (json['marks'] as num?)?.toDouble() ?? 0.0,
      difficulty: json['difficulty'] as String?,
      position: (json['position'] as num?)?.toInt() ?? 0,
      options: (json['options'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map((o) => QuestionOptionModel.fromJson(o))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'stem': stem,
      'stem_image': stemImage,
      'stem_code': stemCode,
      'stem_code_language': stemCodeLanguage,
      'stem_table': stemTable,
      'marks': marks,
      'difficulty': difficulty,
      'position': position,
      'options': options.map((o) => o.toJson()).toList(),
    };
  }
}

class QuestionOptionModel {
  final int id;
  final String optionType; // 'text', 'code', 'latex'
  final String optionText;
  final String? codeLanguage;
  final int position;
  final bool? isCorrect; // Present only on completed attempt result endpoint

  const QuestionOptionModel({
    required this.id,
    required this.optionType,
    required this.optionText,
    this.codeLanguage,
    required this.position,
    this.isCorrect,
  });

  factory QuestionOptionModel.fromJson(Map<String, dynamic> json) {
    return QuestionOptionModel(
      id: (json['id'] as num).toInt(),
      optionType: (json['option_type'] ?? 'text') as String,
      optionText: (json['option_text'] ?? '') as String,
      codeLanguage: json['code_language'] as String?,
      position: (json['position'] as num?)?.toInt() ?? 0,
      isCorrect: json['is_correct'] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'option_type': optionType,
      'option_text': optionText,
      'code_language': codeLanguage,
      'position': position,
      if (isCorrect != null) 'is_correct': isCorrect,
    };
  }
}

/// Payload sent in POST /api/attempts/{id}/submit
class SubmitAnswerPayload {
  final int questionId;
  final List<int>? selectedOptionIds;
  final String? textAnswer;
  final num? numericalAnswer;

  const SubmitAnswerPayload({
    required this.questionId,
    this.selectedOptionIds,
    this.textAnswer,
    this.numericalAnswer,
  });

  Map<String, dynamic> toJson() {
    return {
      'question_id': questionId,
      if (selectedOptionIds != null) 'selected_option_ids': selectedOptionIds,
      if (textAnswer != null) 'text_answer': textAnswer,
      if (numericalAnswer != null) 'numerical_answer': numericalAnswer,
    };
  }
}

/// Returned by POST /api/quizzes/{id}/attempts
class StartAttemptResponse {
  final int attemptId;

  const StartAttemptResponse({required this.attemptId});

  factory StartAttemptResponse.fromJson(Map<String, dynamic> json) {
    return StartAttemptResponse(
      attemptId: (json['attempt_id'] as num).toInt(),
    );
  }
}

/// Returned by POST /api/attempts/{id}/submit
class SubmitQuizResponse {
  final int attemptId;
  final double score;
  final double totalMarks;
  final double percentage;
  final XpAwardEnvelope xpAward;

  const SubmitQuizResponse({
    required this.attemptId,
    required this.score,
    required this.totalMarks,
    required this.percentage,
    required this.xpAward,
  });

  factory SubmitQuizResponse.fromJson(Map<String, dynamic> json) {
    return SubmitQuizResponse(
      attemptId: (json['attempt_id'] as num).toInt(),
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      totalMarks: (json['total_marks'] as num?)?.toDouble() ?? 0.0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
      xpAward: XpAwardEnvelope.fromJson(json['xp_award'] as Map<String, dynamic>),
    );
  }
}

class XpAwardEnvelope {
  final int xpBefore;
  final int xpAfter;
  final int xpGained;
  final int levelBefore;
  final int levelAfter;
  final bool leveledUp;
  final List<BadgeModel> newBadges;
  final String reason;

  const XpAwardEnvelope({
    required this.xpBefore,
    required this.xpAfter,
    required this.xpGained,
    required this.levelBefore,
    required this.levelAfter,
    required this.leveledUp,
    required this.newBadges,
    required this.reason,
  });

  factory XpAwardEnvelope.fromJson(Map<String, dynamic> json) {
    return XpAwardEnvelope(
      xpBefore: (json['xp_before'] as num?)?.toInt() ?? 0,
      xpAfter: (json['xp_after'] as num?)?.toInt() ?? 0,
      xpGained: (json['xp_gained'] as num?)?.toInt() ?? 0,
      levelBefore: (json['level_before'] as num?)?.toInt() ?? 1,
      levelAfter: (json['level_after'] as num?)?.toInt() ?? 1,
      leveledUp: json['leveled_up'] == true,
      newBadges: (json['new_badges'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map((b) => BadgeModel.fromJson(b))
          .toList(),
      reason: (json['reason'] ?? '') as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'xp_before': xpBefore,
      'xp_after': xpAfter,
      'xp_gained': xpGained,
      'level_before': levelBefore,
      'level_after': levelAfter,
      'leveled_up': leveledUp,
      'new_badges': newBadges.map((b) => b.toJson()).toList(),
      'reason': reason,
    };
  }
}

/// Returned by GET /api/attempts/{id}/result
class QuizResultData {
  final AttemptSummary attempt;
  final QuizSummary quiz;
  final List<ResultAnswerModel> answers;

  const QuizResultData({
    required this.attempt,
    required this.quiz,
    required this.answers,
  });

  factory QuizResultData.fromJson(Map<String, dynamic> json) {
    return QuizResultData(
      attempt: AttemptSummary.fromJson(json['attempt'] as Map<String, dynamic>),
      quiz: QuizSummary.fromJson(json['quiz'] as Map<String, dynamic>),
      answers: (json['answers'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map((a) => ResultAnswerModel.fromJson(a))
          .toList(),
    );
  }
}

class AttemptSummary {
  final int id;
  final double score;
  final double totalMarks;
  final double percentage;
  final DateTime? submittedAt;

  const AttemptSummary({
    required this.id,
    required this.score,
    required this.totalMarks,
    required this.percentage,
    this.submittedAt,
  });

  factory AttemptSummary.fromJson(Map<String, dynamic> json) {
    return AttemptSummary(
      id: (json['id'] as num).toInt(),
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      totalMarks: (json['total_marks'] as num?)?.toDouble() ?? 0.0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
      submittedAt: json['submitted_at'] != null
          ? DateTime.tryParse(json['submitted_at'].toString())
          : null,
    );
  }
}

class QuizSummary {
  final int? id;
  final String? title;
  final String? courseName;

  const QuizSummary({this.id, this.title, this.courseName});

  factory QuizSummary.fromJson(Map<String, dynamic> json) {
    return QuizSummary(
      id: (json['id'] as num?)?.toInt(),
      title: json['title'] as String?,
      courseName: json['course_name'] as String?,
    );
  }
}

class ResultAnswerModel {
  final int questionId;
  final String questionStem;
  final String questionType;
  final String? stemImage;
  final String? stemCode;
  final String? stemCodeLanguage;
  final dynamic stemTable;
  final double marks;
  final double marksAwarded;
  final bool isCorrect;
  final List<int>? studentSelectedOptionIds;
  final String? studentTextAnswer;
  final dynamic studentNumericalAnswer;
  final List<QuestionOptionModel> options;
  final List<String> correctShortAnswers;
  final dynamic correctNumerical;
  final String? explanation;

  const ResultAnswerModel({
    required this.questionId,
    required this.questionStem,
    required this.questionType,
    this.stemImage,
    this.stemCode,
    this.stemCodeLanguage,
    this.stemTable,
    required this.marks,
    required this.marksAwarded,
    required this.isCorrect,
    this.studentSelectedOptionIds,
    this.studentTextAnswer,
    this.studentNumericalAnswer,
    required this.options,
    required this.correctShortAnswers,
    this.correctNumerical,
    this.explanation,
  });

  factory ResultAnswerModel.fromJson(Map<String, dynamic> json) {
    return ResultAnswerModel(
      questionId: (json['question_id'] as num).toInt(),
      questionStem: (json['question_stem'] ?? '') as String,
      questionType: (json['question_type'] ?? '') as String,
      stemImage: json['stem_image'] as String?,
      stemCode: json['stem_code'] as String?,
      stemCodeLanguage: json['stem_code_language'] as String?,
      stemTable: json['stem_table'],
      marks: (json['marks'] as num?)?.toDouble() ?? 0.0,
      marksAwarded: (json['marks_awarded'] as num?)?.toDouble() ?? 0.0,
      isCorrect: json['is_correct'] == true,
      studentSelectedOptionIds: (json['student_selected_option_ids'] as List?)
          ?.map((e) => (e as num).toInt())
          .toList(),
      studentTextAnswer: json['student_text_answer'] as String?,
      studentNumericalAnswer: json['student_numerical_answer'],
      options: (json['options'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map((o) => QuestionOptionModel.fromJson(o))
          .toList(),
      correctShortAnswers: (json['correct_short_answers'] as List? ?? [])
          .map((e) => e.toString())
          .toList(),
      correctNumerical: json['correct_numerical'],
      explanation: json['explanation'] as String?,
    );
  }
}

/// Returned by GET /api/quizzes/{id}/leaderboard
class QuizLeaderboard {
  final List<QuizLeaderboardEntry> top;
  final QuizLeaderboardEntry? me;

  const QuizLeaderboard({
    required this.top,
    this.me,
  });

  factory QuizLeaderboard.fromJson(Map<String, dynamic> json) {
    return QuizLeaderboard(
      top: (json['top'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map((e) => QuizLeaderboardEntry.fromJson(e))
          .toList(),
      me: json['me'] is Map<String, dynamic>
          ? QuizLeaderboardEntry.fromJson(json['me'] as Map<String, dynamic>)
          : null,
    );
  }
}

class QuizLeaderboardEntry {
  final int rank;
  final int? userId;
  final String name;
  final String displayName;
  final double score;
  final double totalMarks;
  final double percentage;
  final DateTime? submittedAt;

  const QuizLeaderboardEntry({
    required this.rank,
    this.userId,
    required this.name,
    required this.displayName,
    required this.score,
    required this.totalMarks,
    required this.percentage,
    this.submittedAt,
  });

  factory QuizLeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return QuizLeaderboardEntry(
      rank: (json['rank'] as num).toInt(),
      userId: (json['user_id'] as num?)?.toInt(),
      name: (json['name'] ?? '') as String,
      displayName: (json['display_name'] ?? '') as String,
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      totalMarks: (json['total_marks'] as num?)?.toDouble() ?? 0.0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
      submittedAt: json['submitted_at'] != null
          ? DateTime.tryParse(json['submitted_at'].toString())
          : null,
    );
  }
}

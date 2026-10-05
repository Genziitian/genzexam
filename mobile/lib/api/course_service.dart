import 'api_client.dart';
import 'models/course_model.dart';

/// Real Course service communicating with backend/app/Http/Controllers/CourseController.php.
class CourseService {
  final ApiClient _client;

  CourseService({ApiClient? client}) : _client = client ?? ApiClient();

  ApiClient get client => _client;

  /// Fetches all active courses.
  /// Endpoint: GET /api/courses
  Future<List<CourseModel>> getCourses() async {
    final response = await _client.get<List<dynamic>>('/courses');
    return (response.data ?? [])
        .whereType<Map<String, dynamic>>()
        .map((c) => CourseModel.fromJson(c))
        .toList();
  }

  /// Fetches course metadata and its weeks.
  /// Endpoint: GET /api/courses/{slug}
  Future<CourseModel> getCourse(String slug) async {
    final response = await _client.get<Map<String, dynamic>>('/courses/$slug');
    return CourseModel.fromJson(response.data!);
  }

  /// Fetches active weeks for a course.
  /// Endpoint: GET /api/courses/{slug}/weeks
  Future<List<WeekModel>> getWeeks(String slug) async {
    final response = await _client.get<List<dynamic>>('/courses/$slug/weeks');
    return (response.data ?? [])
        .whereType<Map<String, dynamic>>()
        .map((w) => WeekModel.fromJson(w))
        .toList();
  }

  /// Fetches quizzes (practice & practice_graded) for a single week with student attempt metadata.
  /// Endpoint: GET /api/courses/{slug}/weeks/{weekNumber}/quizzes
  Future<WeekQuizzesResponse> getWeekQuizzes(String slug, int weekNumber) async {
    final response = await _client.get<Map<String, dynamic>>('/courses/$slug/weeks/$weekNumber/quizzes');
    return WeekQuizzesResponse.fromJson(response.data!);
  }

  /// Collapses all weekly practice and graded quizzes across weeks in a single call.
  /// Endpoint: GET /api/courses/{slug}/practice
  Future<CoursePracticeResponse> getPractice(String slug) async {
    final response = await _client.get<Map<String, dynamic>>('/courses/$slug/practice');
    return CoursePracticeResponse.fromJson(response.data!);
  }

  /// Fetches all exam-prep quizzes grouped by section: quiz1, quiz2, endterm, mock_test.
  /// Endpoint: GET /api/courses/{slug}/exam-prep
  Future<CourseExamPrepResponse> getExamPrep(String slug) async {
    final response = await _client.get<Map<String, dynamic>>('/courses/$slug/exam-prep');
    return CourseExamPrepResponse.fromJson(response.data!);
  }
}

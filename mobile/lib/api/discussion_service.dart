import 'api_client.dart';
import 'models/discussion_model.dart';

/// Real Discussion service communicating with backend/app/Http/Controllers/DiscussionController.php.
class DiscussionService {
  final ApiClient _client;

  DiscussionService({ApiClient? client}) : _client = client ?? ApiClient();

  ApiClient get client => _client;

  /// Fetches available discussion subjects catalog.
  /// Endpoint: GET /api/discussions/subjects
  Future<Map<String, String>> getSubjects() async {
    final response = await _client.get<Map<String, dynamic>>('/discussions/subjects');
    return response.data?.map((k, v) => MapEntry(k, v.toString())) ?? {};
  }

  /// Lists community discussions with optional filtering and sorting.
  /// Endpoint: GET /api/discussions
  Future<List<DiscussionListItem>> getDiscussions({
    int? courseId,
    String? courseSlug,
    String? subject,
    String? sort, // 'newest', 'trending', 'solved', 'unsolved'
    String? search,
    bool? mine,
  }) async {
    final query = <String, dynamic>{};
    if (courseId != null) query['course_id'] = courseId;
    if (courseSlug != null) query['course_slug'] = courseSlug;
    if (subject != null) query['subject'] = subject;
    if (sort != null) query['sort'] = sort;
    if (search != null && search.trim().isNotEmpty) query['search'] = search.trim();
    if (mine != null) query['mine'] = mine ? 1 : 0;

    final response = await _client.get<List<dynamic>>(
      '/discussions',
      queryParameters: query,
    );

    return (response.data ?? [])
        .whereType<Map<String, dynamic>>()
        .map((d) => DiscussionListItem.fromJson(d))
        .toList();
  }

  /// Fetches full thread detail and its replies.
  /// Automatically registers a view count on the server if viewer is not author.
  /// Endpoint: GET /api/discussions/{id}
  Future<DiscussionDetail> getDiscussion(int id) async {
    final response = await _client.get<Map<String, dynamic>>('/discussions/$id');
    return DiscussionDetail.fromJson(response.data!);
  }

  /// Creates a new discussion thread.
  /// Endpoint: POST /api/discussions
  Future<int> createDiscussion({
    required String title,
    required String body,
    int? courseId,
    String? subject,
    int? linkedQuizId,
    bool isAnonymous = false,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/discussions',
      data: {
        'title': title.trim(),
        'body': body.trim(),
        if (courseId != null) 'course_id': courseId,
        if (subject != null) 'subject': subject,
        if (linkedQuizId != null) 'linked_quiz_id': linkedQuizId,
        if (isAnonymous) 'is_anonymous': true,
      },
    );

    return (response.data!['id'] as num).toInt();
  }

  /// Adds a reply to a discussion thread.
  /// Endpoint: POST /api/discussions/{id}/replies
  Future<int> replyToDiscussion({
    required int discussionId,
    required String body,
    bool isAnonymous = false,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/discussions/$discussionId/replies',
      data: {
        'body': body.trim(),
        if (isAnonymous) 'is_anonymous': true,
      },
    );

    return (response.data!['id'] as num).toInt();
  }

  /// Toggles upvote on a discussion thread.
  /// Endpoint: POST /api/discussions/{id}/vote
  Future<VoteResult> voteDiscussion(int discussionId) async {
    final response = await _client.post<Map<String, dynamic>>('/discussions/$discussionId/vote');
    return VoteResult.fromJson(response.data!);
  }

  /// Toggles upvote on a reply.
  /// Endpoint: POST /api/discussions/replies/{id}/vote
  Future<VoteResult> voteReply(int replyId) async {
    final response = await _client.post<Map<String, dynamic>>('/discussions/replies/$replyId/vote');
    return VoteResult.fromJson(response.data!);
  }

  /// Marks a reply as the accepted answer (discussion author only).
  /// Endpoint: POST /api/discussions/{id}/accept
  Future<AcceptReplyResult> acceptReply({
    required int discussionId,
    required int replyId,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/discussions/$discussionId/accept',
      data: {'reply_id': replyId},
    );

    return AcceptReplyResult.fromJson(response.data!);
  }

  /// Unmarks the accepted answer (discussion author only).
  /// Endpoint: POST /api/discussions/{id}/unaccept
  Future<bool> unacceptReply(int discussionId) async {
    final response = await _client.post<Map<String, dynamic>>('/discussions/$discussionId/unaccept');
    return response.data?['is_solved'] == true;
  }

  /// Deletes a discussion thread (author or admin only).
  /// Endpoint: DELETE /api/discussions/{id}
  Future<bool> deleteDiscussion(int id) async {
    final response = await _client.delete<Map<String, dynamic>>('/discussions/$id');
    return response.data?['ok'] == true;
  }

  /// Deletes a discussion reply (author or admin only).
  /// Endpoint: DELETE /api/discussions/replies/{id}
  Future<bool> deleteReply(int replyId) async {
    final response = await _client.delete<Map<String, dynamic>>('/discussions/replies/$replyId');
    return response.data?['ok'] == true;
  }
}

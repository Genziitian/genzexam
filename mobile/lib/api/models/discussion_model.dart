/// Discussion models matching backend/app/Http/Controllers/DiscussionController.php and Discussion.php
class DiscussionAuthor {
  final int? id;
  final String name;
  final String? avatar;
  final bool isAdmin;
  final bool isAnonymous;
  final bool isSelf;

  const DiscussionAuthor({
    this.id,
    required this.name,
    this.avatar,
    required this.isAdmin,
    required this.isAnonymous,
    required this.isSelf,
  });

  factory DiscussionAuthor.fromJson(Map<String, dynamic> json) {
    return DiscussionAuthor(
      id: (json['id'] as num?)?.toInt(),
      name: (json['name'] ?? 'Student') as String,
      avatar: json['avatar'] as String?,
      isAdmin: json['is_admin'] == true,
      isAnonymous: json['is_anonymous'] == true,
      isSelf: json['is_self'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'avatar': avatar,
      'is_admin': isAdmin,
      'is_anonymous': isAnonymous,
      'is_self': isSelf,
    };
  }
}

class DiscussionCourseRef {
  final int id;
  final String name;
  final String slug;

  const DiscussionCourseRef({
    required this.id,
    required this.name,
    required this.slug,
  });

  factory DiscussionCourseRef.fromJson(Map<String, dynamic> json) {
    return DiscussionCourseRef(
      id: (json['id'] as num).toInt(),
      name: (json['name'] ?? '') as String,
      slug: (json['slug'] ?? '') as String,
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

class DiscussionQuizRef {
  final int id;
  final String title;

  const DiscussionQuizRef({
    required this.id,
    required this.title,
  });

  factory DiscussionQuizRef.fromJson(Map<String, dynamic> json) {
    return DiscussionQuizRef(
      id: (json['id'] as num).toInt(),
      title: (json['title'] ?? '') as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
    };
  }
}

class DiscussionListItem {
  final int id;
  final String title;
  final String bodyPreview;
  final String? subject;
  final String? subjectLabel;
  final DiscussionCourseRef? course;
  final DiscussionQuizRef? linkedQuiz;
  final bool isAnonymous;
  final bool isSolved;
  final int voteCount;
  final int replyCount;
  final int viewCount;
  final DiscussionAuthor author;
  final bool isMine;
  final bool myVote;
  final DateTime? createdAt;

  const DiscussionListItem({
    required this.id,
    required this.title,
    required this.bodyPreview,
    this.subject,
    this.subjectLabel,
    this.course,
    this.linkedQuiz,
    required this.isAnonymous,
    required this.isSolved,
    required this.voteCount,
    required this.replyCount,
    required this.viewCount,
    required this.author,
    required this.isMine,
    required this.myVote,
    this.createdAt,
  });

  factory DiscussionListItem.fromJson(Map<String, dynamic> json) {
    return DiscussionListItem(
      id: (json['id'] as num).toInt(),
      title: (json['title'] ?? '') as String,
      bodyPreview: (json['body_preview'] ?? '') as String,
      subject: json['subject'] as String?,
      subjectLabel: json['subject_label'] as String?,
      course: json['course'] is Map<String, dynamic>
          ? DiscussionCourseRef.fromJson(json['course'] as Map<String, dynamic>)
          : null,
      linkedQuiz: json['linked_quiz'] is Map<String, dynamic>
          ? DiscussionQuizRef.fromJson(json['linked_quiz'] as Map<String, dynamic>)
          : null,
      isAnonymous: json['is_anonymous'] == true,
      isSolved: json['is_solved'] == true,
      voteCount: (json['vote_count'] as num?)?.toInt() ?? 0,
      replyCount: (json['reply_count'] as num?)?.toInt() ?? 0,
      viewCount: (json['view_count'] as num?)?.toInt() ?? 0,
      author: DiscussionAuthor.fromJson(json['author'] as Map<String, dynamic>),
      isMine: json['is_mine'] == true,
      myVote: json['my_vote'] == true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body_preview': bodyPreview,
      'subject': subject,
      'subject_label': subjectLabel,
      'course': course?.toJson(),
      'linked_quiz': linkedQuiz?.toJson(),
      'is_anonymous': isAnonymous,
      'is_solved': isSolved,
      'vote_count': voteCount,
      'reply_count': replyCount,
      'view_count': viewCount,
      'author': author.toJson(),
      'is_mine': isMine,
      'my_vote': myVote,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}

class DiscussionDetail {
  final int id;
  final String title;
  final String body;
  final String? subject;
  final String? subjectLabel;
  final DiscussionCourseRef? course;
  final DiscussionQuizRef? linkedQuiz;
  final bool isAnonymous;
  final bool isSolved;
  final int? acceptedReplyId;
  final int voteCount;
  final int replyCount;
  final int viewCount;
  final DiscussionAuthor author;
  final bool isMine;
  final bool myVote;
  final DateTime? createdAt;
  final List<DiscussionReplyModel> replies;

  const DiscussionDetail({
    required this.id,
    required this.title,
    required this.body,
    this.subject,
    this.subjectLabel,
    this.course,
    this.linkedQuiz,
    required this.isAnonymous,
    required this.isSolved,
    this.acceptedReplyId,
    required this.voteCount,
    required this.replyCount,
    required this.viewCount,
    required this.author,
    required this.isMine,
    required this.myVote,
    this.createdAt,
    required this.replies,
  });

  factory DiscussionDetail.fromJson(Map<String, dynamic> json) {
    return DiscussionDetail(
      id: (json['id'] as num).toInt(),
      title: (json['title'] ?? '') as String,
      body: (json['body'] ?? '') as String,
      subject: json['subject'] as String?,
      subjectLabel: json['subject_label'] as String?,
      course: json['course'] is Map<String, dynamic>
          ? DiscussionCourseRef.fromJson(json['course'] as Map<String, dynamic>)
          : null,
      linkedQuiz: json['linked_quiz'] is Map<String, dynamic>
          ? DiscussionQuizRef.fromJson(json['linked_quiz'] as Map<String, dynamic>)
          : null,
      isAnonymous: json['is_anonymous'] == true,
      isSolved: json['is_solved'] == true,
      acceptedReplyId: (json['accepted_reply_id'] as num?)?.toInt(),
      voteCount: (json['vote_count'] as num?)?.toInt() ?? 0,
      replyCount: (json['reply_count'] as num?)?.toInt() ?? 0,
      viewCount: (json['view_count'] as num?)?.toInt() ?? 0,
      author: DiscussionAuthor.fromJson(json['author'] as Map<String, dynamic>),
      isMine: json['is_mine'] == true,
      myVote: json['my_vote'] == true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      replies: (json['replies'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map((r) => DiscussionReplyModel.fromJson(r))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'subject': subject,
      'subject_label': subjectLabel,
      'course': course?.toJson(),
      'linked_quiz': linkedQuiz?.toJson(),
      'is_anonymous': isAnonymous,
      'is_solved': isSolved,
      'accepted_reply_id': acceptedReplyId,
      'vote_count': voteCount,
      'reply_count': replyCount,
      'view_count': viewCount,
      'author': author.toJson(),
      'is_mine': isMine,
      'my_vote': myVote,
      'created_at': createdAt?.toIso8601String(),
      'replies': replies.map((r) => r.toJson()).toList(),
    };
  }
}

class DiscussionReplyModel {
  final int id;
  final String body;
  final bool isAnonymous;
  final bool isEndorsed;
  final bool isAccepted;
  final int voteCount;
  final DiscussionAuthor author;
  final bool isMine;
  final bool myVote;
  final DateTime? createdAt;

  const DiscussionReplyModel({
    required this.id,
    required this.body,
    required this.isAnonymous,
    required this.isEndorsed,
    required this.isAccepted,
    required this.voteCount,
    required this.author,
    required this.isMine,
    required this.myVote,
    this.createdAt,
  });

  factory DiscussionReplyModel.fromJson(Map<String, dynamic> json) {
    return DiscussionReplyModel(
      id: (json['id'] as num).toInt(),
      body: (json['body'] ?? '') as String,
      isAnonymous: json['is_anonymous'] == true,
      isEndorsed: json['is_endorsed'] == true,
      isAccepted: json['is_accepted'] == true,
      voteCount: (json['vote_count'] as num?)?.toInt() ?? 0,
      author: DiscussionAuthor.fromJson(json['author'] as Map<String, dynamic>),
      isMine: json['is_mine'] == true,
      myVote: json['my_vote'] == true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'body': body,
      'is_anonymous': isAnonymous,
      'is_endorsed': isEndorsed,
      'is_accepted': isAccepted,
      'vote_count': voteCount,
      'author': author.toJson(),
      'is_mine': isMine,
      'my_vote': myVote,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}

class VoteResult {
  final bool voted;
  final int count;

  const VoteResult({
    required this.voted,
    required this.count,
  });

  factory VoteResult.fromJson(Map<String, dynamic> json) {
    return VoteResult(
      voted: json['voted'] == true,
      count: (json['count'] as num?)?.toInt() ?? 0,
    );
  }
}

class AcceptReplyResult {
  final int acceptedReplyId;
  final bool isSolved;
  final int xpAwarded;

  const AcceptReplyResult({
    required this.acceptedReplyId,
    required this.isSolved,
    required this.xpAwarded,
  });

  factory AcceptReplyResult.fromJson(Map<String, dynamic> json) {
    return AcceptReplyResult(
      acceptedReplyId: (json['accepted_reply_id'] as num).toInt(),
      isSolved: json['is_solved'] == true,
      xpAwarded: (json['xp_awarded'] as num?)?.toInt() ?? 0,
    );
  }
}

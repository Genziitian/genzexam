/// Admin models matching backend/app/Http/Controllers/Admin/AdminUserController.php
/// and backend/app/Http/Controllers/Admin/AdminDashboardController.php.

class AdminUserListItem {
  final int id;
  final String name;
  final String email;
  final String? avatar;
  final String role;
  final bool isAdmin;
  final bool isPro;
  final bool isActive;
  final int xp;
  final bool verified;
  final DateTime? lastSeenAt;
  final DateTime? createdAt;
  final AdminUserPermissions can;

  const AdminUserListItem({
    required this.id,
    required this.name,
    required this.email,
    this.avatar,
    required this.role,
    required this.isAdmin,
    required this.isPro,
    required this.isActive,
    required this.xp,
    required this.verified,
    this.lastSeenAt,
    this.createdAt,
    required this.can,
  });

  factory AdminUserListItem.fromJson(Map<String, dynamic> json) {
    return AdminUserListItem(
      id: (json['id'] as num).toInt(),
      name: (json['name'] ?? '') as String,
      email: (json['email'] ?? '') as String,
      avatar: json['avatar'] as String?,
      role: (json['role'] ?? 'student') as String,
      isAdmin: json['is_admin'] == true,
      isPro: json['is_pro'] == true,
      isActive: json['is_active'] == true,
      xp: (json['xp'] as num?)?.toInt() ?? 0,
      verified: json['verified'] == true,
      lastSeenAt: json['last_seen_at'] != null
          ? DateTime.tryParse(json['last_seen_at'].toString())
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      can: AdminUserPermissions.fromJson(
        (json['can'] as Map<String, dynamic>?) ?? {},
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'avatar': avatar,
      'role': role,
      'is_admin': isAdmin,
      'is_pro': isPro,
      'is_active': isActive,
      'xp': xp,
      'verified': verified,
      'last_seen_at': lastSeenAt?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
      'can': can.toJson(),
    };
  }
}

class AdminUserPermissions {
  final bool toggleActive;
  final bool togglePro;
  final bool setRole;
  final bool delete;

  const AdminUserPermissions({
    required this.toggleActive,
    required this.togglePro,
    required this.setRole,
    required this.delete,
  });

  factory AdminUserPermissions.fromJson(Map<String, dynamic> json) {
    return AdminUserPermissions(
      toggleActive: json['toggle_active'] == true,
      togglePro: json['toggle_pro'] == true,
      setRole: json['set_role'] == true,
      delete: json['delete'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'toggle_active': toggleActive,
      'toggle_pro': togglePro,
      'set_role': setRole,
      'delete': delete,
    };
  }
}

class AdminUserListResponse {
  final List<AdminUserListItem> data;
  final PaginationMeta meta;
  final UserCounts counts;
  final ViewerPermissions viewer;

  const AdminUserListResponse({
    required this.data,
    required this.meta,
    required this.counts,
    required this.viewer,
  });

  factory AdminUserListResponse.fromJson(Map<String, dynamic> json) {
    return AdminUserListResponse(
      data: (json['data'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map((u) => AdminUserListItem.fromJson(u))
          .toList(),
      meta: PaginationMeta.fromJson((json['meta'] as Map<String, dynamic>?) ?? {}),
      counts: UserCounts.fromJson((json['counts'] as Map<String, dynamic>?) ?? {}),
      viewer: ViewerPermissions.fromJson((json['viewer'] as Map<String, dynamic>?) ?? {}),
    );
  }
}

class PaginationMeta {
  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;

  const PaginationMeta({
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
  });

  factory PaginationMeta.fromJson(Map<String, dynamic> json) {
    return PaginationMeta(
      currentPage: (json['current_page'] as num?)?.toInt() ?? 1,
      lastPage: (json['last_page'] as num?)?.toInt() ?? 1,
      perPage: (json['per_page'] as num?)?.toInt() ?? 25,
      total: (json['total'] as num?)?.toInt() ?? 0,
    );
  }
}

class UserCounts {
  final int total;
  final int managers;
  final int admins;
  final int students;
  final int pro;
  final int inactive;

  const UserCounts({
    required this.total,
    required this.managers,
    required this.admins,
    required this.students,
    required this.pro,
    required this.inactive,
  });

  factory UserCounts.fromJson(Map<String, dynamic> json) {
    return UserCounts(
      total: (json['total'] as num?)?.toInt() ?? 0,
      managers: (json['managers'] as num?)?.toInt() ?? 0,
      admins: (json['admins'] as num?)?.toInt() ?? 0,
      students: (json['students'] as num?)?.toInt() ?? 0,
      pro: (json['pro'] as num?)?.toInt() ?? 0,
      inactive: (json['inactive'] as num?)?.toInt() ?? 0,
    );
  }
}

class ViewerPermissions {
  final int id;
  final String role;
  final bool isManager;
  final bool canManageRoles;
  final bool canDeleteUsers;

  const ViewerPermissions({
    required this.id,
    required this.role,
    required this.isManager,
    required this.canManageRoles,
    required this.canDeleteUsers,
  });

  factory ViewerPermissions.fromJson(Map<String, dynamic> json) {
    return ViewerPermissions(
      id: (json['id'] as num?)?.toInt() ?? 0,
      role: (json['role'] ?? 'student') as String,
      isManager: json['is_manager'] == true,
      canManageRoles: json['can_manage_roles'] == true,
      canDeleteUsers: json['can_delete_users'] == true,
    );
  }
}

class AdminStatsResponse {
  final int totalStudents;
  final int totalQuizzes;
  final int totalQuestions;
  final int totalCourses;
  final int totalAttemptsToday;
  final List<Map<String, dynamic>> recentAttempts;
  final List<Map<String, dynamic>> recentLogins;

  const AdminStatsResponse({
    required this.totalStudents,
    required this.totalQuizzes,
    required this.totalQuestions,
    required this.totalCourses,
    required this.totalAttemptsToday,
    required this.recentAttempts,
    required this.recentLogins,
  });

  factory AdminStatsResponse.fromJson(Map<String, dynamic> json) {
    return AdminStatsResponse(
      totalStudents: (json['total_students'] as num?)?.toInt() ?? 0,
      totalQuizzes: (json['total_quizzes'] as num?)?.toInt() ?? 0,
      totalQuestions: (json['total_questions'] as num?)?.toInt() ?? 0,
      totalCourses: (json['total_courses'] as num?)?.toInt() ?? 0,
      totalAttemptsToday: (json['total_attempts_today'] as num?)?.toInt() ?? 0,
      recentAttempts: (json['recent_attempts'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .toList(),
      recentLogins: (json['recent_logins'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .toList(),
    );
  }
}

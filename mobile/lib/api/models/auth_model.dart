/// User model matching backend/app/Models/User.php and AuthController JSON responses.
class UserModel {
  final int id;
  final String name;
  final String email;
  final bool isAdmin;
  final String? role;
  final String? avatar;
  final DateTime? emailVerifiedAt;
  final int xp;
  final int? level;
  final LevelProgressModel? levelProgress;
  final List<BadgeModel>? badges;
  final bool? isPro;
  final bool? isActive;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.isAdmin,
    this.role,
    this.avatar,
    this.emailVerifiedAt,
    this.xp = 0,
    this.level,
    this.levelProgress,
    this.badges,
    this.isPro,
    this.isActive,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int,
      name: (json['name'] ?? '') as String,
      email: (json['email'] ?? '') as String,
      isAdmin: json['is_admin'] == true,
      role: json['role'] as String?,
      avatar: json['avatar'] as String?,
      emailVerifiedAt: json['email_verified_at'] != null
          ? DateTime.tryParse(json['email_verified_at'].toString())
          : null,
      xp: (json['xp'] as num?)?.toInt() ?? 0,
      level: (json['level'] as num?)?.toInt(),
      levelProgress: json['level_progress'] is Map<String, dynamic>
          ? LevelProgressModel.fromJson(json['level_progress'] as Map<String, dynamic>)
          : null,
      badges: (json['badges'] as List?)
          ?.whereType<Map<String, dynamic>>()
          .map((b) => BadgeModel.fromJson(b))
          .toList(),
      isPro: json['is_pro'] as bool?,
      isActive: json['is_active'] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'is_admin': isAdmin,
      'role': role,
      'avatar': avatar,
      'email_verified_at': emailVerifiedAt?.toIso8601String(),
      'xp': xp,
      'level': level,
      'level_progress': levelProgress?.toJson(),
      'badges': badges?.map((b) => b.toJson()).toList(),
      'is_pro': isPro,
      'is_active': isActive,
    };
  }
}

/// Progress model matching XpService::progress() return structure.
class LevelProgressModel {
  final int xp;
  final int level;
  final bool isMax;
  final int xpIntoLevel;
  final int xpForLevel;
  final int xpToNext;
  final int progressPercent;
  final int nextLevelXpTotal;
  final int thisLevelXpTotal;

  const LevelProgressModel({
    required this.xp,
    required this.level,
    required this.isMax,
    required this.xpIntoLevel,
    required this.xpForLevel,
    required this.xpToNext,
    required this.progressPercent,
    required this.nextLevelXpTotal,
    required this.thisLevelXpTotal,
  });

  factory LevelProgressModel.fromJson(Map<String, dynamic> json) {
    return LevelProgressModel(
      xp: (json['xp'] as num?)?.toInt() ?? 0,
      level: (json['level'] as num?)?.toInt() ?? 1,
      isMax: json['is_max'] == true,
      xpIntoLevel: (json['xp_into_level'] as num?)?.toInt() ?? 0,
      xpForLevel: (json['xp_for_level'] as num?)?.toInt() ?? 1,
      xpToNext: (json['xp_to_next'] as num?)?.toInt() ?? 0,
      progressPercent: (json['progress_percent'] as num?)?.toInt() ?? 0,
      nextLevelXpTotal: (json['next_level_xp_total'] as num?)?.toInt() ?? 0,
      thisLevelXpTotal: (json['this_level_xp_total'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'xp': xp,
      'level': level,
      'is_max': isMax,
      'xp_into_level': xpIntoLevel,
      'xp_for_level': xpForLevel,
      'xp_to_next': xpToNext,
      'progress_percent': progressPercent,
      'next_level_xp_total': nextLevelXpTotal,
      'this_level_xp_total': thisLevelXpTotal,
    };
  }
}

/// Badge model matching XpService::BADGES structure.
class BadgeModel {
  final String slug;
  final String label;
  final String description;
  final int level;

  const BadgeModel({
    required this.slug,
    required this.label,
    required this.description,
    required this.level,
  });

  factory BadgeModel.fromJson(Map<String, dynamic> json) {
    return BadgeModel(
      slug: (json['slug'] ?? '') as String,
      label: (json['label'] ?? '') as String,
      description: (json['description'] ?? '') as String,
      level: (json['level'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'slug': slug,
      'label': label,
      'description': description,
      'level': level,
    };
  }
}

/// Response returned by POST /api/auth/login and POST /api/auth/verify-otp.
class AuthSuccessResponse {
  final String token;
  final UserModel user;

  const AuthSuccessResponse({
    required this.token,
    required this.user,
  });

  factory AuthSuccessResponse.fromJson(Map<String, dynamic> json) {
    return AuthSuccessResponse(
      token: (json['token'] ?? '') as String,
      user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}

/// Response returned by POST /api/auth/register.
class RegisterResponse {
  final String message;
  final String email;

  const RegisterResponse({
    required this.message,
    required this.email,
  });

  factory RegisterResponse.fromJson(Map<String, dynamic> json) {
    return RegisterResponse(
      message: (json['message'] ?? '') as String,
      email: (json['email'] ?? '') as String,
    );
  }
}

/// Models matching backend/app/Http/Controllers/ExamPlatformController.php
class ExamPlatformHealth {
  final String status;
  final String service;
  final double timestamp;

  const ExamPlatformHealth({
    required this.status,
    required this.service,
    required this.timestamp,
  });

  factory ExamPlatformHealth.fromJson(Map<String, dynamic> json) {
    return ExamPlatformHealth(
      status: (json['status'] ?? '') as String,
      service: (json['service'] ?? '') as String,
      timestamp: (json['timestamp'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class ExamChatMessage {
  final String id;
  final String senderName;
  final String? senderEmail;
  final String role; // 'manager', 'student', 'proctor'
  final String text;
  final int timestamp;
  final bool isAnnouncement;

  const ExamChatMessage({
    required this.id,
    required this.senderName,
    this.senderEmail,
    required this.role,
    required this.text,
    required this.timestamp,
    required this.isAnnouncement,
  });

  factory ExamChatMessage.fromJson(Map<String, dynamic> json) {
    return ExamChatMessage(
      id: (json['id'] ?? '') as String,
      senderName: (json['senderName'] ?? '') as String,
      senderEmail: json['senderEmail'] as String?,
      role: (json['role'] ?? 'student') as String,
      text: (json['text'] ?? '') as String,
      timestamp: (json['timestamp'] as num?)?.toInt() ?? 0,
      isAnnouncement: json['isAnnouncement'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'senderName': senderName,
      if (senderEmail != null) 'senderEmail': senderEmail,
      'role': role,
      'text': text,
      'timestamp': timestamp,
      'isAnnouncement': isAnnouncement,
    };
  }
}

class ReentryRequest {
  final String id;
  final String email;
  final String name;
  final String reason;
  final String status; // 'pending', 'approved', 'rejected'
  final int timestamp;

  const ReentryRequest({
    required this.id,
    required this.email,
    required this.name,
    required this.reason,
    required this.status,
    required this.timestamp,
  });

  factory ReentryRequest.fromJson(Map<String, dynamic> json) {
    return ReentryRequest(
      id: (json['id'] ?? '') as String,
      email: (json['email'] ?? '') as String,
      name: (json['name'] ?? '') as String,
      reason: (json['reason'] ?? '') as String,
      status: (json['status'] ?? 'pending') as String,
      timestamp: (json['timestamp'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'reason': reason,
      'status': status,
      'timestamp': timestamp,
    };
  }
}

class UserModel {
  final String id;
  final String email;
  final String name;
  final String profilePic;
  final String? username;
  final String? about;
  final bool hasCompletedOnboarding;
  final bool? isOnline;
  final DateTime? lastSeen;

  UserModel({
    required this.id,
    required this.email,
    required this.name,
    required this.profilePic,
    this.username,
    this.about,
    this.hasCompletedOnboarding = false,
    this.isOnline,
    this.lastSeen,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    // Issue #115: Strict validation
    if (json['_id'] == null || json['email'] == null || json['name'] == null) {
      throw FormatException('UserModel.fromJson: Missing required fields');
    }

    return UserModel(
      id: json['_id'].toString(),
      email: json['email'].toString(),
      name: json['name'].toString(),
      profilePic: json['profilePic']?.toString() ?? '',
      username: json['username']?.toString(),
      about: json['about']?.toString(),
      hasCompletedOnboarding: json['hasCompletedOnboarding'] == true,
      isOnline: json['isOnline'] == true,
      lastSeen: json['lastSeen'] != null ? DateTime.tryParse(json['lastSeen'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'email': email,
      'name': name,
      'profilePic': profilePic,
      'username': username,
      'about': about,
      'hasCompletedOnboarding': hasCompletedOnboarding,
      'isOnline': isOnline,
      'lastSeen': lastSeen?.toIso8601String(),
    };
  }
}

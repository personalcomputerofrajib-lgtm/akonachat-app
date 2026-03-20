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
    return UserModel(
      id: json['_id'] ?? '',
      email: json['email'] ?? '',
      name: json['name'] ?? '',
      profilePic: json['profilePic'] ?? '',
      username: json['username'],
      about: json['about'],
      hasCompletedOnboarding: json['hasCompletedOnboarding'] ?? false,
      isOnline: json['isOnline'],
      lastSeen: json['lastSeen'] != null ? DateTime.parse(json['lastSeen']) : null,
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

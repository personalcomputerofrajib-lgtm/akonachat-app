class UserModel {
  final String id;
  final String email;
  final String name;
  final String profilePic;
  final String? username;
  final String? about;
  final bool hasCompletedOnboarding;

  UserModel({
    required this.id,
    required this.email,
    required this.name,
    required this.profilePic,
    this.username,
    this.about,
    this.hasCompletedOnboarding = false,
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
    };
  }
}

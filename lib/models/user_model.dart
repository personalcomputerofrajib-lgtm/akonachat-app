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
  final int coins;
  final int streak;
  final List<dynamic>? gifts;
  final String? profileBanner;

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
    this.coins = 0,
    this.streak = 0,
    this.gifts,
    this.profileBanner,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    // Relaxed validation: Use defaults instead of throwing Exception
    final String safeId = (json['_id'] ?? json['id'] ?? '').toString();
    final String safeEmail = (json['email'] ?? '').toString();
    final String safeName = (json['name'] ?? 'User').toString();

    return UserModel(
      id: safeId,
      email: safeEmail,
      name: safeName,
      profilePic: json['profilePic']?.toString() ?? '',
      username: json['username']?.toString(),
      about: json['about']?.toString(),
      hasCompletedOnboarding: json['hasCompletedOnboarding'] == true,
      isOnline: json['isOnline'] == true,
      lastSeen: json['lastSeen'] != null ? DateTime.tryParse(json['lastSeen'].toString()) : null,
      coins: json['coins'] ?? 0,
      streak: json['streak'] ?? 0,
      gifts: json['gifts'] ?? [],
      profileBanner: json['profileBanner']?.toString(),
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
      'coins': coins,
      'streak': streak,
      'gifts': gifts,
      'profileBanner': profileBanner,
    };
  }
}

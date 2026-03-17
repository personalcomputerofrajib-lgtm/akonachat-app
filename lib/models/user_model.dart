class UserModel {
  final String id;
  final String email;
  final String name;
  final String profilePic;

  UserModel({
    required this.id,
    required this.email,
    required this.name,
    required this.profilePic,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['_id'] ?? '',
      email: json['email'] ?? '',
      name: json['name'] ?? '',
      profilePic: json['profilePic'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'email': email,
      'name': name,
      'profilePic': profilePic,
    };
  }
}

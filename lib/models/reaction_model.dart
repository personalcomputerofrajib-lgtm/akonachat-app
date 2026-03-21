class ReactionModel {
  final String userId;
  final String emoji;
  final DateTime updatedAt;

  ReactionModel({
    required this.userId,
    required this.emoji,
    required this.updatedAt,
  });

  factory ReactionModel.fromJson(Map<String, dynamic> json) {
    if (json['userId'] == null || json['emoji'] == null) {
      throw FormatException('ReactionModel.fromJson: Missing required fields');
    }

    return ReactionModel(
      userId: json['userId'].toString(),
      emoji: json['emoji'].toString(),
      updatedAt: json['updatedAt'] != null 
          ? DateTime.tryParse(json['updatedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'emoji': emoji,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

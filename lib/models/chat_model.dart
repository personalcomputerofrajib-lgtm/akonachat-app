class ChatModel {
  final String id;
  final List<String> participantIds;
  final Map<String, dynamic>? lastMessage;
  final int lastSequence;
  final DateTime updatedAt;

  ChatModel({
    required this.id,
    required this.participantIds,
    this.lastMessage,
    this.lastSequence = 0,
    required this.updatedAt,
  });

  factory ChatModel.fromJson(Map<String, dynamic> json) {
    if (json['_id'] == null) {
      throw FormatException('ChatModel.fromJson: Missing _id');
    }
    
    return ChatModel(
      id: json['_id'].toString(),
      participantIds: (json['participants'] as List?)
              ?.map((p) => (p is Map ? p['_id'] : p).toString())
              .toList() ?? [],
      lastMessage: json['lastMessage'],
      lastSequence: json['lastSequence'] ?? 0,
      updatedAt: json['updatedAt'] != null 
          ? DateTime.tryParse(json['updatedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'participants': participantIds,
      'lastMessage': lastMessage,
      'lastSequence': lastSequence,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

class MessageModel {
  final String id;
  final String chatId;
  final String senderId;
  final String ciphertext;
  final String type; // text, image, audio, voice
  final String? mediaUrl;
  final int sequence;
  final String status; // pending, sent, delivered, read
  final DateTime timestamp;
  final List<dynamic>? reactions;

  MessageModel({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.ciphertext,
    required this.type,
    this.mediaUrl,
    required this.sequence,
    this.status = 'sent',
    required this.timestamp,
    this.reactions,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    final id = json['_id'] ?? json['clientMsgId'];
    if (id == null || json['chatId'] == null || json['senderId'] == null) {
      throw FormatException('MessageModel.fromJson: Missing required fields');
    }

    return MessageModel(
      id: id.toString(),
      chatId: json['chatId'].toString(),
      senderId: (json['senderId'] is Map ? json['senderId']['_id'] : json['senderId']).toString(),
      ciphertext: json['ciphertext']?.toString() ?? '',
      type: json['type']?.toString() ?? 'text',
      mediaUrl: json['mediaUrl']?.toString(),
      sequence: json['sequence'] ?? 0,
      status: json['status']?.toString() ?? 'sent',
      timestamp: json['timestamp'] != null 
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      reactions: json['reactions'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'chatId': chatId,
      'senderId': senderId,
      'ciphertext': ciphertext,
      'type': type,
      'mediaUrl': mediaUrl,
      'sequence': sequence,
      'status': status,
      'timestamp': timestamp.toIso8601String(),
      'reactions': reactions,
    };
  }
}

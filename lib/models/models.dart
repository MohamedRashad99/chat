class Message {
  final String id;
  final String roomId;
  final String userId;
  final String content;
  final String? imageUrl;   // ← NEW: real uploaded image
  final DateTime createdAt;
  final String? username;
  final String? avatarUrl;
  final String? replyToId;
  final String? replyToContent;
  final String? replyToUsername;
  final bool isDeleted;
  final List<String> mentions;
  final bool mentionsAll;

  Message({
    required this.id,
    required this.roomId,
    required this.userId,
    required this.content,
    this.imageUrl,
    required this.createdAt,
    this.username,
    this.avatarUrl,
    this.replyToId,
    this.replyToContent,
    this.replyToUsername,
    this.isDeleted = false,
    this.mentions = const [],
    this.mentionsAll = false,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    final mentionsList = (json['mentions'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    return Message(
      id: json['id'] as String,
      roomId: json['room_id'] as String,
      userId: json['user_id'] as String,
      content: json['content'] as String? ?? '',
      imageUrl: json['image_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      username: json['profiles']?['username'] as String?,
      avatarUrl: json['profiles']?['avatar_url'] as String?,
      replyToId: json['reply_to_id'] as String?,
      replyToContent: json['reply_to_content'] as String?,
      replyToUsername: json['reply_to_username'] as String?,
      isDeleted: json['is_deleted'] as bool? ?? false,
      mentions: mentionsList,
      mentionsAll: json['mentions_all'] as bool? ?? false,
    );
  }

  bool isMentioned(String userId, String username) {
    return mentionsAll ||
        mentions.contains(userId) ||
        content.toLowerCase().contains('@${username.toLowerCase()}');
  }
}

class Room {
  final String id;
  final String name;
  final String? description;
  final DateTime createdAt;
  final bool isGroup;
  final String? createdBy;
  final int unreadCount;
  final String? lastMessage;
  final DateTime? lastMessageAt;

  Room({
    required this.id,
    required this.name,
    this.description,
    required this.createdAt,
    this.isGroup = true,
    this.createdBy,
    this.unreadCount = 0,
    this.lastMessage,
    this.lastMessageAt,
  });

  factory Room.fromJson(Map<String, dynamic> json) {
    return Room(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      isGroup: json['is_group'] as bool? ?? true,
      createdBy: json['created_by'] as String?,
    );
  }
}

class Profile {
  final String id;
  final String username;
  final String? avatarUrl;
  final bool isOnline;

  Profile({
    required this.id,
    required this.username,
    this.avatarUrl,
    this.isOnline = false,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      username: json['username'] as String? ?? 'Anonymous',
      avatarUrl: json['avatar_url'] as String?,
      isOnline: json['is_online'] as bool? ?? false,
    );
  }
}

class RoomMember {
  final String userId;
  final String roomId;
  final String username;
  final String? avatarUrl;
  final bool isAdmin;

  RoomMember({
    required this.userId,
    required this.roomId,
    required this.username,
    this.avatarUrl,
    this.isAdmin = false,
  });

  factory RoomMember.fromJson(Map<String, dynamic> json) {
    return RoomMember(
      userId: json['user_id'] as String,
      roomId: json['room_id'] as String,
      username: json['profiles']?['username'] as String? ?? '',
      avatarUrl: json['profiles']?['avatar_url'] as String?,
      isAdmin: json['is_admin'] as bool? ?? false,
    );
  }
}

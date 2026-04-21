class Message {
  final String id;
  final String roomId;
  final String userId;
  final String content;
  final DateTime createdAt;
  final String? username;
  final String? avatarUrl;

  Message({
    required this.id,
    required this.roomId,
    required this.userId,
    required this.content,
    required this.createdAt,
    this.username,
    this.avatarUrl,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as String,
      roomId: json['room_id'] as String,
      userId: json['user_id'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      username: json['profiles']?['username'] as String?,
      avatarUrl: json['profiles']?['avatar_url'] as String?,
    );
  }
}

class Room {
  final String id;
  final String name;
  final String? description;
  final DateTime createdAt;

  Room({
    required this.id,
    required this.name,
    this.description,
    required this.createdAt,
  });

  factory Room.fromJson(Map<String, dynamic> json) {
    return Room(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class Profile {
  final String id;
  final String username;
  final String? avatarUrl;

  Profile({
    required this.id,
    required this.username,
    this.avatarUrl,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      username: json['username'] as String? ?? 'Anonymous',
      avatarUrl: json['avatar_url'] as String?,
    );
  }
}

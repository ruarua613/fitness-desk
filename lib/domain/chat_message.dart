/// 聊天消息。role 只有 user / assistant 两种。
class ChatMsg {
  final String role;
  final String content;
  final DateTime at;
  final bool error;

  ChatMsg({
    required this.role,
    required this.content,
    DateTime? at,
    this.error = false,
  }) : at = at ?? DateTime.now();

  ChatMsg copyWith({String? content, bool? error}) => ChatMsg(
        role: role,
        content: content ?? this.content,
        at: at,
        error: error ?? this.error,
      );

  bool get isUser => role == 'user';

  Map<String, dynamic> toJson() => {
        'role': role,
        'content': content,
      };
}

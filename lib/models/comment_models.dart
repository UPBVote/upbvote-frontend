class CommentType {
  final String id;
  final String name;

  CommentType({required this.id, required this.name});

  factory CommentType.fromJson(Map<String, dynamic> j) => CommentType(
        id: (j['id'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
      );
}

class Comment {
  final String id;
  final String text;
  final String dateTime;
  final CommentType commentType;
  final String? userId;
  final String? userName;

  Comment({
    required this.id,
    required this.text,
    required this.dateTime,
    required this.commentType,
    this.userId,
    this.userName,
  });

  bool get isAnonymous => commentType.name == 'ANONYMOUS';

  factory Comment.fromJson(Map<String, dynamic> j) => Comment(
        id: (j['id'] ?? '').toString(),
        text: (j['comment'] ?? '').toString(),
        dateTime: (j['dateTime'] ?? '').toString(),
        commentType: j['commentType'] is Map
            ? CommentType.fromJson(j['commentType'] as Map<String, dynamic>)
            : CommentType(id: '', name: ''),
        userId: j['userId']?.toString(),
        userName: j['userName']?.toString() ??
            j['user_name']?.toString() ??
            j['author']?.toString(),
      );
}

import 'package:cloud_firestore/cloud_firestore.dart';

class Comment {
  final String id;
  final String text;
  final String userName;
  final DateTime timestamp;
  final int pageNumber;
  final String groupId;
  final int upvotes;
  final List<String> upvotedBy;

  Comment({
    required this.id,
    required this.text,
    required this.userName,
    required this.timestamp,
    required this.pageNumber,
    required this.groupId,
    this.upvotes = 0,
    this.upvotedBy = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'userName': userName,
      'timestamp': timestamp,
      'pageNumber': pageNumber,
      'groupId': groupId,
      'upvotes': upvotes,
      'upvotedBy': upvotedBy,
    };
  }

  factory Comment.fromMap(Map<String, dynamic> map) {
    return Comment(
      id: map['id'],
      text: map['text'],
      userName: map['userName'],
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      pageNumber: map['pageNumber'],
      groupId: map['groupId'],
      upvotes: map['upvotes'] ?? 0,
      upvotedBy: List<String>.from(map['upvotedBy'] ?? []),
    );
  }
}

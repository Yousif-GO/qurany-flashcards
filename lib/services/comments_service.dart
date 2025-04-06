import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/comment.dart';

class CommentsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Add a new comment
  Future<void> addComment({
    required String text,
    required String userName,
    required int pageNumber,
    required String groupId,
  }) async {
    final commentDoc = _firestore
        .collection('quranRooms')
        .doc(groupId)
        .collection('comments')
        .doc();

    final comment = Comment(
      id: commentDoc.id,
      text: text,
      userName: userName,
      timestamp: DateTime.now(),
      pageNumber: pageNumber,
      groupId: groupId,
      upvotes: 0,
      upvotedBy: [],
    );

    await commentDoc.set(comment.toMap());
  }

  // Get comments stream for a specific page and group
  Stream<List<Comment>> getCommentsStream({
    required int pageNumber,
    required String groupId,
  }) {
    return _firestore
        .collection('quranRooms')
        .doc(groupId)
        .collection('comments')
        .where('pageNumber', isEqualTo: pageNumber)
        .orderBy('upvotes', descending: true)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Comment.fromMap(doc.data())).toList());
  }

  // Toggle upvote
  Future<void> toggleUpvote(
      String groupId, String commentId, String userName) async {
    final docRef = _firestore
        .collection('quranRooms')
        .doc(groupId)
        .collection('comments')
        .doc(commentId);

    return _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;

      List<String> upvotedBy =
          List<String>.from(snapshot.data()?['upvotedBy'] ?? []);

      if (upvotedBy.contains(userName)) {
        upvotedBy.remove(userName);
      } else {
        upvotedBy.add(userName);
      }

      transaction.update(docRef, {
        'upvotes': upvotedBy.length,
        'upvotedBy': upvotedBy,
      });
    });
  }

  // Delete comment
  Future<void> deleteComment(String groupId, String commentId) async {
    await _firestore
        .collection('quranRooms')
        .doc(groupId)
        .collection('comments')
        .doc(commentId)
        .delete();
  }
}

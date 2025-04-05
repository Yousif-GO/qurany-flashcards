import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../models/comment.dart';

class CommentsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Add a new comment
  Future<void> addComment({
    required String text,
    required String userName,
    required int pageNumber,
    required String groupId,
    File? audioFile,
  }) async {
    final commentDoc = _firestore
        .collection('quranRooms')
        .doc(groupId)
        .collection('comments')
        .doc();

    String? audioUrl;

    // Upload audio file if provided
    if (audioFile != null) {
      final audioRef = _storage
          .ref()
          .child('comments_audio')
          .child(groupId)
          .child('${commentDoc.id}.m4a');

      await audioRef.putFile(audioFile);
      audioUrl = await audioRef.getDownloadURL();
    }

    final comment = Comment(
      id: commentDoc.id,
      text: text,
      userName: userName,
      timestamp: DateTime.now(),
      pageNumber: pageNumber,
      groupId: groupId,
      upvotes: 0,
      upvotedBy: [],
      audioUrl: audioUrl,
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
    // Get the comment to check if it has audio
    final commentDoc = await _firestore
        .collection('quranRooms')
        .doc(groupId)
        .collection('comments')
        .doc(commentId)
        .get();

    if (commentDoc.exists) {
      final data = commentDoc.data();
      final audioUrl = data?['audioUrl'];

      // Delete audio file if it exists
      if (audioUrl != null) {
        try {
          final ref = _storage.refFromURL(audioUrl);
          await ref.delete();
        } catch (e) {
          print('Error deleting audio file: $e');
        }
      }
    }

    // Delete the comment document
    await _firestore
        .collection('quranRooms')
        .doc(groupId)
        .collection('comments')
        .doc(commentId)
        .delete();
  }
}

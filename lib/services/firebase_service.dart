import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Check if group and khatma name already exist
  Future<bool> checkRoomExists(String groupName, String khatmaName) async {
    final doc = await _firestore
        .collection('quranRooms')
        .doc(groupName)
        .collection('khatmas')
        .doc(khatmaName)
        .get();

    return doc.exists;
  }

  // Create new room
  Future<void> createRoom({
    required String groupName,
    required String khatmaName,
    required String userName,
  }) async {
    // Create a map of all 604 pages with their initial state
    Map<String, dynamic> pages = {};
    for (int i = 1; i <= 604; i++) {
      pages['page_$i'] = {
        'completed': false,
        'readBy': null,
        'completedAt': null
      };
    }

    await _firestore
        .collection('quranRooms')
        .doc(groupName)
        .collection('khatmas')
        .doc(khatmaName)
        .set({
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': userName,
      'members': [userName],
      'pages': pages,
    });
  }

  // Join existing room
  Future<void> joinRoom({
    required String groupName,
    required String khatmaName,
    required String userName,
    required List<int> selectedPages,
  }) async {
    final roomRef = _firestore
        .collection('quranRooms')
        .doc(groupName)
        .collection('khatmas')
        .doc(khatmaName);

    await _firestore.runTransaction((transaction) async {
      final roomDoc = await transaction.get(roomRef);

      if (!roomDoc.exists) {
        throw Exception('Room does not exist');
      }

      List<String> members =
          List<String>.from(roomDoc.data()?['members'] ?? []);
      if (!members.contains(userName)) {
        members.add(userName);
      }

      transaction.update(roomRef, {
        'members': members,
      });
    });
  }

  // Mark page as completed
  Future<void> markPageAsCompleted({
    required String groupName,
    required String khatmaName,
    required String userName,
    required int pageNumber,
  }) async {
    await _firestore
        .collection('quranRooms')
        .doc(groupName)
        .collection('khatmas')
        .doc(khatmaName)
        .update({
      'pages.$pageNumber': {
        'completed': true,
        'completedBy': userName,
        'completedAt': FieldValue.serverTimestamp(),
      }
    });
  }

  // Get room data stream
  Stream<DocumentSnapshot> getRoomStream(String groupName, String khatmaName) {
    return _firestore
        .collection('quranRooms')
        .doc(groupName)
        .collection('khatmas')
        .doc(khatmaName)
        .snapshots();
  }

  Future<Map<String, dynamic>> getRoomDetails({
    required String groupName,
    required String khatmaName,
  }) async {
    final doc = await _firestore
        .collection('quranRooms')
        .doc(groupName)
        .collection('khatmas')
        .doc(khatmaName)
        .get();

    return doc.data() ?? {};
  }

  Future<bool> checkGroupExists(String groupId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('quranRooms')
        .where('groupName', isEqualTo: groupId)
        .get();
    return snapshot.docs.isNotEmpty;
  }
}

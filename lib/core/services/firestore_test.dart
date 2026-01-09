import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreTest {
  static Future<void> writeHello() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';

    await FirebaseFirestore.instance
        .collection('debug')
        .doc(uid)
        .set({
      'hello': 'world',
      'uid': uid,
      'ts': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

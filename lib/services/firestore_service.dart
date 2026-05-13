import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final _db = FirebaseFirestore.instance;

  // Onay bekleyenler
  Stream<List<Map<String, dynamic>>> pendingListings() {
    return _db
        .collection('listings')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => {'docId': d.id, ...d.data()}).toList());
  }

  // Aktif (onaylı) ilanlar
  Stream<List<Map<String, dynamic>>> activeListings() {
    return _db
        .collection('listings')
        .where('status', isEqualTo: 'active')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => {'docId': d.id, ...d.data()}).toList());
  }

  Future<void> approveListing(String docId) async {
    final snap = await _db.collection('listings').doc(docId).get();
    final data = snap.data();
    await _db.collection('listings').doc(docId).update({'status': 'active'});
    final sellerId = data?['sellerId'] as String?;
    final title    = data?['title']    as String? ?? 'İlanınız';
    if (sellerId != null && sellerId.isNotEmpty) {
      await _db
          .collection('users')
          .doc(sellerId)
          .collection('notifications')
          .add({
        'title': 'İlanınız onaylandı ✓',
        'body': '"$title" ilanınız incelendi ve yayına alındı.',
        'type': 'approved',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> rejectListing(String docId) async {
    final snap = await _db.collection('listings').doc(docId).get();
    final data = snap.data();
    await _db.collection('listings').doc(docId).update({'status': 'rejected'});
    final sellerId = data?['sellerId'] as String?;
    final title    = data?['title']    as String? ?? 'İlanınız';
    if (sellerId != null && sellerId.isNotEmpty) {
      await _db
          .collection('users')
          .doc(sellerId)
          .collection('notifications')
          .add({
        'title': 'İlanınız reddedildi',
        'body': '"$title" ilanınız uygun bulunmadığı için yayına alınmadı.',
        'type': 'rejected',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> deleteListing(String docId) =>
      _db.collection('listings').doc(docId).delete();

  Future<void> updateListing(String docId, Map<String, dynamic> data) =>
      _db.collection('listings').doc(docId).update(data);
}

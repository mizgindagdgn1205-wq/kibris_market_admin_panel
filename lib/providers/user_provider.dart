import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/user_model.dart';

class UserProvider extends ChangeNotifier {
  final _db = FirebaseFirestore.instance;

  List<UserModel> _users = [];
  bool _loading = true;
  String? _error;

  StreamSubscription<QuerySnapshot>? _sub;

  UserProvider() {
    _subscribe();
  }

  bool get loading => _loading;
  String? get error => _error;
  List<UserModel> get users => List.unmodifiable(_users);

  void _subscribe() {
    _sub?.cancel();
    _sub = _db
        .collection('users')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen(
      (snap) {
        _users = snap.docs.map((d) => UserModel.fromMap(d.id, d.data())).toList();
        _loading = false;
        _error = null;
        notifyListeners();
      },
      onError: (e) {
        _error = e.toString();
        _loading = false;
        notifyListeners();
      },
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> setAdmin(String uid, bool isAdmin) async {
    await _db.collection('users').doc(uid).update({'isAdmin': isAdmin});
  }

  Future<void> setBanned(String uid, bool isBanned) async {
    await _db.collection('users').doc(uid).update({'isBanned': isBanned});
  }
}

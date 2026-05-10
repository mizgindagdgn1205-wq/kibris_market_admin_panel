import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  final AuthService _service = AuthService();

  User?       _firebaseUser;
  UserModel?  _userModel;       // Firestore'dan gelen belge
  AuthStatus  _status = AuthStatus.unknown;
  String?     _error;
  bool        _loading = false;

  StreamSubscription<User?>?      _authSub;
  StreamSubscription<UserModel?>? _userSub;

  User?       get firebaseUser => _firebaseUser;
  UserModel?  get userModel    => _userModel;
  AuthStatus  get status       => _status;
  String?     get error        => _error;
  bool        get loading      => _loading;
  bool        get isLoggedIn   => _status == AuthStatus.authenticated;

  // isAdmin artık Firestore belgesinden geliyor
  bool get isAdmin => _userModel?.isAdmin ?? false;

  String get displayName =>
      _userModel?.displayName ?? _firebaseUser?.displayName ?? 'Kullanıcı';
  String get email => _userModel?.email ?? _firebaseUser?.email ?? '';

  AuthProvider() {
    try {
      _authSub = _service.authStateChanges.listen(_onAuthChanged);
    } catch (e) {
      _status = AuthStatus.unauthenticated;
    }
  }

  void _onAuthChanged(User? user) {
    _firebaseUser = user;
    _userSub?.cancel();

    if (user == null) {
      _userModel = null;
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }

    // Kullanıcı giriş yaptı → Firestore belgesini dinlemeye başla
    _userSub = _service.userStream(user.uid).listen((model) {
      _userModel = model;
      _status = AuthStatus.authenticated;
      notifyListeners();
    });
  }

  Future<bool> signIn(String email, String password) async {
    _setLoading(true);
    try {
      await _service.signIn(email, password);
      _error = null;
      return true;
    } on AuthException catch (e) {
      _error = e.message;
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required String phone,
  }) async {
    _setLoading(true);
    try {
      await _service.register(
        email: email,
        password: password,
        displayName: name,
        phone: phone,
      );
      _error = null;
      return true;
    } on AuthException catch (e) {
      _error = e.message;
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> sendPasswordReset(String email) async {
    _setLoading(true);
    try {
      await _service.sendPasswordResetEmail(email);
      _error = null;
      return true;
    } on AuthException catch (e) {
      _error = e.message;
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signOut() async {
    await _service.signOut();
    _userModel = null;
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void _setLoading(bool v) {
    _loading = v;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _userSub?.cancel();
    super.dispose();
  }
}

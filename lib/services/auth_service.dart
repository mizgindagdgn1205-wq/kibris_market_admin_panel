import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';

class AuthException {
  final String message;
  const AuthException(this.message);
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Firestore'dan kullanıcı belgesini dinle
  Stream<UserModel?> userStream(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((snap) => snap.exists
            ? UserModel.fromMap(uid, snap.data()!)
            : null);
  }

  Future<UserModel?> getUser(String uid) async {
    final snap = await _db.collection('users').doc(uid).get();
    if (!snap.exists) return null;
    return UserModel.fromMap(uid, snap.data()!);
  }

  Future<User?> signIn(String email, String password) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return cred.user;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_authErrorMessage(e.code));
    }
  }

  // Kayıt: Auth + Firestore users belgesi oluştur
  Future<User?> register({
    required String email,
    required String password,
    required String displayName,
    required String phone,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = cred.user!;
      await user.updateDisplayName(displayName);

      // Firestore'da users/{uid} belgesini oluştur
      await _db.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': email.trim(),
        'displayName': displayName,
        'phone': phone,
        'isAdmin': false,       // Yeni kullanıcılar admin değil
        'createdAt': DateTime.now().toIso8601String(),
      });

      return user;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_authErrorMessage(e.code));
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthException(_authErrorMessage(e.code));
    }
  }

  Future<void> signOut() async => _auth.signOut();

  String _authErrorMessage(String code) {
    return switch (code) {
      'user-not-found'         => 'Bu e-posta ile kayıtlı kullanıcı bulunamadı.',
      'wrong-password'         => 'Hatalı şifre. Lütfen tekrar deneyin.',
      'invalid-credential'     => 'E-posta veya şifre hatalı.',
      'email-already-in-use'   => 'Bu e-posta adresi zaten kullanımda.',
      'weak-password'          => 'Şifre çok zayıf. En az 6 karakter kullanın.',
      'invalid-email'          => 'Geçersiz e-posta adresi.',
      'too-many-requests'      => 'Çok fazla başarısız giriş. Lütfen bekleyin.',
      'network-request-failed' => 'İnternet bağlantısı yok.',
      _                        => 'Bir hata oluştu. Lütfen tekrar deneyin.',
    };
  }
}

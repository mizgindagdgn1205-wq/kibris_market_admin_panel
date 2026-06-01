import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:otp/otp.dart';
import '../models/user_model.dart';

class AuthException {
  final String message;
  const AuthException(this.message);

  @override
  String toString() => 'AuthException: $message';
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Stream<UserModel?> userStream(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((snap) => snap.exists ? UserModel.fromMap(uid, snap.data()!) : null);
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
      await _db.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': email.trim(),
        'displayName': displayName,
        'phone': phone,
        'isAdmin': false,
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

  // ─── TOTP ────────────────────────────────────────────────────────────────

  /// 32 karakterlik rastgele base32 secret üretir
  String generateTotpSecret() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    final rng = Random.secure();
    return List.generate(32, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  /// Google Authenticator uyumlu otpauth URI
  String totpQrUri(String secret, String email) {
    final label = Uri.encodeComponent('KibrisMarket:$email');
    final issuer = Uri.encodeComponent('KibrisMarket Admin');
    return 'otpauth://totp/$label?secret=$secret&issuer=$issuer&algorithm=SHA1&digits=6&period=30';
  }

  /// Firestore'a secret yaz
  Future<void> saveTotpSecret(String uid, String secret) async {
    await _db.collection('users').doc(uid).update({'totpSecret': secret});
  }

  /// ±1 pencere toleransıyla TOTP doğrula
  bool verifyTotpCode(String secret, String code) {
    final now = DateTime.now().millisecondsSinceEpoch;
    for (int i = -1; i <= 1; i++) {
      final ts = now + (i * 30000);
      final expected = OTP.generateTOTPCodeString(
        secret, ts,
        length: 6,
        interval: 30,
        algorithm: Algorithm.SHA1,
        isGoogle: true,
      );
      if (expected == code) return true;
    }
    return false;
  }

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

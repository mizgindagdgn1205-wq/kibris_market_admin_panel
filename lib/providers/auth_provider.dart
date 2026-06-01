import 'dart:async';
import 'dart:developer' as dev;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

enum AuthStatus { unknown, loading, awaitingTotpSetup, awaitingTotp, authenticated, unauthenticated }

const _kMaxAttempts  = 5;
const _kLockDuration = Duration(minutes: 15);

class AuthProvider extends ChangeNotifier {
  final AuthService _service = AuthService();

  User?       _firebaseUser;
  UserModel?  _userModel;
  AuthStatus  _status = AuthStatus.unknown;
  String?     _error;
  bool        _loading = false;

  // Brute-force koruması
  int       _failedAttempts = 0;
  DateTime? _lockedUntil;

  // TOTP
  bool    _awaitingTotp    = false;
  String? _pendingEmail;
  String? _pendingPassword;
  String? _totpSecret;      // setup ekranında gösterilecek yeni secret

  StreamSubscription<User?>?      _authSub;
  StreamSubscription<UserModel?>? _userSub;

  User?       get firebaseUser   => _firebaseUser;
  UserModel?  get userModel      => _userModel;
  AuthStatus  get status         => _status;
  String?     get error          => _error;
  bool        get loading        => _loading;
  bool        get isLoggedIn     => _status == AuthStatus.authenticated;
  bool        get isAdmin        => _userModel?.isAdmin ?? false;
  int         get failedAttempts => _failedAttempts;
  String?     get totpSecret     => _totpSecret;

  String get displayName =>
      _userModel?.displayName ?? _firebaseUser?.displayName ?? 'Kullanıcı';
  String get email => _userModel?.email ?? _firebaseUser?.email ?? '';

  bool get isLocked {
    if (_lockedUntil == null) return false;
    if (DateTime.now().isAfter(_lockedUntil!)) {
      _lockedUntil = null;
      _failedAttempts = 0;
      return false;
    }
    return true;
  }

  int get lockRemainingSeconds {
    if (_lockedUntil == null) return 0;
    final rem = _lockedUntil!.difference(DateTime.now()).inSeconds;
    return rem < 0 ? 0 : rem;
  }

  AuthProvider() {
    try {
      _authSub = _service.authStateChanges.listen(_onAuthChanged);
    } catch (_) {
      _status = AuthStatus.unauthenticated;
    }
  }

  void _onAuthChanged(User? user) {
    if (_awaitingTotp) return; // TOTP akışı sırasında yoksay

    _firebaseUser = user;
    _userSub?.cancel();

    if (user == null) {
      _userModel = null;
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }

    _status = AuthStatus.loading;
    notifyListeners();

    _service.getUser(user.uid).then((model) {
      _userModel = model;
      _status = AuthStatus.authenticated;
      notifyListeners();
    }).catchError((_) {
      _status = AuthStatus.authenticated;
      notifyListeners();
    });

    _userSub = _service.userStream(user.uid).listen(
      (model) {
        _userModel = model;
        _status = AuthStatus.authenticated;
        notifyListeners();
      },
      onError: (_) {
        if (_status != AuthStatus.authenticated) {
          _status = AuthStatus.authenticated;
          notifyListeners();
        }
      },
      cancelOnError: false,
    );
  }

  Future<bool> signIn(String email, String password) async {
    if (isLocked) {
      _error = 'Çok fazla hatalı giriş. ${lockRemainingSeconds}sn sonra tekrar deneyin.';
      notifyListeners();
      return false;
    }

    _setLoading(true);
    try {
      final user = await _service.signIn(email, password);
      if (user == null) {
        _error = 'Giriş başarısız.';
        return false;
      }

      final model = await _service.getUser(user.uid);
      _failedAttempts = 0;
      _lockedUntil = null;
      _error = null;

      // Admin değilse TOTP gerekmez
      if (!(model?.isAdmin ?? false)) return true;

      // Admin → TOTP akışı
      _awaitingTotp = true;
      _pendingEmail = email;
      _pendingPassword = password;
      _userModel = model;

      final existingSecret = model?.totpSecret;
      if (existingSecret == null || existingSecret.isEmpty) {
        // İlk kez → secret üret, QR kurulum ekranı göster
        _totpSecret = _service.generateTotpSecret();
        await _service.saveTotpSecret(user.uid, _totpSecret!);
        _status = AuthStatus.awaitingTotpSetup;
        dev.log('[TOTP] Yeni secret oluşturuldu, kurulum ekranı gösteriliyor', name: 'AuthProvider');
      } else {
        // Mevcut secret → doğrulama ekranı
        _totpSecret = existingSecret;
        _status = AuthStatus.awaitingTotp;
        dev.log('[TOTP] Mevcut secret bulundu, doğrulama ekranı gösteriliyor', name: 'AuthProvider');
      }
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _failedAttempts++;
      if (_failedAttempts >= _kMaxAttempts) {
        _lockedUntil = DateTime.now().add(_kLockDuration);
        _error = 'Çok fazla hatalı giriş. Hesap 15 dakika kilitlendi.';
      } else {
        final remaining = _kMaxAttempts - _failedAttempts;
        _error = '${e.message} ($remaining deneme hakkı kaldı)';
      }
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Kurulum ekranından "Doğruladım" tıklandığında
  void confirmTotpSetup() {
    _status = AuthStatus.awaitingTotp;
    notifyListeners();
  }

  /// Kod giriş ekranından doğrulama
  Future<bool> verifyTotp(String code) async {
    if (_totpSecret == null) {
      _error = 'TOTP oturumu geçersiz. Lütfen tekrar giriş yapın.';
      notifyListeners();
      return false;
    }

    final ok = _service.verifyTotpCode(_totpSecret!, code);
    if (!ok) {
      _error = 'Hatalı kod. Google Authenticator\'daki güncel kodu girin.';
      notifyListeners();
      return false;
    }

    // Doğrulama başarılı → email/password ile yeniden oturum aç
    _setLoading(true);
    try {
      await _service.signOut();
      _awaitingTotp = false;
      final user = await _service.signIn(_pendingEmail!, _pendingPassword!);
      _pendingEmail = null;
      _pendingPassword = null;

      if (user == null) {
        _error = 'Yeniden kimlik doğrulama başarısız.';
        _status = AuthStatus.unauthenticated;
        notifyListeners();
        return false;
      }

      _firebaseUser = user;
      _error = null;
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _error = e.message;
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signOut() async {
    await _service.signOut();
    _userModel = null;
    _failedAttempts = 0;
    _lockedUntil = null;
    _awaitingTotp = false;
    _pendingEmail = null;
    _pendingPassword = null;
    _totpSecret = null;
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

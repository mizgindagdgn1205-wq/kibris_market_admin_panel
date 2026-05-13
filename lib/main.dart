import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
<<<<<<< HEAD
import 'screens/categories_screen.dart';
import 'screens/pending_listings_screen.dart';
import 'screens/send_notification_screen.dart';
=======
import 'providers/listing_provider.dart';
import 'providers/user_provider.dart';
import 'screens/web_admin_shell.dart';
>>>>>>> 7b97060c3409da2879e2ff64ffcd873a089b502d
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(
<<<<<<< HEAD
    ChangeNotifierProvider(
      create: (_) => AuthProvider(),
=======
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ListingProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
      ],
>>>>>>> 7b97060c3409da2879e2ff64ffcd873a089b502d
      child: const AdminApp(),
    ),
  );
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kıbrıs Market Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        useMaterial3: true,
      ),
      home: const _LoginScreen(),
    );
  }
}

// ── Giriş Ekranı ─────────────────────────────────────────────────────────────

class _LoginScreen extends StatefulWidget {
  const _LoginScreen();

  @override
  State<_LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<_LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  final _uidCtrl   = TextEditingController();
  bool _loading = false;
  String? _error;

  static const _tempAdminUid = 'SN0F8E86tGR3rpPPWgmj9nOXKsw2';

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _uidCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    // Geçici UID girişi
    if (_uidCtrl.text.trim() == _tempAdminUid) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AdminShell()),
      );
      return;
    }

    // E-posta + şifre girişi
    if (_emailCtrl.text.trim().isEmpty || _passCtrl.text.isEmpty) {
      setState(() => _error = 'UID, veya e-posta ve şifre giriniz.');
      return;
    }

    setState(() { _loading = true; _error = null; });
    final ok = await context.read<AuthProvider>().signIn(
      _emailCtrl.text.trim(), _passCtrl.text,
    );
    if (!mounted) return;
    if (ok) {
      final auth = context.read<AuthProvider>();
      if (auth.isAdmin) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AdminShell()),
        );
      } else {
        setState(() { _error = 'Bu hesabın admin yetkisi yok.'; _loading = false; });
        await auth.signOut();
      }
    } else {
      setState(() { _error = 'E-posta veya şifre hatalı.'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: Center(
        child: SizedBox(
          width: 360,
          child: Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.admin_panel_settings, size: 48, color: Color(0xFF1A2035)),
                  const SizedBox(height: 12),
                  const Text('Admin Girişi',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),

                  // Geçici UID girişi
                  TextField(
                    controller: _uidCtrl,
                    onSubmitted: (_) => _login(),
                    decoration: const InputDecoration(
                      labelText: 'UID ile giriş (geçici)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.key_outlined),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Row(children: [
                      Expanded(child: Divider()),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text('veya', style: TextStyle(color: Colors.grey)),
                      ),
                      Expanded(child: Divider()),
                    ]),
                  ),

                  // E-posta girişi
                  TextField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'E-posta',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passCtrl,
                    obscureText: true,
                    onSubmitted: (_) => _login(),
                    decoration: const InputDecoration(
                      labelText: 'Şifre',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A2035),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _loading
                          ? const SizedBox(width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Giriş Yap'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Admin Shell ───────────────────────────────────────────────────────────────

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;

  static const _pages = [
    PendingListingsScreen(),
    CategoriesScreen(),
    SendNotificationScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        selectedItemColor: const Color(0xFF1A2035),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt_outlined),
            activeIcon: Icon(Icons.list_alt),
            label: 'İlanlar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.category_outlined),
            activeIcon: Icon(Icons.category),
            label: 'Kategoriler',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications_outlined),
            activeIcon: Icon(Icons.notifications),
            label: 'Bildirimler',
          ),
        ],
      ),
    );
  }
}

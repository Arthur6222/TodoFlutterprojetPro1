import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'home_page.dart';
import 'auth_page.dart';

// ⚠️  En production : déplacez ces valeurs dans un fichier .env
//     et ajoutez .env dans votre .gitignore.
const supaurl     = 'https://rumnmiuqomekxcpusdwh.supabase.co';
const supaanonkey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9'
    '.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJ1bW5taXVxb21la3hjcHVzZHdoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ3Mjg4MTgsImV4cCI6MjA5MDMwNDgxOH0'
    '.lbcJxo3a3tJRZOMPS5pkR1ZdonOt6d3Sw6OJwYkWycE';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Supabase.initialize(url: supaurl, anonKey: supaanonkey);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Supanotes',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.amberAccent),
        scaffoldBackgroundColor: Colors.grey[200],
        useMaterial3: true,
        dialogTheme: DialogThemeData(
          backgroundColor: const Color(0xFFFFFCED),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      home: const AuthHandler(),
    );
  }
}

// ---------------------------------------------------------------------------
//  AuthHandler — écoute Hive et bascule entre AuthPage et NotePage
// ---------------------------------------------------------------------------
class AuthHandler extends StatefulWidget {
  const AuthHandler({super.key});

  @override
  State<AuthHandler> createState() => _AuthHandlerState();
}

class _AuthHandlerState extends State<AuthHandler> {
  bool _isLoggedIn = false;
  bool _loading    = true;
  Box?  _authBox;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _authBox = await Hive.openBox('auth');
    _updateLoginState();
    _authBox!.listenable().addListener(_updateLoginState);
  }

  void _updateLoginState() {
    if (!mounted) return;
    final username = _authBox?.get('username');
    setState(() {
      _isLoggedIn = username != null;
      _loading    = false;
    });
  }

  @override
  void dispose() {
    _authBox?.listenable().removeListener(_updateLoginState);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return _isLoggedIn ? const NotePage() : const AuthPage();
  }
}
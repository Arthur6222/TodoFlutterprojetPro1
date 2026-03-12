import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'home_page.dart';
import 'auth_page.dart';

const supaurl = 'https://waieouzobsdegiiyedqw.supabase.co';
const supaanonkey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndhaWVvdXpvYnNkZWdpaXllZHF3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjMzMzc5NTcsImV4cCI6MjA3ODkxMzk1N30.6FoBEJZosUTj4fmt-J0zGgmCvJcIwZtcNmPyqB4esQU';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialiser Hive
  await Hive.initFlutter();
  
  // Initialiser Supabase
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

// Gère l'état d'authentification
class AuthHandler extends StatefulWidget {
  const AuthHandler({super.key});

  @override
  State<AuthHandler> createState() => _AuthHandlerState();
}

class _AuthHandlerState extends State<AuthHandler> {
  bool _isLoggedIn = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final box = await Hive.openBox('auth');
    final username = box.get('username');
     
    setState(() {
      _isLoggedIn = username != null;
      _loading = false;
    });

    // Écouter les changements dans Hive
    box.listenable().addListener(() {
      if (mounted) {
        final newUsername = box.get('username');
        setState(() {
          _isLoggedIn = newUsername != null;
        });
      }
    });
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
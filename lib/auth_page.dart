import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';



class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _supabase = Supabase.instance.client;

  bool _loading = false;
  bool _isLoginMode = true;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleAuth() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      _showMessage('Veuillez remplir tous les champs');
      return;
    }
    if (username.length < 3) {
      _showMessage("Le nom d'utilisateur doit contenir au moins 3 caractères");
      return;
    }
    if (password.length < 6) {
      _showMessage('Le mot de passe doit contenir au moins 6 caractères');
      return;
    }

    setState(() => _loading = true);
    try {
      if (_isLoginMode) {
        await _login(username, password);
      } else {
        await _register(username, password);
      }
    } catch (e) {
      _showMessage('Une erreur est survenue : ${e.toString()}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _login(String username, String password) async {
    

    final result = await _supabase
        .from('users')
        .select('id_user, password')
        .eq('username', username)
        .maybeSingle();

    if (result == null) {
      _showMessage('Utilisateur introuvable');
      return;
    }

    if (result['password'] != password) {
      _showMessage('Mot de passe incorrect');
      return;
    }

    final box = await Hive.openBox('auth');
    await box.put('id_user', result['id_user'].toString());
    await box.put('username', username);

    _showMessage('Connexion réussie !');
  }

  Future<void> _register(String username, String password) async {
    final existing = await _supabase
        .from('users')
        .select('id_user')
        .eq('username', username)
        .maybeSingle();

    if (existing != null) {
      _showMessage("Ce nom d'utilisateur existe déjà");
      return;
    }

    final inserted = await _supabase
        .from('users')
        .insert({
          'username': username,
          'password': password,
        })
        .select('id_user')
        .single();

    final box = await Hive.openBox('auth');
    await box.put('id_user', inserted['id_user'].toString());
    await box.put('username', username);

    _showMessage('Inscription réussie !');
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              padding: const EdgeInsets.all(32),
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.note_alt_outlined,
                      size: 80, color: Colors.amberAccent[700]),
                  const SizedBox(height: 16),
                  Text(
                    'Flutter Supanotes',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.amberAccent[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isLoginMode ? 'Bienvenue !' : 'Créer un compte',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _usernameController,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: "Nom d'utilisateur",
                      hintText: "Entrez votre nom d'utilisateur",
                      prefixIcon: const Icon(Icons.person),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _handleAuth(),
                    decoration: InputDecoration(
                      labelText: 'Mot de passe',
                      hintText: 'Entrez votre mot de passe',
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword
                            ? Icons.visibility
                            : Icons.visibility_off),
                        onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_loading)
                    const CircularProgressIndicator()
                  else
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _handleAuth,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amberAccent[700],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          _isLoginMode ? 'Se connecter' : "S'inscrire",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () =>
                        setState(() => _isLoginMode = !_isLoginMode),
                    child: Text(
                      _isLoginMode
                          ? "Pas de compte ? S'inscrire"
                          : 'Déjà un compte ? Se connecter',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.amberAccent[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isLoginMode
                        ? 'Entrez vos identifiants pour vous connecter'
                        : 'Créez un compte pour commencer',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    textAlign: TextAlign.center,
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

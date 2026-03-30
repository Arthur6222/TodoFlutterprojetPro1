import 'dart:convert';
import 'package:crypto/crypto.dart';          
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Hashage SHA-256 du mot de passe avant tout envoi réseau
String _hashPassword(String password) =>
    sha256.convert(utf8.encode(password)).toString();

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _supabase = Supabase.instance.client;

  bool _loading         = false;
  bool _isLoginMode     = true;   // true = connexion, false = inscription
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  //  Validation + dispatch
  // -------------------------------------------------------------------------
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

  // -------------------------------------------------------------------------
  //  Connexion
  // -------------------------------------------------------------------------
  Future<void> _login(String username, String password) async {
    final hashedPwd = _hashPassword(password);

    final result = await _supabase
        .from('users')
        .select('id_user, password')
        .eq('username', username)
        .maybeSingle();

    if (result == null) {
      _showMessage('Utilisateur introuvable');
      return;
    }

    // Comparaison du hash (jamais le mot de passe en clair)
    if (result['password'] != hashedPwd) {
      _showMessage('Mot de passe incorrect');
      return;
    }

    // Stockage local : on garde l'UUID renvoyé par Supabase
    final box = await Hive.openBox('auth');
    await box.put('id_user', result['id_user'].toString());
    await box.put('username', username);

    _showMessage('Connexion réussie !');
    // AuthHandler détecte le changement via listenable → navigation auto
  }

  // -------------------------------------------------------------------------
  //  Inscription
  // -------------------------------------------------------------------------
  Future<void> _register(String username, String password) async {
    // Vérification doublon
    final existing = await _supabase
        .from('users')
        .select('id_user')
        .eq('username', username)
        .maybeSingle();

    if (existing != null) {
      _showMessage("Ce nom d'utilisateur existe déjà");
      return;
    }

    // INSERT — id_user est un UUID généré par Supabase (gen_random_uuid())
    // On récupère l'UUID créé via select()
    final inserted = await _supabase
        .from('users')
        .insert({
          'username': username,
          'password': _hashPassword(password),   // SHA-256, jamais le clair
        })
        .select('id_user')
        .single();

    final box = await Hive.openBox('auth');
    await box.put('id_user', inserted['id_user'].toString());
    await box.put('username', username);

    _showMessage('Inscription réussie !');
    // AuthHandler détecte le changement via listenable → navigation auto
  }

  // -------------------------------------------------------------------------
  //  Helpers
  // -------------------------------------------------------------------------
  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // -------------------------------------------------------------------------
  //  UI
  // -------------------------------------------------------------------------
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

                  // Champ username
                  TextField(
                    controller: _usernameController,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: "Nom d'utilisateur",
                      hintText: 'Entrez votre pseudo',
                      prefixIcon: const Icon(Icons.person),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Champ mot de passe
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
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Bouton principal
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
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          _isLoginMode ? 'Se connecter' : "S'inscrire",
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black),
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),

                  // Basculer mode
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
                          fontWeight: FontWeight.w600),
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
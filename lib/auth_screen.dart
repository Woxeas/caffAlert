import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'name_screen.dart';
import 'timer_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  AuthScreenState createState() => AuthScreenState();
}

class AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLogin = true;
  String? _errorMessage;

  Future<void> _authenticate() async {
    try {
      if (_isLogin) {
        final response = await Supabase.instance.client.auth.signInWithPassword(
          email: _emailController.text,
          password: _passwordController.text,
        );
        if (response.session != null) {
          if (!mounted) return;

          // Ověření, zda uživatel už má jméno
          bool hasName = await _hasName(response.session!.user.id);
          
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => hasName ? TimerScreen() : NameScreen()),
            );
          }
        } else {
          if (!mounted) return;
          setState(() {
            _errorMessage = "Sign-in failed. Please check your credentials.";
          });
        }
      } else {
        final response = await Supabase.instance.client.auth.signUp(
          email: _emailController.text,
          password: _passwordController.text,
        );
        if (response.user != null) {
          if (!mounted) return;
          setState(() {
            _isLogin = true;
          });
          await _createProfileIfNotExists(response.user!.id);
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => NameScreen()),
          );
        }
      }
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
      });
    }
  }

  /// Funkce na ověření, zda už má uživatel jméno
  Future<bool> _hasName(String userId) async {
    final response = await Supabase.instance.client
        .from('profiles')
        .select('name')
        .eq('id', userId)
        .maybeSingle();

    if (response == null) return false;
    final name = response['name'];
    return name != null && name.toString().trim().isNotEmpty;
  }

  // Funkce pro vytvoření profilu, pokud neexistuje
  Future<void> _createProfileIfNotExists(String userId) async {
    final response = await Supabase.instance.client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();

    if (response == null) {
      await Supabase.instance.client.from('profiles').insert({
        'id': userId,
        'name': null,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isLogin ? 'Login' : 'Sign Up'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            if (_errorMessage != null)
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _authenticate,
              child: Text(_isLogin ? 'Login' : 'Sign Up'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _isLogin = !_isLogin;
                  _errorMessage = null;
                });
              },
              child: Text(_isLogin
                  ? 'Don\'t have an account? Sign Up'
                  : 'Already have an account? Login'),
            ),
          ],
        ),
      ),
    );
  }
}

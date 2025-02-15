import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Registrace uživatele
  Future<void> signUp(String email, String password) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
      );
      if (response.user == null) {
        throw Exception("Failed to sign up");
      }
    } on AuthException catch (e) {
      throw Exception(e.message);
    }
  }

  // Přihlášení uživatele
  Future<void> signIn(String email, String password) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (response.session == null) {
        throw Exception("Failed to sign in");
      }
    } on AuthException catch (e) {
      throw Exception(e.message);
    }
  }

  // Odhlášení uživatele
  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
    } on AuthException catch (e) {
      throw Exception(e.message);
    }
  }

  // Kontrola, zda je uživatel přihlášen
  bool get isAuthenticated => _supabase.auth.currentSession != null;
}

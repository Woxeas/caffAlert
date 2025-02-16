import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_logger.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Registrace uživatele
  Future<void> signUp(String email, String password) async {
    try {
      AppLogger.logger.d("Signing up user: $email");
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
      );
      if (response.user == null) {
        AppLogger.logger.e("Sign up failed for user: $email");
        throw Exception("Failed to sign up");
      }
      AppLogger.logger.i("User signed up: ${response.user}");
    } on AuthException catch (e) {
      AppLogger.logger.e("AuthException during signUp: ${e.message}");
      throw Exception(e.message);
    }
  }

  // Přihlášení uživatele
  Future<void> signIn(String email, String password) async {
    try {
      AppLogger.logger.d("Signing in user: $email");
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (response.session == null) {
        AppLogger.logger.e("Sign in failed for user: $email");
        throw Exception("Failed to sign in");
      }
      AppLogger.logger.i("User signed in, session: ${response.session}");
    } on AuthException catch (e) {
      AppLogger.logger.e("AuthException during signIn: ${e.message}");
      throw Exception(e.message);
    }
  }

  // Odhlášení uživatele
  Future<void> signOut() async {
    try {
      AppLogger.logger.d("Signing out user");
      await _supabase.auth.signOut();
      AppLogger.logger.i("User signed out");
    } on AuthException catch (e) {
      AppLogger.logger.e("AuthException during signOut: ${e.message}");
      throw Exception(e.message);
    }
  }

  // Kontrola, zda je uživatel přihlášen
  bool get isAuthenticated => _supabase.auth.currentSession != null;
}

import 'package:flutter/material.dart';
import '../../services/firebase/auth_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();

  Future<bool> signInWithEmail(String email, String password) async {
    final user = await _authService.signInWithEmail(email, password);
    if (user != null) {
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<bool> signUpWithEmail(String email, String password) async {
    final user = await _authService.signUpWithEmail(email, password);
    if (user != null) {
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<void> signOut() async {
    await _authService.signOut();
    notifyListeners();
  }

  bool get isAuthenticated => _authService.currentUser != null;

  Future<bool> resetPassword(String email) async {
    try {
      await _authService.sendPasswordResetEmail(email);
      return true;
    } catch (e) {
      print('Error sending password reset email: $e');
      return false;
    }
  }
}

import 'package:firebase_auth/firebase_auth.dart';

class AdminService {
  static bool isCurrentUserAdmin() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    // Firebase Auth custom claims are not directly exposed in Flutter SDK.
    // But you can access them via IdTokenResult.claims
    // This function should be async, but for button visibility, you may want to use a FutureBuilder or similar.
    return false;
  }

  static Future<bool> isCurrentUserAdminAsync() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    final idTokenResult = await user.getIdTokenResult();
    final claims = idTokenResult.claims;
    return claims != null && claims['admin'] == true;
  }
}

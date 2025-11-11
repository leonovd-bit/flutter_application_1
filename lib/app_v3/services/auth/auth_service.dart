import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../connectivity_service_v3.dart';
import 'firestore_service_v3.dart';
import 'progress_manager.dart';

/// Centralized authentication service for all auth methods
/// Handles email/password, Google Sign-In, and Apple Sign-In
class AuthService {
  // Singleton pattern
  AuthService._();
  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // ===========================================================================
  // GETTERS & STREAMS
  // ===========================================================================

  /// Get current authenticated user
  User? get currentUser => _auth.currentUser;

  /// Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Check if user is signed in
  bool get isSignedIn => _auth.currentUser != null;

  // ===========================================================================
  // EMAIL/PASSWORD AUTHENTICATION
  // ===========================================================================

  /// Sign up with email and password
  /// Returns UserCredential on success, throws exception on failure
  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      debugPrint('[AuthService] Starting email signup for: $email');

      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      debugPrint('[AuthService] User created: ${credential.user?.uid}');

      // Update display name if provided
      if (displayName != null && displayName.trim().isNotEmpty) {
        await credential.user?.updateDisplayName(displayName.trim());
        debugPrint('[AuthService] Display name updated');
      }

      // Send email verification
      await credential.user?.sendEmailVerification();
      debugPrint('[AuthService] Verification email sent');

      // Save progress
      await ProgressManager.saveCurrentStep(OnboardingStep.emailVerification);

      return credential;
    } on FirebaseAuthException catch (e) {
      debugPrint('[AuthService] Firebase Auth Exception: ${e.code} - ${e.message}');
      throw _handleAuthException(e);
    } catch (e) {
      debugPrint('[AuthService] Unexpected error in email signup: $e');
      rethrow;
    }
  }

  /// Sign in with email and password
  /// Returns UserCredential on success, throws exception on failure
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      // Check connectivity first
      final hasConnection = await ConnectivityServiceV3.hasInternetConnection();
      if (!hasConnection) {
        throw Exception('No internet connection. Please check your network and try again.');
      }

      debugPrint('[AuthService] Attempting email sign in: $email');

      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Connection timeout. Please check your internet connection and try again.');
        },
      );

      debugPrint('[AuthService] Sign in successful: ${credential.user?.email}');
      debugPrint('[AuthService] Email verified: ${credential.user?.emailVerified}');

      // Create/update user profile in Firestore
      if (credential.user != null) {
        await _updateUserProfile(credential.user!);
      }

      return credential;
    } on FirebaseAuthException catch (e) {
      debugPrint('[AuthService] Firebase Auth Exception: ${e.code} - ${e.message}');
      throw _handleAuthException(e);
    } catch (e) {
      debugPrint('[AuthService] Error in email sign in: $e');
      rethrow;
    }
  }

  // ===========================================================================
  // GOOGLE SIGN-IN
  // ===========================================================================

  /// Sign in with Google
  /// Returns UserCredential on success, null if user cancelled, throws on error
  Future<UserCredential?> signInWithGoogle() async {
    try {
      debugPrint('[AuthService] Starting Google sign-in');

      // Trigger Google Sign-In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Google sign in timeout. Please check your internet connection.');
        },
      );

      // User cancelled the sign-in
      if (googleUser == null) {
        debugPrint('[AuthService] Google sign-in cancelled by user');
        return null;
      }

      debugPrint('[AuthService] Google user authenticated: ${googleUser.email}');

      // Obtain auth details
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Verify we have tokens
      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        throw Exception('Failed to obtain Google authentication tokens');
      }

      debugPrint('[AuthService] Google tokens obtained');

      // Create Firebase credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase
      final userCredential = await _auth.signInWithCredential(credential).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Firebase authentication timeout. Please check your internet connection.');
        },
      );

      debugPrint('[AuthService] Firebase sign-in successful: ${userCredential.user?.uid}');

      // Create/update user profile in Firestore
      if (userCredential.user != null) {
        await _updateUserProfile(userCredential.user!);
      }

      // Save progress
      await ProgressManager.saveCurrentStep(OnboardingStep.signup);

      return userCredential;
    } on FirebaseAuthException catch (e) {
      debugPrint('[AuthService] Firebase Auth Exception in Google sign-in: ${e.code} - ${e.message}');
      throw _handleAuthException(e);
    } catch (e) {
      debugPrint('[AuthService] Error in Google sign-in: $e');
      // Check for specific Google Sign-In errors
      if (e.toString().contains('sign_in_canceled')) {
        return null; // User cancelled
      }
      rethrow;
    }
  }

  /// Sign out from Google (call this along with Firebase signOut)
  Future<void> signOutGoogle() async {
    try {
      await _googleSignIn.signOut();
      debugPrint('[AuthService] Google sign-out successful');
    } catch (e) {
      debugPrint('[AuthService] Error signing out from Google: $e');
      // Don't throw - sign out should always succeed
    }
  }

  // ===========================================================================
  // APPLE SIGN-IN
  // ===========================================================================

  /// Sign in with Apple
  /// Returns UserCredential on success, throws on error
  Future<UserCredential> signInWithApple() async {
    try {
      debugPrint('[AuthService] Starting Apple sign-in');

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      final userCredential = await _auth.signInWithCredential(oauthCredential);

      debugPrint('[AuthService] Apple sign-in successful: ${userCredential.user?.uid}');

      // Create/update user profile in Firestore
      if (userCredential.user != null) {
        await _updateUserProfile(userCredential.user!);
      }

      // Save progress
      await ProgressManager.saveCurrentStep(OnboardingStep.signup);

      return userCredential;
    } on FirebaseAuthException catch (e) {
      debugPrint('[AuthService] Firebase Auth Exception in Apple sign-in: ${e.code} - ${e.message}');
      throw _handleAuthException(e);
    } catch (e) {
      debugPrint('[AuthService] Error in Apple sign-in: $e');
      rethrow;
    }
  }

  // ===========================================================================
  // PASSWORD RESET
  // ===========================================================================

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      debugPrint('[AuthService] Password reset email sent to: $email');
    } on FirebaseAuthException catch (e) {
      debugPrint('[AuthService] Error sending password reset: ${e.code}');
      throw _handleAuthException(e);
    }
  }

  // ===========================================================================
  // SIGN OUT
  // ===========================================================================

  /// Sign out from all providers
  Future<void> signOut() async {
    try {
      debugPrint('[AuthService] Signing out');
      
      // Sign out from Google if signed in
      await signOutGoogle();
      
      // Sign out from Firebase
      await _auth.signOut();
      
      debugPrint('[AuthService] Sign out successful');
    } catch (e) {
      debugPrint('[AuthService] Error during sign out: $e');
      // Don't throw - sign out should always succeed
    }
  }

  // ===========================================================================
  // EMAIL VERIFICATION
  // ===========================================================================

  /// Send email verification to current user
  Future<void> sendEmailVerification() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('No user signed in');
      }

      if (user.emailVerified) {
        debugPrint('[AuthService] Email already verified');
        return;
      }

      await user.sendEmailVerification();
      debugPrint('[AuthService] Verification email sent');
    } catch (e) {
      debugPrint('[AuthService] Error sending verification email: $e');
      rethrow;
    }
  }

  /// Reload current user to check email verification status
  Future<bool> checkEmailVerified() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      await user.reload();
      final updatedUser = _auth.currentUser;
      return updatedUser?.emailVerified ?? false;
    } catch (e) {
      debugPrint('[AuthService] Error checking email verification: $e');
      return false;
    }
  }

  // ===========================================================================
  // HELPER METHODS
  // ===========================================================================

  /// Update or create user profile in Firestore
  Future<void> _updateUserProfile(User user) async {
    try {
      await FirestoreServiceV3.updateUserProfile(user.uid, {
        'id': user.uid,
        'email': user.email ?? '',
        if (user.displayName != null && user.displayName!.trim().isNotEmpty)
          'fullName': user.displayName,
        if (user.phoneNumber != null && user.phoneNumber!.trim().isNotEmpty)
          'phoneNumber': user.phoneNumber,
      });
      debugPrint('[AuthService] User profile updated in Firestore');
    } catch (e) {
      debugPrint('[AuthService] Error updating user profile: $e');
      // Don't throw - profile update failure shouldn't fail auth
    }
  }

  /// Handle Firebase Auth exceptions and return user-friendly messages
  Exception _handleAuthException(FirebaseAuthException e) {
    String message;
    
    switch (e.code) {
      // Email/Password errors
      case 'weak-password':
        message = 'The password provided is too weak.';
        break;
      case 'email-already-in-use':
        message = 'An account already exists for that email.';
        break;
      case 'invalid-email':
        message = 'The email address is not valid.';
        break;
      case 'operation-not-allowed':
        message = 'Email/password accounts are not enabled.';
        break;
      case 'user-not-found':
        message = 'No account found with this email.';
        break;
      case 'wrong-password':
      case 'invalid-credential':
        message = 'Incorrect email or password.';
        break;
      
      // Network errors
      case 'network-request-failed':
        message = 'Network error. Please check your internet connection.';
        break;
      
      // Rate limiting
      case 'too-many-requests':
        message = 'Too many failed attempts. Please try again later.';
        break;
      
      // Account status
      case 'user-disabled':
        message = 'This account has been disabled. Please contact support.';
        break;
      
      default:
        message = 'Authentication error: ${e.message ?? e.code}';
    }
    
    return Exception(message);
  }
}

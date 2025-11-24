import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import './firestore_service_v3.dart';

/// Service to handle Firebase phone number verification
/// 
/// Supports two flows:
/// 1. Sign-up flow: startPhoneVerification() → verify with dialog → updateUserProfilePhone()
/// 2. Settings flow: Use PhoneVerificationDialog with callbacks
class PhoneVerificationService {
  PhoneVerificationService._();
  static final PhoneVerificationService instance = PhoneVerificationService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Current verification ID (set by startPhoneVerification)
  String? _currentVerificationId;
  
  /// Current phone number being verified
  String? _currentPhoneNumber;

  /// Get current phone number being verified
  String? get currentPhoneNumber => _currentPhoneNumber;

  /// Start phone number verification - simplified for signup flow
  /// 
  /// Sends an SMS with verification code to the provided phone number.
  /// Phone number should be in E.164 format: +[country code][number]
  /// Example: +15551234567
  /// 
  /// Throws FirebaseAuthException if verification fails
  Future<void> startPhoneVerification(String phoneNumber) async {
    try {
      _currentPhoneNumber = phoneNumber;
      
      debugPrint('[PhoneVerification] Starting verification for: $phoneNumber');

      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 120),
        
        verificationCompleted: (PhoneAuthCredential credential) {
          debugPrint('[PhoneVerification] Auto-completed');
          _currentVerificationId = null;
        },
        
        verificationFailed: (FirebaseAuthException e) {
          debugPrint('[PhoneVerification] Failed: ${e.message}');
          _currentVerificationId = null;
          _currentPhoneNumber = null;
        },
        
        codeSent: (String verificationId, int? resendToken) {
          debugPrint('[PhoneVerification] Code sent');
          _currentVerificationId = verificationId;
        },
        
        codeAutoRetrievalTimeout: (String verificationId) {
          debugPrint('[PhoneVerification] Timeout');
        },
      );
    } catch (e) {
      debugPrint('[PhoneVerification] Error: $e');
      _currentVerificationId = null;
      _currentPhoneNumber = null;
      rethrow;
    }
  }

  /// Verify the code entered by user
  /// 
  /// Returns PhoneAuthCredential if successful.
  Future<PhoneAuthCredential> verifyCode(String code) async {
    try {
      final vId = _currentVerificationId;
      
      if (vId == null) {
        throw Exception('No verification ID available');
      }

      debugPrint('[PhoneVerification] Verifying code');

      final credential = PhoneAuthProvider.credential(
        verificationId: vId,
        smsCode: code,
      );

      debugPrint('[PhoneVerification] Code verified');
      _currentVerificationId = null;
      
      return credential;
    } catch (e) {
      debugPrint('[PhoneVerification] Error: $e');
      rethrow;
    }
  }

  /// Link verified phone credential to current user's account
  /// 
  /// After successful code verification, call this to link the phone
  /// to the user's Firebase account.
  Future<void> linkPhoneToCurrentUser(PhoneAuthCredential credential) async {
    try {
      final user = _auth.currentUser;
      
      if (user == null) {
        throw Exception('No user logged in');
      }

      debugPrint('[PhoneVerification] Linking phone to user: ${user.uid}');

      await user.linkWithCredential(credential);

      debugPrint('[PhoneVerification] Phone linked');
      _currentPhoneNumber = null;
    } catch (e) {
      debugPrint('[PhoneVerification] Error: $e');
      rethrow;
    }
  }

  /// Update user profile with verified phone number in Firestore
  /// 
  /// Call after linkPhoneToCurrentUser() succeeds to store the phone in Firestore.
  Future<void> updateUserProfilePhone() async {
    try {
      final user = _auth.currentUser;
      final phoneNumber = user?.phoneNumber ?? _currentPhoneNumber;
      
      if (user == null || phoneNumber == null) {
        throw Exception('No user or phone number');
      }

      debugPrint('[PhoneVerification] Updating Firestore for: ${user.uid}');

      await FirestoreServiceV3.updatePhoneVerification(
        user.uid,
        phoneNumber,
      );

      debugPrint('[PhoneVerification] Firestore updated');
    } catch (e) {
      debugPrint('[PhoneVerification] Error: $e');
      rethrow;
    }
  }

  /// Check if current user's phone is verified in Firestore
  /// 
  /// Used during signup flow polling
  Future<bool> checkPhoneVerificationStatus() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      return await FirestoreServiceV3.isPhoneNumberVerified(user.uid);
    } catch (e) {
      debugPrint('[PhoneVerification] Status check error: $e');
      return false;
    }
  }

  /// Check if current user has a verified phone number
  bool hasVerifiedPhone() {
    final phoneNumber = _auth.currentUser?.phoneNumber;
    return phoneNumber != null && phoneNumber.isNotEmpty;
  }

  /// Get current user's phone number from Firebase Auth
  String? getCurrentUserPhone() {
    return _auth.currentUser?.phoneNumber;
  }

  /// Cancel current verification
  void cancelVerification() {
    _currentVerificationId = null;
    _currentPhoneNumber = null;
    debugPrint('[PhoneVerification] Cancelled');
  }
}

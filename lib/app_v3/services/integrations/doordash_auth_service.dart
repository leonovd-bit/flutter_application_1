import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import '../../config/doordash_config.dart';

/// JWT Authentication Service for DoorDash API
/// Generates and manages JWT tokens for secure API communication
class DoorDashAuthService {
  DoorDashAuthService._();
  static final DoorDashAuthService instance = DoorDashAuthService._();

  /// Generate JWT token for DoorDash API authentication
  /// Uses manual HMAC-SHA256 signing to match Node.js implementation
  String generateJWTToken() {
    try {
      // Check if we have valid credentials
      if (!DoorDashConfig.hasValidCredentials) {
        throw Exception('DoorDash credentials not configured. ${DoorDashConfig.credentialStatus}');
      }

      // JWT Header
      final header = {
        'alg': 'HS256',
        'typ': 'JWT',
        'dd-ver': 'DD-JWT-V1'
      };

      // JWT Payload
      final now = DateTime.now();
      final expiry = now.add(const Duration(minutes: 30)); // Token expires in 30 minutes (DoorDash max)
      
      final payload = {
        'aud': 'doordash',
        'iss': DoorDashConfig.developerId,
        'kid': DoorDashConfig.keyId,
        'exp': expiry.millisecondsSinceEpoch ~/ 1000,
        'iat': now.millisecondsSinceEpoch ~/ 1000,
      };

      // Base64url encode (remove padding, replace characters)
      String base64UrlEncode(Map<String, dynamic> obj) {
        final json = jsonEncode(obj);
        final bytes = utf8.encode(json);
        return base64Url.encode(bytes).replaceAll('=', '');
      }

      // Create JWT parts
      final headerB64 = base64UrlEncode(header);
      final payloadB64 = base64UrlEncode(payload);
      final signatureInput = '$headerB64.$payloadB64';

      // Decode the signing secret from base64url BEFORE signing
      // DoorDash documentation: "the signing secret was base64url decoded prior to signing"
      String secret = DoorDashConfig.signingKey;
      // Add padding if needed for base64url decoding
      while (secret.length % 4 != 0) {
        secret += '=';
      }
      final decodedSecret = base64Url.decode(secret);
      
      // Sign with HMAC-SHA256 using the decoded secret bytes
      final hmac = Hmac(sha256, decodedSecret);
      final digest = hmac.convert(utf8.encode(signatureInput));
      
      // Base64url encode the signature
      final signature = base64Url.encode(digest.bytes).replaceAll('=', '');
      
      final token = '$signatureInput.$signature';

      debugPrint('[DoorDashAuth] JWT token generated successfully');
      debugPrint('[DoorDashAuth] Token: ${token.substring(0, 50)}...');
      return token;

    } catch (e) {
      debugPrint('[DoorDashAuth] Error generating JWT token: $e');
      rethrow;
    }
  }

  /// Validate JWT token (check if it's expired)
  bool isTokenValid(String token) {
    try {
      // Split token into parts
      final parts = token.split('.');
      if (parts.length != 3) return false;

      // Decode payload (add padding if needed)
      String payloadB64 = parts[1];
      while (payloadB64.length % 4 != 0) {
        payloadB64 += '=';
      }
      
      final payloadJson = utf8.decode(base64Url.decode(payloadB64));
      final payload = jsonDecode(payloadJson) as Map<String, dynamic>;
      
      final exp = payload['exp'] as int;
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      
      return exp > now;
    } catch (e) {
      debugPrint('[DoorDashAuth] Token validation failed: $e');
      return false;
    }
  }

  /// Get authorization header for API requests
  Map<String, String> getAuthHeaders() {
    final token = generateJWTToken();
    
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
      'User-Agent': 'FreshPunk/1.0',
    };
  }

  /// Test the authentication setup
  Future<bool> testAuthentication() async {
    try {
      // Generate a test token
      final token = generateJWTToken();
      
      // Validate the token
      final isValid = isTokenValid(token);
      
      if (isValid) {
        debugPrint('[DoorDashAuth] Authentication test passed');
        return true;
      } else {
        debugPrint('[DoorDashAuth] Authentication test failed - invalid token');
        return false;
      }
    } catch (e) {
      debugPrint('[DoorDashAuth] Authentication test failed: $e');
      return false;
    }
  }

  /// Debug method to print token information (development only)
  void debugToken() {
    if (kDebugMode) {
      try {
        final token = generateJWTToken();
        final parts = token.split('.');
        
        if (parts.length == 3) {
          // Decode header and payload (signature stays encoded)
          final headerJson = utf8.decode(base64Url.decode(base64Url.normalize(parts[0])));
          final payloadJson = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
          
          debugPrint('=== JWT Token Debug ===');
          debugPrint('Header: $headerJson');
          debugPrint('Payload: $payloadJson');
          debugPrint('Token Length: ${token.length}');
          debugPrint('Valid: ${isTokenValid(token)}');
          debugPrint('======================');
        }
      } catch (e) {
        debugPrint('[DoorDashAuth] Debug token failed: $e');
      }
    }
  }
}
import 'dart:convert';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:flutter/foundation.dart';
import '../../config/doordash_config.dart';

/// JWT Authentication Service for DoorDash API
/// Generates and manages JWT tokens for secure API communication
class DoorDashAuthService {
  DoorDashAuthService._();
  static final DoorDashAuthService instance = DoorDashAuthService._();

  /// Generate JWT token for DoorDash API authentication
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
      final expiry = now.add(const Duration(hours: 1)); // Token expires in 1 hour
      
      final payload = {
        'aud': 'doordash',
        'iss': DoorDashConfig.developerId,
        'kid': DoorDashConfig.keyId,
        'exp': expiry.millisecondsSinceEpoch ~/ 1000,
        'iat': now.millisecondsSinceEpoch ~/ 1000,
      };

      // Create and sign JWT
      final jwt = JWT(
        payload,
        header: header,
      );

      // Sign with the signing secret (DoorDash uses HMAC-SHA256 with base64 secret)
      final token = jwt.sign(
        SecretKey(DoorDashConfig.signingKey),
        algorithm: JWTAlgorithm.HS256,
      );

      debugPrint('[DoorDashAuth] JWT token generated successfully');
      return token;

    } catch (e) {
      debugPrint('[DoorDashAuth] Error generating JWT token: $e');
      rethrow;
    }
  }

  /// Validate JWT token (check if it's expired)
  bool isTokenValid(String token) {
    try {
      final jwt = JWT.verify(token, SecretKey(DoorDashConfig.signingKey));
      final exp = jwt.payload['exp'] as int;
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
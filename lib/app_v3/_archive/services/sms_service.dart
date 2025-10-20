import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'environment_service.dart';

/// Twilio SMS Service for FreshPunk Food Delivery
/// Handles order confirmations, delivery updates, and notifications
class SMSService {
  static const String _baseUrl = 'https://api.twilio.com/2010-04-01';
  
  SMSService._();
  static final SMSService instance = SMSService._();

  // Get credentials from environment service
  static String get _accountSid => EnvironmentService.twilioAccountSid;
  static String get _authToken => EnvironmentService.twilioAuthToken;
  static String get _fromNumber => EnvironmentService.twilioPhoneNumber;
  
  /// Check if SMS service is properly configured
  static bool get isConfigured => EnvironmentService.isTwilioConfigured;

  /// Send order confirmation SMS
  static Future<bool> sendOrderConfirmation({
    required String toNumber,
    required String orderNumber,
    required String customerName,
    required String estimatedTime,
    required List<String> items,
  }) async {
    final itemsList = items.take(3).join(', ');
    final moreItems = items.length > 3 ? ' +${items.length - 3} more' : '';
    
    final message = '''
🍽️ Order Confirmed! #$orderNumber

Hi $customerName! Your FreshPunk order is being prepared:
$itemsList$moreItems

📦 Estimated delivery: $estimatedTime
📱 Track your order in the app!

Thanks for choosing FreshPunk! 🌟
    ''';
    
    return await _sendSMS(toNumber, message);
  }

  /// Send delivery status update
  static Future<bool> sendDeliveryUpdate({
    required String toNumber,
    required String orderNumber,
    required String status,
    required String? eta,
    required String? driverName,
  }) async {
    String message = '📦 Order Update #$orderNumber\n\n';
    
    switch (status.toLowerCase()) {
      case 'preparing':
        message += '👨‍🍳 Your meal is being prepared!\nETA: $eta';
        break;
      case 'ready':
        message += '✅ Your order is ready for pickup!';
        break;
      case 'out_for_delivery':
        message += '🚗 Out for delivery!';
        if (driverName != null) {
          message += '\nDriver: $driverName';
        }
        if (eta != null) {
          message += '\nETA: $eta';
        }
        break;
      case 'nearby':
        message += '📍 Driver is nearby!\nETA: 2-5 minutes';
        break;
      case 'delivered':
        message += '🎉 Order delivered!\nEnjoy your FreshPunk meal!';
        break;
      default:
        message += 'Status: $status';
        if (eta != null) {
          message += '\nETA: $eta';
        }
    }
    
    message += '\n\n📱 Open the app for real-time tracking';
    
    return await _sendSMS(toNumber, message);
  }

  /// Send driver arrival notification
  static Future<bool> sendDriverArrival({
    required String toNumber,
    required String orderNumber,
    required String driverName,
    required String? driverPhone,
  }) async {
    String message = '''
🚗 Driver Arrived! #$orderNumber

$driverName is here with your FreshPunk order!
    ''';
    
    if (driverPhone != null) {
      message += '\n📞 Contact driver: $driverPhone';
    }
    
    message += '''

Please come outside or be ready at your door.
Thank you! 🌟
    ''';
    
    return await _sendSMS(toNumber, message);
  }

  /// Send subscription reminder
  static Future<bool> sendSubscriptionReminder({
    required String toNumber,
    required String customerName,
    required String nextDeliveryDate,
    required String planName,
  }) async {
    final message = '''
🔔 FreshPunk Reminder

Hi $customerName! Your $planName delivery is scheduled for $nextDeliveryDate.

📱 Modify your meals or skip delivery in the app.

Questions? Reply to this message!
    ''';
    
    return await _sendSMS(toNumber, message);
  }

  /// Send promotional SMS
  static Future<bool> sendPromotion({
    required String toNumber,
    required String customerName,
    required String promoCode,
    required String discount,
    required String expiryDate,
  }) async {
    final message = '''
🎉 Special Offer for $customerName!

Get $discount off your next FreshPunk order!

Code: $promoCode
Expires: $expiryDate

📱 Order now in the app!
    ''';
    
    return await _sendSMS(toNumber, message);
  }

  /// Core SMS sending function
  static Future<bool> _sendSMS(String toNumber, String message) async {
    try {
      // Validate configuration
      if (_accountSid == 'YOUR_TWILIO_ACCOUNT_SID' || 
          _authToken == 'YOUR_TWILIO_AUTH_TOKEN' ||
          _fromNumber == '+1234567890') {
        debugPrint('[SMS] Twilio credentials not configured. SMS not sent.');
        if (kDebugMode) {
          debugPrint('[SMS] Would send to $toNumber:\n$message');
        }
        return false;
      }

      // Clean phone number
      final cleanToNumber = _cleanPhoneNumber(toNumber);
      if (cleanToNumber == null) {
        debugPrint('[SMS] Invalid phone number: $toNumber');
        return false;
      }

      // Prepare Twilio API request
      final url = Uri.parse('$_baseUrl/Accounts/$_accountSid/Messages.json');
      final credentials = base64Encode(utf8.encode('$_accountSid:$_authToken'));
      
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Basic $credentials',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'From': _fromNumber,
          'To': cleanToNumber,
          'Body': message,
        },
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        final sid = data['sid'];
        debugPrint('[SMS] Message sent successfully. SID: $sid');
        return true;
      } else {
        debugPrint('[SMS] Failed to send. Status: ${response.statusCode}');
        debugPrint('[SMS] Response: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('[SMS] Exception sending SMS: $e');
      return false;
    }
  }

  /// Clean and validate phone number
  static String? _cleanPhoneNumber(String phoneNumber) {
    // Remove all non-digit characters
    final digits = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    
    // US phone number validation
    if (digits.length == 10) {
      return '+1$digits'; // Add US country code
    } else if (digits.length == 11 && digits.startsWith('1')) {
      return '+$digits'; // Already has country code
    } else if (digits.length >= 10 && digits.startsWith('+')) {
      return phoneNumber; // International format
    }
    
    return null; // Invalid
  }

  /// Test SMS functionality
  static Future<bool> sendTestSMS(String toNumber) async {
    final message = '''
🧪 FreshPunk Test Message

This is a test from your food delivery app!
SMS integration is working correctly. 🎉

Time: ${DateTime.now().toString()}
    ''';
    
    return await _sendSMS(toNumber, message);
  }
}

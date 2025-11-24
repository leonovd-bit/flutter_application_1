import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../theme/app_theme_v3.dart';
import '../../services/auth/phone_verification_service.dart';

/// Phone Verification Dialog
/// 
/// Two-step dialog for phone number verification:
/// 1. Phone number entry
/// 2. SMS code entry
class PhoneVerificationDialog extends StatefulWidget {
  /// Called when phone is successfully verified
  /// Provides the verified phone number and credential
  final Function(String phoneNumber, PhoneAuthCredential credential)? onPhoneVerified;
  
  /// Called if user cancels the dialog
  final VoidCallback? onCancel;

  const PhoneVerificationDialog({
    super.key,
    this.onPhoneVerified,
    this.onCancel,
  });

  @override
  State<PhoneVerificationDialog> createState() => _PhoneVerificationDialogState();
}

class _PhoneVerificationDialogState extends State<PhoneVerificationDialog> {
  final _phoneVerificationService = PhoneVerificationService.instance;
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();

  bool _isLoading = false;
  bool _showCodeEntry = false;
  String _errorMessage = '';

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  /// Format phone number to E.164 format
  /// Converts: 555-123-4567 → +1-555-123-4567
  /// or: 5551234567 → +1-5551234567
  String _formatPhoneNumber(String input) {
    // Remove all non-digits
    final digitsOnly = input.replaceAll(RegExp(r'\D'), '');
    
    // Add +1 for US numbers (assuming US is the default)
    // In production, you might want to auto-detect country code
    if (digitsOnly.length == 10) {
      return '+1$digitsOnly'; // US: +1XXXXXXXXXX
    } else if (digitsOnly.length == 11 && digitsOnly.startsWith('1')) {
      return '+$digitsOnly'; // Already has 1
    } else if (digitsOnly.startsWith('1') && digitsOnly.length == 11) {
      return '+$digitsOnly';
    } else {
      // Assume +1 for 10 digit numbers
      return '+1$digitsOnly';
    }
  }

  /// Validate phone number format
  bool _isValidPhone(String phone) {
    final digitsOnly = phone.replaceAll(RegExp(r'\D'), '');
    return digitsOnly.length >= 10 && digitsOnly.length <= 15;
  }

  /// Start phone verification
  Future<void> _startPhoneVerification() async {
    final phone = _phoneController.text.trim();

    // Validate
    if (phone.isEmpty) {
      setState(() => _errorMessage = 'Please enter your phone number');
      return;
    }

    if (!_isValidPhone(phone)) {
      setState(() => _errorMessage = 'Please enter a valid phone number');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final formattedPhone = _formatPhoneNumber(phone);
      
      await _phoneVerificationService.startPhoneVerification(formattedPhone);
      
      // If no error, code was sent - show code entry
      if (mounted) {
        setState(() {
          _isLoading = false;
          _showCodeEntry = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  /// Verify the SMS code
  Future<void> _verifyCode() async {
    final code = _codeController.text.trim();

    // Validate
    if (code.isEmpty) {
      setState(() => _errorMessage = 'Please enter the verification code');
      return;
    }

    if (code.length != 6 || !RegExp(r'^[0-9]+$').hasMatch(code)) {
      setState(() => _errorMessage = 'Code must be 6 digits');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final credential = await _phoneVerificationService.verifyCode(code);
      
      if (mounted) {
        setState(() => _isLoading = false);
        
        // Callback with verified phone
        widget.onPhoneVerified?.call(
          _phoneVerificationService.currentPhoneNumber ?? '',
          credential,
        );
        
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Invalid code. Please try again.';
        });
      }
    }
  }

  /// Go back to phone entry
  void _backToPhoneEntry() {
    setState(() {
      _showCodeEntry = false;
      _errorMessage = '';
      _codeController.clear();
      _phoneVerificationService.cancelVerification();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  _showCodeEntry ? Icons.security : Icons.phone,
                  color: AppThemeV3.primaryGreen,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _showCodeEntry ? 'Enter Verification Code' : 'Verify Your Phone Number',
                    style: AppThemeV3.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Description
            Text(
              _showCodeEntry
                  ? 'We sent a 6-digit code to ${_phoneVerificationService.currentPhoneNumber}'
                  : 'Enter your phone number to verify your account',
              style: AppThemeV3.textTheme.bodySmall?.copyWith(
                color: AppThemeV3.textSecondary,
              ),
            ),
            const SizedBox(height: 24),

            // Phone or Code Entry
            if (!_showCodeEntry) ...[
              // Phone number input
              TextField(
                controller: _phoneController,
                enabled: !_isLoading,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  hintText: '(555) 123-4567',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.phone),
                  errorText: _errorMessage.isNotEmpty ? _errorMessage : null,
                ),
              ),
            ] else ...[
              // Verification code input
              TextField(
                controller: _codeController,
                enabled: !_isLoading,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 8,
                ),
                decoration: InputDecoration(
                  labelText: 'Verification Code',
                  hintText: '000000',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  counterText: '', // Hide character counter
                  errorText: _errorMessage.isNotEmpty ? _errorMessage : null,
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Action Buttons
            if (!_showCodeEntry) ...[
              // Send Code Button
              ElevatedButton(
                onPressed: _isLoading ? null : _startPhoneVerification,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppThemeV3.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  disabledBackgroundColor: Colors.grey[300],
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Send Verification Code',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
              ),
            ] else ...[
              // Verify Code Button
              ElevatedButton(
                onPressed: _isLoading ? null : _verifyCode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppThemeV3.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  disabledBackgroundColor: Colors.grey[300],
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Verify Code',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _isLoading ? null : _backToPhoneEntry,
                child: const Text('Change Phone Number'),
              ),
            ],

            const SizedBox(height: 8),

            // Cancel Button
            TextButton(
              onPressed: _isLoading
                  ? null
                  : () {
                      widget.onCancel?.call();
                      Navigator.pop(context);
                    },
              child: const Text('Cancel'),
            ),

            // Info Box
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Text(
                _showCodeEntry
                    ? 'Message rates may apply. Reply STOP to opt out.'
                    : 'We\'ll send an SMS code to verify your phone number. Standard rates apply.',
                style: AppThemeV3.textTheme.labelSmall?.copyWith(
                  color: Colors.blue[900],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

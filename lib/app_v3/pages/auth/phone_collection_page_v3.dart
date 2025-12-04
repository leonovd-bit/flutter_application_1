import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme_v3.dart';
import '../../services/auth/phone_verification_service.dart';
import '../../services/auth/progress_manager.dart';
import 'phone_verification_page_v3.dart';

/// Page to collect phone number from users who signed up with Google/Apple
class PhoneCollectionPageV3 extends StatefulWidget {
  const PhoneCollectionPageV3({super.key});

  @override
  State<PhoneCollectionPageV3> createState() => _PhoneCollectionPageV3State();
}

class _PhoneCollectionPageV3State extends State<PhoneCollectionPageV3> {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number is required';
    }
    
    final digitsOnly = value.replaceAll(RegExp(r'\D'), '');
    
    if (digitsOnly.length != 10) {
      return 'Please enter a 10-digit phone number';
    }
    
    return null;
  }

  Future<void> _continue() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Format phone number to E.164 format
      final digits = _phoneController.text.replaceAll(RegExp(r'\D'), '');
      final phoneNumber = '+1$digits'; // Assuming US phone numbers

      // Save phone number and update progress
      await ProgressManager.saveCurrentStep(OnboardingStep.phoneVerification);
      await ProgressManager.saveSignupProgress(phone: phoneNumber);

      // Start phone verification
      await PhoneVerificationService.instance.startPhoneVerification(phoneNumber);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => PhoneVerificationPageV3(
              phoneNumber: phoneNumber,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Phone verification start error: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send verification SMS: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeV3.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppThemeV3.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                
                // Title
                Text(
                  'Verify your phone',
                  style: AppThemeV3.textTheme.displayMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppThemeV3.textPrimary,
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Description
                Text(
                  'We need your phone number to send delivery updates and verify your account.',
                  style: AppThemeV3.textTheme.bodyLarge?.copyWith(
                    color: AppThemeV3.textSecondary,
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // Phone number field
                Text(
                  'Phone Number',
                  style: AppThemeV3.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppThemeV3.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  autofocus: true,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                    _PhoneNumberFormatter(),
                  ],
                  decoration: InputDecoration(
                    hintText: '(555) 123-4567',
                    prefixIcon: const Icon(Icons.phone),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppThemeV3.border, width: 2),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppThemeV3.border, width: 2),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppThemeV3.accent, width: 2),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.red, width: 2),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.red, width: 2),
                    ),
                  ),
                  validator: _validatePhone,
                ),
                
                const SizedBox(height: 32),
                
                // Info box
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.blue.shade700,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'We\'ll send you a 6-digit code to verify this number.',
                          style: AppThemeV3.textTheme.bodyMedium?.copyWith(
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // Continue button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _continue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Colors.black, width: 2),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            'Continue',
                            style: AppThemeV3.textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Formats phone number as (XXX) XXX-XXXX
class _PhoneNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    final digitsOnly = text.replaceAll(RegExp(r'\D'), '');
    
    if (digitsOnly.isEmpty) {
      return newValue.copyWith(text: '');
    }
    
    final buffer = StringBuffer();
    
    for (int i = 0; i < digitsOnly.length && i < 10; i++) {
      if (i == 0) {
        buffer.write('(');
      }
      if (i == 3) {
        buffer.write(') ');
      }
      if (i == 6) {
        buffer.write('-');
      }
      buffer.write(digitsOnly[i]);
    }
    
    final formatted = buffer.toString();
    
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

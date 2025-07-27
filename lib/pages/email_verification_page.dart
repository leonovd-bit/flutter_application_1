import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'add_address_page.dart';

class EmailVerificationPage extends StatefulWidget {
  final String email;
  
  const EmailVerificationPage({
    super.key,
    required this.email,
  });

  @override
  State<EmailVerificationPage> createState() => _EmailVerificationPageState();
}

class _EmailVerificationPageState extends State<EmailVerificationPage> {
  final List<TextEditingController> _controllers = List.generate(6, (index) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());
  String? _errorMessage;
  bool _isVerifying = false;
  bool _canResend = true;
  int _resendCooldown = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Auto-focus first field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var focusNode in _focusNodes) {
      focusNode.dispose();
    }
    _timer?.cancel();
    super.dispose();
  }

  void _onDigitChanged(int index, String value) {
    setState(() {
      _errorMessage = null;
    });

    if (value.isNotEmpty && index < 5) {
      // Move to next field
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      // Move to previous field
      _focusNodes[index - 1].requestFocus();
    }

    // Check if all fields are filled
    final code = _controllers.map((c) => c.text).join();
    if (code.length == 6) {
      // All digits entered, but don't auto-verify
      _focusNodes[index].unfocus();
    }
  }

  String _getCode() {
    return _controllers.map((c) => c.text).join();
  }

  bool _isCodeComplete() {
    return _getCode().length == 6;
  }

  Future<void> _verifyCode() async {
    if (!_isCodeComplete()) {
      setState(() {
        _errorMessage = 'Please enter the complete 6-digit code';
      });
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      // Check if user is already verified
      await FirebaseAuth.instance.currentUser?.reload();
      final user = FirebaseAuth.instance.currentUser;
      
      if (user?.emailVerified == true) {
        // Email is verified, navigate to next page
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const AddAddressPage(isSignupFlow: true),
            ),
          );
        }
      } else {
        setState(() {
          _errorMessage = 'Invalid verification code. Please try again.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred. Please try again.';
      });
    } finally {
      setState(() {
        _isVerifying = false;
      });
    }
  }

  void _skipVerification() {
    // For web testing, allow skipping email verification
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const AddAddressPage(isSignupFlow: true),
        ),
      );
    }
  }

  Future<void> _resendCode() async {
    if (!_canResend) return;

    try {
      await FirebaseAuth.instance.currentUser?.sendEmailVerification();
      
      setState(() {
        _canResend = false;
        _resendCooldown = 30;
      });

      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _resendCooldown--;
        });

        if (_resendCooldown <= 0) {
          setState(() {
            _canResend = true;
          });
          timer.cancel();
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification code sent to your email'),
            backgroundColor: Color(0xFF2D5A2D),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to resend code. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Verify code',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              
              // Description
              Text(
                'The confirmation code was sent via email to ${widget.email}',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 40),
              
              // Code input fields
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(6, (index) {
                  return SizedBox(
                    width: 45,
                    height: 60,
                    child: TextField(
                      controller: _controllers[index],
                      focusNode: _focusNodes[index],
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      maxLength: 1,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: _errorMessage != null ? Colors.red : Colors.grey[300]!,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: _errorMessage != null ? Colors.red : Colors.grey[300]!,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: _errorMessage != null ? Colors.red : const Color(0xFF2D5A2D),
                          ),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.red),
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onChanged: (value) {
                        // Only allow digits
                        if (value.isNotEmpty && !RegExp(r'^[0-9]$').hasMatch(value)) {
                          _controllers[index].clear();
                          return;
                        }
                        _onDigitChanged(index, value);
                      },
                    ),
                  );
                }),
              ),
              
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              
              const SizedBox(height: 40),
              
              // Resend code
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Don't get the code? ",
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                  TextButton(
                    onPressed: _canResend ? _resendCode : null,
                    child: Text(
                      _canResend ? 'Resend code' : 'Resend in ${_resendCooldown}s',
                      style: TextStyle(
                        color: _canResend ? const Color(0xFF2D5A2D) : Colors.grey,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              
              const Spacer(),
              
              // Skip button (for web testing)
              if (kIsWeb)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: TextButton(
                    onPressed: _skipVerification,
                    child: const Text(
                      'Skip for now (Testing)',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              
              // Verify button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isCodeComplete() && !_isVerifying ? _verifyCode : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isVerifying
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Verify now',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

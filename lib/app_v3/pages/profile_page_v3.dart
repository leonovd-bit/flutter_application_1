import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Image picker is optional; if not available, stub the picker.
// ignore: uri_does_not_exist
// image_picker is temporarily disabled to unblock Android builds.
// The _pickImage method will act as a no-op stub until re-enabled.
import '../theme/app_theme_v3.dart';
import '../services/auth/firestore_service_v3.dart';
import 'dart:io';

import '../models/mock_user_model.dart';

class ProfilePageV3 extends StatefulWidget {
  final MockUser? mockUser;
  const ProfilePageV3({super.key, this.mockUser});

  @override
  State<ProfilePageV3> createState() => _ProfilePageV3State();
}

class _ProfilePageV3State extends State<ProfilePageV3> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _backupEmailController = TextEditingController();
  final _phoneController = TextEditingController();
  
  bool _isLoading = true;
  bool _isSaving = false;
  File? _selectedImage;
  String? _profileImageUrl;
  
  User? _currentUser;
  MockUser? _mockUser;
  Map<String, dynamic>? _userProfile;

  @override
  void initState() {
    super.initState();
    _mockUser = widget.mockUser;
    _loadUserProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
  _backupEmailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    try {
      if (_mockUser != null) {
        // Design mode: use mock user
        setState(() {
          _nameController.text = _mockUser!.displayName;
          _emailController.text = _mockUser!.email;
          _profileImageUrl = _mockUser!.photoUrl;
          _isLoading = false;
        });
        return;
      }
      _currentUser = FirebaseAuth.instance.currentUser;
      if (_currentUser != null) {
        _userProfile = await FirestoreServiceV3.getUserProfile(_currentUser!.uid);
        if (!mounted) return;
        setState(() {
          _nameController.text = _userProfile?['fullName'] ?? _currentUser!.displayName ?? '';
          _emailController.text = _currentUser!.email ?? '';
          _phoneController.text = _userProfile?['phoneNumber'] ?? '';
          _backupEmailController.text = (_userProfile?['backupEmail'] ?? '') as String;
          _profileImageUrl = _userProfile?['profileImageUrl'];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      _showSnackBar('Error loading profile: $e');
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      // Update Firebase Auth display name
      await _currentUser?.updateDisplayName(_nameController.text.trim());

      // Update Firestore profile
      final profileData = {
        'fullName': _nameController.text.trim(),
        'phoneNumber': _phoneController.text.trim(),
  'backupEmail': _backupEmailController.text.trim().isEmpty ? null : _backupEmailController.text.trim(),
      };

      if (_selectedImage != null) {
        // TODO: Upload image to Firebase Storage and get URL
        // profileData['profileImageUrl'] = uploadedImageUrl;
      }

  await FirestoreServiceV3.updateUserProfile(_currentUser!.uid, profileData);
  
  if (!mounted) return;
  _showSnackBar('Profile updated successfully');
  Navigator.pop(context);
    } catch (e) {
      _showSnackBar('Error updating profile: $e');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _promptChangeEmail() async {
    final emailController = TextEditingController(text: _currentUser?.email ?? '');
    final passController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Change Email'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'New Email'),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Enter an email';
                    final ok = RegExp(r'^.+@.+\..+').hasMatch(v.trim());
                    return ok ? null : 'Enter a valid email';
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: passController,
                  decoration: const InputDecoration(labelText: 'Current Password'),
                  obscureText: true,
                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                if (formKey.currentState!.validate()) Navigator.pop(context, true);
              },
              child: const Text('Update'),
            ),
          ],
        );
      },
    );
    if (result != true) return;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not signed in');
      // Re-authenticate
      final cred = EmailAuthProvider.credential(email: user.email ?? '', password: passController.text);
      await user.reauthenticateWithCredential(cred);
      // Use verifyBeforeUpdateEmail so the email only changes after the user clicks the link
      await user.verifyBeforeUpdateEmail(emailController.text.trim());
      if (mounted) {
        // Do not set the email controller to the new email yet; backend updates after verification
        setState(() => _emailController.text = user.email ?? _emailController.text);
        _showSnackBar('Verification sent. Check your new email to confirm the change.');
      }
    } catch (e) {
      _showSnackBar('Failed to update email: $e');
    }
  }

  Future<void> _pickImage() async {
    // No-op while image_picker is disabled; keep UI responsive
    _showSnackBar('Image picker not available in this build.');
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppThemeV3.background,
        appBar: AppBar(
          backgroundColor: AppThemeV3.background,
          elevation: 0,
          title: Text(
            'Profile Information',
            style: AppThemeV3.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppThemeV3.background,
      appBar: AppBar(
        backgroundColor: AppThemeV3.background,
        elevation: 0,
        title: Text(
          'Profile Information',
          style: AppThemeV3.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveProfile,
            child: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    'Save',
                    style: TextStyle(
                      color: AppThemeV3.accent,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Profile Picture Section
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: AppThemeV3.accent.withValues(alpha: 0.1),
                      backgroundImage: _selectedImage != null
                          ? FileImage(_selectedImage!)
                          : _profileImageUrl != null
                              ? NetworkImage(_profileImageUrl!) as ImageProvider
                              : null,
                      child: _selectedImage == null && _profileImageUrl == null
                          ? Icon(
                              Icons.person,
                              size: 60,
                              color: AppThemeV3.accent.withValues(alpha: 0.5),
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppThemeV3.accent,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // Full Name Field
              _buildFormField(
                controller: _nameController,
                label: 'Full Name',
                icon: Icons.person_outline,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your full name';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 20),

              // Email Field (Read-only)
              _buildFormField(
                controller: _emailController,
                label: 'Email Address',
                icon: Icons.email_outlined,
                readOnly: true,
                hint: 'Email cannot be changed',
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _promptChangeEmail,
                  icon: const Icon(Icons.alternate_email),
                  label: const Text('Change Email'),
                ),
              ),

              const SizedBox(height: 20),

              // Backup Email Field
              _buildFormField(
                controller: _backupEmailController,
                label: 'Backup Email (optional)',
                icon: Icons.mark_email_read_outlined,
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return null;
                  final ok = RegExp(r'^.+@.+\..+').hasMatch(value.trim());
                  return ok ? null : 'Enter a valid email';
                },
              ),

              const SizedBox(height: 20),

              // Phone Number Field
              _buildFormField(
                controller: _phoneController,
                label: 'Phone Number',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    if (!RegExp(r'^\+?[\d\s\-\(\)]+$').hasMatch(value)) {
                      return 'Please enter a valid phone number';
                    }
                  }
                  return null;
                },
              ),

              const SizedBox(height: 40),

              // Account Information Section
              _buildInfoSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool readOnly = false,
    String? hint,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppThemeV3.surface,
            AppThemeV3.surface.withValues(alpha: 0.95),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppThemeV3.accent.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        readOnly: readOnly,
        keyboardType: keyboardType,
        validator: validator,
        style: AppThemeV3.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: AppThemeV3.accent),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(20),
          labelStyle: AppThemeV3.textTheme.bodyMedium?.copyWith(
            color: readOnly ? AppThemeV3.textSecondary : AppThemeV3.textPrimary,
            fontWeight: FontWeight.w600,
          ),
          hintStyle: AppThemeV3.textTheme.bodySmall?.copyWith(
            color: AppThemeV3.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildInfoSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppThemeV3.surface,
            AppThemeV3.surface.withValues(alpha: 0.95),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppThemeV3.accent.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Account Information',
            style: AppThemeV3.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppThemeV3.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoRow('User ID', _currentUser?.uid ?? 'N/A'),
          _buildInfoRow('Email Verified', _currentUser?.emailVerified == true ? 'Yes' : 'No'),
          _buildInfoRow('Account Created', _formatDate(_currentUser?.metadata.creationTime)),
          _buildInfoRow('Last Sign In', _formatDate(_currentUser?.metadata.lastSignInTime)),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppThemeV3.textTheme.bodyMedium?.copyWith(
              color: AppThemeV3.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: AppThemeV3.textTheme.bodyMedium?.copyWith(
                color: AppThemeV3.textPrimary,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return '${date.day}/${date.month}/${date.year}';
  }
}

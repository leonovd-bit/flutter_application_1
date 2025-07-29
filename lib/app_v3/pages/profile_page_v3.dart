import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme_v3.dart';
import '../services/firestore_service_v3.dart';
import 'dart:io';

class ProfilePageV3 extends StatefulWidget {
  const ProfilePageV3({super.key});

  @override
  State<ProfilePageV3> createState() => _ProfilePageV3State();
}

class _ProfilePageV3State extends State<ProfilePageV3> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  
  bool _isLoading = true;
  bool _isSaving = false;
  File? _selectedImage;
  String? _profileImageUrl;
  
  User? _currentUser;
  Map<String, dynamic>? _userProfile;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    try {
      _currentUser = FirebaseAuth.instance.currentUser;
      if (_currentUser != null) {
        _userProfile = await FirestoreServiceV3.getUserProfile(_currentUser!.uid);
        
        setState(() {
          _nameController.text = _userProfile?['fullName'] ?? _currentUser!.displayName ?? '';
          _emailController.text = _currentUser!.email ?? '';
          _phoneController.text = _userProfile?['phoneNumber'] ?? '';
          _profileImageUrl = _userProfile?['profileImageUrl'];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
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
      };

      if (_selectedImage != null) {
        // TODO: Upload image to Firebase Storage and get URL
        // profileData['profileImageUrl'] = uploadedImageUrl;
      }

      await FirestoreServiceV3.updateUserProfile(_currentUser!.uid, profileData);

      _showSnackBar('Profile updated successfully');
      Navigator.pop(context);
    } catch (e) {
      _showSnackBar('Error updating profile: $e');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
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
                      backgroundColor: AppThemeV3.accent.withOpacity(0.1),
                      backgroundImage: _selectedImage != null
                          ? FileImage(_selectedImage!)
                          : _profileImageUrl != null
                              ? NetworkImage(_profileImageUrl!) as ImageProvider
                              : null,
                      child: _selectedImage == null && _profileImageUrl == null
                          ? Icon(
                              Icons.person,
                              size: 60,
                              color: AppThemeV3.accent.withOpacity(0.5),
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
                                color: Colors.black.withOpacity(0.2),
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
            AppThemeV3.surface.withOpacity(0.95),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppThemeV3.accent.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
            AppThemeV3.surface.withOpacity(0.95),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppThemeV3.accent.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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

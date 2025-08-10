import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../theme/app_theme_v3.dart';
import '../models/meal_model_v3.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service_v3.dart';

class AddressPageV3 extends StatefulWidget {
  const AddressPageV3({super.key});

  @override
  State<AddressPageV3> createState() => _AddressPageV3State();
}

class _AddressPageV3State extends State<AddressPageV3> {
  final _formKey = GlobalKey<FormState>();
  final _labelController = TextEditingController();
  final _streetController = TextEditingController();
  final _apartmentController = TextEditingController();
  final _zipController = TextEditingController();
  
  String _selectedCity = 'New York City';
  String _selectedState = 'New York';
  
  final List<String> _cities = [
    'New York City',
    'Albany',
    'Buffalo',
    'Rochester',
    'Syracuse',
  ];
  
  final List<String> _states = [
    'New York',
    'New Jersey',
    'Connecticut',
    'Pennsylvania',
    'Massachusetts',
  ];
  
  List<AddressModelV3> _savedAddresses = [];
  bool _editMode = false;
  String? _editingId;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadSavedAddresses();
  }

  void _loadSavedAddresses() {
    // Prefer Firestore when available; fall back to SharedPreferences.
    _loadAddressesPreferFirestore();
  }
  
  Future<void> _loadAddressesPreferFirestore() async {
    setState(() => _loading = true);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        final fromFs = await FirestoreServiceV3.getUserAddresses(uid);
        setState(() {
          _savedAddresses = fromFs;
          _loading = false;
        });
        // ignore: avoid_print
        print('[AddressPage] Loaded ${_savedAddresses.length} addresses from Firestore');
        return;
      } catch (e) {
        // fall through to local
        // ignore: avoid_print
        print('[AddressPage] Firestore load failed, falling back to local. Error: $e');
      }
    }
    await _loadUserCreatedAddresses();
    if (mounted) setState(() => _loading = false);
    // ignore: avoid_print
    print('[AddressPage] Loaded ${_savedAddresses.length} addresses from local');
  }
  
  Future<void> _loadUserCreatedAddresses() async {
    // Load user-created addresses from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final addressList = prefs.getStringList('user_addresses') ?? [];
    
    _savedAddresses.clear();
    for (String addressJson in addressList) {
      try {
        final addressData = json.decode(addressJson);
        _savedAddresses.add(AddressModelV3(
          id: addressData['id'],
          userId: addressData['userId'],
          label: addressData['label'],
          streetAddress: addressData['streetAddress'],
          apartment: addressData['apartment'],
          city: addressData['city'],
          state: addressData['state'],
          zipCode: addressData['zipCode'],
          isDefault: addressData['isDefault'] ?? false,
        ));
      } catch (e) {
        print('Error parsing address: $e');
      }
    }
    
    setState(() {});
  }

  @override
  void dispose() {
    _labelController.dispose();
    _streetController.dispose();
    _apartmentController.dispose();
    _zipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeV3.background,
      appBar: AppBar(
        backgroundColor: AppThemeV3.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Select Address',
          style: AppThemeV3.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          if (_savedAddresses.isNotEmpty)
            IconButton(
              tooltip: _editMode ? 'Done' : 'Edit',
              icon: Icon(_editMode ? Icons.check : Icons.edit),
              onPressed: () => setState(() => _editMode = !_editMode),
            ),
        ],
      ),
  body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
    if (_loading) const LinearProgressIndicator(),
    if (_loading) const SizedBox(height: 16),
            // Saved Addresses Section
            if (_savedAddresses.isNotEmpty) ...[
              Text(
                'Saved Addresses',
                style: AppThemeV3.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              
              // Saved addresses list
              ..._savedAddresses.map((address) => _buildSavedAddressCard(address)),
              
              const SizedBox(height: 32),
            ],
            
            // Add New Address Section
            Text(
              'Add New Address',
              style: AppThemeV3.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            
            // Address form
            Form(
              key: _formKey,
              child: Column(
                children: [
                  // Address label
                  TextFormField(
                    controller: _labelController,
                    decoration: const InputDecoration(
                      hintText: 'Address Label (e.g., Home, Work)',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter an address label';
                      }
                      return null;
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Street address
                  TextFormField(
                    controller: _streetController,
                    decoration: const InputDecoration(
                      hintText: 'Street Address',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter street address';
                      }
                      return null;
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Apartment/Suite (optional)
                  TextFormField(
                    controller: _apartmentController,
                    decoration: const InputDecoration(
                      hintText: 'Apartment, Suite, etc. (Optional)',
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // City dropdown
                  DropdownButtonFormField<String>(
                    value: _selectedCity,
                    decoration: const InputDecoration(
                      hintText: 'City',
                    ),
                    items: _cities.map((city) => DropdownMenuItem(
                      value: city,
                      child: Text(city),
                    )).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedCity = value!;
                      });
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // State dropdown
                  DropdownButtonFormField<String>(
                    value: _selectedState,
                    decoration: const InputDecoration(
                      hintText: 'State',
                    ),
                    items: _states.map((state) => DropdownMenuItem(
                      value: state,
                      child: Text(state),
                    )).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedState = value!;
                      });
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // ZIP Code
                  TextFormField(
                    controller: _zipController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: 'ZIP Code',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter ZIP code';
                      }
                      if (value.length != 5) {
                        return 'ZIP code must be 5 digits';
                      }
                      return null;
                    },
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Save address button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saveNewAddress,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppThemeV3.accent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Save Address',
                        style: AppThemeV3.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSavedAddressCard(AddressModelV3 address) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppThemeV3.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppThemeV3.border),
        boxShadow: AppThemeV3.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _editMode ? null : () => _selectAddress(address),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Address icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppThemeV3.accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    address.label.toLowerCase() == 'home' 
                        ? Icons.home 
                        : address.label.toLowerCase() == 'work'
                            ? Icons.work
                            : Icons.location_on,
                    color: AppThemeV3.accent,
                    size: 20,
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // Address details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            address.label,
                            style: AppThemeV3.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (address.isDefault) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppThemeV3.accent,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Default',
                                style: AppThemeV3.textTheme.bodySmall?.copyWith(
                                  color: Colors.white,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        address.fullAddress,
                        style: AppThemeV3.textTheme.bodyMedium?.copyWith(
                          color: AppThemeV3.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                
                // Right-side actions
                if (_editMode) ...[
                  IconButton(
                    tooltip: 'Edit',
                    icon: const Icon(Icons.edit_location_alt),
                    color: AppThemeV3.accent,
                    onPressed: () => _editExistingAddress(address),
                  ),
                  IconButton(
                    tooltip: 'Delete',
                    icon: const Icon(Icons.delete_outline),
                    color: Colors.redAccent,
                    onPressed: () => _deleteAddress(address),
                  ),
                ] else ...[
                  Icon(
                    Icons.check_circle_outline,
                    color: AppThemeV3.accent,
                    size: 24,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _selectAddress(AddressModelV3 address) {
    // Return both a friendly label and the full address so callers can display the name
    Navigator.pop(context, {
      'label': address.label,
      'fullAddress': address.fullAddress,
    });
  }

  Future<void> _saveNewAddress() async {
    if (!_formKey.currentState!.validate()) return;
  final uid = FirebaseAuth.instance.currentUser?.uid ?? 'local';
  final addressId = _editingId ?? DateTime.now().millisecondsSinceEpoch.toString();
  final newAddress = AddressModelV3(
      id: addressId,
      userId: uid,
      label: _labelController.text.trim(),
      streetAddress: _streetController.text.trim(),
      apartment: _apartmentController.text.trim(),
      city: _selectedCity,
      state: _selectedState,
      zipCode: _zipController.text.trim(),
    );

    // Save/update in SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final addressList = prefs.getStringList('user_addresses') ?? [];
    Map<String, dynamic> toMap(AddressModelV3 a) => {
      'id': a.id,
      'userId': a.userId,
      'label': a.label,
      'streetAddress': a.streetAddress,
      'apartment': a.apartment,
      'city': a.city,
      'state': a.state,
      'zipCode': a.zipCode,
      'isDefault': a.isDefault,
    };
    final existingIndex = addressList.indexWhere((s) {
      try { final d = json.decode(s); return d['id'] == newAddress.id; } catch (_) { return false; }
    });
    if (existingIndex >= 0) {
      addressList[existingIndex] = json.encode(toMap(newAddress));
    } else {
      addressList.add(json.encode(toMap(newAddress)));
    }
    await prefs.setStringList('user_addresses', addressList);

    // Save to Firestore when signed in
    if (uid != 'local') {
      try {
        await FirestoreServiceV3.saveAddress(newAddress);
        // ignore: avoid_print
        print('[AddressPage] Saved address to Firestore: ${newAddress.id}');
      } catch (e) {
        // ignore: avoid_print
        print('[AddressPage] Firestore save failed: $e');
      }
    }

    setState(() {
      final idx = _savedAddresses.indexWhere((a) => a.id == newAddress.id);
      if (idx >= 0) {
        _savedAddresses[idx] = newAddress;
      } else {
        _savedAddresses.add(newAddress);
      }
    });

    // Clear form
    _labelController.clear();
    _streetController.clear();
    _apartmentController.clear();
    _zipController.clear();
    _editingId = null;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(existingIndex >= 0 ? 'Address updated' : 'Address saved successfully'),
        backgroundColor: Colors.green,
      ),
    );

  // Auto-select the new address (return label and full address)
  _selectAddress(newAddress);
  await _loadAddressesPreferFirestore();
  }

  Future<void> _editExistingAddress(AddressModelV3 address) async {
    // Pre-fill form with existing values and scroll to form
    _labelController.text = address.label;
    _streetController.text = address.streetAddress;
    _apartmentController.text = address.apartment;
    _selectedCity = address.city;
    _selectedState = address.state;
    _zipController.text = address.zipCode;
    _editingId = address.id;

    // Replace the saved entry upon save
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Address'),
        content: const Text('Update the fields below and tap Save Address.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
    setState(() => _editMode = false);
  }

  Future<void> _deleteAddress(AddressModelV3 address) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Address'),
        content: Text('Remove "${address.label}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        await FirestoreServiceV3.deleteUserAddress(uid, address.id);
        // ignore: avoid_print
        print('[AddressPage] Deleted address in Firestore: ${address.id}');
      } catch (_) {}
    }
    await _removeAddressFromPrefs(address.id);
    // ignore: avoid_print
    print('[AddressPage] Deleted address locally: ${address.id}');
    setState(() {
      _savedAddresses.removeWhere((a) => a.id == address.id);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Address deleted')),
    );
  }

  Future<void> _removeAddressFromPrefs(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final addressList = prefs.getStringList('user_addresses') ?? [];
    final updated = addressList.where((jsonStr) {
      try {
        final data = json.decode(jsonStr);
        return data['id'] != id;
      } catch (_) {
        return true;
      }
    }).toList();
    await prefs.setStringList('user_addresses', updated);
  }
}

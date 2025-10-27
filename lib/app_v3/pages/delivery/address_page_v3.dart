import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../theme/app_theme_v3.dart';
import '../../models/meal_model_v3.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/mock_user_model.dart';
import '../../services/auth/firestore_service_v3.dart';
import '../../services/maps/simple_google_maps_service.dart';

class AddressPageV3 extends StatefulWidget {
  final MockUser? mockUser;
  const AddressPageV3({super.key, this.mockUser});

  @override
  State<AddressPageV3> createState() => _AddressPageV3State();
}

class _AddressPageV3State extends State<AddressPageV3> {
  MockUser? _mockUser;
  final _formKey = GlobalKey<FormState>();
  final _labelController = TextEditingController();
  final _streetController = TextEditingController();
  final _apartmentController = TextEditingController();
  final _zipController = TextEditingController();
  final _quickLookupController = TextEditingController();
  
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
    _mockUser = widget.mockUser;
    _loadSavedAddresses();
  }

  void _loadSavedAddresses() {
    // Prefer Firestore when available; fall back to SharedPreferences.
    _loadAddressesPreferFirestore();
  }
  
  Future<void> _loadAddressesPreferFirestore() async {
    setState(() => _loading = true);
    final uid = _mockUser?.uid ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        final fromFs = await FirestoreServiceV3.getUserAddresses(uid);
        setState(() {
          _savedAddresses = fromFs;
          _loading = false;
        });
  debugPrint('[AddressPage] Loaded ${_savedAddresses.length} addresses from Firestore');
        return;
      } catch (e) {
  // fall through to local
  debugPrint('[AddressPage] Firestore load failed, falling back to local. Error: $e');
      }
    }
    await _loadUserCreatedAddresses();
    if (mounted) setState(() => _loading = false);
  debugPrint('[AddressPage] Loaded ${_savedAddresses.length} addresses from local');
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
        debugPrint('Error parsing address: $e');
      }
    }
    
    setState(() {});
  }

  String _generateAddressLabel(AddressResult addressResult) {
    // Generate a user-friendly label for an address
    final city = addressResult.city;
    final formattedAddress = addressResult.formattedAddress;
    
    // Extract street from formatted address
    final parts = formattedAddress.split(',');
    if (parts.isNotEmpty) {
      final streetPart = parts.first.trim();
      if (streetPart.isNotEmpty && !streetPart.toLowerCase().contains('unnamed')) {
        return streetPart;
      }
    }
    
    if (city.isNotEmpty) {
      return '$city Address';
    }
    
    return 'New Address';
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
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
            
            // Address validation section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black, width: 2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.search_rounded, size: 20, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Quick Address Lookup',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: -0.5),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Enter your NYC address and we\'ll auto-complete the details',
                    style: TextStyle(fontSize: 14, color: Colors.grey[700], fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 16),
                  
                  // Quick address input
                  TextField(
                    controller: _quickLookupController,
                    decoration: InputDecoration(
                      hintText: 'e.g., 350 5th Ave',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      filled: true,
                      fillColor: Colors.grey[50],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.black, width: 2),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!, width: 2),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.black, width: 2),
                      ),
                      prefixIcon: const Icon(Icons.location_on, color: Colors.black),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.arrow_forward, color: Colors.black),
                        onPressed: () async {
                          if (_quickLookupController.text.isNotEmpty) {
                            await _validateAndFillAddress(_quickLookupController.text);
                          }
                        },
                      ),
                    ),
                    onSubmitted: (value) async {
                      if (value.isNotEmpty) {
                        await _validateAndFillAddress(value);
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Divider
            Row(
              children: [
                const Expanded(child: Divider(color: Colors.black, thickness: 2)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'OR ENTER MANUALLY',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Colors.grey[600],
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const Expanded(child: Divider(color: Colors.black, thickness: 2)),
              ],
            ),
            const SizedBox(height: 24),
            
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
                    color: AppThemeV3.accent.withValues(alpha: 0.1),
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

  /// Convert state abbreviation to full name for dropdown
  String _convertStateAbbreviation(String state) {
    final Map<String, String> stateMap = {
      'NY': 'New York',
      'NJ': 'New Jersey',
      'CT': 'Connecticut',
      'PA': 'Pennsylvania',
      'MA': 'Massachusetts',
    };
    return stateMap[state] ?? state;
  }

  /// Convert city name to match dropdown options
  String _convertCityName(String city) {
    // Handle common variations
    if (city == 'New York' || city == 'NYC' || city == 'Manhattan' || city == 'Brooklyn' || city == 'Queens' || city == 'Bronx' || city == 'Staten Island') {
      return 'New York City';
    }
    return city;
  }

  /// Validate and fill address using Google Maps API
  Future<void> _validateAndFillAddress(String streetAddress) async {
    try {
      debugPrint('[AddressPage] Validating address: "$streetAddress"');
      
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              SizedBox(width: 12),
              Text('Validating address...'),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );
      
      // Add NYC context to the search
      final searchQuery = streetAddress.contains('New York') || streetAddress.contains('NYC')
          ? streetAddress
          : '$streetAddress, New York, NY';
      
      final service = SimpleGoogleMapsService.instance;
      final result = await service.validateAddress(searchQuery);
      
      if (!mounted) return;
      
      if (result != null) {
        debugPrint('[AddressPage] ✅ Address validated: ${result.formattedAddress}');
        
        setState(() {
          _streetController.text = result.street.isNotEmpty ? result.street : streetAddress;
          _selectedCity = result.city.isNotEmpty ? _convertCityName(result.city) : 'New York City';
          _selectedState = result.state.isNotEmpty ? _convertStateAbbreviation(result.state) : 'New York';
          _zipController.text = result.zipCode;
          
          // Generate a label if none exists
          if (_labelController.text.isEmpty) {
            _labelController.text = _generateAddressLabel(result);
          }
          
          // Clear quick lookup
          _quickLookupController.clear();
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✅ Address validated and form filled!'),
            backgroundColor: Colors.green[700],
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        debugPrint('[AddressPage] ⚠️ Address validation failed');
        
        // Fill with defaults
        setState(() {
          _streetController.text = streetAddress;
          _selectedCity = 'New York City';
          _selectedState = 'New York';
          
          if (_labelController.text.isEmpty) {
            _labelController.text = 'Address';
          }
          
          _quickLookupController.clear();
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('⚠️ Could not validate address. Please verify manually.'),
            backgroundColor: Colors.orange[700],
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('[AddressPage] ❌ Error validating address: $e');
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red[700],
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _saveNewAddress() async {
    if (!_formKey.currentState!.validate()) return;
  final uid = _mockUser?.uid ?? FirebaseAuth.instance.currentUser?.uid ?? 'local';
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
  debugPrint('[AddressPage] Saved address to Firestore: ${newAddress.id}');
      } catch (e) {
  debugPrint('[AddressPage] Firestore save failed: $e');
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

  if (!mounted) return;
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
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Address'),
        content: const Text('Update the fields below and tap Save Address.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('OK')),
        ],
      ),
    );
    setState(() => _editMode = false);
  }

  Future<void> _deleteAddress(AddressModelV3 address) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Address'),
        content: Text('Remove "${address.label}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;

  final uid = _mockUser?.uid ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        await FirestoreServiceV3.deleteUserAddress(uid, address.id);
  debugPrint('[AddressPage] Deleted address in Firestore: ${address.id}');
      } catch (_) {}
    }
    await _removeAddressFromPrefs(address.id);
  debugPrint('[AddressPage] Deleted address locally: ${address.id}');
    setState(() {
      _savedAddresses.removeWhere((a) => a.id == address.id);
    });
  if (!mounted) return;
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

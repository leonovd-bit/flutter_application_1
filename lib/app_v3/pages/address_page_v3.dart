import 'package:flutter/material.dart';
import '../theme/app_theme_v3.dart';
import '../models/meal_model_v3.dart';

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

  @override
  void initState() {
    super.initState();
    _loadSavedAddresses();
  }

  void _loadSavedAddresses() {
    // Mock saved addresses - in real app, load from Firebase
    _savedAddresses = [
      AddressModelV3(
        id: '1',
        userId: 'user1',
        label: 'Home',
        streetAddress: '123 Main Street',
        apartment: 'Apt 4B',
        city: 'New York City',
        state: 'New York',
        zipCode: '10001',
        isDefault: true,
      ),
      AddressModelV3(
        id: '2',
        userId: 'user1',
        label: 'Work',
        streetAddress: '456 Broadway',
        city: 'New York City',
        state: 'New York',
        zipCode: '10013',
      ),
    ];
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
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
          onTap: () => _selectAddress(address),
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
                
                // Select button
                Icon(
                  Icons.check_circle_outline,
                  color: AppThemeV3.accent,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _selectAddress(AddressModelV3 address) {
    Navigator.pop(context, address.fullAddress);
  }

  void _saveNewAddress() {
    if (!_formKey.currentState!.validate()) return;

    final newAddress = AddressModelV3(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: 'user1', // Replace with actual user ID
      label: _labelController.text.trim(),
      streetAddress: _streetController.text.trim(),
      apartment: _apartmentController.text.trim(),
      city: _selectedCity,
      state: _selectedState,
      zipCode: _zipController.text.trim(),
    );

    // In real app, save to Firebase
    setState(() {
      _savedAddresses.add(newAddress);
    });

    // Clear form
    _labelController.clear();
    _streetController.clear();
    _apartmentController.clear();
    _zipController.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Address saved successfully'),
        backgroundColor: Colors.green,
      ),
    );

    // Auto-select the new address
    _selectAddress(newAddress);
  }
}

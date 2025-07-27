import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'meal_schedule_page.dart';

class AddAddressPage extends StatefulWidget {
  final bool isSignupFlow;
  
  const AddAddressPage({
    super.key,
    this.isSignupFlow = false,
  });

  @override
  State<AddAddressPage> createState() => _AddAddressPageState();
}

class _AddAddressPageState extends State<AddAddressPage> {
  final _formKey = GlobalKey<FormState>();
  final _addressLine1Controller = TextEditingController();
  final _addressLine2Controller = TextEditingController();
  final _cityController = TextEditingController();
  final _zipController = TextEditingController();
  final _labelController = TextEditingController();
  
  String _selectedState = 'NY'; // Default to NY for NYC users
  bool _isLoading = false;

  final List<String> _usStates = [
    'AL', 'AK', 'AZ', 'AR', 'CA', 'CO', 'CT', 'DE', 'FL', 'GA',
    'HI', 'ID', 'IL', 'IN', 'IA', 'KS', 'KY', 'LA', 'ME', 'MD',
    'MA', 'MI', 'MN', 'MS', 'MO', 'MT', 'NE', 'NV', 'NH', 'NJ',
    'NM', 'NY', 'NC', 'ND', 'OH', 'OK', 'OR', 'PA', 'RI', 'SC',
    'SD', 'TN', 'TX', 'UT', 'VT', 'VA', 'WA', 'WV', 'WI', 'WY'
  ];

  @override
  void dispose() {
    _addressLine1Controller.dispose();
    _addressLine2Controller.dispose();
    _cityController.dispose();
    _zipController.dispose();
    _labelController.dispose();
    super.dispose();
  }

  String? _validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  String? _validateZip(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'ZIP code is required';
    }
    if (!RegExp(r'^\d{5}(-\d{4})?$').hasMatch(value.trim())) {
      return 'Please enter a valid ZIP code';
    }
    return null;
  }

  Future<void> _useCurrentLocation() async {
    // TODO: Implement GPS location functionality
    // For now, just show a placeholder
    setState(() {
      _addressLine1Controller.text = '123 Broadway';
      _cityController.text = 'New York';
      _selectedState = 'NY';
      _zipController.text = '10001';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Current location used (sample data)'),
        backgroundColor: Color(0xFF2D5A2D),
      ),
    );
  }

  Future<void> _saveAddress() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    // Simulate API call delay
    await Future.delayed(const Duration(milliseconds: 500));

    // Create address object
    final address = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'label': _labelController.text.trim(),
      'addressLine1': _addressLine1Controller.text.trim(),
      'addressLine2': _addressLine2Controller.text.trim(),
      'city': _cityController.text.trim(),
      'state': _selectedState,
      'zipCode': _zipController.text.trim(),
      'fullAddress': '${_addressLine1Controller.text.trim()}, ${_cityController.text.trim()}, $_selectedState ${_zipController.text.trim()}',
    };

    setState(() {
      _isLoading = false;
    });

    // Navigate based on flow type
    if (mounted) {
      if (widget.isSignupFlow) {
        // During signup, continue to meal schedule
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const MealSchedulePage(isSignupFlow: true),
          ),
        );
      } else {
        // Regular usage, return with address data
        Navigator.pop(context, address);
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
          'Add Address',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Current location button
                OutlinedButton.icon(
                  onPressed: _useCurrentLocation,
                  icon: const Icon(Icons.my_location, size: 20),
                  label: const Text('Use Current Location'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2D5A2D),
                    side: const BorderSide(color: Color(0xFF2D5A2D)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Address Line 1
                TextFormField(
                  controller: _addressLine1Controller,
                  decoration: InputDecoration(
                    labelText: 'Address Line 1',
                    hintText: 'Street address',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF2D5A2D)),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.red),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                  validator: (value) => _validateRequired(value, 'Address Line 1'),
                ),
                
                const SizedBox(height: 16),
                
                // Address Line 2
                TextFormField(
                  controller: _addressLine2Controller,
                  decoration: InputDecoration(
                    labelText: 'Address Line 2 (Optional)',
                    hintText: 'Apartment, suite, etc.',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF2D5A2D)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // City
                TextFormField(
                  controller: _cityController,
                  decoration: InputDecoration(
                    labelText: 'City',
                    hintText: 'Enter city',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF2D5A2D)),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.red),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                  validator: (value) => _validateRequired(value, 'City'),
                ),
                
                const SizedBox(height: 16),
                
                // State and ZIP row
                Row(
                  children: [
                    // State dropdown
                    Expanded(
                      flex: 1,
                      child: DropdownButtonFormField<String>(
                        value: _selectedState,
                        decoration: InputDecoration(
                          labelText: 'State',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF2D5A2D)),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                        items: _usStates.map((state) {
                          return DropdownMenuItem(
                            value: state,
                            child: Text(state),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedState = value!;
                          });
                        },
                      ),
                    ),
                    
                    const SizedBox(width: 16),
                    
                    // ZIP code
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _zipController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(5),
                        ],
                        decoration: InputDecoration(
                          labelText: 'ZIP Code',
                          hintText: '12345',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF2D5A2D)),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.red),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                        validator: _validateZip,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Address Label
                TextFormField(
                  controller: _labelController,
                  decoration: InputDecoration(
                    labelText: 'Address Label',
                    hintText: 'Home, Work, etc.',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF2D5A2D)),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.red),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                  validator: (value) => _validateRequired(value, 'Address Label'),
                ),
                
                const SizedBox(height: 32),
                
                // Save button
                ElevatedButton(
                  onPressed: _isLoading ? null : _saveAddress,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
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
                      : const Text(
                          'Save Address',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
                
                const SizedBox(height: 16),
                
                // Helper text
                Text(
                  'This address will be saved for future deliveries and can be edited later.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

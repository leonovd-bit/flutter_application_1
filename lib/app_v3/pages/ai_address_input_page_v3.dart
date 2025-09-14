import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/meal_model_v3.dart';
import '../services/firestore_service_v3.dart';
import '../services/ai_meal_recommendation_service.dart';
import 'ai_schedule_review_page_v3.dart';

/// Address input page for AI meal planning workflow
class AIAddressInputPageV3 extends StatefulWidget {
  final AIMealPlan mealPlan;
  
  const AIAddressInputPageV3({
    super.key,
    required this.mealPlan,
  });

  @override
  State<AIAddressInputPageV3> createState() => _AIAddressInputPageV3State();
}

class _AIAddressInputPageV3State extends State<AIAddressInputPageV3> {
  final _formKey = GlobalKey<FormState>();
  final _streetController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _zipController = TextEditingController();
  final _specialInstructionsController = TextEditingController();
  
  String _selectedAddressType = 'home';
  bool _isLoading = false;
  List<AddressModelV3> _savedAddresses = [];
  AddressModelV3? _selectedExistingAddress;

  @override
  void initState() {
    super.initState();
    _loadExistingAddresses();
  }

  @override
  void dispose() {
    _streetController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _zipController.dispose();
    _specialInstructionsController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingAddresses() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    try {
      final addresses = await FirestoreServiceV3.getUserAddresses(user.uid);
      setState(() {
        _savedAddresses = addresses;
      });
    } catch (e) {
      debugPrint('Error loading addresses: $e');
    }
  }

  Future<void> _saveAndContinue() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to continue')),
      );
      return;
    }

    AddressModelV3? address;
    
    if (_selectedExistingAddress != null) {
      address = _selectedExistingAddress;
    } else {
      if (!_formKey.currentState!.validate()) return;
      
      address = AddressModelV3(
        id: '',
        userId: user.uid,
        label: _selectedAddressType,
        streetAddress: _streetController.text.trim(),
        apartment: '',
        city: _cityController.text.trim(),
        state: _stateController.text.trim(),
        zipCode: _zipController.text.trim(),
        isDefault: _savedAddresses.isEmpty, // Make default if it's the first address
      );
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Save new address if not using existing
      if (_selectedExistingAddress == null) {
        await FirestoreServiceV3.saveAddress(address!);
      }
      
      // Navigate to schedule review page
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => AIScheduleReviewPageV3(
              mealPlan: widget.mealPlan,
              deliveryAddress: address!,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving address: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Delivery Address'),
        backgroundColor: Colors.green[600],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Meal plan summary
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your AI Meal Plan',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.green[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('${widget.mealPlan.meals.length} meals selected'),
                    Text('${widget.mealPlan.mealsPerDay} meals per day'),
                    Text('Goal: ${widget.mealPlan.goal}'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.local_fire_department, color: Colors.orange[600], size: 16),
                        const SizedBox(width: 4),
                        Text('${widget.mealPlan.nutritionSummary['calories']?.toInt() ?? 0} cal/week'),
                        const SizedBox(width: 16),
                        Icon(Icons.fitness_center, color: Colors.blue[600], size: 16),
                        const SizedBox(width: 4),
                        Text('${widget.mealPlan.nutritionSummary['protein']?.toInt() ?? 0}g protein'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Existing addresses section
            if (_savedAddresses.isNotEmpty) ...[
              Text(
                'Use Existing Address',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ..._savedAddresses.map((address) => Card(
                child: RadioListTile<AddressModelV3?>(
                  value: address,
                  groupValue: _selectedExistingAddress,
                  onChanged: (value) {
                    setState(() {
                      _selectedExistingAddress = value;
                    });
                  },
                  title: Text(address.type.toUpperCase()),
                  subtitle: Text(address.displayAddress),
                  secondary: Icon(
                    address.type == 'home' ? Icons.home : Icons.work,
                    color: Colors.green[600],
                  ),
                ),
              )),
              
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
            ],
            
            // New address form
            Text(
              _savedAddresses.isEmpty ? 'Delivery Address' : 'Or Add New Address',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            
            Form(
              key: _formKey,
              child: Column(
                children: [
                  // Address type selector
                  DropdownButtonFormField<String>(
                    value: _selectedAddressType,
                    decoration: const InputDecoration(
                      labelText: 'Address Type',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.location_on),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'home', child: Text('Home')),
                      DropdownMenuItem(value: 'work', child: Text('Work')),
                      DropdownMenuItem(value: 'other', child: Text('Other')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedAddressType = value ?? 'home';
                        _selectedExistingAddress = null; // Clear existing selection
                      });
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Street address
                  TextFormField(
                    controller: _streetController,
                    decoration: const InputDecoration(
                      labelText: 'Street Address',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.home),
                    ),
                    validator: (value) {
                      if (_selectedExistingAddress != null) return null;
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your street address';
                      }
                      return null;
                    },
                    onChanged: (_) {
                      setState(() {
                        _selectedExistingAddress = null; // Clear existing selection
                      });
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // City and State row
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _cityController,
                          decoration: const InputDecoration(
                            labelText: 'City',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.location_city),
                          ),
                          validator: (value) {
                            if (_selectedExistingAddress != null) return null;
                            if (value == null || value.trim().isEmpty) {
                              return 'Enter city';
                            }
                            return null;
                          },
                          onChanged: (_) {
                            setState(() {
                              _selectedExistingAddress = null;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _stateController,
                          decoration: const InputDecoration(
                            labelText: 'State',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (_selectedExistingAddress != null) return null;
                            if (value == null || value.trim().isEmpty) {
                              return 'Enter state';
                            }
                            return null;
                          },
                          onChanged: (_) {
                            setState(() {
                              _selectedExistingAddress = null;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // ZIP code
                  TextFormField(
                    controller: _zipController,
                    decoration: const InputDecoration(
                      labelText: 'ZIP Code',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.markunread_mailbox),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (_selectedExistingAddress != null) return null;
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter ZIP code';
                      }
                      if (value.trim().length < 5) {
                        return 'Please enter a valid ZIP code';
                      }
                      return null;
                    },
                    onChanged: (_) {
                      setState(() {
                        _selectedExistingAddress = null;
                      });
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Special instructions
                  TextFormField(
                    controller: _specialInstructionsController,
                    decoration: const InputDecoration(
                      labelText: 'Delivery Instructions (Optional)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.note),
                      hintText: 'e.g., Leave at front door, Ring doorbell',
                    ),
                    maxLines: 2,
                    onChanged: (_) {
                      setState(() {
                        _selectedExistingAddress = null;
                      });
                    },
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Continue button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveAndContinue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[600],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Continue to Schedule',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward, size: 24),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
